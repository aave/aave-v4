// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

contract AaveV4TokenizationSpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployUpgradableTokenizationSpokeInstance(
    address hub,
    uint256 assetId,
    address spokeProxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) internal returns (address tokenizationSpokeProxy, address tokenizationSpokeImplementation) {
    require(hub != address(0), 'invalid hub');
    require(spokeProxyAdminOwner != address(0), 'invalid spoke proxy admin owner');
    require(bytes(shareName).length > 0, 'invalid share name');
    require(bytes(shareSymbol).length > 0, 'invalid share symbol');

    tokenizationSpokeImplementation = Create2Utils.create2Deploy(
      salt,
      _getTokenizationSpokeInstanceInitCode(hub, assetId)
    );

    tokenizationSpokeProxy = Create2Utils.proxify(
      salt,
      tokenizationSpokeImplementation,
      spokeProxyAdminOwner,
      abi.encodeCall(ITokenizationSpokeInstance.initialize, (shareName, shareSymbol))
    );

    return (tokenizationSpokeProxy, tokenizationSpokeImplementation);
  }

  function _computeTokenizationSpokeInstanceAddress(
    bytes32 salt,
    address hub,
    uint256 assetId,
    address spokeProxyAdminOwner,
    string memory shareName,
    string memory shareSymbol
  ) internal pure returns (address) {
    address tokenizationSpokeImplementation = Create2Utils.computeCreate2Address(
      salt,
      _getTokenizationSpokeInstanceInitCode(hub, assetId)
    );
    bytes memory initCode = abi.encodePacked(
      type(TransparentUpgradeableProxy).creationCode,
      abi.encode(
        tokenizationSpokeImplementation,
        spokeProxyAdminOwner,
        abi.encodeCall(ITokenizationSpokeInstance.initialize, (shareName, shareSymbol))
      )
    );
    return Create2Utils.computeCreate2Address(salt, keccak256(initCode));
  }

  function _getTokenizationSpokeInstanceInitCode(
    address hub,
    uint256 assetId
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(type(TokenizationSpokeInstance).creationCode, abi.encode(hub, assetId));
  }
}
