// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FlashLoanPool} from "../../src/FlashLoanPool.sol";
import {IERC3156FlashBorrower} from "../../src/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../../src/interfaces/IERC3156FlashLender.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {ERC3156_CALLBACK_SUCCESS, ReenteringBorrower, RepayingBorrower} from "../helpers/FlashBorrowers.sol";

/**
 * @title NestedReenterBorrower
 * @notice Intenta un segundo `flashLoan` hacia un complice durante el callback.
 */
contract NestedReenterBorrower is IERC3156FlashBorrower {
    IERC3156FlashLender public lender;
    IERC3156FlashBorrower public accomplice;

    function configure(IERC3156FlashLender lender_, IERC3156FlashBorrower accomplice_) external {
        lender = lender_;
        accomplice = accomplice_;
    }

    function onFlashLoan(address, address token, uint256 amount, uint256, bytes calldata data)
        external
        returns (bytes32)
    {
        // Ataque: reentrar prestando al cómplice antes de devolver el primer loan.
        lender.flashLoan(accomplice, token, amount / 2, data);
        IERC20(token).approve(msg.sender, type(uint256).max);
        return ERC3156_CALLBACK_SUCCESS;
    }
}

/**
 * @title ReentrancyAttackTest
 * @notice SWC-107: callbacks maliciosos no reentran `flashLoan`; liquidez del pool intacta.
 * @dev Referencia: `doc/SWC-AUDIT.md` · patrón monorepo módulo 07.
 */
contract ReentrancyAttackTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant LIQUIDITY = 10_000 ether;
    uint256 internal constant LOAN_AMOUNT = 100 ether;

    MockERC20 internal token;
    FlashLoanPool internal pool;
    ReenteringBorrower internal reenterer;
    NestedReenterBorrower internal nested;
    RepayingBorrower internal accomplice;

    address internal lp = makeAddr("lp");

    function setUp() public {
        token = new MockERC20("Flash Token", "FLT");
        pool = new FlashLoanPool(address(token), FEE_BPS);
        reenterer = new ReenteringBorrower();
        nested = new NestedReenterBorrower();
        accomplice = new RepayingBorrower();

        reenterer.setLender(pool);
        nested.configure(pool, accomplice);

        token.mint(lp, 1_000_000 ether);
        token.mint(address(accomplice), 1_000 ether);

        vm.startPrank(lp);
        token.approve(address(pool), LIQUIDITY);
        pool.deposit(LIQUIDITY);
        vm.stopPrank();
    }

    /**
     * @notice SWC-107: reentrar el mismo `flashLoan` desde el callback revierte el guard.
     */
    function test_Attack_reenterFlashLoan_sameReceiver_revertsGuard() public {
        uint256 poolBefore = token.balanceOf(address(pool));

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        pool.flashLoan(reenterer, address(token), LOAN_AMOUNT, "");

        assertEq(token.balanceOf(address(pool)), poolBefore, "pool liquidity intact");
        assertEq(token.balanceOf(address(reenterer)), 0, "attacker holds no loaned tokens");
    }

    /**
     * @notice SWC-107: reentrar prestando a un cómplice también queda bloqueado.
     */
    function test_Attack_reenterFlashLoan_toAccomplice_revertsGuard() public {
        uint256 poolBefore = token.balanceOf(address(pool));
        uint256 accompliceBefore = token.balanceOf(address(accomplice));

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        pool.flashLoan(nested, address(token), LOAN_AMOUNT, "");

        assertEq(token.balanceOf(address(pool)), poolBefore);
        assertEq(token.balanceOf(address(accomplice)), accompliceBefore, "accomplice not funded");
        assertEq(token.balanceOf(address(nested)), 0);
    }

    /**
     * @notice Tras un ataque fallido, un préstamo honesto sigue funcionando (estado no corrupto).
     */
    function test_Attack_reentrancyFailure_doesNotCorruptPool() public {
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        pool.flashLoan(reenterer, address(token), LOAN_AMOUNT, "");

        uint256 fee = pool.flashFee(address(token), LOAN_AMOUNT);
        uint256 poolBefore = token.balanceOf(address(pool));

        assertTrue(pool.flashLoan(accomplice, address(token), LOAN_AMOUNT, ""));
        assertEq(token.balanceOf(address(pool)), poolBefore + fee);
    }

    /**
     * @notice Amount que agota casi toda la liquidez: la reentrada sigue revirtiendo igual.
     */
    function test_Attack_reenterNearMaxLoan_revertsGuard() public {
        uint256 amount = LIQUIDITY - 1;
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        pool.flashLoan(reenterer, address(token), amount, "");
        assertEq(token.balanceOf(address(pool)), LIQUIDITY);
    }
}
