# X402 Protocol Implementation Guide

> **Purpose:** This guide helps developers understand how to implement the X402 protocol for crypto-native payments in APIs. Designed for MVP/experimental projects to showcase how HTTP 402 payment-gated endpoints work.

---

## Table of Contents

1. [What is X402?](#what-is-x402)
2. [Framework Choice: Hono](#framework-choice-hono)
3. [Core Components](#core-components)
4. [Payment Flow](#payment-flow)
5. [402 Response Structure](#402-response-structure)
6. [X-PAYMENT Header](#x-payment-header)
7. [Required Packages](#required-packages)
8. [Environment Configuration](#environment-configuration)
9. [Service Agent Implementation Pattern](#service-agent-implementation-pattern)
10. [Client Agent Implementation Pattern](#client-agent-implementation-pattern)
11. [Testing Guide](#testing-guide)
12. [References](#references)

---

## What is X402?

X402 is an open payment protocol that activates the dormant **HTTP 402 "Payment Required"** status code for crypto-native payments over HTTP.

**Key Concepts:**
- **HTTP 402** was reserved in the HTTP spec but never used until X402
- Enables **programmatic, machine-to-machine** payments without accounts or subscriptions
- Built for **AI agents, APIs, and pay-per-use** services
- Uses **stablecoins** (typically USDC) on EVM chains (Base, Ethereum, Polygon) or Solana
- **Settlement time:** ~200ms on rollups like Base

**Why It Matters:**
Traditional payment systems require account creation, credit cards, and session management. X402 allows a client to pay for a resource on-the-fly using only a crypto wallet—ideal for autonomous agents and micropayments.

---

## Framework Choice: Hono

**Recommended Framework: Hono**

For Bun servers (used in both `service-agent` and `client-agent`), **Hono** is the best choice:

✅ **Lightweight** (~12KB) and extremely fast
✅ **Built on Web Standards** - works on Bun, Deno, Node.js, Cloudflare Workers
✅ **Express-like API** - familiar and easy to learn
✅ **TypeScript-first** - excellent type safety
✅ **Official X402 support** - `x402-hono` middleware package available

**Alternative:** Bun's built-in HTTP router (for simpler use cases)

**Not recommended for this project:** Express (slower, Node.js-centric)

---

## Core Components

X402 involves four key components:

### 1. **Client (Buyer)**
- Makes requests to paid endpoints
- Handles 402 responses
- Signs and submits payments
- Retries requests with payment proof

### 2. **Server (Seller)**
- Serves paid endpoints
- Returns 402 when payment required
- Verifies payment proofs
- Delivers resources after payment confirmation

### 3. **Facilitator**
- **Optional service** that simplifies payment verification and settlement
- Verifies signed payment payloads
- Submits transactions to blockchain
- Does NOT hold funds (non-custodial)
- **Public facilitators available** (no need to build your own)

### 4. **Blockchain**
- Where actual payment settlement occurs
- For this project: **Base Sepolia** (testnet)
- Tokens: USDC or native ETH

---

## Payment Flow

**Step-by-step flow:**

```
1. Client → Server: GET /sessions (no payment header)

2. Server → Client: HTTP 402 Payment Required
   {
     "maxAmountRequired": "0.001",
     "payTo": "0xSellerWallet...",
     "asset": "0xUSDC...",
     "network": "base-sepolia",
     "resource": "/sessions"
   }

3. Client: Signs payment authorization with wallet

4. Client → Server: POST /sessions
   Headers: { "X-PAYMENT": "<signed-payment-proof>" }

5. Server → Facilitator: Verify payment

6. Facilitator → Blockchain: Settle transaction

7. Server → Client: 200 OK { "sessionKey": "..." }
```

**Key Points:**
- Client attempts request **without** payment first
- Server responds with **402** and payment instructions
- Client **signs** payment (using wallet private key)
- Client **retries** with payment proof in `X-PAYMENT` header
- Server **verifies** via facilitator before serving resource

---

## 402 Response Structure

When payment is required, the server returns HTTP status code **402** with a JSON body:

**Example 402 Response:**

```json
HTTP/1.1 402 Payment Required
Content-Type: application/json

{
  "maxAmountRequired": "0.001",
  "resource": "/sessions",
  "description": "Access to strategy signals requires payment",
  "payTo": "0xABCDEF1234567890ABCDEF1234567890ABCDEF12",
  "asset": "0xA0b86991C6218b36c1d19D4a2e9Eb0cE3606EB48",
  "network": "base-sepolia"
}
```

**Field Descriptions:**

| Field | Description |
|-------|-------------|
| `maxAmountRequired` | Price in token units (e.g., "0.001" = 0.001 USDC) |
| `resource` | The endpoint being requested |
| `description` | Human-readable payment reason |
| `payTo` | Seller's wallet address (where payment goes) |
| `asset` | Token contract address (USDC, ETH, etc.) |
| `network` | Blockchain network (base-sepolia, ethereum-mainnet, etc.) |

---

## X-PAYMENT Header

After paying, the client retries the request with payment proof in the **X-PAYMENT** header.

**What It Contains:**
- Signed payment authorization
- Uses **ERC-3009 `TransferWithAuthorization`** standard (gasless transfers)
- Includes a **nonce** to prevent replay attacks

**Example Request:**

```http
POST /sessions HTTP/1.1
Host: service-agent.example.com
X-PAYMENT: <base64-encoded-signed-payment-proof>
Content-Type: application/json
```

**How It Works:**
- Client signs payment data with private key
- Facilitator verifies signature and checks nonce hasn't been used
- Server only accepts valid, unused payment proofs
- **Replay protection:** Each nonce can only be used once

---

## Required Packages

### Service Agent (Server)

```bash
cd service-agent
bun add hono x402-hono viem dotenv
```

**Packages:**
- `hono` - Web framework
- `x402-hono` - X402 middleware for Hono
- `viem` - Ethereum library for wallet operations
- `dotenv` - Environment variable management

### Client Agent (Client)

```bash
cd client-agent
bun add axios x402-axios viem dotenv
```

**Packages:**
- `axios` - HTTP client
- `x402-axios` - Axios interceptor that auto-handles 402 responses
- `viem` - Ethereum library for wallet operations
- `dotenv` - Environment variable management

---

## Environment Configuration

### Service Agent `.env`

```env
PORT=3000
PRIVATE_KEY=0xYourServiceAgentPrivateKey
PAYMENT_WALLET_ADDRESS=0xYourWalletWhereYouReceivePayments
FACILITATOR_URL=https://x402.org/facilitator
RPC_URL=https://sepolia.base.org
```

### Client Agent `.env`

```env
PRIVATE_KEY=0xYourClientAgentPrivateKey
SERVICE_AGENT_URL=http://localhost:3000
FACILITATOR_URL=https://x402.org/facilitator
RPC_URL=https://sepolia.base.org
```

**Important:**
- Use **Base Sepolia** testnet for development
- Get testnet ETH from [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-sepolia-faucet)
- **Public facilitator:** `https://x402.org/facilitator` (free, no setup required)

---

## Service Agent Implementation Pattern

**Basic Hono server with X402 middleware:**

```typescript
import { Hono } from 'hono';
import { x402Middleware } from 'x402-hono';
import { createPublicClient, http } from 'viem';
import { baseSepolia } from 'viem/chains';
import 'dotenv/config';

const app = new Hono();

// Configure blockchain client
const publicClient = createPublicClient({
  chain: baseSepolia,
  transport: http(process.env.RPC_URL)
});

// Protected endpoint with payment requirement
app.post('/sessions',
  x402Middleware({
    payTo: process.env.PAYMENT_WALLET_ADDRESS,
    price: '0.001',
    network: 'base-sepolia',
    facilitatorUrl: process.env.FACILITATOR_URL,
    client: publicClient
  }),
  async (c) => {
    // Payment verified - generate session key
    const sessionKey = crypto.randomUUID();
    return c.json({ sessionKey });
  }
);

// Public endpoint (no payment)
app.get('/health', (c) => c.json({ status: 'ok' }));

export default {
  port: process.env.PORT || 3000,
  fetch: app.fetch,
};
```

**What the Middleware Does:**
1. Checks if request has `X-PAYMENT` header
2. If no header → returns 402 with payment details
3. If header present → verifies payment via facilitator
4. If payment invalid/used → returns 402
5. If payment valid → allows request to proceed

---

## Client Agent Implementation Pattern

**Using `x402-axios` interceptor (automatic handling):**

```typescript
import axios from 'axios';
import { withPaymentInterceptor } from 'x402-axios';
import { privateKeyToAccount } from 'viem/accounts';
import { createWalletClient, http } from 'viem';
import { baseSepolia } from 'viem/chains';
import 'dotenv/config';

// Set up wallet
const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);
const walletClient = createWalletClient({
  account,
  chain: baseSepolia,
  transport: http(process.env.RPC_URL)
});

// Create axios client with payment interceptor
const paidClient = withPaymentInterceptor(
  axios.create({ baseURL: process.env.SERVICE_AGENT_URL }),
  walletClient
);

// Make paid request (automatically handles 402)
async function requestSession() {
  try {
    const response = await paidClient.post('/sessions');
    console.log('Session key received:', response.data.sessionKey);
    return response.data.sessionKey;
  } catch (error) {
    console.error('Failed to get session:', error);
    throw error;
  }
}

requestSession();
```

**What the Interceptor Does:**
1. Makes initial request
2. Detects 402 response automatically
3. Signs payment using wallet
4. Retries request with `X-PAYMENT` header
5. Returns final response (or throws error if payment fails)

---

## Testing Guide

### 1. Start Service Agent

```bash
cd service-agent
bun run index.ts
```

Expected output: `Server running on http://localhost:3000`

### 2. Test Without Payment (Expect 402)

```bash
curl -X POST http://localhost:3000/sessions
```

**Expected Response:**

```json
HTTP/1.1 402 Payment Required

{
  "maxAmountRequired": "0.001",
  "payTo": "0x...",
  "asset": "0x...",
  "network": "base-sepolia",
  "resource": "/sessions"
}
```

### 3. Test With Client Agent (Automatic Payment)

```bash
cd client-agent
bun run index.ts
```

**Expected Output:**

```
Session key received: abc-123-xyz-789
```

### 4. Verification Checklist

- [ ] Service agent starts without errors
- [ ] GET /health returns 200 OK
- [ ] POST /sessions without payment returns 402
- [ ] 402 response includes correct payment metadata
- [ ] Client agent can make payment and receive session key
- [ ] Same payment nonce cannot be reused (replay protection)

---

## References

### Official X402 Documentation
- **Main Docs:** https://x402.gitbook.io/x402
- **Quickstart for Sellers:** https://x402.gitbook.io/x402/getting-started/quickstart-for-sellers
- **HTTP 402 Concept:** https://x402.gitbook.io/x402/core-concepts/http-402
- **Client/Server Model:** https://x402.gitbook.io/x402/core-concepts/client-server
- **Facilitator Guide:** https://x402.gitbook.io/x402/core-concepts/facilitator

### Code Examples
- **GitHub Repository:** https://github.com/coinbase/x402
- **TypeScript Examples:** https://github.com/coinbase/x402/tree/main/examples/typescript

### Additional Resources
- **QuickNode Guide:** https://www.quicknode.com/guides/infrastructure/how-to-use-x402-payment-required
- **Base Sepolia Faucet:** https://www.coinbase.com/faucets/base-sepolia-faucet
- **Public Facilitator:** https://x402.org/facilitator

---

**Last Updated:** 2025-11-05