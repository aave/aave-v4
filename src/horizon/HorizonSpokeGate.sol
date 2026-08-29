// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';
import {IHorizonSpokeGate} from 'src/horizon/interfaces/IHorizonSpokeGate.sol';

/// @title HorizonSpokeGate
/// @author Aave Labs
/// @notice Gate for Horizon RWA spokes. Managers authorized for a reserve can supply, withdraw,
/// repay and set collateral usage on the position of any user for that reserve (e.g. forced
/// transfers via withdraw and re-supply, forced repayments), but never borrow. Liquidations are
/// permissionless and all other calls follow the default position manager authorization.
contract HorizonSpokeGate is Ownable, IHorizonSpokeGate {
  /// @dev Reserve-manager action selectors, indexed by their least-significant byte.
  /// This relies on every other selector routed through the gate having a different trailing byte.
  uint256 internal constant _RESERVE_MANAGER_ACTIONS_BITMAP =
    (uint256(1) << uint8(uint32(ISpoke.supply.selector))) |
      (uint256(1) << uint8(uint32(ISpoke.withdraw.selector))) |
      (uint256(1) << uint8(uint32(ISpoke.repay.selector))) |
      (uint256(1) << uint8(uint32(ISpoke.setUsingAsCollateral.selector)));

  mapping(uint256 reserveId => mapping(address manager => bool)) internal _reserveManagers;

  /// @dev Constructor.
  /// @param initialOwner The owner managing reserve manager authorizations.
  constructor(address initialOwner) Ownable(initialOwner) {}

  /// @inheritdoc IHorizonSpokeGate
  function updateReserveManager(
    uint256 reserveId,
    address manager,
    bool active
  ) external onlyOwner {
    _reserveManagers[reserveId][manager] = active;
    emit UpdateReserveManager(reserveId, manager, active);
  }

  /// @inheritdoc IHorizonSpokeGate
  function isReserveManager(uint256 reserveId, address manager) public view returns (bool) {
    return _reserveManagers[reserveId][manager];
  }

  /// @inheritdoc ISpokeGate
  function isCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata data
  ) external view returns (bool) {
    bytes4 selector = bytes4(data);
    if (selector == ISpoke.liquidationCall.selector) return true;
    if (
      (_RESERVE_MANAGER_ACTIONS_BITMAP &
        (uint256(1) << uint8(uint32(selector)))) !=
      0 &&
      isReserveManager({reserveId: uint256(bytes32(data[4:36])), manager: caller})
    ) {
      return true;
    }
    return ISpoke(msg.sender).isPositionManager(onBehalfOf, caller);
  }
}
