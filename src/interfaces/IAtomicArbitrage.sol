// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IAtomicArbitrage
 * @notice Ejecutor de arbitraje financiado con flash loan ERC-3156.
 * @dev Selectores de errores/eventos para tests Foundry (`vm.expectRevert` / `vm.expectEmit`).
 */
interface IAtomicArbitrage {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice `initiator` del callback no es este contrato.
    error InvalidInitiator();

    /// @notice `msg.sender` del callback no es el lender configurado.
    error UntrustedLender();

    /// @notice El round-trip no cubre `amount + fee` (o el profit es menor a `minProfit`).
    error UnprofitableArbitrage();

    /// @notice No se pudo dejar el repay listo para el lender.
    error LoanRepaymentFailed();

    /// @notice Dirección cero no permitida.
    error ZeroAddress();

    /// @notice Principal del execute es cero.
    error ZeroAmount();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /**
     * @notice Arbitraje atómico cerrado con beneficio transferido al owner.
     * @param token ERC-20 prestado.
     * @param amount Principal del flash loan.
     * @param profit Unidades netas enviadas al owner (sin SSTORE de acumulado).
     */
    event ArbitrageExecuted(address indexed token, uint256 amount, uint256 profit);

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice Lender ERC-3156 de confianza.
     * @return Dirección del `FlashLoanPool`.
     */
    function flashLender() external view returns (address);

    /**
     * @notice Destinatario de beneficios (immutable).
     * @return Address que recibe el profit en el callback.
     */
    function owner() external view returns (address);

    // -------------------------------------------------------------------------
    // Mutating
    // -------------------------------------------------------------------------

    /**
     * @notice Inicia `flashLoan` hacia este contrato.
     * @param amount Principal a pedir prestado.
     * @param params ABI: `ammBuy`, `ammSell`, `tokenB`, `minProfit`.
     */
    function execute(uint256 amount, bytes calldata params) external;
}
