// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {IEligibilityRegistry} from 'src/spoke/interfaces/IEligibilityRegistry.sol';
import {AuthKind} from 'src/spoke/libraries/AuthKind.sol';

/// @title EligibilityRegistry
/// @author Aave Labs
/// @notice Registry of an issuer: a status and a KYC expiry per account, and the actions granted to
/// the reserve managers of each Spoke reserve.
contract EligibilityRegistry is IEligibilityRegistry, AccessManaged {
  mapping(address account => Entry) internal _entries;
  mapping(address spoke => mapping(uint256 reserveId => mapping(address manager => uint8 actions)))
    internal _reserveManagers;

  /// @dev Constructor.
  /// @param authority_ The address of the authority contract which manages permissions.
  constructor(address authority_) AccessManaged(authority_) {
    require(authority_ != address(0), InvalidAddress());
  }

  /// @inheritdoc IEligibilityRegistry
  function updateEligibility(
    address[] calldata accounts,
    Status status,
    uint40 validUntil
  ) external restricted {
    for (uint256 i = 0; i < accounts.length; ++i) {
      _entries[accounts[i]] = Entry({status: status, validUntil: validUntil});
      emit UpdateEligibility(accounts[i], status, validUntil);
    }
  }

  /// @inheritdoc IEligibilityRegistry
  function updateReserveManager(
    address spoke,
    uint256 reserveId,
    address manager,
    uint8 actions
  ) external restricted {
    require(spoke != address(0) && manager != address(0), InvalidAddress());
    require(actions & ~AuthKind.ALL_ACTIONS == 0, InvalidActions());
    _reserveManagers[spoke][reserveId][manager] = actions;
    emit UpdateReserveManager(spoke, reserveId, manager, actions);
  }

  /// @inheritdoc IEligibilityRegistry
  function getStatus(address account) external view returns (Status) {
    Entry memory entry = _entries[account];
    if (entry.status == Status.ACTIVE && entry.validUntil < block.timestamp) {
      return Status.OFFBOARDED;
    }
    return entry.status;
  }

  /// @inheritdoc IEligibilityRegistry
  function getEntry(address account) external view returns (Entry memory) {
    return _entries[account];
  }

  /// @inheritdoc IEligibilityRegistry
  function getReserveManagerActions(
    address spoke,
    uint256 reserveId,
    address manager
  ) external view returns (uint8) {
    return _reserveManagers[spoke][reserveId][manager];
  }
}
