// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";
import {IFlashLoanPool} from "./interfaces/IFlashLoanPool.sol";

/**
 * @title FlashLoanPool
 * @notice Pool ERC-3156 de un solo token. Fase 1: esqueleto para tests TDD.
 * @dev Fase 2 implementa `deposit` / `flashLoan` / fee / maxLoan. Los cuerpos revierten a propósito.
 */
contract FlashLoanPool is IERC3156FlashLender, IFlashLoanPool, ReentrancyGuard, Ownable2Step {
    /// @dev Marcador TDD: quitar en fase 2 al implementar la lógica.
    error NotImplemented();

    /// @inheritdoc IFlashLoanPool
    address public immutable override token;

    /// @inheritdoc IFlashLoanPool
    uint256 public immutable override feeBps;

    /**
     * @notice Configura el token prestable y la prima en basis points.
     * @param token_ ERC-20 único soportado.
     * @param feeBps_ Fee (`5` = 0.05%). Denominador 10_000.
     */
    constructor(address token_, uint256 feeBps_) Ownable(msg.sender) {
        if (token_ == address(0)) {
            revert IFlashLoanPool.ZeroAddress();
        }
        token = token_;
        feeBps = feeBps_;
    }

    /// @inheritdoc IERC3156FlashLender
    function maxFlashLoan(address) external view override returns (uint256) {
        revert NotImplemented();
    }

    /// @inheritdoc IERC3156FlashLender
    function flashFee(address, uint256) external view override returns (uint256) {
        revert NotImplemented();
    }

    /// @inheritdoc IERC3156FlashLender
    function flashLoan(IERC3156FlashBorrower, address, uint256, bytes calldata)
        external
        override
        nonReentrant
        returns (bool)
    {
        revert NotImplemented();
    }

    /// @inheritdoc IFlashLoanPool
    function deposit(uint256) external override {
        revert NotImplemented();
    }

    /// @inheritdoc IFlashLoanPool
    function withdraw(uint256) external override onlyOwner {
        revert NotImplemented();
    }
}
