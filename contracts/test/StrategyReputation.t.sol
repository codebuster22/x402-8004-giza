// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/StrategyRegistry.sol";
import "../src/StrategyReputation.sol";

contract StrategyReputationTest is Test {
    StrategyRegistry public registry;
    StrategyReputation public reputation;

    // Test accounts with known private keys
    address public agent;
    uint256 public agentPrivateKey;

    address public client1;
    uint256 public client1PrivateKey;

    address public client2;
    uint256 public client2PrivateKey;

    address public stranger;
    uint256 public strangerPrivateKey;

    uint256 public agentId;

    // EIP-712 domain separator components
    bytes32 private constant FEEDBACK_AUTH_TYPEHASH = keccak256(
        "FeedbackAuth(uint256 agentId,address clientAddress,uint256 indexLimit,uint256 expiry,uint256 chainId)"
    );

    // Events to test
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint8 score,
        bytes32 indexed tag1,
        bytes32 tag2,
        string fileuri,
        bytes32 filehash
    );

    function setUp() public {
        // Create test accounts with private keys
        agentPrivateKey = 0xA11CE;
        agent = vm.addr(agentPrivateKey);

        client1PrivateKey = 0xB0B;
        client1 = vm.addr(client1PrivateKey);

        client2PrivateKey = 0xC0C;
        client2 = vm.addr(client2PrivateKey);

        strangerPrivateKey = 0xBAD;
        stranger = vm.addr(strangerPrivateKey);

        // Deploy contracts
        registry = new StrategyRegistry();
        reputation = new StrategyReputation(address(registry));

        // Register an agent
        vm.prank(agent);
        agentId = registry.register("ipfs://test-agent");
    }

    /**
     * Helper function to generate valid feedbackAuth
     * @param _agentId Agent identifier
     * @param _clientAddress Client address to authorize
     * @param _indexLimit Maximum feedback index for this authorization
     * @param _expiry Expiry timestamp
     * @param _signerPrivateKey Private key to sign with (typically agent's key)
     * @return feedbackAuth Encoded authorization bytes
     */
    function _generateFeedbackAuth(
        uint256 _agentId,
        address _clientAddress,
        uint256 _indexLimit,
        uint256 _expiry,
        uint256 _signerPrivateKey
    ) internal returns (bytes memory feedbackAuth) {
        // Compute EIP-712 struct hash
        bytes32 structHash = keccak256(abi.encode(
            FEEDBACK_AUTH_TYPEHASH,
            _agentId,
            _clientAddress,
            _indexLimit,
            _expiry,
            block.chainid
        ));

        // Compute EIP-712 digest
        bytes32 digest = reputation.hashTypedDataV4(structHash);

        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

        // Encode signature (65 bytes: r + s + v)
        bytes memory signature = abi.encodePacked(r, s, v);

        // Encode feedbackAuth: struct fields + signature
        feedbackAuth = abi.encodePacked(
            abi.encode(_agentId, _clientAddress, _indexLimit, _expiry, block.chainid),
            signature
        );
    }

    /**
     * T061: Test that giveFeedback stores feedback correctly
     */
    function test_GiveFeedback_StoresFeedback() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId,
            client1,
            5, // indexLimit
            expiry,
            agentPrivateKey
        );

        vm.prank(client1);
        reputation.giveFeedback(
            agentId,
            85, // score
            bytes32("quality"), // tag1
            bytes32("responsive"), // tag2
            "ipfs://feedback-file",
            keccak256("feedback content"),
            auth
        );

        // Verify client index incremented
        assertEq(reputation.getClientIndex(agentId, client1), 1);

        // Verify reputation updated
        (uint64 count, uint8 avgScore) = reputation.getSummary(agentId);
        assertEq(count, 1);
        assertEq(avgScore, 85);
    }

    /**
     * T062: Test that client index increments correctly
     */
    function test_GiveFeedback_IncrementsClientIndex() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId,
            client1,
            3, // Allow 3 feedbacks
            expiry,
            agentPrivateKey
        );

        // Initial index should be 0
        assertEq(reputation.getClientIndex(agentId, client1), 0);

        // First feedback
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 80, bytes32("good"), bytes32("fast"),
            "", bytes32(0), auth
        );
        assertEq(reputation.getClientIndex(agentId, client1), 1);

        // Second feedback
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 90, bytes32("great"), bytes32("helpful"),
            "", bytes32(0), auth
        );
        assertEq(reputation.getClientIndex(agentId, client1), 2);

        // Third feedback
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 95, bytes32("excellent"), bytes32("reliable"),
            "", bytes32(0), auth
        );
        assertEq(reputation.getClientIndex(agentId, client1), 3);
    }

    /**
     * T063: Test that NewFeedback event is emitted correctly
     */
    function test_GiveFeedback_EmitsNewFeedbackEvent() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes32 tag1 = bytes32("professional");
        bytes32 tag2 = bytes32("efficient");
        string memory fileuri = "ipfs://detailed-feedback";
        bytes32 filehash = keccak256("feedback content hash");

        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit NewFeedback(agentId, client1, 88, tag1, tag2, fileuri, filehash);

        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 88, tag1, tag2, fileuri, filehash, auth
        );
    }

    /**
     * T064: Test that score > 100 is rejected
     */
    function test_GiveFeedback_RevertsInvalidScore() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSelector(
            IStrategyReputation.InvalidScore.selector,
            101
        ));
        reputation.giveFeedback(
            agentId, 101, bytes32(0), bytes32(0), "", bytes32(0), auth
        );
    }

    /**
     * T065: Test that nonexistent agent is rejected
     */
    function test_GiveFeedback_RevertsNonexistentAgent() public {
        uint256 fakeAgentId = 999;
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            fakeAgentId, client1, 5, expiry, agentPrivateKey
        );

        vm.prank(client1);
        vm.expectRevert(); // ownerOf will revert for nonexistent token
        reputation.giveFeedback(
            fakeAgentId, 80, bytes32(0), bytes32(0), "", bytes32(0), auth
        );
    }

    /**
     * T066: Test that expired signature is rejected
     */
    function test_GiveFeedback_RevertsExpiredSignature() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );

        // Warp time past expiry
        vm.warp(expiry + 1);

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSelector(
            IStrategyReputation.FeedbackAuthExpired.selector,
            expiry,
            expiry + 1
        ));
        reputation.giveFeedback(
            agentId, 80, bytes32(0), bytes32(0), "", bytes32(0), auth
        );
    }

    /**
     * T067: Test that signature from non-owner is rejected
     */
    function test_GiveFeedback_RevertsInvalidSigner() public {
        uint256 expiry = block.timestamp + 1 hours;
        // Sign with stranger's key instead of agent's key
        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 5, expiry, strangerPrivateKey
        );

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSelector(
            IStrategyReputation.InvalidSigner.selector,
            agent, // expected
            stranger // actual
        ));
        reputation.giveFeedback(
            agentId, 80, bytes32(0), bytes32(0), "", bytes32(0), auth
        );
    }

    /**
     * T068: Test that index limit is enforced
     */
    function test_GiveFeedback_RevertsIndexLimitExceeded() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 2, expiry, agentPrivateKey // Only allow 2 feedbacks
        );

        // First feedback (index 0 -> 1)
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 80, bytes32(0), bytes32(0), "", bytes32(0), auth
        );

        // Second feedback (index 1 -> 2)
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), auth
        );

        // Third feedback should fail (index 2 >= limit 2)
        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSelector(
            IStrategyReputation.IndexLimitExceeded.selector,
            agentId,
            client1,
            2, // current index
            2  // limit
        ));
        reputation.giveFeedback(
            agentId, 90, bytes32(0), bytes32(0), "", bytes32(0), auth
        );
    }

    /**
     * T069: Test that multiple clients can submit feedback independently
     */
    function test_GiveFeedback_AllowsMultipleClients() public {
        uint256 expiry = block.timestamp + 1 hours;

        // Generate separate auth for each client
        bytes memory auth1 = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );
        bytes memory auth2 = _generateFeedbackAuth(
            agentId, client2, 5, expiry, agentPrivateKey
        );

        // Client1 submits feedback
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 85, bytes32("client1"), bytes32(0), "", bytes32(0), auth1
        );

        // Client2 submits feedback
        vm.prank(client2);
        reputation.giveFeedback(
            agentId, 92, bytes32("client2"), bytes32(0), "", bytes32(0), auth2
        );

        // Verify indices are independent
        assertEq(reputation.getClientIndex(agentId, client1), 1);
        assertEq(reputation.getClientIndex(agentId, client2), 1);

        // Verify reputation aggregation
        (uint64 count, uint8 avgScore) = reputation.getSummary(agentId);
        assertEq(count, 2);
        assertEq(uint256(avgScore), 88); // (85 + 92) / 2
    }

    /**
     * T070: Test getClientIndex returns correct values
     */
    function test_GetClientIndex_ReturnsCorrectValue() public {
        // Initial state - no feedback submitted
        assertEq(reputation.getClientIndex(agentId, client1), 0);
        assertEq(reputation.getClientIndex(agentId, client2), 0);

        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );

        // Submit one feedback from client1
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 80, bytes32(0), bytes32(0), "", bytes32(0), auth
        );

        // Verify client1 index updated, client2 unchanged
        assertEq(reputation.getClientIndex(agentId, client1), 1);
        assertEq(reputation.getClientIndex(agentId, client2), 0);
    }

    /**
     * Additional test: Verify reputation summary calculation
     */
    function test_GetSummary_CalculatesAverage() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth1 = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );
        bytes memory auth2 = _generateFeedbackAuth(
            agentId, client2, 5, expiry, agentPrivateKey
        );

        // Initial state - no feedback
        (uint64 count, uint8 avgScore) = reputation.getSummary(agentId);
        assertEq(count, 0);
        assertEq(avgScore, 0);

        // Submit feedback: 70
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 70, bytes32(0), bytes32(0), "", bytes32(0), auth1
        );
        (count, avgScore) = reputation.getSummary(agentId);
        assertEq(count, 1);
        assertEq(avgScore, 70);

        // Submit feedback: 90 (average should be 80)
        vm.prank(client2);
        reputation.giveFeedback(
            agentId, 90, bytes32(0), bytes32(0), "", bytes32(0), auth2
        );
        (count, avgScore) = reputation.getSummary(agentId);
        assertEq(count, 2);
        assertEq(avgScore, 80);

        // Submit another from client1: 85 (average should be 81 = 245/3)
        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), auth1
        );
        (count, avgScore) = reputation.getSummary(agentId);
        assertEq(count, 3);
        assertEq(avgScore, 81); // (70+90+85)/3 = 81.666... truncated to 81
    }

    /**
     * Additional test: Verify empty string fileuri is accepted
     */
    function test_GiveFeedback_AllowsEmptyFileuri() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );

        vm.prank(client1);
        reputation.giveFeedback(
            agentId,
            75,
            bytes32("tag1"),
            bytes32("tag2"),
            "", // empty fileuri
            bytes32(0), // empty filehash
            auth
        );

        // Should succeed
        assertEq(reputation.getClientIndex(agentId, client1), 1);
    }

    /**
     * Additional test: Verify zero score is accepted
     */
    function test_GiveFeedback_AllowsZeroScore() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );

        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 0, bytes32(0), bytes32(0), "", bytes32(0), auth
        );

        (uint64 count, uint8 avgScore) = reputation.getSummary(agentId);
        assertEq(count, 1);
        assertEq(avgScore, 0);
    }

    /**
     * Additional test: Verify boundary score (100) is accepted
     */
    function test_GiveFeedback_AllowsMaxScore() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory auth = _generateFeedbackAuth(
            agentId, client1, 5, expiry, agentPrivateKey
        );

        vm.prank(client1);
        reputation.giveFeedback(
            agentId, 100, bytes32(0), bytes32(0), "", bytes32(0), auth
        );

        (uint64 count, uint8 avgScore) = reputation.getSummary(agentId);
        assertEq(count, 1);
        assertEq(avgScore, 100);
    }
}
