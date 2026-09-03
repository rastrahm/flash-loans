// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IERC3156FlashBorrower
 * @notice Receptor de un flash loan ERC-3156.
 * @dev El valor de retorno debe ser `keccak256("ERC3156FlashBorrower.onFlashLoan")`.
 */
interface IERC3156FlashBorrower {
    /**
     * @notice Recibe tokens prestados y debe dejar aprobado el repay (`amount + fee`) al lender.
     * @param initiator Dirección que llamó a `flashLoan` en el lender.
     * @param token ERC-20 prestado.
     * @param amount Principal transferido al receptor.
     * @param fee Prima a devolver junto con el principal.
     * @param data Payload opaco pasado desde `flashLoan`.
     * @return Magic value ERC-3156 si el callback tuvo éxito.
     */
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32);
}
