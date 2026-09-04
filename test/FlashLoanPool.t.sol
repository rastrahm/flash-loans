// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {FlashLoanPool} from "../src/FlashLoanPool.sol";
import {IFlashLoanPool} from "../src/interfaces/IFlashLoanPool.sol";
import {IERC3156FlashBorrower} from "../src/interfaces/IERC3156FlashBorrower.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {
    BadCallbackBorrower,
    NonRepayingBorrower,
    ReenteringBorrower,
    RepayingBorrower
} from "./helpers/FlashBorrowers.sol";

/**
 * @title FlashLoanPoolTest
 * @notice Suite unitaria del lender: `maxFlashLoan`, `flashFee`, `flashLoan`, deposit/withdraw y reverts.
 * @dev Fase 2: caminos verdes. Reentrancy cubierta vía `ReenteringBorrower`.
 */
contract FlashLoanPoolTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant LIQUIDITY = 1_000 ether;
    uint256 internal constant LOAN_AMOUNT = 100 ether;

    MockERC20 internal token;
    MockERC20 internal otherToken;
    FlashLoanPool internal pool;

    address internal lp = makeAddr("lp");
    address internal stranger = makeAddr("stranger");

    RepayingBorrower internal repayer;
    NonRepayingBorrower internal deadbeat;
    BadCallbackBorrower internal badCallback;
    ReenteringBorrower internal reenterer;

    function setUp() public {
        token = new MockERC20("Flash Token", "FLT");
        otherToken = new MockERC20("Other", "OTH");
        pool = new FlashLoanPool(address(token), FEE_BPS);

        token.mint(lp, 1_000_000 ether);

        repayer = new RepayingBorrower();
        deadbeat = new NonRepayingBorrower();
        badCallback = new BadCallbackBorrower();
        reenterer = new ReenteringBorrower();
        reenterer.setLender(pool);
    }

    function _expectedFee(uint256 amount) internal pure returns (uint256) {
        return amount * FEE_BPS / BPS_DENOMINATOR;
    }

    function _depositFromLp(uint256 amount) internal {
        vm.startPrank(lp);
        token.approve(address(pool), amount);
        pool.deposit(amount);
        vm.stopPrank();
    }

    function _fundRepayerFee(uint256 amount) internal {
        token.mint(address(repayer), _expectedFee(amount));
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @notice Constructor fija token, fee y owner.
     */
    function test_constructor_setsTokenFeeAndOwner() public view {
        assertEq(pool.token(), address(token));
        assertEq(pool.feeBps(), FEE_BPS);
        assertEq(pool.owner(), address(this));
    }

    /**
     * @notice Token cero revierte `ZeroAddress`.
     */
    function test_constructor_revertsZeroAddress() public {
        vm.expectRevert(IFlashLoanPool.ZeroAddress.selector);
        new FlashLoanPool(address(0), FEE_BPS);
    }

    // -------------------------------------------------------------------------
    // maxFlashLoan
    // -------------------------------------------------------------------------

    /**
     * @notice Token no soportado: `maxFlashLoan` es 0 (ERC-3156).
     */
    function test_maxFlashLoan_unsupportedTokenReturnsZero() public view {
        assertEq(pool.maxFlashLoan(address(otherToken)), 0);
    }

    /**
     * @notice Pool vacío: `maxFlashLoan` del token soportado es 0.
     */
    function test_maxFlashLoan_emptyPoolReturnsZero() public view {
        assertEq(pool.maxFlashLoan(address(token)), 0);
    }

    /**
     * @notice Tras depositar, `maxFlashLoan` iguala el balance del pool.
     */
    function test_maxFlashLoan_equalsPoolBalanceAfterDeposit() public {
        _depositFromLp(LIQUIDITY);
        assertEq(pool.maxFlashLoan(address(token)), LIQUIDITY);
        assertEq(pool.maxFlashLoan(address(token)), token.balanceOf(address(pool)));
    }

    // -------------------------------------------------------------------------
    // flashFee
    // -------------------------------------------------------------------------

    /**
     * @notice Token no soportado: `flashFee` revierte `UnsupportedToken`.
     */
    function test_flashFee_revertsUnsupportedToken() public {
        vm.expectRevert(IFlashLoanPool.UnsupportedToken.selector);
        pool.flashFee(address(otherToken), LOAN_AMOUNT);
    }

    /**
     * @notice Fee = `amount * feeBps / 10_000`.
     */
    function test_flashFee_computesBps() public view {
        assertEq(pool.flashFee(address(token), LOAN_AMOUNT), _expectedFee(LOAN_AMOUNT));
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    // -------------------------------------------------------------------------
    // deposit
    // -------------------------------------------------------------------------

    /**
     * @notice Depósito cero revierte `ZeroAmount`.
     */
    function test_deposit_revertsZeroAmount() public {
        vm.expectRevert(IFlashLoanPool.ZeroAmount.selector);
        pool.deposit(0);
    }

    /**
     * @notice Depósito transfiere tokens al pool y emite `LiquidityDeposited`.
     */
    function test_deposit_transfersAndEmits() public {
        vm.startPrank(lp);
        token.approve(address(pool), LIQUIDITY);

        vm.expectEmit(true, false, false, true, address(pool));
        emit IFlashLoanPool.LiquidityDeposited(lp, LIQUIDITY);

        pool.deposit(LIQUIDITY);
        vm.stopPrank();

        assertEq(token.balanceOf(address(pool)), LIQUIDITY);
        assertEq(token.balanceOf(lp), 1_000_000 ether - LIQUIDITY);
    }

    // -------------------------------------------------------------------------
    // withdraw
    // -------------------------------------------------------------------------

    /**
     * @notice Retiro cero revierte `ZeroAmount`.
     */
    function test_withdraw_revertsZeroAmount() public {
        vm.expectRevert(IFlashLoanPool.ZeroAmount.selector);
        pool.withdraw(0);
    }

    /**
     * @notice No-owner no puede retirar.
     */
    function test_withdraw_revertsNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        pool.withdraw(1);
    }

    /**
     * @notice Owner retira liquidez y emite `LiquidityWithdrawn`.
     */
    function test_withdraw_ownerPullsLiquidity() public {
        _depositFromLp(LIQUIDITY);

        vm.expectEmit(true, false, false, true, address(pool));
        emit IFlashLoanPool.LiquidityWithdrawn(address(this), LIQUIDITY);

        pool.withdraw(LIQUIDITY);

        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(token.balanceOf(address(this)), LIQUIDITY);
    }

    // -------------------------------------------------------------------------
    // flashLoan — reverts
    // -------------------------------------------------------------------------

    /**
     * @notice Receiver cero revierte `ZeroAddress`.
     */
    function test_flashLoan_revertsZeroReceiver() public {
        _depositFromLp(LIQUIDITY);
        vm.expectRevert(IFlashLoanPool.ZeroAddress.selector);
        pool.flashLoan(IERC3156FlashBorrower(address(0)), address(token), LOAN_AMOUNT, "");
    }

    /**
     * @notice Token no soportado revierte `UnsupportedToken`.
     */
    function test_flashLoan_revertsUnsupportedToken() public {
        _depositFromLp(LIQUIDITY);
        vm.expectRevert(IFlashLoanPool.UnsupportedToken.selector);
        pool.flashLoan(repayer, address(otherToken), LOAN_AMOUNT, "");
    }

    /**
     * @notice Amount 0 revierte `ZeroAmount`.
     */
    function test_flashLoan_revertsZeroAmount() public {
        _depositFromLp(LIQUIDITY);
        vm.expectRevert(IFlashLoanPool.ZeroAmount.selector);
        pool.flashLoan(repayer, address(token), 0, "");
    }

    /**
     * @notice Amount mayor a `maxFlashLoan` revierte `AmountExceedsMaxLoan`.
     */
    function test_flashLoan_revertsAmountExceedsMaxLoan() public {
        _depositFromLp(LIQUIDITY);
        vm.expectRevert(IFlashLoanPool.AmountExceedsMaxLoan.selector);
        pool.flashLoan(repayer, address(token), LIQUIDITY + 1, "");
    }

    /**
     * @notice Callback con magic value inválido revierte `CallbackFailed`.
     */
    function test_flashLoan_revertsCallbackFailed() public {
        _depositFromLp(LIQUIDITY);
        vm.expectRevert(IFlashLoanPool.CallbackFailed.selector);
        pool.flashLoan(badCallback, address(token), LOAN_AMOUNT, "");
    }

    /**
     * @notice Receptor que no aprueba el repay revierte `LoanRepaymentFailed`.
     */
    function test_flashLoan_revertsLoanRepaymentFailed() public {
        _depositFromLp(LIQUIDITY);
        vm.expectRevert(IFlashLoanPool.LoanRepaymentFailed.selector);
        pool.flashLoan(deadbeat, address(token), LOAN_AMOUNT, "");
    }

    /**
     * @notice Reentrar `flashLoan` desde el callback revierte el guard.
     */
    function test_flashLoan_revertsOnReentrancy() public {
        _depositFromLp(LIQUIDITY);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        pool.flashLoan(reenterer, address(token), LOAN_AMOUNT, "");
    }

    // -------------------------------------------------------------------------
    // flashLoan — camino feliz
    // -------------------------------------------------------------------------

    /**
     * @notice Préstamo + repay: el pool gana el fee y emite `FlashLoan`.
     */
    function test_flashLoan_repaysPrincipalAndFee() public {
        _depositFromLp(LIQUIDITY);
        uint256 fee = _expectedFee(LOAN_AMOUNT);
        _fundRepayerFee(LOAN_AMOUNT);

        uint256 poolBefore = token.balanceOf(address(pool));

        vm.expectEmit(true, true, false, true, address(pool));
        emit IFlashLoanPool.FlashLoan(address(repayer), address(token), LOAN_AMOUNT, fee);

        bool ok = pool.flashLoan(repayer, address(token), LOAN_AMOUNT, "");
        assertTrue(ok);

        assertEq(token.balanceOf(address(pool)), poolBefore + fee, "pool keeps fee");
        assertEq(token.balanceOf(address(repayer)), 0, "borrower repaid all loaned tokens");
        assertEq(IERC20(token).allowance(address(repayer), address(pool)), 0);
    }
}
