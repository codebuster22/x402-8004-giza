# Quickstart: ERC-8004 Smart Contracts

**Feature**: 001-erc8004-contracts | **Date**: 2025-11-05

## Overview

This guide walks you through setting up, building, testing, and deploying the StrategyRegistry and StrategyReputation contracts for the Giza Open Strategies project.

---

## Prerequisites

Ensure you have the following installed:

### Required Tools

1. **Bun** (v1.0+)
   ```bash
   curl -fsSL https://bun.sh/install | bash
   ```

2. **Foundry** (latest)
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

3. **Git**
   ```bash
   # Should already be installed
   git --version
   ```

### Verify Installation

```bash
bun --version   # Should show 1.0+
forge --version # Should show foundryup output
cast --version  # Part of Foundry suite
```

---

## Project Setup

### 1. Navigate to Contracts Directory

```bash
cd contracts
```

### 2. Install Dependencies

```bash
# Install OpenZeppelin contracts via Bun (NOT Foundry)
bun add @openzeppelin/contracts@^5.1.0

# Foundry will detect dependencies via remappings.txt
```

### 3. Configure Remappings

Create or verify `remappings.txt`:

```bash
echo "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/" > remappings.txt
```

### 4. Verify Foundry Configuration

Check `foundry.toml`:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["node_modules"]
solc_version = "0.8.20"
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
base_sepolia = "${BASE_SEPOLIA_RPC_URL}"
```

---

## Build & Test

### Build Contracts

```bash
forge build
```

**Expected Output**:
```
[⠊] Compiling...
[⠒] Compiling 5 files with 0.8.20
[⠢] Solc 0.8.20 finished in 2.34s
Compiler run successful!
```

**Artifacts**:
- Compiled contracts: `out/`
- ABIs: `out/<ContractName>.sol/<ContractName>.json`

### Run Tests

```bash
forge test
```

**Expected Output**:
```
Running 12 tests for test/StrategyRegistry.t.sol:StrategyRegistryTest
[PASS] testRegister() (gas: 142536)
[PASS] testRegisterEmitsEvent() (gas: 145021)
...

Running 18 tests for test/StrategyReputation.t.sol:StrategyReputationTest
[PASS] testGiveFeedback() (gas: 198742)
[PASS] testSignatureVerification() (gas: 201359)
...

Test result: ok. 30 passed; 0 failed; finished in 42.18ms
```

### Run Tests with Gas Report

```bash
forge test --gas-report
```

### Run Tests with Verbosity

```bash
forge test -vvv  # Show traces for failing tests
```

---

## Local Development

### Start Local Anvil Node

```bash
# In separate terminal
anvil
```

**Anvil provides**:
- 10 pre-funded accounts
- Instant block mining
- RPC endpoint: `http://localhost:8545`

### Deploy to Local Node

```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <anvil-private-key>
```

**Example with Anvil's first account**:
```bash
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

---

## Base Sepolia Deployment

### 1. Set Up Environment Variables

Create `.env` file in `contracts/` directory:

```env
# Base Sepolia RPC (get from https://www.quicknode.com/ or Alchemy)
BASE_SEPOLIA_RPC_URL=https://base-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Deployer private key (NEVER commit this!)
PRIVATE_KEY=0x...

# Etherscan API key for verification (get from https://basescan.org/)
BASESCAN_API_KEY=YOUR_API_KEY
```

**Load environment**:
```bash
source .env
```

### 2. Fund Deployer Account

- Get Base Sepolia ETH from: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- Or bridge from Sepolia: https://bridge.base.org/

**Check balance**:
```bash
cast balance <your-address> --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 3. Deploy Contracts

```bash
forge script script/Deploy.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY \
  --private-key $PRIVATE_KEY
```

**Expected Output**:
```
== Logs ==
StrategyRegistry deployed to: 0x1234567890123456789012345678901234567890
StrategyReputation deployed to: 0xABCDEF0123456789012345678901234567890ABC

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
Total Paid: 0.00123 ETH (412000 gas * avg 3 gwei)
```

### 4. Verify Deployment

**Check on BaseScan**:
- Registry: https://sepolia.basescan.org/address/0x1234...
- Reputation: https://sepolia.basescan.org/address/0xABCD...

**Verify contracts are verified**:
```bash
# Should show "Contract Source Code Verified"
```

---

## Interacting with Deployed Contracts

### Using Cast (CLI)

#### Register an Agent

```bash
# 1. Upload metadata to IPFS (use pinata.cloud or similar)
# 2. Register agent
cast send <REGISTRY_ADDRESS> \
  "register(string)" \
  "ipfs://QmYourMetadataHash" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# Get agentId from event logs
cast logs --address <REGISTRY_ADDRESS> \
  --from-block latest \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

#### Query Agent Info

```bash
# Get owner
cast call <REGISTRY_ADDRESS> \
  "ownerOf(uint256)" \
  1 \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Get tokenURI
cast call <REGISTRY_ADDRESS> \
  "tokenURI(uint256)" \
  1 \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

#### Get Reputation Summary

```bash
cast call <REPUTATION_ADDRESS> \
  "getSummary(uint256)" \
  1 \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Returns: (count, averageScore) as tuple
```

### Using Ethers.js (JavaScript/TypeScript)

```javascript
import { ethers } from 'ethers';

// Connect to Base Sepolia
const provider = new ethers.JsonRpcProvider(process.env.BASE_SEPOLIA_RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// Load contracts
const registryABI = [...]; // Load from out/StrategyRegistry.sol/StrategyRegistry.json
const reputationABI = [...]; // Load from out/StrategyReputation.sol/StrategyReputation.json

const registry = new ethers.Contract(REGISTRY_ADDRESS, registryABI, wallet);
const reputation = new ethers.Contract(REPUTATION_ADDRESS, reputationABI, wallet);

// Register agent
const tx = await registry.register("ipfs://QmYourHash");
const receipt = await tx.wait();
const agentId = receipt.logs[0].args.agentId;
console.log('Registered agentId:', agentId);

// Query reputation
const [count, avgScore] = await reputation.getSummary(agentId);
console.log(`Reputation: ${avgScore} (from ${count} feedbacks)`);
```

---

## Testing Workflow

### Test Strategy

Per constitution (Principle VI), tests focus on critical business logic:

1. **StrategyRegistry** (7 tests):
   - Register basic functionality
   - Event emission
   - TokenURI storage
   - Transfer ownership
   - Empty tokenURI allowed

2. **StrategyReputation** (18 tests):
   - Signature verification (EIP-712)
   - Index tracking and increments
   - Index limit enforcement
   - Expiry validation
   - Signer authorization (agent owner)
   - Reputation calculation
   - Multiple feedbacks from same client

### Running Specific Tests

```bash
# Run only StrategyRegistry tests
forge test --match-contract StrategyRegistryTest

# Run only signature tests
forge test --match-test testSignature

# Run with coverage
forge coverage
```

### Writing New Tests

Create test file in `test/` directory:

```solidity
// test/MyFeature.t.sol
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/StrategyReputation.sol";

contract MyFeatureTest is Test {
    StrategyReputation reputation;

    function setUp() public {
        // Deploy contracts
        reputation = new StrategyReputation(address(registry));
    }

    function testMyFeature() public {
        // Test code
    }
}
```

---

## Common Tasks

### Update Dependencies

```bash
# Update OpenZeppelin
cd contracts
bun update @openzeppelin/contracts

# Rebuild
forge build
```

### Clean Build Artifacts

```bash
forge clean
```

### Format Code

```bash
forge fmt
```

### Generate ABI

ABIs are automatically generated in `out/` directory:

```bash
# Extract ABI
cat out/StrategyRegistry.sol/StrategyRegistry.json | jq '.abi' > StrategyRegistry.abi.json
```

---

## Troubleshooting

### Build Fails: "Cannot find module"

**Problem**: Remappings not configured correctly

**Solution**:
```bash
echo "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/" > remappings.txt
forge build
```

### Deployment Fails: "Insufficient funds"

**Problem**: Not enough ETH in deployer account

**Solution**: Get Base Sepolia ETH from faucet or check balance:
```bash
cast balance <your-address> --rpc-url $BASE_SEPOLIA_RPC_URL
```

### Tests Fail: "EIP712: invalid signature"

**Problem**: Signature generation doesn't match on-chain verification

**Solution**: Verify EIP-712 domain matches deployed contract:
- chainId: 84532 (Base Sepolia)
- verifyingContract: actual deployed address
- name: "StrategyReputation"
- version: "1"

### Verification Fails

**Problem**: Etherscan can't verify source code

**Solution**: Manually verify:
```bash
forge verify-contract \
  <CONTRACT_ADDRESS> \
  src/StrategyRegistry.sol:StrategyRegistry \
  --chain base-sepolia \
  --etherscan-api-key $BASESCAN_API_KEY
```

---

## Next Steps

After successful deployment:

1. **Record Addresses**: Save contract addresses to project documentation
2. **Update Indexer Config**: Configure Ponder with contract addresses and start blocks
3. **Test Integration**: Register a test agent and submit feedback
4. **Deploy Service Agent**: Set up Hono server with X402 middleware
5. **Deploy Client Agent**: Implement discovery and feedback submission

---

## Reference

### Important Files

- `src/StrategyRegistry.sol` - Identity registry contract
- `src/StrategyReputation.sol` - Reputation contract
- `test/StrategyRegistry.t.sol` - Registry tests
- `test/StrategyReputation.t.sol` - Reputation tests
- `script/Deploy.s.sol` - Deployment script
- `foundry.toml` - Foundry configuration
- `remappings.txt` - Solidity import mappings

### Useful Commands

```bash
# Build
forge build

# Test
forge test
forge test -vvv  # verbose
forge test --gas-report

# Deploy (local)
anvil  # in separate terminal
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy (Base Sepolia)
forge script script/Deploy.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --private-key $PRIVATE_KEY

# Cast (interact with contracts)
cast call <address> "function(args)" --rpc-url <rpc>
cast send <address> "function(args)" --rpc-url <rpc> --private-key <key>
cast logs --address <address> --from-block latest --rpc-url <rpc>

# Utilities
forge clean
forge fmt
forge coverage
```

### External Resources

- **Foundry Book**: https://book.getfoundry.sh/
- **OpenZeppelin Docs**: https://docs.openzeppelin.com/contracts/5.x/
- **Base Sepolia Faucet**: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- **BaseScan Explorer**: https://sepolia.basescan.org/
- **EIP-712 Spec**: https://eips.ethereum.org/EIPS/eip-712
- **ERC-8004 Reference**: https://raw.githubusercontent.com/ChaosChain/trustless-agents-erc-ri/refs/heads/main/src/ReputationRegistry.sol

---

**Last Updated**: 2025-11-05 | **Version**: 1.0
