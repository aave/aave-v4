// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {AddressesProviderInstance} from 'src/addresses-provider/instances/AddressesProviderInstance.sol';

/// @title AddressesProviderDeployProcedure
/// @author Aave Labs
/// @notice Deploys the AddressesProvider contract behind a transparent proxy.
contract AddressesProviderDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a AddressesProvider instance via CREATE2 and sets up a transparent proxy.
  /// @param owner The owner of the proxy admin and the AddressesProvider initializer.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return addressesProviderProxy The address of the deployed transparent proxy.
  /// @return addressesProviderImplementation The address of the deployed AddressesProvider implementation contract.
  function _deployAddressesProvider(
    address owner,
    bytes32 salt
  ) internal returns (address addressesProviderProxy, address addressesProviderImplementation) {
    require(owner != address(0), 'invalid owner');
    addressesProviderImplementation = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: type(AddressesProviderInstance).creationCode
    });
    addressesProviderProxy = Create2Utils.proxify({
      salt: salt,
      logic: addressesProviderImplementation,
      initialOwner: owner,
      data: abi.encodeCall(AddressesProviderInstance.initialize, (owner))
    });
    return (addressesProviderProxy, addressesProviderImplementation);
  }
}
