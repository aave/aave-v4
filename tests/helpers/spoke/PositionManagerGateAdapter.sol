// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPositionManagerGate} from 'src/spoke/interfaces/IPositionManagerGate.sol';

/// @dev Test adapter preserving concise Spoke-oriented calls while position-manager state lives in the gate.
library PositionManagerGateAdapter {
  function updatePositionManager(ISpoke spoke, address positionManager, bool active) internal {
    _gate(spoke).updatePositionManager(address(spoke), positionManager, active);
  }

  function setUserPositionManager(ISpoke spoke, address positionManager, bool approve) internal {
    _gate(spoke).setUserPositionManager(address(spoke), positionManager, approve);
  }

  function setUserPositionManagersWithSig(
    ISpoke spoke,
    IPositionManagerGate.SetUserPositionManagers memory params,
    bytes memory signature
  ) internal {
    _gate(spoke).setUserPositionManagersWithSig(params, signature);
  }

  function renouncePositionManagerRole(ISpoke spoke, address user) internal {
    _gate(spoke).renouncePositionManagerRole(address(spoke), user);
  }

  function isPositionManagerActive(
    ISpoke spoke,
    address positionManager
  ) internal view returns (bool) {
    return _gate(spoke).isPositionManagerActive(address(spoke), positionManager);
  }

  function isPositionManager(
    ISpoke spoke,
    address user,
    address positionManager
  ) internal view returns (bool) {
    return _gate(spoke).isPositionManager(address(spoke), user, positionManager);
  }

  function _gate(ISpoke spoke) private view returns (IPositionManagerGate) {
    return IPositionManagerGate(spoke.GATE());
  }
}

abstract contract PositionManagerGateTestHelpers {
  mapping(address spoke => IPositionManagerGate gate) private _positionManagerGates;

  function _cachePositionManagerGate(ISpoke spoke) internal {
    _positionManagerGates[address(spoke)] = IPositionManagerGate(spoke.GATE());
  }

  function _positionManagerGate(ISpoke spoke) internal view returns (IPositionManagerGate gate) {
    gate = _positionManagerGates[address(spoke)];
    if (address(gate) == address(0)) gate = IPositionManagerGate(spoke.GATE());
  }

  function _updatePositionManager(ISpoke spoke, address positionManager, bool active) internal {
    _positionManagerGate(spoke).updatePositionManager(address(spoke), positionManager, active);
  }

  function _setUserPositionManager(ISpoke spoke, address positionManager, bool approve) internal {
    _positionManagerGate(spoke).setUserPositionManager(address(spoke), positionManager, approve);
  }

  function _setUserPositionManagersWithSig(
    ISpoke spoke,
    IPositionManagerGate.SetUserPositionManagers memory params,
    bytes memory signature
  ) internal {
    _positionManagerGate(spoke).setUserPositionManagersWithSig(params, signature);
  }

  function _renouncePositionManagerRole(ISpoke spoke, address user) internal {
    _positionManagerGate(spoke).renouncePositionManagerRole(address(spoke), user);
  }

  function _isPositionManagerActive(
    ISpoke spoke,
    address positionManager
  ) internal view returns (bool) {
    return _positionManagerGate(spoke).isPositionManagerActive(address(spoke), positionManager);
  }

  function _isPositionManager(
    ISpoke spoke,
    address user,
    address positionManager
  ) internal view returns (bool) {
    return _positionManagerGate(spoke).isPositionManager(address(spoke), user, positionManager);
  }
}
