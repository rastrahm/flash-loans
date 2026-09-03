// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IFlashLoanPool
 * @notice Superficie propia del pool de liquidez prestable (además de ERC-3156).
 * @dev Selectores de errores/eventos para tests Foundry (`vm.expectRevert` / `vm.expectEmit`).
 */
interface IFlashLoanPool {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice `token` no es el ERC-20 configurado en el pool.
    error UnsupportedToken();

    /// @notice `amount` supera `maxFlashLoan`.
    error AmountExceedsMaxLoan();

    /// @notice El callback no devolvió el magic value ERC-3156.
    error CallbackFailed();

    /// @notice Principal o depósito/retiro es cero.
    error ZeroAmount();

    /// @notice El pull de `amount + fee` desde el receptor falló.
    error LoanRepaymentFailed();

    /// @notice Dirección cero no permitida.
    error ZeroAddress();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /**
     * @notice Flash loan completado (callback + repay).
     * @param receiver Receptor ERC-3156.
     * @param token ERC-20 prestado.
     * @param amount Principal.
     * @param fee Prima cobrada.
     */
    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee);

    /**
     * @notice Liquidez aportada al pool.
     * @param provider Quien depositó.
     * @param amount Unidades del token del pool.
     */
    event LiquidityDeposited(address indexed provider, uint256 amount);

    /**
     * @notice Liquidez retirada del pool.
     * @param provider Quien retiró.
     * @param amount Unidades transferidas.
     */
    event LiquidityWithdrawn(address indexed provider, uint256 amount);

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice ERC-20 único prestable en v1.
     * @return Dirección del token.
     */
    function token() external view returns (address);

    /**
     * @notice Fee del flash loan en basis points.
     * @return `feeBps` (p.ej. `5` = 0.05%).
     */
    function feeBps() external view returns (uint256);

    // -------------------------------------------------------------------------
    // Mutating
    // -------------------------------------------------------------------------

    /**
     * @notice Transfiere `amount` del token del pool hacia el contrato.
     * @param amount Unidades a depositar.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Retira `amount` de liquidez ociosa (admin v1).
     * @param amount Unidades a retirar.
     */
    function withdraw(uint256 amount) external;
}
