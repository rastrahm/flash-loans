// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrage} from "../../src/AtomicArbitrage.sol";
import {FlashLoanPool} from "../../src/FlashLoanPool.sol";
import {IFlashLoanPool} from "../../src/interfaces/IFlashLoanPool.sol";
import {IAtomicArbitrage} from "../../src/interfaces/IAtomicArbitrage.sol";
import {MockAMM} from "../../src/mocks/MockAMM.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {RepayingBorrower} from "../helpers/FlashBorrowers.sol";

/**
 * @title FlashLoanFuzzTest
 * @notice Fase 7: fuzz de amounts (`bound`) para fee, deposit, flashLoan y arb rentable.
 */
contract FlashLoanFuzzTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant SEED_LIQUIDITY = 10_000 ether;

    MockERC20 internal token;
    MockERC20 internal tokenB;
    MockERC20 internal otherToken;
    FlashLoanPool internal pool;
    RepayingBorrower internal repayer;

    MockAMM internal ammBuy;
    MockAMM internal ammSell;
    AtomicArbitrage internal arb;

    address internal lp = makeAddr("lp");
    address internal profitOwner = makeAddr("profitOwner");

    function setUp() public {
        token = new MockERC20("Flash Token", "FLT");
        tokenB = new MockERC20("Token B", "TKB");
        otherToken = new MockERC20("Other", "OTH");
        pool = new FlashLoanPool(address(token), FEE_BPS);
        repayer = new RepayingBorrower();

        token.mint(lp, type(uint128).max);
        token.mint(address(repayer), type(uint128).max);

        vm.startPrank(lp);
        token.approve(address(pool), SEED_LIQUIDITY);
        pool.deposit(SEED_LIQUIDITY);
        vm.stopPrank();

        ammBuy = new MockAMM(address(token), address(tokenB));
        ammSell = new MockAMM(address(token), address(tokenB));
        arb = new AtomicArbitrage(address(pool), profitOwner);

        _fundAmm(ammBuy, 100 ether, 1_000 ether);
        _fundAmm(ammSell, 1_000 ether, 100 ether);
    }

    function _fundAmm(MockAMM amm, uint256 reserveA, uint256 reserveB) internal {
        token.mint(address(amm), reserveA);
        tokenB.mint(address(amm), reserveB);
        amm.setReserves(reserveA, reserveB);
    }

    function _fee(uint256 amount) internal pure returns (uint256) {
        return amount * FEE_BPS / BPS_DENOMINATOR;
    }

    // -------------------------------------------------------------------------
    // Lender
    // -------------------------------------------------------------------------

    /**
     * @notice `flashFee` = `amount * feeBps / 10_000` para el token soportado.
     */
    function testFuzz_flashFee_matchesBps(uint256 amount) public view {
        amount = bound(amount, 0, type(uint128).max);
        assertEq(pool.flashFee(address(token), amount), _fee(amount));
    }

    /**
     * @notice Token no soportado siempre revierte en `flashFee`.
     */
    function testFuzz_flashFee_revertsUnsupportedToken(uint256 amount) public {
        amount = bound(amount, 0, type(uint128).max);
        vm.expectRevert(IFlashLoanPool.UnsupportedToken.selector);
        pool.flashFee(address(otherToken), amount);
    }

    /**
     * @notice Tras depositar, `maxFlashLoan` iguala el balance del pool.
     */
    function testFuzz_deposit_maxFlashLoanEqualsBalance(uint256 amount) public {
        amount = bound(amount, 1, 100_000 ether);

        uint256 beforeBal = token.balanceOf(address(pool));

        vm.startPrank(lp);
        token.approve(address(pool), amount);
        pool.deposit(amount);
        vm.stopPrank();

        assertEq(pool.maxFlashLoan(address(token)), beforeBal + amount);
        assertEq(pool.maxFlashLoan(address(otherToken)), 0);
    }

    /**
     * @notice Flash loan exitoso: el pool gana exactamente el fee.
     */
    function testFuzz_flashLoan_poolGainsExactFee(uint256 amount) public {
        uint256 liquidity = token.balanceOf(address(pool));
        amount = bound(amount, 1, liquidity);

        uint256 fee = _fee(amount);
        uint256 poolBefore = token.balanceOf(address(pool));

        assertTrue(pool.flashLoan(repayer, address(token), amount, ""));

        assertEq(token.balanceOf(address(pool)), poolBefore + fee);
        assertEq(pool.maxFlashLoan(address(token)), poolBefore + fee);
    }

    /**
     * @notice Amount por encima de `maxFlashLoan` revierte `AmountExceedsMaxLoan`.
     */
    function testFuzz_flashLoan_revertsWhenExceedsMax(uint256 extra) public {
        uint256 liquidity = token.balanceOf(address(pool));
        extra = bound(extra, 1, 1_000 ether);

        vm.expectRevert(IFlashLoanPool.AmountExceedsMaxLoan.selector);
        pool.flashLoan(repayer, address(token), liquidity + extra, "");
    }

    /**
     * @notice Depósito cero siempre revierte (fuzz trivial de selector).
     */
    function testFuzz_deposit_revertsZeroAmount() public {
        vm.expectRevert(IFlashLoanPool.ZeroAmount.selector);
        pool.deposit(0);
    }

    // -------------------------------------------------------------------------
    // Arbitrage
    // -------------------------------------------------------------------------

    /**
     * @notice Con spread artificial, amounts acotados dejan profit al owner y fee al pool.
     */
    function testFuzz_execute_profitable_amountBounds(uint256 amount) public {
        // Rango donde el imbalance extremo sigue cubriendo fee + slippage.
        amount = bound(amount, 0.01 ether, 20 ether);

        uint256 mid = ammBuy.getAmountOut(amount, address(token));
        uint256 grossOut = ammSell.getAmountOut(mid, address(tokenB));
        uint256 fee = _fee(amount);
        vm.assume(grossOut > amount + fee);

        uint256 expectedProfit = grossOut - amount - fee;
        uint256 poolBefore = token.balanceOf(address(pool));
        uint256 ownerBefore = token.balanceOf(profitOwner);

        bytes memory params = abi.encode(address(ammBuy), address(ammSell), address(tokenB), uint256(0));
        arb.execute(amount, params);

        assertEq(token.balanceOf(address(pool)), poolBefore + fee);
        assertEq(token.balanceOf(profitOwner), ownerBefore + expectedProfit);
        assertEq(token.balanceOf(address(arb)), 0);
    }

    /**
     * @notice `minProfit` mayor al edge disponible revierte de forma atómica.
     */
    function testFuzz_execute_minProfitTooHigh_reverts(uint256 amount, uint256 bump) public {
        amount = bound(amount, 0.01 ether, 20 ether);
        bump = bound(bump, 1, 100 ether);

        uint256 mid = ammBuy.getAmountOut(amount, address(token));
        uint256 grossOut = ammSell.getAmountOut(mid, address(tokenB));
        uint256 fee = _fee(amount);
        vm.assume(grossOut > amount + fee);

        uint256 profit = grossOut - amount - fee;
        uint256 poolBefore = token.balanceOf(address(pool));

        bytes memory params = abi.encode(address(ammBuy), address(ammSell), address(tokenB), profit + bump);
        vm.expectRevert(IAtomicArbitrage.UnprofitableArbitrage.selector);
        arb.execute(amount, params);

        assertEq(token.balanceOf(address(pool)), poolBefore);
    }
}
