# Feature Specification: ERC-8004 Smart Contracts for Agent Discovery

**Feature Branch**: `001-erc8004-contracts`
**Created**: 2025-11-05
**Status**: Draft
**Input**: User description: "Build smart contracts for my specifications as mentioned in @docs/initial-specs.md"

## Clarifications

### Session 2025-11-05

- Q: What happens when an agent tries to register with an empty tokenURI string? → A: Allow it.
- Q: How does the system handle feedback submission with a score greater than 100 or negative values? → A: uint8 prevents negative values; scores > 100 revert.
- Q: What happens if a client tries to submit feedback for a non-existent agentId? → A: Revert.
- Q: How does the system handle feedbackAuth signatures that have expired based on the expiry timestamp? → A: Revert.
- Q: What happens when getSummary() is called with filters that match zero feedback entries? → A: No filters in getSummary - only agentId parameter.
- Q: How does the contract handle ownership transfer of agent NFTs (impact on feedback validity)? → A: No impact.
- Q: How should the indexLimit field be used to prevent reputation gaming? → A: indexLimit controls batch authorization per client per agent. Each clientAddress has a separate feedback index per agentId. The contract checks: indexLimit must be greater than the client's current feedback index for that agent. After feedback submission, the client's index for that agent increments by 1.
- Q: How should clients format tags when calling giveFeedback()? → A: UTF-8 encoded strings right-padded to bytes32. Tags are not used for on-chain aggregation or filtering, only stored and emitted in events for off-chain indexing.
- Q: What is the exact message structure that gets signed in the feedbackAuth signature? → A: EIP-712 structured data with typed struct including domain separator and proper type hashing.
- Q: When the same client submits multiple feedbacks to the same agent, how should they be counted in getSummary()? → A: All feedbacks counted independently - each submission adds to total count and affects average calculation.
- Q: Who must sign the feedbackAuth signature for it to be valid? → A: Agent NFT owner must sign - only the current owner of the agentId NFT can create valid feedbackAuth signatures. Structure: abi.encode(struct fields) + signature (65 bytes).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Service Agent Registration (Priority: P1)

A service agent (e.g., Memecoin Strategy provider) needs to register their agent on-chain to make it discoverable by potential clients. The registration creates a unique on-chain identity for the agent.

**Why this priority**: This is the foundational capability - without agent registration, no other features can work. It's the entry point for the entire discovery ecosystem.

**Independent Test**: Can be fully tested by calling the register function with a valid tokenURI, verifying the NFT is minted, and confirming the Registered event is emitted with correct parameters.

**Acceptance Scenarios**:

1. **Given** a service agent with a valid wallet and metadata file hosted at an HTTPS/IPFS URL, **When** they call register(tokenURI), **Then** an ERC-721 NFT is minted to their address with a unique agentId, and a Registered event is emitted containing the agentId, tokenURI, and owner address.

2. **Given** a successfully registered agent, **When** querying the NFT contract for the tokenURI of their agentId, **Then** the system returns the exact tokenURI string that was provided during registration.

---

### User Story 2 - Feedback Submission (Priority: P2)

A client agent that has paid for and consumed a service needs to submit feedback and ratings for the service provider. This feedback helps other clients make informed decisions.

**Why this priority**: Feedback is essential for building trust in the ecosystem, but the system can function for initial testing without it. It becomes critical as the network grows.

**Independent Test**: Can be fully tested by a client calling giveFeedback() with valid parameters (agentId, score, tags, feedbackAuth), verifying the feedback is stored, and confirming the NewFeedback event is emitted.

**Acceptance Scenarios**:

1. **Given** a client has a valid feedbackAuth signature from a service agent, **When** they call giveFeedback() with a score between 0-100 and relevant tags, **Then** the feedback is recorded on-chain and a NewFeedback event is emitted with the agentId, client address, score, and tags.

2. **Given** a client attempts to submit feedback without a valid feedbackAuth signature, **When** they call giveFeedback(), **Then** the transaction reverts with an authentication error.

---

### User Story 3 - Reputation Aggregation (Priority: P3)

The system needs to aggregate feedback data to provide a summary reputation score for any registered agent. This allows clients to compare agents based on historical feedback.

**Why this priority**: While useful for discovery, the basic contract functionality works without aggregation. This can be enhanced iteratively.

**Independent Test**: Can be tested by submitting multiple feedback entries for an agent, then calling getSummary(agentId) and verifying the returned count and average score include all feedback for that agent.

**Acceptance Scenarios**:

1. **Given** an agent has received feedback from multiple clients, **When** calling getSummary(agentId), **Then** the system returns the total feedback count and average score calculated from all submitted feedback for that agent.

---

### Edge Cases

- Empty tokenURI registration: System allows registration with empty tokenURI strings.
- Invalid feedback scores: Transactions revert when score > 100 (negative values prevented by uint8 data type).
- Non-existent agentId: giveFeedback() reverts when agentId does not exist.
- Expired feedbackAuth: Transactions revert when feedbackAuth signature has passed expiry timestamp.
- Zero feedback results: getSummary() returns count=0 and average=0 for agents with no feedback.
- NFT ownership transfer: Agent NFT transfers have no impact on existing feedback validity or reputation calculations. However, feedbackAuth signatures signed by previous owners become invalid after transfer (only current owner's signatures are accepted).
- Client index at limit: When a client's feedback index equals indexLimit, feedback submission reverts (indexLimit is exclusive upper bound).
- Multiple feedbackAuth: A client can hold multiple feedbackAuth signatures with different indexLimits; the contract validates against the provided signature's indexLimit.
- Client index persistence: Client feedback indices persist across all feedback submissions and cannot be reset or decremented.
- Repeated client feedback: When a client submits multiple feedbacks to the same agent, each feedback is stored separately and all contribute equally to the reputation average (no special handling or deduplication).

## Requirements *(mandatory)*

### Functional Requirements

#### Identity Registry (StrategyRegistry)

- **FR-001**: System MUST provide a register() function that accepts a tokenURI string parameter (including empty strings) and returns a unique numeric agentId
- **FR-002**: System MUST mint an ERC-721 NFT to the caller's address upon successful registration, where the tokenId equals the agentId
- **FR-003**: System MUST store the tokenURI metadata reference for each registered agent using ERC-721 tokenURI storage
- **FR-004**: System MUST emit a Registered event containing the agentId, tokenURI, and owner address after successful registration
- **FR-005**: System MUST increment agentIds sequentially starting from 1 (or 0 based on implementation preference)
- **FR-006**: System MUST support standard ERC-721 ownership transfer functions (transfer, approve, etc.)
- **FR-007**: System MUST allow anyone to query the tokenURI for any registered agentId

#### Reputation Registry (StrategyReputation)

- **FR-008**: System MUST provide a giveFeedback() function accepting parameters: agentId, score (0-100), tag1, tag2, fileuri, filehash, and feedbackAuth signature
- **FR-009**: System MUST verify the feedbackAuth signature using EIP-712 structured data format with proper domain separator and type hashing before accepting feedback
- **FR-023**: System MUST recover the signer address from the feedbackAuth signature (65 bytes appended to encoded struct fields) and verify it matches the current owner of the agentId NFT
- **FR-010**: System MUST store feedback with the submitter's address, score, tags, and timestamp for each agentId
- **FR-011**: System MUST emit a NewFeedback event after successfully storing feedback, containing agentId, clientAddress, score, tag1, tag2, fileuri, and filehash
- **FR-012**: System MUST provide a getSummary() function that accepts only agentId as parameter
- **FR-013**: System MUST calculate and return the total count of all feedback entries and the average score (as uint8) for the given agentId when getSummary() is called (average calculated as: sum of all scores / count, returning 0 when count is 0). Each feedback from every client is counted independently, including multiple feedbacks from the same client.
- **FR-014**: System MUST reject feedback submissions with scores greater than 100
- **FR-019**: System MUST reject feedback submissions for non-existent agentIds
- **FR-015**: System MUST validate that feedbackAuth signatures include agentId, clientAddress, indexLimit, expiry timestamp, and chainId
- **FR-020**: System MUST maintain a separate feedback index counter for each clientAddress per agentId
- **FR-021**: System MUST reject feedback submissions when the client's current feedback index for that agentId is greater than or equal to the indexLimit specified in the feedbackAuth
- **FR-022**: System MUST increment the client's feedback index for that agentId by 1 after successfully storing feedback
- **FR-016**: System MUST reject feedbackAuth signatures that have passed their expiry timestamp
- **FR-017**: System MUST reject feedbackAuth signatures with incorrect chainId
- **FR-018**: System MUST store a reference to the StrategyRegistry (identity registry) contract address during deployment

### Key Entities

- **Agent**: A registered service provider represented as an ERC-721 NFT with a unique agentId, owned by a wallet address, with associated metadata stored at a tokenURI (IPFS/HTTPS URL)

- **Agent Metadata**: Off-chain JSON file containing agent name, description, tags (array of plain strings like ["memecoin", "trading"]), endpoints (array of endpoint objects), and supportedTrust mechanisms - referenced by tokenURI

- **Feedback**: On-chain record of a client's evaluation of an agent, containing: score (0-100), two tags (bytes32 format: UTF-8 encoded strings right-padded with zeros), client address, timestamp, optional fileuri and filehash for detailed feedback. Tags are stored and emitted in events but not used in on-chain reputation calculations.

- **FeedbackAuth**: An EIP-712 structured cryptographic signature generated by the agent NFT owner authorizing a specific client to submit feedback up to a certain threshold. Structure: abi.encode(struct fields: agentId, clientAddress, indexLimit, expiry, chainId) + 65-byte signature. Only the current owner of the agentId NFT can create valid feedbackAuth signatures. This allows batch authorization of multiple feedback submissions without requiring new signatures for each one.

- **Client Feedback Index**: A per-client-per-agent counter tracking how many feedbacks a specific client has submitted to a specific agent. Starts at 0 for each new client-agent pair and increments by 1 after each successful feedback submission. Used to enforce indexLimit authorization.

- **Reputation Summary**: Aggregated view of feedback data for an agent, calculated on-demand, containing total feedback count and average score for all feedback submitted to that agent

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Service agents can successfully register and receive a unique on-chain identity within a single transaction
- **SC-002**: Any wallet can query and retrieve the metadata URI for any registered agent without additional permissions
- **SC-003**: Clients with valid authorization can submit feedback that is permanently recorded on-chain and publicly verifiable
- **SC-004**: Unauthorized feedback submission attempts are rejected 100% of the time, preventing spam and fake reviews
- **SC-005**: Reputation summaries accurately reflect all submitted feedback with correct count and average score calculations
- **SC-006**: The system provides basic aggregation of all feedback for any agentId without filtering capabilities
- **SC-007**: All registration and feedback events are emitted correctly, enabling off-chain indexing services to build discovery APIs
- **SC-008**: The contracts comply with ERC-721 standard for the identity registry, ensuring compatibility with existing NFT tooling and wallets

## Scope

### In Scope

- ERC-721-based identity registry for agent registration
- Feedback submission with cryptographic authorization (feedbackAuth)
- On-chain storage of feedback scores, tags, and timestamps
- Basic reputation aggregation by agentId (no filtering)
- Event emission for off-chain indexing (Registered, NewFeedback)
- EIP-191 and ERC-1271 signature verification for feedbackAuth
- Basic access control (only authorized clients can submit feedback)

### Out of Scope

- Feedback revocation functionality (deferred post-MVP)
- Agent response to feedback (deferred post-MVP)
- Multi-chain support (Base Sepolia only for MVP)
- Metadata validation or parsing on-chain
- Payment processing logic (handled by separate X402 layer)
- WebSocket or API server implementation (handled by off-chain services)
- Indexer implementation (separate Ponder service)
- Client and service agent implementation (separate components)
- Dispute resolution mechanisms
- Staking or slashing for reputation manipulation prevention
- Upgradability patterns for contracts

## Assumptions

- The tokenURI provided during registration points to valid JSON metadata conforming to the expected schema (system does not validate metadata on-chain)
- Agent NFT owners will generate and distribute feedbackAuth signatures off-chain to paying clients
- The feedbackAuth structure is: abi.encode(struct fields) + 65-byte signature, where struct fields are (agentId, clientAddress, indexLimit, expiry, chainId)
- Only the current owner of the agent NFT has authority to sign valid feedbackAuth signatures
- Each client maintains a separate feedback index per agent (starting at 0)
- Service agents can authorize multiple feedback submissions by setting indexLimit to allow N feedbacks (e.g., indexLimit = 5 allows the client to submit feedback until their index reaches 5)
- Agents typically set indexLimit based on the client's current index plus the number of authorized submissions (e.g., currentClientIndex + N)
- Gas costs for on-chain feedback storage are acceptable for the MVP use case
- Base Sepolia testnet provides sufficient performance and reliability for initial testing
- ERC-721 standard implementation is sufficient for agent identity (no ERC-1155 or custom extensions needed)
- Feedback scores are on a 0-100 scale with integer precision
- Feedback tags are represented as bytes32 values (UTF-8 encoded strings right-padded with zeros, up to 32 characters)
- Feedback tags are used only for event emission and off-chain indexing, not for on-chain reputation calculations
- Agent metadata tags in tokenURI JSON are plain string arrays
- Multiple feedbacks from the same client to the same agent are all counted independently in reputation calculations (no deduplication or overwriting)
- The identity registry address is immutable once the reputation contract is deployed
- Clients understand and accept that feedback is permanent and cannot be deleted

## Dependencies

- Base Sepolia testnet infrastructure and RPC endpoints
- OpenZeppelin Contracts library for ERC-721 implementation (ERC721URIStorage)
- OpenZeppelin Contracts library for EIP-712 signature verification utilities
- Solidity compiler version 0.8.x or higher
- Ethereum wallet infrastructure for transaction signing
- IPFS or HTTPS hosting for agent metadata files (tokenURI endpoints)
- Off-chain indexer service (Ponder) to consume emitted events
- Off-chain facilitator service (X402) for payment verification

## Reference Implementation

- ERC-8004 Reputation Registry Reference: https://raw.githubusercontent.com/ChaosChain/trustless-agents-erc-ri/refs/heads/main/src/ReputationRegistry.sol

## Risks

- **Smart Contract Security**: Vulnerabilities in signature verification could allow unauthorized feedback submission
- **Gas Costs**: On-chain feedback storage may become expensive at scale
- **Feedback Spam**: Without rate limiting, authorized clients could submit excessive feedback
- **Signature Replay**: If feedbackAuth signatures are not properly validated (expiry, chainId), they could be replayed
- **Metadata Availability**: If tokenURI endpoints go offline, agent metadata becomes unavailable
- **Reputation Gaming**: Agents could create multiple fake clients to submit positive feedback (indexLimit in feedbackAuth mitigates this)
- **Upgrade Path**: Without upgradability, fixing bugs requires full redeployment and data migration

## Success Validation

The feature will be considered successfully implemented when:

1. A service agent can call register(tokenURI) and receive an agentId, with the NFT appearing in their wallet
2. The Registered event is emitted with correct data and can be captured by an off-chain listener
3. A client with a valid feedbackAuth can call giveFeedback() and see their feedback recorded on-chain
4. Invalid feedbackAuth signatures are rejected with appropriate error messages
5. getSummary(agentId) returns accurate feedback counts and average scores for registered agents
6. Multiple agents can register independently without conflicts
7. Multiple clients can submit feedback for the same agent
8. A single client can submit multiple feedbacks to the same agent using one feedbackAuth (until indexLimit is reached)
9. The client feedback index mechanism correctly enforces indexLimit boundaries and increments after each submission
10. The contracts pass security audits for signature verification and access control
11. The contracts are deployed to Base Sepolia and verified on block explorers
