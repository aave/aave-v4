// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';

contract AaveV4SpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployUpgradeableSpokeInstance(
    address spokeProxyAdminOwner,
    address authority,
    address oracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (address spokeProxy, address spokeImplementation) {
    require(spokeProxyAdminOwner != address(0), 'invalid spoke proxy admin owner');
    require(authority != address(0), 'invalid authority');
    require(oracle != address(0), 'invalid oracle');
    require(maxUserReservesLimit > 0, 'invalid max user reserves limit');
    spokeImplementation = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: _getSpokeInstanceInitCode(spokeBytecode, oracle, maxUserReservesLimit)
    });
    spokeProxy = Create2Utils.proxify({
      salt: salt,
      logic: spokeImplementation,
      initialOwner: spokeProxyAdminOwner,
      data: abi.encodeCall(ISpokeInstance.initialize, (authority))
    });
    return (spokeProxy, spokeImplementation);
  }

  function _getSpokeInstanceInitCode(
    bytes memory spokeBytecode,
    address oracle,
    uint16 maxUserReservesLimit
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(spokeBytecode, abi.encode(oracle, maxUserReservesLimit));
  }
}
