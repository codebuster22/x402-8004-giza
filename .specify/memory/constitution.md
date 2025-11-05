# Giza Open Strategies Constitution

<!--
SYNC IMPACT REPORT
==================
Version: 1.0.0 (Initial Constitution)
Ratified: 2025-11-05
Last Amended: 2025-11-05

Modified Principles: N/A (Initial version)
Added Sections: All sections (new constitution)
Removed Sections: N/A

Template Sync Status:
✅ plan-template.md - Aligned with multi-component structure, no testing mandate
✅ spec-template.md - Aligned with DRY principles, speed over security
✅ tasks-template.md - Aligned with optional testing, experimental nature
✅ checklist-template.md - No changes needed
✅ agent-file-template.md - No changes needed

Follow-up TODOs: None
-->

## Core Principles

### I. Multi-Component Architecture

This project consists of four independent components that work together:

1. **Smart Contracts**: Solidity code using Foundry framework
2. **Indexer**: Ponder-based blockchain event indexer
3. **Client Server**: Hono-based API server for client interactions
4. **Service Server**: Hono-based API server for service operations

Each component MUST maintain clear boundaries and responsibilities. Inter-component communication happens through well-defined interfaces (smart contract events, API endpoints, shared data models).

**Rationale**: Clear component separation allows independent development, deployment, and troubleshooting while maintaining system cohesion.

### II. Simplicity and DRY (Don't Repeat Yourself)

Code MUST be:
- Simple and readable over clever or complex
- Modular with single responsibility per module
- DRY - shared logic extracted into reusable functions/modules
- Minimal abstraction - only abstract when duplication exists in 3+ places

Avoid:
- Premature optimization
- Over-engineering
- Unnecessary patterns or frameworks
- Complex inheritance hierarchies

**Rationale**: This is an experimental project prioritizing rapid iteration and learning. Simple code enables faster changes and easier debugging.

### III. Hono for Server Components

Both Client Server and Service Server MUST use Hono as the web framework.

Requirements:
- RESTful API design where appropriate
- Middleware for cross-cutting concerns (logging, error handling)
- Type-safe route definitions using Hono's TypeScript support
- Lean server structure - no unnecessary dependencies

**Rationale**: Hono is lightweight, fast, and provides excellent TypeScript support, aligning with our simplicity principle.

### IV. Bun as Package Manager (Universal)

ALL JavaScript/TypeScript components (indexer, servers) MUST use Bun:

- MUST use `bun add <package>` to add dependencies
- MUST use `bun install` to install dependencies
- MUST use `bun run <script>` to execute scripts
- NEVER manually edit package.json to add packages

**Rationale**: Bun provides fast, consistent dependency management. Manual package.json edits bypass lockfile integrity and can cause inconsistencies.

### V. Solidity Library Management via Bun

Smart contracts MUST manage Solidity dependencies through Bun, NOT Foundry's git submodules:

- Add Solidity libraries: `bun add <npm-package>`
- Map imports in `remappings.txt`
- Keep remappings.txt version-controlled
- NO git submodules in `lib/` directory

**Rationale**: Bun-managed dependencies are faster, more reliable, and integrate better with CI/CD. Git submodules are fragile and slow.

### VI. Testing Strategy: Pragmatic and Optional

Testing approach:
- Smart contracts: Tests SHOULD be written for critical business logic
- Indexer: Tests NOT required (experimental, rapidly changing)
- Servers: Tests NOT required (experimental, rapidly changing)
- Integration tests: Only when explicitly needed for complex workflows
- Mocks: Avoid unless absolutely necessary (prefer real implementations or lightweight stubs)

**Rationale**: This is an experimental project, not production software. Speed of iteration matters more than test coverage. Tests should add value, not ceremony.

### VII. Speed Over Security

Development priorities:
1. Getting things done and working
2. Learning and experimentation
3. Simplicity and maintainability
4. Security considerations (minimal, not zero)

Security practices:
- Basic input validation SHOULD exist
- NO need for comprehensive threat modeling
- NO need for security audits
- Focus on functional correctness, not attack resistance

**Rationale**: This is an experiment to validate concepts and learn. Security hardening can come later if the project graduates to production.

## Technology Stack Requirements

### Smart Contracts
- Language: Solidity
- Framework: Foundry
- Dependencies: Managed via Bun + remappings.txt
- Build tool: `forge build`
- Test runner: `forge test` (when tests exist)

### Indexer
- Framework: Ponder
- Runtime: Bun
- Server: Hono (if API needed)
- Language: TypeScript

### Client Server & Service Server
- Framework: Hono
- Runtime: Bun
- Language: TypeScript
- Database: As needed (prefer simple solutions like SQLite for experiments)

## Development Workflow

### Adding Dependencies

**For JavaScript/TypeScript packages**:
```bash
cd <component-directory>
bun add <package-name>
```

**For Solidity libraries**:
```bash
cd contracts
bun add <npm-solidity-package>
# Then update remappings.txt with appropriate import path
```

### Code Changes

1. Keep changes focused and small
2. One logical change per commit
3. Descriptive commit messages
4. No need for formal code review (experimental project)
5. Push directly to main if you own the project, or use short-lived feature branches

### Running Components

Each component has its own scripts in package.json (for JS/TS) or Foundry commands (for contracts):

- Indexer: `bun run dev`, `bun run start`
- Servers: Define scripts as needed (`bun run dev`, `bun run start`)
- Contracts: `forge build`, `forge test`, `forge script`

## Governance

**Authority**: This constitution is the authoritative source for project development practices.

**Amendment Process**:
- Constitution updates must be documented with clear rationale
- Version follows semantic versioning (MAJOR.MINOR.PATCH)
- Changes should be communicated to all contributors
- No formal approval needed for experimental projects (owner decides)

**Compliance**:
- All code changes SHOULD align with principles above
- Complexity that violates principles MUST be justified in commit messages or PRs
- When in doubt, favor simplicity and speed

**Version**: 1.0.0 | **Ratified**: 2025-11-05 | **Last Amended**: 2025-11-05
