# Implementation Tasks: ERC-8004 Smart Contracts for Agent Discovery

**Feature**: 001-erc8004-contracts
**Branch**: `001-erc8004-contracts`
**Date**: 2025-11-05

---

## Overview

This document provides actionable implementation tasks for building the StrategyRegistry and StrategyReputation smart contracts. Tasks are organized by user story (P1, P2, P3) to enable independent development and testing.

### User Stories Summary

- **User Story 1 (P1)**: Service Agent Registration - Register agents on-chain with ERC-721 NFT identity
- **User Story 2 (P2)**: Feedback Submission - Submit feedback with EIP-712 signature authorization
- **User Story 3 (P3)**: Reputation Aggregation - Aggregate feedback data and calculate reputation scores

### Implementation Strategy

**MVP Scope**: User Story 1 (Service Agent Registration) provides a complete, deployable feature that enables agent registration and discovery.

**Incremental Delivery**:
1. **Phase 1-3 (US1)**: Core registration functionality - fully testable and deployable
2. **Phase 4-5 (US2)**: Add feedback submission - builds on US1, independently testable
3. **Phase 6 (US3)**: Add reputation aggregation - completes the feature set

Each user story can be developed, tested, and deployed independently.

---

## Phase 1: Project Setup

**Goal**: Initialize Foundry project with dependencies and configuration.

**Tasks**:

- [x] T001 Initialize Foundry project by running `forge init --force` in contracts/ directory
- [x] T002 [P] Configure foundry.toml with Solidity version 0.8.30, optimizer settings, and Base Sepolia RPC endpoint
- [x] T003 [P] Install OpenZeppelin contracts via `bun add @openzeppelin/contracts@^5.1.0` in contracts/ directory
- [x] T004 [P] Create remappings.txt with OpenZeppelin import mapping: `@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/`
- [x] T005 [P] Create .gitignore file to exclude Foundry artifacts (out/, cache/, broadcast/), node_modules/, and .env
- [x] T006 [P] Create .env.example file with template for BASE_SEPOLIA_RPC_URL, PRIVATE_KEY, and BASESCAN_API_KEY
- [x] T007 [P] Create contracts/src/interfaces/ directory for contract interfaces
- [x] T008 Verify setup by running `forge build` and confirming successful compilation

**Validation**: All tasks complete when `forge build` runs without errors and directory structure matches plan.md.

---

## Phase 2: Foundational Infrastructure

**Goal**: Create shared interfaces and base infrastructure needed by all user stories.

**Tasks**:

- [x] T009 [P] Create IStrategyRegistry interface in contracts/src/interfaces/IStrategyRegistry.sol with register(), ownerOf(), and tokenURI() function signatures
- [x] T010 [P] Define custom errors in contracts/src/interfaces/IStrategyRegistry.sol (if needed for registry)
- [x] T011 [P] Create IStrategyReputation interface in contracts/src/interfaces/IStrategyReputation.sol with giveFeedback(), getSummary(), and getClientIndex() function signatures
- [x] T012 [P] Define custom errors in contracts/src/interfaces/IStrategyReputation.sol: AgentNotFound, InvalidScore, IndexLimitExceeded, FeedbackAuthExpired, InvalidSigner, InvalidChainId
- [x] T013 Verify interfaces compile successfully with `forge build`

**Validation**: Interfaces compile without errors and define all required function signatures from spec.md.

**Dependency**: Must complete before any user story implementation.

---

## Phase 3: User Story 1 - Service Agent Registration (P1)

**Story Goal**: Enable service agents to register on-chain and receive unique ERC-721 NFT identities.

**Independent Test Criteria**:
- Agent can call register() with any tokenURI (including empty string) and receive unique agentId
- NFT is minted to caller's address
- Registered event is emitted with correct agentId, tokenURI, and owner
- tokenURI() query returns the exact string provided during registration
- agentIds increment sequentially starting from 1

**Tasks**:

### US1: Contract Implementation

- [x] T014 [US1] Create StrategyRegistry contract in contracts/src/StrategyRegistry.sol inheriting from OpenZeppelin ERC721URIStorage
- [x] T015 [US1] Implement constructor setting ERC721 name to "Strategy Agent" and symbol to "STRATEGY-AGENT"
- [x] T016 [US1] Add private state variable _nextAgentId initialized to 1 in contracts/src/StrategyRegistry.sol
- [x] T017 [US1] Implement register(string tokenURI) function in contracts/src/StrategyRegistry.sol that mints NFT with incremented agentId
- [x] T018 [US1] Add _setTokenURI call in register() function to store tokenURI for the agentId
- [x] T019 [US1] Define and emit Registered event with indexed agentId and owner, non-indexed tokenURI in register() function
- [x] T020 [US1] Verify register() function returns the newly minted agentId

### US1: Test Implementation

- [x] T021 [US1] Create StrategyRegistry.t.sol test contract in contracts/test/ inheriting from forge-std Test
- [x] T022 [US1] Implement setUp() function that deploys StrategyRegistry contract and creates test accounts
- [x] T023 [P] [US1] Write test_Register_MintsNFT() verifying NFT is minted to caller's address after registration
- [x] T024 [P] [US1] Write test_Register_IncrementsAgentId() verifying sequential agentId assignment (1, 2, 3...)
- [x] T025 [P] [US1] Write test_Register_StoresTokenURI() verifying tokenURI() returns exact input string
- [x] T026 [P] [US1] Write test_Register_EmitsRegisteredEvent() verifying Registered event emission with correct parameters
- [x] T027 [P] [US1] Write test_Register_AllowsEmptyTokenURI() verifying empty string is accepted as tokenURI
- [x] T028 [P] [US1] Write test_OwnerOf_ReturnsCorrectOwner() verifying ownerOf() returns agent NFT owner
- [x] T029 [P] [US1] Write test_Transfer_UpdatesOwnership() verifying agent NFT can be transferred via transferFrom()
- [x] T030 [US1] Run all tests with `forge test --match-contract StrategyRegistryTest` and verify 100% pass

**Story Validation**: All tests pass. Agent registration works end-to-end. Contract is deployable and functional without Phase 4-6.

**Parallel Opportunities**: T023-T029 (test writing) can be done in parallel after T022 completes.

---

## Phase 4: User Story 2 - Feedback Submission (P2)

**Story Goal**: Enable clients to submit feedback with EIP-712 signature authorization from agent owners.

**Independent Test Criteria**:
- Client with valid feedbackAuth can submit feedback successfully
- Feedback is stored on-chain with all parameters (score, tags, fileuri, filehash)
- NewFeedback event is emitted with correct indexed and non-indexed fields
- Invalid feedbackAuth signatures are rejected with appropriate errors
- Client feedback index increments correctly after each submission
- indexLimit enforcement prevents submissions when index >= limit

**Tasks**:

### US2: Contract Implementation - StrategyReputation Base

- [x] T031 [US2] Create StrategyReputation contract in contracts/src/StrategyReputation.sol inheriting from OpenZeppelin EIP712
- [ ] T032 [US2] Implement constructor accepting identityRegistry address parameter and initializing EIP712 with name "StrategyReputation" and version "1"
- [ ] T033 [US2] Add immutable identityRegistry variable of type IStrategyRegistry in StrategyReputation contract
- [ ] T034 [US2] Define FEEDBACK_AUTH_TYPEHASH constant as keccak256 of EIP-712 struct signature string
- [ ] T035 [US2] Define Feedback struct with fields: clientAddress, score (uint8), tag1, tag2 (bytes32), fileuri (string), filehash (bytes32), timestamp (uint40)
- [ ] T036 [US2] Add private mapping _clientIndices: mapping(uint256 => mapping(address => uint256)) for tracking client feedback counts per agent
- [ ] T037 [US2] Add private mapping _feedbacks: mapping(uint256 => Feedback[]) for storing feedback arrays per agent

### US2: Contract Implementation - Signature Verification

- [ ] T038 [US2] Implement _verifyFeedbackAuth internal function that accepts agentId, clientAddress, indexLimit, expiry, signature parameters
- [ ] T039 [US2] Add expiry timestamp validation in _verifyFeedbackAuth (require block.timestamp <= expiry)
- [ ] T040 [US2] Add chainId validation in _verifyFeedbackAuth (encoded in EIP-712 struct hash)
- [ ] T041 [US2] Compute EIP-712 struct hash in _verifyFeedbackAuth using FEEDBACK_AUTH_TYPEHASH and parameters
- [ ] T042 [US2] Call _hashTypedDataV4(structHash) to get final digest for signature verification
- [ ] T043 [US2] Use ECDSA.recover to extract signer address from signature and digest
- [ ] T044 [US2] Return recovered signer address from _verifyFeedbackAuth function

### US2: Contract Implementation - giveFeedback Function

- [ ] T045 [US2] Implement giveFeedback() public function accepting agentId, score, tag1, tag2, fileuri, filehash, feedbackAuth parameters
- [ ] T046 [US2] Add score validation in giveFeedback: revert InvalidScore if score > 100
- [ ] T047 [US2] Decode feedbackAuth bytes to extract struct fields (agentId, clientAddress, indexLimit, expiry, chainId) and 65-byte signature
- [ ] T048 [US2] Call _verifyFeedbackAuth to recover signer address from feedbackAuth
- [ ] T049 [US2] Query identityRegistry.ownerOf(agentId) to get agent NFT owner (reverts if agentId doesn't exist)
- [ ] T050 [US2] Validate recovered signer equals agent owner: revert InvalidSigner if mismatch
- [ ] T051 [US2] Get current client index from _clientIndices[agentId][msg.sender]
- [ ] T052 [US2] Validate current index < indexLimit: revert IndexLimitExceeded if at or over limit
- [ ] T053 [US2] Create Feedback struct with msg.sender as clientAddress, uint40(block.timestamp) as timestamp
- [ ] T054 [US2] Append new Feedback struct to _feedbacks[agentId] array
- [ ] T055 [US2] Increment _clientIndices[agentId][msg.sender] by 1
- [ ] T056 [US2] Emit NewFeedback event with indexed agentId, clientAddress, tag1; non-indexed score, tag2, fileuri, filehash

### US2: Helper Functions

- [ ] T057 [P] [US2] Implement getClientIndex(uint256 agentId, address clientAddress) public view function returning current index from _clientIndices
- [ ] T058 [P] [US2] Add error handling comments documenting all revert conditions in giveFeedback function

### US2: Test Implementation

- [ ] T059 [US2] Create StrategyReputation.t.sol test contract in contracts/test/ with setUp() deploying both Registry and Reputation contracts
- [ ] T060 [US2] Create test helper function _generateValidFeedbackAuth that signs EIP-712 typed data using agent owner's private key
- [ ] T061 [P] [US2] Write test_GiveFeedback_StoresFeedback() verifying feedback is stored correctly in _feedbacks array
- [ ] T062 [P] [US2] Write test_GiveFeedback_IncrementsClientIndex() verifying client index increments from 0 to 1
- [ ] T063 [P] [US2] Write test_GiveFeedback_EmitsNewFeedbackEvent() verifying NewFeedback event with all parameters
- [ ] T064 [P] [US2] Write test_GiveFeedback_RevertsInvalidScore() testing score > 100 rejection
- [ ] T065 [P] [US2] Write test_GiveFeedback_RevertsNonexistentAgent() testing agentId that doesn't exist
- [ ] T066 [P] [US2] Write test_GiveFeedback_RevertsExpiredSignature() testing feedbackAuth past expiry
- [ ] T067 [P] [US2] Write test_GiveFeedback_RevertsInvalidSigner() testing feedbackAuth signed by non-owner
- [ ] T068 [P] [US2] Write test_GiveFeedback_RevertsIndexLimitExceeded() testing submission when current index >= indexLimit
- [ ] T069 [P] [US2] Write test_GiveFeedback_AllowsMultipleFromSameClient() verifying client can submit multiple feedbacks with batch auth
- [ ] T070 [P] [US2] Write test_GetClientIndex_ReturnsCorrectValue() verifying getClientIndex returns accurate current index
- [ ] T071 [US2] Run all tests with `forge test --match-contract StrategyReputationTest` and verify 100% pass

**Story Validation**: All tests pass. Feedback submission works with proper signature verification, index tracking, and event emission. Contract integrates correctly with StrategyRegistry.

**Parallel Opportunities**: T057-T058 (helper functions) can be developed in parallel with T045-T056. T061-T070 (test writing) can be done in parallel after T060 completes.

---

## Phase 5: User Story 3 - Reputation Aggregation (P3)

**Story Goal**: Aggregate feedback data and provide reputation summaries for agents.

**Independent Test Criteria**:
- getSummary() returns accurate count and average score for agents with feedback
- getSummary() returns (0, 0) for agents with no feedback
- Average calculation handles multiple feedbacks correctly
- Multiple feedbacks from same client all contribute to average (no deduplication)
- Reputation updates correctly after each new feedback submission

**Tasks**:

### US3: Contract Implementation - Reputation Storage

- [ ] T072 [US3] Define AgentReputation struct with fields: feedbackCount (uint64), totalScore (uint256)
- [ ] T073 [US3] Add private mapping _reputations: mapping(uint256 => AgentReputation) in StrategyReputation contract
- [ ] T074 [US3] Implement _updateReputation internal function accepting agentId and score parameters
- [ ] T075 [US3] In _updateReputation: increment _reputations[agentId].feedbackCount by 1
- [ ] T076 [US3] In _updateReputation: add score to _reputations[agentId].totalScore
- [ ] T077 [US3] Call _updateReputation(agentId, score) at end of giveFeedback function (before event emission)

### US3: Contract Implementation - getSummary Function

- [ ] T078 [US3] Implement getSummary(uint256 agentId) public view function returning (uint64 count, uint8 averageScore)
- [ ] T079 [US3] In getSummary: load AgentReputation from _reputations[agentId]
- [ ] T080 [US3] In getSummary: set count = reputation.feedbackCount
- [ ] T081 [US3] In getSummary: calculate averageScore = count > 0 ? uint8(totalScore / count) : 0
- [ ] T082 [US3] Add overflow protection documentation for totalScore accumulation (uint256 max vs 100 * uint64 max)

### US3: Test Implementation

- [ ] T083 [P] [US3] Write test_GetSummary_ReturnsZeroForNoFeedback() verifying (0, 0) for newly registered agent
- [ ] T084 [P] [US3] Write test_GetSummary_CalculatesAverageCorrectly() verifying average of multiple feedbacks (e.g., [85, 90, 80] → 85 average)
- [ ] T085 [P] [US3] Write test_GetSummary_UpdatesAfterEachFeedback() verifying count and average update after each giveFeedback call
- [ ] T086 [P] [US3] Write test_GetSummary_CountsMultipleFeedbacksFromSameClient() verifying no deduplication when same client submits multiple times
- [ ] T087 [P] [US3] Write test_GetSummary_HandlesLargeNumberOfFeedbacks() testing with 100+ feedbacks to verify no overflow
- [ ] T088 [US3] Run all tests with `forge test` and verify 100% pass rate across all test files

**Story Validation**: All tests pass. Reputation aggregation works correctly. Complete feature set is functional and tested.

**Parallel Opportunities**: T083-T087 (test writing) can all be done in parallel after T082 completes.

---

## Phase 6: Deployment & Integration

**Goal**: Deploy contracts to Base Sepolia and prepare for integration with other components.

**Tasks**:

### Deployment Script

- [ ] T089 [P] Create Deploy.s.sol deployment script in contracts/script/ inheriting from forge-std Script
- [ ] T090 [P] Implement run() function in Deploy.s.sol that deploys StrategyRegistry then StrategyReputation with registry address
- [ ] T091 [P] Add console logging in Deploy.s.sol to output deployed contract addresses
- [ ] T092 Test deployment locally with `forge script script/Deploy.s.sol --rpc-url http://localhost:8545` using Anvil

### Base Sepolia Deployment

- [ ] T093 Create .env file with BASE_SEPOLIA_RPC_URL, PRIVATE_KEY, and BASESCAN_API_KEY (never commit)
- [ ] T094 Fund deployer account with Base Sepolia ETH from faucet
- [ ] T095 Deploy contracts to Base Sepolia with `forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify`
- [ ] T096 [P] Verify StrategyRegistry contract on BaseScan using `forge verify-contract`
- [ ] T097 [P] Verify StrategyReputation contract on BaseScan using `forge verify-contract`
- [ ] T098 Document deployed contract addresses in deployment log or README

### Integration Preparation

- [ ] T099 [P] Extract StrategyRegistry ABI from out/StrategyRegistry.sol/StrategyRegistry.json to specs/001-erc8004-contracts/contracts/StrategyRegistry.abi.json
- [ ] T100 [P] Extract StrategyReputation ABI from out/StrategyReputation.sol/StrategyReputation.json to specs/001-erc8004-contracts/contracts/StrategyReputation.abi.json
- [ ] T101 Create integration test example script demonstrating end-to-end flow: register agent → submit feedback → query reputation
- [ ] T102 Update CLAUDE.md agent context file with deployed contract addresses and integration notes

**Validation**: Contracts deployed successfully to Base Sepolia, verified on BaseScan, and ready for indexer integration.

**Parallel Opportunities**: T089-T091 (deployment script) can be done in parallel with final testing. T096-T097 (contract verification) can run in parallel. T099-T100 (ABI extraction) can run in parallel.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Goal**: Final optimizations, documentation, and quality improvements.

**Tasks**:

### Gas Optimization

- [ ] T103 [P] Run `forge test --gas-report` and document gas costs for register(), giveFeedback(), and getSummary()
- [ ] T104 [P] Review feedback struct packing and optimize if needed to reduce storage slots
- [ ] T105 [P] Add NatSpec comments to all public functions in StrategyRegistry.sol
- [ ] T106 [P] Add NatSpec comments to all public functions in StrategyReputation.sol

### Documentation

- [ ] T107 [P] Create README.md in contracts/ directory with quickstart instructions from specs/001-erc8004-contracts/quickstart.md
- [ ] T108 [P] Document all custom errors with usage examples in contract comments
- [ ] T109 [P] Create DEPLOYMENT.md with deployment addresses, transaction hashes, and verification links

### Final Validation

- [ ] T110 Run full test suite with coverage: `forge coverage` and verify critical paths are tested
- [ ] T111 Review all contracts for TODO comments and resolve or document
- [ ] T112 Verify foundry.toml settings match production requirements (optimizer runs, solc version)
- [ ] T113 Final code review: check for unused imports, commented code, console.log statements

**Validation**: All documentation complete, gas costs documented, contracts optimized and clean.

**Parallel Opportunities**: T103-T106 (gas optimization and NatSpec) can all run in parallel. T107-T109 (documentation) can run in parallel.

---

## Dependencies & Execution Order

### Story Dependency Graph

```
Setup (Phase 1) → Foundational (Phase 2) → [User Stories can be done in order or in parallel if resources allow]
                                           ├─ US1 (Phase 3) [REQUIRED for US2, US3]
                                           ├─ US2 (Phase 4) [REQUIRES US1, REQUIRED for US3]
                                           └─ US3 (Phase 5) [REQUIRES US1 & US2]

                                           All Stories → Deployment (Phase 6) → Polish (Phase 7)
```

### Critical Path

1. Phase 1 (Setup) → Phase 2 (Foundational) - **Must complete first**
2. Phase 3 (US1) - **Blocking for US2 and US3**
3. Phase 4 (US2) - **Blocking for US3**
4. Phase 5 (US3) - **Can start after US2**
5. Phase 6 (Deployment) - **Can start after all stories complete**
6. Phase 7 (Polish) - **Final cleanup**

### Parallel Execution Opportunities

**Within Phase 3 (US1)**:
- T023-T029 (test writing) can all run in parallel after T022 completes

**Within Phase 4 (US2)**:
- T037-T058 (helper functions) can overlap with main implementation
- T061-T070 (test writing) can all run in parallel after T060 completes

**Within Phase 5 (US3)**:
- T083-T087 (test writing) can all run in parallel after T082 completes

**Within Phase 6 (Deployment)**:
- T089-T091 (deployment script) independent of testing
- T096-T097 (contract verification) can run in parallel
- T099-T100 (ABI extraction) can run in parallel

**Within Phase 7 (Polish)**:
- T103-T106 (optimization) can all run in parallel
- T107-T109 (documentation) can all run in parallel

---

## Task Summary

| Phase | Task Count | Can Start After | Estimated Effort |
|-------|------------|------------------|------------------|
| Phase 1: Setup | 8 tasks | Immediate | 1 hour |
| Phase 2: Foundational | 5 tasks | Phase 1 | 1 hour |
| Phase 3: US1 (P1) | 17 tasks | Phase 2 | 4 hours |
| Phase 4: US2 (P2) | 41 tasks | Phase 3 | 8 hours |
| Phase 5: US3 (P3) | 17 tasks | Phase 4 | 3 hours |
| Phase 6: Deployment | 14 tasks | Phase 5 | 2 hours |
| Phase 7: Polish | 11 tasks | Phase 6 | 2 hours |
| **TOTAL** | **113 tasks** | - | **~21 hours** |

### Parallelizable Tasks

- **39 tasks** marked with `[P]` can be executed in parallel within their phase
- Test writing tasks (36 total) are highly parallelizable within each phase

### MVP Recommendation

**Minimum Viable Product**: Complete Phase 1-3 only (User Story 1)
- **30 tasks** (Setup + Foundational + US1)
- **~6 hours** of effort
- **Delivers**: Fully functional agent registration with ERC-721 NFT identity
- **Testable**: Complete test suite for registration functionality
- **Deployable**: Can be deployed and used independently

---

## Validation Checklist

Before marking the feature complete, verify:

- [ ] All 113 tasks completed and checked off
- [ ] All tests pass: `forge test` shows 100% pass rate
- [ ] Contracts deployed to Base Sepolia and verified on BaseScan
- [ ] Gas costs documented and acceptable (register ~150k, giveFeedback ~200k)
- [ ] All public functions have NatSpec documentation
- [ ] ABIs exported and available for indexer integration
- [ ] Integration test demonstrates full end-to-end flow
- [ ] Deployment addresses documented in DEPLOYMENT.md
- [ ] No console.log, TODO, or commented debug code remains
- [ ] Constitution principles satisfied (no violations)

---

**Generated**: 2025-11-05 | **Status**: Ready for implementation
