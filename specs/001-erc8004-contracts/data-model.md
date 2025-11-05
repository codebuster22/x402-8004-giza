# Data Model: ERC-8004 Smart Contracts

**Feature**: 001-erc8004-contracts | **Date**: 2025-11-05

## Overview

This document defines the on-chain data structures, state variables, and relationships for the StrategyRegistry and StrategyReputation contracts.

---

## StrategyRegistry (Identity Registry)

### Contract Metadata

- **Name**: "Strategy Agent"
- **Symbol**: "STRATEGY-AGENT"
- **Base**: ERC721URIStorage (OpenZeppelin)
- **Chain**: Base Sepolia (chainId: 84532)

### State Variables

```solidity
// Inherited from ERC721
mapping(uint256 => address) private _owners;           // agentId => owner address
mapping(address => uint256) private _balances;         // owner => NFT count
mapping(uint256 => address) private _tokenApprovals;   // agentId => approved address
mapping(address => mapping(address => bool)) private _operatorApprovals;  // owner => operator => approved

// Inherited from ERC721URIStorage
mapping(uint256 => string) private _tokenURIs;         // agentId => metadata URI

// Custom
uint256 private _nextAgentId;                          // Counter for agent IDs (starts at 1)
```

### Entity: Agent (NFT)

```solidity
// Represented as ERC-721 token
// No explicit struct - data distributed across inherited mappings

// Derived properties (via functions):
uint256 agentId;          // Token ID (unique identifier)
address owner;            // Current NFT owner (ownerOf function)
string tokenURI;          // IPFS/HTTPS URI to metadata JSON (tokenURI function)
```

### Validation Rules

| Rule | Description | Enforcement |
|------|-------------|-------------|
| Unique agentId | Each agentId is unique and sequential | Enforced by _nextAgentId counter increment |
| Owner required | Every agent has exactly one owner | Enforced by ERC-721 standard (_safeMint) |
| tokenURI format | Can be any string (including empty) | No validation (per spec clarification) |
| Transfer allowed | Agents can be transferred like NFTs | Standard ERC-721 transfer functions |

### State Transitions

```
[Unregistered] --register()--> [Registered]
     │                              │
     │                              ├─ transfer() -> [Registered with new owner]
     │                              │
     │                              └─ burn() -> [Burned] (if implemented)
```

### Events

```solidity
event Registered(
    uint256 indexed agentId,  // Newly minted agent ID
    string tokenURI,          // Metadata URI (not indexed - can be large)
    address indexed owner     // Agent owner (msg.sender)
);

// Inherited from ERC-721:
event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
```

---

## StrategyReputation (Reputation Registry)

### Contract Metadata

- **EIP-712 Domain**:
  - name: "StrategyReputation"
  - version: "1"
  - chainId: 84532 (Base Sepolia)
  - verifyingContract: (deployed address)

### State Variables

```solidity
// Registry reference (immutable)
IStrategyRegistry public immutable identityRegistry;

// Client feedback indices
mapping(uint256 => mapping(address => uint256)) private _clientIndices;
// agentId => (clientAddress => currentIndex)

// Reputation aggregation
struct AgentReputation {
    uint64 feedbackCount;   // Total number of feedbacks received
    uint256 totalScore;     // Sum of all scores (for average calculation)
}
mapping(uint256 => AgentReputation) private _reputations;

// Feedback storage
struct Feedback {
    address clientAddress;  // Who gave the feedback
    uint8 score;            // 0-100 rating
    bytes32 tag1;           // UTF-8 encoded tag (indexed in event)
    bytes32 tag2;           // UTF-8 encoded tag (not indexed)
    string fileuri;         // Optional URI to detailed feedback file
    bytes32 filehash;       // Optional hash of feedback file
    uint40 timestamp;       // When feedback was submitted (block.timestamp)
}
mapping(uint256 => Feedback[]) private _feedbacks;
// agentId => array of all feedback entries

// EIP-712 type hash (constant)
bytes32 private constant FEEDBACK_AUTH_TYPEHASH = keccak256(
    "FeedbackAuth(uint256 agentId,address clientAddress,uint256 indexLimit,uint256 expiry,uint256 chainId)"
);
```

### Entity: Feedback

```solidity
struct Feedback {
    address clientAddress;  // bytes20
    uint8 score;            // 1 byte (0-100)
    bytes32 tag1;           // 32 bytes (UTF-8 string right-padded)
    bytes32 tag2;           // 32 bytes (UTF-8 string right-padded)
    string fileuri;         // Variable length (IPFS CID or HTTPS URL)
    bytes32 filehash;       // 32 bytes (keccak256 of file content)
    uint40 timestamp;       // 5 bytes (sufficient until year 36,812)
}
// Total: ~133 bytes + fileuri length
```

### Entity: ClientIndex

```solidity
// Represented as nested mapping value (no struct)
uint256 currentIndex;  // How many feedbacks this client has submitted to this agent
```

### Entity: AgentReputation

```solidity
struct AgentReputation {
    uint64 feedbackCount;   // 8 bytes (max 18 quintillion feedbacks)
    uint256 totalScore;     // 32 bytes (sum for average calculation)
}
// Total: 40 bytes per agent
```

### Entity: FeedbackAuth (Off-chain, validated on-chain)

```solidity
// Not stored on-chain, passed as function parameter
struct FeedbackAuth {
    uint256 agentId;           // Which agent this authorizes feedback for
    address clientAddress;     // Which client is authorized
    uint256 indexLimit;        // Maximum index client can reach
    uint256 expiry;            // Timestamp when authorization expires
    uint256 chainId;           // Must match block.chainid
    bytes signature;           // 65 bytes (r, s, v) - EIP-712 signature
}

// Encoded as: abi.encode(struct fields) + signature (65 bytes)
```

### Validation Rules

| Rule | Description | Enforcement |
|------|-------------|-------------|
| Score bounds | 0 ≤ score ≤ 100 | `require(score <= 100)` or custom error |
| Agent exists | agentId must be registered | Call identityRegistry.ownerOf() (reverts if not exists) |
| Index limit | currentIndex < indexLimit | `require(_clientIndices[agentId][msg.sender] < indexLimit)` |
| Signature expiry | block.timestamp ≤ expiry | `require(block.timestamp <= expiry)` |
| Chain ID match | feedbackAuth.chainId == block.chainid | Encoded in EIP-712 struct hash |
| Signer authority | signer == agentOwner | `require(signer == identityRegistry.ownerOf(agentId))` |
| Tags format | bytes32 (UTF-8) | No validation (client responsibility) |

### State Transitions

```
Client Index:
[0] --giveFeedback()--> [1] --giveFeedback()--> [2] ... --> [indexLimit-1] --giveFeedback()--> [BLOCKED]

Agent Reputation:
[count=0, total=0] --giveFeedback(score=85)--> [count=1, total=85]
                   --giveFeedback(score=90)--> [count=2, total=175]
                   --giveFeedback(score=80)--> [count=3, total=255]
                   ... (continuous accumulation)

Feedback Storage:
feedbacks[agentId] = []
--giveFeedback()--> feedbacks[agentId] = [Feedback1]
--giveFeedback()--> feedbacks[agentId] = [Feedback1, Feedback2]
--giveFeedback()--> feedbacks[agentId] = [Feedback1, Feedback2, Feedback3]
... (append-only array)
```

### Events

```solidity
event NewFeedback(
    uint256 indexed agentId,       // Which agent received feedback
    address indexed clientAddress, // Who gave the feedback
    uint8 score,                    // Rating (0-100)
    bytes32 indexed tag1,           // Primary tag (indexed for filtering)
    bytes32 tag2,                   // Secondary tag (not indexed)
    string fileuri,                 // Optional detailed feedback URI
    bytes32 filehash                // Optional file content hash
);
// Note: timestamp not in event (use block.timestamp from event metadata)
```

---

## Relationships

### Cross-Contract Dependencies

```
StrategyReputation --> IStrategyRegistry
    - constructor parameter: address _identityRegistry
    - function calls: ownerOf(agentId) for signer verification
    - immutable reference (set once in constructor)
```

### Data Dependencies

```
Agent (NFT in StrategyRegistry)
    |
    ├─ 1:N with Feedback entries (in StrategyReputation)
    |       Each agent can have 0..N feedback entries
    |
    └─ 1:N with ClientIndex mappings (in StrategyReputation)
            Each agent has 0..N unique client indices

Client Address (EOA or contract)
    |
    ├─ 1:N with Feedback entries (as clientAddress)
    |       Each client can give feedback to multiple agents
    |
    └─ 1:1 with ClientIndex per agent
            Each client has exactly one index per agent

AgentReputation
    |
    └─ 1:1 with Agent (agentId)
            Each agent has exactly one reputation summary
```

### Event Indexing (for off-chain Indexer)

```
StrategyRegistry.Registered event
    ↓
Indexer stores: agentId, tokenURI, owner
Indexer fetches: metadata from tokenURI (name, description, tags, endpoints)
    ↓
Builds searchable agent registry

StrategyReputation.NewFeedback event
    ↓
Indexer stores: agentId, clientAddress, score, tag1, tag2, fileuri, filehash, timestamp
    ↓
Can call getSummary(agentId) for aggregate reputation
    ↓
Builds searchable feedback history with reputation scores
```

---

## Storage Layout Considerations

### Gas Optimization

**Struct Packing** (Feedback struct):
```solidity
// Packed layout (fits in 4 storage slots + dynamic string):
// Slot 1: address (20 bytes) + uint8 (1 byte) + padding (11 bytes)
// Slot 2: bytes32 tag1
// Slot 3: bytes32 tag2
// Slot 4: bytes32 filehash
// Slot 5: uint40 timestamp (5 bytes) + padding
// Slot 6+: string fileuri (dynamic)

// Total: ~6 slots + fileuri length
```

**AgentReputation Packing**:
```solidity
// Packed layout (fits in 2 slots):
// Slot 1: uint64 feedbackCount (8 bytes) + padding
// Slot 2: uint256 totalScore (32 bytes)

// Could optimize to 1 slot if count were uint32 and total were uint224:
// struct AgentReputation {
//     uint32 feedbackCount;  // 4 bytes (max 4 billion - still plenty)
//     uint224 totalScore;    // 28 bytes (max 100 * 4B = 400B fits easily)
// }
// Total: 1 slot (32 bytes)
```

### Storage Access Patterns

**Hot paths** (frequent reads/writes):
- `_clientIndices[agentId][msg.sender]` - read + write on every giveFeedback()
- `_reputations[agentId]` - read + write on every giveFeedback()
- `identityRegistry.ownerOf(agentId)` - external read on every giveFeedback()

**Cold paths** (rare reads):
- `_feedbacks[agentId]` - write-only (append), rarely read on-chain
- `getSummary(agentId)` - view function (no gas cost for external calls)

---

## Data Integrity Constraints

### Invariants

1. **Client Index Monotonicity**: Client indices only increase, never decrease or reset
   - `_clientIndices[agentId][client]` always increments by 1
   - No function to decrement or reset

2. **Reputation Consistency**: Reputation totals match individual feedback entries
   - `_reputations[agentId].feedbackCount == _feedbacks[agentId].length`
   - `_reputations[agentId].totalScore == sum(_feedbacks[agentId][*].score)`

3. **Agent Ownership**: Only current NFT owner can sign valid feedbackAuth
   - `ECDSA.recover(feedbackAuth) == identityRegistry.ownerOf(agentId)`

4. **Feedback Immutability**: Once submitted, feedback cannot be modified or deleted
   - No update or delete functions
   - Array is append-only

5. **Index Authorization**: Clients can only submit feedback within authorized range
   - `_clientIndices[agentId][client] < indexLimit` at submission time
   - Index increments after successful submission

### Boundary Conditions

| Condition | Handling |
|-----------|----------|
| Agent with 0 feedbacks | `getSummary()` returns `(0, 0)` |
| Client with index at limit | `giveFeedback()` reverts with IndexLimitExceeded |
| Expired feedbackAuth | `giveFeedback()` reverts with FeedbackAuthExpired |
| Score > 100 | `giveFeedback()` reverts with InvalidScore |
| Non-existent agentId | `ownerOf()` reverts (standard ERC-721 behavior) |
| Empty tokenURI | Allowed (per spec clarification) |
| Empty fileuri | Allowed (optional field) |

---

## Size Estimates

### Per-Agent Storage

- **StrategyRegistry**: ~1 NFT entry (~100 bytes ERC-721 data + tokenURI string length)
- **StrategyReputation**: ~40 bytes (AgentReputation struct)

### Per-Feedback Storage

- **Feedback struct**: ~133 bytes + fileuri length
- **Client index update**: 32 bytes (uint256 in mapping)
- **Reputation update**: No additional storage (updates existing AgentReputation)

### Projected Storage for MVP

Assumptions:
- 100 agents
- 10 feedbacks per agent on average
- Average tokenURI: 50 bytes (IPFS CID)
- Average fileuri: 50 bytes (IPFS CID)

**Total storage**:
- Registry: 100 agents * 150 bytes = 15 KB
- Reputation summaries: 100 agents * 40 bytes = 4 KB
- Feedbacks: 1000 feedbacks * 183 bytes = 183 KB
- Client indices: 1000 unique client-agent pairs * 32 bytes = 32 KB

**Grand total**: ~234 KB on-chain storage (well within limits for Base Sepolia)

---

## Summary

### StrategyRegistry

- **Primary storage**: ERC-721 NFT state (agentId, owner, tokenURI)
- **Key operations**: Mint (register), query (ownerOf, tokenURI), transfer (standard ERC-721)
- **Events**: Registered (for indexer), Transfer (standard ERC-721)

### StrategyReputation

- **Primary storage**: Feedback arrays, client indices, reputation summaries
- **Key operations**: Submit feedback (with signature verification), query summary (view)
- **Events**: NewFeedback (for indexer)
- **Dependencies**: IStrategyRegistry for owner verification

### Design Principles Applied

- ✅ **Simple data structures**: Standard mappings and structs
- ✅ **DRY**: Leverage OpenZeppelin implementations
- ✅ **Gas-efficient**: Running totals, packed structs, minimal iteration
- ✅ **Immutable feedback**: Append-only arrays
- ✅ **Type-safe**: Strong typing with custom errors

---

**Data Model Complete**: Ready for contract interface definitions and quickstart guide.
