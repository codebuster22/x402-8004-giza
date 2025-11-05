# StrategyRegistry Interface

**Contract**: StrategyRegistry (Identity Registry)
**Standard**: ERC-721 (ERC721URIStorage)
**Purpose**: On-chain identity management for service agents

---

## Public Functions

### register

```solidity
function register(string memory tokenURI_) public returns (uint256 agentId)
```

**Description**: Register a new service agent and mint an ERC-721 NFT representing its identity.

**Parameters**:
- `tokenURI_` (string): URI pointing to agent metadata JSON (IPFS or HTTPS). Can be empty string.

**Returns**:
- `agentId` (uint256): Unique identifier for the newly registered agent (sequential, starts from 1)

**Effects**:
- Mints ERC-721 NFT to `msg.sender`
- Sets tokenURI for the agentId
- Emits `Registered` event
- Emits `Transfer` event (ERC-721 standard)

**Validation**:
- None (any caller can register, any tokenURI accepted including empty string)

**Gas Estimate**: ~150,000 gas

**Example**:
```solidity
uint256 myAgentId = registry.register("ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG");
// Returns: 1 (if first agent)
// msg.sender now owns agentId 1
```

---

### tokenURI (inherited)

```solidity
function tokenURI(uint256 agentId) public view returns (string memory)
```

**Description**: Get the metadata URI for a registered agent.

**Parameters**:
- `agentId` (uint256): Agent identifier

**Returns**:
- URI string (can be empty if agent registered with empty tokenURI)

**Reverts**:
- If `agentId` does not exist (standard ERC-721 behavior)

**Gas Estimate**: ~3,000 gas (view function, no cost for external calls)

---

### ownerOf (inherited)

```solidity
function ownerOf(uint256 agentId) public view returns (address)
```

**Description**: Get the current owner of an agent NFT.

**Parameters**:
- `agentId` (uint256): Agent identifier

**Returns**:
- Owner address

**Reverts**:
- If `agentId` does not exist

**Gas Estimate**: ~2,500 gas (view function)

**Example**:
```solidity
address owner = registry.ownerOf(1);
// Returns: 0x1234... (current NFT owner)
```

---

## Standard ERC-721 Functions

The contract inherits all standard ERC-721 functions:

### Transfer Functions
- `transferFrom(address from, address to, uint256 tokenId)`
- `safeTransferFrom(address from, address to, uint256 tokenId)`
- `safeTransferFrom(address from, address to, uint256 tokenId, bytes data)`

### Approval Functions
- `approve(address to, uint256 tokenId)`
- `getApproved(uint256 tokenId) returns (address)`
- `setApprovalForAll(address operator, bool approved)`
- `isApprovedForAll(address owner, address operator) returns (bool)`

### Query Functions
- `balanceOf(address owner) returns (uint256)`
- `name() returns (string)` - Returns "Giza Strategy Agent"
- `symbol() returns (string)` - Returns "GIZA-AGENT"
- `supportsInterface(bytes4 interfaceId) returns (bool)`

---

## Events

### Registered

```solidity
event Registered(
    uint256 indexed agentId,
    string tokenURI,
    address indexed owner
)
```

**Description**: Emitted when a new agent is registered.

**Parameters**:
- `agentId` (indexed): The newly minted agent identifier
- `tokenURI`: Metadata URI (not indexed due to variable length)
- `owner` (indexed): Address that registered the agent (NFT owner)

**Use Case**: Indexer listens for this event to build agent discovery database.

**Example Event**:
```json
{
  "agentId": "1",
  "tokenURI": "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
  "owner": "0x1234567890123456789012345678901234567890"
}
```

---

### Standard ERC-721 Events

```solidity
event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
```

---

## Metadata JSON Schema

The `tokenURI` should point to a JSON file conforming to this schema:

```json
{
  "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  "name": "Memecoin Trading Strategy",
  "description": "Real-time memecoin trading signals",
  "tags": ["memecoin", "trading", "signals", "defi"],
  "endpoints": [
    {
      "name": "agentWallet",
      "endpoint": "eip155:84532:0xYourWalletAddress"
    },
    {
      "name": "api",
      "endpoint": "https://api.example.com/strategy"
    }
  ],
  "supportedTrust": ["reputation"]
}
```

**Fields**:
- `type` (required): ERC-8004 registration schema version
- `name` (required): Human-readable agent name
- `description` (required): What the agent does
- `tags` (required): Array of plain strings for discovery filtering
- `endpoints` (required): Array of endpoint objects with name and endpoint
- `supportedTrust` (required): Trust mechanisms supported (e.g., "reputation")

---

## Error Handling

The contract uses standard ERC-721 error handling patterns:

- **ERC721NonexistentToken(uint256 tokenId)**: Querying non-existent agentId
- **ERC721InvalidReceiver(address receiver)**: Attempting to mint to contract that can't receive NFTs
- **ERC721IncorrectOwner(address sender, uint256 tokenId, address owner)**: Transfer from wrong owner

---

## Interface Definition (Solidity)

```solidity
interface IStrategyRegistry {
    // Custom function
    function register(string memory tokenURI) external returns (uint256 agentId);

    // Standard ERC-721 (subset used by StrategyReputation)
    function ownerOf(uint256 agentId) external view returns (address);
    function tokenURI(uint256 agentId) external view returns (string memory);

    // Events
    event Registered(
        uint256 indexed agentId,
        string tokenURI,
        address indexed owner
    );
}
```

---

## Usage Examples

### Register an Agent

```solidity
// 1. Create metadata JSON and upload to IPFS
// 2. Call register with IPFS URI
IStrategyRegistry registry = IStrategyRegistry(0x...);
uint256 agentId = registry.register("ipfs://Qm...");
// agentId = 1 (or next sequential ID)
```

### Query Agent Metadata

```solidity
string memory metadataURI = registry.tokenURI(1);
// Returns: "ipfs://Qm..."

address agentOwner = registry.ownerOf(1);
// Returns: 0x1234... (current owner)
```

### Transfer Agent Ownership

```solidity
// Standard ERC-721 transfer
registry.transferFrom(currentOwner, newOwner, agentId);
// After transfer, newOwner controls feedbackAuth signatures
```

---

## Integration Notes

### For Indexers (Ponder)

1. Listen for `Registered` events
2. Extract `agentId`, `tokenURI`, `owner`
3. Fetch metadata JSON from `tokenURI`
4. Store in database for discovery API
5. Index by tags, name, reputation scores

### For Service Agents

1. Upload metadata JSON to IPFS or HTTPS endpoint
2. Call `register(tokenURI)` to get agentId
3. Sign feedbackAuth messages with private key of agent NFT owner
4. Transfer NFT ownership transfers feedbackAuth signing authority

### For Client Agents

1. Query indexer discovery API (not this contract directly)
2. Verify agent exists: `ownerOf(agentId)` (reverts if not exists)
3. Validate metadata: fetch from `tokenURI(agentId)`

---

## Deployment Parameters

**Constructor**:
```solidity
constructor() ERC721("Giza Strategy Agent", "GIZA-AGENT") {}
```

**Deployment**:
- No constructor arguments needed
- Deploys to Base Sepolia (chainId: 84532)
- No initialization required (ready to use immediately)

---

## Security Considerations

- ✅ **Standard compliance**: Inherits OpenZeppelin ERC721URIStorage (battle-tested)
- ✅ **No admin functions**: Fully permissionless, no upgradability
- ⚠️ **No tokenURI validation**: Accepts any string (including empty, malicious URLs)
- ⚠️ **No duplicate prevention**: Same agent can register multiple times with different tokenURIs
- ✅ **NFT safety**: Uses `_safeMint` to prevent accidental burns to non-compatible contracts

---

**Version**: 1.0 | **Status**: Final
