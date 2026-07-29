// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {AaveV4EtherfiCash} from 'src/etherfi/AaveV4EtherfiCash.sol';

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
///      The data provider is a compile-time constant (from the pinned AaveV4EtherfiCash address
///      book) rather than a constructor argument, so this contract keeps the exact
///      `(oracle, maxUserReservesLimit)` constructor shape the Aave deployment framework appends
///      to the spoke bytecode — the instance deployment pipeline needs no framework changes. Code,
///      not storage: zero storage-layout risk across Aave upgrades.
contract EtherFiSpokeInstance is SpokeInstance {
  error OnlyEtherFiSafe(address account);

  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_
  ) SpokeInstance(oracle_, maxUserReservesLimit_) {}

  /// @notice The ether.fi data provider used to recognize Cash Safes.
  function etherFiDataProvider() public pure returns (address) {
    return AaveV4EtherfiCash.ETHERFI_DATA_PROVIDER;
  }

  /// @notice Borrows `amount` of reserve `reserveId` for `onBehalfOf`, which must be an ether.fi
  ///         Cash Safe.
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) public override returns (uint256, uint256) {
    require(
      IEtherFiDataProvider(AaveV4EtherfiCash.ETHERFI_DATA_PROVIDER).isEtherFiSafe(onBehalfOf),
      OnlyEtherFiSafe(onBehalfOf)
    );
    return super.borrow(reserveId, amount, onBehalfOf);
  }
}
