// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script, console} from 'forge-std/Script.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

interface ICreateX {
  function computeCreate3Address(bytes32 salt) external view returns (address);
}

/// @title AaveV4BabylonSpokeDeployment library
/// @author Aave Labs
/// @notice Deploys the BabylonSpoke of a Babylon market whose Hubs are already deployed.
library AaveV4BabylonSpokeDeployment {
  /// @notice Deploys the BabylonSpoke at the address the full market deployment gives it, under
  /// `accessManager`, with its ProxyAdmin owned by `deployer`, and sets its function roles.
  /// @param config The Babylon market config.
  /// @param deployer The config deployer.
  /// @param accessManager The AccessManager of the deployed Hubs.
  /// @return report The BabylonSpoke instance batch report.
  function deploy(
    AaveV4BabylonConfig.Config memory config,
    address deployer,
    address accessManager
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory report) {
    bytes32 salt = AaveV4DeployOrchestration._deriveChildSalt({
      baseSalt: AaveV4DeployOrchestration._deriveSalt({deployer: deployer, salt: config.salt}),
      contractType: 'babylonSpoke',
      label: config.babylonSpokeLabel
    });
    report = AaveV4DeployBase.deployBabylonSpokeInstanceBatch({
      proxyAdminOwner: deployer,
      authority: accessManager,
      liquidationManager: config.liquidationManager,
      managedCollateralReserveId: config.managedCollateralReserveId,
      babylonSpokeBytecode: BytecodeHelper.getBabylonSpokeBytecode(),
      oracleDecimals: DeployConstants.ORACLE_DECIMALS,
      salt: salt
    });
    AaveV4SpokeRolesProcedure.setupSpokeAllRoles({
      accessManager: accessManager,
      spoke: report.spokeProxy
    });
  }
}

/// @title AaveV4DeployBabylonSpoke
/// @author Aave Labs
/// @notice Deploys the BabylonSpoke of the market `AaveV4DeployBabylon` deployed, under its
/// AccessManager, and writes the deployment report with the BabylonSpoke added.
contract AaveV4DeployBabylonSpoke is Script {
  /// @dev CreateX factory, https://github.com/pcaversaccio/createx.
  address internal constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';

  function run() external {
    AaveV4BabylonConfig.Config memory config = _config();
    _requireConfigLibraries(config.librarySalt);
    _requireLiquidationManager(config);
    string memory json = vm.readFile(config.report);
    address accessManager = _readAccessManager(config, json);

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    AaveV4BabylonConfig.requireDeployer(config, deployer);
    BatchReports.SpokeInstanceBatchReport memory report = AaveV4BabylonSpokeDeployment.deploy({
      config: config,
      deployer: deployer,
      accessManager: accessManager
    });
    vm.stopBroadcast();

    _writeReport(config, report);
  }

  /// @dev Reads the AccessManager from the report and reverts unless every Hub of the report is
  /// under it and the report has no BabylonSpoke yet.
  function _readAccessManager(
    AaveV4BabylonConfig.Config memory config,
    string memory json
  ) internal view returns (address accessManager) {
    accessManager = vm.parseJsonAddress(json, '.accessManager');
    require(accessManager.code.length > 0, 'access manager code');
    for (uint256 i; i < config.hubLabels.length; ++i) {
      address hub = vm.parseJsonAddress(json, string.concat('.hub.', config.hubLabels[i]));
      require(IAccessManaged(hub).authority() == accessManager, 'hub authority');
    }
    require(
      !vm.keyExistsJson(json, string.concat('.babylonSpoke.', config.babylonSpokeLabel)),
      'babylon spoke already in report'
    );
  }

  /// @dev Writes a copy of the report with the BabylonSpoke, its implementation and its oracle, keyed
  /// by the BabylonSpoke label as the single-step market deployment does.
  function _writeReport(
    AaveV4BabylonConfig.Config memory config,
    BatchReports.SpokeInstanceBatchReport memory report
  ) internal {
    string memory path = _outputReport();
    string memory label = config.babylonSpokeLabel;
    vm.createDir(OUTPUT_DIR, true);
    vm.writeFile(path, vm.readFile(config.report));
    vm.writeJson(
      vm.serializeAddress('babylonSpoke', label, report.spokeProxy),
      path,
      '.babylonSpoke'
    );
    vm.writeJson(
      vm.serializeAddress('babylonSpokeImplementation', label, report.spokeImplementation),
      path,
      '.babylonSpokeImplementation'
    );
    vm.writeJson(vm.serializeAddress('oracle', label, report.aaveOracle), path, '.oracle');
    console.log('report written to %s', path);
  }

  function _outputReport() internal virtual returns (string memory) {
    return string.concat(OUTPUT_DIR, 'babylon-spoke-', vm.toString(vm.unixTime() / 1000), '.json');
  }

  /// @dev Reverts unless the liquidation manager is the AaveAdapter proxy Babylon deploys through
  /// CreateX's permissioned CREATE3 from `liquidationManagerDeployer` with `liquidationManagerSalt`.
  /// The salt derivation follows Babylon's `AaveAdapterScript`. On Ethereum the check is mandatory.
  function _requireLiquidationManager(
    AaveV4BabylonConfig.Config memory config
  ) internal view virtual {
    address deployer = config.liquidationManagerDeployer;
    if (deployer == address(0)) {
      require(block.chainid != 1, 'liquidation manager deployer unset');
      return;
    }
    bytes32 salt = keccak256(
      abi.encodePacked(config.liquidationManagerSalt, 'AaveAdapter', '_proxy')
    );
    bytes32 permissionedSalt = bytes32(
      abi.encodePacked(bytes20(deployer), bytes1(0), bytes11(salt))
    );
    bytes32 guardedSalt = keccak256(
      abi.encodePacked(bytes32(uint256(uint160(deployer))), permissionedSalt)
    );
    require(
      ICreateX(CREATEX).computeCreate3Address(guardedSalt) == config.liquidationManager,
      'liquidation manager is not the createx address'
    );
  }

  function _config() internal view virtual returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read();
  }

  /// @dev Reverts unless the BabylonSpoke links the libraries deployed at `librarySalt`, so a
  /// deployment never links the libraries of another config.
  function _requireConfigLibraries(bytes32 librarySalt) internal view virtual {
    address liquidationLogic = Create2Utils.computeCreate2Address(
      librarySalt,
      vm.getCode(SpokeDeployUtils.LIQUIDATION_LOGIC_ARTIFACT)
    );
    require(liquidationLogic.code.length > 0, 'config libraries not deployed');
    address babylonLiquidationLogic = Create2Utils.computeCreate2Address(
      librarySalt,
      vm.getCode(SpokeDeployUtils.BABYLON_LIQUIDATION_LOGIC_ARTIFACT)
    );
    require(babylonLiquidationLogic.code.length > 0, 'config libraries not deployed');
    bytes memory babylonSpokeBytecode = BytecodeHelper.getBabylonSpokeBytecode();
    require(
      _containsAddress(babylonSpokeBytecode, liquidationLogic) &&
        _containsAddress(babylonSpokeBytecode, babylonLiquidationLogic),
      'babylon spoke links other libraries'
    );
  }

  function _containsAddress(bytes memory code, address target) internal pure returns (bool) {
    bytes20 needle = bytes20(target);
    for (uint256 i; i + 20 <= code.length; ++i) {
      bytes20 window;
      assembly ('memory-safe') {
        // keep the 20 leading bytes, the word's tail belongs to the next bytes of the code
        window := and(mload(add(add(code, 0x20), i)), not(sub(shl(96, 1), 1)))
      }
      if (window == needle) {
        return true;
      }
    }
    return false;
  }
}
