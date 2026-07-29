// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

/// @dev The ether.fi data provider used to recognize Cash Safes (a proxy; address is stable).
interface IEtherFiDataProvider {
  function isEtherFiSafe(address account) external view returns (bool);
}

/// @title EtherFiSpokeInstance
/// @notice Aave v4 SpokeInstance for the ether.fi whitelabel instance: `borrow` is gated so only
///         ether.fi Cash Safes (per EtherFiDataProvider.isEtherFiSafe) can be the position owner.
///         Supply, withdraw, repay, and liquidationCall are untouched — public LPs and liquidators
///         remain permissionless.
/// @dev The check keys on `onBehalfOf` (the position owner), so it holds whether the safe borrows
///      through its registered position manager or directly. The override deliberately adds no
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

  /// @notice Borrows `amount` of reserve `reserveId` for `onBehalfOf`, which must be an ether.fi
  ///         Cash Safe.
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
