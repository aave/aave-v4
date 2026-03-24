// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

contract AaveV4TokenizationSpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployUpgradeableTokenizationSpokeInstance(
    address hub,
    address underlying,
    address spokeProxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) internal returns (address tokenizationSpokeProxy, address tokenizationSpokeImplementation) {
    require(hub != address(0), 'invalid hub');
    require(spokeProxyAdminOwner != address(0), 'invalid spoke proxy admin owner');
    require(bytes(shareName).length > 0, 'invalid share name');
    require(bytes(shareSymbol).length > 0, 'invalid share symbol');

    tokenizationSpokeImplementation = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: _getTokenizationSpokeInstanceInitCode(hub, underlying)
    });

    tokenizationSpokeProxy = Create2Utils.proxify({
      salt: salt,
      logic: tokenizationSpokeImplementation,
      initialOwner: spokeProxyAdminOwner,
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
  function _getTokenizationSpokeInstanceInitCode(
    address hub,
    address underlying
  ) internal pure returns (bytes memory) {
    return
      abi.encodePacked(type(TokenizationSpokeInstance).creationCode, abi.encode(hub, underlying));
  }
}
