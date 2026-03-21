# Fuzzing & Invariant Testing Suite

A comprehensive handler-based invariant testing suite for the Aave v4 protocol. This suite performs deep stateful fuzzing across multiple hubs and spokes, validating critical system properties through automated property checking and postcondition verification.

## Overview

The suite tests a complex multi-hub, multi-spoke deployment with:

- **2 Hubs** with distinct interest rate strategies and asset configurations
- **2 Spokes** with varying risk parameters (conservative vs. aggressive)
- **Cross-hub liquidity flows** simulating bridge mechanics with different capacity caps
- **Multiple actors** executing concurrent operations (supply, borrow, repay, liquidations)

All protocol actions are monitored by hooks that snapshot state and verify postconditions after each transaction, enabling detection of invariant violations and edge cases that could lead to protocol insolvency or user fund loss.

## Tooling

Compatible with industry-standard fuzzing tools:

- **Echidna** - battle tested haskell based property-based fuzzer
- **Medusa** - parallelized, coverage-guided, smart contract fuzzing, powered by go-ethereum
- **Foundry** - native invariant testing framework

## Architecture

### Dependencies

Hub invariant assertions and spec strings are imported from hub-suite — not duplicated. Spoke-specific code is self-contained.

```
protocol-suite → hub-suite → shared/
```

| Imported from hub-suite  | Local file                       |
| ------------------------ | -------------------------------- |
| `HubInvariantsSpec`      | `specs/InvariantsSpec.t.sol`     |
| `HubPostconditionsSpec`  | `specs/PostconditionsSpec.t.sol` |
| `HubInvariantAssertions` | `Invariants.t.sol`               |

### Core Components

**Setup Layer** (`Setup.t.sol`, `base/`)

- Deploys 2-hub, 2-spoke architecture with 2 treasury spokes
- Configures distinct collateral factors, liquidation parameters, and interest rate curves
- Initializes multiple actors with protocol permissions

**Spec Layer** (`specs/`)

- `InvariantsSpec` – inherits `HubInvariantsSpec` from hub-suite, adds spoke-specific strings (`INV_SP_*`)
- `PostconditionsSpec` – inherits `HubPostconditionsSpec` from hub-suite, adds spoke-specific strings (`GPOST_SP_*`, `HSPOST_SP_*`)

**Handler Layer** (`handlers/`)

- `SpokeHandler` – user operations (supply, borrow, repay, withdraw, liquidations)
- `TreasurySpokeHandler` – fee collection and distribution
- `HubConfiguratorHandler`, `SpokeConfiguratorHandler` – admin operations
- `PriceFeedSimulatorHandler`, `DonationAttackHandler` – simulation handlers

**Invariant Layer** (`invariants/`)

- Hub invariant assertions imported from hub-suite via `HubInvariantAssertions` (INV_HUB_A through R)
- `SpokeInvariants` – spoke-specific invariant assertions (INV_SP_A through I)
- Stateful hub invariants Q and R imported from hub-suite's `HubInvariantAssertions`

**Verification Layer** (`hooks/`)

- Before/after hooks with state snapshots
- Global and handler-specific postcondition assertions
- Hub and spoke postconditions

**Replay Layer** (`replays/`)

- Minimal reproduction tests for discovered violations
- Facilitates debugging and regression prevention

## How It Works

1. **Fuzzer** generates random inputs and selects handler functions
2. **Handlers** execute protocol actions through actor proxies (respects roles and permissions)
3. **Hooks** capture snapshots of relevant state variables for analysis
4. **Postconditions** validate expected outcomes and state transitions (e.g., "drawn rate matches calculated rate after hub non-view operations")
5. **Invariants** continuously checked across all protocol states

## Quick Start

```bash
# Run full fuzzing campaign with Medusa
make medusa

# Run with Echidna in assertion mode
make echidna-assert

# Generate replay tests from Echidna corpus
make runes-echidna

# Generate replay tests from Medusa corpus
make runes-medusa
```

## Advanced Usage

**Echidna Modes:**

```bash
make echidna          # Property mode (boolean invariants)
make echidna-assert   # Assertion mode (require/assert violations)
make echidna-explore  # Exploration mode (maximize coverage)
```

**Foundry:**

```bash
make foundry-invariants  # Native Foundry invariant runner
```

**Replay Specific Failure:**

```bash
forge test --mc ReplayTest_1 -vvv
```

## Key Features

- Multi-hub, multi-spoke testing for cross-protocol interactions
- Hub invariant logic imported from hub-suite (single source of truth, no duplication)
- Comprehensive postcondition checking after every state transition
- Actor-based modeling for realistic multi-user scenarios
- Admin operation fuzzing (config updates, parameter changes)

---

**Note:** This suite complements unit tests by exploring unbounded state spaces and adversarial scenarios that are difficult to anticipate manually.
