// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {AtomicArbitrage} from "../src/AtomicArbitrage.sol";
import {FlashLoanPool} from "../src/FlashLoanPool.sol";
import {IAtomicArbitrage} from "../src/interfaces/IAtomicArbitrage.sol";
import {IERC3156FlashBorrower} from "../src/interfaces/IERC3156FlashBorrower.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {ReenteringBorrower} from "./helpers/FlashBorrowers.sol";

/**
 * @title FakeLender
 * @notice Simula un lender que invoca `onFlashLoan` sin ser el pool de confianza.
 */
contract FakeLender {
    /**
     * @notice Llama al callback del arb fingiendo ser el lender ERC-3156.
     */
    function spoofCallback(
        AtomicArbitrage arb,
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        return arb.onFlashLoan(initiator, token, amount, fee, data);
    }
}

/**
 * @title UnauthorizedTest
 * @notice Fase 6: terceros no pueden disparar el callback ni robar fondos vía initiator falso.
 */
contract UnauthorizedTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant LIQUIDITY = 10_000 ether;
    uint256 internal constant LOAN_AMOUNT = 10 ether;
    uint256 internal constant BUY_RESERVE_A = 100 ether;
    uint256 internal constant BUY_RESERVE_B = 1_000 ether;
    uint256 internal constant SELL_RESERVE_A = 1_000 ether;
    uint256 internal constant SELL_RESERVE_B = 100 ether;

    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    FlashLoanPool internal pool;
    MockAMM internal ammBuy;
    MockAMM internal ammSell;
    AtomicArbitrage internal arb;
    FakeLender internal fakeLender;

    address internal lp = makeAddr("lp");
    address internal profitOwner = makeAddr("profitOwner");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");

        pool = new FlashLoanPool(address(tokenA), FEE_BPS);
        ammBuy = new MockAMM(address(tokenA), address(tokenB));
        ammSell = new MockAMM(address(tokenA), address(tokenB));
        arb = new AtomicArbitrage(address(pool), profitOwner);
        fakeLender = new FakeLender();

        tokenA.mint(lp, 1_000_000 ether);
        vm.startPrank(lp);
        tokenA.approve(address(pool), LIQUIDITY);
        pool.deposit(LIQUIDITY);
        vm.stopPrank();

        _fundAmm(ammBuy, BUY_RESERVE_A, BUY_RESERVE_B);
        _fundAmm(ammSell, SELL_RESERVE_A, SELL_RESERVE_B);
    }

    function _fundAmm(MockAMM amm, uint256 reserveA, uint256 reserveB) internal {
        tokenA.mint(address(amm), reserveA);
        tokenB.mint(address(amm), reserveB);
        amm.setReserves(reserveA, reserveB);
    }

    function _params() internal view returns (bytes memory) {
        return abi.encode(address(ammBuy), address(ammSell), address(tokenB), uint256(0));
    }

    // -------------------------------------------------------------------------
    // UntrustedLender
    // -------------------------------------------------------------------------

    /**
     * @notice Un EOA no puede invocar `onFlashLoan` directamente.
     */
    function test_onFlashLoan_revertsWhenCalledByEOA() public {
        vm.prank(attacker);
        vm.expectRevert(IAtomicArbitrage.UntrustedLender.selector);
        arb.onFlashLoan(address(arb), address(tokenA), LOAN_AMOUNT, 0, _params());
    }

    /**
     * @notice Un contrato “lender” falso no puede pasar la auth aunque `initiator == arb`.
     */
    function test_onFlashLoan_revertsWhenCalledByFakeLender() public {
        // Fondo el arb para que, sin auth, un spoof podría intentar swaps.
        tokenA.mint(address(arb), LOAN_AMOUNT);

        uint256 poolBefore = tokenA.balanceOf(address(pool));
        uint256 arbBefore = tokenA.balanceOf(address(arb));
        uint256 ownerBefore = tokenA.balanceOf(profitOwner);

        vm.expectRevert(IAtomicArbitrage.UntrustedLender.selector);
        fakeLender.spoofCallback(arb, address(arb), address(tokenA), LOAN_AMOUNT, 0, _params());

        assertEq(tokenA.balanceOf(address(pool)), poolBefore);
        assertEq(tokenA.balanceOf(address(arb)), arbBefore, "arb funds not drained");
        assertEq(tokenA.balanceOf(profitOwner), ownerBefore);
    }

    /**
     * @notice Incluso con `initiator` del atacante, un caller no-lender revierte `UntrustedLender` primero.
     */
    function test_onFlashLoan_untrustedLenderCheckedBeforeInitiator() public {
        vm.prank(attacker);
        vm.expectRevert(IAtomicArbitrage.UntrustedLender.selector);
        arb.onFlashLoan(attacker, address(tokenA), LOAN_AMOUNT, 0, _params());
    }

    // -------------------------------------------------------------------------
    // InvalidInitiator
    // -------------------------------------------------------------------------

    /**
     * @notice Si un tercero inicia `flashLoan(arb, …)`, el arb ve `initiator != this` y revierte.
     * @dev Toda la tx revierte: el pool no pierde liquidez.
     */
    function test_flashLoan_thirdPartyInitiator_revertsInvalidInitiator_poolIntact() public {
        uint256 poolBefore = tokenA.balanceOf(address(pool));
        uint256 arbBefore = tokenA.balanceOf(address(arb));
        uint256 ownerBefore = tokenA.balanceOf(profitOwner);
        uint256 buyA = tokenA.balanceOf(address(ammBuy));
        uint256 sellA = tokenA.balanceOf(address(ammSell));

        vm.prank(attacker);
        vm.expectRevert(IAtomicArbitrage.InvalidInitiator.selector);
        pool.flashLoan(IERC3156FlashBorrower(address(arb)), address(tokenA), LOAN_AMOUNT, _params());

        assertEq(tokenA.balanceOf(address(pool)), poolBefore, "pool intact");
        assertEq(tokenA.balanceOf(address(arb)), arbBefore);
        assertEq(tokenA.balanceOf(profitOwner), ownerBefore);
        assertEq(tokenA.balanceOf(address(ammBuy)), buyA, "ammBuy not mutated");
        assertEq(tokenA.balanceOf(address(ammSell)), sellA, "ammSell not mutated");
    }

    // -------------------------------------------------------------------------
    // Reentrancy (lender) — refuerzo documentado en fase 6
    // -------------------------------------------------------------------------

    /**
     * @notice Reentrar `flashLoan` desde un borrower malicioso sigue bloqueado por el guard del pool.
     */
    function test_flashLoan_reentrancyFromMaliciousBorrower_reverts() public {
        ReenteringBorrower reenterer = new ReenteringBorrower();
        reenterer.setLender(pool);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        pool.flashLoan(reenterer, address(tokenA), LOAN_AMOUNT, "");

        assertEq(tokenA.balanceOf(address(pool)), LIQUIDITY);
    }
}
