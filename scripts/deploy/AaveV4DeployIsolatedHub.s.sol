// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';

/// @title AaveV4DeployIsolatedHubBase
/// @author Aave Labs
/// @notice Generic base script to deploy a standalone Hub instance (proxy + implementation + interest rate
///         strategy) intended for an isolated market. Concrete scripts override the deploy inputs, the
///         expected chain id and the deployment name for a specific market.
abstract contract AaveV4DeployIsolatedHubBase is Script {
  struct HubDeployInputs {
    address proxyAdminOwner;
    address authority;
    bytes32 salt;
  }

  /// @dev Override to provide the market-specific deploy inputs.
  function _getDeployInputs(
    address deployer
  ) internal view virtual returns (HubDeployInputs memory);

  /// @dev Override to return the expected chain id for this deployment.
  function _expectedChainId() internal view virtual returns (uint256);

  /// @dev Override to return a human-readable name for this hub deployment (used in logs).
  function _deploymentName() internal view virtual returns (string memory);

  function run() external virtual returns (BatchReports.HubInstanceBatchReport memory report) {
    require(block.chainid == _expectedChainId(), 'chain id mismatch');

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    HubDeployInputs memory inputs = _getDeployInputs(deployer);
    report = _deploy(inputs);
    vm.stopBroadcast();

    _logReport(deployer, inputs, report);
  }

  function _deploy(
    HubDeployInputs memory inputs
  ) internal returns (BatchReports.HubInstanceBatchReport memory) {
    return
      AaveV4DeployBase.deployHubInstanceBatch({
        proxyAdminOwner: inputs.proxyAdminOwner,
        authority: inputs.authority,
        hubBytecode: BytecodeHelper.getHubBytecode(),
        salt: inputs.salt
      });
  }

  function _logReport(
    address deployer,
    HubDeployInputs memory inputs,
    BatchReports.HubInstanceBatchReport memory report
  ) internal view {
    console.log(string.concat(_deploymentName(), ' deployment complete'));
    console.log('  deployer               :', deployer);
    console.log('  authority              :', inputs.authority);
    console.log('  proxyAdminOwner        :', inputs.proxyAdminOwner);
    console.log('  hubProxy               :', report.hubProxy);
    console.log('  hubImpl                :', report.hubImplementation);
    console.log('  interestRateStrategy   :', report.irStrategy);
  }
}

/// @title AaveV4DeployPendlePaxosIsolatedHub
/// @author Aave Labs
/// @notice Deploys the Pendle Paxos isolated-market Hub on Ethereum mainnet.
/// @dev Usage (FOUNDRY_LIBRARIES is not required, the Hub has no external library dependency):
///   forge clean && forge script \
///     scripts/deploy/AaveV4DeployIsolatedHub.s.sol:AaveV4DeployPendlePaxosIsolatedHub \
///     --rpc-url mainnet --account <acct> --slow (--broadcast --verify)
contract AaveV4DeployPendlePaxosIsolatedHub is AaveV4DeployIsolatedHubBase {
  uint256 internal constant _ETHEREUM_CHAIN_ID = 1;

  // AaveV4Ethereum.ACCESS_MANAGER
  // https://github.com/aave-dao/aave-address-book/blob/c48a741a10b94202f738d52a09e9c9a8bf18a67d/src/AaveV4Ethereum.sol#L8
  address public constant ACCESS_MANAGER = 0x08aE3BE30958cDd1847ec58fFfd4C451a87fDF01;
  // GovernanceV3Ethereum.EXECUTOR_LVL_1
  // https://github.com/aave-dao/aave-address-book/blob/c48a741a10b94202f738d52a09e9c9a8bf18a67d/src/GovernanceV3Ethereum.sol#L56
  address public constant EXECUTOR_LVL_1 = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

  uint256 internal constant _VERSION = 1;
  string internal constant _HUB_LABEL = 'PENDLE_PAXOS_ISOLATED_HUB';

  function hubSalt(address deployer) public view returns (bytes32) {
    bytes32 userSalt = keccak256(
      bytes(string.concat('chain ', vm.toString(block.chainid), '_version ', vm.toString(_VERSION)))
    );
    bytes32 rootSalt = AaveV4DeployOrchestration._deriveSalt(deployer, userSalt);
    return AaveV4DeployOrchestration._deriveChildSalt(rootSalt, 'hub', _HUB_LABEL);
  }

  function _getDeployInputs(
    address deployer
  ) internal view override returns (HubDeployInputs memory) {
    return
      HubDeployInputs({
        proxyAdminOwner: EXECUTOR_LVL_1,
        authority: ACCESS_MANAGER,
        salt: hubSalt(deployer)
      });
  }

  function _expectedChainId() internal pure override returns (uint256) {
    return _ETHEREUM_CHAIN_ID;
  }

  function _deploymentName() internal pure override returns (string memory) {
    return 'Pendle Paxos Isolated Hub';
  }
}
