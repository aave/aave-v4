// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {Constants} from 'tests/Constants.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {AaveV4HubConfiguratorDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4HubConfiguratorDeployProcedureWrapper.sol';
import {AaveV4HubDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4HubDeployProcedureWrapper.sol';
import {AaveV4InterestRateStrategyDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4InterestRateStrategyDeployProcedureWrapper.sol';
import {AaveV4NativeTokenGatewayDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4NativeTokenGatewayDeployProcedureWrapper.sol';
import {AaveV4SignatureGatewayDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4SignatureGatewayDeployProcedureWrapper.sol';
import {AaveV4AccessManagerEnumerableDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4AccessManagerEnumerableDeployProcedureWrapper.sol';
import {AaveV4AaveOracleDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4AaveOracleDeployProcedureWrapper.sol';
import {AaveV4SpokeDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4SpokeDeployProcedureWrapper.sol';
import {AaveV4TreasurySpokeDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4TreasurySpokeDeployProcedureWrapper.sol';
import {AaveV4SpokeConfiguratorDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4SpokeConfiguratorDeployProcedureWrapper.sol';
import {AaveV4AccessManagerRolesProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4AccessManagerRolesProcedureWrapper.sol';
import {AaveV4SpokeRolesProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4SpokeRolesProcedureWrapper.sol';
import {AaveV4HubRolesProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4HubRolesProcedureWrapper.sol';
import {AaveV4HubConfiguratorRolesProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4HubConfiguratorRolesProcedureWrapper.sol';
import {AaveV4SpokeConfiguratorRolesProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4SpokeConfiguratorRolesProcedureWrapper.sol';
import {AaveV4TokenizationSpokeDeployProcedureWrapper} from 'tests/mocks/deployments/procedures/AaveV4TokenizationSpokeDeployProcedureWrapper.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';

contract ProceduresBase is Test, InputUtils {
  address public owner = makeAddr('owner');
  address public accessManager;
  address public hub = makeAddr('hub');
  address public nativeWrapper = makeAddr('nativeWrapper');
  address public accessManagerAdmin = makeAddr('accessManagerAdmin');
  uint8 public oracleDecimals = 8;
  string public oracleDescription = 'Oracle Description';
  uint16 public maxUserReservesLimit = Constants.MAX_ALLOWED_USER_RESERVES_LIMIT;
  address public spoke = makeAddr('spoke');
  address public aaveOracle;
  address public treasurySpoke = makeAddr('treasurySpoke');
  address public admin = makeAddr('admin');
  bytes32 public salt;
  function setUp() public virtual {
    _etchCreate2Factory();

    accessManager = address(new AccessManagerEnumerable(accessManagerAdmin));
    aaveOracle = address(new AaveOracle(oracleDecimals, oracleDescription));
    salt = keccak256('testSalt');
  }
}
