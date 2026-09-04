// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrage} from "../../src/AtomicArbitrage.sol";
import {FlashLoanPool} from "../../src/FlashLoanPool.sol";
import {MockAMM} from "../../src/mocks/MockAMM.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title ArbitrageForkTest
 * @notice Fase 8: ejecuta el stack sobre un fork de mainnet si hay `MAINNET_RPC_URL`.
 * @dev Sin RPC la suite se salta (`vm.skip`). Despliega mocks en el fork (no depende de Uniswap live).
 */
contract ArbitrageForkTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant LIQUIDITY = 10_000 ether;
    uint256 internal constant LOAN_AMOUNT = 10 ether;

    bool internal forked;

    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    FlashLoanPool internal pool;
    AtomicArbitrage internal arb;
    MockAMM internal ammBuy;
    MockAMM internal ammSell;

    address internal lp = makeAddr("lp");
    address internal profitOwner = makeAddr("profitOwner");

    function setUp() public {
        string memory rpc;
        try vm.envString("MAINNET_RPC_URL") returns (string memory url) {
            rpc = url;
        } catch {
            return;
        }
        if (bytes(rpc).length == 0) {
            return;
        }

        vm.createSelectFork(rpc);
        forked = true;

        tokenA = new MockERC20("Fork Token A", "FTKA");
        tokenB = new MockERC20("Fork Token B", "FTKB");
        pool = new FlashLoanPool(address(tokenA), FEE_BPS);
        arb = new AtomicArbitrage(address(pool), profitOwner);
        ammBuy = new MockAMM(address(tokenA), address(tokenB));
        ammSell = new MockAMM(address(tokenA), address(tokenB));

        tokenA.mint(lp, 1_000_000 ether);
        vm.startPrank(lp);
        tokenA.approve(address(pool), LIQUIDITY);
        pool.deposit(LIQUIDITY);
        vm.stopPrank();

        _fundAmm(ammBuy, 100 ether, 1_000 ether);
        _fundAmm(ammSell, 1_000 ether, 100 ether);
    }

    function _fundAmm(MockAMM amm, uint256 reserveA, uint256 reserveB) internal {
        tokenA.mint(address(amm), reserveA);
        tokenB.mint(address(amm), reserveB);
        amm.setReserves(reserveA, reserveB);
    }

    function _skipIfNoFork() internal {
        if (!forked) {
            vm.skip(true);
        }
    }

    /**
     * @notice En fork: arbitraje rentable deja fee en el pool y profit en el owner.
     */
    function testFork_execute_profitable_onForkedEvm() public {
        _skipIfNoFork();

        uint256 poolBefore = tokenA.balanceOf(address(pool));
        uint256 ownerBefore = tokenA.balanceOf(profitOwner);
        uint256 fee = LOAN_AMOUNT * FEE_BPS / 10_000;

        bytes memory params = abi.encode(address(ammBuy), address(ammSell), address(tokenB), uint256(0));
        arb.execute(LOAN_AMOUNT, params);

        assertEq(tokenA.balanceOf(address(pool)), poolBefore + fee);
        assertGt(tokenA.balanceOf(profitOwner), ownerBefore);
        assertEq(tokenA.balanceOf(address(arb)), 0);
    }

    /**
     * @notice En fork: AMMs equilibrados revierten sin mover liquidez del pool.
     */
    function testFork_execute_balanced_reverts_poolIntact() public {
        _skipIfNoFork();

        deal(address(tokenA), address(ammBuy), 1_000 ether);
        deal(address(tokenB), address(ammBuy), 1_000 ether);
        ammBuy.setReserves(1_000 ether, 1_000 ether);
        deal(address(tokenA), address(ammSell), 1_000 ether);
        deal(address(tokenB), address(ammSell), 1_000 ether);
        ammSell.setReserves(1_000 ether, 1_000 ether);

        uint256 poolBefore = tokenA.balanceOf(address(pool));
        bytes memory params = abi.encode(address(ammBuy), address(ammSell), address(tokenB), uint256(0));

        vm.expectRevert();
        arb.execute(LOAN_AMOUNT, params);

        assertEq(tokenA.balanceOf(address(pool)), poolBefore);
    }
}
