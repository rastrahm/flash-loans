// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {FlashLoanPool} from "../../src/FlashLoanPool.sol";
import {IFlashLoanPool} from "../../src/interfaces/IFlashLoanPool.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {RepayingBorrower} from "../helpers/FlashBorrowers.sol";

/**
 * @title FlashLoanHandler
 * @notice Actor aleatorio para invariantes: deposit / withdraw / flashLoan / intentos fallidos.
 * @dev Ghosts: `ghostDeposited + ghostFeesEarned - ghostWithdrawn == balance(pool)`.
 */
contract FlashLoanHandler is Test {
    uint256 internal constant FEE_BPS = 5;

    FlashLoanPool public immutable pool;
    MockERC20 public immutable token;
    RepayingBorrower public immutable repayer;

    address[] public actorsList;

    uint256 public ghostDeposited;
    uint256 public ghostWithdrawn;
    uint256 public ghostFeesEarned;

    constructor(FlashLoanPool pool_, MockERC20 token_, RepayingBorrower repayer_) {
        pool = pool_;
        token = token_;
        repayer = repayer_;

        actorsList.push(makeAddr("actor0"));
        actorsList.push(makeAddr("actor1"));
        actorsList.push(makeAddr("actor2"));

        for (uint256 i = 0; i < actorsList.length; ++i) {
            token.mint(actorsList[i], 1_000_000 ether);
        }
        token.mint(address(repayer), type(uint128).max);
    }

    /**
     * @notice Deposita liquidez desde un actor aleatorio.
     */
    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actorsList[actorSeed % actorsList.length];
        amount = bound(amount, 1, 10_000 ether);

        vm.startPrank(actor);
        token.approve(address(pool), amount);
        pool.deposit(amount);
        vm.stopPrank();

        ghostDeposited += amount;
    }

    /**
     * @notice Retira liquidez ociosa (solo owner = este handler).
     */
    function withdraw(uint256 amount) external {
        uint256 bal = token.balanceOf(address(pool));
        if (bal == 0) {
            return;
        }
        amount = bound(amount, 1, bal);

        pool.withdraw(amount);
        ghostWithdrawn += amount;
    }

    /**
     * @notice Flash loan exitoso: el pool acumula el fee.
     */
    function flashLoanSuccess(uint256 amount) external {
        uint256 bal = token.balanceOf(address(pool));
        if (bal == 0) {
            return;
        }
        amount = bound(amount, 1, bal);

        uint256 fee = pool.flashFee(address(token), amount);
        pool.flashLoan(repayer, address(token), amount, "");
        ghostFeesEarned += fee;
    }

    /**
     * @notice Intentos que deben revertir sin mutar ghosts (amount 0 / exceso / token inválido).
     */
    function flashLoanFailing(uint256 kind, uint256 amount) external {
        uint256 bal = token.balanceOf(address(pool));
        kind = bound(kind, 0, 2);

        uint256 poolBefore = token.balanceOf(address(pool));
        uint256 deposited = ghostDeposited;
        uint256 withdrawn = ghostWithdrawn;
        uint256 fees = ghostFeesEarned;

        if (kind == 0) {
            vm.expectRevert(IFlashLoanPool.ZeroAmount.selector);
            pool.flashLoan(repayer, address(token), 0, "");
        } else if (kind == 1) {
            amount = bound(amount, bal + 1, bal + 1_000 ether);
            vm.expectRevert(IFlashLoanPool.AmountExceedsMaxLoan.selector);
            pool.flashLoan(repayer, address(token), amount, "");
        } else {
            address other = address(uint160(uint256(keccak256(abi.encode(amount, "other")))));
            // Token distinto: UnsupportedToken (balance del pool no cambia).
            amount = bound(amount, 1, bal == 0 ? 1 ether : bal);
            vm.expectRevert(IFlashLoanPool.UnsupportedToken.selector);
            pool.flashLoan(repayer, other, amount, "");
        }

        assertEq(token.balanceOf(address(pool)), poolBefore);
        assertEq(ghostDeposited, deposited);
        assertEq(ghostWithdrawn, withdrawn);
        assertEq(ghostFeesEarned, fees);
    }
}
