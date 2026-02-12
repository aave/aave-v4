// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4TokenizationSpokeBatch} from 'src/deployments/batches/AaveV4TokenizationSpokeBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';

contract BatchBaseTest is Test, InputUtils {
  address public admin = makeAddr('admin');
  bytes32 public salt;
  address public accessManager;
  address public nativeWrapper;

  function setUp() public virtual {
    salt = keccak256('testSalt');
    _etchCreate2Factory();

    // used Hub, Spoke, Configurator batches
    AaveV4AccessBatch accessBatch = new AaveV4AccessBatch(admin, salt);
    accessManager = accessBatch.getReport().accessManager;

    // used by Gateway batch
    nativeWrapper = address(new WETH9());
  }
}
