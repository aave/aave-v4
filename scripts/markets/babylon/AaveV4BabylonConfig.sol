// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4BabylonConfig
/// @author Aave Labs
/// @notice Reads the Babylon market config and the deployment report it points to.
library AaveV4BabylonConfig {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;

  /// @dev salt The user-provided deploy salt.
  /// @dev hubLabel The label of the Babylon Hub.
  /// @dev babylonSpokeLabel The label of the BabylonSpoke.
  /// @dev liquidationManager The only address allowed to liquidate on the BabylonSpoke.
  /// @dev managedCollateralReserveId The identifier of the only reserve usable as collateral.
  /// @dev admin The address receiving every role and ownership at handover.
  /// @dev report The deployment report written by the deploy script.
  struct Config {
    bytes32 salt;
    string hubLabel;
    string babylonSpokeLabel;
    address liquidationManager;
    uint256 managedCollateralReserveId;
    address admin;
    string report;
  }

  /// @dev Addresses of the deployed Babylon market read from the deployment report.
  struct Deployment {
    address accessManager;
    address hubConfigurator;
    address spokeConfigurator;
    address treasurySpoke;
    address hub;
    address babylonSpoke;
  }

  /// @notice Returns the config file path for the current chain.
  function path() internal view returns (string memory) {
    if (block.chainid == SEPOLIA_CHAIN_ID) {
      return 'scripts/markets/babylon/sepolia.json';
    }
    revert('unsupported chain');
  }

  /// @notice Reads the config for the current chain.
  function read() internal view returns (Config memory) {
    return parse(vm.readFile(path()));
  }

  /// @notice Parses a config JSON.
  /// @param json The config JSON.
  function parse(string memory json) internal pure returns (Config memory) {
    return
      Config({
        salt: vm.parseJsonBytes32(json, '.salt'),
        hubLabel: vm.parseJsonString(json, '.hubLabel'),
        babylonSpokeLabel: vm.parseJsonString(json, '.babylonSpokeLabel'),
        liquidationManager: vm.parseJsonAddress(json, '.liquidationManager'),
        managedCollateralReserveId: vm.parseJsonUint(json, '.managedCollateralReserveId'),
        admin: vm.parseJsonAddress(json, '.admin'),
        report: vm.parseJsonString(json, '.report')
      });
  }

  /// @notice Builds the deploy inputs: one Hub and one BabylonSpoke, roles deferred to the handover.
  /// @param config The Babylon market config.
  function deployInputs(
    Config memory config
  ) internal pure returns (InputUtils.FullDeployInputs memory) {
    string[] memory hubLabels = new string[](1);
    hubLabels[0] = config.hubLabel;
    string[] memory babylonSpokeLabels = new string[](1);
    babylonSpokeLabels[0] = config.babylonSpokeLabel;
    address[] memory babylonLiquidationManagers = new address[](1);
    babylonLiquidationManagers[0] = config.liquidationManager;
    uint256[] memory babylonManagedCollateralReserveIds = new uint256[](1);
    babylonManagedCollateralReserveIds[0] = config.managedCollateralReserveId;

    return
      InputUtils.FullDeployInputs({
        accessManagerAdmin: address(0),
        proxyAdminOwner: address(0),
        hubAdmin: address(0),
        hubConfiguratorAdmin: address(0),
        treasurySpokeOwner: address(0),
        spokeAdmin: address(0),
        spokeConfiguratorAdmin: address(0),
        gatewayOwner: address(0),
        positionManagerOwner: address(0),
        nativeWrapper: address(0),
        deployNativeTokenGateway: false,
        deploySignatureGateway: false,
        deployPositionManagers: false,
        grantRoles: false,
        hubLabels: hubLabels,
        spokeLabels: new string[](0),
        spokeMaxReservesLimits: new uint16[](0),
        babylonSpokeLabels: babylonSpokeLabels,
        babylonLiquidationManagers: babylonLiquidationManagers,
        babylonManagedCollateralReserveIds: babylonManagedCollateralReserveIds,
        salt: config.salt
      });
  }

  /// @notice Reads the deployed addresses from the deployment report.
  /// @param config The Babylon market config.
  function readDeployment(Config memory config) internal view returns (Deployment memory) {
    string memory json = vm.readFile(config.report);
    return
      Deployment({
        accessManager: vm.parseJsonAddress(json, '.accessManager'),
        hubConfigurator: vm.parseJsonAddress(json, '.hubConfigurator'),
        spokeConfigurator: vm.parseJsonAddress(json, '.spokeConfigurator'),
        treasurySpoke: vm.parseJsonAddress(json, '.treasurySpoke'),
        hub: vm.parseJsonAddress(json, string.concat('.hub.', config.hubLabel)),
        babylonSpoke: vm.parseJsonAddress(
          json,
          string.concat('.babylonSpoke.', config.babylonSpokeLabel)
        )
      });
  }
}
