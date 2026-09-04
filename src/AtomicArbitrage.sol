// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IAtomicArbitrage} from "./interfaces/IAtomicArbitrage.sol";

/**
 * @title AtomicArbitrage
 * @notice Ejecutor ERC-3156 de arbitraje atómico entre dos AMMs. Fase 3: esqueleto TDD.
 * @dev Fase 4 implementa `execute` / `onFlashLoan` (auth, swaps, repay, profit a owner).
 */
contract AtomicArbitrage is IERC3156FlashBorrower, IAtomicArbitrage {
    /// @dev Marcador TDD: quitar en fase 4 al implementar la lógica.
    error NotImplemented();

    /// @inheritdoc IAtomicArbitrage
    address public immutable override flashLender;

    /// @inheritdoc IAtomicArbitrage
    address public immutable override owner;

    /**
     * @notice Fija lender de confianza y destinatario de beneficios.
     * @param flashLender_ Pool ERC-3156.
     * @param owner_ Receptor del profit (sin SSTORE de acumulado).
     */
    constructor(address flashLender_, address owner_) {
        if (flashLender_ == address(0) || owner_ == address(0)) {
            revert IAtomicArbitrage.ZeroAddress();
        }
        flashLender = flashLender_;
        owner = owner_;
    }

    /// @inheritdoc IAtomicArbitrage
    function execute(uint256, bytes calldata) external override {
        revert NotImplemented();
    }

    /// @inheritdoc IERC3156FlashBorrower
    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external pure override returns (bytes32) {
        revert NotImplemented();
    }
}
