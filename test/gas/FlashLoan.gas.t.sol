// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrage} from "../../src/AtomicArbitrage.sol";
import {FlashLoanPool} from "../../src/FlashLoanPool.sol";
import {MockAMM} from "../../src/mocks/MockAMM.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {RepayingBorrower} from "../helpers/FlashBorrowers.sol";

/**
 * @title FlashLoanGasTest
 * @notice Baseline de gas para `forge snapshot` y `doc/GAS.md` (Fase 8).
 */
contract FlashLoanGasTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant LIQUIDITY = 10_000 ether;
    uint256 internal constant LOAN_AMOUNT = 10 ether;

    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    FlashLoanPool internal pool;
    AtomicArbitrage internal arb;
    MockAMM internal ammBuy;
    MockAMM internal ammSell;
    RepayingBorrower internal repayer;

    address internal lp = makeAddr("lp");
    address internal profitOwner = makeAddr("profitOwner");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        pool = new FlashLoanPool(address(tokenA), FEE_BPS);
        arb = new AtomicArbitrage(address(pool), profitOwner);
        ammBuy = new MockAMM(address(tokenA), address(tokenB));
        ammSell = new MockAMM(address(tokenA), address(tokenB));
        repayer = new RepayingBorrower();

        tokenA.mint(lp, 1_000_000 ether);
        tokenA.mint(address(repayer), 1_000 ether);

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

    function testGas_deposit() public {
        vm.startPrank(lp);
        tokenA.approve(address(pool), 100 ether);
        pool.deposit(100 ether);
        vm.stopPrank();
    }

    function testGas_withdraw() public {
        pool.withdraw(100 ether);
    }

    function testGas_flashLoan_repay() public {
        pool.flashLoan(repayer, address(tokenA), LOAN_AMOUNT, "");
    }

    function testGas_maxFlashLoan() public view {
        pool.maxFlashLoan(address(tokenA));
    }

    function testGas_flashFee() public view {
        pool.flashFee(address(tokenA), LOAN_AMOUNT);
    }

    function testGas_execute_arbitrage() public {
        bytes memory params = abi.encode(address(ammBuy), address(ammSell), address(tokenB), uint256(0));
        arb.execute(LOAN_AMOUNT, params);
    }
}
