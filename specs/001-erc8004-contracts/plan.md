# Implementation Plan: ERC-8004 Smart Contracts for Agent Discovery

**Branch**: `001-erc8004-contracts` | **Date**: 2025-11-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-erc8004-contracts/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement two ERC-8004 compliant smart contracts for the Giza Open Strategies ecosystem: StrategyRegistry (Identity Registry) and StrategyReputation (Reputation Registry). The StrategyRegistry provides ERC-721-based on-chain identities for service agents, while StrategyReputation manages feedback submissions with EIP-712 signature authorization and per-client-per-agent index tracking. The contracts emit events for off-chain indexing and provide basic reputation aggregation without filtering capabilities.

## Technical Context

**Language/Version**: Solidity 0.8.30
**Primary Dependencies**: OpenZeppelin Contracts (ERC721URIStorage, EIP712, ECDSA), Foundry framework
**Storage**: On-chain state (agent NFTs, feedback records, client indices) - no off-chain database needed
**Testing**: Forge test (Foundry's testing framework) - tests for critical business logic only
**Target Platform**: Base Sepolia testnet (EVM-compatible L2)
**Project Type**: Smart contracts (single component of multi-component architecture)
**Performance Goals**: Standard EVM transaction throughput, optimize for feedback submission gas costs
**Constraints**: Base Sepolia gas limits, ERC-721 standard compliance, permanent on-chain storage
**Scale/Scope**: MVP for testing - designed to handle hundreds of agents and thousands of feedback entries

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Research Check (Phase 0)

| Principle | Compliance | Notes |
|-----------|------------|-------|
| **Multi-Component Architecture** | ✅ PASS | Smart contracts are one of four components (contracts, indexer, client server, service server). Clear boundaries via events and function interfaces. |
| **Simplicity and DRY** | ✅ PASS | Simple contract design, inheriting from standard OpenZeppelin implementations. Minimal abstraction until duplication appears. |
| **Bun for Package Manager** | ✅ PASS | Solidity dependencies (OpenZeppelin) managed via `bun add` with remappings.txt, no git submodules. |
| **Solidity Library Management** | ✅ PASS | Will use `bun add @openzeppelin/contracts` and configure remappings.txt. |
| **Testing Strategy** | ✅ PASS | Tests SHOULD be written for critical business logic (signature verification, index tracking). No integration test requirements. |
| **Speed Over Security** | ✅ PASS | Focus on functional correctness. Basic input validation (score bounds, agentId existence). No formal audit required for MVP. |

**Status**: ✅ All gates passed - proceeding to Phase 0

### Post-Design Check (Phase 1)

| Principle | Compliance | Notes |
|-----------|------------|-------|
| **Multi-Component Architecture** | ✅ PASS | Contracts emit `Registered` and `NewFeedback` events for indexer consumption. No cross-contract dependencies beyond StrategyReputation → StrategyRegistry reference. |
| **Simplicity and DRY** | ✅ PASS | Data model uses standard mappings and structs. Reputation calculation logic is simple sum/count. No complex patterns. |
| **Bun for Package Manager** | ✅ PASS | Dependencies added via bun, remappings configured for OpenZeppelin imports. |
| **Solidity Library Management** | ✅ PASS | Using npm-published OpenZeppelin contracts, not git submodules. |
| **Testing Strategy** | ✅ PASS | Test plan focuses on signature verification, index enforcement, and reputation calculation - critical business logic only. |
| **Speed Over Security** | ✅ PASS | Basic validation implemented. Signature verification uses battle-tested OpenZeppelin libraries. No custom cryptography. |

**Status**: ✅ All gates passed - design approved

## Project Structure

### Documentation (this feature)

```text
specs/001-erc8004-contracts/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - Solidity patterns, EIP-712 research
├── data-model.md        # Phase 1 output - Contract state and data structures
├── quickstart.md        # Phase 1 output - Build and deployment guide
├── contracts/           # Phase 1 output - Contract interfaces and ABIs
│   ├── StrategyRegistry.interface.md
│   └── StrategyReputation.interface.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
contracts/
├── src/
│   ├── StrategyRegistry.sol        # ERC-721 identity registry
│   ├── StrategyReputation.sol      # EIP-712 reputation contract
│   └── interfaces/
│       └── IStrategyRegistry.sol   # Interface for cross-contract calls
├── test/
│   ├── StrategyRegistry.t.sol      # Foundry tests for registration
│   └── StrategyReputation.t.sol    # Foundry tests for feedback & reputation
├── script/
│   └── Deploy.s.sol                # Foundry deployment script
├── foundry.toml                    # Foundry configuration
└── remappings.txt                  # Solidity import mappings for dependencies

.gitignore                          # Include Foundry artifacts (out/, cache/, broadcast/)
package.json                        # Bun dependencies for Solidity libraries
bun.lockb                           # Bun lockfile
```

**Structure Decision**: Single project structure (Option 1) for smart contracts component. Contracts are organized by domain (registry vs reputation) with clear separation. Testing follows Foundry conventions with `.t.sol` suffix. Deployment scripts use `.s.sol` suffix per Foundry standards.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations detected** - all constitution principles are satisfied by this design.

## Phase 0: Research & Technical Decisions

### Research Topics

1. **EIP-712 Signature Structure for FeedbackAuth**
   - How to structure typed data for agentId, clientAddress, indexLimit, expiry, chainId
   - Domain separator configuration for Base Sepolia
   - Signature recovery and verification patterns in Solidity
   - Reference: ERC-8004 reference implementation

2. **Per-Client-Per-Agent Index Tracking**
   - Optimal storage pattern: nested mapping vs single mapping with composite key
   - Gas cost comparison for different approaches
   - Index increment and boundary checking patterns

3. **Reputation Aggregation Patterns**
   - On-chain vs off-chain aggregation tradeoffs
   - Gas-efficient average calculation with overflow protection
   - Storage patterns for feedback arrays vs running totals

4. **ERC-721 Integration with Custom Logic**
   - Extending ERC721URIStorage for agent identity
   - Owner verification for feedbackAuth validation
   - Event emission best practices for indexer consumption

5. **OpenZeppelin Dependencies via Bun**
   - Correct package: `@openzeppelin/contracts`
   - Remappings.txt configuration for imports
   - Version selection (latest stable 5.x or 4.x for compatibility)

### Decisions to Document

- Storage pattern for client feedback indices
- Signature verification approach (EIP712 vs raw keccak256)
- Reputation calculation strategy (on-demand vs cached)
- Event structure for indexer optimization
- Starting agentId value (0 or 1)
- Error handling patterns (revert strings vs custom errors)

## Phase 1: Design Artifacts

### Data Model (data-model.md)

**State Variables**:
- StrategyRegistry: NFT counter, tokenURI mappings (inherited from ERC721URIStorage)
- StrategyReputation: feedback storage, client indices, identity registry reference

**Entities**:
- Agent (NFT): agentId, owner, tokenURI
- Feedback: agentId, clientAddress, score, tag1, tag2, fileuri, filehash, timestamp
- ClientIndex: mapping(agentId => mapping(clientAddress => uint256))

**Relationships**:
- StrategyReputation has reference to StrategyRegistry (constructor parameter)
- Feedback entries linked to agentId
- Client indices scoped by agentId and clientAddress

### Contract Interfaces (contracts/)

**StrategyRegistry.interface.md**:
- `register(string tokenURI) returns (uint256 agentId)` - Public
- `tokenURI(uint256 agentId) returns (string)` - Public view (inherited)
- `ownerOf(uint256 agentId) returns (address)` - Public view (inherited)
- Event: `Registered(uint256 indexed agentId, string tokenURI, address indexed owner)`

**StrategyReputation.interface.md**:
- `giveFeedback(uint256 agentId, uint8 score, bytes32 tag1, bytes32 tag2, string fileuri, bytes32 filehash, bytes feedbackAuth)` - Public
- `getSummary(uint256 agentId) returns (uint64 count, uint8 averageScore)` - Public view
- `getClientIndex(uint256 agentId, address clientAddress) returns (uint256)` - Public view
- Event: `NewFeedback(uint256 indexed agentId, address indexed clientAddress, uint8 score, bytes32 indexed tag1, bytes32 tag2, string fileuri, bytes32 filehash)`

### Quickstart (quickstart.md)

**Prerequisites**:
- Bun installed
- Foundry installed (`foundryup`)

**Setup**:
1. Install dependencies: `bun install`
2. Build contracts: `forge build`
3. Run tests: `forge test`

**Deployment**:
1. Configure `.env` with private key and RPC URL
2. Deploy: `forge script script/Deploy.s.sol --rpc-url base-sepolia --broadcast`
3. Verify: `forge verify-contract <address> <contract> --chain base-sepolia`

## Phase 2: Task Generation

**Not included in this plan** - use `/speckit.tasks` command to generate actionable tasks from this plan and the data model.
