// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title AaveV4TokenizationSpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys the canonical TokenizationSpoke implementation and TokenizationSpoke transparent proxies.
contract AaveV4TokenizationSpokeDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys the canonical TokenizationSpokeInstance implementation via CREATE2.
  /// @dev The implementation holds no Hub or asset specific state and is shared by every TokenizationSpoke proxy.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed TokenizationSpoke implementation contract.
  function _deployTokenizationSpokeImplementation(bytes32 salt) internal returns (address) {
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: type(TokenizationSpokeInstance).creationCode
      });
  }

  /// @notice Deploys a TokenizationSpoke transparent proxy via CREATE2 pointing to `implementation`.
  /// @param implementation The address of the TokenizationSpokeInstance implementation.
  /// @param hub The address of the Hub that the tokenization spoke connects to.
  /// @param underlying The address of the underlying asset to tokenize.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param shareName The name of the share token.
  /// @param shareSymbol The symbol of the share token.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return tokenizationSpokeProxy The address of the deployed transparent proxy.
  function _deployTokenizationSpokeProxy(
    address implementation,
    address hub,
    address underlying,
    address proxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) internal returns (address tokenizationSpokeProxy) {
    require(implementation != address(0), 'invalid implementation');
    require(hub != address(0), 'invalid hub');
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(bytes(shareName).length > 0, 'invalid share name');
    require(bytes(shareSymbol).length > 0, 'invalid share symbol');

    tokenizationSpokeProxy = Create2Utils.proxify({
      salt: salt,
      logic: implementation,
      initialOwner: proxyAdminOwner,
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
  }
}
