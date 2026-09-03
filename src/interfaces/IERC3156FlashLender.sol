// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";

/**
 * @title IERC3156FlashLender
 * @notice Proveedor de flash loans ERC-3156.
 */
interface IERC3156FlashLender {
    /**
     * @notice Máximo principal prestable para `token` en este bloque.
     * @param token ERC-20 solicitado.
     * @return Liquidez disponible; `0` si el token no está soportado.
     */
    function maxFlashLoan(address token) external view returns (uint256);

    /**
     * @notice Prima cobrada por prestar `amount` de `token`.
     * @param token ERC-20 solicitado.
     * @param amount Principal a prestar.
     * @return Fee en unidades del token.
     */
    function flashFee(address token, uint256 amount) external view returns (uint256);

    /**
     * @notice Prestá `amount` de `token` a `receiver` y exige repay `amount + fee` al volver del callback.
     * @param receiver Contrato que implementa `IERC3156FlashBorrower`.
     * @param token ERC-20 a prestar.
     * @param amount Principal.
     * @param data Payload reenviado a `onFlashLoan`.
     * @return `true` si el préstamo se completó (repay incluido).
     */
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool);
}
