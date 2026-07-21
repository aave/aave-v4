// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {UpgradeableBeacon} from 'src/dependencies/openzeppelin/UpgradeableBeacon.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

/// @title AaveV4TokenizationSpokeBeaconDeployProcedure
/// @author Aave Labs
/// @notice Deploys the shared TokenizationSpoke implementation and its UpgradeableBeacon.
/// @dev All TokenizationSpoke beacon proxies share this single implementation and beacon, so the
/// beacon owner controls upgrades for every TokenizationSpoke that points to it.
contract AaveV4TokenizationSpokeBeaconDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys the shared TokenizationSpoke implementation and beacon via CREATE2.
  /// @param beaconOwner The owner of the beacon, able to upgrade the shared implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return tokenizationSpokeBeacon The address of the deployed beacon.
  /// @return tokenizationSpokeImplementation The address of the deployed shared implementation contract.
  function _deployTokenizationSpokeBeacon(
    address beaconOwner,
    bytes32 salt
  ) internal returns (address tokenizationSpokeBeacon, address tokenizationSpokeImplementation) {
    require(beaconOwner != address(0), 'invalid beacon owner');

    tokenizationSpokeImplementation = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: type(TokenizationSpokeInstance).creationCode
    });

    tokenizationSpokeBeacon = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: abi.encodePacked(
        type(UpgradeableBeacon).creationCode,
        abi.encode(tokenizationSpokeImplementation, beaconOwner)
      )
    });

    return (tokenizationSpokeBeacon, tokenizationSpokeImplementation);
  }
}
