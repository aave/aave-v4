// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title SpokeEngine
/// @author Aave Labs
/// @notice Library containing Spoke configurator logic for AaveV4ConfigEngine.
library SpokeEngine {
  using SafeCast for uint256;

  /// @notice Lists new reserves on Spokes.
  /// @param listings The reserve listings to execute.
  function executeSpokeReserveListings(
    IAaveV4ConfigEngine.ReserveListing[] calldata listings
  ) external {
    uint256 length = listings.length;
    for (uint256 i; i < length; ++i) {
      listings[i].spokeConfigurator.addReserve(
        listings[i].spoke,
        listings[i].hub,
        listings[i].underlying,
        listings[i].priceSource,
        listings[i].config,
        listings[i].dynamicConfig
      );
    }
  }

  /// @notice Updates reserve config on Spokes.
  /// @dev `frozen` dispatches to `freezeReserve` (which also zeroes the collateral factor) or
  /// `unfreezeReserve`, and only when the on-chain frozen flag differs.
  /// @param updates The reserve config updates to execute.
  function executeSpokeReserveConfigUpdates(
    IAaveV4ConfigEngine.ReserveConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      if (updates[i].priceSource != EngineFlags.KEEP_CURRENT_ADDRESS) {
        updates[i].spokeConfigurator.updateReservePriceSource(
          updates[i].spoke,
          updates[i].hub,
          updates[i].underlying,
          updates[i].priceSource
        );
      }
      if (updates[i].collateralRisk != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updateCollateralRisk(
          updates[i].spoke,
          updates[i].hub,
          updates[i].underlying,
          updates[i].collateralRisk
        );
      }
      if (updates[i].paused != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updatePaused(
          updates[i].spoke,
          updates[i].hub,
          updates[i].underlying,
          EngineFlags.toBool(updates[i].paused)
        );
      }
      if (updates[i].frozen != EngineFlags.KEEP_CURRENT) {
        _updateFrozen(updates[i]);
      }
      if (updates[i].borrowable != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updateBorrowable(
          updates[i].spoke,
          updates[i].hub,
          updates[i].underlying,
          EngineFlags.toBool(updates[i].borrowable)
        );
      }
      if (updates[i].receiveSharesEnabled != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updateReceiveSharesEnabled(
          updates[i].spoke,
          updates[i].hub,
          updates[i].underlying,
          EngineFlags.toBool(updates[i].receiveSharesEnabled)
        );
      }
    }
  }

  /// @notice Updates liquidation config on Spokes.
  /// @dev If all three fields (targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor)
  /// are set, calls updateLiquidationConfig with the full struct. Otherwise, each non-KEEP_CURRENT
  /// field is updated individually via its dedicated setter. If no field is set, the update is skipped.
  /// @param updates The liquidation config updates to execute.
  function executeSpokeLiquidationConfigUpdates(
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      bool updateTarget = updates[i].targetHealthFactor != EngineFlags.KEEP_CURRENT;
      bool updateMaxBonus = updates[i].healthFactorForMaxBonus != EngineFlags.KEEP_CURRENT;
      bool updateBonusFactor = updates[i].liquidationBonusFactor != EngineFlags.KEEP_CURRENT;

      if (updateTarget && updateMaxBonus && updateBonusFactor) {
        updates[i].spokeConfigurator.updateLiquidationConfig(
          updates[i].spoke,
          ISpoke.LiquidationConfig({
            targetHealthFactor: updates[i].targetHealthFactor.toUint128(),
            healthFactorForMaxBonus: updates[i].healthFactorForMaxBonus.toUint64(),
            liquidationBonusFactor: updates[i].liquidationBonusFactor.toUint16()
          })
        );
      } else {
        if (updateTarget) {
          updates[i].spokeConfigurator.updateLiquidationTargetHealthFactor(
            updates[i].spoke,
            updates[i].targetHealthFactor
          );
        }
        if (updateMaxBonus) {
          updates[i].spokeConfigurator.updateHealthFactorForMaxBonus(
            updates[i].spoke,
            updates[i].healthFactorForMaxBonus
          );
        }
        if (updateBonusFactor) {
          updates[i].spokeConfigurator.updateLiquidationBonusFactor(
            updates[i].spoke,
            updates[i].liquidationBonusFactor
          );
        }
      }
    }
  }

  /// @notice Adds dynamic reserve configs on Spokes.
  /// @param additions The dynamic reserve config additions to execute.
  function executeSpokeDynamicReserveConfigAdditions(
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] calldata additions
  ) external {
    uint256 length = additions.length;
    for (uint256 i; i < length; ++i) {
      additions[i].spokeConfigurator.addDynamicReserveConfig(
        additions[i].spoke,
        additions[i].hub,
        additions[i].underlying,
        additions[i].dynamicConfig
      );
    }
  }

  /// @notice Updates dynamic reserve configs on Spokes.
  /// @dev Reads the current config, applies only the fields that differ from KEEP_CURRENT,
  /// and writes back. If no field is modified the external call is skipped entirely.
  /// @param updates The dynamic reserve config updates to execute.
  function executeSpokeDynamicReserveConfigUpdates(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      uint256 reserveId = _resolveReserveId(
        updates[i].spoke,
        updates[i].hub,
        updates[i].underlying
      );
      bool anyUpdated;

      ISpoke.DynamicReserveConfig memory current = ISpoke(updates[i].spoke).getDynamicReserveConfig(
        reserveId,
        updates[i].dynamicConfigKey.toUint32()
      );

      if (updates[i].collateralFactor != EngineFlags.KEEP_CURRENT) {
        current.collateralFactor = updates[i].collateralFactor.toUint16();
        anyUpdated = true;
      }
      if (updates[i].maxLiquidationBonus != EngineFlags.KEEP_CURRENT) {
        current.maxLiquidationBonus = updates[i].maxLiquidationBonus.toUint32();
        anyUpdated = true;
      }
      if (updates[i].liquidationFee != EngineFlags.KEEP_CURRENT) {
        current.liquidationFee = updates[i].liquidationFee.toUint16();
        anyUpdated = true;
      }

      if (!anyUpdated) continue;

      updates[i].spokeConfigurator.updateDynamicReserveConfig(
        updates[i].spoke,
        updates[i].hub,
        updates[i].underlying,
        updates[i].dynamicConfigKey.toUint32(),
        current
      );
    }
  }

  /// @notice Updates position managers on Spokes.
  /// @param updates The position manager updates to execute on Spokes.
  function executeSpokePositionManagerUpdates(
    IAaveV4ConfigEngine.PositionManagerUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      updates[i].spokeConfigurator.updatePositionManager(
        updates[i].spoke,
        updates[i].positionManager,
        updates[i].active
      );
    }
  }

  /// @dev Freezes or unfreezes the reserve when the requested state differs from the on-chain flag.
  function _updateFrozen(IAaveV4ConfigEngine.ReserveConfigUpdate calldata update) private {
    bool frozen = EngineFlags.toBool(update.frozen);
    uint256 reserveId = _resolveReserveId(update.spoke, update.hub, update.underlying);
    if (ISpoke(update.spoke).getReserveConfig(reserveId).frozen == frozen) return;
    if (frozen) {
      update.spokeConfigurator.freezeReserve(update.spoke, update.hub, update.underlying);
    } else {
      update.spokeConfigurator.unfreezeReserve(update.spoke, update.hub, update.underlying);
    }
  }

  /// @dev Resolves the reserve ID from spoke, hub, and underlying addresses.
  function _resolveReserveId(
    address spoke,
    address hub,
    address underlying
  ) private view returns (uint256) {
    uint256 assetId = IHubBase(hub).getAssetId(underlying);
    return ISpoke(spoke).getReserveId(hub, assetId);
  }
}
