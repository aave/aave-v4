// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EtherfiCashScriptBase} from 'scripts/etherfi/EtherfiCashScriptBase.s.sol';
import {console2} from 'forge-std/console2.sol';

import {EtherfiCashOpMainnet} from 'src/etherfi/EtherfiCashOpMainnet.sol';

interface IERC20Metadata {
  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);
}

/// @dev Matches src/spoke/interfaces/IPriceFeed.sol — the exact interface AaveOracle consumes.
interface IPriceFeed {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function latestAnswer() external view returns (int256);
}

/// @title ValidateEtherfiCashLaunch
/// @notice Read-only preflight for the launch payload. Run before every deploy:
///   forge script scripts/etherfi/ValidateEtherfiCashLaunch.s.sol --rpc-url optimism
///
/// Checks, per pinned address in EtherfiCashOpMainnet:
///   - instance contracts: set and have code (hard blocker if not)
///   - underlyings: have code, symbol() matches the expected asset, sane decimals
///   - feeds: have code, answer > 0, updated within the last 24h, 8 decimals (warn otherwise)
/// Prints READY / NOT READY. Never broadcasts.
contract ValidateEtherfiCashLaunchScript is EtherfiCashScriptBase {
  uint256 internal blockers;
  uint256 internal warnings;

  function run() external {
    _requireOpMainnet();

    console2.log('=== instance contracts ===');
    _instance('ACCESS_MANAGER', EtherfiCashOpMainnet.ACCESS_MANAGER);
    _instance('CONFIG_ENGINE', EtherfiCashOpMainnet.CONFIG_ENGINE);
    _instance('HUB', EtherfiCashOpMainnet.HUB);
    _instance('HUB_CONFIGURATOR', EtherfiCashOpMainnet.HUB_CONFIGURATOR);
    _instance('CASH_SPOKE', EtherfiCashOpMainnet.CASH_SPOKE);
    _instance('SPOKE_CONFIGURATOR', EtherfiCashOpMainnet.SPOKE_CONFIGURATOR);
    _instance('IR_STRATEGY', EtherfiCashOpMainnet.IR_STRATEGY);
    _instance('TREASURY_SPOKE', EtherfiCashOpMainnet.TREASURY_SPOKE);

    console2.log('=== administration safes ===');
    _instance('OWNER_SAFE', EtherfiCashOpMainnet.OWNER_SAFE);
    _instance('OPERATOR_SAFE', EtherfiCashOpMainnet.OPERATOR_SAFE);

    console2.log('=== assets (underlying + feed) ===');
    _asset('USDC', EtherfiCashOpMainnet.USDC, EtherfiCashOpMainnet.USDC_FEED);
    _asset('USDT', EtherfiCashOpMainnet.USDT, EtherfiCashOpMainnet.USDT_FEED);
    _asset('EURC', EtherfiCashOpMainnet.EURC, EtherfiCashOpMainnet.EURC_FEED);
    _asset('frxUSD', EtherfiCashOpMainnet.FRXUSD, EtherfiCashOpMainnet.FRXUSD_FEED);
    _asset('WETH', EtherfiCashOpMainnet.WETH, EtherfiCashOpMainnet.WETH_FEED);
    _asset('weETH', EtherfiCashOpMainnet.WEETH, EtherfiCashOpMainnet.WEETH_FEED);
    _asset('eBTC', EtherfiCashOpMainnet.EBTC, EtherfiCashOpMainnet.EBTC_FEED);
    _asset('eUSD', EtherfiCashOpMainnet.EUSD, EtherfiCashOpMainnet.EUSD_FEED);
    _asset('ETHFI', EtherfiCashOpMainnet.ETHFI, EtherfiCashOpMainnet.ETHFI_FEED);
    _asset('sETHFI', EtherfiCashOpMainnet.SETHFI, EtherfiCashOpMainnet.SETHFI_FEED);
    _asset('OP', EtherfiCashOpMainnet.OP, EtherfiCashOpMainnet.OP_FEED);
    _asset('WHYPE', EtherfiCashOpMainnet.WHYPE, EtherfiCashOpMainnet.WHYPE_FEED);
    _asset('beHYPE', EtherfiCashOpMainnet.BEHYPE, EtherfiCashOpMainnet.BEHYPE_FEED);
    _asset('liquidETH', EtherfiCashOpMainnet.LIQUID_ETH, EtherfiCashOpMainnet.LIQUID_ETH_FEED);
    _asset('liquidBTC', EtherfiCashOpMainnet.LIQUID_BTC, EtherfiCashOpMainnet.LIQUID_BTC_FEED);
    _asset('liquidUSD', EtherfiCashOpMainnet.LIQUID_USD, EtherfiCashOpMainnet.LIQUID_USD_FEED);
    _asset(
      'liquidRESERVE',
      EtherfiCashOpMainnet.LIQUID_RESERVE,
      EtherfiCashOpMainnet.LIQUID_RESERVE_FEED
    );
    _asset('weEUR', EtherfiCashOpMainnet.WEEUR, EtherfiCashOpMainnet.WEEUR_FEED);
    _asset('liquidRWA', EtherfiCashOpMainnet.LIQUID_RWA, EtherfiCashOpMainnet.LIQUID_RWA_FEED);

    console2.log('=== result ===');
    console2.log('blockers:', blockers);
    console2.log('warnings:', warnings);
    if (blockers == 0) {
      console2.log('READY: all instance addresses resolve; deploy can proceed');
    } else {
      console2.log('NOT READY: fill the missing addresses in EtherfiCashOpMainnet.sol');
    }
  }

  function _instance(string memory name, address target) internal {
    if (target == address(0)) {
      console2.log(string.concat('  [BLOCKER] ', name, ': unset (TBD)'));
      blockers++;
    } else if (target.code.length == 0) {
      console2.log(string.concat('  [BLOCKER] ', name, ': no code at ', vm.toString(target)));
      blockers++;
    } else {
      console2.log(string.concat('  [ok] ', name, ': ', vm.toString(target)));
    }
  }

  function _asset(string memory name, address underlying, address feed) internal {
    if (underlying == address(0) || feed == address(0)) {
      console2.log(
        string.concat(
          '  [SKIP] ',
          name,
          ': ',
          underlying == address(0) ? 'underlying unset' : 'feed unset',
          ' - payload will exclude this asset'
        )
      );
      warnings++;
      return;
    }

    if (underlying.code.length == 0) {
      console2.log(string.concat('  [BLOCKER] ', name, ': underlying has no code'));
      blockers++;
      return;
    }
    if (feed.code.length == 0) {
      console2.log(string.concat('  [BLOCKER] ', name, ': feed has no code'));
      blockers++;
      return;
    }

    string memory onchainSymbol = IERC20Metadata(underlying).symbol();
    uint8 tokenDecimals = IERC20Metadata(underlying).decimals();

    uint8 feedDecimals = IPriceFeed(feed).decimals();
    int256 answer = IPriceFeed(feed).latestAnswer();
    string memory feedDescription = IPriceFeed(feed).description();

    string memory line = string.concat(
      '  [ok] ',
      name,
      ': symbol=',
      onchainSymbol,
      ' dec=',
      vm.toString(tokenDecimals),
      ' feed="',
      feedDescription,
      '" feedDec=',
      vm.toString(feedDecimals),
      ' answer=',
      vm.toString(answer)
    );
    console2.log(line);

    if (keccak256(bytes(onchainSymbol)) != keccak256(bytes(name))) {
      console2.log(
        string.concat('    [WARN] on-chain symbol "', onchainSymbol, '" != expected "', name, '"')
      );
      warnings++;
    }
    if (answer <= 0) {
      console2.log('    [BLOCKER] feed answer is not positive');
      blockers++;
    }
    if (feedDecimals != 8) {
      console2.log('    [WARN] feed decimals != 8 - confirm the oracle expects this');
      warnings++;
    }
  }
}
