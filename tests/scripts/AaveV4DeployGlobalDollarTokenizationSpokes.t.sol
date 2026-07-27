// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {AaveV4DeployGlobalDollarTokenizationSpokes} from 'scripts/deploy/AaveV4DeployTokenizationSpoke.s.sol';

contract AaveV4DeployGlobalDollarTokenizationSpokesTest is Test {
  // deprecated instances whose ProxyAdmins are owned by the PayloadsController
  address internal constant DEPRECATED_WA_GLOBAL_DOLLAR_USDC =
    0x4131E0B2E7AFeCEAf3d3b4225aA61a3B2B7535b8;
  address internal constant DEPRECATED_WA_GLOBAL_DOLLAR_USDT =
    0x8Dabe53E8cB991c57f0307F6f419E6D469b0deAA;
  address internal constant DEPRECATED_WA_GLOBAL_DOLLAR_PT_USDG =
    0x27eF1140364948A0E30E248297FfDFE5a4091ec4;
  // GovernanceV3Ethereum.PAYLOADS_CONTROLLER
  address internal constant PAYLOADS_CONTROLLER = 0xdAbad81aF85554E9ae636395611C58F7eC1aAEc5;
  // GovernanceV3Ethereum.EXECUTOR_LVL_1
  address internal constant EXECUTOR_LVL_1 = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
  // AaveV4EthereumTokenizationSpokes.CORE_USDC_TOKENIZATION_SPOKE
  address internal constant CORE_USDC_TOKENIZATION_SPOKE =
    0x531E90a2376902DE8915789Fcc1075e3B0c153E7;

  AaveV4DeployGlobalDollarTokenizationSpokes internal _script;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 25544900);
    _script = new AaveV4DeployGlobalDollarTokenizationSpokes();
  }

  function test_run_deploysTokenizationSpokes() public {
    BatchReports.TokenizationSpokeBatchReport[] memory reports = _script.run();
    assertEq(reports.length, 3);

    address[3] memory underlyings = [_script.USDC(), _script.USDT(), _script.PT_USDG_24SEP2026()];
    string[3] memory names = [
      'Wrapped Aave Global Dollar USDC',
      'Wrapped Aave Global Dollar USDT',
      'Wrapped Aave Global Dollar PT_USDG_24SEP2026'
    ];
    string[3] memory symbols = [
      'waGlobalDollarUSDC',
      'waGlobalDollarUSDT',
      'waGlobalDollarPT_USDG_24SEP2026'
    ];
    address[3] memory deprecated = [
      DEPRECATED_WA_GLOBAL_DOLLAR_USDC,
      DEPRECATED_WA_GLOBAL_DOLLAR_USDT,
      DEPRECATED_WA_GLOBAL_DOLLAR_PT_USDG
    ];

    for (uint256 i; i < reports.length; ++i) {
      address proxy = reports[i].tokenizationSpokeProxy;
      assertGt(proxy.code.length, 0);
      assertGt(reports[i].tokenizationSpokeImplementation.code.length, 0);
      assertNotEq(proxy, deprecated[i]);

      assertEq(ITokenizationSpoke(proxy).hub(), _script.GLOBAL_DOLLAR_HUB());
      assertEq(ITokenizationSpoke(proxy).asset(), underlyings[i]);
      assertEq(ITokenizationSpoke(proxy).name(), names[i]);
      assertEq(ITokenizationSpoke(proxy).symbol(), symbols[i]);

      address proxyAdminOwner = Ownable(ProxyHelper.getProxyAdmin(proxy)).owner();
      assertEq(
        proxyAdminOwner,
        _script.PROTOCOL_SECURITY_COUNCIL(),
        'ProxyAdmin owner should be the Protocol Security Council'
      );
      assertNotEq(
        proxyAdminOwner,
        PAYLOADS_CONTROLLER,
        'ProxyAdmin owner must never be the PayloadsController'
      );
      assertNotEq(
        proxyAdminOwner,
        EXECUTOR_LVL_1,
        'ProxyAdmin owner should not be the DAO executor'
      );
    }
  }

  function test_run_revertsOffMainnet_fuzz(uint64 wrongChainId) public {
    vm.assume(wrongChainId != 1);
    vm.chainId(wrongChainId);

    vm.expectRevert('chain id mismatch');
    _script.run();
  }

  function test_constantsMatchOnchainState() public view {
    assertEq(_script.GLOBAL_DOLLAR_HUB(), 0x62d63197660c080236193CA60b70E49A08E90368);

    // the intended owner is the owner of the healthy mainnet TokenizationSpoke ProxyAdmins
    assertEq(
      _script.PROTOCOL_SECURITY_COUNCIL(),
      Ownable(ProxyHelper.getProxyAdmin(CORE_USDC_TOKENIZATION_SPOKE)).owner()
    );

    // deploy inputs must match the deprecated instances they replace
    assertEq(ITokenizationSpoke(DEPRECATED_WA_GLOBAL_DOLLAR_USDC).asset(), _script.USDC());
    assertEq(ITokenizationSpoke(DEPRECATED_WA_GLOBAL_DOLLAR_USDT).asset(), _script.USDT());
    assertEq(
      ITokenizationSpoke(DEPRECATED_WA_GLOBAL_DOLLAR_PT_USDG).asset(),
      _script.PT_USDG_24SEP2026()
    );
    assertEq(
      ITokenizationSpoke(DEPRECATED_WA_GLOBAL_DOLLAR_USDC).hub(),
      _script.GLOBAL_DOLLAR_HUB()
    );
    assertEq(
      ITokenizationSpoke(DEPRECATED_WA_GLOBAL_DOLLAR_USDT).hub(),
      _script.GLOBAL_DOLLAR_HUB()
    );
    assertEq(
      ITokenizationSpoke(DEPRECATED_WA_GLOBAL_DOLLAR_PT_USDG).hub(),
      _script.GLOBAL_DOLLAR_HUB()
    );
  }

  function test_tokenizationSpokeSaltMatchesOrchestrationFormula_fuzz(
    address deployer
  ) public view {
    bytes32 orchestrationSalt = keccak256('AAVE_V4');
    bytes32 userSalt = keccak256(bytes('chain 1_version 1'));
    bytes32 expectedRoot = bytes32(bytes20(deployer)) |
      (keccak256(abi.encode(orchestrationSalt, userSalt)) >> 160);
    bytes32 expected = keccak256(
      abi.encode(expectedRoot, 'tokenization-spoke', 'waGlobalDollarUSDC')
    );

    assertEq(_script.tokenizationSpokeSalt(deployer, 'waGlobalDollarUSDC'), expected);
  }
}
