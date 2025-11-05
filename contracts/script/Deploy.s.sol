// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/StrategyRegistry.sol";
import "../src/StrategyReputation.sol";

/**
 * @title Deploy
 * @notice Deployment script for StrategyRegistry and StrategyReputation contracts
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url <RPC_URL> --broadcast --verify
 */
contract Deploy is Script {
    function run() external {
        // Start broadcasting transactions
        // Uses default foundry test account if PRIVATE_KEY not set
        vm.startBroadcast();

        // Deploy StrategyRegistry
        console.log("Deploying StrategyRegistry...");
        StrategyRegistry registry = new StrategyRegistry();
        console.log("StrategyRegistry deployed at:", address(registry));

        // Deploy StrategyReputation with registry address
        console.log("\nDeploying StrategyReputation...");
        StrategyReputation reputation = new StrategyReputation(address(registry));
        console.log("StrategyReputation deployed at:", address(reputation));

        // Stop broadcasting
        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("StrategyRegistry:", address(registry));
        console.log("StrategyReputation:", address(reputation));
        console.log("==========================");

        // Verify contracts are properly initialized
        console.log("\n=== VERIFICATION ===");
        console.log("Registry name:", registry.name());
        console.log("Registry symbol:", registry.symbol());
        console.log("Reputation identityRegistry:", address(reputation.identityRegistry()));
        console.log("Reputation points to Registry:", address(reputation.identityRegistry()) == address(registry));
        console.log("====================");
    }
}
