// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IFeeSharesMinter} from 'src/utils/IFeeSharesMinter.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title FeeSharesMinterEngine
/// @author Aave Labs
/// @notice Library containing FeeSharesMinter configuration logic for AaveV4ConfigEngine.
library FeeSharesMinterEngine {
  /// @notice Sets per-asset minimum accrued fees percent on FeeSharesMinters.
  /// @param configs The per-asset FeeSharesMinter configs to execute.
  function executeFeeSharesMinterConfigs(
    IAaveV4ConfigEngine.FeeSharesMinterConfig[] calldata configs
  ) external {
    uint256 length = configs.length;
    for (uint256 i; i < length; ++i) {
      IFeeSharesMinter(configs[i].feeSharesMinter).setConfig(
        configs[i].hub,
        configs[i].assetId,
        configs[i].minAccruedFeesPercent
      );
    }
  }

  /// @notice Sets the minimum accrued fees percent on FeeSharesMinters for every asset currently
  /// listed on each Hub.
  /// @param configs The hub-wide FeeSharesMinter configs to execute.
  function executeFeeSharesMinterHubConfigs(
    IAaveV4ConfigEngine.FeeSharesMinterHubConfig[] calldata configs
  ) external {
    uint256 length = configs.length;
    for (uint256 i; i < length; ++i) {
      uint256 assetCount = IHub(configs[i].hub).getAssetCount();
      for (uint256 assetId; assetId < assetCount; ++assetId) {
        IFeeSharesMinter(configs[i].feeSharesMinter).setConfig(
          configs[i].hub,
          assetId,
          configs[i].minAccruedFeesPercent
        );
      }
    }
  }

  /// @notice Registers or updates workflow authorizations on FeeSharesMinters.
  /// @param configs The FeeSharesMinter workflow configs to execute.
  function executeFeeSharesMinterWorkflowConfigs(
    IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig[] calldata configs
  ) external {
    uint256 length = configs.length;
    for (uint256 i; i < length; ++i) {
      IFeeSharesMinter(configs[i].feeSharesMinter).setWorkflowConfig(
        configs[i].workflowId,
        configs[i].config
      );
    }
  }
}
