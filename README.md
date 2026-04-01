# Aave V4

A unified liquidity layer and modular architecture that enhances capital efficiency, scalability, and risk management.

## Table of Contents

- [Documentation](#documentation)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Dependencies](#dependencies)
- [Development](#development)
- [Security](#security)

## Documentation

- [Aave V4 Overview](./docs/overview.md)
- [Aave V4 Docs](https://aave.com/docs/aave-v4)

## Architecture

The Aave V4 architecture follows a modular **hub-and-spoke design** that separates liquidity management from user-facing operations and collateralization.

## Repository Structure

```
aave-v4/
├── src/                          # Main source code
│   ├── access/                   # Access control contracts
│   ├── dependencies/             # Dependencies (Chainlink, OpenZeppelin, etc.)
│   ├── hub/                      # Hub contracts and interfaces
│   ├── interfaces/               # Shared interfaces
│   ├── libraries/                # Shared libraries (math, types)
│   ├── misc/                     # Miscellaneous contracts
│   ├── position-manager/         # Position Managers, including gateway contracts
│   ├── spoke/                    # Spoke contracts and interfaces
│   └── utils/                    # Utility contracts (Multicall, etc.)
├── tests/                        # Test suite
│   ├── contracts/                # Contract tests (hub, spoke, tokenization, etc.)
│   ├── gas/                      # Gas snapshot tests
│   ├── helpers/                  # Test helpers and mocks
│   ├── misc/                     # Symbolic tests, prototype development
│   └── setup/                    # Base test setup and fixtures
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
  yarn --version
  # Install dependencies
  yarn install
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
- **Check linting**: `yarn lint`
- **Fix linting issues**: `yarn lint:fix`
- **Generate Rust bindings**: `yarn rs:generate`

### Gas Snapshots

Gas snapshots are automatically generated and stored in the `snapshots/` directory. To update snapshots:

```bash
make gas-report
```

Snapshot files generated:

- `Hub.Operations.json`: Gas for Hub actions or treasury operations invoked by Spokes.
- `Spoke.Operations.json`: Gas for user-facing Spoke operations.
- `Spoke.Operations.ZeroRiskPremium.json`: Same scenarios as `Spoke.Operations.json` but with Collateral Risk set to 0, to show baseline gas excluding risk-premium computation.
- `Spoke.Getters.json`: Gas for getters across different combinations of supplies/borrows.
- `NativeTokenGateway.Operations.json`: Gas for native-asset (ETH) gateway flows.
- `SignatureGateway.Operations.json`: Gas for EIP-712 meta-transactions.

## Security

### Audit Reports

You can find all audit reports under [audits](./audits/):

- [2026-02-05 - Aave V4 - Blackthorn](./audits/2026-02-05_Aave-V4_Blackthorn.pdf)
- [2026-02-10 - Aave V4 - TrailOfBits](./audits/2026-02-10_Aave-V4_TrailOfBits.pdf)
- [2026-02-19 - Aave V4 - ChainSecurity](./audits/2026-02-19_Aave-V4_ChainSecurity.pdf)

### Bug Bounty

Further details will be made available soon.

# License

Aave V4 is licensed under the Business Source License, see [LICENSE](./LICENSE). Each Solidity file in Aave V4 states the applicable license. As a customized license, BUSL uses the `LicenseRef-` prefix per [SPDX Spec v2.3, Annex E](https://spdx.github.io/spdx-spec/v2.3/using-SPDX-short-identifiers-in-source-files/).

# Contributing

Contributions are licensed under the Aave Protocol Contributor License Agreement, see [CLA_LICENSE](./CLA_LICENSE). See [CONTRIBUTING](./CONTRIBUTING.md) for further details and guidelines.
