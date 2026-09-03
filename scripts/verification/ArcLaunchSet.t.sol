// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ArcConfigInputs} from 'scripts/config/ArcConfigInputs.sol';
import {ArcParameters} from 'scripts/config/ArcParameters.sol';

import {Test} from 'forge-std/Test.sol';

/// @title ArcLaunchSetTest
/// @author Aave Labs
/// @notice Checks that scripts/config/arc-config.json resolves to the launch set we intend: the assets whose
///         underlying and price source are both filled in, and no others.
/// @dev The configured addresses have no code locally, so each one is etched before reading. That
///      only stands in for the code-presence check; on Arc the addresses have to be real, and an
///      adapter that is not deployed yet makes `readAssets` revert rather than list the asset.
contract ArcLaunchSetTest is Test {
  /// @dev Minimal runtime code, enough to satisfy the code-presence check.
  bytes internal constant STUB_CODE = hex'60006000f3';

  function setUp() public {
    for (uint256 i; i < ArcParameters.assetCount(); ++i) {
      (address underlying, address priceSource) = _configuredAddresses(ArcParameters.Asset(i));
      if (underlying != address(0)) vm.etch(underlying, STUB_CODE);
      if (priceSource != address(0)) vm.etch(priceSource, STUB_CODE);
    }
  }

  /// @notice All four ARFC assets now have a token and an oracle, so all four are in the launch set.
  function test_launchSetIsAllFourAssets() public view {
    ArcConfigInputs.AssetInput[] memory assets = ArcConfigInputs.readAssets();

    assertEq(assets.length, ArcParameters.assetCount(), 'launch set size');
    for (uint256 i; i < assets.length; ++i) {
      assertEq(uint256(assets[i].key), i, 'asset order follows the enum');
    }
  }

  /// @notice Every asset in the launch set carries both addresses from the config file.
  function test_launchSetAddressesMatchConfig() public view {
    ArcConfigInputs.AssetInput[] memory assets = ArcConfigInputs.readAssets();

    for (uint256 i; i < assets.length; ++i) {
      (address underlying, address priceSource) = _configuredAddresses(assets[i].key);
      string memory name = ArcParameters.symbol(assets[i].key);

      assertEq(assets[i].underlying, underlying, string.concat(name, ' underlying'));
      assertEq(assets[i].priceSource, priceSource, string.concat(name, ' price source'));
    }
  }

  /// @notice cirBTC prices off Arc's BTC/USD SVR proxy. The address the ARFC lists has no code on
  ///         Arc, as do all four of its oracle entries, so they are not used.
  function test_cirBtcUsesBtcUsdSvrProxy() public view {
    (address underlying, address priceSource) = _configuredAddresses(ArcParameters.Asset.CIRBTC);

    assertTrue(underlying != address(0), 'cirBTC token');
    assertEq(priceSource, 0x7777547914e03BCbB04Ae034942765a0dbb26aE3, 'cirBTC price source');
  }

  /// @notice The deployer is recorded, which step 5 needs to assert it holds nothing.
  function test_deployerIsSet() public view {
    assertEq(ArcConfigInputs.readDeployer(), 0x623f1C807fE1088439e129ebF3B9c92a63a0F5cD);
  }

  /// @notice wETH carries the token address supplied for Arc and Arc's ETH/USD SVR proxy.
  function test_wethIsConfigured() public view {
    (address underlying, address priceSource) = _configuredAddresses(ArcParameters.Asset.WETH);

    assertEq(underlying, 0x128cC466B61f542da60c70e3aA11c10e19B84EDB, 'wETH token');
    assertEq(priceSource, 0x2c7Dc3567b3490f53A8d32625d766834dd023F60, 'wETH price source');
  }

  /// @notice An asset whose price source is not deployed yet is refused, not listed, so the config
  ///         can carry the adapter addresses before the adapters exist.
  function test_undeployedPriceSourceIsRefused() public {
    (, address priceSource) = _configuredAddresses(ArcParameters.Asset.USDC);
    vm.etch(priceSource, '');

    vm.expectRevert(
      abi.encodeWithSelector(ArcConfigInputs.NotAContract.selector, 'USDC price source')
    );
    this.externalReadAssets();
  }

  /// @dev External entry point so the test can expect a revert from reading the config.
  function externalReadAssets() external view {
    ArcConfigInputs.readAssets();
  }

  function _configuredAddresses(
    ArcParameters.Asset asset
  ) internal view returns (address underlying, address priceSource) {
    string memory json = vm.readFile('scripts/config/arc-config.json');
    string memory path = string.concat('.assets.', ArcParameters.symbol(asset));

    underlying = vm.parseJsonAddress(json, string.concat(path, '.underlying'));
    priceSource = vm.parseJsonAddress(json, string.concat(path, '.priceSource'));
  }
}
