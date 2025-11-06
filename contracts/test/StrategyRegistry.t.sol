// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/StrategyRegistry.sol";

contract StrategyRegistryTest is Test {
    StrategyRegistry public registry;

    address public alice = address(0x1);
    address public bob = address(0x2);

    event Registered(uint256 indexed agentId, string tokenURI, address indexed owner);

    function setUp() public {
        registry = new StrategyRegistry();
    }

    /**
     * T023: Test that register() mints NFT to caller's address
     */
    function test_Register_MintsNFT() public {
        vm.prank(alice);
        uint256 agentId = registry.register("ipfs://test");

        // Verify NFT was minted to alice
        assertEq(registry.ownerOf(agentId), alice);
        assertEq(registry.balanceOf(alice), 1);
    }

    /**
     * T024: Test that agentIds increment sequentially (1, 2, 3...)
     */
    function test_Register_IncrementsAgentId() public {
        vm.prank(alice);
        uint256 agentId1 = registry.register("ipfs://test1");

        vm.prank(bob);
        uint256 agentId2 = registry.register("ipfs://test2");

        vm.prank(alice);
        uint256 agentId3 = registry.register("ipfs://test3");

        // Verify sequential IDs starting from 1
        assertEq(agentId1, 1);
        assertEq(agentId2, 2);
        assertEq(agentId3, 3);
    }

    /**
     * T025: Test that tokenURI() returns exact input string
     */
    function test_Register_StoresTokenURI() public {
        string memory testURI = "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";

        vm.prank(alice);
        uint256 agentId = registry.register(testURI);

        // Verify tokenURI matches input
        assertEq(registry.tokenURI(agentId), testURI);
    }

    /**
     * T026: Test that Registered event is emitted with correct parameters
     */
    function test_Register_EmitsRegisteredEvent() public {
        string memory testURI = "ipfs://test";

        // Expect Registered event
        vm.expectEmit(true, true, false, true);
        emit Registered(1, testURI, alice);

        vm.prank(alice);
        registry.register(testURI);
    }

    /**
     * T027: Test that empty string is accepted as tokenURI
     */
    function test_Register_AllowsEmptyTokenURI() public {
        vm.prank(alice);
        uint256 agentId = registry.register("");

        // Verify empty string stored and retrievable
        assertEq(registry.tokenURI(agentId), "");
        assertEq(registry.ownerOf(agentId), alice);
    }

    /**
     * T028: Test that ownerOf() returns correct owner
     */
    function test_OwnerOf_ReturnsCorrectOwner() public {
        vm.prank(alice);
        uint256 agentId1 = registry.register("ipfs://alice");

        vm.prank(bob);
        uint256 agentId2 = registry.register("ipfs://bob");

        // Verify owners match registrants
        assertEq(registry.ownerOf(agentId1), alice);
        assertEq(registry.ownerOf(agentId2), bob);
    }

    /**
     * T029: Test that agent NFT can be transferred via transferFrom()
     */
    function test_Transfer_UpdatesOwnership() public {
        // Alice registers agent
        vm.prank(alice);
        uint256 agentId = registry.register("ipfs://test");

        // Verify alice is original owner
        assertEq(registry.ownerOf(agentId), alice);

        // Alice transfers to bob
        vm.prank(alice);
        registry.transferFrom(alice, bob, agentId);

        // Verify bob is new owner
        assertEq(registry.ownerOf(agentId), bob);
        assertEq(registry.balanceOf(alice), 0);
        assertEq(registry.balanceOf(bob), 1);
    }

    /**
     * Additional test: Verify contract name and symbol
     */
    function test_ContractMetadata() public {
        assertEq(registry.name(), "Strategy Agent");
        assertEq(registry.symbol(), "STRATEGY-AGENT");
    }

    /**
     * Additional test: Verify tokenURI reverts for non-existent agent
     */
    function testRevert_TokenURI_NonexistentAgent() public {
        vm.expectRevert();
        registry.tokenURI(999);
    }

    /**
     * Additional test: Verify ownerOf reverts for non-existent agent
     */
    function testRevert_OwnerOf_NonexistentAgent() public {
        vm.expectRevert();
        registry.ownerOf(999);
    }
}
