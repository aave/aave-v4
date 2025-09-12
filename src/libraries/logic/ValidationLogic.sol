// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {Constants} from 'src/libraries/helpers/Constants.sol';
import {IHub} from 'src/interfaces/IHub.sol';

/**
 * @title ValidationLogic library
 * @author Aave Labs
 * @notice Implements functions to validate the different actions of the protocol
 */
library ValidationLogic {
  /**
   * @notice Validates the parameters for an add action to the hub.
   * @param asset The data of the asset being added.
   * @param spoke The data of the spoke performing the add.
   * @param assetId The identifier of the asset.
   * @param amount The amount being added.
   * @param from The address initiating the add action.
   * @param hubAddress The address of the hub contract where the asset is being added.
   */
  function validateAdd(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 assetId,
    uint256 amount,
    address from,
    address hubAddress
  ) internal view {
    IHub hub = IHub(hubAddress);
    require(from != hubAddress, IHub.InvalidAddress());
    require(amount > 0, IHub.InvalidAmount());
    require(spoke.active, IHub.SpokeNotActive());
    uint256 addCap = spoke.addCap;
    require(
      addCap == Constants.MAX_CAP ||
        addCap * 10 ** asset.decimals >=
        hub.previewAddByShares(assetId, spoke.addedShares) + amount,
      IHub.AddCapExceeded(addCap)
    );
  }

  /**
   * @notice Validates the parameters for a remove action on the hub.
   * @param spoke The data of the spoke performing the remove.
   * @param assetId The identifier of the asset.
   * @param amount The amount being removed.
   * @param to The address receiving the removed assets.
   * @param hubAddress The address of the hub contract where the asset is being removed.
   */
  function validateRemove(
    DataTypes.SpokeData storage spoke,
    uint256 assetId,
    uint256 amount,
    address to,
    address hubAddress
  ) internal view {
    IHub hub = IHub(hubAddress);
    require(to != hubAddress, IHub.InvalidAddress());
    require(amount > 0, IHub.InvalidAmount());
    require(spoke.active, IHub.SpokeNotActive());
    uint256 removable = hub.previewRemoveByShares(assetId, spoke.addedShares);
    require(amount <= removable, IHub.AddedAmountExceeded(removable));
  }

  /**
   * @notice Validates the parameters for a draw action on the hub.
   * @param asset The data of the asset being drawn.
   * @param spoke The data of the spoke performing the draw.
   * @param assetId The identifier of the asset.
   * @param amount The amount being drawn.
   * @param to The address receiving the drawn assets.
   * @param hubAddress The address of the hub contract where the asset is being drawn from.
   * @param spokeAddress The address of the spoke performing the draw.
   */
  function validateDraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 assetId,
    uint256 amount,
    address to,
    address hubAddress,
    address spokeAddress
  ) internal view {
    IHub hub = IHub(hubAddress);
    require(to != hubAddress, IHub.InvalidAddress());
    require(amount > 0, IHub.InvalidAmount());
    require(spoke.active, IHub.SpokeNotActive());
    uint256 drawCap = spoke.drawCap;
    uint256 totalOwed = hub.getSpokeTotalOwed(assetId, spokeAddress);
    require(
      drawCap == Constants.MAX_CAP || drawCap * 10 ** asset.decimals >= totalOwed + amount,
      IHub.DrawCapExceeded(drawCap)
    );
  }
}
