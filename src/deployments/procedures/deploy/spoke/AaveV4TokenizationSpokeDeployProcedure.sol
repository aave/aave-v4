// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title AaveV4TokenizationSpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys an upgradeable TokenizationSpoke instance behind a transparent proxy.
contract AaveV4TokenizationSpokeDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a TokenizationSpoke implementation via CREATE2 and sets up a transparent proxy.
  /// @param hub The address of the Hub that the tokenization spoke connects to.
  /// @param underlying The address of the underlying asset to tokenize.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param shareName The name of the share token.
  /// @param shareSymbol The symbol of the share token.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return tokenizationSpokeProxy The address of the deployed transparent proxy.
  /// @return tokenizationSpokeImplementation The address of the deployed TokenizationSpoke implementation contract.
  function _deployUpgradeableTokenizationSpokeInstance(
    address hub,
    address underlying,
    address proxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) internal returns (address tokenizationSpokeProxy, address tokenizationSpokeImplementation) {
    require(hub != address(0), 'invalid hub');
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(bytes(shareName).length > 0, 'invalid share name');
    require(bytes(shareSymbol).length > 0, 'invalid share symbol');

    tokenizationSpokeImplementation = Create2Utils.create2DeployIdempotent({
      salt: salt,
      bytecode: _getTokenizationSpokeInstanceInitCode(hub, underlying)
    });

    tokenizationSpokeProxy = Create2Utils.proxify({
      salt: salt,
      logic: tokenizationSpokeImplementation,
      initialOwner: proxyAdminOwner,
      data: abi.encodeCall(ITokenizationSpokeInstance.initialize, (shareName, shareSymbol))
    });

    require(
      ITokenizationSpoke(tokenizationSpokeProxy).hub() == hub,
      'tokenization spoke hub mismatch'
    );
    require(
      ITokenizationSpoke(tokenizationSpokeProxy).asset() == underlying,
      'tokenization spoke underlying mismatch'
    );

    return (tokenizationSpokeProxy, tokenizationSpokeImplementation);
  }

  /// @notice Returns the creation bytecode for a TokenizationSpokeInstance with constructor arguments appended.
  /// @param hub The address of the Hub contract.
  /// @param underlying The address of the underlying asset.
  /// @return The ABI-encoded creation bytecode.
  function _getTokenizationSpokeInstanceInitCode(
    address hub,
    address underlying
  ) internal pure returns (bytes memory) {
    return
      abi.encodePacked(type(TokenizationSpokeInstance).creationCode, abi.encode(hub, underlying));
  }
}
