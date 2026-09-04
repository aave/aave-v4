// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {AaveV4HubConfiguratorDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4HubConfiguratorDeployProcedureWrapper.sol';
import {AaveV4HubDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4HubDeployProcedureWrapper.sol';
import {AaveV4InterestRateStrategyDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4InterestRateStrategyDeployProcedureWrapper.sol';
import {AaveV4NativeTokenGatewayDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4NativeTokenGatewayDeployProcedureWrapper.sol';
import {AaveV4SignatureGatewayDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4SignatureGatewayDeployProcedureWrapper.sol';
import {AaveV4AccessManagerEnumerableDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4AccessManagerEnumerableDeployProcedureWrapper.sol';
import {AaveV4AaveOracleDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4AaveOracleDeployProcedureWrapper.sol';
import {AaveV4SpokeDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4SpokeDeployProcedureWrapper.sol';
import {AaveV4TreasurySpokeDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4TreasurySpokeDeployProcedureWrapper.sol';
import {AaveV4SpokeConfiguratorDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4SpokeConfiguratorDeployProcedureWrapper.sol';
import {AaveV4AccessManagerRolesProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4AccessManagerRolesProcedureWrapper.sol';
import {AaveV4SpokeRolesProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4SpokeRolesProcedureWrapper.sol';
import {AaveV4HubRolesProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4HubRolesProcedureWrapper.sol';
import {AaveV4HubConfiguratorRolesProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4HubConfiguratorRolesProcedureWrapper.sol';
import {AaveV4SpokeConfiguratorRolesProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4SpokeConfiguratorRolesProcedureWrapper.sol';
import {AaveV4TokenizationSpokeDeployProcedureWrapper} from 'tests/helpers/mocks/deployments/procedures/AaveV4TokenizationSpokeDeployProcedureWrapper.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {AaveV4HubInstanceBatch} from 'src/deployments/batches/AaveV4HubInstanceBatch.sol';
import {AaveV4TreasurySpokeBatch} from 'src/deployments/batches/AaveV4TreasurySpokeBatch.sol';
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
import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';

contract ProceduresBase is Create2TestHelper {
  address public owner = makeAddr('owner');
  address public accessManager;
  address public hub = makeAddr('hub');
  address public nativeWrapper = makeAddr('nativeWrapper');
  address public accessManagerAdmin = makeAddr('accessManagerAdmin');
  uint8 public oracleDecimals = 8;
  uint16 public maxUserReservesLimit = DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT;
  address public spoke = makeAddr('spoke');
  address public aaveOracle;
  address public feeReceiver = makeAddr('feeReceiver');
  address public admin = makeAddr('admin');
  bytes32 public salt;
  bytes internal hubBytecode;
  bytes internal spokeBytecode;

  function setUp() public virtual {
    _etchCreate2Factory();

    hubBytecode = vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
    spokeBytecode = vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance');
    accessManager = address(new AccessManagerEnumerable(accessManagerAdmin));
    aaveOracle = address(new AaveOracle(oracleDecimals));
    salt = keccak256('testSalt');
  }

  function _assertCanCall(address target, bytes4[] memory selectors) internal {
    for (uint256 idx; idx < selectors.length; idx++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        target,
        selectors[idx]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 idx; idx < selectors.length; idx++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        unauthorized,
        target,
        selectors[idx]
      );
      assertFalse(allowed);
      assertEq(delay, 0);
    }
  }
}
