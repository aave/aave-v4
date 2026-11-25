// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {BulkLeversMap} from 'src/libraries/BulkLeversMap.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IEmergencySteward} from 'src/emergency/interfaces/IEmergencySteward.sol';

/// @title EmergencySteward
/// @author Aave Labs
/// @notice Runs the bulk emergency levers through the SpokeConfigurator.
/// @dev Must be granted permission by the SpokeConfigurator.
contract EmergencySteward is AccessManaged, IEmergencySteward {
  /// @inheritdoc IEmergencySteward
  address public immutable SPOKE_CONFIGURATOR;

  /// @dev Constructor.
  /// @param authority_ The address of the authority contract that manages access control.
  /// @param spokeConfigurator_ The address of the SpokeConfigurator.
  constructor(address authority_, address spokeConfigurator_) AccessManaged(authority_) {
    require(spokeConfigurator_ != address(0), InvalidAddress());
    SPOKE_CONFIGURATOR = spokeConfigurator_;
  }

  /// @inheritdoc IEmergencySteward
  function pauseAllReserves(address spoke) external restricted {
    uint256 reserveCount = ISpoke(spoke).getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      (address hub, address underlying) = _getReserveAddresses(ISpoke(spoke), reserveId);
      ISpokeConfigurator(SPOKE_CONFIGURATOR).holdPaused(
        spoke,
        hub,
        underlying,
        BulkLeversMap.SPOKE_MASK
      );
    }
  }

  /// @inheritdoc IEmergencySteward
  function unpauseAllReserves(address spoke) external restricted {
    uint256 reserveCount = ISpoke(spoke).getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      (address hub, address underlying) = _getReserveAddresses(ISpoke(spoke), reserveId);
      ISpokeConfigurator(SPOKE_CONFIGURATOR).releasePaused(
        spoke,
        hub,
        underlying,
        BulkLeversMap.SPOKE_MASK
      );
    }
  }

  /// @inheritdoc IEmergencySteward
  function freezeSpoke(address spoke) external restricted {
    uint256 reserveCount = ISpoke(spoke).getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      (address hub, address underlying) = _getReserveAddresses(ISpoke(spoke), reserveId);
      ISpokeConfigurator(SPOKE_CONFIGURATOR).holdFrozen(
        spoke,
        hub,
        underlying,
        BulkLeversMap.SPOKE_MASK
      );
    }
  }

  /// @inheritdoc IEmergencySteward
  function unfreezeSpoke(address spoke) external restricted {
    uint256 reserveCount = ISpoke(spoke).getReserveCount();
    for (uint256 reserveId = 0; reserveId < reserveCount; ++reserveId) {
      (address hub, address underlying) = _getReserveAddresses(ISpoke(spoke), reserveId);
      ISpokeConfigurator(SPOKE_CONFIGURATOR).releaseFrozen(
        spoke,
        hub,
        underlying,
        BulkLeversMap.SPOKE_MASK
      );
    }
  }

  /// @inheritdoc IEmergencySteward
  function freezeAsset(address hub, address underlying) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    uint256 spokeCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokeCount; ++i) {
      address spoke = targetHub.getSpokeAddress(assetId, i);
      if (_isReserveListed(ISpoke(spoke), hub, assetId)) {
        ISpokeConfigurator(SPOKE_CONFIGURATOR).holdFrozen(
          spoke,
          hub,
          underlying,
          BulkLeversMap.ASSET_MASK
        );
      }
    }
  }

  /// @inheritdoc IEmergencySteward
  function unfreezeAsset(address hub, address underlying) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    uint256 spokeCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokeCount; ++i) {
      address spoke = targetHub.getSpokeAddress(assetId, i);
      if (_isReserveListed(ISpoke(spoke), hub, assetId)) {
        ISpokeConfigurator(SPOKE_CONFIGURATOR).releaseFrozen(
          spoke,
          hub,
          underlying,
          BulkLeversMap.ASSET_MASK
        );
      }
    }
  }

  /// @inheritdoc IEmergencySteward
  function disableAssetBorrowing(address hub, address underlying) external restricted {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    uint256 spokeCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokeCount; ++i) {
      address spoke = targetHub.getSpokeAddress(assetId, i);
      if (_isReserveListed(ISpoke(spoke), hub, assetId)) {
        ISpokeConfigurator(SPOKE_CONFIGURATOR).disableBorrowing(spoke, hub, underlying);
      }
    }
  }

  /// @inheritdoc IEmergencySteward
  function deactivatePositionManager(
    address[] calldata spokes,
    address positionManager
  ) external restricted {
    for (uint256 i = 0; i < spokes.length; ++i) {
      if (ISpoke(spokes[i]).isPositionManagerActive(positionManager)) {
        ISpokeConfigurator(SPOKE_CONFIGURATOR).updatePositionManager(
          spokes[i],
          positionManager,
          false
        );
      }
    }
  }

  /// @dev Returns the Hub and underlying asset addresses of a Spoke's reserve.
  function _getReserveAddresses(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (address, address) {
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    return (address(reserve.hub), reserve.underlying);
  }

  /// @dev Returns false if the Spoke has no reserve for the asset, including Spokes without `getReserveId` such as
  /// the TreasurySpoke and TokenizationSpoke. Bubbles up any other revert.
  function _isReserveListed(
    ISpoke spoke,
    address hub,
    uint256 assetId
  ) internal view returns (bool) {
    try spoke.getReserveId(hub, assetId) {
      return true;
    } catch (bytes memory reason) {
      if (
        reason.length == 0 ||
        (reason.length == 4 && bytes4(reason) == ISpoke.ReserveNotListed.selector)
      ) {
        return false;
      }
      assembly ('memory-safe') {
        revert(add(reason, 32), mload(reason))
      }
    }
  }
}
