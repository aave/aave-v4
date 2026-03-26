// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AuthorityBatch} from 'src/deployments/batches/AaveV4AuthorityBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4HubInstanceBatch} from 'src/deployments/batches/AaveV4HubInstanceBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4TokenizationSpokeBatch} from 'src/deployments/batches/AaveV4TokenizationSpokeBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';
import {AaveV4PositionManagerBatch} from 'src/deployments/batches/AaveV4PositionManagerBatch.sol';
import {AaveV4TreasurySpokeBatch} from 'src/deployments/batches/AaveV4TreasurySpokeBatch.sol';
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

contract BatchBaseTest is Create2TestHelper {
  address public admin = makeAddr('admin');
  address public feeReceiver = makeAddr('feeReceiver');
  bytes32 public salt;
  address public accessManager;
  address public nativeWrapper;
  bytes internal hubBytecode;
  bytes internal spokeBytecode;

  function setUp() public virtual {
    salt = keccak256('testSalt');
    _etchCreate2Factory();

    hubBytecode = vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
    spokeBytecode = vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance');

    // used Hub, Spoke, Configurator batches
    AaveV4AuthorityBatch authorityBatch = new AaveV4AuthorityBatch({admin_: admin, salt_: salt});
    accessManager = authorityBatch.getReport().accessManager;

    // used by Gateway batch
    nativeWrapper = address(new WETH9());
  }
}
