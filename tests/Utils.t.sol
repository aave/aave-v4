// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {LiquidityHub, DataTypes} from 'src/contracts/LiquidityHub.sol';
import {Spoke, ISpoke} from 'src/contracts/Spoke.sol';

library Utils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // hub
  function addAssetAndSpokes(
    LiquidityHub hub,
    address asset,
    DataTypes.AssetConfig memory assetConfig,
    address[] memory spokes,
    DataTypes.SpokeConfig[] memory spokeConfigs,
    Spoke.ReserveConfig[] memory reserveConfigs
  ) internal {
    hub.addAsset(assetConfig, asset);
    uint256 assetId = hub.assetCount() - 1;
    for (uint256 i = 0; i < spokes.length; i++) {
      hub.addSpoke(assetId, spokeConfigs[i], spokes[i]);
      Spoke(spokes[i]).addReserve(assetId, reserveConfigs[i], asset);
    }
  }

  function supply(
    LiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    uint256 riskPremiumRad,
    address user,
    address to // todo: implement
  ) internal {
    vm.startPrank(user);
    hub.assetsList(assetId).approve(address(hub), amount);
    vm.stopPrank();

    vm.prank(spoke);
    hub.supply({assetId: assetId, amount: amount, riskPremiumRad: riskPremiumRad, supplier: user});
  }

  function draw(
    LiquidityHub hub,
    uint256 assetId,
    address spoke,
    address to,
    uint256 amount,
    uint256 riskPremiumRad,
    address onBehalfOf // todo: implement
  ) internal {
    vm.prank(spoke);
    hub.draw({assetId: assetId, amount: amount, riskPremiumRad: riskPremiumRad, to: to});
  }

  function withdraw(
    LiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    uint256 riskPremiumRad,
    address to
  ) internal {
    vm.prank(spoke);
    hub.withdraw({assetId: assetId, amount: amount, riskPremiumRad: riskPremiumRad, to: to});
  }

  function borrow(
    Spoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(user);
    spoke.borrow(reserveId, amount, user);
  }

  // spoke
  function spokeSupply(
    LiquidityHub hub,
    Spoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(user);
    spoke.supply(reserveId, amount);
  }

  function setUsingAsCollateral(
    Spoke spoke,
    address user,
    uint256 reserveId,
    bool usingAsCollateral
  ) internal {
    vm.prank(user);
    spoke.setUsingAsCollateral(reserveId, usingAsCollateral);
  }

  function updateLiquidationThreshold(Spoke spoke, uint256 reserveId, uint256 newLt) internal {
    Spoke.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.lt = newLt;
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateCollateral(Spoke spoke, uint256 reserveId, bool newCollateral) internal {
    Spoke.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.collateral = newCollateral;
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateBorrowable(Spoke spoke, uint256 reserveId, bool newBorrowable) internal {
    Spoke.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.borrowable = newBorrowable;
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }
}
