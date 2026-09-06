// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {AtomicArbitrage} from "../../src/AtomicArbitrage.sol";
import {FlashLoanPool} from "../../src/FlashLoanPool.sol";
import {IAtomicArbitrage} from "../../src/interfaces/IAtomicArbitrage.sol";
import {IERC3156FlashBorrower} from "../../src/interfaces/IERC3156FlashBorrower.sol";
import {MockAMM} from "../../src/mocks/MockAMM.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title FakeLender
 * @notice Lender falso que intenta disparar `onFlashLoan` del arb.
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
 * @title CallbackSpoofAttackTest
 * @notice Ataques de spoofing del callback ERC-3156: EOA, lender falso, initiator de tercero.
 * @dev Referencia: `doc/SWC-AUDIT.md` · `UntrustedLender` / `InvalidInitiator`.
 */
contract CallbackSpoofAttackTest is Test {
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

        _fundAmm(ammBuy, 100 ether, 1_000 ether);
        _fundAmm(ammSell, 1_000 ether, 100 ether);
    }

    function _fundAmm(MockAMM amm, uint256 reserveA, uint256 reserveB) internal {
        tokenA.mint(address(amm), reserveA);
        tokenB.mint(address(amm), reserveB);
        amm.setReserves(reserveA, reserveB);
    }

    function _params() internal view returns (bytes memory) {
        return abi.encode(address(ammBuy), address(ammSell), address(tokenB), uint256(0));
    }

    /**
     * @notice Ataque: EOA llama `onFlashLoan` directo → `UntrustedLender`; sin movimiento de fondos.
     */
    function test_Attack_callbackFromEOA_revertsUntrustedLender() public {
        uint256 poolBefore = tokenA.balanceOf(address(pool));

        vm.prank(attacker);
        vm.expectRevert(IAtomicArbitrage.UntrustedLender.selector);
        arb.onFlashLoan(address(arb), address(tokenA), LOAN_AMOUNT, 0, _params());

        assertEq(tokenA.balanceOf(address(pool)), poolBefore);
    }

    /**
     * @notice Ataque: lender falso + `initiator == arb` intenta drenar tokens ya en el arb.
     */
    function test_Attack_fakeLender_cannotDrainArbBalance() public {
        tokenA.mint(address(arb), LOAN_AMOUNT);

        uint256 poolBefore = tokenA.balanceOf(address(pool));
        uint256 arbBefore = tokenA.balanceOf(address(arb));
        uint256 ownerBefore = tokenA.balanceOf(profitOwner);
        uint256 buyA = tokenA.balanceOf(address(ammBuy));

        vm.expectRevert(IAtomicArbitrage.UntrustedLender.selector);
        fakeLender.spoofCallback(arb, address(arb), address(tokenA), LOAN_AMOUNT, 0, _params());

        assertEq(tokenA.balanceOf(address(pool)), poolBefore);
        assertEq(tokenA.balanceOf(address(arb)), arbBefore, "arb not drained");
        assertEq(tokenA.balanceOf(profitOwner), ownerBefore);
        assertEq(tokenA.balanceOf(address(ammBuy)), buyA, "no swap executed");
    }

    /**
     * @notice Ataque: tercero inicia `flashLoan(arb, …)` → `InvalidInitiator`; capital intacto.
     */
    function test_Attack_thirdPartyInitiator_revertsInvalidInitiator_capitalIntact() public {
        uint256 poolBefore = tokenA.balanceOf(address(pool));
        uint256 arbBefore = tokenA.balanceOf(address(arb));
        uint256 ownerBefore = tokenA.balanceOf(profitOwner);
        uint256 buyA = tokenA.balanceOf(address(ammBuy));
        uint256 sellA = tokenA.balanceOf(address(ammSell));

        vm.prank(attacker);
        vm.expectRevert(IAtomicArbitrage.InvalidInitiator.selector);
        pool.flashLoan(IERC3156FlashBorrower(address(arb)), address(tokenA), LOAN_AMOUNT, _params());

        assertEq(tokenA.balanceOf(address(pool)), poolBefore);
        assertEq(tokenA.balanceOf(address(arb)), arbBefore);
        assertEq(tokenA.balanceOf(profitOwner), ownerBefore);
        assertEq(tokenA.balanceOf(address(ammBuy)), buyA);
        assertEq(tokenA.balanceOf(address(ammSell)), sellA);
    }

    /**
     * @notice Auth: `UntrustedLender` se evalúa antes que `InvalidInitiator`.
     */
    function test_Attack_untrustedLenderCheckedBeforeInitiator() public {
        vm.prank(attacker);
        vm.expectRevert(IAtomicArbitrage.UntrustedLender.selector);
        arb.onFlashLoan(attacker, address(tokenA), LOAN_AMOUNT, 0, _params());
    }
}
