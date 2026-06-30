// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4TokenizationSpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeDeployProcedure.sol';

/// @title AaveV4TokenizationSpokeBatch
/// @author Aave Labs
/// @notice Deploys a TokenizationSpoke instance (beacon proxy) for a given asset, producing a batch report.
contract AaveV4TokenizationSpokeBatch is AaveV4TokenizationSpokeDeployProcedure {
  BatchReports.TokenizationSpokeBatchReport internal _report;

  /// @dev Constructor.
  /// @param beacon_ The address of the shared TokenizationSpoke beacon.
  /// @param hub_ The address of the Hub the TokenizationSpoke connects to.
  /// @param underlying_ The address of the underlying asset to tokenize.
  /// @param shareName_ The name of the share token.
  /// @param shareSymbol_ The symbol of the share token.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(
    address beacon_,
    address hub_,
    address underlying_,
    string memory shareName_,
    string memory shareSymbol_,
    bytes32 salt_
  ) {
    address tokenizationSpokeProxy = _deployTokenizationSpokeInstance({
      beacon: beacon_,
      hub: hub_,
      underlying: underlying_,
      shareName: shareName_,
      shareSymbol: shareSymbol_,
      salt: salt_
    });

    _report = BatchReports.TokenizationSpokeBatchReport({
      tokenizationSpokeProxy: tokenizationSpokeProxy,
      tokenizationSpokeBeacon: beacon_
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.TokenizationSpokeBatchReport memory) {
    return _report;
  }
}
