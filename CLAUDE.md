# Aave V4

Modular lending protocol with a **hub-and-spoke architecture**. The Hub is an immutable liquidity coordinator; Spokes are upgradeable user-facing modules for supply/borrow. Risk is priced per-user via a **Risk Premium** system based on collateral quality. Multiple spokes can share one hub's liquidity. See `docs/overview.md` for detailed architecture, risk premium math, liquidation engine, and dynamic config mechanics.

## Entities

- **Hub** (`src/hub/Hub.sol`) — Immutable. Manages per-asset liquidity pools, interest accrual (drawn index), spoke caps, premium shares, deficit accounting. One hub can have many spokes.
- **HubConfigurator** (`src/hub/HubConfigurator.sol`) — AccessManaged admin wrapper for Hub config (add assets, fees, rate strategies).
- **Spoke** (`src/spoke/Spoke.sol`) — Abstract base. Handles supply/withdraw/borrow/repay, user positions, collateral management, liquidations, dynamic risk config. Upgradeable.
- **SpokeInstance** (`src/spoke/instances/SpokeInstance.sol`) — Concrete upgradeable Spoke implementation.
- **TokenizationSpoke** (`src/spoke/TokenizationSpoke.sol`) — ERC4626 vault wrapping a single Hub asset. Tokenizes supply positions into transferable shares.
- **TreasurySpoke** (`src/spoke/TreasurySpoke.sol`) — Protocol fee accumulation spoke. No user borrowing.
- **AaveOracle** (`src/spoke/AaveOracle.sol`) — Spoke-specific price oracle integrating Chainlink feeds.
- **SpokeConfigurator** (`src/spoke/SpokeConfigurator.sol`) — AccessManaged admin wrapper for Spoke reserve config, liquidation params, collateral risk.
- **GatewayBase** (`src/position-manager/GatewayBase.sol`) — Base for user-facing gateways (spoke registration, position manager delegation).
- **NativeTokenGateway** (`src/position-manager/NativeTokenGateway.sol`) — ETH ↔ WETH wrapping gateway.
- **SignatureGateway** (`src/position-manager/SignatureGateway.sol`) — EIP712 meta-transaction gateway for gasless operations.
- **AssetInterestRateStrategy** (`src/hub/AssetInterestRateStrategy.sol`) — Per-asset interest rate model used by Hub.
- **SpokeStorage** (`src/spoke/SpokeStorage.sol`) — Storage layout for upgradeable Spoke (inherited by Spoke.sol).
- **TokenizationSpokeInstance** (`src/spoke/instances/TokenizationSpokeInstance.sol`) — Concrete upgradeable TokenizationSpoke implementation.
- **AccessManagerEnumerable** (`src/access/AccessManagerEnumerable.sol`) — OZ AccessManager with role enumeration.

### Key relationships

```
Users → Spokes → Hub → Underlying ERC20s
  ↓      ↑  ↓
Gateways ┘  AaveOracle (Chainlink)
```

- Users can interact with Spokes directly or through Gateways (for ETH wrapping or meta-transactions)

- Spokes call `Hub.add()`/`Hub.draw()`/`Hub.restore()` for liquidity operations
- Hub tracks shares (added, drawn, premium) per spoke per asset
- User positions live in the Spoke, with drawn/premium shares referencing Hub indices
- Dynamic config keys allow governance parameter updates without affecting existing positions

### Key concepts

- **Drawn debt** = principal borrowed from Hub. Accrues at Hub's base rate.
- **Premium debt** = extra interest from user's collateral quality (Risk Premium). Full-precision formula: `(premiumShares * drawnIndex) - premiumOffsetRay` (result in asset-units-in-Ray). See `Premium.calculatePremiumRay()`.
- **Dynamic config keys** = versioned risk parameters (CF, LB, LF). New positions bind to latest key; old positions keep their key until a risk-increasing action rebinds them.
- **Share-based accounting** = all positions stored as shares. Debt share price is index-based (`drawnShares × drawnIndex`). Supply share price is `totalAddedAssets / addedShares` where `totalAddedAssets = liquidity + swept + aggregatedOwed - realizedFees - unrealizedFees` (see `AssetLogic.totalAddedAssets`). Both prices should only increase. Supply share conversions use virtual offsets (`VIRTUAL_ASSETS` and `VIRTUAL_SHARES`, both 1e6) in `SharesMath.sol` to mitigate first-depositor share inflation attacks.

## Precision

- **Ray** (1e27) — `drawnIndex` and `drawnRate` are pure Ray quantities (dimensionless multipliers). Ray provides extra precision over Wad for compounding interest calculations where shares multiply by indices (`drawnShares * drawnIndex`).
- **Asset-units-in-Ray** — `premiumOffsetRay`, `deficitRay`, and similar `*Ray`-suffixed variables are asset amounts scaled by 1e27 (not dimensionless). They carry both an asset-unit meaning and Ray scaling for precision when used in arithmetic with `drawnIndex`.
- **Wad** (1e18) — Used for health factors, percentages, and general fixed-point math. Defined in `src/libraries/math/WadRayMath.sol`.
- **Value** — Price-scaled amount where **1e26 = 1 USD**. Computed as `amount * price * 10^(18 - decimals)` (see `SpokeUtils.toValue`). Oracle prices use a fixed 8 decimals (`ORACLE_DECIMALS = 8`), standard Chainlink format. Used throughout liquidation logic and health factor calculations for cross-asset comparisons.
- **BPS** (basis points, 1e4 = 100%) — Used for collateral risk, percentages, liquidation bonus/fee. `PercentageMath.sol` handles BPS arithmetic.

### Rounding

Always use explicit rounding directions — never rely on implicit truncation. Use the math helpers: `WadRayMath.sol`, `PercentageMath.sol`, `MathUtils.sol`, and OZ's `Math.sol` (for `mulDiv` with rounding). General rule: round in favour of the protocol and against the user. When multiple external parties are involved (e.g., liquidations in `LiquidationLogic.sol` with protocol, liquidator, and borrower), the preference order is **protocol > liquidator > user**.

## Directory structure

```
src/
├── hub/                    # Hub core, configurator, rate strategy
│   ├── libraries/          # AssetLogic, SharesMath, Premium
│   └── interfaces/
├── spoke/                  # Spoke core, configurator, oracle, vault, treasury
│   ├── instances/          # SpokeInstance, TokenizationSpokeInstance
│   ├── libraries/          # LiquidationLogic, UserPositionUtils, UserPositionDebt,
│   │                       # PositionStatusMap, ReserveFlagsMap, SpokeUtils, EIP712Hash
│   └── interfaces/
├── position-manager/       # Gateways (Native, Signature)
│   ├── libraries/          # EIP712 hash helpers
│   └── interfaces/
├── libraries/math/         # WadRayMath, PercentageMath, MathUtils
├── libraries/types/        # Shared type definitions (Roles)
├── utils/                  # Multicall, ExtSload, IntentConsumer, NoncesKeyed, Rescuable
├── access/                 # AccessManagerEnumerable
├── interfaces/             # Top-level interfaces
└── dependencies/           # Vendored: OZ, solady, chainlink, weth

tests/
├── Base.t.sol              # Root test base (~3300 lines). Deploys everything. Inherit from this.
├── Utils.sol               # Wrapper helpers (supply, borrow, approve with prank)
├── Constants.sol           # Test constants
├── DeployUtils.sol         # Contract deployment helpers
├── unit/
│   ├── Hub/                # Hub unit tests
│   ├── Spoke/              # Spoke unit tests (SpokeBase.t.sol = spoke test base class)
│   │   └── Liquidations/
│   ├── TokenizationSpoke/
│   ├── misc/
│   │   └── SignatureGateway/  # 9 test files with layered base
│   └── libraries/
├── gas/                    # Gas snapshot tests (Hub, Spoke, TokenizationSpoke, Gateways)
├── mocks/                  # TestnetERC20, MockPriceFeed, EIP712Types, etc.

snapshots/                  # Gas snapshots (forge snapshot output)
scripts/                    # Deployment scripts
docs/overview.md            # Architecture documentation
```

## Caveats

- Dependencies are vendored in `src/dependencies/`, not in `lib/` — no submodules for OZ/solady/chainlink.
- Position manager approval is required for gateways to act on behalf of users.
- `reserveId` (spoke-level) ≠ `assetId` (hub-level). The same underlying token can have different reserveIds across spokes.
- Premium offset is stored in asset units scaled by Ray (not shares) to separate accrued premium from principal.
- EIP712 types for tests are defined in `tests/mocks/EIP712Types.sol` and auto-bound via `[bind_json]` in foundry.toml to `tests/mocks/JsonBindings.sol`. When adding new EIP712 types, update both files.

## Build & validation

```bash
forge build                                          # compile
forge test --match-path tests/unit/Spoke/Spoke.Borrow.t.sol  # target specific test file
forge test --match-contract SpokeBorrowTest          # target specific contract
forge test --fuzz-runs 5                             # quick full suite during dev
forge test                                           # full suite (1000 fuzz runs)
make gas-report                                      # update gas snapshots (runs tests/gas/**)
yarn lint:fix                                        # format code (prettier + solidity plugin)
```

Run targeted tests (`--match-path` or `--match-contract`) while developing. Use `forge test --fuzz-runs 5` for quick full-suite sanity checks mid-development. Run full `forge test` at the end. Always run `make gas-report` before commits or after significant runs to keep snapshots current.

### Code size

`SpokeInstance` and `Hub` are close to the 24KB contract size limit. After changes that add code to these contracts, check sizes with `forge build --sizes | grep <Contract>`. If a change pushes a contract over the limit, warn the user — do not silently reject the change. Before committing, verify all touched contracts are within the size limit.

## Snapshots

Mostly ignore files in `snapshots/` directory. Only reference them when evaluating gas differences. If a change impacts gas, report the diff from snapshot files and note whether the change is significant.

## Code style

- Use `///` natspec format for all doc comments.
- **External/public functions**: Define the function signature in the interface. Document it there with `/// @notice`, `/// @dev`, `/// @param`, `/// @return`. In the implementation, use `/// @inheritdoc IInterfaceName` — do not duplicate docs.
- **Struct fields**: Use `/// @notice` for the struct, then `/// @dev fieldName Description` per field. Always note precision/units (e.g., "expressed in asset units and scaled by RAY").
- **Internal/private helpers** (in contracts or libraries): Add `/// @dev` comments when they add value — explain why, constraints, or non-obvious behavior. Do not document every parameter mechanically.
- **Error handling**: Use `require` with custom errors (e.g., `require(condition, CustomError())`), never string messages.
- **General**: Avoid unnecessary comments. Keep code clean and to the point. Follow the surrounding convention in whatever file you're editing.

## Agent workflow

**Always use subagents (Task tool with Explore/general-purpose types) to explore files** so that the global planner agent context is not polluted with large file contents. Read files through subagents; only read small, targeted sections directly.

**Always ask the user clarifying questions when requirements are unclear.** Do not assume intent — use AskUserQuestion to resolve ambiguity before implementing.

## Security checklist

- Review every change with an adversarial mindset. After coding, ask: "What new attack surface did I introduce?"
- Favor the simplest design that meets requirements. Reject changes that raise security risk without strong justification
- Guard core invariants: supply share price monotonically increases, protocol remains solvent
- Rounding exploitability — can an attacker profit by repeated rounding? Consider share inflation attacks on exchange rates
- Flash loans / large borrows — can they manipulate state (prices, indices, liquidity) within a single tx?
- Flow of funds — where do tokens move, who gains, who loses?
- Griefing — can an attacker force another user into a bad state (block liquidations, inflate gas, trap funds) without profit?
- Donation attacks — can someone send tokens directly to a contract to manipulate share prices, bypassing accounting?
- Reentrancy via external calls (token transfers, callbacks) — follow checks-effects-interactions
- Access control — verify every new external/public function has correct guards (`onlySpoke`, `restricted`, role checks)
- Storage layout — Spoke is upgradeable. Never reorder/remove/insert storage vars in `SpokeStorage.sol`. Append only
- Hub↔Spoke consistency — changes to one must preserve the other's assumptions. Verify both sides of cross-contract flows

## Using Cast

Use Cast for quick blockchain utilities rather than writing custom scripts. Use `cast --help` and `cast <subcommand> --help` for full reference (no internet assumed).

```bash
cast keccak "transfer(address,uint256)"        # hash function sig
cast sig "transfer(address,uint256)"           # 4-byte selector
cast 4byte 0xa9059cbb                          # reverse lookup selector
cast call <addr> "balanceOf(address)" <who>    # read contract state
cast run <txhash> --trace                      # debug failed tx
```

Best practices: Use Cast for prototyping before writing scripts. Prefer Cast for one-offs. Chain Cast commands with shell scripting for workflows.

## Testing guidelines

Every feature or change MUST have comprehensive tests before creating a PR.

- **New features**: Tests demonstrating complete flow and all edge cases
- **Bug fixes**: Tests that reproduce the bug and verify the fix
- **Refactoring**: Ensure existing tests still pass; add new ones if behavior changes
- **Gas optimizations**: Include benchmark comparisons in `tests/gas/`

### Required test types

**Unit tests**: Happy paths, failure cases, edge cases, revert conditions with specific custom errors.

**Fuzz tests**: Highly encouraged for all new functionality. Use Foundry's built-in fuzzing. Default seed is `0x640`.

Test names: `test_FeatureName_SpecificScenario_ExpectedOutcome()`

### Test abstractions — always use them

`Base.t.sol` deploys the full environment (hub, spokes, oracle, treasury, access manager, tokens, reserves). **New tests should inherit from `Base`** (or from `SpokeBase` for spoke tests). Never write standalone test contracts — always use the existing hierarchy and its 200+ helper functions.

```
Test (forge-std)
  └── Base (tests/Base.t.sol)          — deploys everything, 200+ helpers
       └── SpokeBase (tests/unit/Spoke/SpokeBase.t.sol) — spoke-specific helpers
            └── Your spoke/hub/library test
       └── SignatureGatewayBaseTest (tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol)
            └── Your gateway test
```

**Example** — how SignatureGateway tests extend the base and use data builders:

```solidity
// tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol
contract SignatureGatewayBaseTest is SpokeBase {
  ISignatureGateway public gateway;

  function setUp() public virtual override {
    deployFixtures(); // from Base
    initEnvironment(); // from Base
    gateway = ISignatureGateway(new SignatureGateway(ADMIN));
    vm.prank(address(ADMIN));
    gateway.registerSpoke(address(spoke1), true);
  }
}

// tests/unit/misc/SignatureGateway/SignatureGateway.t.sol
contract SignatureGatewayTest is SignatureGatewayBaseTest {
  function test_supplyWithSig() public {
    ISignatureGateway.Supply memory p = _supplyData(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);

    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p, signature);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
  }
}
```

Key helpers from the test base: `deployFixtures()` + `initEnvironment()` for setup, `makeAddr()`/`makeKey()` for actors, `Utils.supply/approve/supplyCollateral()` (prank-wrapped), `_warpBeforeRandomDeadline()`, `_sign()`, `vm.expectEmit/expectRevert/expectCall()`.

### Testing checklist before PR

- All new functions have unit tests
- Critical paths have fuzz tests with random inputs
- Edge cases and revert scenarios are tested
- All tests pass: `forge test`

## After completing a task

- **Review**: Suggest the user review changes using fresh subagents in a new context for an unbiased second pass.
- **Commit learnings**: If you discovered a non-obvious codebase pattern, convention, or gotcha during implementation, suggest adding it to this file.
- **Keep this file up to date**: If anything in the codebase changes that invalidates information here, update this file as part of the change.
