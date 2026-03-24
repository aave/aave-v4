# Contributing to Aave V4

## Contributor License Agreement (CLA)

By submitting a pull request, commit, or any other contribution to this repository, you agree to be bound by the [Aave Protocol Contributor License Agreement](./CLA_LICENSE). In summary:

- You **retain copyright** over your contributions.
- You grant a **perpetual, worldwide, royalty-free license** to use, reproduce, modify, and distribute your contribution as part of the Licensed Work.
- You grant a corresponding **patent license** for patent claims necessarily infringed by your contribution.
- You acknowledge that the repository license (BUSL) **may transition** to an open-source license, and you waive the right to object.
- You authorize the Licensor to **enforce and defend** the repository license on your behalf.

Please read the full [CLA_LICENSE](./CLA_LICENSE) before contributing.

## Ways to Contribute

1. **Opening an issue** — Report bugs with reproducible test cases or propose feature improvements. Check existing issues before opening duplicates; add context to existing ones instead.
2. **Resolving an issue** — Fix bugs or implement features. Reference the related issue in your PR.
3. **Reviewing open PRs** — Provide feedback on code quality, naming, gas optimizations, or design alternatives.

## Pull Request Guidelines

- Open PRs against the `main` branch.
- Reference any related issue.
- Follow the [Solidity style guide](https://docs.soliditylang.org/en/latest/style-guide.html), using `_prependUnderscore` for internal functions, internal top-level parameters, and parameters with naming collisions.
- Document new functions, structs, and interfaces with [NatSpec](https://docs.soliditylang.org/en/latest/natspec-format.html).
- Add tests: unit + fuzz for small changes; integration + invariant for larger ones.
- Run the full test suite and update gas snapshots:

```bash
forge test
make gas-report
```

- Squash commits where possible. PRs merged to `main` will be squash-merged.

## Setup

```bash
git clone https://github.com/aave/aave-v4.git
cd aave-v4
cp .env.example .env
forge install
yarn install
forge build
```

See the [README](./README.md) for detailed dependency and tooling instructions.

## Code of Conduct

Be respectful. Aggressive, disrespectful, or spam contributions will be removed and closed.

## License

Aave V4 source code is licensed under [LICENSE](./LICENSE). All contributions are licensed under the [Aave Protocol CLA](./CLA_LICENSE).
