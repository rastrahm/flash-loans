// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IERC3156FlashBorrower} from "../../src/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../../src/interfaces/IERC3156FlashLender.sol";

bytes32 constant ERC3156_CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

/**
 * @title RepayingBorrower
 * @notice Aprueba `amount + fee` al lender y devuelve el magic value ERC-3156.
 */
contract RepayingBorrower is IERC3156FlashBorrower {
    /**
     * @inheritdoc IERC3156FlashBorrower
     */
    function onFlashLoan(address, address token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {
        IERC20(token).approve(msg.sender, amount + fee);
        return ERC3156_CALLBACK_SUCCESS;
    }
}

/**
 * @title NonRepayingBorrower
 * @notice Devuelve éxito sin aprobar el repay (el pull del lender debe fallar).
 */
contract NonRepayingBorrower is IERC3156FlashBorrower {
    /**
     * @inheritdoc IERC3156FlashBorrower
     */
    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external pure returns (bytes32) {
        return ERC3156_CALLBACK_SUCCESS;
    }
}

/**
 * @title BadCallbackBorrower
 * @notice Devuelve un magic value distinto al de ERC-3156.
 */
contract BadCallbackBorrower is IERC3156FlashBorrower {
    /**
     * @inheritdoc IERC3156FlashBorrower
     */
    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/**
 * @title ReenteringBorrower
 * @notice Reentra `flashLoan` durante el callback.
 */
contract ReenteringBorrower is IERC3156FlashBorrower {
    IERC3156FlashLender public lender;

    /**
     * @notice Fija el lender contra el que reentrar.
     * @param lender_ Pool ERC-3156.
     */
    function setLender(IERC3156FlashLender lender_) external {
        lender = lender_;
    }

    /**
     * @inheritdoc IERC3156FlashBorrower
     */
    function onFlashLoan(address, address token, uint256 amount, uint256, bytes calldata data)
        external
        returns (bytes32)
    {
        lender.flashLoan(this, token, amount, data);
        return ERC3156_CALLBACK_SUCCESS;
    }
}
