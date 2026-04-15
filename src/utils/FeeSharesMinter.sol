// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Rescuable} from 'src/utils/Rescuable.sol';
import {IFeeSharesMinter} from 'src/utils/IFeeSharesMinter.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title FeeSharesMinter
/// @author Aave Labs
/// @notice Contract to mint fee shares on the Hub when specific conditions are met.
contract FeeSharesMinter is IFeeSharesMinter, Ownable2Step, Rescuable {
  mapping(address hub => mapping(uint256 assetId => uint16)) internal _minAccruedFeesPercent;

  /// @dev Constructor.
  /// @param owner The owner of the contract.
  constructor(address owner) Ownable(owner) {}

  /// @inheritdoc IFeeSharesMinter
  function setConfig(
    address hub,
    uint256 assetId,
    uint16 minAccruedFeesPercent
  ) external onlyOwner {
    require(
      minAccruedFeesPercent > 0 && minAccruedFeesPercent <= PercentageMath.PERCENTAGE_FACTOR,
      InvalidConfig()
    );
    _minAccruedFeesPercent[hub][assetId] = minAccruedFeesPercent;
    emit ConfigUpdated(hub, assetId, minAccruedFeesPercent);
  }

  /// @inheritdoc IFeeSharesMinter
  function performUpkeep(bytes calldata performData) external override {
    (address hub, uint256 assetId) = abi.decode(performData, (address, uint256));
    _performUpkeep(hub, assetId);
  }

  /// @inheritdoc IFeeSharesMinter
  function checkUpkeep(
    bytes calldata checkData
  ) external view override returns (bool, bytes memory) {
    (address hub, uint256 assetId) = abi.decode(checkData, (address, uint256));
    bool upkeepNeeded = _checkUpkeep(hub, assetId);
    bytes memory performData = checkData;
    return (upkeepNeeded, performData);
  }

  /// @inheritdoc IFeeSharesMinter
  function getConfig(address hub, uint256 assetId) external view returns (uint16) {
    return _minAccruedFeesPercent[hub][assetId];
  }

  /// @dev Internal function to execute fee share minting.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  function _performUpkeep(address hub, uint256 assetId) internal virtual {
    require(_checkUpkeep(hub, assetId), ConditionsNotMet());

    IHub(hub).mintFeeShares(assetId);
  }

  /// @dev Internal function to check execution conditions.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @return True if conditions are met, false otherwise.
  function _checkUpkeep(address hub, uint256 assetId) internal view virtual returns (bool) {
    uint16 minAccruedFeesPercent = _minAccruedFeesPercent[hub][assetId];
    if (minAccruedFeesPercent == 0) {
      return false;
    }

    IHub hubContract = IHub(hub);
    uint256 accruedFees = hubContract.getAssetAccruedFees(assetId);
    uint256 totalAddedAssets = hubContract.getAddedAssets(assetId);

    if (totalAddedAssets == 0) {
      return false;
    }
    if (PercentageMath.percentDivDown(accruedFees, totalAddedAssets) < minAccruedFeesPercent) {
      return false;
    }

    // Ensure at least 1 fee share would be minted
    uint256 expectedShares = hubContract.previewAddByAssets(assetId, accruedFees);

    return expectedShares > 0;
  }

  /// @inheritdoc Rescuable
  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }
}
