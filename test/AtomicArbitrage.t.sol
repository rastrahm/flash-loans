// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrage} from "../src/AtomicArbitrage.sol";
import {FlashLoanPool} from "../src/FlashLoanPool.sol";
import {IAtomicArbitrage} from "../src/interfaces/IAtomicArbitrage.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title AtomicArbitrageTest
 * @notice Fase 3 (TDD): mocks AMM desbalanceados + caminos de `execute` / profit.
 * @dev Constructor y MockAMM verdes; `execute` / profit quedan en rojo hasta la fase 4.
 */
contract AtomicArbitrageTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant LIQUIDITY = 10_000 ether;
    uint256 internal constant LOAN_AMOUNT = 10 ether;

    /// @dev AMM buy: A escasa / B abundante → vender A compra mucho B.
    uint256 internal constant BUY_RESERVE_A = 100 ether;
    uint256 internal constant BUY_RESERVE_B = 1_000 ether;

    /// @dev AMM sell: A abundante / B escasa → vender B recupera mucho A.
    uint256 internal constant SELL_RESERVE_A = 1_000 ether;
    uint256 internal constant SELL_RESERVE_B = 100 ether;

    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    FlashLoanPool internal pool;
    MockAMM internal ammBuy;
    MockAMM internal ammSell;
    AtomicArbitrage internal arb;

    address internal lp = makeAddr("lp");
    address internal profitOwner = makeAddr("profitOwner");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");

        pool = new FlashLoanPool(address(tokenA), FEE_BPS);
        ammBuy = new MockAMM(address(tokenA), address(tokenB));
        ammSell = new MockAMM(address(tokenA), address(tokenB));
        arb = new AtomicArbitrage(address(pool), profitOwner);

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

    function _params(uint256 minProfit) internal view returns (bytes memory) {
        return abi.encode(address(ammBuy), address(ammSell), address(tokenB), minProfit);
    }

    function _expectedFee(uint256 amount) internal pure returns (uint256) {
        return amount * FEE_BPS / 10_000;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @notice Constructor fija lender y owner de profit.
     */
    function test_constructor_setsFlashLenderAndOwner() public view {
        assertEq(arb.flashLender(), address(pool));
        assertEq(arb.owner(), profitOwner);
    }

    /**
     * @notice Lender o owner cero revierte `ZeroAddress`.
     */
    function test_constructor_revertsZeroAddress() public {
        vm.expectRevert(IAtomicArbitrage.ZeroAddress.selector);
        new AtomicArbitrage(address(0), profitOwner);

        vm.expectRevert(IAtomicArbitrage.ZeroAddress.selector);
        new AtomicArbitrage(address(pool), address(0));
    }

    // -------------------------------------------------------------------------
    // MockAMM — imbalance (fase 3, verdes)
    // -------------------------------------------------------------------------

    /**
     * @notice `getAmountOut` respeta fee 0.3% y reservas seteadas.
     */
    function test_mockAmm_getAmountOut_usesConstantProductFee() public view {
        uint256 amountIn = 1 ether;
        uint256 amountInWithFee = amountIn * 997;
        uint256 expected = (amountInWithFee * BUY_RESERVE_B) / (BUY_RESERVE_A * 1000 + amountInWithFee);
        assertEq(ammBuy.getAmountOut(amountIn, address(tokenA)), expected);
    }

    /**
     * @notice El desequilibrio A→B→A produce más `tokenA` que el input (spread artificial).
     */
    function test_mockAmm_imbalance_roundTripYieldsMoreTokenA() public view {
        uint256 amountIn = LOAN_AMOUNT;
        uint256 mid = ammBuy.getAmountOut(amountIn, address(tokenA));
        uint256 amountOut = ammSell.getAmountOut(mid, address(tokenB));
        assertGt(amountOut, amountIn + _expectedFee(amountIn), "spread must cover flash fee");
    }

    /**
     * @notice Swap actualiza reservas y transfiere output al receptor.
     */
    function test_mockAmm_swap_transfersAndUpdatesReserves() public {
        address trader = makeAddr("trader");
        uint256 amountIn = 1 ether;
        uint256 expectedOut = ammBuy.getAmountOut(amountIn, address(tokenA));

        tokenA.mint(trader, amountIn);
        vm.startPrank(trader);
        tokenA.approve(address(ammBuy), amountIn);
        uint256 out = ammBuy.swap(address(tokenA), amountIn, expectedOut, trader);
        vm.stopPrank();

        assertEq(out, expectedOut);
        assertEq(tokenB.balanceOf(trader), expectedOut);
        assertEq(ammBuy.reserve0(), BUY_RESERVE_A + amountIn);
        assertEq(ammBuy.reserve1(), BUY_RESERVE_B - expectedOut);
    }

    // -------------------------------------------------------------------------
    // execute — caminos TDD (rojo hasta fase 4)
    // -------------------------------------------------------------------------

    /**
     * @notice Amount 0 revierte `ZeroAmount`.
     */
    function test_execute_revertsZeroAmount() public {
        vm.expectRevert(IAtomicArbitrage.ZeroAmount.selector);
        arb.execute(0, _params(0));
    }

    /**
     * @notice Con AMMs desbalanceados, el owner recibe profit y el pool cobra el fee.
     */
    function test_execute_profitable_sendsProfitToOwner() public {
        uint256 poolBefore = tokenA.balanceOf(address(pool));
        uint256 ownerBefore = tokenA.balanceOf(profitOwner);
        uint256 fee = _expectedFee(LOAN_AMOUNT);

        uint256 mid = ammBuy.getAmountOut(LOAN_AMOUNT, address(tokenA));
        uint256 grossOut = ammSell.getAmountOut(mid, address(tokenB));
        uint256 expectedProfit = grossOut - LOAN_AMOUNT - fee;

        vm.expectEmit(true, false, false, true, address(arb));
        emit IAtomicArbitrage.ArbitrageExecuted(address(tokenA), LOAN_AMOUNT, expectedProfit);

        arb.execute(LOAN_AMOUNT, _params(0));

        assertEq(tokenA.balanceOf(address(pool)), poolBefore + fee, "pool keeps fee");
        assertEq(tokenA.balanceOf(profitOwner), ownerBefore + expectedProfit, "owner gets profit");
        assertEq(tokenA.balanceOf(address(arb)), 0, "arb holds no leftover");
        assertGt(expectedProfit, 0);
    }

    /**
     * @notice `minProfit` por encima del edge disponible revierte `UnprofitableArbitrage`.
     * @dev Fase 5 refuerza el caso sin spread; aquí el umbral alto fuerza el mismo error.
     */
    function test_execute_revertsWhenMinProfitTooHigh() public {
        vm.expectRevert(IAtomicArbitrage.UnprofitableArbitrage.selector);
        arb.execute(LOAN_AMOUNT, _params(type(uint256).max));
    }
}
