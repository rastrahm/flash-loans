// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {AtomicArbitrage} from "../src/AtomicArbitrage.sol";
import {FlashLoanPool} from "../src/FlashLoanPool.sol";
import {MockAMM} from "../src/mocks/MockAMM.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title Deploy
 * @notice Deploy local: tokens mock, pool ERC-3156, AMMs desbalanceados y AtomicArbitrage.
 * @dev `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 */
contract Deploy is Script {
    uint256 internal constant FEE_BPS = 5;
    uint256 internal constant MINT_AMOUNT = 1_000_000 ether;
    uint256 internal constant POOL_LIQUIDITY = 10_000 ether;
    uint256 internal constant BUY_RESERVE_A = 100 ether;
    uint256 internal constant BUY_RESERVE_B = 1_000 ether;
    uint256 internal constant SELL_RESERVE_A = 1_000 ether;
    uint256 internal constant SELL_RESERVE_B = 100 ether;

    /**
     * @notice Despliega el stack demo listo para `execute` rentable en Anvil.
     */
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        MockERC20 tokenA = new MockERC20("Flash Token A", "TKA");
        MockERC20 tokenB = new MockERC20("Flash Token B", "TKB");
        tokenA.mint(deployer, MINT_AMOUNT);
        tokenB.mint(deployer, MINT_AMOUNT);

        FlashLoanPool pool = new FlashLoanPool(address(tokenA), FEE_BPS);
        tokenA.approve(address(pool), POOL_LIQUIDITY);
        pool.deposit(POOL_LIQUIDITY);

        MockAMM ammBuy = new MockAMM(address(tokenA), address(tokenB));
        MockAMM ammSell = new MockAMM(address(tokenA), address(tokenB));

        tokenA.mint(address(ammBuy), BUY_RESERVE_A);
        tokenB.mint(address(ammBuy), BUY_RESERVE_B);
        ammBuy.setReserves(BUY_RESERVE_A, BUY_RESERVE_B);

        tokenA.mint(address(ammSell), SELL_RESERVE_A);
        tokenB.mint(address(ammSell), SELL_RESERVE_B);
        ammSell.setReserves(SELL_RESERVE_A, SELL_RESERVE_B);

        AtomicArbitrage arb = new AtomicArbitrage(address(pool), deployer);

        vm.stopBroadcast();

        console2.log("TokenA", address(tokenA));
        console2.log("TokenB", address(tokenB));
        console2.log("FlashLoanPool", address(pool));
        console2.log("AmmBuy", address(ammBuy));
        console2.log("AmmSell", address(ammSell));
        console2.log("AtomicArbitrage", address(arb));
        console2.log("FeeBps", FEE_BPS);
        console2.log("ProfitOwner", deployer);
    }
}
