# PositionManager

## Summary

Position Managers are trusted periphery contracts that operate on Aave V4 Spokes on behalf of users. They enable supply, repay, withdraw, borrow, and configuration actions to be delegated to third-party entities without requiring users to cede persistent custody of funds. Spoke-level Position Manager approval is a simple on/off authorization per (Spoke, user, PositionManager). Finer scoping, where present, is implemented inside specific Position Managers via per-reserve allowances, bitmapped config permissions, or EIP-712 signed intents. The specialized managers (`GiverPositionManager`, `TakerPositionManager`, and `ConfigPositionManager`) each encode a narrow delegation scope (inflow, outflow, or configuration), while gateways provide signature-oriented and native-asset-oriented execution paths. The architecture replaces Aave V3's aToken allowance, credit delegation signature, and `WrappedTokenGatewayV3` (native-asset gateway) patterns with a more expressive, auditable delegation model designed to support lending aggregators, automated strategies, and protocol-to-protocol integrations.

## Relationship to the Hub/Spoke Architecture

Spokes in Aave V4 expose supply, borrow, withdraw, repay, and liquidation entry points. Actions that mutate a position on behalf of another user (e.g., `supply`, `withdraw`, `borrow`, `repay`, `setUsingAsCollateral`) enforce an `onBehalfOf` restriction: a caller can only act on its own position unless it has been explicitly approved as a Position Manager by the target user and activated by Spoke governance/admins. Position Managers sit at this boundary. They are not core protocol contracts and are not designed as custodial vaults. However, some flows may hold assets transiently within a transaction before forwarding to or from the Hub. A Spoke treats an address as a Position Manager for a user only if (i) the Position Manager-side Spoke allowlist gate (`onlyRegisteredSpoke`) is satisfied, (ii) the Spoke-side activation gate (`active=true`) is set, and (iii) the user approval gate is satisfied. The Spoke enforces this gate at the call site and otherwise does not attempt to interpret or restrict the Position Manager’s internal policy.

The Position Manager system is implemented in `src/position-manager/` and consists of two abstract base contracts (`PositionManagerBase` and `PositionManagerIntentBase`), two gateway contracts (`NativeTokenGateway`, `SignatureGateway`), and three specialized Position Manager contracts (`GiverPositionManager`, `TakerPositionManager`, `ConfigPositionManager`). `NativeTokenGateway` and `GiverPositionManager` inherit `PositionManagerBase` directly. `SignatureGateway`, `TakerPositionManager`, and `ConfigPositionManager` inherit `PositionManagerIntentBase`, which extends `PositionManagerBase` with EIP-712 typed-intent verification. Spoke-side activation of Position Managers (gate 2) is managed externally via `SpokeConfigurator`, which exposes `updatePositionManager` to set or clear the `active` flag for a Position Manager on a given Spoke.

## Trust Model and Authorization

Authorization is a three-gate system. For a Position Manager contract to act on a user’s position through a given Spoke, all three conditions must hold:

1. **Position Manager-side Spoke allowlist** (`onlyRegisteredSpoke`): the owner of the Position Manager must have registered the target Spoke via `registerSpoke`. This check is enforced by the Position Manager itself before it forwards any call. If the Spoke is not registered, the call reverts regardless of what the Spoke or the user has approved.
2. **Spoke-side activation** (`active=true`): the Spoke governance/admins must have activated the Position Manager address on that Spoke.
3. **User approval**: the user must have explicitly approved the Position Manager on that Spoke.

None of the three gates alone is sufficient. Even if a Spoke has activated a Position Manager and a user has approved it, calls will still revert at the Position Manager if that Spoke has not been registered by the Position Manager owner. Conversely, a registered Spoke combined with a user approval is inert until the Spoke itself has activated the Position Manager. A user may approve a Position Manager while it is inactive or while the Spoke is unregistered; the approval is persisted but only becomes effective once all three conditions are met. One exception applies: a user is always their own implicit Position Manager. `_isPositionManager` short-circuits to `true` when `user == manager`, bypassing the Spoke-side `active` flag and user approval check (but not the Position Manager’s own `onlyRegisteredSpoke`, which is enforced at the Position Manager entry point before any Spoke call). A user may also revoke their prior approval to a Position Manager at any time by calling `setUserPositionManager` on the Spoke, passing `false` as the value of the `approve` parameter.

These three conditions apply uniformly to all Position Managers described below.

This design means Position Manager approvals are scoped to specific Spoke + Position Manager combinations. Approving a Position Manager on one Spoke grants no access on any other Spoke. There is no global Position Manager registry or cross-spoke approval propagation.

Every Position Manager exposes `renouncePositionManagerRole` (owner-only, defined in `PositionManagerBase`), which calls `ISpoke.renouncePositionManagerRole` to revoke the Position Manager's own approval for a given user on a given Spoke. This is a cooperative cleanup mechanism: the Position Manager contract initiates the revocation rather than waiting for the user to submit a separate transaction. The Spoke-side call is a no-op if the approval was already absent (no event is emitted in that case). Revocation does not affect the Position Manager's `active` flag on the Spoke; it only clears that specific user's approval entry.

**Governor sunsetting.** Whoever controls the Spoke configurator domain admin role (typically the Governor via `AccessManaged` on `SpokeConfigurator`) can deactivate a Position Manager on a Spoke by calling `SpokeConfigurator.updatePositionManager`, to set that address’s Spoke-side `active` flag to `false`. Delegated actions gated by `onlyPositionManager` then fail for that contract on that Spoke until it is reactivated with `updatePositionManager`. This does not iterate users or delete approval bitmap entries; it removes the Spoke-side activation gate (`active=true`, as described above) globally for that Spoke + Position Manager pair, so persisted user approvals are inert while the manager remains inactive.

## Signature-Based Approval Flows

Users approve Position Managers via `setUserPositionManagersWithSig` on the target Spoke. The function accepts an EIP-712 typed signature authorizing a set of approval updates, enabling gasless approval that can be bundled with the first delegated action in a single transaction (typically via multicall on multicall-enabled Position Managers; `NativeTokenGateway` is the exception, as multicall is intentionally disabled to prevent `msg.value` reuse across delegatecalls). This replaces the need for a separate onchain approval transaction before a Position Manager can operate.

The plural form (`setUserPositionManagersWithSig`, not `setUserPositionManagerWithSig`) reflects that a single signed message can authorize multiple Position Manager updates in one operation.

**Approval via Position Manager (`setSelfAsUserPositionManagerWithSig`)**

`PositionManagerBase` exposes `setSelfAsUserPositionManagerWithSig`, which forwards a `setUserPositionManagersWithSig` call to the target Spoke on the user’s behalf. Because all concrete Position Managers inherit from `PositionManagerBase`, this function is available on every Position Manager, not only on gateways. For Position Managers with multicall enabled, this pattern allows a user to approve a Position Manager and execute the first action in a single multicall. (`NativeTokenGateway` is the exception: multicall is intentionally disabled.) Two constraints apply:

1. The Position Manager enforces `onlyRegisteredSpoke`: the call is rejected if the Position Manager has not allowlisted the target Spoke (i.e., the Spoke is not registered in the Position Manager’s own registry).
2. The Position Manager’s multicall is restricted to its own methods. It cannot relay arbitrary calls to other Position Managers or contracts. This prevents a scenario where an EOA uses a multicall to chain approvals across Position Managers it has not independently chosen to authorize.

The signature in `setSelfAsUserPositionManagerWithSig` must specify exactly one Position Manager update, and that update must name the address of the Position Manager.

The Spoke call is executed in a `try/catch`: if sig verification fails (expired deadline, wrong nonce, address mismatch), the function returns successfully without setting any approval and without reverting. Integrators building a multicall that chains this with a subsequent delegated action must be aware that, if the approval silently failed, any subsequent Spoke call that is gated by Position Manager authorization (i.e., uses `onlyPositionManager(onBehalfOf)` / `_isPositionManager(onBehalfOf, msg.sender)`) will revert with `Unauthorized`.

**ERC-20 Permit (`permitReserveUnderlying`)**

`PositionManagerBase` exposes `permitReserveUnderlying`, which calls `IERC20Permit.permit` directly in a `try/catch` to attempt setting the ERC-20 allowance for the Position Manager within the same multicall. Nothing is stored. Because permit failures are intentionally ignored, downstream supply/repay calls will only succeed if the allowance is actually in place at execution time.

## PositionManagerBase

`PositionManagerBase.sol` is the shared base for all Position Manager contracts, including gateways. It inherits `Ownable2Step`, `Rescuable`, and `Multicall`. It defines:

- The `onlyRegisteredSpoke` modifier, `registerSpoke` (owner-only) to allowlist or remove Spokes, and `isSpokeRegistered` for external inspection.
- `setSelfAsUserPositionManagerWithSig` to forward a `setUserPositionManagersWithSig` call to the target Spoke on the user's behalf, enabling gasless Position Manager approval that can be bundled with the first delegated action in a single multicall.
- `permitReserveUnderlying` to call `IERC20Permit.permit` in a `try/catch`, setting the ERC-20 allowance for the Position Manager within the same multicall; permit failures are silently ignored, so downstream supply or repay calls succeed only if the allowance is in place at execution time.
- `renouncePositionManagerRole` (owner-only) to call `ISpoke.renouncePositionManagerRole`, revoking the Position Manager's own approval for a given user on a given Spoke; the Spoke-side call is a no-op if the approval was already absent.
- A `Multicall` wrapper gated by `_multicallEnabled()`, which each subclass overrides to enable or disable multicall; `NativeTokenGateway` disables multicall to prevent `msg.value` reuse across delegatecalls, while all other Position Managers enable it.

## PositionManagerIntentBase

`PositionManagerIntentBase.sol` extends `PositionManagerBase` by additionally inheriting `IntentConsumer`, which adds EIP-712 domain separation and keyed-nonce consumption via `_verifyAndConsumeIntent`. It is used by contracts that verify user-signed intents: `SignatureGateway`, `TakerPositionManager`, and `ConfigPositionManager`. `NativeTokenGateway` and `GiverPositionManager` inherit `PositionManagerBase` directly, as they do not process user signatures.

## NativeTokenGateway

`NativeTokenGateway.sol` handles native coin (ETH or equivalent) wrapping and unwrapping around Spoke interactions. On the inflow side it accepts native coin, wraps it to the corresponding ERC-20, and forwards to the Spoke. On the outflow side it unwraps from the Spoke and returns native coin to the user. The implementation is structurally close to Aave V3's `WrappedTokenGatewayV3`.

## SignatureGateway

`SignatureGateway.sol` executes EIP-712 typed user intent signatures for Spoke actions. It supports `supplyWithSig`, `withdrawWithSig`, `borrowWithSig`, `repayWithSig`, `setUsingAsCollateralWithSig`, `updateUserRiskPremiumWithSig`, and `updateUserDynamicConfigWithSig`. Each function verifies a typed EIP-712 signature from the user and then executes the corresponding Spoke operation on their behalf. It uses keyed nonces, where each key namespace is consumed sequentially.

## GiverPositionManager

`GiverPositionManager` allows an integrator (the external caller of `GiverPositionManager`) to supply or repay on behalf of a user, subject to the three-gate authorization described in Trust Model and Authorization. No additional per-user allowances are required because the caller provides the funds. The inflow-only scope means the Position Manager can move assets into the protocol on a user’s behalf but cannot withdraw or borrow.

The caller (integrator) provides the funds: `supplyOnBehalfOf` and `repayOnBehalfOf` transfer tokens from `msg.sender` to the Position Manager, which then approves the Spoke to pull them. The user whose position is being acted on does not need to grant any ERC-20 approvals. `repayOnBehalfOf` rejects `type(uint256).max` as the amount to prevent a frontrunning attack surface where the end user could borrow more before the repay lands. Thus the repay amount is capped at the user’s total debt.

Supply and repay on behalf are permissioned by the Spoke’s Position Manager authorization gate (i.e., the Position Manager contract as `msg.sender` to the Spoke must be `active` on the Spoke and approved by `onBehalfOf`), and are additionally gated by the Position Manager’s own Spoke allowlist (`onlyRegisteredSpoke`). This prevents donation attack vectors that would otherwise exist if arbitrary callers could supply to another user’s position uninvited.

The intended integrators are lending aggregators and automated repayment systems that need to fund or service positions on behalf of users without requiring active user involvement per transaction.

## TakerPositionManager

`TakerPositionManager` can execute `withdraw` and `borrow` on behalf of a user, subject to the three-gate authorization described in Trust Model and Authorization, and additionally when the spender holds a sufficient allowance in `TakerPositionManager`. Assets from `withdrawOnBehalfOf` and `borrowOnBehalfOf` are transferred to `msg.sender` (the spender), not to the position owner. Allowances are scoped to specific `(Spoke, ReserveId, owner, spender)` tuples; granting allowance for one Reserve on one Spoke confers no authority over any other Reserve, Spoke, or spender. These allowances are an additional gate and do not replace spoke-level Position Manager authorization.

**Allowance mechanics**

Withdraw and borrow allowances are tracked separately via `_withdrawAllowances` and `_borrowAllowances` mappings. Users grant allowances through `approveWithdraw` / `approveBorrow` (onchain) or `approveWithdrawWithSig` / `approveBorrowWithSig` (EIP-712 signed intents). When a spender withdraws or borrows up to the granted amount, the consumed amount is deducted from the outstanding allowance. When the allowance is set to `type(uint256).max`, spend operations do not decrease it. This max allowance behavior matches the convention established by ERC-20 for unlimited approvals.

`renounceWithdrawAllowance` and `renounceBorrowAllowance` allow the spender to clear its own allowance for a given user, intended for cooperative consumers that want to release dust allowances after a position closes without requiring the user to submit an additional transaction.

**Aave V3 equivalence**

In Aave V3, two patterns covered outflow delegation: aToken allowances (ERC-20 `approve`/`transferFrom` on aTokens) enabled third parties to transfer a user's supply position, and credit delegation signatures (`approveDelegation` with EIP-712 sig) enabled third parties to borrow on a user's behalf. The TakerPositionManager replaces both with a unified, multi-asset scoped allowance model that covers withdrawals and borrows independently, without requiring aToken transfers or aToken-level accounting.

## ConfigPositionManager

`ConfigPositionManager` allows users to grant config permissions to any address (a delegatee), authorizing it to modify position settings on their behalf, subject to the three-gate authorization described in Trust Model and Authorization. The in-scope operations are:

- `setUsingAsCollateralOnBehalfOf`: toggle whether a specific Reserve is used as collateral in a user's position
- `updateUserRiskPremiumOnBehalfOf`: update the user-level risk premium applied to a position
- `updateUserDynamicConfigOnBehalfOf`: update dynamic position configuration parameters

These operations do not move funds. They adjust how the Spoke treats a user's position in risk and accounting calculations. Delegating them to a Position Manager allows automated position management systems to rebalance collateral configuration without requiring user interaction per adjustment.

**Granular permissions**

Permissions are granted per `(Spoke, delegator, delegatee)` triple using a bitmap (`ConfigPermissionsMap`). Each of the three config operations can be delegated independently:

- `setCanUpdateUsingAsCollateralPermission`
- `setCanUpdateUserRiskPremiumPermission`
- `setCanUpdateUserDynamicConfigPermission`

A convenience function `setGlobalPermission` sets or clears all three at once. Delegatees can renounce their own permissions:

- `renounceGlobalPermission`
- `renounceCanUpdateUsingAsCollateralPermission`
- `renounceCanUpdateUserRiskPremiumPermission`
- `renounceCanUpdateUserDynamicConfigPermission`

## Authorization Scope Summary

| **PositionManager**   | **Inflow (supply/repay)**                    | **Outflow (withdraw/borrow)**  | **Configuration**         |
| --------------------- | -------------------------------------------- | ------------------------------ | ------------------------- |
| GiverPositionManager  | Yes, caller provides funds on behalf of user | No                             | No                        |
| TakerPositionManager  | No                                           | Yes, within granted allowances | No                        |
| ConfigPositionManager | No                                           | No                             | Yes, per-operation bitmap |
| SignatureGateway      | Yes, via user sig                            | Yes, via user sig              | Yes, via user sig         |
| NativeTokenGateway    | Yes, native coin wrap                        | Yes, native coin unwrap        | No                        |

## Out of Scope

The following are explicitly excluded from the Position Manager system:

- **Persistent custody**: Position Managers are not custodial vaults, do not track per-user balances, and may hold assets transiently within a transaction before forwarding to or from the Hub.
- **Cross-spoke authority**: A Position Manager approval on one Spoke grants no authority on any other Spoke.
- **Flash loan origination**: Position Managers do not expose flash loan entry points.
- **Strategy execution or rebalancing logic**: Position Managers expose delegation primitives only; strategy logic is the responsibility of the integrating protocol.
- **Liquidation**: The standard Spoke liquidation path is not routed through the Position Manager system.
- **Factory deployment**: Position Managers are deployed and registered independently. There is no Position Manager factory.

## Key Differences from Aave V3

In Aave V3, protocol-to-protocol integrations relied on three patterns that are replaced or superseded in Aave V4:

**aToken allowances** allowed one address to transfer another user's aTokens (representing supply positions). In Aave V4, aToken allowances are not the primary delegation mechanism. The TakerPositionManager provides an explicit, scoped alternative for withdraw-on-behalf scenarios that does not require aToken transfers.

**Credit delegation signatures** (`approveDelegation` with EIP-712 sig) allowed users to authorize third parties to borrow on their behalf. In Aave V4, the TakerPositionManager replaces this with per-reserve, per-spoke borrow allowances that support both onchain and EIP-712 signed grants without aToken-level accounting.

**Native-asset gateway** (`WrappedTokenGatewayV3`) was a standalone periphery contract for wrapping/unwrapping native assets (ETH) around Pool interactions. In Aave V4, `NativeTokenGateway` subsumes this role as a Position Manager, inheriting `PositionManagerBase` and integrating into the unified authorization model rather than operating as an independent contract with its own trust assumptions.
