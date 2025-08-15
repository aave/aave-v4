// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {IHub} from 'src/interfaces/IHub.sol';

type ReserveData is uint256;

/*
  IHub hub; // 160 bits
  uint16 assetId; // 16 bits
  uint8 decimals; // 8 bits
  uint16 dynamicConfigKey; // 16 bits
  bool paused; // 1 bit (packed)
  bool frozen; // 1 bit (packed)
  bool borrowable; // 1 bit (packed)
  uint24 collateralRisk; // 24 bits
 */

library ReserveDataLib {
  using ReserveDataLib for *;

  uint256 constant HUB_OFFSET = 0;
  uint256 constant ASSET_ID_OFFSET = 160;
  uint256 constant DECIMALS_OFFSET = 160 + 16;
  uint256 constant DYNAMIC_CONFIG_KEY_OFFSET = 160 + 16 + 8;
  uint256 constant PAUSED_OFFSET = 160 + 16 + 8 + 16;
  uint256 constant FROZEN_OFFSET = 160 + 16 + 8 + 16 + 1;
  uint256 constant BORROWABLE_OFFSET = 160 + 16 + 8 + 16 + 1 + 1;
  uint256 constant COLLATERAL_RISK_OFFSET = 160 + 16 + 8 + 16 + 1 + 1 + 1;

  uint256 constant HUB_MASK = type(uint256).max >> (256 - 160);
  uint256 constant ASSET_ID_MASK = (type(uint256).max >> (256 - 16)) << ASSET_ID_OFFSET;
  uint256 constant DECIMALS_MASK = (type(uint256).max >> (256 - 8)) << DECIMALS_OFFSET;
  uint256 constant DYNAMIC_CONFIG_KEY_MASK =
    (type(uint256).max >> (256 - 16)) << DYNAMIC_CONFIG_KEY_OFFSET;
  uint256 constant PAUSED_MASK = (type(uint256).max >> (256 - 1)) << PAUSED_OFFSET;
  uint256 constant FROZEN_MASK = (type(uint256).max >> (256 - 1)) << FROZEN_OFFSET;
  uint256 constant BORROWABLE_MASK = (type(uint256).max >> (256 - 1)) << BORROWABLE_OFFSET;
  uint256 constant COLLATERAL_RISK_MASK =
    (type(uint256).max >> (256 - 24)) << COLLATERAL_RISK_OFFSET;

  function hub(ReserveData data) internal pure returns (IHub) {
    return IHub(address(uint160(ReserveData.unwrap(data) & HUB_MASK)));
  }

  function assetId(ReserveData data) internal pure returns (uint16) {
    return uint16((ReserveData.unwrap(data) & ASSET_ID_MASK) >> ASSET_ID_OFFSET);
  }

  function decimals(ReserveData data) internal pure returns (uint8) {
    return uint8((ReserveData.unwrap(data) & DECIMALS_MASK) >> DECIMALS_OFFSET);
  }

  function dynamicConfigKey(ReserveData data) internal pure returns (uint16) {
    return
      uint16((ReserveData.unwrap(data) & DYNAMIC_CONFIG_KEY_MASK) >> DYNAMIC_CONFIG_KEY_OFFSET);
  }

  function paused(ReserveData data) internal pure returns (bool) {
    return (ReserveData.unwrap(data) & PAUSED_MASK) != 0;
  }

  function frozen(ReserveData data) internal pure returns (bool) {
    return (ReserveData.unwrap(data) & FROZEN_MASK) != 0;
  }

  function borrowable(ReserveData data) internal pure returns (bool) {
    return (ReserveData.unwrap(data) & BORROWABLE_MASK) != 0;
  }

  function collateralRisk(ReserveData data) internal pure returns (uint24) {
    return uint24((ReserveData.unwrap(data) & COLLATERAL_RISK_MASK) >> COLLATERAL_RISK_OFFSET);
  }

  function init(
    address hub_,
    uint16 assetId_,
    uint8 decimals_,
    uint16 dynamicConfigKey_,
    DataTypes.ReserveConfig calldata config_
  ) internal pure returns (ReserveData) {
    return
      ReserveData
        .wrap(0)
        .setHub(hub_)
        .setAssetId(assetId_)
        .setDecimals(decimals_)
        .setDynamicConfigKey(dynamicConfigKey_)
        .setReserveConfig(config_);
  }

  function setHub(ReserveData data, address hub_) internal pure returns (ReserveData) {
    return
      ReserveData.wrap(
        (ReserveData.unwrap(data) & ~HUB_MASK) | (uint256(uint160(hub_)) << HUB_OFFSET)
      );
  }

  function setAssetId(ReserveData data, uint16 assetId_) internal pure returns (ReserveData) {
    return
      ReserveData.wrap(
        (ReserveData.unwrap(data) & ~ASSET_ID_MASK) | (uint256(assetId_) << ASSET_ID_OFFSET)
      );
  }

  function setDecimals(ReserveData data, uint8 decimals_) internal pure returns (ReserveData) {
    return
      ReserveData.wrap(
        (ReserveData.unwrap(data) & ~DECIMALS_MASK) | (uint256(decimals_) << DECIMALS_OFFSET)
      );
  }

  function setDynamicConfigKey(
    ReserveData data,
    uint16 dynamicConfigKey_
  ) internal pure returns (ReserveData) {
    return
      ReserveData.wrap(
        (ReserveData.unwrap(data) & ~DYNAMIC_CONFIG_KEY_MASK) |
          (uint256(dynamicConfigKey_) << DYNAMIC_CONFIG_KEY_OFFSET)
      );
  }

  function setReserveConfig(
    ReserveData data,
    DataTypes.ReserveConfig calldata config
  ) internal pure returns (ReserveData) {
    return
      data
        .setPaused(config.paused)
        .setFrozen(config.frozen)
        .setBorrowable(config.borrowable)
        .setCollateralRisk(config.collateralRisk);
  }

  function setPaused(ReserveData data, bool paused_) internal pure returns (ReserveData) {
    return
      ReserveData.wrap(
        (ReserveData.unwrap(data) & ~PAUSED_MASK) | (paused_.toUint() << PAUSED_OFFSET)
      );
  }

  function setFrozen(ReserveData data, bool frozen_) internal pure returns (ReserveData) {
    return
      ReserveData.wrap(
        (ReserveData.unwrap(data) & ~FROZEN_MASK) | (frozen_.toUint() << FROZEN_OFFSET)
      );
  }

  function setBorrowable(ReserveData data, bool borrowable_) internal pure returns (ReserveData) {
    return
      ReserveData.wrap(
        (ReserveData.unwrap(data) & ~BORROWABLE_MASK) | (borrowable_.toUint() << BORROWABLE_OFFSET)
      );
  }

  function setCollateralRisk(
    ReserveData data,
    uint24 collateralRisk_
  ) internal pure returns (ReserveData) {
    return
      ReserveData.wrap(
        (ReserveData.unwrap(data) & ~COLLATERAL_RISK_MASK) |
          (uint256(collateralRisk_) << COLLATERAL_RISK_OFFSET)
      );
  }

  function reserve(ReserveData data) internal pure returns (DataTypes.Reserve memory) {
    return
      DataTypes.Reserve({
        hub: data.hub(),
        assetId: data.assetId(),
        decimals: data.decimals(),
        dynamicConfigKey: data.dynamicConfigKey(),
        paused: data.paused(),
        frozen: data.frozen(),
        borrowable: data.borrowable(),
        collateralRisk: data.collateralRisk()
      });
  }

  function reserveConfig(ReserveData data) internal pure returns (DataTypes.ReserveConfig memory) {
    return
      DataTypes.ReserveConfig({
        paused: data.paused(),
        frozen: data.frozen(),
        borrowable: data.borrowable(),
        collateralRisk: data.collateralRisk()
      });
  }

  function toUint(bool value) internal pure returns (uint256 ret) {
    assembly ('memory-safe') {
      ret := iszero(iszero(value))
    }
  }
}
