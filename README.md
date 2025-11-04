# Aave V4

Aave V4 complete codebase, Foundry-based.

## Overview

Aave V4 introduces a unified liquidity layer and modular architecture that enhances capital efficiency, scalability, and risk management.

## Documentation

[insert link to protocol tech docs]

## Contributing

If you're interested in contributing, please read the [contributing docs](./CONTRIBUTING.md) before submitting a pull request.

## Architecture

The Aave V4 architecture follows a modular hub-and-spoke design.

Liquidity Hubs (`Hub.sol`) can extend credit lines to multiple Spokes (`Spoke.sol`) across its assets, and Spokes can similarly connect to a separate Hub for every reserve listed on it. User entry points exist on the Spokes, which will abstract all Hub logic from the user. Spokes are also responsible for collateralization enforcement and accounting across end users, while Spoke-level accounting and caps management will be handled in the Hub.

## Repository Structure

All contracts are held within the `aave-v4/src` folder.

Dependencies are in the `aave-v4/src/dependencies` subfolder, rather than handled through external package managers. This mitigates supply chain attack vectors and ensures dependency immutability, while minimizing potential install times.

All Foundry-based tests are in the `aave-v4/tests` folder. Gas snapshot tests are in the `aave-v4/tests/gas` subfolder.

Base test setup is in the `aave-v4/tests/Base.t.sol` file which configures hubs and associated spokes to initialize a testing environment.

## Dependencies

- Foundry, [how-to install](https://book.getfoundry.sh/getting-started/installation) (we recommend also update to the last version with `foundryup`)
- Node, [how-to install](https://nodejs.org/en/download)
- Lcov
  - Optional, only needed for coverage testing
  - For Ubuntu, you can install via `apt install lcov`
  - For Mac, you can install via `brew install lcov`

## Quickstart

````bash
# Clone the repository
git clone https://github.com/aave/aave-v4.git
cd aave-v4

# Install dependencies
```sh
cp .env.example .env
forge install
## required for linting
yarn install

# Build contracts
forge build
````

## Tests

- To run the full test suite: `make test`
- To re-generate the coverage report: `make coverage`
- To run gas snapshots: `make gas-report`

## Security

[link to audit reports]

## License

All Rights Reserved © Aave Labs
