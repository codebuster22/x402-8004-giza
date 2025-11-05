# ERC-8004 Implementation Guide

> **Purpose:** This guide helps developers understand how to implement ERC-8004 (Trustless Agents) for on-chain agent identity, discovery, and reputation. Designed for MVP/experimental projects to showcase how agents can be discovered and trusted without pre-existing relationships.

---

## Table of Contents

1. [What is ERC-8004?](#what-is-erc-8004)
2. [The Three Registry System](#the-three-registry-system)
3. [Project Architecture Context](#project-architecture-context)
4. [Identity Registry](#identity-registry)
5. [Reputation Registry](#reputation-registry)
6. [Validation Registry](#validation-registry)
7. [Registration → Discovery → Feedback Flow](#registration--discovery--feedback-flow)
8. [Deployment Considerations](#deployment-considerations)
9. [Minimal Implementation for MVP](#minimal-implementation-for-mvp)
10. [Implementation Examples](#implementation-examples)
11. [Indexer Integration](#indexer-integration)
12. [References](#references)

---

## What is ERC-8004?

**ERC-8004: Trustless Agents** is an Ethereum standard that enables AI agents to discover, authenticate, and interact with each other without centralized intermediaries or pre-existing trust relationships.

### The Problem

Existing agent communication protocols (MCP, A2A, OASF) enable agents to communicate, but they lack:
- **Discovery mechanism** - How do agents find each other?
- **Trust layer** - How do agents know which agents to trust?
- **Reputation system** - How is agent performance tracked?

### The Solution

ERC-8004 provides three lightweight on-chain registries:
1. **Identity Registry** - Agent discovery (who exists?)
2. **Reputation Registry** - Trust signals (who is reliable?)
3. **Validation Registry** - Independent verification (proof of work quality)

### Why It Matters

**For AI Agent Economies:**
- Agents can discover service providers programmatically
- Reputation creates trust without centralized gatekeepers
- Cross-organizational agent collaboration becomes possible
- Opens the door to autonomous agent marketplaces

**Key Features:**
- Agents are **ERC-721 NFTs** (immediately compatible with NFT infrastructure)
- **Censorship-resistant** identities stored on-chain
- **Portable reputation** that follows agents across chains
- **Open discovery** - anyone can query and filter agents

---

## The Three Registry System

ERC-8004 defines three registries that work together:

### 1. **Identity Registry** (Agent Discovery)

**Purpose:** Provides every agent with a unique, portable, on-chain identity.

**Key Concepts:**
- Each agent is an **ERC-721 NFT**
- `agentId` = `tokenId`
- **tokenURI** points to registration file (IPFS or HTTPS)
- Registration file contains agent metadata, endpoints, tags

**What It Enables:**
- Agents can be discovered by querying the registry
- Indexers can parse registration files and build searchable databases
- Agents have transferable ownership (NFT transfer = agent ownership change)

### 2. **Reputation Registry** (Trust Signals)

**Purpose:** Allows clients to post feedback and ratings on agents they've interacted with.

**Key Concepts:**
- Feedback includes a **score (0-100)** and optional tags
- Feedback requires **feedbackAuth** (agent pre-authorizes client to give feedback)
- Prevents spam: only authorized clients can submit feedback
- Aggregation functions: `getSummary()` returns average score and count

**What It Enables:**
- Clients can filter agents by reputation
- Agents with better ratings are more discoverable
- Trust emerges from real interactions, not marketing

### 3. **Validation Registry** (Work Verification)

**Purpose:** Independent validators can verify agent work quality through cryptographic proof.

**Key Concepts:**
- Validators submit verification results (0-100 score)
- Supports multiple trust models:
  - **Crypto-economic** (stake-secured re-execution)
  - **TEE attestation** (trusted execution environments)
  - **zkML proofs** (zero-knowledge machine learning)
- Optional for MVP but powerful for production systems

**What It Enables:**
- Third-party verification of agent outputs
- Stronger trust signals beyond self-reported reputation
- Differentiation between validation types (soft vs hard finality)

---

## Project Architecture Context

In your project, ERC-8004 components map to these contracts and services:

| ERC-8004 Component | Your Project Name | Purpose |
|-------------------|-------------------|---------|
| Identity Registry | **StrategyRegistry** | Service agents register here |
| Reputation Registry | **StrategyReputation** | Clients leave feedback here |
| Validation Registry | *(Skipped for MVP)* | Not implemented initially |
| Indexer | **Indexer (Ponder)** | Listens to events, builds discovery API |
| Agent (Buyer) | **Client Agent (Giza Agent)** | Discovers and connects to service agents |
| Agent (Seller) | **Service Agent (Memecoin Strategy)** | Provides signals, receives payments |

### How They Work Together

```
1. Service Agent registers in StrategyRegistry
   ↓ (emits Registered event)

2. Indexer catches event, fetches tokenURI, indexes agent data
   ↓ (stores: name, tags, endpoint, reputation)

3. Client Agent queries Indexer API
   - Filter by tags: ["memecoin", "trading"]
   - Filter by min reputation score: 80
   ↓

4. Indexer returns filtered list of Service Agents

5. Client Agent connects to selected Service Agent (X402 payment)

6. After interaction, Client Agent submits feedback to StrategyReputation
   ↓ (emits NewFeedback event)

7. Indexer updates agent reputation score
```

---

## Identity Registry

### Concepts

**Agents as ERC-721 NFTs:**
- Every agent is a unique NFT token
- `agentId` equals the ERC-721 `tokenId`
- Ownership = control over agent identity
- Transferable, tradeable, composable with NFT infrastructure

**Global Agent Identifier (CAIP-10 format):**
```
eip155:chainId:registryAddress:agentId
```

**Example:**
```
eip155:84532:0x1234567890abcdef1234567890abcdef12345678:42
```
This uniquely identifies agent #42 on Base Sepolia (chainId 84532).

**tokenURI:**
- Points to agent registration file
- Can be IPFS (`ipfs://Qm...`) or HTTPS (`https://example.com/agent.json`)
- Must follow ERC-8004 registration file format

---

### Interface Functions

#### `register(string calldata tokenURI, MetadataEntry[] calldata metadata)`

Registers a new agent with full metadata support.

**Parameters:**
- `tokenURI` - **[REQUIRED]** URL to agent registration file
- `metadata` - **[OPTIONAL]** Array of key-value pairs for on-chain metadata

**Returns:** `uint256 agentId` - The newly minted ERC-721 token ID

**Emits:** `Registered(uint256 indexed agentId, string tokenURI, address indexed owner)`

---

#### `register(string calldata tokenURI)`

Simplified registration with only tokenURI (recommended for MVP).

**Parameters:**
- `tokenURI` - **[REQUIRED]** URL to agent registration file

**Returns:** `uint256 agentId`

---

#### `register()`

Placeholder registration with no initial URI (rarely used).

**Returns:** `uint256 agentId`

---

#### `getMetadata(uint256 agentId, string calldata key)` / `setMetadata(...)`

**Purpose:** Optional on-chain metadata storage (e.g., "agentWallet", "agentName")

**For MVP:** Can be **skipped entirely** - use registration file instead.

---

### Events

```solidity
/// MUST emit on registration
event Registered(
    uint256 indexed agentId,
    string tokenURI,
    address indexed owner
);

/// OPTIONAL - emit when on-chain metadata is set
event MetadataSet(
    uint256 indexed agentId,
    string indexed indexedKey,
    string key,
    bytes value
);
```

**Why Events Matter:**
- Indexer listens for `Registered` events
- Extracts `tokenURI`, fetches registration file, indexes agent
- Enables real-time discovery of new agents

---

### Agent Registration File Format

The `tokenURI` must resolve to a JSON file with this structure:

```json
{
  "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  "name": "Memecoin Trading Strategy Agent",
  "description": "Provides trading signals for memecoins with 80% accuracy",
  "image": "https://example.com/agent-avatar.png",
  "tags": ["memecoin", "trading", "signals", "defi"],
  "endpoints": [
    {
      "name": "A2A",
      "endpoint": "https://agent.example.com/.well-known/agent-card.json",
      "version": "0.3.0"
    },
    {
      "name": "agentWallet",
      "endpoint": "eip155:84532:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7"
    }
  ],
  "registrations": [
    {
      "agentId": 1,
      "agentRegistry": "eip155:84532:0x1234567890abcdef1234567890abcdef12345678"
    }
  ],
  "supportedTrust": ["reputation"]
}
```

#### Field Descriptions

| Field | Required? | Description |
|-------|-----------|-------------|
| `type` | **REQUIRED** | Must be the ERC-8004 schema URL |
| `name` | **REQUIRED** | Human-readable agent name |
| `description` | **REQUIRED** | What the agent does, pricing, interaction methods |
| `image` | OPTIONAL | Avatar/logo URL |
| `tags` | **STRONGLY RECOMMENDED** | Array of keywords for discovery/filtering |
| `endpoints` | **REQUIRED** | Array of communication endpoints (A2A, MCP, wallet, etc.) |
| `registrations` | OPTIONAL | Other chains where agent is registered |
| `supportedTrust` | OPTIONAL | Trust models supported (reputation, crypto-economic, tee) |

**Critical for Discovery: `tags` field**

Tags enable filtering in Indexer:
```javascript
// Example: Client queries Indexer
GET /agents?tags=memecoin,trading&minReputation=80
```

---

### Full Interface

```solidity
/// @title ERC-8004 Identity Registry Interface
interface IIdentityRegistry is IERC721 {

    struct MetadataEntry {
        string key;
        bytes value;
    }

    /// @notice Register agent with tokenURI and optional metadata
    function register(
        string calldata tokenURI,
        MetadataEntry[] calldata metadata
    ) external returns (uint256 agentId);

    /// @notice Register agent with only tokenURI (recommended for MVP)
    function register(string calldata tokenURI) external returns (uint256 agentId);

    /// @notice Register agent with no parameters (placeholder)
    function register() external returns (uint256 agentId);

    /// @notice Get on-chain metadata for agent (optional feature)
    function getMetadata(uint256 agentId, string calldata key) external view returns (bytes memory);

    /// @notice Set on-chain metadata for agent (optional feature)
    function setMetadata(uint256 agentId, string calldata key, bytes calldata value) external;

    /// @notice MUST emit on registration
    event Registered(uint256 indexed agentId, string tokenURI, address indexed owner);

    /// @notice OPTIONAL - emit when metadata is set
    event MetadataSet(
        uint256 indexed agentId,
        string indexed indexedKey,
        string key,
        bytes value
    );
}
```

---

## Reputation Registry

### Concepts

**Purpose:** Track feedback from clients who have interacted with agents.

**Key Mechanism: feedbackAuth**

Agents **pre-authorize** specific clients to submit feedback. This prevents spam and Sybil attacks.

**feedbackAuth Structure:**
```
(
  uint256 agentId,
  address clientAddress,
  uint64 indexLimit,        // Max number of feedbacks client can submit
  uint40 expiry,            // Timestamp when auth expires
  uint256 chainId,
  address identityRegistry,
  address signerAddress     // Agent's signer
)
```

**How It Works:**
1. Service Agent generates feedbackAuth signature (EIP-191 or ERC-1271)
2. Service Agent sends feedbackAuth to Client Agent (off-chain or in payment flow)
3. Client Agent calls `giveFeedback()` with feedbackAuth
4. Reputation Registry verifies signature and authorization
5. If valid, feedback is recorded and `NewFeedback` event emitted

**Verification Rules:**
- Signature must be valid (EIP-191/ERC-1271)
- Current block timestamp < `expiry`
- Client's current feedback count < `indexLimit`
- `chainId` and `identityRegistry` match current deployment

---

### Interface Functions

#### `giveFeedback(...)`

Submit feedback for an agent.

```solidity
function giveFeedback(
    uint256 agentId,        // [REQUIRED] Agent being rated
    uint8 score,            // [REQUIRED] Rating 0-100
    bytes32 tag1,           // [OPTIONAL] Category tag
    bytes32 tag2,           // [OPTIONAL] Secondary tag
    string calldata fileuri, // [OPTIONAL] Off-chain feedback file
    bytes32 filehash,       // [OPTIONAL] Hash for file integrity
    bytes memory feedbackAuth // [REQUIRED] Signed authorization
) external;
```

**Emits:** `NewFeedback(uint256 indexed agentId, address indexed clientAddress, uint8 score, bytes32 indexed tag1, bytes32 tag2, string fileuri, bytes32 filehash)`

---

#### `getSummary(...)`

Get aggregated reputation statistics.

```solidity
function getSummary(
    uint256 agentId,               // [REQUIRED]
    address[] calldata clientAddresses, // [OPTIONAL] Filter by clients
    bytes32 tag1,                  // [OPTIONAL] Filter by tag
    bytes32 tag2                   // [OPTIONAL] Filter by tag
) external view returns (
    uint64 count,
    uint8 averageScore
);
```

**Example:**
```solidity
// Get overall reputation for agent #1
(uint64 count, uint8 avgScore) = reputationRegistry.getSummary(1, new address[](0), bytes32(0), bytes32(0));
// count = 15, avgScore = 87
```

---

#### `readFeedback(...)` / `readAllFeedback(...)`

Read individual or batch feedback entries.

```solidity
function readFeedback(
    uint256 agentId,
    address clientAddress,
    uint64 index
) external view returns (
    uint8 score,
    bytes32 tag1,
    bytes32 tag2,
    bool isRevoked
);

function readAllFeedback(
    uint256 agentId,
    address[] calldata clientAddresses,
    bytes32 tag1,
    bytes32 tag2,
    bool includeRevoked
) external view returns (
    address[] memory clientAddresses,
    uint8[] memory scores,
    bytes32[] memory tag1s,
    bytes32[] memory tag2s,
    bool[] memory revokedStatuses
);
```

---

#### `revokeFeedback(...)` / `appendResponse(...)`

**For MVP:** These can be **skipped**.

- `revokeFeedback()` - Allows client to withdraw feedback
- `appendResponse()` - Allows agent or third party to respond to feedback

---

### Events

```solidity
/// MUST emit on feedback submission
event NewFeedback(
    uint256 indexed agentId,
    address indexed clientAddress,
    uint8 score,
    bytes32 indexed tag1,
    bytes32 tag2,
    string fileuri,
    bytes32 filehash
);

/// OPTIONAL for MVP
event FeedbackRevoked(
    uint256 indexed agentId,
    address indexed clientAddress,
    uint64 indexed feedbackIndex
);

/// OPTIONAL for MVP
event ResponseAppended(
    uint256 indexed agentId,
    address indexed clientAddress,
    uint64 feedbackIndex,
    address indexed responder,
    string responseUri
);
```

---

### Feedback File Format (Optional, Off-Chain)

If `fileuri` is provided, it should resolve to:

```json
{
  "agentRegistry": "eip155:84532:0x123...abc",
  "agentId": 1,
  "clientAddress": "eip155:84532:0x456...def",
  "createdAt": "2025-11-05T10:30:00Z",
  "feedbackAuth": "0x...",
  "score": 95,
  "tag1": "trading",
  "tag2": "accurate",
  "skill": "Memecoin signal generation",
  "context": "Used for 2 weeks, 15 signals total",
  "task": "Provide buy/sell signals for DOGE, SHIB, PEPE",
  "capability": "High frequency trading signals",
  "proof_of_payment": {
    "fromAddress": "0x456...def",
    "toAddress": "0x789...ghi",
    "chainId": "84532",
    "txHash": "0xabc...123"
  }
}
```

---

### Full Interface

```solidity
/// @title ERC-8004 Reputation Registry Interface
interface IReputationRegistry {

    /// @notice Returns the linked identity registry address
    function getIdentityRegistry() external view returns (address);

    /// @notice Submit feedback for an agent
    function giveFeedback(
        uint256 agentId,
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        string calldata fileuri,
        bytes32 filehash,
        bytes memory feedbackAuth
    ) external;

    /// @notice Revoke previously submitted feedback (optional for MVP)
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;

    /// @notice Append response to feedback (optional for MVP)
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string calldata responseUri,
        bytes32 responseHash
    ) external;

    /// @notice Get aggregated reputation summary
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        bytes32 tag1,
        bytes32 tag2
    ) external view returns (uint64 count, uint8 averageScore);

    /// @notice Read a specific feedback entry
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64 index
    ) external view returns (
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        bool isRevoked
    );

    /// @notice Read all feedback for an agent with filters
    function readAllFeedback(
        uint256 agentId,
        address[] calldata clientAddresses,
        bytes32 tag1,
        bytes32 tag2,
        bool includeRevoked
    ) external view returns (
        address[] memory clientAddresses,
        uint8[] memory scores,
        bytes32[] memory tag1s,
        bytes32[] memory tag2s,
        bool[] memory revokedStatuses
    );

    /// @notice MUST emit on feedback submission
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint8 score,
        bytes32 indexed tag1,
        bytes32 tag2,
        string fileuri,
        bytes32 filehash
    );

    /// @notice OPTIONAL - emit on feedback revocation
    event FeedbackRevoked(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 indexed feedbackIndex
    );

    /// @notice OPTIONAL - emit when response is appended
    event ResponseAppended(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        address indexed responder,
        string responseUri
    );
}
```

---

## Validation Registry

**Note:** This registry is **OPTIONAL for MVP** and can be skipped entirely. Including here for completeness.

### Purpose

Independent validators verify agent work quality through cryptographic proof.

### Concepts

**Three Trust Models:**
1. **Reputation** - Social consensus from client feedback
2. **Crypto-economic** - Stake-secured re-execution by validators
3. **TEE attestation** - Trusted Execution Environment proofs
4. **zkML** - Zero-knowledge machine learning proofs

### Key Functions

```solidity
interface IValidationRegistry {

    /// @notice Request validation from a validator
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestUri,
        bytes32 requestHash
    ) external;

    /// @notice Submit validation result
    function validationResponse(
        bytes32 requestHash,
        uint8 response,          // 0-100 score
        string calldata responseUri,
        bytes32 responseHash,
        bytes32 tag              // e.g., "soft-finality" vs "hard-finality"
    ) external;

    /// @notice Get validation status
    function getValidationStatus(
        bytes32 requestHash,
        address validatorAddress
    ) external view returns (
        uint256 agentId,
        uint8 response,
        uint40 lastUpdate,
        bytes32 tag
    );

    event ValidationRequest(
        bytes32 indexed requestHash,
        address indexed validatorAddress,
        uint256 indexed agentId,
        string requestUri
    );

    event ValidationResponse(
        bytes32 indexed requestHash,
        address indexed validatorAddress,
        uint256 indexed agentId,
        uint8 response,
        bytes32 tag
    );
}
```

---

## Registration → Discovery → Feedback Flow

### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: Service Agent Registration                              │
└─────────────────────────────────────────────────────────────────┘
Service Agent
    │
    ├─> Uploads registration file to IPFS
    │   (name, description, tags, endpoints)
    │
    └─> Calls StrategyRegistry.register(tokenURI)
        ├─> Mints ERC-721 NFT (agentId = tokenId)
        └─> Emits: Registered(agentId, tokenURI, owner)

┌─────────────────────────────────────────────────────────────────┐
│ Step 2: Indexer Indexes Agent                                   │
└─────────────────────────────────────────────────────────────────┘
Indexer (Ponder)
    │
    ├─> Listens to Registered event
    ├─> Fetches tokenURI (IPFS or HTTPS)
    ├─> Parses registration file
    │   - Extract: name, description, tags, endpoints
    ├─> Stores in database
    └─> Builds searchable API

┌─────────────────────────────────────────────────────────────────┐
│ Step 3: Client Agent Discovery                                  │
└─────────────────────────────────────────────────────────────────┘
Client Agent (Giza Agent)
    │
    └─> Queries Indexer API
        GET /agents?tags=memecoin,trading&minReputation=80
        │
        └─> Indexer returns:
            [
              {
                "agentId": 1,
                "name": "Memecoin Trader",
                "endpoint": "https://service-agent.com",
                "reputation": { "count": 15, "average": 87 },
                "tags": ["memecoin", "trading"]
              }
            ]

┌─────────────────────────────────────────────────────────────────┐
│ Step 4: Client Agent Interacts with Service Agent              │
└─────────────────────────────────────────────────────────────────┘
Client Agent → Service Agent
    │
    ├─> POST /sessions (X402 payment flow)
    ├─> Receives session key
    ├─> Establishes WebSocket connection
    └─> Receives trading signals

┌─────────────────────────────────────────────────────────────────┐
│ Step 5: Client Agent Submits Feedback                          │
└─────────────────────────────────────────────────────────────────┘
Client Agent
    │
    └─> Calls StrategyReputation.giveFeedback(
            agentId: 1,
            score: 95,
            tag1: "trading",
            tag2: "accurate",
            feedbackAuth: <signature>
        )
        └─> Emits: NewFeedback(agentId, clientAddress, score, tags...)

┌─────────────────────────────────────────────────────────────────┐
│ Step 6: Indexer Updates Reputation                             │
└─────────────────────────────────────────────────────────────────┘
Indexer
    │
    ├─> Listens to NewFeedback event
    ├─> Queries StrategyReputation.getSummary(agentId)
    ├─> Updates agent reputation in database
    │   - Old: count=15, avg=87
    │   - New: count=16, avg=88
    └─> Future queries return updated reputation
```

---

## Deployment Considerations

### Singleton Per Chain Model

ERC-8004 registries are deployed as **singletons** on each chain:
- One Identity Registry per chain
- One Reputation Registry per chain (linked to Identity Registry)
- One Validation Registry per chain (optional)

**For This Project:**
- Deploy on **Base Sepolia** (testnet)
- ChainId: `84532`

### Contract Deployment Order

1. **Deploy Identity Registry (StrategyRegistry)**
   - No constructor dependencies
   - Inherits from ERC721URIStorage

2. **Deploy Reputation Registry (StrategyReputation)**
   - Constructor requires: `address identityRegistry`

3. **Record Addresses**
   ```
   StrategyRegistry: 0x1234...
   StrategyReputation: 0x5678...
   ```

4. **Configure Indexer**
   - Point to deployed contract addresses
   - Listen to events starting from deployment block

---

## Minimal Implementation for MVP

### What to Implement

#### ✅ Identity Registry (StrategyRegistry)

**Must implement:**
- `register(string tokenURI)` function
- Emit `Registered` event with `agentId`, `tokenURI`, `owner`
- Inherit from `ERC721URIStorage`

**Can skip:**
- `getMetadata()` / `setMetadata()` functions
- `MetadataSet` event
- Multi-parameter `register()` variants

#### ✅ Reputation Registry (StrategyReputation)

**Must implement:**
- `giveFeedback()` function
- `getSummary()` function
- feedbackAuth verification (EIP-191/ERC-1271)
- Emit `NewFeedback` event

**Can skip:**
- `revokeFeedback()` function
- `appendResponse()` function
- `FeedbackRevoked` and `ResponseAppended` events

#### ✅ Agent Registration File

**Must include:**
- `type`, `name`, `description`
- `endpoints` array with at least one endpoint
- **`tags` array** (critical for discovery)

**Can omit:**
- `image`
- `registrations`
- `supportedTrust`

#### ❌ Validation Registry

**Skip entirely for MVP** - not needed to demonstrate discovery and reputation.

---

### Simplified Contract Interfaces for MVP

```solidity
// StrategyRegistry.sol (Minimal)
contract StrategyRegistry is ERC721URIStorage {
    uint256 private _nextAgentId = 1;

    event Registered(uint256 indexed agentId, string tokenURI, address indexed owner);

    function register(string memory tokenURI) external returns (uint256) {
        uint256 agentId = _nextAgentId++;
        _safeMint(msg.sender, agentId);
        _setTokenURI(agentId, tokenURI);
        emit Registered(agentId, tokenURI, msg.sender);
        return agentId;
    }
}

// StrategyReputation.sol (Minimal)
contract StrategyReputation {
    address public immutable identityRegistry;

    struct Feedback {
        uint8 score;
        bytes32 tag1;
        bytes32 tag2;
        uint40 timestamp;
    }

    // agentId => clientAddress => Feedback[]
    mapping(uint256 => mapping(address => Feedback[])) public feedbacks;

    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint8 score,
        bytes32 indexed tag1,
        bytes32 tag2,
        string fileuri,
        bytes32 filehash
    );

    constructor(address _identityRegistry) {
        identityRegistry = _identityRegistry;
    }

    function giveFeedback(
        uint256 agentId,
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        string calldata fileuri,
        bytes32 filehash,
        bytes memory feedbackAuth
    ) external {
        // Verify feedbackAuth signature (EIP-191/ERC-1271)
        _verifyFeedbackAuth(agentId, msg.sender, feedbackAuth);

        // Store feedback
        feedbacks[agentId][msg.sender].push(Feedback({
            score: score,
            tag1: tag1,
            tag2: tag2,
            timestamp: uint40(block.timestamp)
        }));

        emit NewFeedback(agentId, msg.sender, score, tag1, tag2, fileuri, filehash);
    }

    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        bytes32 tag1,
        bytes32 tag2
    ) external view returns (uint64 count, uint8 averageScore) {
        // Aggregate feedback (implement filtering logic)
        // Return count and average
    }

    function _verifyFeedbackAuth(
        uint256 agentId,
        address clientAddress,
        bytes memory feedbackAuth
    ) internal view {
        // Implement EIP-191/ERC-1271 signature verification
        // Verify: agentId, clientAddress, indexLimit, expiry, chainId
    }
}
```

---

## Implementation Examples

### Example 1: Register a Service Agent

```typescript
// service-agent/scripts/register.ts
import { createWalletClient, http } from 'viem';
import { baseSepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import fs from 'fs';

// 1. Create registration file
const registrationData = {
  type: "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  name: "Memecoin Trading Strategy",
  description: "Provides real-time trading signals for memecoins",
  tags: ["memecoin", "trading", "signals", "defi"],
  endpoints: [
    {
      name: "agentWallet",
      endpoint: "eip155:84532:0xYourServiceAgentWallet"
    }
  ]
};

// 2. Upload to IPFS or host on HTTPS
const tokenURI = "ipfs://QmXxx..."; // or "https://example.com/agent.json"

// 3. Call StrategyRegistry.register()
const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const client = createWalletClient({
  account,
  chain: baseSepolia,
  transport: http()
});

const hash = await client.writeContract({
  address: '0xStrategyRegistryAddress',
  abi: [{
    name: 'register',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'tokenURI', type: 'string' }],
    outputs: [{ name: 'agentId', type: 'uint256' }]
  }],
  functionName: 'register',
  args: [tokenURI]
});

console.log('Registration tx:', hash);
```

---

### Example 2: Query Agents via Indexer

```typescript
// client-agent/src/discovery.ts

// Query Indexer API to discover agents
async function discoverAgents() {
  const response = await fetch(
    'http://indexer.example.com/agents?tags=memecoin,trading&minReputation=80'
  );

  const agents = await response.json();
  /*
  [
    {
      "agentId": 1,
      "name": "Memecoin Trader",
      "endpoint": "https://service-agent.com",
      "reputation": { "count": 16, "average": 88 },
      "tags": ["memecoin", "trading", "signals"]
    }
  ]
  */

  return agents;
}

// Select agent with best reputation
const agents = await discoverAgents();
const bestAgent = agents.sort((a, b) =>
  b.reputation.average - a.reputation.average
)[0];

console.log('Selected agent:', bestAgent.name);
```

---

### Example 3: Submit Feedback

```typescript
// client-agent/src/feedback.ts

async function submitFeedback(agentId: number, score: number, feedbackAuth: string) {
  const hash = await client.writeContract({
    address: '0xStrategyReputationAddress',
    abi: [{
      name: 'giveFeedback',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: 'agentId', type: 'uint256' },
        { name: 'score', type: 'uint8' },
        { name: 'tag1', type: 'bytes32' },
        { name: 'tag2', type: 'bytes32' },
        { name: 'fileuri', type: 'string' },
        { name: 'filehash', type: 'bytes32' },
        { name: 'feedbackAuth', type: 'bytes' }
      ],
      outputs: []
    }],
    functionName: 'giveFeedback',
    args: [
      agentId,
      score,
      '0x' + Buffer.from('trading').toString('hex').padEnd(64, '0'), // tag1
      '0x0000000000000000000000000000000000000000000000000000000000000000', // tag2 (empty)
      '', // fileuri (empty for MVP)
      '0x0000000000000000000000000000000000000000000000000000000000000000', // filehash (empty)
      feedbackAuth
    ]
  });

  console.log('Feedback submitted:', hash);
}
```

---

## Indexer Integration

### Events to Listen For

The Indexer (Ponder) must listen to these events:

#### 1. **Registered Event** (StrategyRegistry)

```typescript
// ponder.config.ts
export default {
  contracts: {
    StrategyRegistry: {
      address: '0x...',
      abi: strategyRegistryAbi,
      network: 'base-sepolia',
      startBlock: 12345678
    }
  }
};

// src/StrategyRegistry.ts
ponder.on("StrategyRegistry:Registered", async ({ event, context }) => {
  const { agentId, tokenURI, owner } = event.args;

  // Fetch registration file
  const response = await fetch(tokenURI);
  const metadata = await response.json();

  // Store in database
  await context.db.Agent.create({
    id: agentId.toString(),
    owner: owner,
    tokenURI: tokenURI,
    name: metadata.name,
    description: metadata.description,
    tags: metadata.tags,
    endpoints: metadata.endpoints,
    image: metadata.image
  });
});
```

#### 2. **NewFeedback Event** (StrategyReputation)

```typescript
ponder.on("StrategyReputation:NewFeedback", async ({ event, context }) => {
  const { agentId, clientAddress, score, tag1, tag2 } = event.args;

  // Store feedback
  await context.db.Feedback.create({
    id: `${agentId}-${clientAddress}-${event.block.timestamp}`,
    agentId: agentId.toString(),
    clientAddress: clientAddress,
    score: score,
    tag1: tag1,
    tag2: tag2,
    timestamp: event.block.timestamp
  });

  // Update agent reputation summary
  const feedbacks = await context.db.Feedback.findMany({
    where: { agentId: agentId.toString() }
  });

  const averageScore = feedbacks.reduce((sum, f) => sum + f.score, 0) / feedbacks.length;

  await context.db.Agent.update({
    id: agentId.toString(),
    data: {
      reputationCount: feedbacks.length,
      reputationAverage: Math.round(averageScore)
    }
  });
});
```

---

### Building Discovery API

```typescript
// ponder/src/api.ts

// GET /agents?tags=memecoin&minReputation=80
app.get('/agents', async (req, res) => {
  const { tags, minReputation } = req.query;

  let query: any = {};

  // Filter by tags
  if (tags) {
    const tagArray = tags.split(',');
    query.tags = { hasSome: tagArray };
  }

  // Filter by minimum reputation
  if (minReputation) {
    query.reputationAverage = { gte: parseInt(minReputation) };
  }

  const agents = await db.Agent.findMany({
    where: query,
    orderBy: { reputationAverage: 'desc' }
  });

  res.json(agents);
});
```

---

## References

### Official ERC-8004 Documentation
- **EIP-8004 Specification:** https://eips.ethereum.org/EIPS/eip-8004
- **Official Website:** https://8004.org/

### Community Resources
- **Ethereum Magicians Discussion:** https://ethereum-magicians.org/t/erc-8004-trustless-agents/25098
- **QuestFlow Blog:** https://blog.questflow.ai/p/erc-8004-and-the-rise-of-trustless

### Related Standards
- **ERC-721:** NFT standard (base for Identity Registry)
- **EIP-191:** Signed data standard (for feedbackAuth)
- **ERC-1271:** Contract signature verification
- **CAIP-10:** Chain-agnostic account identifiers

### Project-Specific
- **Base Sepolia Explorer:** https://sepolia.basescan.org/
- **Base Sepolia RPC:** https://sepolia.base.org
- **Ponder Documentation:** https://ponder.sh/docs

---

**Last Updated:** 2025-11-05
