// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AddressesProviderDeployProcedure} from 'src/deployments/procedures/deploy/addresses-provider/AddressesProviderDeployProcedure.sol';

/// @title AddressesProviderBatch
/// @author Aave Labs
/// @notice Deploys the AddressesProvider contract, producing a batch report.
contract AddressesProviderBatch is AddressesProviderDeployProcedure {
  BatchReports.AddressesProviderBatchReport internal _report;

  /// @dev Constructor.
  /// @param owner_ The owner of the AddressesProvider proxy admin and initializer.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address owner_, bytes32 salt_) {
    (
      address addressesProviderProxy,
      address addressesProviderImplementation
    ) = _deployAddressesProvider({owner: owner_, salt: salt_});
    _report = BatchReports.AddressesProviderBatchReport({
      addressesProviderProxy: addressesProviderProxy,
      addressesProviderImplementation: addressesProviderImplementation
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.AddressesProviderBatchReport memory) {
    return _report;
  }
}
