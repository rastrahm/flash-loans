// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ISimpleAMM
 * @notice Superficie mínima de swap para mocks (y futura adaptación a pares del módulo 06).
 */
interface ISimpleAMM {
    /**
     * @notice Primer token del par.
     * @return Dirección de `token0`.
     */
    function token0() external view returns (address);

    /**
     * @notice Segundo token del par.
     * @return Dirección de `token1`.
     */
    function token1() external view returns (address);

    /**
     * @notice Estima el output de un swap exact-in.
     * @param amountIn Unidades de `tokenIn`.
     * @param tokenIn Token que se vende al pool.
     * @return amountOut Unidades del otro token.
     */
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256 amountOut);

    /**
     * @notice Ejecuta un swap exact-in.
     * @param tokenIn Token que el caller transfiere al AMM.
     * @param amountIn Unidades de input.
     * @param minOut Slippage mínimo de output.
     * @param to Receptor del token de salida.
     * @return amountOut Unidades transferidas a `to`.
     */
    function swap(address tokenIn, uint256 amountIn, uint256 minOut, address to) external returns (uint256 amountOut);
}
