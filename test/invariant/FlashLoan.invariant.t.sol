// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {FlashLoanPool} from "../../src/FlashLoanPool.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {RepayingBorrower} from "../helpers/FlashBorrowers.sol";
import {FlashLoanHandler} from "./FlashLoanHandler.sol";

/**
 * @title FlashLoanInvariantTest
 * @notice Fase 7: `balance(pool) == deposits - withdraws + fees`; maxLoan; fallos atómicos.
 */
contract FlashLoanInvariantTest is StdInvariant, Test {
    uint256 internal constant FEE_BPS = 5;

    MockERC20 internal token;
    FlashLoanPool internal pool;
    RepayingBorrower internal repayer;
    FlashLoanHandler internal handler;

    function setUp() public {
        token = new MockERC20("Flash Token", "FLT");
        pool = new FlashLoanPool(address(token), FEE_BPS);
        repayer = new RepayingBorrower();
        handler = new FlashLoanHandler(pool, token, repayer);

        pool.transferOwnership(address(handler));
        vm.prank(address(handler));
        pool.acceptOwnership();

        // Liquidez inicial contada en ghosts del handler.
        handler.deposit(0, 1_000 ether);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = FlashLoanHandler.deposit.selector;
        selectors[1] = FlashLoanHandler.withdraw.selector;
        selectors[2] = FlashLoanHandler.flashLoanSuccess.selector;
        selectors[3] = FlashLoanHandler.flashLoanFailing.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice Contabilidad exacta: balance = depósitos + fees − retiros (los retiros pueden incluir fees).
    function invariant_balanceEqualsGhostAccounting() public view {
        uint256 expected = handler.ghostDeposited() + handler.ghostFeesEarned() - handler.ghostWithdrawn();
        assertEq(token.balanceOf(address(pool)), expected);
    }

    /// @notice `maxFlashLoan` del token soportado refleja el balance actual.
    function invariant_maxFlashLoanEqualsBalance() public view {
        assertEq(pool.maxFlashLoan(address(token)), token.balanceOf(address(pool)));
    }

    /// @notice Token ajeno: `maxFlashLoan` siempre 0.
    function invariant_unsupportedTokenMaxLoanIsZero() public view {
        assertEq(pool.maxFlashLoan(address(0xBEEF)), 0);
    }

    /// @notice No se puede retirar más de lo aportado + fees cobrados.
    function invariant_withdrawnLeDepositsPlusFees() public view {
        assertLe(handler.ghostWithdrawn(), handler.ghostDeposited() + handler.ghostFeesEarned());
    }
}
