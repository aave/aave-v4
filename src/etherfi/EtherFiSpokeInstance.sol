// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {IEtherFiDataProvider} from 'src/etherfi/interfaces/IEtherFiDataProvider.sol';

/// @title EtherFiSpokeInstance
/// @notice Aave v4 SpokeInstance for the ether.fi whitelabel instance: `borrow` is gated so only
///         ether.fi Cash Safes (per EtherFiDataProvider.isEtherFiSafe) can be the position owner.
///         Supply, withdraw, repay, and liquidationCall are untouched — public LPs and liquidators
///         remain permissionless.
/// @dev The check keys on `onBehalfOf` (the position owner), so it holds whether the safe borrows
///      through its registered position manager or directly.
///
///      SECURITY INVARIANT — position manager listing: the check constrains who carries the debt,
///      not where the borrowed funds go (the spoke pays out to `msg.sender`). The cash-v3
///      LendGateway is the ONLY position manager that may ever be activated on this spoke via
///      `updatePositionManager` — it mirrors this exact invariant in its own natspec ("no
///      position manager other than this gateway is ever activated on the Spoke"), which is what
///      keeps every exit from a safe's position inside the Cash rails (safe withdrawal delay or
///      card settlement). In particular the stock Aave TakerPositionManager must never be listed:
///      its `borrowOnBehalfOf` forwards borrowed funds to the delegated spender, so a safe-signed
///      allowance (incl. the ERC-1271 `*WithSig` paths, which need no transaction from the safe)
///      would let any spender route borrowed funds outside the Cash flow while the debt sits on
///      the safe. For the same reason the stock position managers are not even deployed with this
///      instance (see DeployEtherfiCashInstance), and EtherFiSafe must never implement ERC-1271
///      `isValidSignature`.
///
///      The override deliberately adds no
///      modifiers and no logic beyond the check: the parent's nonReentrant + onlyPositionManager
///      run inside the super call (redeclaring nonReentrant here would self-deadlock on the shared
///      guard), and keeping the body to one check + super means upstream borrow changes flow
///      through untouched.
///
///      The data provider is a compile-time constant (the ether.fi prod EtherFiDataProvider proxy
///      on OP Mainnet) rather than a constructor argument, so this contract keeps the exact
///      `(oracle, maxUserReservesLimit)` constructor shape the Aave deployment framework appends
///      to the spoke bytecode — the instance deployment pipeline needs no framework changes. Code,
///      not storage: zero storage-layout risk across Aave upgrades.
///
///      This file is maintained verbatim in both etherfi-protocol/cash-v3 (the audited copy) and
///      the aave-v4 launch branch (the deployed copy); only the SpokeInstance import path differs
///      per repo. Keep them in sync.
contract EtherFiSpokeInstance is SpokeInstance {
  /// @notice The ether.fi data provider used to recognize Cash Safes (prod proxy, OP Mainnet).
  address public constant ETHERFI_DATA_PROVIDER = 0xDC515Cb479a64552c5A11a57109C314E40A1A778;

  error OnlyEtherFiSafe(address account);

  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_
  ) SpokeInstance(oracle_, maxUserReservesLimit_) {}

  /// @inheritdoc ISpoke
  /// @dev Restricted relative to the base implementation: `onBehalfOf` must be an ether.fi Cash
  ///      Safe (per EtherFiDataProvider.isEtherFiSafe), otherwise reverts with OnlyEtherFiSafe.
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) public override returns (uint256, uint256) {
    require(
      IEtherFiDataProvider(ETHERFI_DATA_PROVIDER).isEtherFiSafe(onBehalfOf),
      OnlyEtherFiSafe(onBehalfOf)
    );
    return super.borrow(reserveId, amount, onBehalfOf);
  }
}
