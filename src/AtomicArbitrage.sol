// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ArbitrageMath} from "./libraries/ArbitrageMath.sol";
import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";
import {IAtomicArbitrage} from "./interfaces/IAtomicArbitrage.sol";
import {IFlashLoanPool} from "./interfaces/IFlashLoanPool.sol";
import {ISimpleAMM} from "./interfaces/ISimpleAMM.sol";

/**
 * @title AtomicArbitrage
 * @notice Ejecutor ERC-3156: flash loan → swap en dos AMMs → repay + profit al owner.
 * @dev Auth estricta en `onFlashLoan` (`UntrustedLender` / `InvalidInitiator`).
 *      Profit sin SSTORE: transfer directo a `owner` immutable.
 *      `params` ABI: `(address ammBuy, address ammSell, address tokenB, uint256 minProfit)`.
 */
contract AtomicArbitrage is IERC3156FlashBorrower, IAtomicArbitrage {
    using SafeERC20 for IERC20;

    /// @notice Magic value ERC-3156.
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @inheritdoc IAtomicArbitrage
    address public immutable override flashLender;

    /// @inheritdoc IAtomicArbitrage
    address public immutable override owner;

    /**
     * @notice Fija lender de confianza y destinatario de beneficios.
     * @param flashLender_ Pool ERC-3156 (`IFlashLoanPool` + `IERC3156FlashLender`).
     * @param owner_ Receptor del profit (immutable; cero writes de acumulado).
     */
    constructor(address flashLender_, address owner_) {
        if (flashLender_ == address(0) || owner_ == address(0)) {
            revert IAtomicArbitrage.ZeroAddress();
        }
        flashLender = flashLender_;
        owner = owner_;
    }

    /**
     * @notice Inicia un flash loan hacia este contrato y ejecuta el arbitraje en el callback.
     * @dev Cualquiera puede llamar; el profit siempre va a `owner`.
     * @param amount Principal a pedir prestado (`> 0`).
     * @param params ABI-encoded: `ammBuy`, `ammSell`, `tokenB`, `minProfit`.
     */
    function execute(uint256 amount, bytes calldata params) external override {
        if (amount == 0) {
            revert IAtomicArbitrage.ZeroAmount();
        }
        address loanToken = IFlashLoanPool(flashLender).token();
        IERC3156FlashLender(flashLender).flashLoan(this, loanToken, amount, params);
    }

    /**
     * @notice Callback ERC-3156: autentica, hace round-trip de swaps, paga profit y aprueba el repay.
     * @param initiator Quien llamó `flashLoan` en el lender (debe ser `address(this)`).
     * @param token ERC-20 prestado.
     * @param amount Principal recibido.
     * @param fee Prima a devolver junto con el principal.
     * @param data Mismos `params` de `execute`.
     * @return Magic value `CALLBACK_SUCCESS` si el camino es rentable.
     */
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        override
        returns (bytes32)
    {
        if (msg.sender != flashLender) {
            revert IAtomicArbitrage.UntrustedLender();
        }
        if (initiator != address(this)) {
            revert IAtomicArbitrage.InvalidInitiator();
        }

        (address ammBuy, address ammSell, address tokenB, uint256 minProfit) =
            abi.decode(data, (address, address, address, uint256));

        _swapRoundTrip(token, amount, ammBuy, ammSell, tokenB);

        uint256 required = ArbitrageMath.repayAmount(amount, fee);
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (!ArbitrageMath.isProfitable(bal, required, minProfit)) {
            revert IAtomicArbitrage.UnprofitableArbitrage();
        }

        uint256 profit = bal - required;
        if (profit > 0) {
            IERC20(token).safeTransfer(owner, profit);
        }

        IERC20(token).forceApprove(flashLender, required);

        emit ArbitrageExecuted(token, amount, profit);
        return CALLBACK_SUCCESS;
    }

    /**
     * @dev Round-trip: `token` → `tokenB` en `ammBuy`, luego `tokenB` → `token` en `ammSell`.
     * @param token Token prestado (input del primer swap).
     * @param amount Principal del flash loan.
     * @param ammBuy AMM donde se compra el intermediario.
     * @param ammSell AMM donde se vende el intermediario.
     * @param tokenB Token intermediario.
     */
    function _swapRoundTrip(address token, uint256 amount, address ammBuy, address ammSell, address tokenB) private {
        IERC20 loanToken = IERC20(token);
        loanToken.forceApprove(ammBuy, amount);
        ISimpleAMM(ammBuy).swap(token, amount, 0, address(this));

        uint256 mid = IERC20(tokenB).balanceOf(address(this));
        IERC20(tokenB).forceApprove(ammSell, mid);
        ISimpleAMM(ammSell).swap(tokenB, mid, 0, address(this));
    }
}
