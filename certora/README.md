# Certora Formal Verification

This folder contains the formal verification specifications for the Aave V4 protocol using the Certora Prover.

## Folder Structure

```
certora/
├── conf/                    # Configuration files for running the prover
│   ├── libs/               # Library-specific configurations
│   └── *.conf              # Main configuration files
├── harness/                 # Solidity harness contracts for verification
│   ├── HubHarness.sol      # Hub contract harness exposing internal functions
│   ├── LibBitHarness.sol   # LibBit library harness
│   ├── MathWrapper.sol     # Math library wrapper for verification
│   └── PremiumWrapper.sol  # Premium library wrapper for verification
├── spec/                    # CVL specification files
│   ├── libs/               # Library specifications
│   └── symbolicRepresentation/  # Symbolic representations for CVL
├── runAll.sh               # Script to run all conf files
└── compileAll.sh           # Script to compile all contracts
```

## Key Properties Verified

The formal verification focuses on the following critical safety properties:

### Solvency & Share Rate

- **Share Rate Monotonicity** - The exchange rate between shares and assets never decreases, protecting LP token holders
- **Total Assets ≥ Total Shares** - Ensures the protocol remains solvent
- **External Solvency** - Hub underlying balance always covers total added assets

### Position Safety

- **No Collateral → No Debt** - Users without collateral cannot accumulate debt
- **Borrowing Flag Consistency** - Borrowing status accurately reflects drawn shares
- **Health Factor Maintenance** - User health stays above liquidation threshold after operations

### State Consistency

- **Spoke Isolation** - Operations on one spoke don't affect other spokes
- **Sum Invariants** - Sum of spoke supplies/drawn shares equals totals
- **Reserve ID Validity** - Reserve mappings remain consistent

### Accrue Integrity

- **Idempotency** - Calling accrue twice is equivalent to calling once
- **Index Monotonicity** - Interest indices only increase

## Prerequisites

1. Install the Certora Prover CLI:

   ```bash
   pip install certora-cli
   ```

2. Set your Certora API key:
   ```bash
   export CERTORAKEY=<your-api-key>
   ```

## Running the Prover

### Run All Configurations

```bash
./certora/runAll.sh
```

### Run a Single Configuration

```bash
certoraRun certora/conf/<config_file>.conf
```

### Run a Specific Rule

```bash
certoraRun certora/conf/<config_file>.conf --rule <rule_name> --msg "<description>"
```

### Documentation

For more information on the Certora Prover and CVL specification language, see:

- [Certora Documentation](https://docs.certora.com/)
- [CVL Language Reference](https://docs.certora.com/en/latest/docs/cvl/index.html)
- [Certora Prover CLI](https://docs.certora.com/en/latest/docs/prover/cli/index.html)

---

## Hub Specifications

### `HubBase.spec`

**Base definitions for Hub specifications.**

- **Imports:** `ERC20s_CVL.spec`, `Math_CVL.spec`, `common.spec`
- **Purpose:** Contains safe assumptions and summarizations used across all Hub spec files
- **Key Summaries:**
  - `calculateInterestRate` → NONDET
  - `Premium.calculatePremiumRay` → CVL implementation

### `Hub.spec`

**Main Hub verification rules.**

- **Config:** `certora/conf/Hub.conf`
- **Imports:** `ERC20s_CVL.spec`, `Math_CVL.spec`, `HubValidState.spec`
- **Purpose:** State change rules where validation functions are ignored, assuming `accrue` has been called
- **Key Summaries:** All `_validate*` functions → NONDET
- **Key Rules:**
  - `supplyExchangeRateIsMonotonic` - Share exchange rate never decreases (critical for LP token safety)
  - `noChangeToOtherSpoke` - Operations on one spoke don't affect other spokes' state
  - `totalAssetsCompareToSuppliedAmount` - Total assets always >= total shares (solvency)
  - `accrueWasCalled` - Ensures accrue is called before state-changing operations

### `HubValidState.spec`

**Hub valid state properties and invariants.**

- **Config:** `certora/conf/HubValidState.conf`, `certora/conf/HubValidState_totalAssets.conf`
- **Imports:** `ERC20s_CVL.spec`, `Math_CVL.spec`, `HubBase.spec`
- **Purpose:** Verifies invariants about the Hub's state, assuming a given drawnIndex and accrue was called
- **Key Features:**
  - Ghost variables for tracking spoke supply, drawn amounts, and premium offsets
  - Hooks on storage operations to maintain ghost consistency
  - Sum invariants for spoke data
- **Key Rules/Invariants:**
  - `solvency_external` - Hub underlying balance >= total added assets (external solvency)
  - `totalAssetsVsShares` - Total assets always >= total shares (share rate >= 1)
  - `sumOfSpokeSupply` - Sum of all spoke supplies equals total supply
  - `sumOfSpokeDrawnShares` - Sum of all spoke drawn shares equals total drawn
  - `premiumOffset_Integrity` - Premium offset tracking consistency
- **Additional Config:** `HubValidState_totalAssets.conf` runs `totalAssetsVsShares` with parallel splitting

### `HubIntegrityRules.spec`

**Hub integrity verification rules.**

- **Config:** `certora/conf/HubIntegrity.conf`
- **Imports:** `ERC20s_CVL.spec`, `Math_CVL.spec`, `HubValidState.spec`
- **Purpose:** Verifies that state changes are consistent (e.g., add increases balances, remove decreases them)
- **Key Rules:**
  - `nothingForZero_add` - Add operation increases balances
  - `nothingForZero_remove` - Remove operation decreases balances

### `HubAccrueIntegrity.spec`

**Accrue function integrity proofs.**

- **Config:** `certora/conf/HubAccrueIntegrity.conf`
- **Imports:** `HubBase.spec`
- **Purpose:** Unit test properties of `AssetLogic.accrue()` function
- **Key Rules:**
  - `runningTwiceIsEquivalentToOne` - Idempotency of accrue
  - Index monotonicity rules
  - Interest rate calculation rules

### `HubAccrueSupplyRate.spec`

**Supply rate verification.**

- **Config:** `certora/conf/HubAccrueSupplyRate.conf`
- **Purpose:** Verifies supply rate calculations

### `HubAccrueUnrealizedFee.spec`

**Unrealized fee verification.**

- **Config:** `certora/conf/HubAccrueUnrealizedFee.conf`
- **Purpose:** Verifies unrealized fee calculations

### `HubAdditivity.spec`

**Additivity properties of Hub operations.**

- **Config:** `certora/conf/HubAdditivity.conf`
- **Imports:** `ERC20s_CVL.spec`, `Math_CVL.spec`, `SharesMath.spec`
- **Purpose:** Verifies that splitting operations is less beneficial than single operations
- **Key Rules:** Additivity proofs for `add`, `remove`, `draw`, `restore`, `reportDeficit`, `eliminateDeficit`

---

## Spoke Specifications

### `SpokeBase.spec`

**Base definitions for Spoke specifications.**

- **Imports:** `Math_CVL.spec`, `SymbolicPositionStatus.spec`, `ERC20s_CVL.spec`
- **Purpose:** Safe assumptions and summarizations for all Spoke spec files
- **Key Summaries:**
  - Sorting functions → CVL implementation
  - Price functions → Symbolic representation
  - Authority checks → NONDET

### `Spoke.spec`

**Main Spoke verification rules.**

- **Config:** `certora/conf/Spoke.conf`, `certora/conf/Spoke_noCollateralNoDebt.conf`
- **Imports:** `SpokeBase.spec`
- **Purpose:** Spoke-independent verification (no link to Hub)
- **Key Features:**
  - Symbolic Hub summaries for external calls
  - Index tracking per asset per block
  - User position invariants
- **Key Rules/Invariants:**
  - `isBorrowingIFFdrawnShares` - Borrowing flag set iff user has drawn shares
  - `drawnSharesZero` - Zero drawn shares implies zero premium shares
  - `noCollateralNoDebt` - User with no collateral cannot have debt (critical safety property)
  - `validReserveId` - Reserve ID validity and consistency
  - `increaseCollateralOrReduceDebtFunctions` - Functions either increase collateral or reduce debt
  - `collateralFactorNotZero` - Borrowed reserves must have non-zero collateral factor
  - `uniqueAssetIdPerReserveId` - Each reserve maps to unique asset
- **Additional Config:** `Spoke_noCollateralNoDebt.conf` runs `noCollateralNoDebt` with parallel splitting prover args

### `SpokeHealthCheck.spec`

**Health factor verification.**

- **Config:** `certora/conf/SpokeHealthCheck.conf`
- **Imports:** `SpokeBase.spec`, `SymbolicHub.spec`
- **Purpose:** Verifies that health factor is checked after position updates
- **Key Rules:**
  - `userHealthStaysAboveThreshold` - Health factor maintained after operations

### `SpokeUserIntegrity.spec`

**User position integrity.**

- **Config:** `certora/conf/SpokeUserIntegrity.conf`
- **Purpose:** Verifies that only one user's account is updated at a time

### `SpokeHubIntegrity.spec`

**Spoke-Hub integration verification.**

- **Config:** `certora/conf/SpokeWithHub.conf`
- **Imports:** `SpokeBase.spec`, `HubValidState.spec`
- **Purpose:** Verifies consistency between Spoke user positions and Hub spoke data
- **Key Invariants:**
  - `userDrawnShareConsistency` - User drawn shares match Hub records
  - `userSuppliedShareConsistency` - User supplied shares match Hub records
  - `userPremiumShareConsistency` - Premium shares consistency
  - `userPremiumOffsetConsistency` - Premium offset consistency

---

## Library Specifications

### `libs/Math.spec`

**Mathematical function verification.**

- **Config:** `certora/conf/libs/Math.conf`
- **Purpose:** Proves CVL representations match Solidity implementations
- **Verified Functions:**
  - `mulDivDown`, `mulDivUp`
  - `rayMulDown`, `rayMulUp`, `rayDivDown`, `rayDivUp`
  - `wadDivDown`, `wadDivUp`
  - `percentMulDown`, `percentMulUp`
  - `fromRayUp`, `toRay`

### `libs/SharesMath.spec`

**Shares math library verification.**

- **Config:** `certora/conf/libs/SharesMath.conf`
- **Purpose:** Proves mathematical properties of share calculations
- **Key Rules:**
  - Monotonicity of `toSharesUp`, `toSharesDown`, `toAssetsUp`, `toAssetsDown`
  - Additivity properties
  - Inverse relationships

### `libs/LibBit.spec`

**Bit manipulation library verification.**

- **Config:** `certora/conf/libs/LibBit.conf`

### `libs/PositionStatus.spec`

**Position status verification.**

- **Config:** `certora/conf/libs/PositionStatus.conf`

### `libs/Premium.spec`

**Premium calculation verification.**

- **Config:** `certora/conf/libs/Premium.conf`
- **Imports:** `HubBase.spec`, `common.spec`
- **Purpose:** Verifies that `Premium.calculatePremiumRay` matches its CVL summarization
- **Key Rules:**
  - `calculatePremiumRay_equivalence` - Solidity matches CVL implementation

---

## Symbolic Representations

### `symbolicRepresentation/Math_CVL.spec`

**CVL implementations of math functions.**

- **Purpose:** Provides CVL equivalents of Solidity math functions for use in summaries
- **Functions:** `mulDivDownCVL`, `mulDivUpCVL`, `mulDivRayDownCVL`, `mulDivRayUpCVL`, `divRayUpCVL`, `mulRayCVL`

### `symbolicRepresentation/ERC20s_CVL.spec`

**ERC20 symbolic representations.**

- **Purpose:** Symbolic handling of ERC20 token interactions

### `symbolicRepresentation/SymbolicHub.spec`

**Symbolic Hub for Spoke verification.**

- **Purpose:** Allows verifying Spoke independently of Hub implementation

### `symbolicRepresentation/SymbolicPositionStatus.spec`

**Symbolic position status handling.**

---

## Common Specifications

### `common.spec`

**Shared method summaries.**

- **Purpose:** Common summaries used in both Hub and Spoke specifications
- **Key Summaries:**
  - `mulDivDown`, `mulDivUp` → CVL implementations
  - `rayMulDown`, `rayMulUp`, `rayDivDown` → CVL implementations
  - `wadDivUp`, `wadDivDown` → CVL implementations
  - `percentMulDown`, `percentMulUp` → CVL implementations
- **Ghost Variables:**
  - `RAY` = 10^27
  - `WAD` = 10^18
  - `PERCENTAGE_FACTOR` = 10000

---

## Dependency Graph

```
common.spec
    ├── HubBase.spec
    │       ├── Hub.spec
    │       ├── HubValidState.spec
    │       │       ├── HubIntegrityRules.spec
    │       │       └── SpokeHubIntegrity.spec
    │       ├── HubAccrueIntegrity.spec
    │       ├── HubAccrueSupplyRate.spec
    │       ├── HubAccrueUnrealizedFee.spec
    │       └── HubAdditivity.spec (via SharesMath.spec)
    │
    └── SpokeBase.spec
            ├── Spoke.spec
            ├── SpokeHealthCheck.spec
            ├── SpokeUserIntegrity.spec
            └── SpokeHubIntegrity.spec

symbolicRepresentation/
    ├── Math_CVL.spec (used by most specs)
    ├── ERC20s_CVL.spec (used by most specs)
    ├── SymbolicHub.spec (used by SpokeHealthCheck)
    └── SymbolicPositionStatus.spec (used by SpokeBase, SpokeHubIntegrity)
```

---

## Harness Contracts

### `HubHarness.sol`

Exposes internal Hub functions for verification:

- `accrueInterest()` - Exposes `AssetLogic.accrue()`

### `MathWrapper.sol`

Wraps math library functions for direct verification:

- Exposes `WadRayMath` functions: `rayMulDown`, `rayMulUp`, `rayDivDown`, `rayDivUp`, `wadDivDown`, `wadDivUp`
- Exposes `MathUtils` functions: `mulDivDown`, `mulDivUp`
- Exposes `PercentageMath` functions: `percentMulDown`, `percentMulUp`

### `LibBitHarness.sol`

Wraps LibBit library for verification.

### `PremiumWrapper.sol`

Wraps Premium library for verification:

- Exposes `Premium.calculatePremiumRay()` for CVL equivalence testing

---

## Tips for Running Verification

1. **Use Build Cache:** Most conf files have `"build_cache": true` to speed up repeated runs.

2. **Split Long-Running Rules:** Use `--split_rules` for rules that may timeout:

   ```bash
   certoraRun certora/conf/Spoke.conf --split_rules drawnSharesZero noCollateralNoDebt
   ```

3. **Run Specific Rules:** Use `--rule` to run individual rules:

   ```bash
   certoraRun certora/conf/Hub.conf --rule totalAssetsCompareToSuppliedAmount --msg "Hub totalAssets"
   ```

4. **View Results:** Check the Certora Prover dashboard at https://prover.certora.com
