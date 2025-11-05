// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IStrategyRegistry.sol";
import "./interfaces/IStrategyReputation.sol";

/**
 * @title StrategyReputation
 * @notice Feedback and reputation management for service agents
 * @dev Implements EIP-712 signature-based feedback authorization
 */
contract StrategyReputation is EIP712, IStrategyReputation {
    using ECDSA for bytes32;

    /// @notice Reference to the identity registry contract
    IStrategyRegistry public immutable identityRegistry;

    /// @notice EIP-712 type hash for FeedbackAuth struct
    bytes32 private constant FEEDBACK_AUTH_TYPEHASH = keccak256(
        "FeedbackAuth(uint256 agentId,address clientAddress,uint256 indexLimit,uint256 expiry,uint256 chainId)"
    );

    /// @notice Feedback data structure
    struct Feedback {
        address clientAddress;
        uint8 score;
        bytes32 tag1;
        bytes32 tag2;
        string fileuri;
        bytes32 filehash;
        uint40 timestamp;
    }

    /// @notice Reputation aggregation structure
    struct AgentReputation {
        uint64 feedbackCount;
        uint256 totalScore;
    }

    /// @notice Mapping from agentId to array of feedback entries
    mapping(uint256 => Feedback[]) private _feedbacks;

    /// @notice Mapping from agentId => clientAddress => current feedback index
    mapping(uint256 => mapping(address => uint256)) private _clientIndices;

    /// @notice Mapping from agentId to reputation summary
    mapping(uint256 => AgentReputation) private _reputations;

    /**
     * @notice Initialize the contract with identity registry reference
     * @param _identityRegistry Address of the StrategyRegistry contract
     */
    constructor(address _identityRegistry)
        EIP712("StrategyReputation", "1")
    {
        identityRegistry = IStrategyRegistry(_identityRegistry);
    }

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
    ) external {
        // Validate score bounds
        if (score > 100) {
            revert InvalidScore(score);
        }

        // Decode feedbackAuth: abi.encode(struct fields) + 65-byte signature
        // First, extract the encoded struct data (all bytes except last 65)
        uint256 structLength = feedbackAuth.length - 65;
        bytes memory structData = new bytes(structLength);
        for (uint256 i = 0; i < structLength; i++) {
            structData[i] = feedbackAuth[i];
        }

        (uint256 authAgentId, address authClientAddress, uint256 indexLimit, uint256 expiry, uint256 chainId)
            = abi.decode(structData, (uint256, address, uint256, uint256, uint256));

        // Extract 65-byte signature
        bytes memory signature = new bytes(65);
        for (uint256 i = 0; i < 65; i++) {
            signature[i] = feedbackAuth[structLength + i];
        }

        // Verify feedbackAuth parameters match call parameters
        require(authAgentId == agentId, "AgentId mismatch");
        require(authClientAddress == msg.sender, "Client mismatch");

        // Verify expiry
        if (block.timestamp > expiry) {
            revert FeedbackAuthExpired(expiry, block.timestamp);
        }

        // Verify chainId
        if (chainId != block.chainid) {
            revert InvalidChainId();
        }

        // Verify signature from agent owner
        address signer = _verifyFeedbackAuth(agentId, msg.sender, indexLimit, expiry, signature);

        // Get agent owner (reverts if agent doesn't exist)
        // Cast to IERC721 to access ownerOf function
        address agentOwner = IERC721(address(identityRegistry)).ownerOf(agentId);

        // Verify signer is agent owner
        if (signer != agentOwner) {
            revert InvalidSigner(agentOwner, signer);
        }

        // Verify index limit
        uint256 currentIndex = _clientIndices[agentId][msg.sender];
        if (currentIndex >= indexLimit) {
            revert IndexLimitExceeded(agentId, msg.sender, currentIndex, indexLimit);
        }

        // Create feedback struct
        Feedback memory feedback = Feedback({
            clientAddress: msg.sender,
            score: score,
            tag1: tag1,
            tag2: tag2,
            fileuri: fileuri,
            filehash: filehash,
            timestamp: uint40(block.timestamp)
        });

        // Store feedback
        _feedbacks[agentId].push(feedback);

        // Increment client index
        _clientIndices[agentId][msg.sender]++;

        // Update reputation
        _updateReputation(agentId, score);

        // Emit event
        emit NewFeedback(agentId, msg.sender, score, tag1, tag2, fileuri, filehash);
    }

    /**
     * @notice Get aggregated reputation summary for an agent
     * @param agentId Agent identifier
     * @return count Total number of feedback entries
     * @return averageScore Average score across all feedbacks (0-100)
     */
    function getSummary(uint256 agentId) external view returns (uint64 count, uint8 averageScore) {
        AgentReputation memory reputation = _reputations[agentId];
        count = reputation.feedbackCount;
        averageScore = count > 0 ? uint8(reputation.totalScore / count) : 0;
    }

    /**
     * @notice Get current feedback index for a client-agent pair
     * @param agentId Agent identifier
     * @param clientAddress Client address to query
     * @return Current index (starts at 0, increments with each feedback)
     */
    function getClientIndex(uint256 agentId, address clientAddress) external view returns (uint256) {
        return _clientIndices[agentId][clientAddress];
    }

    /**
     * @notice Internal function to verify feedbackAuth signature
     * @param agentId Agent identifier
     * @param clientAddress Client address
     * @param indexLimit Maximum index limit
     * @param expiry Expiry timestamp
     * @param signature 65-byte ECDSA signature
     * @return signer Recovered signer address
     */
    function _verifyFeedbackAuth(
        uint256 agentId,
        address clientAddress,
        uint256 indexLimit,
        uint256 expiry,
        bytes memory signature
    ) internal view returns (address signer) {
        // Compute struct hash
        bytes32 structHash = keccak256(abi.encode(
            FEEDBACK_AUTH_TYPEHASH,
            agentId,
            clientAddress,
            indexLimit,
            expiry,
            block.chainid
        ));

        // Get EIP-712 digest
        bytes32 digest = _hashTypedDataV4(structHash);

        // Recover signer
        signer = ECDSA.recover(digest, signature);
    }

    /**
     * @notice Internal function to update reputation after feedback
     * @param agentId Agent identifier
     * @param score Feedback score to add
     */
    function _updateReputation(uint256 agentId, uint8 score) internal {
        _reputations[agentId].feedbackCount++;
        _reputations[agentId].totalScore += score;
    }

    /**
     * @notice Expose hashTypedDataV4 for testing purposes
     * @param structHash The struct hash to wrap with domain separator
     * @return The EIP-712 digest
     * @dev This function is public to enable test signature generation
     */
    function hashTypedDataV4(bytes32 structHash) public view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}
