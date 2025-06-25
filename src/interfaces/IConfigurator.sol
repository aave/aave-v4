// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title IConfigurator
 * @author Aave Labs
 * @notice Interface for the Configurator
 * @dev Must be granted permission by the Hub and Spoke
 */
interface IConfigurator {
  /**
   * @notice Thrown when the the list of assets and spoke configs are not the same length in `addSpokes`.
   */
  error MismatchedConfigs();

  /**
   * @notice Registers the same spoke for multiple assets with the hub, each with their own configuration.
   * @param hub The address of the Hub contract.
   * @param assetIds The list of asset ids to register the spoke for.
   * @param spoke The address of the Spoke contract.
   * @param configs The list of Spoke configurations to register.
   * @dev The i-th asset id in `assetIds` corresponds to the i-th configuration in `configs`.
   */
  function addSpokes(
    address hub,
    uint256[] calldata assetIds,
    address spoke,
    DataTypes.SpokeConfig[] memory configs
  ) external;

  /**
   * @notice Registers an asset with the hub
   * @param hub The address of the Hub contract.
   * @param asset The address of the asset.
   * @param irStrategy The address of the interest rate strategy contract.
   * @return The id of the registered asset.
   @ @dev The number of decimals of the asset is fetched from the asset ERC20 contract.
   */
  function addAsset(address hub, address asset, address irStrategy) external returns (uint256);

  /**
   * @notice Registers an asset with the hub, with the specified number of decimals
   * @param hub The address of the Hub contract.
   * @param asset The address of the asset.
   * @param decimals The number of decimals of the asset.
   * @param irStrategy The address of the interest rate strategy contract.
   * @return The id of the registered asset.
   */
  function addAsset(
    address hub,
    address asset,
    uint8 decimals,
    address irStrategy
  ) external returns (uint256);

  /**
   * @notice Sets the active flag of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The id of the asset.
   * @param active The new active flag.
   */
  function setActive(address hub, uint256 assetId, bool active) external;

  /**
   * @notice Sets the paused flag of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The id of the asset.
   * @param paused The new paused flag.
   */
  function setPaused(address hub, uint256 assetId, bool paused) external;

  /**
   * @notice Sets the frozen flag of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The id of the asset.
   * @param frozen The new frozen flag.
   */
  function setFrozen(address hub, uint256 assetId, bool frozen) external;

  /**
   * @notice Sets the liquidity fee of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The id of the asset.
   * @param liquidityFee The new liquidity fee.
   */
  function setLiquidityFee(address hub, uint256 assetId, uint256 liquidityFee) external;

  /**
   * @notice Sets the fee receiver of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The id of the asset.
   * @param feeReceiver The new fee receiver.
   * @dev Before updating the fee receiver, it adjusts the spoke config of the old and new fee receivers.
   */
  function setFeeReceiver(address hub, uint256 assetId, address feeReceiver) external;

  /**
   * @notice Sets the liquidity fee and fee receiver of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The id of the asset.
   * @param liquidityFee The new liquidity fee.
   * @param feeReceiver The new fee receiver.
   * @dev Before updating the fee receiver, it adjusts the spoke config of the old and new fee receivers.
   */
  function setLiquidityFeeAndReceiver(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external;

  /**
   * @notice Sets the interest rate strategy of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The id of the asset.
   * @param irStrategy The new interest rate strategy.
   */
  function setInterestRateStrategy(address hub, uint256 assetId, address irStrategy) external;
}
