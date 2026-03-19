// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {Assertions} from 'tests/helpers/hub/Assertions.sol';

/// @title ConfigHelpers
/// @notice Hub-level configuration mutator helpers for the Aave V4 test suite.
abstract contract ConfigHelpers is Assertions {
  using SafeCast for *;

  function _updateAssetReinvestmentController(
    IHub hub,
    uint256 assetId,
    address newReinvestmentController,
    address hubAdmin
  ) internal pausePrank {
    IHub.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.reinvestmentController = newReinvestmentController;

    vm.prank(hubAdmin);
    hub.updateAssetConfig(assetId, config, new bytes(0));

    assertEq(hub.getAssetConfig(assetId), config);
  }

  function _updateLiquidityFee(
    IHub hub,
    uint256 assetId,
    uint256 liquidityFee,
    address hubAdmin
  ) internal pausePrank {
    IHub.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee.toUint16();
    vm.prank(hubAdmin);
    hub.updateAssetConfig(assetId, config, new bytes(0));

    assertEq(hub.getAssetConfig(assetId), config);
  }

  function _updateSpokeHalted(
    IHub hub,
    uint256 assetId,
    address spoke,
    bool halted,
    address hubAdmin
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.halted = halted;
    vm.prank(hubAdmin);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function _updateSpokeActive(
    IHub hub,
    uint256 assetId,
    address spoke,
    bool newActive,
    address hubAdmin
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.active = newActive;
    vm.prank(hubAdmin);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function _updateAddCap(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint40 newAddCap,
    address hubAdmin
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.addCap = newAddCap;
    vm.prank(hubAdmin);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function _updateDrawCap(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint40 newDrawCap,
    address hubAdmin
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.drawCap = newDrawCap;
    vm.prank(hubAdmin);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function _updateSpokeRiskPremiumThreshold(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint24 newRiskPremiumThreshold,
    address hubAdmin
  ) internal pausePrank {
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.riskPremiumThreshold = newRiskPremiumThreshold;
    vm.prank(hubAdmin);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function _grantDeficitEliminatorRole(
    IHub hub,
    address target,
    address admin
  ) internal pausePrank {
    IAccessManager manager = IAccessManager(hub.authority());
    vm.prank(admin);
    manager.grantRole(Roles.DEFICIT_ELIMINATOR_ROLE, target, 0);
  }
}
