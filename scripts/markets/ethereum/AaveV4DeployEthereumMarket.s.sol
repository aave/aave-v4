// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployEthereum} from 'scripts/deploy/AaveV4DeployEthereum.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4DeployEthereumMarket
/// @author Aave Labs
/// @notice Deploys the initial Aave V4 Ethereum market (3 hubs, 10 spokes, gateways and position managers).
/// @dev All admin and owner roles default to the deployer, they are handed over by AaveV4EthereumMarketPayloads.handover().
contract AaveV4DeployEthereumMarket is AaveV4DeployEthereum {
  address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  uint256 internal constant VERSION = 1;

  function _getDeployInputs()
    internal
    pure
    override
    returns (InputUtils.FullDeployInputs memory inputs)
  {
    string[] memory hubLabels = new string[](3);
    hubLabels[0] = 'PRIME_HUB';
    hubLabels[1] = 'CORE_HUB';
    hubLabels[2] = 'PLUS_HUB';

    string[] memory spokeLabels = new string[](10);
    spokeLabels[0] = 'MAIN_SPOKE';
    spokeLabels[1] = 'LIDO_ESPOKE';
    spokeLabels[2] = 'ETHERFI_ESPOKE';
    spokeLabels[3] = 'KELP_ESPOKE';
    spokeLabels[4] = 'LOMBARD_BTC_SPOKE';
    spokeLabels[5] = 'GOLD_SPOKE';
    spokeLabels[6] = 'FOREX_SPOKE';
    spokeLabels[7] = 'BLUECHIP_SPOKE';
    spokeLabels[8] = 'ETHENA_ECOSYSTEM_SPOKE';
    spokeLabels[9] = 'ETHENA_CORRELATED_SPOKE';

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
      nativeWrapper: WETH,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      deployPositionManagers: true,
      grantRoles: true,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      spokeMaxReservesLimits: new uint16[](0),
      salt: keccak256(bytes(string.concat('chain 1_version ', vm.toString(VERSION))))
    });
  }
}
