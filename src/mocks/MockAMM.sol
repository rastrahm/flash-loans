// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISimpleAMM} from "../interfaces/ISimpleAMM.sol";

/**
 * @title MockAMM
 * @notice AMM simplificado `x * y = k` con fee 0.3% para tests de arbitraje.
 * @dev Reservas seteables; tokenizar liquidez vía mint externo a este contrato.
 */
contract MockAMM is ISimpleAMM {
    using SafeERC20 for IERC20;

    /// @notice `tokenIn` no es `token0` ni `token1`.
    error InvalidToken();

    /// @notice Output menor a `minOut`.
    error SlippageExceeded();

    /// @notice Input o liquidez insuficiente.
    error InsufficientLiquidity();

    /// @inheritdoc ISimpleAMM
    address public immutable override token0;

    /// @inheritdoc ISimpleAMM
    address public immutable override token1;

    /// @notice Reserva contabilizada de `token0`.
    uint256 public reserve0;

    /// @notice Reserva contabilizada de `token1`.
    uint256 public reserve1;

    /**
     * @notice Fija el par de tokens del mock.
     * @param token0_ Primer token del par.
     * @param token1_ Segundo token del par.
     */
    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    /**
     * @notice Sobrescribe reservas (tests: alinear con balances mintados al AMM).
     * @param reserve0_ Nueva reserva de `token0`.
     * @param reserve1_ Nueva reserva de `token1`.
     */
    function setReserves(uint256 reserve0_, uint256 reserve1_) external {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
    }

    /// @inheritdoc ISimpleAMM
    function getAmountOut(uint256 amountIn, address tokenIn) external view override returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = _reservesFor(tokenIn);
        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /// @inheritdoc ISimpleAMM
    function swap(address tokenIn, uint256 amountIn, uint256 minOut, address to)
        external
        override
        returns (uint256 amountOut)
    {
        if (amountIn == 0) {
            revert InsufficientLiquidity();
        }

        (uint256 reserveIn, uint256 reserveOut) = _reservesFor(tokenIn);
        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut == 0 || amountOut > reserveOut) {
            revert InsufficientLiquidity();
        }
        if (amountOut < minOut) {
            revert SlippageExceeded();
        }

        address tokenOut = tokenIn == token0 ? token1 : token0;

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(to, amountOut);

        if (tokenIn == token0) {
            reserve0 = reserveIn + amountIn;
            reserve1 = reserveOut - amountOut;
        } else {
            reserve1 = reserveIn + amountIn;
            reserve0 = reserveOut - amountOut;
        }
    }

    /**
     * @notice Fórmula Uniswap V2: `amountIn * 997 * reserveOut / (reserveIn * 1000 + amountIn * 997)`.
     */
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        private
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) {
            return 0;
        }
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    /**
     * @notice Resuelve (reserveIn, reserveOut) para `tokenIn`.
     */
    function _reservesFor(address tokenIn) private view returns (uint256 reserveIn, uint256 reserveOut) {
        if (tokenIn == token0) {
            return (reserve0, reserve1);
        }
        if (tokenIn == token1) {
            return (reserve1, reserve0);
        }
        revert InvalidToken();
    }
}
