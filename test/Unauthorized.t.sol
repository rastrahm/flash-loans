// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrage} from "../src/AtomicArbitrage.sol";
import {FlashLoanPool} from "../src/FlashLoanPool.sol";
import {IAtomicArbitrage} from "../src/interfaces/IAtomicArbitrage.sol";
import {IERC3156FlashBorrower} from "../src/interfaces/IERC3156FlashBorrower.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title FakeLender
 * @notice Simula un lender que invoca `onFlashLoan` sin ser el pool de confianza.
 */
contract FakeLender {
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
 * @notice Unit auth: `UntrustedLender` / `InvalidInitiator` (regresión rápida).
 * @dev Narrativas adversariales ampliadas en `test/attack/CallbackSpoofAttack.t.sol`.
 */
contract UnauthorizedTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant LIQUIDITY = 10_000 ether;
    uint256 internal constant LOAN_AMOUNT = 10 ether;

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

        tokenA.mint(address(ammBuy), 100 ether);
        tokenB.mint(address(ammBuy), 1_000 ether);
        ammBuy.setReserves(100 ether, 1_000 ether);
        tokenA.mint(address(ammSell), 1_000 ether);
        tokenB.mint(address(ammSell), 100 ether);
        ammSell.setReserves(1_000 ether, 100 ether);
    }

    function _params() internal view returns (bytes memory) {
        return abi.encode(address(ammBuy), address(ammSell), address(tokenB), uint256(0));
    }

    function test_onFlashLoan_revertsWhenCalledByEOA() public {
        vm.prank(attacker);
        vm.expectRevert(IAtomicArbitrage.UntrustedLender.selector);
        arb.onFlashLoan(address(arb), address(tokenA), LOAN_AMOUNT, 0, _params());
    }

    function test_onFlashLoan_revertsWhenCalledByFakeLender() public {
        vm.expectRevert(IAtomicArbitrage.UntrustedLender.selector);
        fakeLender.spoofCallback(arb, address(arb), address(tokenA), LOAN_AMOUNT, 0, _params());
    }

    function test_flashLoan_thirdPartyInitiator_revertsInvalidInitiator() public {
        vm.prank(attacker);
        vm.expectRevert(IAtomicArbitrage.InvalidInitiator.selector);
        pool.flashLoan(IERC3156FlashBorrower(address(arb)), address(tokenA), LOAN_AMOUNT, _params());
    }
}
