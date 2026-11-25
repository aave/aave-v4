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
/// @notice Runs the bulk emergency levers by calling the SpokeConfigurator one reserve or Spoke at a time.
/// @dev Holds no state. The bulk lever records and saved collateral factors stay in the SpokeConfigurator, which
/// every configuration path writes through, so they stay correct when the same settings change outside this
/// contract.
/// @dev Must be granted the SpokeConfigurator selectors it calls: `holdPaused`, `releasePaused`, `holdFrozen`
/// and `releaseFrozen`.
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

  /// @dev Returns the Hub and underlying asset addresses of a Spoke's reserve.
  function _getReserveAddresses(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (address, address) {
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    return (address(reserve.hub), reserve.underlying);
  }

  /// @dev Returns false when the Spoke has no reserve for the Hub asset: either the lookup reverts with
  /// `ReserveNotListed`, or it reverts without data because the Spoke does not implement `getReserveId`, as with
  /// the TreasurySpoke and TokenizationSpoke. Any other revert is bubbled up, so an unexpected Spoke failure
  /// stops the call instead of silently skipping the Spoke. Reverts from the subsequent configuration calls
  /// also propagate.
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
