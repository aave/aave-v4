# PositionManager

## Summary

PositionManagers are trusted periphery contracts that operate on Aave V4 Spokes on behalf of users. They enable supply, repay, withdraw, borrow, and configuration actions to be delegated to third-party contracts without requiring users to cede persistent custody of funds. Spoke-level PositionManager approval is a simple on/off authorization per (Spoke, user, PositionManager); finer scoping—where present—is implemented inside specific PositionManagers via per-reserve allowances, bitmapped config permissions, or EIP-712 signed intents. The specialized managers (`GiverPositionManager`, `TakerPositionManager`, and `ConfigPositionManager`) each encode a narrow delegation scope (inflow, outflow, or configuration), while gateways provide signature- and native-asset-oriented execution paths. The architecture replaces Aave V3's aToken allowance and credit delegation signature patterns with a more expressive, auditable delegation model designed to support lending aggregators, automated strategies, and protocol-to-protocol integrations.

## Relationship to the Hub/Spoke Architecture

Spokes in Aave V4 expose supply, borrow, withdraw, repay, and liquidation entry points. Actions that mutate a position _on behalf of_ another user (e.g., `supply`, `withdraw`, `borrow`, `repay`, `setUsingAsCollateral`) enforce an `onBehalfOf` restriction: a caller can only act on its own position unless it has been explicitly approved as a PositionManager by the target user and activated by Spoke governance/admins. PositionManagers sit at this boundary. They are not core protocol contracts and are not designed as custodial vaults; however, some flows may hold assets transiently within a transaction before forwarding to or from the Hub/Spoke. A Spoke treats an address as a PositionManager for a user only if (i) the PositionManager is marked `active` on that Spoke and (ii) the user has approved it on that Spoke; the Spoke enforces this gate at the call site and otherwise does not attempt to interpret or restrict the PositionManager’s internal policy.

The PositionManager system is implemented in `src/position-manager/` and consists of a shared base contract (`PositionManagerBase`), two gateway contracts (`NativeTokenGateway`, `SignatureGateway`), and three specialized PositionManager contracts (`GiverPositionManager`, `TakerPositionManager`, `ConfigPositionManager`). All five concrete contracts inherit from `PositionManagerBase`.

## Trust Model and Authorization

Spoke-side authorization is a two-gate system. For a PositionManager contract to act on a user's position through a given Spoke, two conditions must both hold: the Spoke must have activated the PositionManager address (`active=true`), and the user must have explicitly approved that PositionManager on the same Spoke. This is not reserve or “market” scoped; it is scoped to the Spoke instance. Independently, all PositionManager contracts also enforce their own Spoke allowlist via `onlyRegisteredSpoke` before forwarding calls to a Spoke.

Neither gate alone is sufficient. A PositionManager that is `active` on a Spoke cannot act on a user who has not approved it on that Spoke. A user may approve a PositionManager even while it is inactive; the approval is persisted but only becomes effective once the Spoke activates the PositionManager. The Spoke enforces both checks at the call site before delegating execution. One exception applies: a user is always their own implicit PositionManager: `_isPositionManager` short-circuits to `true` when `user == manager`, bypassing both the `active` flag and the approval check.

This design means PositionManager approvals are scoped to specific Spoke + PositionManager combinations. Approving a PositionManager on one Spoke grants no access on any other Spoke. There is no global PositionManager registry or cross-spoke approval propagation.

## Signature-Based Approval Flows

Users approve PositionManagers via `setUserPositionManagersWithSig` on the target Spoke. The function accepts an EIP-712 typed signature authorizing a set of approval updates, enabling gasless approval that can be bundled with the first delegated action in a single transaction (typically via multicall on multicall-enabled PositionManagers; `NativeTokenGateway` is the exception, as multicall is intentionally disabled). This replaces the need for a separate on-chain approval transaction before a PositionManager can operate.

The plural form (`setUserPositionManagersWithSig`, not `setUserPositionManagerWithSig`) reflects that a single signed message can authorize multiple PositionManager updates in one operation.

**Approval via PositionManager (setSelfAsUserPositionManagerWithSig)**

`PositionManagerBase` exposes `setSelfAsUserPositionManagerWithSig`, which forwards a `setUserPositionManagersWithSig` call to the target Spoke on the user's behalf. Because all concrete PositionManagers inherit from `PositionManagerBase`, this function is available on every PositionManager, not only on gateways. For PositionManagers with multicall enabled, this pattern allows a user to approve a PositionManager and execute the first action in a single multicall. (`NativeTokenGateway` is the exception: multicall is intentionally disabled.) Two constraints apply:

1. The PositionManager enforces `onlyRegisteredSpoke`: the call is rejected if the PositionManager has not allowlisted the target Spoke (i.e., the Spoke is not registered in the PositionManager’s own registry).
2. The PositionManager's multicall is restricted to its own methods. It cannot relay arbitrary calls to other PositionManagers or contracts. This prevents a scenario where an EOA uses a multicall to chain approvals across PositionManagers it has not independently chosen to authorize.

The signature in `setSelfAsUserPositionManagerWithSig` must specify exactly one PositionManager update, and that update must name `address(this)`.

The Spoke call is executed in a `try/catch`: if sig verification fails (expired deadline, wrong nonce, address mismatch), the function returns successfully without setting any approval and without reverting. Integrators building a multicall that chains this with a subsequent delegated action must be aware that, if the approval silently failed, any subsequent Spoke call that is gated by PositionManager authorization (i.e., uses `onlyPositionManager(onBehalfOf)` / `_isPositionManager(onBehalfOf, msg.sender)`) will revert with `Unauthorized()`.

**ERC-20 Permit (permitReserveUnderlying)**

`PositionManagerBase` exposes `permitReserveUnderlying`, which calls `IERC20Permit(underlying).permit(...)` directly in a `try/catch` to attempt setting the ERC-20 allowance for the PositionManager within the same multicall. Nothing is stored. Because permit failures are intentionally ignored, downstream supply/repay calls will only succeed if the allowance is actually in place at execution time.

## PositionManagerBase

`PositionManagerBase.sol` is the shared base for all PositionManager contracts, including gateways. It inherits `Ownable2Step`, `IntentConsumer`, `Rescuable`, and `Multicall`. It defines:

- The `onlyRegisteredSpoke` modifier and spoke registration management.
- `setSelfAsUserPositionManagerWithSig` for gasless PositionManager approval.
- `permitReserveUnderlying` for ERC-20 permit-based allowance in the same multicall.
- `renouncePositionManagerRole` (owner-only) to clear a PositionManager's role for a user.
- A `Multicall` wrapper gated by `_multicallEnabled()`, which each subclass overrides to enable or disable multicall. `NativeTokenGateway` disables multicall to prevent `msg.value` reuse across delegatecalls; all other PositionManagers enable it.

## NativeTokenGateway

`NativeTokenGateway.sol` handles native coin (ETH or equivalent) wrapping and unwrapping around Spoke interactions. On the inflow side it accepts native coin, wraps it to the corresponding ERC-20, and forwards to the Spoke. On the outflow side it unwraps from the Spoke and returns native coin to the user. The implementation is structurally close to Aave V3's `WrappedTokenGatewayV3`.

## SignatureGateway

`SignatureGateway.sol` executes EIP-712 typed user intent signatures for Spoke actions. It supports `supplyWithSig`, `withdrawWithSig`, `borrowWithSig`, `repayWithSig`, `setUsingAsCollateralWithSig`, `updateUserRiskPremiumWithSig`, and `updateUserDynamicConfigWithSig`. Each function verifies a typed EIP-712 signature from the user and then executes the corresponding Spoke operation on their behalf. It uses keyed nonces, where each key namespace is consumed sequentially.

## GiverPositionManager

`GiverPositionManager` allows an integrator (the external caller of `GiverPositionManager`) to supply or repay on behalf of a user when (i) `GiverPositionManager` has allowlisted the target Spoke (`onlyRegisteredSpoke`), (ii) the Spoke has activated `GiverPositionManager` (`active=true`), and (iii) the user has approved `GiverPositionManager` on that Spoke. No additional per-user allowances are required because the caller (integrator) provides the funds. The inflow-only scope means the PositionManager can move assets into the protocol on a user's behalf but cannot withdraw or borrow.

The caller (integrator) provides the funds: `supplyOnBehalfOf` and `repayOnBehalfOf` transfer tokens from `msg.sender` to the PositionManager, which then forwards them to the Spoke. The user whose position is being acted on does not need to grant any ERC-20 approvals. `repayOnBehalfOf` rejects `type(uint256).max` as the amount to prevent ambiguity; the repay amount is capped at the user's total debt.

Supply and repay on behalf are permissioned by the Spoke’s PositionManager authorization gate (i.e., the PositionManager contract as `msg.sender` to the Spoke must be `active` on the Spoke and approved by `onBehalfOf`), and are additionally gated by the PositionManager’s own Spoke allowlist (`onlyRegisteredSpoke`). This prevents donation attack vectors that would otherwise exist if arbitrary callers could supply to another user's position uninvited.

The intended integrators are lending aggregators and automated repayment systems that need to fund or service positions on behalf of users without requiring active user involvement per transaction.

## TakerPositionManager

`TakerPositionManager` can execute `withdraw` and `borrow` on behalf of a user when (i) it has allowlisted the target Spoke (`onlyRegisteredSpoke`), (ii) the Spoke recognizes it as the user’s PositionManager (i.e., it is `active` on that Spoke and approved by the user), and (iii) the spender holds a sufficient allowance in `TakerPositionManager`. Assets from `withdrawOnBehalfOf` and `borrowOnBehalfOf` are transferred to `msg.sender` (the spender), not to the position owner. Allowances are scoped to specific `(Spoke, ReserveId, owner, spender)` tuples; granting allowance for one Reserve on one Spoke confers no authority over any other Reserve, Spoke, or spender. These allowances are an additional gate and do not replace Spoke-level PositionManager authorization.

**Allowance mechanics**

Withdraw and borrow allowances are tracked separately via `_withdrawAllowances` and `_borrowAllowances` mappings. Users grant allowances through `approveWithdraw` / `approveBorrow` (on-chain) or `approveWithdrawWithSig` / `approveBorrowWithSig` (EIP-712 signed intents). When a spender withdraws or borrows up to the granted amount, the consumed amount is deducted from the outstanding allowance. When the allowance is set to `uint256.max`, spend operations do not decrease it. This max allowance behavior matches the convention established by ERC-20 for unlimited approvals.

`renounceWithdrawAllowance` and `renounceBorrowAllowance` allow the spender to clear its own allowance for a given user, intended for cooperative consumers that want to release dust allowances after a position closes without requiring the user to submit an additional transaction.

**V3 equivalence**

In Aave V3, credit delegation signatures allowed users to grant a third party the ability to borrow on their behalf via aToken `approveDelegation`. The TakerPositionManager replaces this pattern with a more general, multi-asset scoped allowance model that also covers withdrawals.

## ConfigPositionManager

`ConfigPositionManager` allows any address a user has granted config permissions to (a delegatee) to execute position configuration actions on that user's behalf. These config permissions are an additional gate and do not replace Spoke-level PositionManager authorization: calls require (i) `ConfigPositionManager` to have allowlisted the target Spoke (`onlyRegisteredSpoke`), (ii) the Spoke to have activated `ConfigPositionManager` (`active=true`), and (iii) the user to have approved `ConfigPositionManager` on that Spoke. The in-scope operations are:

- `setUsingAsCollateralOnBehalfOf`: toggle whether a specific Reserve is used as collateral in a user's position
- `updateUserRiskPremiumOnBehalfOf`: update the user-level risk premium applied to a position
- `updateUserDynamicConfigOnBehalfOf`: update dynamic position configuration parameters

These operations do not move funds. They adjust how the Hub treats a user's position in risk and accounting calculations. Delegating them to a PositionManager allows automated position management systems to rebalance collateral configuration without requiring user interaction per adjustment.

**Granular permissions**

Permissions are granted per `(Spoke, delegator, delegatee)` triple using a bitmap (`ConfigPermissionsMap`). Each of the three config operations can be delegated independently:

- `setCanUpdateUsingAsCollateralPermission`
- `setCanUpdateUserRiskPremiumPermission`
- `setCanUpdateUserDynamicConfigPermission`

A convenience function `setGlobalPermission` sets or clears all three at once. Delegatees can renounce their own permissions via `renounceGlobalPermission`, `renounceCanUpdateUsingAsCollateralPermission`, `renounceCanUpdateUserRiskPremiumPermission`, and `renounceCanUpdateUserDynamicConfigPermission`.

## Authorization Scope Summary

| PositionManager       | Inflow (supply/repay)       | Outflow (withdraw/borrow)      | Configuration             |
| --------------------- | --------------------------- | ------------------------------ | ------------------------- |
| GiverPositionManager  | Yes, caller funds on behalf | No                             | No                        |
| TakerPositionManager  | No                          | Yes, within granted allowances | No                        |
| ConfigPositionManager | No                          | No                             | Yes, per-operation bitmap |
| SignatureGateway      | Yes, via user sig           | Yes, via user sig              | Yes, via user sig         |
| NativeTokenGateway    | Yes, native coin wrap       | Yes, native coin unwrap        | No                        |

## Out of Scope

The following are explicitly excluded from the PositionManager system:

- **Persistent custody**: PositionManagers are not intended to be custodial vaults and do not track per-user balances. They may still hold assets transiently (and can incidentally retain residual balances, e.g., dust or unexpected transfers) before forwarding to or from the Hub/Spoke.
- **Cross-spoke authority**: A PositionManager approval on one Spoke grants no authority on any other Spoke.
- **Flash loan origination**: PositionManagers do not expose flash loan entry points.
- **Strategy execution or rebalancing logic**: PositionManagers expose delegation primitives. Strategy logic is the responsibility of the integrating protocol.
- **Liquidation**: The standard Spoke liquidation path is not routed through the PositionManager system.
- **Factory deployment**: PositionManagers are deployed and registered independently. There is no PositionManager factory.

## Key Differences from Aave V3

In Aave V3, protocol-to-protocol integrations relied on two patterns that are replaced or superseded in V4:

**aToken allowances** allowed one address to transfer another user's aTokens (representing supply positions). In V4, aToken allowances are not the primary delegation mechanism. The TakerPositionManager provides an explicit, scoped alternative for withdraw-on-behalf scenarios that does not require aToken transfers.

**Credit delegation signatures** (`approveDelegation` with EIP-712 sig) allowed users to authorize third parties to borrow on their behalf. In V4, the TakerPositionManager replaces this with per-reserve, per-spoke borrow allowances that support both on-chain and EIP-712 signed grants without aToken-level accounting.
