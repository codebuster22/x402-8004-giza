# StrategyReputation Interface

**Contract**: StrategyReputation (Reputation Registry)
**Standard**: ERC-8004 Reputation with EIP-712 Signatures
**Purpose**: Feedback submission and reputation aggregation for service agents

---

## Public Functions

### giveFeedback

```solidity
function giveFeedback(
    uint256 agentId,
    uint8 score,
    bytes32 tag1,
    bytes32 tag2,
    string memory fileuri,
    bytes32 filehash,
    bytes memory feedbackAuth
) public
```

**Description**: Submit feedback for a service agent with cryptographic authorization from the agent owner.

**Parameters**:
- `agentId` (uint256): Agent identifier (must exist in StrategyRegistry)
- `score` (uint8): Rating from 0-100
- `tag1` (bytes32): Primary tag (UTF-8 encoded string right-padded with zeros)
- `tag2` (bytes32): Secondary tag (UTF-8 encoded string right-padded with zeros)
- `fileuri` (string): Optional URI to detailed feedback file (IPFS/HTTPS, can be empty)
- `filehash` (bytes32): Optional hash of feedback file content (can be bytes32(0))
- `feedbackAuth` (bytes): EIP-712 signature authorizing this feedback (abi.encode(struct) + 65-byte signature)

**Effects**:
- Stores feedback in `_feedbacks[agentId]` array
- Increments `_clientIndices[agentId][msg.sender]` by 1
- Updates `_reputations[agentId]` (increments count, adds to totalScore)
- Emits `NewFeedback` event

**Validation**:
- Score must be ≤ 100
- AgentId must exist (ownerOf call reverts if not)
- feedbackAuth signature must be valid EIP-712 signature
- Recovered signer must equal current agent NFT owner
- feedbackAuth must not be expired (expiry ≥ block.timestamp)
- Client's current index must be < indexLimit from feedbackAuth
- Chain ID in feedbackAuth must match block.chainid

**Reverts**:
- `InvalidScore(score)` if score > 100
- `AgentNotFound(agentId)` if agentId doesn't exist
- `IndexLimitExceeded(agentId, client, currentIndex, indexLimit)` if index >= limit
- `FeedbackAuthExpired(expiry, block.timestamp)` if expired
- `InvalidSigner(expected, actual)` if signer != agent owner
- `InvalidChainId()` if chainId mismatch

**Gas Estimate**: ~200,000 gas (signature verification + storage writes)

**Example**:
```solidity
// Assume agent owner signed feedbackAuth for client 0xABC... with indexLimit=5
IStrategyReputation reputation = IStrategyReputation(0x...);

reputation.giveFeedback(
    1,                                    // agentId
    85,                                   // score (0-100)
    bytes32("trading"),                   // tag1 (UTF-8 encoded)
    bytes32("memecoin"),                  // tag2
    "ipfs://QmFeedbackDetails...",        // fileuri (optional)
    keccak256("feedback content"),        // filehash (optional)
    feedbackAuthBytes                     // EIP-712 signature from agent owner
);
// Success: feedback stored, client index = 1, reputation updated
```

---

### getSummary

```solidity
function getSummary(uint256 agentId) public view returns (uint64 count, uint8 averageScore)
```

**Description**: Get aggregated reputation summary for an agent.

**Parameters**:
- `agentId` (uint256): Agent identifier

**Returns**:
- `count` (uint64): Total number of feedback entries received
- `averageScore` (uint8): Average score across all feedbacks (0-100), or 0 if count=0

**Calculation**:
```solidity
count = _reputations[agentId].feedbackCount;
averageScore = count > 0
    ? uint8(_reputations[agentId].totalScore / count)
    : 0;
```

**Gas Estimate**: ~5,000 gas (view function, no cost for external calls)

**Example**:
```solidity
(uint64 count, uint8 avgScore) = reputation.getSummary(1);
// Returns: (16, 88) - 16 feedbacks with 88 average score
```

---

### getClientIndex

```solidity
function getClientIndex(uint256 agentId, address clientAddress) public view returns (uint256)
```

**Description**: Get the current feedback index for a specific client-agent pair.

**Parameters**:
- `agentId` (uint256): Agent identifier
- `clientAddress` (address): Client address to query

**Returns**:
- Current index (starts at 0, increments by 1 with each feedback)

**Gas Estimate**: ~2,500 gas (view function)

**Example**:
```solidity
uint256 currentIndex = reputation.getClientIndex(1, 0xABC...);
// Returns: 3 (client has submitted 3 feedbacks to agent 1)

// To authorize 2 more feedbacks:
// indexLimit should be set to currentIndex + 2 = 5
```

**Use Case**: Agent queries this before generating feedbackAuth to set appropriate indexLimit.

---

## Events

### NewFeedback

```solidity
event NewFeedback(
    uint256 indexed agentId,
    address indexed clientAddress,
    uint8 score,
    bytes32 indexed tag1,
    bytes32 tag2,
    string fileuri,
    bytes32 filehash
)
```

**Description**: Emitted when feedback is successfully submitted.

**Parameters**:
- `agentId` (indexed): Agent that received feedback
- `clientAddress` (indexed): Client who submitted feedback
- `score`: Rating value (0-100)
- `tag1` (indexed): Primary tag for filtering (UTF-8 bytes32)
- `tag2`: Secondary tag (not indexed)
- `fileuri`: URI to detailed feedback file
- `filehash`: Hash of feedback file content

**Note**: Timestamp not included in event (use `block.timestamp` from event metadata)

**Use Case**: Indexer listens for this event to build feedback history and update reputation scores.

**Example Event**:
```json
{
  "agentId": "1",
  "clientAddress": "0xABC1234567890123456789012345678901234567",
  "score": "85",
  "tag1": "0x74726164696e6700000000000000000000000000000000000000000000000000",  // "trading"
  "tag2": "0x6d656d65636f696e00000000000000000000000000000000000000000000000000",  // "memecoin"
  "fileuri": "ipfs://QmFeedbackDetails...",
  "filehash": "0x1234567890abcdef..."
}
```

---

## FeedbackAuth Signature Structure

### EIP-712 Typed Data

```solidity
// Domain separator
EIP712Domain {
    string name = "StrategyReputation";
    string version = "1";
    uint256 chainId = 84532;  // Base Sepolia
    address verifyingContract = <deployed address>;
}

// Struct to sign
struct FeedbackAuth {
    uint256 agentId;
    address clientAddress;
    uint256 indexLimit;
    uint256 expiry;
    uint256 chainId;
}

// Type hash
bytes32 constant FEEDBACK_AUTH_TYPEHASH = keccak256(
    "FeedbackAuth(uint256 agentId,address clientAddress,uint256 indexLimit,uint256 expiry,uint256 chainId)"
);
```

### Signature Generation (Off-chain)

```javascript
// Using ethers.js v6
const domain = {
    name: "StrategyReputation",
    version: "1",
    chainId: 84532,
    verifyingContract: "0x..." // Deployed StrategyReputation address
};

const types = {
    FeedbackAuth: [
        { name: "agentId", type: "uint256" },
        { name: "clientAddress", type: "address" },
        { name: "indexLimit", type: "uint256" },
        { name: "expiry", type: "uint256" },
        { name: "chainId", type: "uint256" }
    ]
};

const value = {
    agentId: 1,
    clientAddress: "0xABC...",
    indexLimit: 5,  // currentIndex + N authorized feedbacks
    expiry: Math.floor(Date.now() / 1000) + 86400,  // 24 hours
    chainId: 84532
};

// Agent owner signs
const signature = await agentOwnerWallet.signTypedData(domain, types, value);

// Encode for contract call
const encodedStruct = ethers.AbiCoder.defaultAbiCoder().encode(
    ["uint256", "address", "uint256", "uint256", "uint256"],
    [value.agentId, value.clientAddress, value.indexLimit, value.expiry, value.chainId]
);

const feedbackAuth = ethers.concat([encodedStruct, signature]);
// feedbackAuth is now ready to pass to giveFeedback()
```

### Signature Verification (On-chain)

```solidity
function _verifyFeedbackAuth(
    uint256 agentId,
    address clientAddress,
    uint256 indexLimit,
    uint256 expiry,
    bytes memory signature
) internal view returns (address signer) {
    bytes32 structHash = keccak256(abi.encode(
        FEEDBACK_AUTH_TYPEHASH,
        agentId,
        clientAddress,
        indexLimit,
        expiry,
        block.chainid
    ));

    bytes32 digest = _hashTypedDataV4(structHash);
    signer = ECDSA.recover(digest, signature);
}
```

---

## Error Definitions

```solidity
error AgentNotFound(uint256 agentId);
error InvalidScore(uint8 score);
error IndexLimitExceeded(uint256 agentId, address client, uint256 currentIndex, uint256 indexLimit);
error FeedbackAuthExpired(uint256 expiry, uint256 currentTimestamp);
error InvalidSigner(address expectedSigner, address actualSigner);
error InvalidChainId();
```

---

## Interface Definition (Solidity)

```solidity
interface IStrategyReputation {
    // Main functions
    function giveFeedback(
        uint256 agentId,
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        string memory fileuri,
        bytes32 filehash,
        bytes memory feedbackAuth
    ) external;

    function getSummary(uint256 agentId) external view returns (uint64 count, uint8 averageScore);

    function getClientIndex(uint256 agentId, address clientAddress) external view returns (uint256);

    // Registry reference
    function identityRegistry() external view returns (address);

    // Events
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint8 score,
        bytes32 indexed tag1,
        bytes32 tag2,
        string fileuri,
        bytes32 filehash
    );

    // Errors
    error AgentNotFound(uint256 agentId);
    error InvalidScore(uint8 score);
    error IndexLimitExceeded(uint256 agentId, address client, uint256 currentIndex, uint256 indexLimit);
    error FeedbackAuthExpired(uint256 expiry, uint256 currentTimestamp);
    error InvalidSigner(address expectedSigner, address actualSigner);
    error InvalidChainId();
}
```

---

## Usage Examples

### Complete Flow: Agent Authorizes Client Feedback

```solidity
// 1. Client requests feedback authorization from agent (off-chain)
// 2. Agent checks client's current index
uint256 currentIndex = reputation.getClientIndex(agentId, clientAddress);
// currentIndex = 0 (new client)

// 3. Agent generates feedbackAuth signature (off-chain)
// indexLimit = currentIndex + 1 = 1 (authorizes 1 feedback)
// expiry = now + 24 hours
// Agent signs EIP-712 typed data

// 4. Client calls giveFeedback with signature
reputation.giveFeedback(
    agentId,
    90,  // score
    bytes32("excellent"),
    bytes32("responsive"),
    "",  // no detailed feedback file
    bytes32(0),  // no filehash
    feedbackAuthBytes
);

// 5. Contract validates and stores feedback
// - Verifies signature from agent owner
// - Checks currentIndex (0) < indexLimit (1) ✓
// - Stores feedback
// - Increments client index to 1
// - Emits NewFeedback event

// 6. Query updated reputation
(uint64 count, uint8 avg) = reputation.getSummary(agentId);
// count = 1, avg = 90
```

### Batch Authorization

```solidity
// Agent authorizes client for 10 feedbacks at once
uint256 currentIndex = reputation.getClientIndex(agentId, clientAddress);
// currentIndex = 5 (client has submitted 5 feedbacks)

// Agent sets indexLimit = 15 (authorizes 10 more)
// Client can now call giveFeedback() 10 times without new signature
// After 10 calls, client index = 15, must request new auth
```

### Tag Encoding

```solidity
// Tags are UTF-8 strings encoded as bytes32
// Right-padded with zeros

// JavaScript/TypeScript:
const tag1 = ethers.encodeBytes32String("trading");
// Result: 0x74726164696e6700000000000000000000000000000000000000000000000000

// Solidity (for testing):
bytes32 tag1 = bytes32("trading");  // Automatic right-padding

// Decoding in indexer:
const tagString = ethers.decodeBytes32String(tag1);
// Result: "trading"
```

---

## Integration Notes

### For Service Agents

1. **Generate feedbackAuth after payment**:
   - Query client's current index: `getClientIndex(agentId, clientAddress)`
   - Set `indexLimit = currentIndex + N` (where N = authorized feedback count)
   - Sign EIP-712 typed data with agent NFT owner's private key
   - Return feedbackAuth to client

2. **Monitor feedback**:
   - Listen for `NewFeedback` events with your agentId
   - Query updated reputation: `getSummary(agentId)`

### For Client Agents

1. **Obtain feedbackAuth from agent** (off-chain, after payment via X402)
2. **Submit feedback**:
   ```solidity
   reputation.giveFeedback(agentId, score, tag1, tag2, fileuri, filehash, feedbackAuth);
   ```
3. **Handle errors**:
   - `IndexLimitExceeded`: Request new feedbackAuth from agent
   - `FeedbackAuthExpired`: Request new feedbackAuth with fresh expiry
   - `InvalidSigner`: Agent may have transferred NFT, contact new owner

### For Indexers (Ponder)

1. **Listen for NewFeedback events**
2. **Store feedback data**:
   - agentId, clientAddress, score, tags, fileuri, filehash, timestamp (from block)
3. **Update agent reputation**:
   - Option A: Call `getSummary(agentId)` to get on-chain aggregate
   - Option B: Calculate off-chain from all NewFeedback events (same result)
4. **Build discovery API**:
   - Filter agents by average reputation score
   - Show feedback history per agent
   - Filter feedbacks by tags

---

## Deployment Parameters

**Constructor**:
```solidity
constructor(address _identityRegistry)
    EIP712("StrategyReputation", "1")
{
    identityRegistry = IStrategyRegistry(_identityRegistry);
}
```

**Deployment**:
1. Deploy StrategyRegistry first
2. Deploy StrategyReputation with StrategyRegistry address
3. No initialization required (ready to use immediately)

**Deployment Script Example**:
```solidity
// Deploy.s.sol
StrategyRegistry registry = new StrategyRegistry();
StrategyReputation reputation = new StrategyReputation(address(registry));
```

---

## Security Considerations

- ✅ **EIP-712 signatures**: Standard typed data signing prevents signature replay across contracts/chains
- ✅ **Owner verification**: Only current agent NFT owner can sign valid feedbackAuth
- ✅ **Index limits**: Prevents unlimited feedback spam from single client
- ✅ **Expiry enforcement**: Signatures cannot be used indefinitely
- ✅ **ChainId validation**: Prevents cross-chain signature replay
- ⚠️ **No signature nonce**: Same feedbackAuth can be reused if index limit not reached (intentional design)
- ⚠️ **No rate limiting**: Clients can submit multiple feedbacks rapidly (limited by indexLimit)
- ⚠️ **No score validation beyond bounds**: Score of 0 or 100 is allowed (no min/max thresholds)
- ⚠️ **Tags not validated**: Any bytes32 value accepted (client responsibility to encode properly)

---

## Gas Optimization Notes

- **Running totals**: getSummary() is O(1), not O(N) over feedbacks
- **Packed structs**: Feedback struct uses efficient layout
- **View functions**: No gas cost for external calls to getSummary(), getClientIndex()
- **Custom errors**: ~50% cheaper than require strings
- **Immutable registry**: identityRegistry reference is immutable (cheaper SLOAD)

---

**Version**: 1.0 | **Status**: Final
