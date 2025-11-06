# ERC-8004 Smart Contracts - Strategy Agent Discovery

ERC-721 based identity registry and EIP-712 based reputation system for service agents.

## Overview

This project implements the ERC-8004 standard for agent discovery and reputation management on Ethereum-compatible chains. It consists of two main contracts:

1. **StrategyRegistry** - ERC-721 NFT-based identity registry for service agents
2. **StrategyReputation** - EIP-712 signature-based feedback and reputation system

## Features

### StrategyRegistry
- ✅ ERC-721 compliant NFT identity for agents
- ✅ Sequential agent IDs starting from 1
- ✅ Token URI support for agent metadata
- ✅ Standard NFT transfer functionality
- ✅ Registered event emission

### StrategyReputation
- ✅ EIP-712 typed signature authorization
- ✅ Per-client-per-agent feedback indexing
- ✅ Batch feedback authorization via indexLimit
- ✅ Score validation (0-100 range)
- ✅ Expiry timestamp checking
- ✅ Chain ID verification
- ✅ Real-time reputation aggregation
- ✅ Gas-efficient running totals

## Contract Addresses

### Base Sepolia Testnet
_Deployment pending - see DEPLOYMENT.md for latest addresses_

## Quick Start

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Bun (for package management)
curl -fsSL https://bun.sh/install | bash
```

### Installation

```bash
# Clone repository
cd contracts

# Install dependencies
bun install

# Build contracts
forge build

# Run tests
forge test

# Run tests with gas reporting
forge test --gas-report
```

### Deployment

1. Create `.env` file:
```bash
cp .env.example .env
# Edit .env with your configuration
```

2. Deploy to Base Sepolia:
```bash
forge script script/Deploy.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

## Usage Examples

### Register an Agent

```solidity
// Register agent and receive NFT identity
uint256 agentId = strategyRegistry.register("ipfs://QmYourMetadata");
// Agent NFT is minted to msg.sender with sequential ID
```

### Submit Feedback

```solidity
// Agent owner creates EIP-712 signature authorizing feedback
// Structure: FeedbackAuth(agentId, clientAddress, indexLimit, expiry, chainId)

bytes memory feedbackAuth = /* EIP-712 signed authorization */;

// Client submits feedback
strategyReputation.giveFeedback(
    agentId,
    85,                          // score (0-100)
    bytes32("performance"),      // tag1
    bytes32("reliable"),         // tag2
    "ipfs://feedback-details",   // fileuri
    keccak256("file-content"),   // filehash
    feedbackAuth                 // authorization signature
);
```

### Query Reputation

```solidity
// Get aggregated reputation summary
(uint64 count, uint8 averageScore) = strategyReputation.getSummary(agentId);

// Get client's current feedback index
uint256 currentIndex = strategyReputation.getClientIndex(agentId, clientAddress);
```

## Architecture

### Feedback Authorization Flow

```
1. Agent Owner signs FeedbackAuth (EIP-712)
   ├── agentId: Agent identifier
   ├── clientAddress: Authorized client
   ├── indexLimit: Max feedback index (enables batch authorization)
   ├── expiry: Signature expiration timestamp
   └── chainId: Target blockchain ID

2. Client submits feedback with feedbackAuth
   ├── Contract validates signature
   ├── Verifies signer is agent owner
   ├── Checks current index < indexLimit
   ├── Stores feedback on-chain
   ├── Increments client index
   └── Updates reputation running totals

3. Reputation updates immediately
   └── Average calculated from running totals
```

### Per-Client-Per-Agent Indexing

Each `(agentId, clientAddress)` pair maintains an independent feedback index starting at 0. This enables:
- **Batch authorization**: Agent can authorize multiple feedbacks via single signature
- **Replay attack prevention**: Each feedback increments the index
- **Granular control**: Agent sets indexLimit per client

## Gas Costs

Based on test execution with optimizer enabled:

| Function | Avg Gas | Description |
|----------|---------|-------------|
| `register()` | ~100,453 | Register new agent |
| `giveFeedback()` | ~172,402 | Submit feedback (includes signature verification) |
| `getSummary()` | ~4,683 | Query reputation (view function, no gas for external calls) |
| `getClientIndex()` | ~2,531 | Query client index (view function) |

## Testing

### Test Coverage

- **28 tests total** (100% passing)
- **StrategyRegistryTest**: 10 tests covering registration, ownership, transfers
- **StrategyReputationTest**: 18 tests covering feedback, reputation, edge cases

### Run Tests

```bash
# All tests
forge test

# Specific contract
forge test --match-contract StrategyRegistryTest

# Verbose output
forge test -vv

# Gas reporting
forge test --gas-report

# Coverage
forge coverage
```

## Security Considerations

### Implemented Protections

1. **EIP-712 Structured Signatures**: Type-safe signature verification
2. **Replay Attack Prevention**: Per-client feedback indices
3. **Expiry Validation**: Time-bounded authorizations
4. **Chain ID Verification**: Cross-chain replay protection
5. **Owner Authorization**: Only agent owner can authorize feedback
6. **Score Bounds**: Score must be ≤100 (uint8 prevents negatives)
7. **Overflow Protection**: uint256 totalScore accommodates max possible sum

### Known Limitations

1. **No feedback deletion**: Feedback is immutable once submitted
2. **Single signer model**: Agent NFT owner is sole authorizer
3. **No dispute mechanism**: Feedback cannot be challenged on-chain
4. **Gas costs**: Large batch operations may be expensive

## Development

### Project Structure

```
contracts/
├── src/
│   ├── StrategyRegistry.sol      # ERC-721 identity registry
│   ├── StrategyReputation.sol    # Reputation contract
│   └── interfaces/
│       ├── IStrategyRegistry.sol
│       └── IStrategyReputation.sol
├── test/
│   ├── StrategyRegistry.t.sol
│   └── StrategyReputation.t.sol
├── script/
│   └── Deploy.s.sol
└── foundry.toml
```

### Tech Stack

- **Solidity**: 0.8.30
- **Framework**: Foundry
- **Dependencies**: OpenZeppelin Contracts v5.1.0
- **Testing**: Forge (via-IR compilation enabled)
- **Package Manager**: Bun

### Contributing

This project follows Foundry best practices:
- Use `forge fmt` for code formatting
- All tests must pass before PR
- Gas optimization via via-IR compilation
- NatSpec comments for all public functions

## License

MIT

## Resources

- [ERC-8004 Specification](https://eips.ethereum.org/EIPS/eip-8004)
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [EIP-712 Standard](https://eips.ethereum.org/EIPS/eip-712)
