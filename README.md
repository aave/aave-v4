# Aave V4

[![codecov](https://codecov.io/gh/aave/aave-v4/graph/badge.svg?token=afC1P2GrDM)](https://codecov.io/gh/aave/aave-v4)

**Aave V4 complete codebase, Foundry-based.**

A unified liquidity layer and modular architecture that enhances capital efficiency, scalability, and risk management.

## Table of Contents

- [Documentation](#documentation)
- [Contributing](#contributing)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Dependencies](#dependencies)
- [Development](#development)
- [Deployment](#deployment)
- [Security](#security)
- [Versioning](#versioning)
- [Links](#links)
- [License](#license)

## Documentation

- [Aave V4 features](TBD)

## Contributing

Please read our [Contributing Guidelines](./CONTRIBUTING.md) before submitting pull requests.

Key points:

- Significant protocol changes require discussion before PR creation
- All changes must include comprehensive tests
- PRs must maintain or improve test coverage
- Gas snapshots must be updated for code changes

## Architecture

The Aave V4 architecture follows a modular **hub-and-spoke design** that separates liquidity management from user-facing operations and collateralization.

### Core Components

#### Hub (`Hub.sol`)

- Manages unified liquidity pools for assets
- Extends credit lines to multiple Spokes
- Handles asset and Spoke accounting and caps management
- Responsible for supplied shares exchange rate and debt index conversions
- Implements interest rate strategies and asset logic
- Handles reinvestment controllers and their permissioning

#### Spoke (`Spoke.sol`)

- User-facing entry points for supplies, withdraws, borrows, repays, and liquidations
- Enforces collateralization requirements
- Manages user positions and risk parameters
- Abstracts Hub logic from end users
- Can connect to separate Hubs for each reserve
- Connects to and reads from oracles

#### Key Design Principles

1. **Separation of Concerns**: Hubs handle liquidity and asset management, Spokes handle user interactions and risk enforcement.
2. **Flexibility**: Each reserve on a Spoke can connect to a different Hub.
3. **Modularity**: Independent configuration per component.
4. **Capital Efficiency**: Shared liquidity pools enable better capital utilization. Sweep functionality allows rehypothecation of idle funds.

## Repository Structure

```
aave-v4/
├── src/                          # Main source code
│   ├── hub/                      # Hub contracts and interfaces
│   ├── spoke/                    # Spoke contracts and interfaces
│   ├── position-manager/         # Position Managers, including gateway contracts
│   ├── libraries/                # Shared libraries (math, types)
│   ├── utils/                    # Utility contracts (Multicall, etc.)
│   └── dependencies/             # Dependencies (Chainlink, OpenZeppelin, etc.)
├── tests/                        # Test suite
│   ├── unit/                     # Unit tests
│   ├── gas/                      # Gas snapshot tests
│   ├── invariant/                # Invariant tests
│   ├── misc/                     # Symbolic tests, prototype development
│   └── Base.t.sol                # Base test setup
├── scripts/                      # Deployment scripts
├── snapshots/                    # Gas snapshots
└── lib/                          # Foundry dependencies
```

## Dependencies

### Required

- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** - Development framework
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup  # Update to latest version
  ```
- **[Node.js](https://nodejs.org/en/download)** - For linting and tooling
  ```bash
  # Verify installation
  node --version
  npm --version
  ```

### Optional

- **Lcov** - For coverage reports

  ```bash
  # Ubuntu
  sudo apt install lcov

  # macOS
  brew install lcov
  ```

### Dependency Strategy

Dependencies are located in the `src/dependencies` subfolder rather than managed through external package managers. This approach:

- Mitigates supply chain attack vectors
- Ensures dependency immutability
- Minimizes installation overhead
- Provides simplified version control and auditability

## Quickstart

### 1. Clone the Repository

```bash
git clone https://github.com/aave/aave-v4.git
cd aave-v4
```

### 2. Install Dependencies

```bash
# Copy environment template and populate
cp .env.example .env

# Install Foundry dependencies
forge install

# Install Node.js dependencies (required for linting)
yarn install
```

### 3. Build Contracts

```bash
forge build
```

## Development

### Testing

- **Run full test suite**: `make test` or `forge test -vvv`
- **Run specific test file**: `forge test --match-contract ...`
- **Run with gas reporting**: `make gas-report`
- **Generate coverage report**: `make coverage`

### Code Quality

- **Check contract sizes**: `forge build --sizes`

### Gas Snapshots

Gas snapshots are automatically generated and stored in the `snapshots/` directory. To update snapshots:

```bash
make gas-report
```

Snapshot files generated:

- `Hub.Operations.json`
- `Spoke.Operations.json`
- `Spoke.Getters.json`
- `NativeTokenGateway.Operations.json`
- `SignatureGateway.Operations.json`

## Deployment

Deployment scripts are located in the `scripts/` directory. See `./Makefile` for deployment commands.

## Security

- **Audit Reports**: [TBD]
- **Security Policy**: [TBD]
- **Bug Bounty**: [TBD]

## Versioning

Current version: **v0.5.3**

See `package.json` for version information and metadata.

## Links

- [Website](https://aave.com)
- [Documentation](https://docs.aave.com)
- [Twitter](https://twitter.com/aave)
- [Forum](https://governance.aave.com)

## License

All Rights Reserved © Aave Labs
