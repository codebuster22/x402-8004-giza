# Research: ERC-8004 Smart Contracts

**Feature**: 001-erc8004-contracts | **Date**: 2025-11-05

## Overview

This document captures technical research and decisions for implementing StrategyRegistry and StrategyReputation contracts following ERC-8004 specifications.

---

## 1. EIP-712 Signature Structure for FeedbackAuth

### Decision

Use OpenZeppelin's `EIP712` base contract with structured typed data for feedbackAuth signatures.

### Implementation Pattern

```solidity
// In StrategyReputation contract
bytes32 private constant FEEDBACK_AUTH_TYPEHASH = keccak256(
    "FeedbackAuth(uint256 agentId,address clientAddress,uint256 indexLimit,uint256 expiry,uint256 chainId)"
);

function _verifyFeedbackAuth(
    uint256 agentId,
    address clientAddress,
    uint256 indexLimit,
    uint256 expiry,
    bytes memory signature
) internal view returns (address signer) {
    require(block.timestamp <= expiry, "FeedbackAuth expired");
    require(block.chainid == expiry, "Invalid chainId"); // chainId encoded in expiry field

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

### Rationale

- **EIP-712**: Provides wallet-friendly structured data signing with domain separation
- **OpenZeppelin EIP712**: Battle-tested implementation, handles domain separator automatically
- **ECDSA**: OpenZeppelin's library for safe signature recovery
- **Type Hash**: Computed once as constant for gas efficiency

### Alternatives Considered

- **Raw keccak256(abi.encodePacked(...))**: Rejected due to collision risks and poor wallet UX
- **EIP-191 personal_sign**: Rejected because it doesn't provide structured data display in wallets

### Reference

- OpenZeppelin EIP712: https://docs.openzeppelin.com/contracts/5.x/api/utils#EIP712
- ERC-8004 Reference: https://raw.githubusercontent.com/ChaosChain/trustless-agents-erc-ri/refs/heads/main/src/ReputationRegistry.sol

---

## 2. Per-Client-Per-Agent Index Tracking

### Decision

Use nested mapping pattern: `mapping(uint256 => mapping(address => uint256))` for client feedback indices.

### Implementation Pattern

```solidity
// Storage
mapping(uint256 => mapping(address => uint256)) private _clientIndices;

// Get current index
function getClientIndex(uint256 agentId, address clientAddress) public view returns (uint256) {
    return _clientIndices[agentId][clientAddress];
}

// Increment after feedback
function _incrementClientIndex(uint256 agentId, address clientAddress) internal {
    _clientIndices[agentId][clientAddress]++;
}

// Validation
function _validateIndexLimit(uint256 agentId, address clientAddress, uint256 indexLimit) internal view {
    require(_clientIndices[agentId][clientAddress] < indexLimit, "Index limit exceeded");
}
```

### Rationale

- **Nested mapping**: Most gas-efficient for lookups and updates (SLOAD/SSTORE)
- **Default value 0**: Solidity mappings initialize to 0, perfect for starting index
- **No array iteration**: O(1) lookups, no gas cost scaling with feedback count
- **Simple increment**: Post-increment after validation ensures atomic operation

### Alternatives Considered

- **Single mapping with composite key `keccak256(abi.encodePacked(agentId, clientAddress))`**: Rejected due to extra hashing cost on every access
- **Struct with index + timestamp**: Rejected as timestamp not required for indexLimit logic

### Gas Cost Analysis

- Nested mapping read (SLOAD): ~2,100 gas
- Nested mapping write (SSTORE): ~20,000 gas (first write), ~5,000 gas (update)
- Composite key approach would add ~500 gas per access for hashing

---

## 3. Reputation Aggregation Patterns

### Decision

Use **running totals** pattern with on-demand average calculation in view function.

### Implementation Pattern

```solidity
// Storage
struct AgentReputation {
    uint64 feedbackCount;
    uint256 totalScore;  // Sum of all scores
}

mapping(uint256 => AgentReputation) private _reputations;

// Update on each feedback
function _updateReputation(uint256 agentId, uint8 score) internal {
    _reputations[agentId].feedbackCount++;
    _reputations[agentId].totalScore += score;
}

// View function
function getSummary(uint256 agentId) public view returns (uint64 count, uint8 averageScore) {
    AgentReputation memory rep = _reputations[agentId];
    count = rep.feedbackCount;
    averageScore = rep.feedbackCount > 0
        ? uint8(rep.totalScore / rep.feedbackCount)
        : 0;
}
```

### Rationale

- **Running totals**: Avoids iterating through feedback array (gas-efficient writes)
- **On-demand calculation**: Average computed in view function (no gas cost for reads)
- **uint256 for totalScore**: Prevents overflow (max score 100 * max uint64 count fits in uint256)
- **uint64 for count**: Supports up to 18 quintillion feedbacks (more than sufficient)
- **uint8 for average**: Matches score range (0-100)

### Alternatives Considered

- **Store feedback array + iterate**: Rejected due to unbounded gas cost for getSummary()
- **Cache average on write**: Rejected as it adds gas cost to feedback submission for rarely-used data
- **Off-chain aggregation only**: Rejected as on-chain summary is required for discoverability

### Overflow Protection

- **totalScore**: uint256 max = 2^256 - 1 ≈ 10^77
- **Maximum possible total**: 100 * 2^64 ≈ 1.8 * 10^21 (safe by orders of magnitude)

---

## 4. ERC-721 Integration with Custom Logic

### Decision

Extend `ERC721URIStorage` from OpenZeppelin with minimal custom logic.

### Implementation Pattern

```solidity
// StrategyRegistry.sol
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract StrategyRegistry is ERC721URIStorage {
    uint256 private _nextAgentId = 1;  // Start from 1

    constructor() ERC721("Giza Strategy Agent", "GIZA-AGENT") {}

    function register(string memory tokenURI_) public returns (uint256 agentId) {
        agentId = _nextAgentId++;
        _safeMint(msg.sender, agentId);
        _setTokenURI(agentId, tokenURI_);

        emit Registered(agentId, tokenURI_, msg.sender);
    }

    event Registered(
        uint256 indexed agentId,
        string tokenURI,
        address indexed owner
    );
}
```

### Rationale

- **ERC721URIStorage**: Provides built-in tokenURI storage per token (perfect for agent metadata)
- **Start from 1**: More intuitive than 0, easier to check "exists" with `> 0` checks
- **_safeMint**: Prevents accidental burns to contracts that can't handle NFTs
- **_setTokenURI**: Built-in function, no custom storage needed
- **Minimal custom code**: Leverages battle-tested OpenZeppelin implementations

### Owner Verification Pattern (for StrategyReputation)

```solidity
// In StrategyReputation constructor
IStrategyRegistry public immutable identityRegistry;

constructor(address _identityRegistry) EIP712("StrategyReputation", "1") {
    identityRegistry = IStrategyRegistry(_identityRegistry);
}

// In giveFeedback
address agentOwner = identityRegistry.ownerOf(agentId);
address signer = _verifyFeedbackAuth(...);
require(signer == agentOwner, "Invalid feedbackAuth signer");
```

### Event Emission Best Practices

- **Indexed fields**: agentId, owner (enables efficient event filtering)
- **String data**: tokenURI as non-indexed (avoids expensive keccak256 in logs)
- **Emission timing**: After state changes (follows checks-effects-interactions pattern)

### Alternatives Considered

- **Custom ERC-721 implementation**: Rejected due to unnecessary complexity and security risks
- **Start agentId from 0**: Rejected as it complicates existence checks (`agentId == 0` could mean uninitialized)
- **_mint instead of _safeMint**: Rejected to prevent accidental NFT loss

---

## 5. OpenZeppelin Dependencies via Bun

### Decision

Use OpenZeppelin Contracts v5.1.0 installed via Bun with remappings.txt configuration.

### Installation Commands

```bash
cd contracts
bun add @openzeppelin/contracts@^5.1.0
```

### remappings.txt Configuration

```text
@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/
```

### Rationale

- **Version 5.1.0**: Latest stable, includes all required features (EIP712, ERC721URIStorage, ECDSA)
- **Bun management**: Faster than npm, aligns with project constitution
- **remappings.txt**: Standard Foundry pattern for import resolution
- **No git submodules**: Avoids slow, fragile git submodule dependencies

### Required Imports

```solidity
// StrategyRegistry
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// StrategyReputation
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
```

### Verification

After installation, verify with:
```bash
forge build  # Should compile without errors
```

### Alternatives Considered

- **OpenZeppelin v4.x**: Rejected as v5.x is current stable with better gas optimizations
- **Solmate**: Rejected as OpenZeppelin has better EIP-712 support and is more widely audited
- **Git submodules**: Rejected per project constitution (Principle V)

---

## Additional Technical Decisions

### 6. Error Handling Pattern

**Decision**: Use custom errors (Solidity 0.8.4+) for gas efficiency.

```solidity
error AgentNotFound(uint256 agentId);
error IndexLimitExceeded(uint256 agentId, address client, uint256 currentIndex, uint256 limit);
error FeedbackAuthExpired(uint256 expiry, uint256 currentTime);
error InvalidScore(uint8 score);
error InvalidSigner(address expected, address actual);

// Usage
if (score > 100) revert InvalidScore(score);
if (signer != agentOwner) revert InvalidSigner(agentOwner, signer);
```

**Rationale**: Custom errors are more gas-efficient than require strings and provide better debugging info.

### 7. Starting AgentId Value

**Decision**: Start from `1` (not `0`).

**Rationale**:
- Easier existence checks: `if (agentId > 0)` vs checking NFT ownership
- Prevents confusion between "agentId 0" and "no agent"
- Common pattern in NFT contracts

### 8. Feedback Storage Pattern

**Decision**: Use array of structs per agent rather than mapping.

```solidity
struct Feedback {
    address clientAddress;
    uint8 score;
    bytes32 tag1;
    bytes32 tag2;
    string fileuri;
    bytes32 filehash;
    uint40 timestamp;
}

mapping(uint256 => Feedback[]) private _feedbacks;
```

**Rationale**:
- Enables future features (pagination, history queries)
- Indexer can reconstruct full feedback history from events
- Array append is gas-efficient (~20k gas)
- uint40 timestamp sufficient until year 36,812

**Alternative**: Don't store feedback at all (events only). Rejected because getSummary() needs on-chain data.

---

## Summary of Key Decisions

| Decision Point | Choice | Primary Rationale |
|----------------|--------|-------------------|
| Signature Format | EIP-712 with OpenZeppelin | Wallet UX, type safety, battle-tested |
| Client Index Storage | Nested mapping | O(1) access, gas-efficient |
| Reputation Aggregation | Running totals | Constant-time updates and reads |
| ERC-721 Base | OpenZeppelin ERC721URIStorage | Standard compliance, minimal custom code |
| Dependencies | Bun + remappings.txt | Fast, per constitution, no submodules |
| Error Handling | Custom errors | Gas efficiency, better debugging |
| Starting AgentId | 1 | Easier existence checks, common pattern |
| Feedback Storage | Array of structs | Future-proof, event-driven indexing |

---

## Open Questions / Future Considerations

### Addressed in Spec

- ✅ Empty tokenURI allowed (per clarifications)
- ✅ Tags format: UTF-8 bytes32 (per clarifications)
- ✅ Multiple feedback from same client counted independently (per clarifications)

### For Post-MVP

- **Feedback pagination**: If feedback arrays grow large, add pagination to view functions
- **Gas optimization**: Profile actual gas costs, optimize hot paths if needed
- **Upgradeability**: Current design is immutable; consider proxy pattern for future versions
- **Batch operations**: Support batch feedback submission for gas savings

---

**Research Complete**: All technical decisions documented. Ready for Phase 1 (Design Artifacts).
