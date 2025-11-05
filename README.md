# Aave V4

## Dependencies

- Foundry, [how-to install](https://book.getfoundry.sh/getting-started/installation) (we recommend also update to the last version with `foundryup`)
- Node, [how-to install](https://nodejs.org/en/download)
- Lcov
  - Optional, only needed for coverage testing
  - For Ubuntu, you can install via `apt install lcov`
  - For Mac, you can install via `brew install lcov`

## Setup

```sh
cp .env.example .env
forge install
# required for linting
yarn install
```

## Tests

- To run the full test suite: `make test`
- To re-generate the coverage report: `make coverage`
