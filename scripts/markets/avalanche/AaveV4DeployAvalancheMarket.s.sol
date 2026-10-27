// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4DeployAvalancheMarket
/// @author Aave Labs
/// @notice Deploys the initial Aave V4 Avalanche market (1 hub, 3 spokes, gateways and position managers).
/// @dev All admin and owner roles default to the deployer, they are handed over by AaveV4AvalancheMarketPayloads.handover().
contract AaveV4DeployAvalancheMarket is AaveV4DeployBatchBaseScript {
  address internal constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
  uint256 internal constant VERSION = 1;

  constructor() AaveV4DeployBatchBaseScript('avalanche') {}

  function _getDeployInputs()
    internal
    pure
    override
    returns (InputUtils.FullDeployInputs memory inputs)
  {
    string[] memory hubLabels = new string[](1);
    hubLabels[0] = 'CORE_HUB';

    string[] memory spokeLabels = new string[](3);
    spokeLabels[0] = 'MAIN_SPOKE';
    spokeLabels[1] = 'AVAX_CORRELATED_SPOKE';
    spokeLabels[2] = 'FOREX_SPOKE';

    inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: address(0),
      proxyAdminOwner: address(0),
      hubAdmin: address(0),
      hubConfiguratorAdmin: address(0),
      treasurySpokeOwner: address(0),
      spokeAdmin: address(0),
      spokeConfiguratorAdmin: address(0),
      gatewayOwner: address(0),
      positionManagerOwner: address(0),
      nativeWrapper: WAVAX,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      deployPositionManagers: true,
      grantRoles: true,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      spokeMaxReservesLimits: new uint16[](0),
      salt: keccak256(bytes(string.concat('avalanche 43114_version ', vm.toString(VERSION))))
    });
  }

  function _expectedChainId() internal pure override returns (uint256) {
    return 43114;
  }
}
