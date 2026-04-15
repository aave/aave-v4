// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title InputUtils Library
/// @author Aave Labs
/// @notice Deployment input struct and validation helpers.
library InputUtils {
  /// @dev accessManagerAdmin The default admin of the access manager. Only used when grantRoles is true.
  /// @dev proxyAdminOwner The owner of the Hub and Spoke ProxyAdmin contracts. Required at deploy time (constructor arg).
  ///      When grantRoles is `false`, defaults to the deployer; ownership can be transferred post-deployment.
  /// @dev hubAdmin The admin of the Hub. Only used when grantRoles is true.
  /// @dev hubConfiguratorAdmin The admin granted all hub configurator roles. Only used when grantRoles is true.
  /// @dev treasurySpokeOwner The owner of the TreasurySpoke (Ownable). Required at deploy time (constructor arg).
  ///      When grantRoles is `false`, defaults to the deployer; ownership can be transferred post-deployment.
  /// @dev feeSharesMinterOwner The owner of the FeeSharesMinter (Ownable). Required at deploy time (constructor arg).
  ///      When grantRoles is `false`, defaults to the deployer; ownership can be transferred post-deployment.
  /// @dev spokeAdmin The spoke admin. Only used when grantRoles is true.
  /// @dev spokeConfiguratorAdmin The admin granted all spoke configurator roles. Only used when grantRoles is true.
  /// @dev gatewayOwner The owner of the native token and signature gateways.
  /// @dev positionManagerOwner The owner of the position manager contracts (giver/taker/config).
  /// @dev nativeWrapper The address of the native wrapper (required when deployNativeTokenGateway is true).
  /// @dev deployNativeTokenGateway Whether to deploy the NativeTokenGateway.
  /// @dev deploySignatureGateway Whether to deploy the SignatureGateway.
  /// @dev deployPositionManagers Whether to deploy the position manager batch (giver/taker/config).
  /// @dev grantRoles Whether to grant roles during deployment. When `false`, only deploy-time ownership
  ///      addresses (proxyAdminOwner, treasurySpokeOwner) are set, defaulting
  ///      to the deployer. The deployer also retains the AccessManager ACCESS_MANAGER_ADMIN_ROLE.
  ///      All role grants and admin transfers are deferred to a later action.
  /// @dev hubLabels An array of hub labels; the number of hub labels defines the number of hubs to deploy.
  /// @dev spokeLabels An array of spoke labels; the number of spoke labels defines the number of spokes to deploy.
  /// @dev spokeMaxReservesLimits Per-spoke max user reserves limit (parallel to spokeLabels).
  /// @dev salt Root salt for deterministic CREATE2 deployment; orchestration derives per-batch salts.
  struct FullDeployInputs {
    address accessManagerAdmin;
    address proxyAdminOwner;
    address hubAdmin;
    address hubConfiguratorAdmin;
    address treasurySpokeOwner;
    address feeSharesMinterOwner;
    address spokeAdmin;
    address spokeConfiguratorAdmin;
    address gatewayOwner;
    address positionManagerOwner;
    address nativeWrapper;
    bool deployNativeTokenGateway;
    bool deploySignatureGateway;
    bool deployPositionManagers;
    bool grantRoles;
    string[] hubLabels;
    string[] spokeLabels;
    uint16[] spokeMaxReservesLimits;
    bytes32 salt;
  }

  /// @notice Reverts if any two labels in the array are identical.
  /// @param labels The array of labels to validate.
  /// @param kind A descriptor used in the revert message (e.g. "hub", "spoke").
  function validateUniqueLabels(string[] memory labels, string memory kind) internal pure {
    for (uint256 i; i < labels.length; i++) {
      for (uint256 j = i + 1; j < labels.length; j++) {
        require(
          keccak256(bytes(labels[i])) != keccak256(bytes(labels[j])),
          string.concat('duplicate ', kind, ' label: ', labels[i])
        );
      }
    }
  }
}
