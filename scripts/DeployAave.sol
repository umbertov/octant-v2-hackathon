// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
// Import your contracts and interfaces
import {
    YieldDonatingAaveV3StrategyFactory
} from "../src/strategies/yieldDonating/YieldDonatingAaveV3StrategyFactory.sol";
import {YieldDonatingTokenizedStrategy} from "@octant-core/strategies/yieldDonating/YieldDonatingTokenizedStrategy.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StrategyAaveDeploymentScript is Script {
    function run() external {
        (
            address management,
            address donationAddress,
            address keeper,
            address emergencyAdmin,
            bool enableBurning,
            address asset,
            address lendingPool
        ) = (
            vm.envAddress("MANAGEMENT_ADDRESS"),
            vm.envAddress("DONATION_ADDRESS"),
            vm.envAddress("KEEPER_ADDRESS"),
            vm.envAddress("EMERGENCY_ADMIN_ADDRESS"),
            vm.envBool("ENABLE_BURNING"),
            vm.envAddress("TEST_ASSET_ADDRESS"),
            vm.envAddress("TEST_AAVE_POOL")
        );
        vm.label(management, "management");
        vm.label(donationAddress, "donationAddress");
        vm.label(keeper, "keeper");
        vm.label(emergencyAdmin, "emergencyAdmin");
        vm.label(asset, "asset");
        vm.label(lendingPool, "lendingPool");

        vm.startBroadcast();

        address tokenizedStrategyAddress = address(new YieldDonatingTokenizedStrategy());
        console2.log("YieldDonatingTokenizedStrategy deployed to:", tokenizedStrategyAddress);

        YieldDonatingAaveV3StrategyFactory strategyFactory =
            new YieldDonatingAaveV3StrategyFactory(management, donationAddress, keeper, emergencyAdmin);
        console2.log("YieldDonatingAaveV3StrategyFactory deployed to:", address(strategyFactory));

        address deployedStrategy = strategyFactory.newStrategy(lendingPool, asset, "Yield Donating Strategy");

        console2.log("Strategy deployed to:", address(deployedStrategy));

        vm.stopBroadcast();

        console2.logAddress(address(deployedStrategy));
    }
}
