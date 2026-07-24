// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {EtherfiCashLaunchPayload} from 'src/etherfi/EtherfiCashLaunchPayload.sol';
import {EtherfiCashOpMainnet} from 'src/etherfi/EtherfiCashOpMainnet.sol';

/// @title EtherfiCashScriptBase
/// @notice Shared base for every ether.fi Cash launch script: OP Mainnet guard, standardized
/// errors, and the instance/asset address resolution used by deploy, verify, Safe-tx and
/// launch-spec scripts.
///
/// Address sources, in priority order:
///   1. Environment variables (ETHERFI_CASH_* — useful for fork rehearsals),
///   2. EtherfiCashOpMainnet constants (the reviewed, pinned values).
abstract contract EtherfiCashScriptBase is Script {
  error WrongChain(uint256 chainId);
  error MissingInstanceAddress(string name);
  error NoCodeAtAddress(string name, address target);

  function _requireOpMainnet() internal view {
    require(block.chainid == 10, WrongChain(block.chainid));
  }

  function _requireCode(string memory name, address target) internal view {
    require(target.code.length > 0, NoCodeAtAddress(name, target));
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
}
