// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./interfaces/IStrategyRegistry.sol";

/**
 * @title StrategyRegistry
 * @notice ERC-721 identity registry for service agents
 * @dev Implements agent registration with unique NFT identities
 */
contract StrategyRegistry is ERC721URIStorage, IStrategyRegistry {
    /// @notice Counter for sequential agent ID assignment
    /// @dev Starts at 1, increments for each registration
    uint256 private _nextAgentId;

    /**
     * @notice Initialize the contract with name and symbol
     * @dev Sets _nextAgentId to 1 (agentIds start from 1, not 0)
     */
    constructor() ERC721("Strategy Agent", "STRATEGY-AGENT") {
        _nextAgentId = 1;
    }

    /**
     * @notice Register a new service agent and mint an ERC-721 NFT
     * @param tokenURI_ URI pointing to agent metadata JSON (can be empty)
     * @return agentId The unique identifier for the newly registered agent
     * @dev Mints NFT to msg.sender, emits Registered event
     */
    function register(string memory tokenURI_) external returns (uint256 agentId) {
        // Get current agentId and increment counter
        agentId = _nextAgentId++;

        // Mint NFT to caller
        _safeMint(msg.sender, agentId);

        // Set tokenURI for this agent
        _setTokenURI(agentId, tokenURI_);

        // Emit custom Registered event
        emit Registered(agentId, tokenURI_, msg.sender);

        return agentId;
    }
}
