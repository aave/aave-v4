// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {IntentConsumer} from 'src/utils/IntentConsumer.sol';
import {IPositionManagerGate} from 'src/spoke/interfaces/IPositionManagerGate.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';
import {PositionManagerGateEIP712Hash} from 'src/spoke/libraries/PositionManagerGateEIP712Hash.sol';

/// @title PositionManagerGate
/// @author Aave Labs
/// @notice Gate implementing the canonical user-approved position-manager policy.
/// @dev A single gate can serve multiple Spokes. All state is scoped by the calling Spoke.
contract PositionManagerGate is IPositionManagerGate, AccessManaged, IntentConsumer {
  using PositionManagerGateEIP712Hash for *;

  struct PositionManagerConfig {
    mapping(address user => bool) approval;
    bool active;
  }

  bytes32 public constant SET_USER_POSITION_MANAGERS_TYPEHASH =
    PositionManagerGateEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH;

  mapping(address spoke => mapping(address positionManager => PositionManagerConfig))
    internal _positionManagers;

  constructor(address authority_) AccessManaged(authority_) {
    require(authority_ != address(0), InvalidAddress());
  }

  /// @inheritdoc IPositionManagerGate
  function updatePositionManager(
    address spoke,
    address positionManager,
    bool active
  ) external restricted {
    require(spoke != address(0), InvalidAddress());
    _positionManagers[spoke][positionManager].active = active;
    emit UpdatePositionManager(spoke, positionManager, active);
  }

  /// @inheritdoc IPositionManagerGate
  function setUserPositionManager(address spoke, address positionManager, bool approve) external {
    _setUserPositionManager(spoke, positionManager, msg.sender, approve);
  }

  /// @inheritdoc IPositionManagerGate
  function setUserPositionManagersWithSig(
    SetUserPositionManagers calldata params,
    bytes calldata signature
  ) external {
    require(params.spoke != address(0), InvalidAddress());
    _verifyAndConsumeIntent({
      signer: params.onBehalfOf,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    for (uint256 i = 0; i < params.updates.length; ++i) {
      _setUserPositionManager(
        params.spoke,
        params.updates[i].positionManager,
        params.onBehalfOf,
        params.updates[i].approve
      );
    }
  }

  /// @inheritdoc IPositionManagerGate
  function renouncePositionManagerRole(address spoke, address user) external {
    PositionManagerConfig storage config = _positionManagers[spoke][msg.sender];
    if (!config.approval[user]) return;
    config.approval[user] = false;
    emit SetUserPositionManager(spoke, user, msg.sender, false);
  }

  /// @inheritdoc IPositionManagerGate
  function isPositionManagerActive(
    address spoke,
    address positionManager
  ) external view returns (bool) {
    return _positionManagers[spoke][positionManager].active;
  }

  /// @inheritdoc IPositionManagerGate
  function isPositionManager(
    address spoke,
    address user,
    address positionManager
  ) public view returns (bool) {
    if (user == positionManager) return true;
    PositionManagerConfig storage config = _positionManagers[spoke][positionManager];
    return config.active && config.approval[user];
  }

  /// @inheritdoc ISpokeGate
  function isCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata
  ) external view returns (bool) {
    return isPositionManager(msg.sender, onBehalfOf, caller);
  }

  function _setUserPositionManager(
    address spoke,
    address positionManager,
    address user,
    bool approve
  ) internal {
    require(spoke != address(0), InvalidAddress());
    _positionManagers[spoke][positionManager].approval[user] = approve;
    emit SetUserPositionManager(spoke, user, positionManager, approve);
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('PositionManagerGate', '1');
  }
}
