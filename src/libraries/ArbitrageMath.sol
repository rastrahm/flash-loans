// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ArbitrageMath
 * @notice Cálculos puros de deuda y umbral de profit (sin storage).
 */
library ArbitrageMath {
    /**
     * @notice Suma principal y prima del flash loan.
     * @param amount Principal ERC-3156.
     * @param fee Prima `flashFee`.
     * @return Deuda total a devolver al lender.
     */
    function repayAmount(uint256 amount, uint256 fee) internal pure returns (uint256) {
        return amount + fee;
    }

    /**
     * @notice Comprueba si el balance post-swap cubre deuda y profit mínimo.
     * @param balance Balance del token prestado en el borrower.
     * @param required `amount + fee`.
     * @param minProfit Beneficio mínimo exigido (wei del token).
     * @return `true` si `balance - required >= minProfit`.
     */
    function isProfitable(uint256 balance, uint256 required, uint256 minProfit) internal pure returns (bool) {
        if (balance < required) {
            return false;
        }
        return balance - required >= minProfit;
    }
}
