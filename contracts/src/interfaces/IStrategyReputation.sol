// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./IStrategyRegistry.sol";

/**
 * @title IStrategyReputation
 * @notice Interface for the StrategyReputation feedback and reputation contract
 * @dev Implements EIP-712 signature-based feedback authorization
 */
interface IStrategyReputation {
    /**
     * @notice Emitted when new feedback is submitted for an agent
     * @param agentId The agent receiving feedback
     * @param clientAddress The client submitting feedback
     * @param score The rating (0-100)
     * @param tag1 Primary tag (indexed for filtering)
     * @param tag2 Secondary tag
     * @param fileuri URI to detailed feedback file
     * @param filehash Hash of feedback file content
     */
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint8 score,
        bytes32 indexed tag1,
        bytes32 tag2,
        string fileuri,
        bytes32 filehash
    );

    /**
     * @notice Agent not found in identity registry
     * @param agentId The invalid agent identifier
     */
    error AgentNotFound(uint256 agentId);

    /**
     * @notice Score value is invalid (must be <= 100)
     * @param score The invalid score value
     */
    error InvalidScore(uint8 score);

    /**
     * @notice Client has exceeded their feedback index limit
     * @param agentId The agent identifier
     * @param client The client address
     * @param currentIndex The client's current feedback index
     * @param indexLimit The authorized limit from feedbackAuth
     */
    error IndexLimitExceeded(
        uint256 agentId,
        address client,
        uint256 currentIndex,
        uint256 indexLimit
    );

    /**
     * @notice FeedbackAuth signature has expired
     * @param expiry The expiry timestamp from feedbackAuth
     * @param currentTimestamp The current block timestamp
     */
    error FeedbackAuthExpired(uint256 expiry, uint256 currentTimestamp);

    /**
     * @notice Recovered signer does not match expected agent owner
     * @param expectedSigner The expected signer (agent owner)
     * @param actualSigner The recovered signer from signature
     */
    error InvalidSigner(address expectedSigner, address actualSigner);

    /**
     * @notice Chain ID mismatch in feedbackAuth
     */
    error InvalidChainId();

    /**
     * @notice Submit feedback for a service agent
     * @param agentId Agent identifier
     * @param score Rating from 0-100
     * @param tag1 Primary tag (UTF-8 encoded bytes32)
     * @param tag2 Secondary tag (UTF-8 encoded bytes32)
     * @param fileuri Optional URI to detailed feedback file
     * @param filehash Optional hash of feedback file content
     * @param feedbackAuth EIP-712 signature authorizing this feedback
     */
    function giveFeedback(
        uint256 agentId,
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        string memory fileuri,
        bytes32 filehash,
        bytes memory feedbackAuth
    ) external;

    /**
     * @notice Get aggregated reputation summary for an agent
     * @param agentId Agent identifier
     * @return count Total number of feedback entries
     * @return averageScore Average score across all feedbacks (0-100)
     */
    function getSummary(uint256 agentId) external view returns (uint64 count, uint8 averageScore);

    /**
     * @notice Get current feedback index for a client-agent pair
     * @param agentId Agent identifier
     * @param clientAddress Client address to query
     * @return Current index (starts at 0, increments with each feedback)
     */
    function getClientIndex(uint256 agentId, address clientAddress) external view returns (uint256);

    /**
     * @notice Get the identity registry contract reference
     * @return The StrategyRegistry contract
     */
    function identityRegistry() external view returns (IStrategyRegistry);
}
