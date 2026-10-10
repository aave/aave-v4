// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {IERC165} from 'src/dependencies/openzeppelin/IERC165.sol';
import {IReceiver} from 'src/dependencies/chainlink/IReceiver.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Rescuable} from 'src/utils/Rescuable.sol';
import {IFeeSharesMinter} from 'src/utils/IFeeSharesMinter.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title FeeSharesMinter
/// @author Aave Labs
/// @notice Contract that receives signed CRE reports and mints Hub fee shares when conditions are met.
contract FeeSharesMinter is IFeeSharesMinter, Ownable2Step, Rescuable {
  using PercentageMath for uint256;

  mapping(address hub => mapping(uint256 assetId => uint16)) internal _minAccruedFeesPercent;
  mapping(bytes32 workflowId => WorkflowConfig) internal _workflowConfigs;

  constructor(address owner) Ownable(owner) {}

  /// @inheritdoc IFeeSharesMinter
  function setConfig(
    address hub,
    uint256 assetId,
    uint16 minAccruedFeesPercent
  ) external onlyOwner {
    require(
      minAccruedFeesPercent <= PercentageMath.PERCENTAGE_FACTOR,
      InvalidConfig(minAccruedFeesPercent)
    );
    require(assetId < IHub(hub).getAssetCount(), IHub.AssetNotListed());
    _minAccruedFeesPercent[hub][assetId] = minAccruedFeesPercent;
    emit ConfigUpdated(hub, assetId, minAccruedFeesPercent);
  }

  /// @inheritdoc IFeeSharesMinter
  function setWorkflowConfig(
    bytes32 workflowId,
    WorkflowConfig calldata config
  ) external onlyOwner {
    _workflowConfigs[workflowId] = config;
    emit WorkflowConfigUpdated(
      workflowId,
      config.forwarder,
      config.owner,
      config.name,
      config.isActive
    );
  }

  /// @dev `report` must be abi-encoded as `(address hub, uint256 assetId)`.
  /// @inheritdoc IReceiver
  function onReport(bytes calldata metadata, bytes calldata report) external override {
    _validateWorkflow(metadata);
    (address hub, uint256 assetId) = abi.decode(report, (address, uint256));
    require(_canMint(hub, assetId), ConditionsNotMet());
    IHub(hub).mintFeeShares(assetId);
  }

  /// @inheritdoc IFeeSharesMinter
  function getConfig(address hub, uint256 assetId) external view returns (uint16) {
    return _minAccruedFeesPercent[hub][assetId];
  }

  /// @inheritdoc IFeeSharesMinter
  function getWorkflowConfig(bytes32 workflowId) external view returns (WorkflowConfig memory) {
    return _workflowConfigs[workflowId];
  }

  /// @inheritdoc IFeeSharesMinter
  function canMint(address hub, uint256 assetId) external view returns (bool) {
    return _canMint(hub, assetId);
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return interfaceId == type(IReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function _validateWorkflow(bytes calldata metadata) internal view virtual {
    (bytes32 workflowId, bytes10 workflowName, address workflowOwner) = _decodeMetadata(metadata);
    WorkflowConfig storage config = _workflowConfigs[workflowId];

    require(config.isActive, WorkflowNotActive(workflowId));
    require(msg.sender == config.forwarder, InvalidWorkflowForwarder(msg.sender, config.forwarder));
    require(workflowOwner == config.owner, InvalidWorkflowOwner(workflowOwner, config.owner));
    require(workflowName == config.name, InvalidWorkflowName(workflowName, config.name));
  }

  function _canMint(address hub, uint256 assetId) internal view virtual returns (bool) {
    uint16 minAccruedFeesPercent = _minAccruedFeesPercent[hub][assetId];
    if (minAccruedFeesPercent == 0) {
      return false;
    }

    IHub targetHub = IHub(hub);
    uint256 accruedFees = targetHub.getAssetAccruedFees(assetId);
    uint256 totalAddedAssets = targetHub.getAddedAssets(assetId);

    if (totalAddedAssets == 0) {
      return false;
    }
    if (accruedFees.percentDivDown(totalAddedAssets) < minAccruedFeesPercent) {
      return false;
    }

    return targetHub.previewAddByAssets(assetId, accruedFees) > 0;
  }

  /// @inheritdoc Rescuable
  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }

  function _decodeMetadata(
    bytes memory metadata
  ) internal pure returns (bytes32 workflowId, bytes10 workflowName, address workflowOwner) {
    assembly {
      workflowId := mload(add(metadata, 32))
      workflowName := mload(add(metadata, 64))
      workflowOwner := shr(96, mload(add(metadata, 74)))
    }
    return (workflowId, workflowName, workflowOwner);
  }
}
