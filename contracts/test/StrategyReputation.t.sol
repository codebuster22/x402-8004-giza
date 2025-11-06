// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/StrategyRegistry.sol";
import "../src/StrategyReputation.sol";

contract StrategyReputationTest is Test {
    StrategyRegistry public registry;
    StrategyReputation public reputation;

    uint256 public agentOwnerPk = 0x1;
    address public agentOwner = vm.addr(agentOwnerPk);
    address public client1 = address(0x2);
    address public client2 = address(0x3);

    uint256 public agentId;

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
        // Deploy contracts
        registry = new StrategyRegistry();
        reputation = new StrategyReputation(address(registry));

        // Register an agent
        vm.prank(agentOwner);
        agentId = registry.register("ipfs://agent1");
    }

    /**
     * Helper function to generate valid feedbackAuth
     * Implements EIP-712 signature as per spec
     */
    function _generateValidFeedbackAuth(
        uint256 _agentId,
        address _clientAddress,
        uint256 _indexLimit,
        uint256 _expiry,
        uint256 _chainId,
        uint256 _signerPk
    ) internal returns (bytes memory) {
        // Compute EIP-712 struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "FeedbackAuth(uint256 agentId,address clientAddress,uint256 indexLimit,uint256 expiry,uint256 chainId)"
                ),
                _agentId,
                _clientAddress,
                _indexLimit,
                _expiry,
                _chainId
            )
        );

        // Get domain separator from contract
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("StrategyReputation"),
                keccak256("1"),
                block.chainid,
                address(reputation)
            )
        );

        // Compute digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Sign digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Return abi.encode(struct fields) + signature
        return abi.encodePacked(abi.encode(_agentId, _clientAddress, _indexLimit, _expiry, _chainId), signature);
    }

    /**
     * T061: Test that giveFeedback stores feedback correctly
     */
    function test_GiveFeedback_StoresFeedback() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory feedbackAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);

        vm.prank(client1);
        reputation.giveFeedback(
            agentId,
            85,
            bytes32("performance"),
            bytes32("reliable"),
            "ipfs://feedback1",
            keccak256("feedback-content"),
            feedbackAuth
        );

        // Verify feedback was stored by checking reputation was updated
        (uint64 count, uint8 averageScore) = reputation.getSummary(agentId);
        assertEq(count, 1);
        assertEq(averageScore, 85);
    }

    /**
     * T062: Test that client index increments correctly
     */
    function test_GiveFeedback_IncrementsClientIndex() public {
        uint256 expiry = block.timestamp + 1 hours;

        // Initial index should be 0
        assertEq(reputation.getClientIndex(agentId, client1), 0);

        // Submit first feedback
        bytes memory feedbackAuth1 =
            _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        reputation.giveFeedback(agentId, 85, bytes32("tag1"), bytes32("tag2"), "", bytes32(0), feedbackAuth1);

        // Index should be 1
        assertEq(reputation.getClientIndex(agentId, client1), 1);

        // Submit second feedback with higher limit
        bytes memory feedbackAuth2 =
            _generateValidFeedbackAuth(agentId, client1, 2, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        reputation.giveFeedback(agentId, 90, bytes32("tag1"), bytes32("tag2"), "", bytes32(0), feedbackAuth2);

        // Index should be 2
        assertEq(reputation.getClientIndex(agentId, client1), 2);
    }

    /**
     * T063: Test that NewFeedback event is emitted
     */
    function test_GiveFeedback_EmitsNewFeedbackEvent() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory feedbackAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);

        bytes32 tag1 = bytes32("performance");
        bytes32 tag2 = bytes32("reliable");
        string memory fileuri = "ipfs://feedback1";
        bytes32 filehash = keccak256("content");

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit NewFeedback(agentId, client1, 85, tag1, tag2, fileuri, filehash);

        vm.prank(client1);
        reputation.giveFeedback(agentId, 85, tag1, tag2, fileuri, filehash, feedbackAuth);
    }

    /**
     * T064: Test that score > 100 reverts with InvalidScore
     */
    function test_GiveFeedback_RevertsInvalidScore() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory feedbackAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSelector(IStrategyReputation.InvalidScore.selector, 101));
        reputation.giveFeedback(agentId, 101, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth);
    }

    /**
     * T065: Test that non-existent agentId reverts
     */
    function test_GiveFeedback_RevertsNonexistentAgent() public {
        uint256 fakeAgentId = 999;
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory feedbackAuth =
            _generateValidFeedbackAuth(fakeAgentId, client1, 1, expiry, block.chainid, agentOwnerPk);

        vm.prank(client1);
        vm.expectRevert(); // ERC721 will revert with "NONEXISTENT_TOKEN"
        reputation.giveFeedback(fakeAgentId, 85, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth);
    }

    /**
     * T066: Test that expired signature reverts with FeedbackAuthExpired
     */
    function test_GiveFeedback_RevertsExpiredSignature() public {
        uint256 expiry = block.timestamp - 1; // Already expired
        bytes memory feedbackAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);

        vm.prank(client1);
        vm.expectRevert(
            abi.encodeWithSelector(IStrategyReputation.FeedbackAuthExpired.selector, expiry, block.timestamp)
        );
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth);
    }

    /**
     * T067: Test that signature from non-owner reverts with InvalidSigner
     */
    function test_GiveFeedback_RevertsInvalidSigner() public {
        uint256 wrongPk = 0x999; // Not the agent owner's key
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory feedbackAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, wrongPk);

        vm.prank(client1);
        vm.expectRevert(
            abi.encodeWithSelector(IStrategyReputation.InvalidSigner.selector, agentOwner, vm.addr(wrongPk))
        );
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth);
    }

    /**
     * T068: Test that index >= indexLimit reverts with IndexLimitExceeded
     */
    function test_GiveFeedback_RevertsIndexLimitExceeded() public {
        uint256 expiry = block.timestamp + 1 hours;

        // Submit first feedback with limit 1
        bytes memory feedbackAuth1 =
            _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth1);

        // Try to submit again with same limit (index is now 1, limit is 1, so 1 >= 1 should fail)
        bytes memory feedbackAuth2 =
            _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSelector(IStrategyReputation.IndexLimitExceeded.selector, agentId, client1, 1, 1));
        reputation.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth2);
    }

    /**
     * T069: Test that multiple feedbacks from same client work with batch auth
     */
    function test_GiveFeedback_AllowsMultipleFromSameClient() public {
        uint256 expiry = block.timestamp + 1 hours;

        // Authorize 3 feedbacks at once
        bytes memory feedbackAuth1 = _generateValidFeedbackAuth(
            agentId,
            client1,
            3, // indexLimit allows indices 0, 1, 2
            expiry,
            block.chainid,
            agentOwnerPk
        );

        // Submit 3 feedbacks
        vm.startPrank(client1);
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth1);

        bytes memory feedbackAuth2 =
            _generateValidFeedbackAuth(agentId, client1, 3, expiry, block.chainid, agentOwnerPk);
        reputation.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth2);

        bytes memory feedbackAuth3 =
            _generateValidFeedbackAuth(agentId, client1, 3, expiry, block.chainid, agentOwnerPk);
        reputation.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth3);
        vm.stopPrank();

        // Verify all 3 feedbacks counted
        (uint64 count, uint8 averageScore) = reputation.getSummary(agentId);
        assertEq(count, 3);
        assertEq(averageScore, (85 + 90 + 80) / 3); // 85
        assertEq(reputation.getClientIndex(agentId, client1), 3);
    }

    /**
     * T070: Test that getClientIndex returns correct value
     */
    function test_GetClientIndex_ReturnsCorrectValue() public {
        // Initial state
        assertEq(reputation.getClientIndex(agentId, client1), 0);
        assertEq(reputation.getClientIndex(agentId, client2), 0);

        // Submit feedback from client1
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory feedbackAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth);

        // Only client1's index should increment
        assertEq(reputation.getClientIndex(agentId, client1), 1);
        assertEq(reputation.getClientIndex(agentId, client2), 0);
    }

    /**
     * T083: Test that getSummary returns (0, 0) for no feedback
     */
    function test_GetSummary_ReturnsZeroForNoFeedback() public {
        (uint64 count, uint8 averageScore) = reputation.getSummary(agentId);
        assertEq(count, 0);
        assertEq(averageScore, 0);
    }

    /**
     * T084: Test that getSummary calculates average correctly
     */
    function test_GetSummary_CalculatesAverageCorrectly() public {
        uint256 expiry = block.timestamp + 1 hours;

        // Submit 3 feedbacks with scores 85, 90, 80
        bytes memory auth1 = _generateValidFeedbackAuth(agentId, client1, 3, expiry, block.chainid, agentOwnerPk);
        vm.startPrank(client1);
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), auth1);

        bytes memory auth2 = _generateValidFeedbackAuth(agentId, client1, 3, expiry, block.chainid, agentOwnerPk);
        reputation.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "", bytes32(0), auth2);

        bytes memory auth3 = _generateValidFeedbackAuth(agentId, client1, 3, expiry, block.chainid, agentOwnerPk);
        reputation.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "", bytes32(0), auth3);
        vm.stopPrank();

        (uint64 count, uint8 averageScore) = reputation.getSummary(agentId);
        assertEq(count, 3);
        assertEq(averageScore, 85); // (85 + 90 + 80) / 3 = 85
    }

    /**
     * T085: Test that getSummary updates after each feedback
     */
    function test_GetSummary_UpdatesAfterEachFeedback() public {
        uint256 expiry = block.timestamp + 1 hours;

        // After first feedback
        bytes memory auth1 = _generateValidFeedbackAuth(agentId, client1, 3, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        reputation.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "", bytes32(0), auth1);

        (uint64 count1, uint8 avg1) = reputation.getSummary(agentId);
        assertEq(count1, 1);
        assertEq(avg1, 80);

        // After second feedback
        bytes memory auth2 = _generateValidFeedbackAuth(agentId, client1, 3, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        reputation.giveFeedback(agentId, 100, bytes32(0), bytes32(0), "", bytes32(0), auth2);

        (uint64 count2, uint8 avg2) = reputation.getSummary(agentId);
        assertEq(count2, 2);
        assertEq(avg2, 90); // (80 + 100) / 2

        // After third feedback
        bytes memory auth3 = _generateValidFeedbackAuth(agentId, client1, 3, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        reputation.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "", bytes32(0), auth3);

        (uint64 count3, uint8 avg3) = reputation.getSummary(agentId);
        assertEq(count3, 3);
        assertEq(avg3, 90); // (80 + 100 + 90) / 3
    }

    /**
     * T086: Test that multiple feedbacks from same client all count (no deduplication)
     */
    function test_GetSummary_CountsMultipleFeedbacksFromSameClient() public {
        uint256 expiry = block.timestamp + 1 hours;

        // Client1 submits 2 feedbacks
        bytes memory auth1 = _generateValidFeedbackAuth(agentId, client1, 2, expiry, block.chainid, agentOwnerPk);
        vm.startPrank(client1);
        reputation.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "", bytes32(0), auth1);
        bytes memory auth2 = _generateValidFeedbackAuth(agentId, client1, 2, expiry, block.chainid, agentOwnerPk);
        reputation.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "", bytes32(0), auth2);
        vm.stopPrank();

        // Client2 submits 1 feedback
        bytes memory auth3 = _generateValidFeedbackAuth(agentId, client2, 1, expiry, block.chainid, agentOwnerPk);
        vm.prank(client2);
        reputation.giveFeedback(agentId, 100, bytes32(0), bytes32(0), "", bytes32(0), auth3);

        // Total should be 3 feedbacks
        (uint64 count, uint8 avg) = reputation.getSummary(agentId);
        assertEq(count, 3);
        assertEq(avg, 90); // (80 + 90 + 100) / 3
    }

    /**
     * T087: Test with large number of feedbacks (100+) to verify no overflow
     */
    function test_GetSummary_HandlesLargeNumberOfFeedbacks() public {
        uint256 expiry = block.timestamp + 1 hours;
        uint256 numFeedbacks = 100;

        // Submit 100 feedbacks with score 50
        vm.startPrank(client1);
        for (uint256 i = 0; i < numFeedbacks; i++) {
            bytes memory currentAuth =
                _generateValidFeedbackAuth(agentId, client1, numFeedbacks, expiry, block.chainid, agentOwnerPk);
            reputation.giveFeedback(agentId, 50, bytes32(0), bytes32(0), "", bytes32(0), currentAuth);
        }
        vm.stopPrank();

        (uint64 count, uint8 avg) = reputation.getSummary(agentId);
        assertEq(count, 100);
        assertEq(avg, 50);
    }

    /**
     * Additional test: Verify chainId mismatch reverts
     */
    function test_GiveFeedback_RevertsInvalidChainId() public {
        uint256 expiry = block.timestamp + 1 hours;
        uint256 wrongChainId = 999;
        bytes memory feedbackAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, wrongChainId, agentOwnerPk);

        vm.prank(client1);
        vm.expectRevert(IStrategyReputation.InvalidChainId.selector);
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), feedbackAuth);
    }

    /**
     * Additional test: Verify identityRegistry reference
     */
    function test_IdentityRegistry_ReturnsCorrectAddress() public {
        assertEq(address(reputation.identityRegistry()), address(registry));
    }

    /**
     * Additional test: Verify agent ownership transfer affects authorization
     */
    function test_AgentTransfer_RequiresNewOwnerSignature() public {
        uint256 expiry = block.timestamp + 1 hours;
        uint256 newOwnerPk = 0x4;
        address newOwner = vm.addr(newOwnerPk);

        // Transfer agent to new owner
        vm.prank(agentOwner);
        registry.transferFrom(agentOwner, newOwner, agentId);

        // Old owner's signature should fail
        bytes memory oldAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, agentOwnerPk);
        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSelector(IStrategyReputation.InvalidSigner.selector, newOwner, agentOwner));
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), oldAuth);

        // New owner's signature should work
        bytes memory newAuth = _generateValidFeedbackAuth(agentId, client1, 1, expiry, block.chainid, newOwnerPk);
        vm.prank(client1);
        reputation.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "", bytes32(0), newAuth);

        (uint64 count,) = reputation.getSummary(agentId);
        assertEq(count, 1);
    }
}
