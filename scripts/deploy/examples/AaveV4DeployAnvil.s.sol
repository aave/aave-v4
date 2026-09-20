// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';

/// @title AaveV4DeployAnvil
/// @author Aave Labs
/// @notice Anvil-only demo deploy script with hardcoded inputs for local testing.
/// @dev Requires LiquidationLogic library pre-deployed (SpokeInstance depends on it).
///      Step 1: anvil (in separate terminal)
///      Step 2: set Create2Factory on anvil:
///         Run: cast rpc anvil_setCode 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3 --rpc-url http://127.0.0.1:8545
///      Step 3: run lib deployment from anvil test user:
///         Run: forge script scripts/LibraryPreCompile.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --ffi --sender 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --unlocked
///      Step 4: run deploy script from anvil test user:
///         Run: forge script scripts/deploy/examples/AaveV4DeployAnvil.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --sender 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --unlocked
contract AaveV4DeployAnvil is AaveV4DeployBatchBaseScript {
  address public weth;

  /// @dev Constructor. Deploys a WETH9 instance for use as the native wrapper.
  constructor() AaveV4DeployBatchBaseScript('anvil-deploy') {
    weth = address(new WETH9());
  }

  function _getDeployInputs()
    internal
    view
    override
    returns (InputUtils.FullDeployInputs memory inputs)
  {
    string[] memory hubLabels = new string[](2);
    hubLabels[0] = 'core';
    hubLabels[1] = 'test';

    string[] memory spokeLabels = new string[](3);
    spokeLabels[0] = 'mainnet';
    spokeLabels[1] = 'test';
    spokeLabels[2] = 'prime';

    inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: address(0),
      proxyAdminOwner: address(0),
      hubAdmin: address(0),
      hubConfiguratorAdmin: address(0),
      treasurySpokeOwner: address(0),
      feeSharesMinterOwner: address(0),
      spokeAdmin: address(0),
      spokeConfiguratorAdmin: address(1),
      gatewayOwner: address(2),
      positionManagerOwner: address(3),
      nativeWrapper: weth,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      deployPositionManagers: true,
      grantRoles: true,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      spokeMaxReservesLimits: new uint16[](0),
      salt: keccak256('anvil-test')
    });
  }

  function _expectedChainId() internal pure override returns (uint256) {
    return 31337;
  }

  /// @dev Skip user prompt on anvil.
  function _executeUserPrompt() internal override {}
}
