// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {Constants} from 'src/libraries/helpers/Constants.sol';
import {IHub} from 'src/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/interfaces/IHubConfigurator.sol';

/**
 * @title HubConfigurator
 * @author Aave Labs
 * @notice HubConfigurator contract for the Aave protocol
 * @dev Must be granted permission by the Hub
 */
contract HubConfigurator is Ownable, IHubConfigurator {
  using SafeCast for uint256;

  /**
   * @dev Constructor
   * @param owner_ The address of the owner
   */
  constructor(address owner_) Ownable(owner_) {}

  /// @inheritdoc IHubConfigurator
  function addAsset(
    address hub,
    address underlying,
    address feeReceiver,
    address irStrategy,
    bytes calldata data
  ) external override onlyOwner returns (uint256) {
    IHub targetHub = IHub(hub);

    uint256 assetId = targetHub.addAsset(
      underlying,
      IERC20Metadata(underlying).decimals(),
      feeReceiver,
      irStrategy,
      data
    );

    targetHub.addSpoke(
      assetId,
      feeReceiver,
      DataTypes.SpokeConfig({addCap: Constants.MAX_CAP, drawCap: Constants.MAX_CAP, active: true})
    );

    return assetId;
  }

  /// @inheritdoc IHubConfigurator
  function addAsset(
    address hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata data
  ) external override onlyOwner returns (uint256) {
    IHub targetHub = IHub(hub);

    uint256 assetId = targetHub.addAsset(underlying, decimals, feeReceiver, irStrategy, data);

    targetHub.addSpoke(
      assetId,
      feeReceiver,
      DataTypes.SpokeConfig({addCap: Constants.MAX_CAP, drawCap: Constants.MAX_CAP, active: true})
    );

    return assetId;
  }

  /// @inheritdoc IHubConfigurator
  function updateLiquidityFee(
    address hub,
    uint256 assetId,
    uint256 liquidityFee
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee.toUint16();
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeReceiver(
    address hub,
    uint256 assetId,
    address feeReceiver
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    _updateFeeReceiverSpokeConfig(targetHub, assetId, config.feeReceiver, feeReceiver);
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateFeeConfig(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    _updateFeeReceiverSpokeConfig(targetHub, assetId, config.feeReceiver, feeReceiver);
    config.liquidityFee = liquidityFee.toUint16();
    config.feeReceiver = feeReceiver;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    DataTypes.AssetConfig memory config = targetHub.getAssetConfig(assetId);
    config.irStrategy = irStrategy;
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateAssetConfig(
    address hub,
    uint256 assetId,
    DataTypes.AssetConfig calldata config
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    _updateFeeReceiverSpokeConfig(
      targetHub,
      assetId,
      targetHub.getAssetConfig(assetId).feeReceiver,
      config.feeReceiver
    );
    targetHub.updateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHubConfigurator
  function freezeAsset(address hub, uint256 assetId) external override onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokesCount; ++i) {
      address spokeAddress = targetHub.getSpokeAddress(assetId, i);
      _updateSpokeCaps(targetHub, assetId, spokeAddress, 0, 0);
    }
  }

  /// @inheritdoc IHubConfigurator
  function pauseAsset(address hub, uint256 assetId) external override onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 spokesCount = targetHub.getSpokeCount(assetId);
    for (uint256 i = 0; i < spokesCount; ++i) {
      address spokeAddress = targetHub.getSpokeAddress(assetId, i);
      DataTypes.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spokeAddress);
      config.active = false;
      targetHub.updateSpokeConfig(assetId, spokeAddress, config);
    }
  }

  /// @inheritdoc IHubConfigurator
  function addSpoke(
    address hub,
    address spoke,
    uint256 assetId,
    DataTypes.SpokeConfig calldata config
  ) external onlyOwner {
    IHub(hub).addSpoke(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function addSpokeToAssets(
    address hub,
    address spoke,
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] calldata configs
  ) external onlyOwner {
    require(assetIds.length == configs.length, MismatchedConfigs());
    for (uint256 i = 0; i < assetIds.length; ++i) {
      IHub(hub).addSpoke(assetIds[i], spoke, configs[i]);
    }
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeActive(
    address hub,
    uint256 assetId,
    address spoke,
    bool active
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    DataTypes.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    config.active = active;
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeSupplyCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    DataTypes.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    config.addCap = addCap.toUint56();
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeDrawCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 drawCap
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    DataTypes.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
    config.drawCap = drawCap.toUint56();
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeCaps(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) external override onlyOwner {
    _updateSpokeCaps(IHub(hub), assetId, spoke, addCap, drawCap);
  }

  /// @inheritdoc IHubConfigurator
  function updateSpokeConfig(
    address hub,
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external override onlyOwner {
    IHub targetHub = IHub(hub);
    targetHub.updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHubConfigurator
  function pauseSpoke(address hub, address spoke) external override onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 assetId = 0; assetId < assetCount; ++assetId) {
      if (targetHub.isSpokeListed(assetId, spoke)) {
        DataTypes.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
        config.active = false;
        targetHub.updateSpokeConfig(assetId, spoke, config);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function freezeSpoke(address hub, address spoke) external override onlyOwner {
    IHub targetHub = IHub(hub);
    uint256 assetCount = targetHub.getAssetCount();
    for (uint256 assetId = 0; assetId < assetCount; ++assetId) {
      if (targetHub.isSpokeListed(assetId, spoke)) {
        _updateSpokeCaps(targetHub, assetId, spoke, 0, 0);
      }
    }
  }

  /// @inheritdoc IHubConfigurator
  function updateInterestRateData(
    address hub,
    uint256 assetId,
    bytes calldata data
  ) external override onlyOwner {
    IHub(hub).setInterestRateData(assetId, data);
  }

  /**
   * @dev Updates the spoke configs for the old and new fee receivers.
   *  - updates the caps for the old fee receiver to 0.
   *  - if new fee receiver is not already a spoke, it adds it with max caps and active flag set to true.
   *  - if new fee receiver is already a spoke, it updates the caps to max, without changing the active flag.
   * @dev If the old and new fee receivers are the same, it does nothing.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param oldFeeReceiver The old fee receiver.
   * @param newFeeReceiver The new fee receiver.
   */
  function _updateFeeReceiverSpokeConfig(
    IHub hub,
    uint256 assetId,
    address oldFeeReceiver,
    address newFeeReceiver
  ) internal {
    if (oldFeeReceiver == newFeeReceiver) {
      return;
    }

    _updateSpokeCaps(hub, assetId, oldFeeReceiver, 0, 0);

    if (!hub.isSpokeListed(assetId, newFeeReceiver)) {
      hub.addSpoke(
        assetId,
        newFeeReceiver,
        DataTypes.SpokeConfig({addCap: Constants.MAX_CAP, drawCap: Constants.MAX_CAP, active: true})
      );
    } else {
      _updateSpokeCaps(hub, assetId, newFeeReceiver, Constants.MAX_CAP, Constants.MAX_CAP);
    }
  }

  /**
   * @dev Updates the spoke caps, without changing the active flag.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @param addCap The new add cap.
   * @param drawCap The new draw cap.
   */
  function _updateSpokeCaps(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) internal {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(assetId, spoke);
    config.addCap = addCap.toUint56();
    config.drawCap = drawCap.toUint56();
    hub.updateSpokeConfig(assetId, spoke, config);
  }
}
