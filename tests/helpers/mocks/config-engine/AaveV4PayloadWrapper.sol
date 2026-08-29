// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

contract AaveV4PayloadWrapper is AaveV4Payload {
  bool public constant IS_TEST = true;

  // Hook tracking
  bool public preExecuteCalled;
  bool public postExecuteCalled;
  uint256 public preExecuteOrder;
  uint256 public postExecuteOrder;
  uint256 private _callCounter;

  // Hub action storage
  IAaveV4ConfigEngine.AssetListing[] private _hubAssetListings;
  IAaveV4ConfigEngine.AssetConfigUpdate[] private _hubAssetConfigUpdates;
  bytes private _hubSpokeToAssetsAdditionsEncoded;
  IAaveV4ConfigEngine.SpokeConfigUpdate[] private _hubSpokeConfigUpdates;
  IAaveV4ConfigEngine.AssetHalt[] private _hubAssetHalts;
  IAaveV4ConfigEngine.AssetDeactivation[] private _hubAssetDeactivations;
  IAaveV4ConfigEngine.AssetCapsReset[] private _hubAssetCapsResets;
  IAaveV4ConfigEngine.SpokeDeactivation[] private _hubSpokeDeactivations;
  IAaveV4ConfigEngine.SpokeCapsReset[] private _hubSpokeCapsResets;

  // Spoke action storage
  IAaveV4ConfigEngine.ReserveListing[] private _spokeReserveListings;
  IAaveV4ConfigEngine.ReserveConfigUpdate[] private _spokeReserveConfigUpdates;
  IAaveV4ConfigEngine.LiquidationConfigUpdate[] private _spokeLiquidationConfigUpdates;
  IAaveV4ConfigEngine.DynamicReserveConfigAddition[] private _spokeDynamicReserveConfigAdditions;
  IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] private _spokeDynamicReserveConfigUpdates;
  IAaveV4ConfigEngine.PositionManagerUpdate[] private _spokePositionManagerUpdates;

  // Position manager action storage
  IAaveV4ConfigEngine.SpokeRegistration[] private _positionManagerSpokeRegistrations;
  IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] private _positionManagerRoleRenouncements;

  // Access manager action storage
  IAaveV4ConfigEngine.RoleMembership[] private _accessManagerRoleMemberships;
  bytes private _accessManagerRoleUpdatesEncoded;
  IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] private _accessManagerTargetFunctionRoleUpdates;
  IAaveV4ConfigEngine.TargetAdminDelayUpdate[] private _accessManagerTargetAdminDelayUpdates;

  // FeeSharesMinter action storage
  IAaveV4ConfigEngine.FeeSharesMinterConfig[] private _feeSharesMinterConfigs;
  IAaveV4ConfigEngine.FeeSharesMinterHubConfig[] private _feeSharesMinterHubConfigs;
  IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig[] private _feeSharesMinterWorkflowConfigs;

  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}

  // Hook overrides
  function _preExecute() internal override {
    preExecuteCalled = true;
    preExecuteOrder = ++_callCounter;
  }

  function _postExecute() internal override {
    postExecuteCalled = true;
    postExecuteOrder = ++_callCounter;
  }

  // Hub setters
  function setHubAssetListings(IAaveV4ConfigEngine.AssetListing[] memory items) external {
    delete _hubAssetListings;
    for (uint256 i = 0; i < items.length; i++) {
      _hubAssetListings.push(items[i]);
    }
  }

  function setHubAssetConfigUpdates(IAaveV4ConfigEngine.AssetConfigUpdate[] memory items) external {
    delete _hubAssetConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _hubAssetConfigUpdates.push(items[i]);
    }
  }

  function setHubSpokeToAssetsAdditions(
    IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory items
  ) external {
    _hubSpokeToAssetsAdditionsEncoded = abi.encode(items);
  }

  function setHubSpokeConfigUpdates(IAaveV4ConfigEngine.SpokeConfigUpdate[] memory items) external {
    delete _hubSpokeConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _hubSpokeConfigUpdates.push(items[i]);
    }
  }

  function setHubAssetHalts(IAaveV4ConfigEngine.AssetHalt[] memory items) external {
    delete _hubAssetHalts;
    for (uint256 i = 0; i < items.length; i++) {
      _hubAssetHalts.push(items[i]);
    }
  }

  function setHubAssetDeactivations(IAaveV4ConfigEngine.AssetDeactivation[] memory items) external {
    delete _hubAssetDeactivations;
    for (uint256 i = 0; i < items.length; i++) {
      _hubAssetDeactivations.push(items[i]);
    }
  }

  function setHubAssetCapsResets(IAaveV4ConfigEngine.AssetCapsReset[] memory items) external {
    delete _hubAssetCapsResets;
    for (uint256 i = 0; i < items.length; i++) {
      _hubAssetCapsResets.push(items[i]);
    }
  }

  function setHubSpokeDeactivations(IAaveV4ConfigEngine.SpokeDeactivation[] memory items) external {
    delete _hubSpokeDeactivations;
    for (uint256 i = 0; i < items.length; i++) {
      _hubSpokeDeactivations.push(items[i]);
    }
  }

  function setHubSpokeCapsResets(IAaveV4ConfigEngine.SpokeCapsReset[] memory items) external {
    delete _hubSpokeCapsResets;
    for (uint256 i = 0; i < items.length; i++) {
      _hubSpokeCapsResets.push(items[i]);
    }
  }

  // Spoke setters
  function setSpokeReserveListings(IAaveV4ConfigEngine.ReserveListing[] memory items) external {
    delete _spokeReserveListings;
    for (uint256 i = 0; i < items.length; i++) {
      _spokeReserveListings.push(items[i]);
    }
  }

  function setSpokeReserveConfigUpdates(
    IAaveV4ConfigEngine.ReserveConfigUpdate[] memory items
  ) external {
    delete _spokeReserveConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _spokeReserveConfigUpdates.push(items[i]);
    }
  }

  function setSpokeLiquidationConfigUpdates(
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory items
  ) external {
    delete _spokeLiquidationConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _spokeLiquidationConfigUpdates.push(items[i]);
    }
  }

  function setSpokeDynamicReserveConfigAdditions(
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory items
  ) external {
    delete _spokeDynamicReserveConfigAdditions;
    for (uint256 i = 0; i < items.length; i++) {
      _spokeDynamicReserveConfigAdditions.push(items[i]);
    }
  }

  function setSpokeDynamicReserveConfigUpdates(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory items
  ) external {
    delete _spokeDynamicReserveConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _spokeDynamicReserveConfigUpdates.push(items[i]);
    }
  }

  function setSpokePositionManagerUpdates(
    IAaveV4ConfigEngine.PositionManagerUpdate[] memory items
  ) external {
    delete _spokePositionManagerUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _spokePositionManagerUpdates.push(items[i]);
    }
  }

  // Position manager setters
  function setPositionManagerSpokeRegistrations(
    IAaveV4ConfigEngine.SpokeRegistration[] memory items
  ) external {
    delete _positionManagerSpokeRegistrations;
    for (uint256 i = 0; i < items.length; i++) {
      _positionManagerSpokeRegistrations.push(items[i]);
    }
  }

  function setPositionManagerRoleRenouncements(
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] memory items
  ) external {
    delete _positionManagerRoleRenouncements;
    for (uint256 i = 0; i < items.length; i++) {
      _positionManagerRoleRenouncements.push(items[i]);
    }
  }

  // Access manager setters
  function setAccessManagerRoleMemberships(
    IAaveV4ConfigEngine.RoleMembership[] memory items
  ) external {
    delete _accessManagerRoleMemberships;
    for (uint256 i = 0; i < items.length; i++) {
      _accessManagerRoleMemberships.push(items[i]);
    }
  }

  function setAccessManagerRoleUpdates(IAaveV4ConfigEngine.RoleUpdate[] memory items) external {
    _accessManagerRoleUpdatesEncoded = abi.encode(items);
  }

  function setAccessManagerTargetFunctionRoleUpdates(
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory items
  ) external {
    delete _accessManagerTargetFunctionRoleUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _accessManagerTargetFunctionRoleUpdates.push(items[i]);
    }
  }

  function setAccessManagerTargetAdminDelayUpdates(
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory items
  ) external {
    delete _accessManagerTargetAdminDelayUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _accessManagerTargetAdminDelayUpdates.push(items[i]);
    }
  }

  // FeeSharesMinter setters
  function setFeeSharesMinterConfigs(
    IAaveV4ConfigEngine.FeeSharesMinterConfig[] memory items
  ) external {
    delete _feeSharesMinterConfigs;
    for (uint256 i = 0; i < items.length; i++) {
      _feeSharesMinterConfigs.push(items[i]);
    }
  }

  function setFeeSharesMinterHubConfigs(
    IAaveV4ConfigEngine.FeeSharesMinterHubConfig[] memory items
  ) external {
    delete _feeSharesMinterHubConfigs;
    for (uint256 i = 0; i < items.length; i++) {
      _feeSharesMinterHubConfigs.push(items[i]);
    }
  }

  function setFeeSharesMinterWorkflowConfigs(
    IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig[] memory items
  ) external {
    delete _feeSharesMinterWorkflowConfigs;
    for (uint256 i = 0; i < items.length; i++) {
      _feeSharesMinterWorkflowConfigs.push(items[i]);
    }
  }

  function hubAssetListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetListing[] memory)
  {
    return _hubAssetListings;
  }

  function hubAssetConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetConfigUpdate[] memory)
  {
    return _hubAssetConfigUpdates;
  }

  function hubSpokeToAssetsAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory)
  {
    if (_hubSpokeToAssetsAdditionsEncoded.length == 0) {
      return new IAaveV4ConfigEngine.SpokeToAssetsAddition[](0);
    }
    return
      abi.decode(_hubSpokeToAssetsAdditionsEncoded, (IAaveV4ConfigEngine.SpokeToAssetsAddition[]));
  }

  function hubSpokeConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeConfigUpdate[] memory)
  {
    return _hubSpokeConfigUpdates;
  }

  function hubAssetHalts() public view override returns (IAaveV4ConfigEngine.AssetHalt[] memory) {
    return _hubAssetHalts;
  }

  function hubAssetDeactivations()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetDeactivation[] memory)
  {
    return _hubAssetDeactivations;
  }

  function hubAssetCapsResets()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetCapsReset[] memory)
  {
    return _hubAssetCapsResets;
  }

  function hubSpokeDeactivations()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeDeactivation[] memory)
  {
    return _hubSpokeDeactivations;
  }

  function hubSpokeCapsResets()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeCapsReset[] memory)
  {
    return _hubSpokeCapsResets;
  }

  function spokeReserveListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReserveListing[] memory)
  {
    return _spokeReserveListings;
  }

  function spokeReserveConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory)
  {
    return _spokeReserveConfigUpdates;
  }

  function spokeLiquidationConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory)
  {
    return _spokeLiquidationConfigUpdates;
  }

  function spokeDynamicReserveConfigAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory)
  {
    return _spokeDynamicReserveConfigAdditions;
  }

  function spokeDynamicReserveConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory)
  {
    return _spokeDynamicReserveConfigUpdates;
  }

  function spokePositionManagerUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory)
  {
    return _spokePositionManagerUpdates;
  }

  function accessManagerRoleMemberships()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleMembership[] memory)
  {
    return _accessManagerRoleMemberships;
  }

  function accessManagerRoleUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleUpdate[] memory)
  {
    if (_accessManagerRoleUpdatesEncoded.length == 0) {
      return new IAaveV4ConfigEngine.RoleUpdate[](0);
    }
    return abi.decode(_accessManagerRoleUpdatesEncoded, (IAaveV4ConfigEngine.RoleUpdate[]));
  }

  function accessManagerTargetFunctionRoleUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory)
  {
    return _accessManagerTargetFunctionRoleUpdates;
  }

  function accessManagerTargetAdminDelayUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory)
  {
    return _accessManagerTargetAdminDelayUpdates;
  }

  function positionManagerSpokeRegistrations()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeRegistration[] memory)
  {
    return _positionManagerSpokeRegistrations;
  }

  function positionManagerRoleRenouncements()
    public
    view
    override
    returns (IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] memory)
  {
    return _positionManagerRoleRenouncements;
  }

  function feeSharesMinterConfigs()
    public
    view
    override
    returns (IAaveV4ConfigEngine.FeeSharesMinterConfig[] memory)
  {
    return _feeSharesMinterConfigs;
  }

  function feeSharesMinterHubConfigs()
    public
    view
    override
    returns (IAaveV4ConfigEngine.FeeSharesMinterHubConfig[] memory)
  {
    return _feeSharesMinterHubConfigs;
  }

  function feeSharesMinterWorkflowConfigs()
    public
    view
    override
    returns (IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig[] memory)
  {
    return _feeSharesMinterWorkflowConfigs;
  }
}
