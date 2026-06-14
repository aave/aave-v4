// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';

/// @title AaveV4DeployCorrelatedSpokeBase
/// @author Aave Labs
/// @notice Generic base script to deploy a standalone Spoke instance (proxy + implementation + AaveOracle)
///         intended for a correlated-asset market. Concrete scripts override the deploy inputs, the
///         expected chain id and the deployment name for a specific market.
/// @dev Requires FOUNDRY_LIBRARIES to be populated in .env with the LiquidationLogic library address, as
///      SpokeInstance depends on it.
abstract contract AaveV4DeployCorrelatedSpokeBase is Script {
  struct SpokeDeployInputs {
    address proxyAdminOwner;
    address authority;
    uint8 oracleDecimals;
    uint16 maxUserReservesLimit;
    bytes32 salt;
  }

  /// @dev Override to provide the market-specific deploy inputs.
  function _getDeployInputs(
    address deployer
  ) internal view virtual returns (SpokeDeployInputs memory);

  /// @dev Override to return the expected chain id for this deployment.
  function _expectedChainId() internal view virtual returns (uint256);

  /// @dev Override to return a human-readable name for this spoke deployment (used in logs).
  function _deploymentName() internal view virtual returns (string memory);

  function run() external virtual returns (BatchReports.SpokeInstanceBatchReport memory report) {
    require(block.chainid == _expectedChainId(), 'chain id mismatch');

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    SpokeDeployInputs memory inputs = _getDeployInputs(deployer);
    report = _deploy(inputs);
    vm.stopBroadcast();

    _logReport(deployer, inputs, report);
  }

  function _deploy(
    SpokeDeployInputs memory inputs
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory) {
    return
      AaveV4DeployBase.deploySpokeInstanceBatch({
        proxyAdminOwner: inputs.proxyAdminOwner,
        authority: inputs.authority,
        spokeBytecode: BytecodeHelper.getSpokeBytecode(),
        oracleDecimals: inputs.oracleDecimals,
        maxUserReservesLimit: inputs.maxUserReservesLimit,
        salt: inputs.salt
      });
  }

  function _logReport(
    address deployer,
    SpokeDeployInputs memory inputs,
    BatchReports.SpokeInstanceBatchReport memory report
  ) internal view {
    console.log(string.concat(_deploymentName(), ' deployment complete'));
    console.log('  deployer               :', deployer);
    console.log('  authority              :', inputs.authority);
    console.log('  proxyAdminOwner        :', inputs.proxyAdminOwner);
    console.log('  oracleDecimals         :', uint256(inputs.oracleDecimals));
    console.log('  maxUserReservesLimit   :', uint256(inputs.maxUserReservesLimit));
    console.log('  spokeProxy             :', report.spokeProxy);
    console.log('  spokeImpl              :', report.spokeImplementation);
    console.log('  aaveOracle             :', report.aaveOracle);
  }
}

/// @title AaveV4DeployUSDGCorrelatedSpoke
/// @author Aave Labs
/// @notice Deploys the USDG correlated-asset Spoke on Ethereum mainnet.
/// @dev Usage (make sure FOUNDRY_LIBRARIES is populated in .env with the LiquidationLogic address):
///   forge clean && forge script \
///     scripts/deploy/AaveV4DeployCorrelatedSpoke.s.sol:AaveV4DeployUSDGCorrelatedSpoke \
///     --rpc-url mainnet --account <acct> --slow (--broadcast --verify)
contract AaveV4DeployUSDGCorrelatedSpoke is AaveV4DeployCorrelatedSpokeBase {
  uint256 internal constant _ETHEREUM_CHAIN_ID = 1;

  // AaveV4Ethereum.ACCESS_MANAGER
  // https://github.com/aave-dao/aave-address-book/blob/c48a741a10b94202f738d52a09e9c9a8bf18a67d/src/AaveV4Ethereum.sol#L8
  address public constant ACCESS_MANAGER = 0x08aE3BE30958cDd1847ec58fFfd4C451a87fDF01;
  // GovernanceV3Ethereum.EXECUTOR_LVL_1
  // https://github.com/aave-dao/aave-address-book/blob/c48a741a10b94202f738d52a09e9c9a8bf18a67d/src/GovernanceV3Ethereum.sol#L56
  address public constant EXECUTOR_LVL_1 = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

  uint256 internal constant _VERSION = 1;
  string internal constant _SPOKE_LABEL = 'USDG_CORRELATED_SPOKE';

  function spokeSalt(address deployer) public view returns (bytes32) {
    bytes32 userSalt = keccak256(
      bytes(string.concat('chain ', vm.toString(block.chainid), '_version ', vm.toString(_VERSION)))
    );
    bytes32 rootSalt = AaveV4DeployOrchestration._deriveSalt(deployer, userSalt);
    return AaveV4DeployOrchestration._deriveChildSalt(rootSalt, 'spoke', _SPOKE_LABEL);
  }

  function _getDeployInputs(
    address deployer
  ) internal view override returns (SpokeDeployInputs memory) {
    return
      SpokeDeployInputs({
        proxyAdminOwner: EXECUTOR_LVL_1,
        authority: ACCESS_MANAGER,
        oracleDecimals: DeployConstants.ORACLE_DECIMALS,
        maxUserReservesLimit: DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
        salt: spokeSalt(deployer)
      });
  }

  function _expectedChainId() internal pure override returns (uint256) {
    return _ETHEREUM_CHAIN_ID;
  }

  function _deploymentName() internal pure override returns (string memory) {
    return 'USDG Correlated Spoke';
  }
}
