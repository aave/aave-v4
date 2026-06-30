// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title AaveV4TokenizationSpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys a TokenizationSpoke instance behind a beacon proxy.
contract AaveV4TokenizationSpokeDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a TokenizationSpoke beacon proxy via CREATE2 and initializes it.
  /// @param beacon The address of the shared TokenizationSpoke beacon.
  /// @param hub The address of the Hub that the tokenization spoke connects to.
  /// @param underlying The address of the underlying asset to tokenize.
  /// @param shareName The name of the share token.
  /// @param shareSymbol The symbol of the share token.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return tokenizationSpokeProxy The address of the deployed beacon proxy.
  function _deployTokenizationSpokeInstance(
    address beacon,
    address hub,
    address underlying,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) internal returns (address tokenizationSpokeProxy) {
    require(beacon != address(0), 'invalid beacon');
    require(hub != address(0), 'invalid hub');
    require(bytes(shareName).length > 0, 'invalid share name');
    require(bytes(shareSymbol).length > 0, 'invalid share symbol');

    tokenizationSpokeProxy = Create2Utils.beaconProxify({
      salt: salt,
      beacon: beacon,
      data: abi.encodeCall(
        ITokenizationSpokeInstance.initialize,
        (hub, underlying, shareName, shareSymbol)
      )
    });

    require(
      ITokenizationSpoke(tokenizationSpokeProxy).hub() == hub,
      'tokenization spoke hub mismatch'
    );
    require(
      ITokenizationSpoke(tokenizationSpokeProxy).asset() == underlying,
      'tokenization spoke underlying mismatch'
    );

    return tokenizationSpokeProxy;
  }
}
