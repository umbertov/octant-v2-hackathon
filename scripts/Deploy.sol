// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
// Import your contracts and interfaces
import {YieldDonatingStrategyFactory} from "../src/strategies/yieldDonating/YieldDonatingStrategyFactory.sol";
import {YieldDonatingTokenizedStrategy} from "@octant-core/strategies/yieldDonating/YieldDonatingTokenizedStrategy.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StrategyDeploymentScript is Script {
    function run() external {
        (
            address management,
            address donationAddress,
            address keeper,
            address emergencyAdmin,
            bool enableBurning,
            address asset,
            address yieldSource
        ) = (
            vm.envAddress("MANAGEMENT_ADDRESS"),
            vm.envAddress("DONATION_ADDRESS"),
            vm.envAddress("KEEPER_ADDRESS"),
            vm.envAddress("EMERGENCY_ADMIN_ADDRESS"),
            vm.envBool("ENABLE_BURNING"),
            vm.envAddress("TEST_ASSET_ADDRESS"),
            vm.envAddress("TEST_YIELD_SOURCE")
        );
        vm.label(management, "management");
        vm.label(donationAddress, "donationAddress");
        vm.label(keeper, "keeper");
        vm.label(emergencyAdmin, "emergencyAdmin");
        vm.label(asset, "asset");
        vm.label(yieldSource, "yieldSource");

        vm.startBroadcast();

        address tokenizedStrategyAddress = address(new YieldDonatingTokenizedStrategy());
        console2.log("YieldDonatingTokenizedStrategy deployed to:", tokenizedStrategyAddress);

        YieldDonatingStrategyFactory strategyFactory =
            new YieldDonatingStrategyFactory(management, donationAddress, keeper, emergencyAdmin);
        console2.log("YieldDonatingStrategyFactory deployed to:", address(strategyFactory));

        address deployedStrategy = strategyFactory.newStrategy(yieldSource, asset, "Yield Donating Strategy");

        console2.log("Strategy deployed to:", address(deployedStrategy));

        vm.stopBroadcast();

        console2.logAddress(address(deployedStrategy));
    }
}
