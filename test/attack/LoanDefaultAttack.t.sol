// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {FlashLoanPool} from "../../src/FlashLoanPool.sol";
import {IFlashLoanPool} from "../../src/interfaces/IFlashLoanPool.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {BadCallbackBorrower, NonRepayingBorrower} from "../helpers/FlashBorrowers.sol";

/**
 * @title LoanDefaultAttackTest
 * @notice Ataques de impago / callback inválido: el pool no pierde liquidez (atomicidad).
 * @dev Referencia: `doc/SWC-AUDIT.md` · `LoanRepaymentFailed` / `CallbackFailed`.
 */
contract LoanDefaultAttackTest is Test {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant LIQUIDITY = 10_000 ether;
    uint256 internal constant LOAN_AMOUNT = 100 ether;

    MockERC20 internal token;
    FlashLoanPool internal pool;
    NonRepayingBorrower internal deadbeat;
    BadCallbackBorrower internal badCallback;

    address internal lp = makeAddr("lp");

    function setUp() public {
        token = new MockERC20("Flash Token", "FLT");
        pool = new FlashLoanPool(address(token), FEE_BPS);
        deadbeat = new NonRepayingBorrower();
        badCallback = new BadCallbackBorrower();

        token.mint(lp, 1_000_000 ether);
        vm.startPrank(lp);
        token.approve(address(pool), LIQUIDITY);
        pool.deposit(LIQUIDITY);
        vm.stopPrank();
    }

    /**
     * @notice Ataque: receptor no aprueba repay → `LoanRepaymentFailed`; pool intacto.
     */
    function test_Attack_nonRepayingBorrower_reverts_poolIntact() public {
        uint256 poolBefore = token.balanceOf(address(pool));

        vm.expectRevert(IFlashLoanPool.LoanRepaymentFailed.selector);
        pool.flashLoan(deadbeat, address(token), LOAN_AMOUNT, "");

        assertEq(token.balanceOf(address(pool)), poolBefore);
        assertEq(token.balanceOf(address(deadbeat)), 0, "loan tokens rolled back");
    }

    /**
     * @notice Ataque: magic value inválido → `CallbackFailed`; pool intacto.
     */
    function test_Attack_badCallbackMagic_reverts_poolIntact() public {
        uint256 poolBefore = token.balanceOf(address(pool));

        vm.expectRevert(IFlashLoanPool.CallbackFailed.selector);
        pool.flashLoan(badCallback, address(token), LOAN_AMOUNT, "");

        assertEq(token.balanceOf(address(pool)), poolBefore);
        assertEq(token.balanceOf(address(badCallback)), 0);
    }

    /**
     * @notice Ataque: intentar prestar más que la liquidez → revert; sin transfer parcial.
     */
    function test_Attack_overborrow_revertsBeforeTransfer() public {
        uint256 poolBefore = token.balanceOf(address(pool));

        vm.expectRevert(IFlashLoanPool.AmountExceedsMaxLoan.selector);
        pool.flashLoan(deadbeat, address(token), LIQUIDITY + 1, "");

        assertEq(token.balanceOf(address(pool)), poolBefore);
        assertEq(token.balanceOf(address(deadbeat)), 0);
    }
}
