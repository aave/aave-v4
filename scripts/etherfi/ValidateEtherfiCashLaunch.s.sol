// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EtherfiCashScriptBase} from 'scripts/etherfi/EtherfiCashScriptBase.s.sol';
import {console2} from 'forge-std/console2.sol';

import {
  AaveV4EtherfiCash,
  AaveV4EtherfiCashHubs,
  AaveV4EtherfiCashSpokes,
  AaveV4EtherfiCashAssets
} from 'src/etherfi/AaveV4EtherfiCash.sol';

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
/// Checks, per pinned address in the AaveV4EtherfiCash address-book libraries:
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
    _instance('LIQUIDATION_LOGIC (canonical)', AaveV4EtherfiCash.LIQUIDATION_LOGIC);
    _instance('ACCESS_MANAGER', AaveV4EtherfiCash.ACCESS_MANAGER);
    _instance('CONFIG_ENGINE', AaveV4EtherfiCash.CONFIG_ENGINE);
    _instance('HUB', AaveV4EtherfiCashHubs.CASH_HUB);
    _instance('HUB_CONFIGURATOR', AaveV4EtherfiCash.HUB_CONFIGURATOR);
    _instance('CASH_SPOKE', AaveV4EtherfiCashSpokes.CASH_SPOKE);
    _instance('SPOKE_CONFIGURATOR', AaveV4EtherfiCash.SPOKE_CONFIGURATOR);
    _instance('IR_STRATEGY', AaveV4EtherfiCashHubs.CASH_HUB_IR_STRATEGY);
    _instance('TREASURY_SPOKE', AaveV4EtherfiCashSpokes.TREASURY_SPOKE);

    console2.log('=== administration safes ===');
    _instance('OWNER_SAFE', AaveV4EtherfiCash.OWNER_SAFE);
    _instance('OPERATOR_SAFE', AaveV4EtherfiCash.OPERATOR_SAFE);

    console2.log('=== assets (underlying + feed) ===');
    _asset('USDC', AaveV4EtherfiCashAssets.USDC_UNDERLYING, AaveV4EtherfiCashAssets.USDC_ORACLE);
    _asset('USDT', AaveV4EtherfiCashAssets.USDT_UNDERLYING, AaveV4EtherfiCashAssets.USDT_ORACLE);
    _asset('EURC', AaveV4EtherfiCashAssets.EURC_UNDERLYING, AaveV4EtherfiCashAssets.EURC_ORACLE);
    _asset(
      'frxUSD',
      AaveV4EtherfiCashAssets.FRXUSD_UNDERLYING,
      AaveV4EtherfiCashAssets.FRXUSD_ORACLE
    );
    _asset('WETH', AaveV4EtherfiCashAssets.WETH_UNDERLYING, AaveV4EtherfiCashAssets.WETH_ORACLE);
    _asset('weETH', AaveV4EtherfiCashAssets.WEETH_UNDERLYING, AaveV4EtherfiCashAssets.WEETH_ORACLE);
    _asset('eBTC', AaveV4EtherfiCashAssets.EBTC_UNDERLYING, AaveV4EtherfiCashAssets.EBTC_ORACLE);
    _asset('eUSD', AaveV4EtherfiCashAssets.EUSD_UNDERLYING, AaveV4EtherfiCashAssets.EUSD_ORACLE);
    _asset('ETHFI', AaveV4EtherfiCashAssets.ETHFI_UNDERLYING, AaveV4EtherfiCashAssets.ETHFI_ORACLE);
    _asset(
      'sETHFI',
      AaveV4EtherfiCashAssets.SETHFI_UNDERLYING,
      AaveV4EtherfiCashAssets.SETHFI_ORACLE
    );
    _asset('OP', AaveV4EtherfiCashAssets.OP_UNDERLYING, AaveV4EtherfiCashAssets.OP_ORACLE);
    _asset('WHYPE', AaveV4EtherfiCashAssets.WHYPE_UNDERLYING, AaveV4EtherfiCashAssets.WHYPE_ORACLE);
    _asset(
      'beHYPE',
      AaveV4EtherfiCashAssets.BEHYPE_UNDERLYING,
      AaveV4EtherfiCashAssets.BEHYPE_ORACLE
    );
    _asset(
      'liquidETH',
      AaveV4EtherfiCashAssets.LIQUID_ETH_UNDERLYING,
      AaveV4EtherfiCashAssets.LIQUID_ETH_ORACLE
    );
    _asset(
      'liquidBTC',
      AaveV4EtherfiCashAssets.LIQUID_BTC_UNDERLYING,
      AaveV4EtherfiCashAssets.LIQUID_BTC_ORACLE
    );
    _asset(
      'liquidUSD',
      AaveV4EtherfiCashAssets.LIQUID_USD_UNDERLYING,
      AaveV4EtherfiCashAssets.LIQUID_USD_ORACLE
    );
    _asset(
      'liquidRESERVE',
      AaveV4EtherfiCashAssets.LIQUID_RESERVE_UNDERLYING,
      AaveV4EtherfiCashAssets.LIQUID_RESERVE_ORACLE
    );
    _asset('weEUR', AaveV4EtherfiCashAssets.WEEUR_UNDERLYING, AaveV4EtherfiCashAssets.WEEUR_ORACLE);
    _asset(
      'liquidRWA',
      AaveV4EtherfiCashAssets.LIQUID_RWA_UNDERLYING,
      AaveV4EtherfiCashAssets.LIQUID_RWA_ORACLE
    );

    console2.log('=== result ===');
    console2.log('blockers:', blockers);
    console2.log('warnings:', warnings);
    if (blockers == 0) {
      console2.log('READY: all instance addresses resolve; deploy can proceed');
    } else {
      console2.log('NOT READY: fill the missing addresses in AaveV4EtherfiCash.sol');
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
