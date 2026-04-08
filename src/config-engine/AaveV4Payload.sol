// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title AaveV4Payload
/// @author Aave Labs
/// @notice Abstract base payload contract for Aave V4 governance proposals.
abstract contract AaveV4Payload {
  using Address for address;

  /// @notice The config engine used to execute payload actions via delegatecall.
  IAaveV4ConfigEngine public immutable CONFIG_ENGINE;

  /// @dev Thrown when the config engine address is zero.
  error InvalidConfigEngine();

  /// @param configEngine_ The IAaveV4ConfigEngine implementation to delegatecall into.
  constructor(IAaveV4ConfigEngine configEngine_) {
    require(address(configEngine_) != address(0), InvalidConfigEngine());
    CONFIG_ENGINE = configEngine_;
  }

  /// @notice Main execution entry point called by governance. Runs all configured actions.
  /// @dev Expected to be called by a governance executor. No on-chain access control is applied;
  /// the caller is responsible for authorization. Idempotency is not guaranteed.
  function execute() external {
    _preExecute();
    _executeAccessManagerActions();
    _executeHubActions();
    _executeSpokeActions();
    _executePositionManagerActions();
    _postExecute();
  }

  /// @notice Returns the Hub asset listings to execute. Override to provide listings.
  /// @return An array of AssetListing structs (empty by default).
  function hubAssetListings()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.AssetListing[] memory)
  {
    return new IAaveV4ConfigEngine.AssetListing[](0);
  }

  /// @notice Returns the Hub asset config updates to execute. Override to provide updates.
  /// @return An array of AssetConfigUpdate structs (empty by default).
  function hubAssetConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.AssetConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.AssetConfigUpdate[](0);
  }

  /// @notice Returns the Hub Spoke-to-assets additions to execute. Override to provide additions.
  /// @return An array of SpokeToAssetsAddition structs (empty by default).
  function hubSpokeToAssetsAdditions()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeToAssetsAddition[](0);
  }

  /// @notice Returns the Hub Spoke config updates to execute. Override to provide updates.
  /// @return An array of SpokeConfigUpdate structs (empty by default).
  function hubSpokeConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.SpokeConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeConfigUpdate[](0);
  }

  /// @notice Returns the Hub asset halts to execute. Override to provide halts.
  /// @return An array of AssetHalt structs (empty by default).
  function hubAssetHalts() public view virtual returns (IAaveV4ConfigEngine.AssetHalt[] memory) {
    return new IAaveV4ConfigEngine.AssetHalt[](0);
  }

  /// @notice Returns the Hub asset deactivations to execute. Override to provide deactivations.
  /// @return An array of AssetDeactivation structs (empty by default).
  function hubAssetDeactivations()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.AssetDeactivation[] memory)
  {
    return new IAaveV4ConfigEngine.AssetDeactivation[](0);
  }

  /// @notice Returns the Hub asset caps resets to execute. Override to provide resets.
  /// @return An array of AssetCapsReset structs (empty by default).
  function hubAssetCapsResets()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.AssetCapsReset[] memory)
  {
    return new IAaveV4ConfigEngine.AssetCapsReset[](0);
  }

  /// @notice Returns the Hub Spoke deactivations to execute. Override to provide deactivations.
  /// @return An array of SpokeDeactivation structs (empty by default).
  function hubSpokeDeactivations()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.SpokeDeactivation[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeDeactivation[](0);
  }

  /// @notice Returns the Hub Spoke caps resets to execute. Override to provide resets.
  /// @return An array of SpokeCapsReset structs (empty by default).
  function hubSpokeCapsResets()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.SpokeCapsReset[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeCapsReset[](0);
  }

  /// @notice Returns the Spoke reserve listings to execute. Override to provide listings.
  /// @return An array of ReserveListing structs (empty by default).
  function spokeReserveListings()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.ReserveListing[] memory)
  {
    return new IAaveV4ConfigEngine.ReserveListing[](0);
  }

  /// @notice Returns the Spoke reserve config updates to execute. Override to provide updates.
  /// @return An array of ReserveConfigUpdate structs (empty by default).
  function spokeReserveConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.ReserveConfigUpdate[](0);
  }

  /// @notice Returns the Spoke liquidation config updates to execute. Override to provide updates.
  /// @return An array of LiquidationConfigUpdate structs (empty by default).
  function spokeLiquidationConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.LiquidationConfigUpdate[](0);
  }

  /// @notice Returns the Spoke dynamic reserve config additions to execute. Override to provide additions.
  /// @return An array of DynamicReserveConfigAddition structs (empty by default).
  function spokeDynamicReserveConfigAdditions()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory)
  {
    return new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](0);
  }

  /// @notice Returns the Spoke dynamic reserve config updates to execute. Override to provide updates.
  /// @return An array of DynamicReserveConfigUpdate structs (empty by default).
  function spokeDynamicReserveConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](0);
  }

  /// @notice Returns the Spoke position manager updates to execute. Override to provide updates.
  /// @return An array of PositionManagerUpdate structs (empty by default).
  function spokePositionManagerUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.PositionManagerUpdate[](0);
  }

  /// @notice Returns the access manager role memberships to execute. Override to provide memberships.
  /// @return An array of RoleMembership structs (empty by default).
  function accessManagerRoleMemberships()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.RoleMembership[] memory)
  {
    return new IAaveV4ConfigEngine.RoleMembership[](0);
  }

  /// @notice Returns the access manager role updates to execute. Override to provide updates.
  /// @return An array of RoleUpdate structs (empty by default).
  function accessManagerRoleUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.RoleUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.RoleUpdate[](0);
  }

  /// @notice Returns the access manager target function role updates to execute. Override to provide updates.
  /// @return An array of TargetFunctionRoleUpdate structs (empty by default).
  function accessManagerTargetFunctionRoleUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](0);
  }

  /// @notice Returns the access manager target admin delay updates to execute. Override to provide updates.
  /// @return An array of TargetAdminDelayUpdate structs (empty by default).
  function accessManagerTargetAdminDelayUpdates()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.TargetAdminDelayUpdate[](0);
  }

  /// @notice Returns the position manager Spoke registrations to execute. Override to provide registrations.
  /// @return An array of SpokeRegistration structs (empty by default).
  function positionManagerSpokeRegistrations()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.SpokeRegistration[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeRegistration[](0);
  }

  /// @notice Returns the position manager role renouncements to execute. Override to provide renouncements.
  /// @return An array of PositionManagerRoleRenouncement structs (empty by default).
  function positionManagerRoleRenouncements()
    public
    view
    virtual
    returns (IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] memory)
  {
    return new IAaveV4ConfigEngine.PositionManagerRoleRenouncement[](0);
  }

  /// @notice Executes all hub-related configuration actions via delegatecall to the engine.
  function _executeHubActions() internal {
    IAaveV4ConfigEngine.AssetListing[] memory listings = hubAssetListings();
    if (listings.length > 0) {
      _delegateCallEngine(abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetListings, (listings)));
    }

    IAaveV4ConfigEngine.AssetConfigUpdate[] memory assetConfigUpdates = hubAssetConfigUpdates();
    if (assetConfigUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetConfigUpdates, (assetConfigUpdates))
      );
    }

    IAaveV4ConfigEngine.SpokeToAssetsAddition[]
      memory spokeToAssetsAdds = hubSpokeToAssetsAdditions();
    if (spokeToAssetsAdds.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeToAssetsAdditions, (spokeToAssetsAdds))
      );
    }

    IAaveV4ConfigEngine.SpokeConfigUpdate[] memory spokeConfigUpdates = hubSpokeConfigUpdates();
    if (spokeConfigUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeConfigUpdates, (spokeConfigUpdates))
      );
    }

    IAaveV4ConfigEngine.AssetHalt[] memory assetHalts = hubAssetHalts();
    if (assetHalts.length > 0) {
      _delegateCallEngine(abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetHalts, (assetHalts)));
    }

    IAaveV4ConfigEngine.AssetDeactivation[] memory assetDeactivations = hubAssetDeactivations();
    if (assetDeactivations.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetDeactivations, (assetDeactivations))
      );
    }

    IAaveV4ConfigEngine.AssetCapsReset[] memory assetCapsResets = hubAssetCapsResets();
    if (assetCapsResets.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetCapsResets, (assetCapsResets))
      );
    }

    IAaveV4ConfigEngine.SpokeDeactivation[] memory spokeDeactivations = hubSpokeDeactivations();
    if (spokeDeactivations.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeDeactivations, (spokeDeactivations))
      );
    }

    IAaveV4ConfigEngine.SpokeCapsReset[] memory spokeCapsResets = hubSpokeCapsResets();
    if (spokeCapsResets.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeCapsResets, (spokeCapsResets))
      );
    }
  }

  /// @notice Executes all Spoke-related configuration actions via delegatecall to the engine.
  function _executeSpokeActions() internal {
    IAaveV4ConfigEngine.ReserveListing[] memory reserveListings = spokeReserveListings();
    if (reserveListings.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeReserveListings, (reserveListings))
      );
    }

    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory reserveConfigUpdates = spokeReserveConfigUpdates();
    if (reserveConfigUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeReserveConfigUpdates, (reserveConfigUpdates))
      );
    }

    IAaveV4ConfigEngine.LiquidationConfigUpdate[]
      memory liqConfigUpdates = spokeLiquidationConfigUpdates();
    if (liqConfigUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeLiquidationConfigUpdates, (liqConfigUpdates))
      );
    }

    IAaveV4ConfigEngine.DynamicReserveConfigAddition[]
      memory dynAdds = spokeDynamicReserveConfigAdditions();
    if (dynAdds.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeDynamicReserveConfigAdditions, (dynAdds))
      );
    }

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]
      memory dynUpdates = spokeDynamicReserveConfigUpdates();
    if (dynUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeDynamicReserveConfigUpdates, (dynUpdates))
      );
    }

    IAaveV4ConfigEngine.PositionManagerUpdate[] memory pmUpdates = spokePositionManagerUpdates();
    if (pmUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokePositionManagerUpdates, (pmUpdates))
      );
    }
  }

  /// @notice Executes all Access Manager configuration actions via delegatecall to the engine.
  function _executeAccessManagerActions() internal {
    IAaveV4ConfigEngine.RoleMembership[] memory memberships = accessManagerRoleMemberships();
    if (memberships.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeRoleMemberships, (memberships))
      );
    }

    IAaveV4ConfigEngine.RoleUpdate[] memory roleUpdates = accessManagerRoleUpdates();
    if (roleUpdates.length > 0) {
      _delegateCallEngine(abi.encodeCall(IAaveV4ConfigEngine.executeRoleUpdates, (roleUpdates)));
    }

    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[]
      memory fnRoleUpdates = accessManagerTargetFunctionRoleUpdates();
    if (fnRoleUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeTargetFunctionRoleUpdates, (fnRoleUpdates))
      );
    }

    IAaveV4ConfigEngine.TargetAdminDelayUpdate[]
      memory targetDelayUpdates = accessManagerTargetAdminDelayUpdates();
    if (targetDelayUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeTargetAdminDelayUpdates, (targetDelayUpdates))
      );
    }
  }

  /// @notice Executes all Position Manager configuration actions via delegatecall to the engine.
  function _executePositionManagerActions() internal {
    IAaveV4ConfigEngine.SpokeRegistration[] memory spokeRegs = positionManagerSpokeRegistrations();
    if (spokeRegs.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executePositionManagerSpokeRegistrations, (spokeRegs))
      );
    }

    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[]
      memory renouncements = positionManagerRoleRenouncements();
    if (renouncements.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executePositionManagerRoleRenouncements, (renouncements))
      );
    }
  }

  /// @notice Delegatecalls the config engine with the given calldata.
  /// @param data The ABI-encoded function call to forward to CONFIG_ENGINE.
  /// @dev Bubbles up any revert reason from the engine call. Assumes the engine functions return no data.
  function _delegateCallEngine(bytes memory data) internal {
    address(CONFIG_ENGINE).functionDelegateCall(data);
  }

  /// @notice Hook called before executing any actions. Override to add pre-execution logic.
  function _preExecute() internal virtual {}

  /// @notice Hook called after executing all actions. Override to add post-execution logic.
  function _postExecute() internal virtual {}
}
