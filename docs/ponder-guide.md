# Ponder Indexer Guide: Giza Open Strategies

> **Purpose:** Build an indexer for ERC-8004 agent discovery using Ponder on Base Sepolia. This indexer enables the Client Agent (Giza Agent) to discover Service Agents by tags and reputation.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Project Setup](#project-setup)
4. [Configuration](#configuration)
5. [Schema Design](#schema-design)
6. [Event Handlers](#event-handlers)
7. [Discovery API](#discovery-api)
8. [Testing](#testing)
9. [Deployment](#deployment)
10. [References](#references)

---

## Introduction

### What This Indexer Does

This Ponder indexer is part of the **Giza Open Strategies** project, which implements:
- **ERC-8004** agent identity and reputation system
- **X402** payment-gated API access

**The Indexer's Role:**
1. Listens to on-chain events from StrategyRegistry and StrategyReputation contracts
2. Fetches and parses agent registration files from IPFS/HTTPS
3. Stores agent metadata (name, tags, endpoints) for searchability
4. Aggregates reputation scores from feedback events
5. Provides a discovery API for Client Agents to query agents by tags and reputation

**Key Features:**
- Tag-based filtering (e.g., `GET /agents?tags=memecoin,trading`)
- Reputation-based filtering (e.g., `minReputation=80`)
- Real-time updates as new agents register and receive feedback

---

## Prerequisites

### Required

- **Bun runtime** installed
- **Base Sepolia RPC URL** (e.g., from Alchemy, QuickNode, or public RPC)
- **Deployed contracts:**
  - StrategyRegistry (Identity Registry)
  - StrategyReputation (Reputation Registry)
- **Contract ABIs** exported as TypeScript files

### Environment Setup

Create `.env` file:

```env
# RPC
PONDER_RPC_URL_BASE_SEPOLIA=https://sepolia.base.org

# Contract Addresses (Base Sepolia)
STRATEGY_REGISTRY_ADDRESS=0xYourStrategyRegistryAddress
STRATEGY_REPUTATION_ADDRESS=0xYourStrategyReputationAddress

# Contract Start Blocks (optional but recommended for faster sync)
STRATEGY_REGISTRY_START_BLOCK=12345678
STRATEGY_REPUTATION_START_BLOCK=12345678

# Database (Ponder uses SQLite by default, PostgreSQL for production)
DATABASE_URL=postgresql://user:password@localhost:5432/ponder

# API Server
API_PORT=42069
```

---

## Project Setup

### 1. Create Ponder Project

```bash
bun create ponder
cd <project-name>
```

### 2. Install Additional Dependencies

```bash
bun add drizzle-orm
```

### 3. Project Structure

```
.
├── ponder.config.ts       # Chain and contract configuration
├── ponder.schema.ts       # Database schema (tables)
├── src/
│   ├── index.ts           # Event handlers
│   └── api.ts             # Discovery API endpoints
├── abis/
│   ├── StrategyRegistry.ts
│   └── StrategyReputation.ts
└── .env
```

### 4. Export Contract ABIs

Place your contract ABIs in `/abis/` as TypeScript files:

**abis/StrategyRegistry.ts:**
```typescript
export const StrategyRegistryAbi = [
  {
    type: "event",
    name: "Registered",
    inputs: [
      { name: "agentId", type: "uint256", indexed: true },
      { name: "tokenURI", type: "string", indexed: false },
      { name: "owner", type: "address", indexed: true }
    ]
  },
  // ... other functions/events
] as const;
```

**abis/StrategyReputation.ts:**
```typescript
export const StrategyReputationAbi = [
  {
    type: "event",
    name: "NewFeedback",
    inputs: [
      { name: "agentId", type: "uint256", indexed: true },
      { name: "clientAddress", type: "address", indexed: true },
      { name: "score", type: "uint8", indexed: false },
      { name: "tag1", type: "bytes32", indexed: true },
      { name: "tag2", type: "bytes32", indexed: false },
      { name: "fileuri", type: "string", indexed: false },
      { name: "filehash", type: "bytes32", indexed: false }
    ]
  },
  // ... other functions/events
] as const;
```

---

## Configuration

### ponder.config.ts

Configure chains and contracts to index:

```typescript
import { createConfig } from "ponder";
import { http } from "viem";

import { StrategyRegistryAbi } from "./abis/StrategyRegistry";
import { StrategyReputationAbi } from "./abis/StrategyReputation";

export default createConfig({
  networks: {
    baseSepolia: {
      chainId: 84532,
      transport: http(process.env.PONDER_RPC_URL_BASE_SEPOLIA),
    },
  },
  contracts: {
    StrategyRegistry: {
      abi: StrategyRegistryAbi,
      network: "baseSepolia",
      address: process.env.STRATEGY_REGISTRY_ADDRESS as `0x${string}`,
      startBlock: parseInt(process.env.STRATEGY_REGISTRY_START_BLOCK || "0"),
    },
    StrategyReputation: {
      abi: StrategyReputationAbi,
      network: "baseSepolia",
      address: process.env.STRATEGY_REPUTATION_ADDRESS as `0x${string}`,
      startBlock: parseInt(process.env.STRATEGY_REPUTATION_START_BLOCK || "0"),
    },
  },
});
```

**Key Points:**
- Only **2 contracts** (no payment handler - X402 doesn't need it)
- Use environment variables for addresses and start blocks
- Base Sepolia chainId: `84532`

---

## Schema Design

### ponder.schema.ts

Define database tables for agents and feedback:

```typescript
import { onchainTable } from "ponder";

/**
 * Agent Table
 * Stores agent identity and metadata from StrategyRegistry
 */
export const agent = onchainTable("agent", (t) => ({
  // Primary key
  agentId: t.bigint().primaryKey(),

  // From Registered event
  tokenURI: t.text().notNull(),
  owner: t.hex().notNull(),

  // Parsed from registration file (fetched via tokenURI)
  name: t.text().notNull(),
  description: t.text(),
  tags: t.json().$type<string[]>(), // CRITICAL for discovery filtering
  endpoints: t.json().$type<any[]>(),
  image: t.text(),

  // Reputation aggregation
  reputationCount: t.integer().notNull().default(0),
  reputationAverage: t.integer().notNull().default(0), // 0-100

  // Timestamps
  createdAt: t.bigint().notNull(),
  updatedAt: t.bigint().notNull(),
}));

/**
 * Feedback Table
 * Stores feedback from StrategyReputation
 */
export const feedback = onchainTable("feedback", (t) => ({
  // Composite primary key: agentId-clientAddress-timestamp
  id: t.text().primaryKey(),

  agentId: t.bigint().notNull(),
  clientAddress: t.hex().notNull(),
  score: t.integer().notNull(), // 0-100

  // Optional tags from feedback event
  tag1: t.text(),
  tag2: t.text(),

  // Timestamp
  timestamp: t.bigint().notNull(),
}));
```

**Schema Highlights:**

1. **agent.tags** - Array of strings enabling tag-based filtering
2. **agent.reputationAverage** - Pre-calculated average for fast queries
3. **feedback.id** - Simple string primary key (no complex composite keys needed)
4. **No payment table** - X402 doesn't emit payment events

---

## Event Handlers

### src/index.ts

Handle on-chain events and update database:

```typescript
import { ponder } from "ponder:registry";
import { agent, feedback } from "ponder:schema";
import { eq } from "ponder";

/**
 * Helper: Convert bytes32 to string (for tags)
 */
function bytes32ToString(bytes32: string): string | null {
  if (bytes32 === "0x0000000000000000000000000000000000000000000000000000000000000000") {
    return null;
  }
  // Remove 0x prefix and trailing zeros
  const hex = bytes32.slice(2).replace(/0+$/, "");
  if (hex.length === 0) return null;

  try {
    return Buffer.from(hex, "hex").toString("utf8");
  } catch {
    return null;
  }
}

/**
 * Event Handler: StrategyRegistry.Registered
 * Triggered when a new agent is registered
 */
ponder.on("StrategyRegistry:Registered", async ({ event, context }) => {
  const { agentId, tokenURI, owner } = event.args;

  console.log(`[Registered] Agent ${agentId} registered by ${owner}`);

  // Fetch registration file from tokenURI
  let metadata: any;
  try {
    const response = await fetch(tokenURI);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    metadata = await response.json();
  } catch (error) {
    console.error(`Failed to fetch tokenURI for agent ${agentId}:`, error);
    // Use fallback metadata
    metadata = {
      name: `Agent #${agentId}`,
      description: "Registration file unavailable",
      tags: [],
      endpoints: [],
    };
  }

  // Insert agent into database
  await context.db.insert(agent).values({
    agentId: agentId,
    tokenURI: tokenURI,
    owner: owner,
    name: metadata.name || `Agent #${agentId}`,
    description: metadata.description || "",
    tags: metadata.tags || [],
    endpoints: metadata.endpoints || [],
    image: metadata.image || null,
    reputationCount: 0,
    reputationAverage: 0,
    createdAt: event.block.timestamp,
    updatedAt: event.block.timestamp,
  });

  console.log(`[Registered] Agent ${agentId} indexed: ${metadata.name}`);
});

/**
 * Event Handler: StrategyReputation.NewFeedback
 * Triggered when feedback is submitted for an agent
 */
ponder.on("StrategyReputation:NewFeedback", async ({ event, context }) => {
  const { agentId, clientAddress, score, tag1, tag2 } = event.args;

  console.log(`[NewFeedback] Agent ${agentId} received score ${score} from ${clientAddress}`);

  // Parse tags (bytes32 to string)
  const tag1String = bytes32ToString(tag1);
  const tag2String = bytes32ToString(tag2);

  // Store feedback
  await context.db.insert(feedback).values({
    id: `${agentId}-${clientAddress}-${event.block.timestamp}`,
    agentId: agentId,
    clientAddress: clientAddress,
    score: Number(score),
    tag1: tag1String,
    tag2: tag2String,
    timestamp: event.block.timestamp,
  });

  // Recalculate agent reputation
  const allFeedbacks = await context.db
    .select()
    .from(feedback)
    .where(eq(feedback.agentId, agentId));

  const count = allFeedbacks.length;
  const totalScore = allFeedbacks.reduce((sum, f) => sum + f.score, 0);
  const avgScore = Math.round(totalScore / count);

  // Update agent reputation
  await context.db
    .update(agent, { agentId: agentId })
    .set({
      reputationCount: count,
      reputationAverage: avgScore,
      updatedAt: event.block.timestamp,
    });

  console.log(`[NewFeedback] Agent ${agentId} reputation updated: ${avgScore}/100 (${count} feedbacks)`);
});
```

**Handler Highlights:**

1. **Registered Handler:**
   - Fetches registration file from tokenURI (IPFS or HTTPS)
   - Parses JSON and extracts name, tags, endpoints
   - Stores in database with fallback for failed fetches

2. **NewFeedback Handler:**
   - Stores individual feedback
   - Queries all feedbacks for agent
   - Calculates new average score
   - Updates agent reputation in real-time

---

## Discovery API

### src/api.ts

Build REST API for agent discovery:

```typescript
import { ponder } from "ponder:registry";
import { agent } from "ponder:schema";
import { and, gte, sql, desc } from "ponder";

/**
 * GET /agents
 * Query parameters:
 *   - tags: comma-separated list (e.g., "memecoin,trading")
 *   - minReputation: minimum reputation score (0-100)
 *
 * Returns: Array of agents matching filters, sorted by reputation
 */
ponder.get("/agents", async (c) => {
  const tags = c.req.query("tags");
  const minReputation = c.req.query("minReputation");

  console.log(`[API] GET /agents?tags=${tags}&minReputation=${minReputation}`);

  let query = c.db.select().from(agent);

  // Filter by tags (if provided)
  if (tags) {
    const tagArray = tags.split(",").map((t) => t.trim());

    // Check if agent.tags array contains ANY of the requested tags
    // Using JSON array overlap check
    query = query.where(
      sql`EXISTS (
        SELECT 1
        FROM json_each(${agent.tags})
        WHERE value IN (${sql.join(
          tagArray.map((tag) => sql`${tag}`),
          sql`, `
        )})
      )`
    );
  }

  // Filter by minimum reputation (if provided)
  if (minReputation) {
    const minScore = parseInt(minReputation, 10);
    query = query.where(gte(agent.reputationAverage, minScore));
  }

  // Sort by reputation (highest first)
  query = query.orderBy(desc(agent.reputationAverage));

  const agents = await query;

  console.log(`[API] Returning ${agents.length} agents`);

  return c.json(agents);
});

/**
 * GET /agents/:agentId
 * Get details for a specific agent
 */
ponder.get("/agents/:agentId", async (c) => {
  const agentId = BigInt(c.req.param("agentId"));

  const agentData = await c.db
    .select()
    .from(agent)
    .where(eq(agent.agentId, agentId))
    .limit(1);

  if (agentData.length === 0) {
    return c.json({ error: "Agent not found" }, 404);
  }

  return c.json(agentData[0]);
});

/**
 * GET /health
 * Health check endpoint
 */
ponder.get("/health", async (c) => {
  return c.json({ status: "ok", timestamp: Date.now() });
});
```

**API Endpoints:**

1. **GET /agents** - Main discovery endpoint
   - Filter by tags: `/agents?tags=memecoin,trading`
   - Filter by reputation: `/agents?minReputation=80`
   - Combine filters: `/agents?tags=memecoin&minReputation=80`

2. **GET /agents/:agentId** - Get specific agent details

3. **GET /health** - Health check

**Example Response:**

```json
[
  {
    "agentId": "1",
    "tokenURI": "ipfs://QmXxx...",
    "owner": "0x742d35Cc...",
    "name": "Memecoin Trading Strategy",
    "description": "Real-time memecoin trading signals",
    "tags": ["memecoin", "trading", "signals", "defi"],
    "endpoints": [
      {
        "name": "agentWallet",
        "endpoint": "eip155:84532:0x742d35Cc..."
      }
    ],
    "image": "https://example.com/avatar.png",
    "reputationCount": 16,
    "reputationAverage": 88,
    "createdAt": "1730808600",
    "updatedAt": "1730895000"
  }
]
```

---

## Testing

### 1. Start Ponder in Development Mode

```bash
bun ponder dev
```

Expected output:
```
✓ Started indexing on baseSepolia
✓ Listening on http://localhost:42069
```

### 2. Test Event Indexing

**Deploy and register a test agent:**

```bash
# In contracts project
cast send $STRATEGY_REGISTRY_ADDRESS "register(string)" "ipfs://QmTest..." \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**Check Ponder logs:**
```
[Registered] Agent 1 registered by 0x742d35Cc...
[Registered] Agent 1 indexed: Test Agent
```

**Query API:**
```bash
curl http://localhost:42069/agents
```

### 3. Test Feedback Indexing

**Submit test feedback:**

```bash
cast send $STRATEGY_REPUTATION_ADDRESS \
  "giveFeedback(uint256,uint8,bytes32,bytes32,string,bytes32,bytes)" \
  1 95 "0x..." "0x..." "" "0x..." "0x..." \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**Check Ponder logs:**
```
[NewFeedback] Agent 1 received score 95 from 0x456...
[NewFeedback] Agent 1 reputation updated: 95/100 (1 feedbacks)
```

**Query API:**
```bash
curl http://localhost:42069/agents/1
# Should show reputationAverage: 95
```

### 4. Test Discovery Filters

**Tag filter:**
```bash
curl "http://localhost:42069/agents?tags=memecoin"
```

**Reputation filter:**
```bash
curl "http://localhost:42069/agents?minReputation=80"
```

**Combined filters:**
```bash
curl "http://localhost:42069/agents?tags=memecoin,trading&minReputation=80"
```

---

## Deployment

### Local Development

```bash
bun ponder dev
```

### Production (Self-Hosted)

**1. Use PostgreSQL database:**

```env
DATABASE_URL=postgresql://user:password@localhost:5432/ponder_production
```

**2. Start Ponder:**

```bash
bun ponder start
```

**3. Keep process running (use PM2 or systemd):**

```bash
# Using PM2
pm2 start "bun ponder start" --name ponder-indexer

# Using systemd
sudo systemctl start ponder-indexer
```

### Production (Railway/Render)

**1. Add to Railway:**
- Connect GitHub repo
- Set environment variables
- Railway auto-detects Bun and runs `bun ponder start`

**2. Configure PostgreSQL addon:**
- Railway provides `DATABASE_URL` automatically

**3. Set custom start block:**
- Set `STRATEGY_REGISTRY_START_BLOCK` to deployment block for faster sync

---

## Performance Tips

### 1. Start Block Optimization

Set start blocks to contract deployment blocks to avoid syncing from genesis:

```env
STRATEGY_REGISTRY_START_BLOCK=12345678
STRATEGY_REPUTATION_START_BLOCK=12345678
```

### 2. Database Indexing

Add database indexes for frequently queried fields:

```sql
CREATE INDEX idx_agent_tags ON agent USING GIN (tags);
CREATE INDEX idx_agent_reputation ON agent (reputationAverage DESC);
CREATE INDEX idx_feedback_agent ON feedback (agentId);
```

### 3. Caching

For high-traffic APIs, add Redis caching:

```typescript
// Cache GET /agents results for 60 seconds
const cachedResult = await redis.get("agents:" + queryHash);
if (cachedResult) return c.json(JSON.parse(cachedResult));

// ... query database ...

await redis.setex("agents:" + queryHash, 60, JSON.stringify(result));
```

---

## Troubleshooting

### Issue: "Failed to fetch tokenURI"

**Cause:** IPFS gateway timeout or invalid URL

**Solution:**
- Use fallback IPFS gateways
- Implement retry logic
- Use cached metadata for failed fetches

```typescript
const gateways = [
  "https://ipfs.io/ipfs/",
  "https://cloudflare-ipfs.com/ipfs/",
  "https://gateway.pinata.cloud/ipfs/",
];

for (const gateway of gateways) {
  try {
    const url = tokenURI.replace("ipfs://", gateway);
    const response = await fetch(url, { timeout: 5000 });
    if (response.ok) return await response.json();
  } catch {}
}
```

### Issue: "Sync too slow"

**Cause:** Syncing from block 0

**Solution:** Set start block to contract deployment block

### Issue: "API not responding"

**Cause:** Ponder dev server not exposing HTTP

**Solution:** Check `ponder.config.ts` includes HTTP server config

---

## References

### Ponder Documentation
- **Official Docs:** https://ponder.sh/docs
- **Configuration:** https://ponder.sh/docs/getting-started/config
- **Schema Design:** https://ponder.sh/docs/schema
- **Event Handlers:** https://ponder.sh/docs/indexing/overview
- **API Routes:** https://ponder.sh/docs/api/create-routes

### Project-Specific
- **ERC-8004 Guide:** See `8004-guide.md`
- **X402 Guide:** See `402-guide.md`
- **Project Specs:** See `initial-specs.md`
- **Base Sepolia Explorer:** https://sepolia.basescan.org/

---

**Last Updated:** 2025-11-05
