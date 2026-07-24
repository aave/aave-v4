// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

import {EtherfiCashLaunchPayload} from 'src/etherfi/EtherfiCashLaunchPayload.sol';
import {EtherfiCashActivationPayload} from 'src/etherfi/EtherfiCashActivationPayload.sol';
import {EtherfiCashOpMainnet} from 'src/etherfi/EtherfiCashOpMainnet.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

/// @title DeployEtherfiCashLaunchPayload
/// @notice Step 2 of the governance lifecycle: deploys the ether.fi Cash launch payload on
/// OP Mainnet. The deployed address is immutable — reviewers (Certora / BGD) diff the verified
/// on-chain bytecode against this source before the vote.
///
/// Usage:
///   dry run:   forge script scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol --rpc-url optimism
///   broadcast: forge script scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol --rpc-url optimism \
///              --account <keystore> --broadcast --verify
///
/// Address sources, in priority order:
///   1. Environment variables (ETHERFI_CASH_* — useful for fork rehearsals),
///   2. EtherfiCashOpMainnet constants (the reviewed, pinned values — fill at the AIP stage).
/// The script refuses to run while any instance address resolves to zero, and prints the
/// included/skipped asset roster so nothing is listed (or dropped) silently.
contract DeployEtherfiCashLaunchPayloadScript is Script {
  /// @dev CREATE2 salt; bump the suffix if a new payload version must be deployed.
  bytes32 internal constant SALT = keccak256('ETHERFI_CASH_AAVE_V4_LAUNCH_V1');

  error WrongChain(uint256 chainId);
  error MissingInstanceAddress(string name);

  function run() external returns (address payloadAddress, address activationAddress) {
    require(block.chainid == 10, WrongChain(block.chainid));

    EtherfiCashLaunchPayload.InstanceAddresses memory instance = _instanceAddresses();
    EtherfiCashLaunchPayload.AssetAddresses memory assets = _assetAddresses();

    vm.startBroadcast();
    EtherfiCashLaunchPayload payload = new EtherfiCashLaunchPayload{salt: SALT}(instance, assets);
    EtherfiCashActivationPayload activation = new EtherfiCashActivationPayload{salt: SALT}(
      IHub(instance.hub),
      IHubConfigurator(instance.hubConfigurator)
    );
    vm.stopBroadcast();

    payloadAddress = address(payload);
    activationAddress = address(activation);
    console2.log('EtherfiCashLaunchPayload (phase 1, dormant config) deployed at:', payloadAddress);
    console2.log('EtherfiCashActivationPayload (phase 2) deployed at:', activationAddress);
    _logRoster(payload);
  }

  function _instanceAddresses()
    internal
    view
    returns (EtherfiCashLaunchPayload.InstanceAddresses memory instance)
  {
    instance = EtherfiCashLaunchPayload.InstanceAddresses({
      configEngine: _required('ETHERFI_CASH_CONFIG_ENGINE', EtherfiCashOpMainnet.CONFIG_ENGINE),
      hubConfigurator: _required(
        'ETHERFI_CASH_HUB_CONFIGURATOR',
        EtherfiCashOpMainnet.HUB_CONFIGURATOR
      ),
      hub: _required('ETHERFI_CASH_HUB', EtherfiCashOpMainnet.HUB),
      spokeConfigurator: _required(
        'ETHERFI_CASH_SPOKE_CONFIGURATOR',
        EtherfiCashOpMainnet.SPOKE_CONFIGURATOR
      ),
      cashSpoke: _required('ETHERFI_CASH_SPOKE', EtherfiCashOpMainnet.CASH_SPOKE),
      irStrategy: _required('ETHERFI_CASH_IR_STRATEGY', EtherfiCashOpMainnet.IR_STRATEGY),
      feeReceiver: _required('ETHERFI_CASH_TREASURY_SPOKE', EtherfiCashOpMainnet.TREASURY_SPOKE),
      accessManager: _required('ETHERFI_CASH_ACCESS_MANAGER', EtherfiCashOpMainnet.ACCESS_MANAGER),
      ownerSafe: _required('ETHERFI_CASH_OWNER_SAFE', EtherfiCashOpMainnet.OWNER_SAFE),
      operatorSafe: _required('ETHERFI_CASH_OPERATOR_SAFE', EtherfiCashOpMainnet.OPERATOR_SAFE)
    });
  }

  function _assetAddresses()
    internal
    view
    returns (EtherfiCashLaunchPayload.AssetAddresses memory assets)
  {
    assets = EtherfiCashLaunchPayload.AssetAddresses({
      usdc: _optional('ETHERFI_CASH_USDC', EtherfiCashOpMainnet.USDC),
      usdcFeed: _optional('ETHERFI_CASH_USDC_FEED', EtherfiCashOpMainnet.USDC_FEED),
      usdt: _optional('ETHERFI_CASH_USDT', EtherfiCashOpMainnet.USDT),
      usdtFeed: _optional('ETHERFI_CASH_USDT_FEED', EtherfiCashOpMainnet.USDT_FEED),
      eurc: _optional('ETHERFI_CASH_EURC', EtherfiCashOpMainnet.EURC),
      eurcFeed: _optional('ETHERFI_CASH_EURC_FEED', EtherfiCashOpMainnet.EURC_FEED),
      frxUsd: _optional('ETHERFI_CASH_FRXUSD', EtherfiCashOpMainnet.FRXUSD),
      frxUsdFeed: _optional('ETHERFI_CASH_FRXUSD_FEED', EtherfiCashOpMainnet.FRXUSD_FEED),
      weth: _optional('ETHERFI_CASH_WETH', EtherfiCashOpMainnet.WETH),
      wethFeed: _optional('ETHERFI_CASH_WETH_FEED', EtherfiCashOpMainnet.WETH_FEED),
      weEth: _optional('ETHERFI_CASH_WEETH', EtherfiCashOpMainnet.WEETH),
      weEthFeed: _optional('ETHERFI_CASH_WEETH_FEED', EtherfiCashOpMainnet.WEETH_FEED),
      eBtc: _optional('ETHERFI_CASH_EBTC', EtherfiCashOpMainnet.EBTC),
      eBtcFeed: _optional('ETHERFI_CASH_EBTC_FEED', EtherfiCashOpMainnet.EBTC_FEED),
      eUsd: _optional('ETHERFI_CASH_EUSD', EtherfiCashOpMainnet.EUSD),
      eUsdFeed: _optional('ETHERFI_CASH_EUSD_FEED', EtherfiCashOpMainnet.EUSD_FEED),
      ethfi: _optional('ETHERFI_CASH_ETHFI', EtherfiCashOpMainnet.ETHFI),
      ethfiFeed: _optional('ETHERFI_CASH_ETHFI_FEED', EtherfiCashOpMainnet.ETHFI_FEED),
      sEthfi: _optional('ETHERFI_CASH_SETHFI', EtherfiCashOpMainnet.SETHFI),
      sEthfiFeed: _optional('ETHERFI_CASH_SETHFI_FEED', EtherfiCashOpMainnet.SETHFI_FEED),
      op: _optional('ETHERFI_CASH_OP', EtherfiCashOpMainnet.OP),
      opFeed: _optional('ETHERFI_CASH_OP_FEED', EtherfiCashOpMainnet.OP_FEED),
      wHype: _optional('ETHERFI_CASH_WHYPE', EtherfiCashOpMainnet.WHYPE),
      wHypeFeed: _optional('ETHERFI_CASH_WHYPE_FEED', EtherfiCashOpMainnet.WHYPE_FEED),
      beHype: _optional('ETHERFI_CASH_BEHYPE', EtherfiCashOpMainnet.BEHYPE),
      beHypeFeed: _optional('ETHERFI_CASH_BEHYPE_FEED', EtherfiCashOpMainnet.BEHYPE_FEED),
      liquidEth: _optional('ETHERFI_CASH_LIQUID_ETH', EtherfiCashOpMainnet.LIQUID_ETH),
      liquidEthFeed: _optional('ETHERFI_CASH_LIQUID_ETH_FEED', EtherfiCashOpMainnet.LIQUID_ETH_FEED),
      liquidBtc: _optional('ETHERFI_CASH_LIQUID_BTC', EtherfiCashOpMainnet.LIQUID_BTC),
      liquidBtcFeed: _optional('ETHERFI_CASH_LIQUID_BTC_FEED', EtherfiCashOpMainnet.LIQUID_BTC_FEED),
      liquidUsd: _optional('ETHERFI_CASH_LIQUID_USD', EtherfiCashOpMainnet.LIQUID_USD),
      liquidUsdFeed: _optional('ETHERFI_CASH_LIQUID_USD_FEED', EtherfiCashOpMainnet.LIQUID_USD_FEED),
      liquidReserve: _optional('ETHERFI_CASH_LIQUID_RESERVE', EtherfiCashOpMainnet.LIQUID_RESERVE),
      liquidReserveFeed: _optional(
        'ETHERFI_CASH_LIQUID_RESERVE_FEED',
        EtherfiCashOpMainnet.LIQUID_RESERVE_FEED
      ),
      weEur: _optional('ETHERFI_CASH_WEEUR', EtherfiCashOpMainnet.WEEUR),
      weEurFeed: _optional('ETHERFI_CASH_WEEUR_FEED', EtherfiCashOpMainnet.WEEUR_FEED),
      liquidRwa: _optional('ETHERFI_CASH_LIQUID_RWA', EtherfiCashOpMainnet.LIQUID_RWA),
      liquidRwaFeed: _optional('ETHERFI_CASH_LIQUID_RWA_FEED', EtherfiCashOpMainnet.LIQUID_RWA_FEED)
    });
  }

  function _required(string memory envKey, address pinned) internal view returns (address a) {
    a = vm.envOr(envKey, pinned);
    require(a != address(0), MissingInstanceAddress(envKey));
  }

  function _optional(string memory envKey, address pinned) internal view returns (address) {
    return vm.envOr(envKey, pinned);
  }

  function _logRoster(EtherfiCashLaunchPayload payload) internal view {
    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    console2.log('assets included in this payload:', specs.length, 'of 19');
    for (uint256 i; i < specs.length; i++) {
      console2.log(
        string.concat(
          '  ',
          vm.toString(specs[i].underlying),
          specs[i].borrowable ? '  borrowable' : '  collateral-only',
          '  CF(bps):',
          vm.toString(specs[i].collateralFactor),
          '  addCap:',
          vm.toString(specs[i].addCap),
          '  drawCap:',
          vm.toString(specs[i].drawCap)
        )
      );
    }
    if (specs.length < 19) {
      console2.log(
        'WARNING: assets skipped (underlying or feed unset) - they will need a follow-up payload'
      );
    }
  }
}
