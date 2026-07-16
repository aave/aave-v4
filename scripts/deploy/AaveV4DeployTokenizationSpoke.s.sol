// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

/// @title AaveV4DeployTokenizationSpokeBase
/// @author Aave Labs
/// @notice Generic base script to deploy standalone TokenizationSpoke instances (proxy + implementation)
///         for existing Hubs. Concrete scripts override the deploy inputs, the expected chain id and the
///         deployment name for a specific market. Registration on the Hub (`addSpoke`) is not part of the
///         deployment and is performed separately by governance or the Protocol Security Council.
abstract contract AaveV4DeployTokenizationSpokeBase is Script {
  struct TokenizationSpokeDeployInputs {
    address hub;
    address underlying;
    address proxyAdminOwner;
    string shareName;
    string shareSymbol;
    bytes32 salt;
  }

  /// @dev Override to provide the market-specific deploy inputs, one entry per TokenizationSpoke.
  function _getDeployInputs(
    address deployer
  ) internal view virtual returns (TokenizationSpokeDeployInputs[] memory);

  /// @dev Override to return the expected chain id for this deployment.
  function _expectedChainId() internal view virtual returns (uint256);

  /// @dev Override to return a human-readable name for this deployment (used in logs).
  function _deploymentName() internal view virtual returns (string memory);

  function run()
    external
    virtual
    returns (BatchReports.TokenizationSpokeBatchReport[] memory reports)
  {
    require(block.chainid == _expectedChainId(), 'chain id mismatch');

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    TokenizationSpokeDeployInputs[] memory inputs = _getDeployInputs(deployer);
    reports = _deploy(inputs);
    vm.stopBroadcast();

    _logReports(deployer, inputs, reports);
  }

  function _deploy(
    TokenizationSpokeDeployInputs[] memory inputs
  ) internal returns (BatchReports.TokenizationSpokeBatchReport[] memory reports) {
    reports = new BatchReports.TokenizationSpokeBatchReport[](inputs.length);
    for (uint256 i; i < inputs.length; ++i) {
      reports[i] = AaveV4DeployBase.deployTokenizationSpokeBatch({
        hub: inputs[i].hub,
        underlying: inputs[i].underlying,
        proxyAdminOwner: inputs[i].proxyAdminOwner,
        shareName: inputs[i].shareName,
        shareSymbol: inputs[i].shareSymbol,
        salt: inputs[i].salt
      });
    }
  }

  function _logReports(
    address deployer,
    TokenizationSpokeDeployInputs[] memory inputs,
    BatchReports.TokenizationSpokeBatchReport[] memory reports
  ) internal view {
    console.log(string.concat(_deploymentName(), ' deployment complete'));
    console.log('  deployer               :', deployer);
    for (uint256 i; i < reports.length; ++i) {
      console.log(string.concat('  ', inputs[i].shareSymbol));
      console.log('    hub                  :', inputs[i].hub);
      console.log('    underlying           :', inputs[i].underlying);
      console.log('    proxyAdminOwner      :', inputs[i].proxyAdminOwner);
      console.log('    tokenizationSpoke    :', reports[i].tokenizationSpokeProxy);
      console.log('    tokenizationSpokeImpl:', reports[i].tokenizationSpokeImplementation);
    }
  }
}

/// @title AaveV4DeployPaxosTokenizationSpokes
/// @author Aave Labs
/// @notice Deploys replacement TokenizationSpokes (USDC, USDT, PT_USDG_24SEP2026) for the Paxos Hub on
///         Ethereum mainnet. The previously deployed instances are deprecated as their ProxyAdmins are
///         owned by the PayloadsController and can never exercise ownership; the replacements set the
///         ProxyAdmin owner to the Protocol Security Council, matching all other mainnet
///         TokenizationSpokes. Activation on the Hub is performed separately by the Protocol Security
///         Council.
/// @dev Usage:
///   forge clean && forge script \
///     scripts/deploy/AaveV4DeployTokenizationSpoke.s.sol:AaveV4DeployPaxosTokenizationSpokes \
///     --rpc-url mainnet --account <acct> --slow (--broadcast --verify)
contract AaveV4DeployPaxosTokenizationSpokes is AaveV4DeployTokenizationSpokeBase {
  uint256 internal constant _ETHEREUM_CHAIN_ID = 1;

  // AaveV4EthereumHubs.PAXOS_HUB
  // https://github.com/aave-dao/aave-address-book/blob/7e444a1e73b538fd0b9e093e5156401d6fccca7d/src/AaveV4Ethereum.sol#L38
  address public constant PAXOS_HUB = 0x62d63197660c080236193CA60b70E49A08E90368;
  // Protocol Security Council
  // https://etherscan.io/address/0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9
  address public constant PROTOCOL_SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;

  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address public constant PT_USDG_24SEP2026 = 0xc1906aeCf868749a2DeE203F59b904c0cf212140;

  uint256 internal constant _VERSION = 1;

  function tokenizationSpokeSalt(
    address deployer,
    string memory label
  ) public view returns (bytes32) {
    bytes32 userSalt = keccak256(
      bytes(string.concat('chain ', vm.toString(block.chainid), '_version ', vm.toString(_VERSION)))
    );
    bytes32 rootSalt = AaveV4DeployOrchestration._deriveSalt(deployer, userSalt);
    return AaveV4DeployOrchestration._deriveChildSalt(rootSalt, 'tokenization-spoke', label);
  }

  function _getDeployInputs(
    address deployer
  ) internal view override returns (TokenizationSpokeDeployInputs[] memory inputs) {
    inputs = new TokenizationSpokeDeployInputs[](3);
    inputs[0] = TokenizationSpokeDeployInputs({
      hub: PAXOS_HUB,
      underlying: USDC,
      proxyAdminOwner: PROTOCOL_SECURITY_COUNCIL,
      shareName: 'Wrapped Aave Paxos USDC',
      shareSymbol: 'waPaxosUSDC',
      salt: tokenizationSpokeSalt(deployer, 'waPaxosUSDC')
    });
    inputs[1] = TokenizationSpokeDeployInputs({
      hub: PAXOS_HUB,
      underlying: USDT,
      proxyAdminOwner: PROTOCOL_SECURITY_COUNCIL,
      shareName: 'Wrapped Aave Paxos USDT',
      shareSymbol: 'waPaxosUSDT',
      salt: tokenizationSpokeSalt(deployer, 'waPaxosUSDT')
    });
    inputs[2] = TokenizationSpokeDeployInputs({
      hub: PAXOS_HUB,
      underlying: PT_USDG_24SEP2026,
      proxyAdminOwner: PROTOCOL_SECURITY_COUNCIL,
      shareName: 'Wrapped Aave Paxos PT_USDG_24SEP2026',
      shareSymbol: 'waPaxosPT_USDG_24SEP2026',
      salt: tokenizationSpokeSalt(deployer, 'waPaxosPT_USDG_24SEP2026')
    });
  }

  function _expectedChainId() internal pure override returns (uint256) {
    return _ETHEREUM_CHAIN_ID;
  }

  function _deploymentName() internal pure override returns (string memory) {
    return 'Paxos TokenizationSpokes';
  }
}
