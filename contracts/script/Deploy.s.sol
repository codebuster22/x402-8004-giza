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
        // Note: Private key should be provided via --private-key flag or PRIVATE_KEY env var
        vm.startBroadcast();

        console.log("Deploying StrategyRegistry...");
        StrategyRegistry registry = new StrategyRegistry();
        console.log("StrategyRegistry deployed at:", address(registry));

        console.log("\nDeploying StrategyReputation...");
        StrategyReputation reputation = new StrategyReputation(address(registry));
        console.log("StrategyReputation deployed at:", address(reputation));

        // Verify deployment
        console.log("\n=== Deployment Summary ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer Address:", msg.sender);
        console.log("StrategyRegistry:", address(registry));
        console.log("StrategyReputation:", address(reputation));
        console.log("\nRegistry Name:", registry.name());
        console.log("Registry Symbol:", registry.symbol());
        console.log("Reputation identityRegistry:", address(reputation.identityRegistry()));

        vm.stopBroadcast();

        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on BaseScan (if --verify was used)");
        console.log("2. Save deployment addresses to deployment log");
        console.log("3. Extract ABIs for frontend integration");
    }
}
