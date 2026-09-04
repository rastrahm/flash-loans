// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";
import {IFlashLoanPool} from "./interfaces/IFlashLoanPool.sol";

/**
 * @title FlashLoanPool
 * @notice Pool ERC-3156 de un solo token: liquidez depositable y flash loans con fee en bps.
 * @dev CEI + `nonReentrant` en `flashLoan`. Repay vía `transferFrom`; fallo → `LoanRepaymentFailed`.
 *      Modelo v1: liquidez custodiada; `withdraw` solo `owner` (`Ownable2Step`).
 */
contract FlashLoanPool is IERC3156FlashLender, IFlashLoanPool, ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice Magic value ERC-3156 que debe devolver `onFlashLoan`.
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @notice Denominador de basis points (`feeBps / BPS_DENOMINATOR`).
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @inheritdoc IFlashLoanPool
    address public immutable override token;

    /// @inheritdoc IFlashLoanPool
    uint256 public immutable override feeBps;

    /**
     * @notice Configura el token prestable y la prima en basis points.
     * @param token_ ERC-20 único soportado.
     * @param feeBps_ Fee en bps (`5` = 0.05%). Máximo `BPS_DENOMINATOR` (100%).
     */
    constructor(address token_, uint256 feeBps_) Ownable(msg.sender) {
        if (token_ == address(0)) {
            revert IFlashLoanPool.ZeroAddress();
        }
        if (feeBps_ > BPS_DENOMINATOR) {
            revert IFlashLoanPool.FeeBpsTooHigh();
        }
        token = token_;
        feeBps = feeBps_;
    }

    /**
     * @notice Máximo principal prestable para `token_` en este bloque.
     * @dev Token no soportado → `0` (ERC-3156). Soportado → balance actual del pool.
     * @param token_ ERC-20 solicitado.
     * @return Liquidez disponible.
     */
    function maxFlashLoan(address token_) external view override returns (uint256) {
        if (token_ != token) {
            return 0;
        }
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Prima cobrada por prestar `amount` de `token_`.
     * @param token_ ERC-20 solicitado.
     * @param amount Principal a prestar.
     * @return Fee en unidades del token (`amount * feeBps / 10_000`).
     */
    function flashFee(address token_, uint256 amount) external view override returns (uint256) {
        if (token_ != token) {
            revert IFlashLoanPool.UnsupportedToken();
        }
        return amount * feeBps / BPS_DENOMINATOR;
    }

    /**
     * @notice Prestá `amount` de `token_` a `receiver` y exige repay `amount + fee` al volver del callback.
     * @dev Orden: checks → transfer → `onFlashLoan` → magic value → pull repay → event.
     * @param receiver Contrato `IERC3156FlashBorrower`.
     * @param token_ ERC-20 a prestar (debe ser el token del pool).
     * @param amount Principal.
     * @param data Payload reenviado a `onFlashLoan`.
     * @return `true` si el préstamo y el repay se completaron.
     */
    function flashLoan(IERC3156FlashBorrower receiver, address token_, uint256 amount, bytes calldata data)
        external
        override
        nonReentrant
        returns (bool)
    {
        if (address(receiver) == address(0)) {
            revert IFlashLoanPool.ZeroAddress();
        }
        if (token_ != token) {
            revert IFlashLoanPool.UnsupportedToken();
        }
        if (amount == 0) {
            revert IFlashLoanPool.ZeroAmount();
        }

        IERC20 loanToken = IERC20(token);
        uint256 available = loanToken.balanceOf(address(this));
        if (amount > available) {
            revert IFlashLoanPool.AmountExceedsMaxLoan();
        }

        uint256 fee = amount * feeBps / BPS_DENOMINATOR;

        loanToken.safeTransfer(address(receiver), amount);

        bytes32 rc = receiver.onFlashLoan(msg.sender, token_, amount, fee, data);
        if (rc != CALLBACK_SUCCESS) {
            revert IFlashLoanPool.CallbackFailed();
        }

        _chargeRepayment(loanToken, address(receiver), amount + fee);

        emit FlashLoan(address(receiver), token_, amount, fee);
        return true;
    }

    /**
     * @notice Aporta liquidez del token del pool.
     * @param amount Unidades a depositar (`> 0`).
     */
    function deposit(uint256 amount) external override {
        if (amount == 0) {
            revert IFlashLoanPool.ZeroAmount();
        }
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit LiquidityDeposited(msg.sender, amount);
    }

    /**
     * @notice Retira liquidez ociosa hacia el owner.
     * @dev Solo `owner` (`Ownable2Step`). No reduce préstamos en vuelo: el lock de `flashLoan` serializa.
     * @param amount Unidades a retirar (`> 0`, ≤ balance).
     */
    function withdraw(uint256 amount) external override onlyOwner {
        if (amount == 0) {
            revert IFlashLoanPool.ZeroAmount();
        }
        IERC20(token).safeTransfer(msg.sender, amount);
        emit LiquidityWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Cobra `repayment` del receptor; cualquier fallo de pull → `LoanRepaymentFailed`.
     * @param loanToken ERC-20 prestado.
     * @param from Receptor del flash loan.
     * @param repayment `amount + fee`.
     */
    function _chargeRepayment(IERC20 loanToken, address from, uint256 repayment) private {
        uint256 balanceBefore = loanToken.balanceOf(address(this));
        try loanToken.transferFrom(from, address(this), repayment) returns (bool ok) {
            if (!ok || loanToken.balanceOf(address(this)) < balanceBefore + repayment) {
                revert IFlashLoanPool.LoanRepaymentFailed();
            }
        } catch {
            revert IFlashLoanPool.LoanRepaymentFailed();
        }
    }
}
