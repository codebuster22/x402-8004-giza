// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IStrategyRegistry
 * @notice Interface for the StrategyRegistry identity registry contract
 * @dev Extends ERC-721 standard with agent registration functionality
 */
interface IStrategyRegistry {
    /**
     * @notice Emitted when a new agent is registered
     * @param agentId The unique identifier for the registered agent
     * @param tokenURI The metadata URI for the agent
     * @param owner The address that owns the agent NFT
     */
    event Registered(
        uint256 indexed agentId,
        string tokenURI,
        address indexed owner
    );

    /**
     * @notice Register a new service agent and mint an ERC-721 NFT
     * @param tokenURI_ URI pointing to agent metadata JSON (can be empty)
     * @return agentId The unique identifier for the newly registered agent
     */
    function register(string memory tokenURI_) external returns (uint256 agentId);

    // Note: ownerOf() and tokenURI() are provided by ERC-721 standard
    // They are not redeclared here to avoid inheritance conflicts
}
