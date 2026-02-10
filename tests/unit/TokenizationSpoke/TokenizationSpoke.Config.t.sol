// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

contract TokenizationSpokeConfigTest is TokenizationSpokeBaseTest {
  function test_constructor_reverts_when_invalid_setup() public {
    uint256 invalidAssetId = vm.randomUint(hub1.getAssetCount(), UINT256_MAX);
    vm.expectRevert();
    new TokenizationSpokeInstance(address(hub1), invalidAssetId);

    vm.expectRevert();
    new TokenizationSpokeInstance(address(0), vm.randomUint());
  }

  function test_constructor_asset_correctly_set() public {
    uint256 assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    TokenizationSpokeInstance instance = new TokenizationSpokeInstance(address(hub1), assetId);
    assertEq(instance.asset(), hub1.getAsset(assetId).underlying);
    assertEq(instance.decimals(), hub1.getAsset(assetId).decimals);
  }

  function test_setUp() public {
    assertEq(daiVault.name(), SHARE_NAME);
    assertEq(daiVault.symbol(), SHARE_SYMBOL);
    assertEq(daiVault.decimals(), tokenList.dai.decimals());

    assertEq(daiVault.asset(), address(tokenList.dai));
    assertEq(daiVault.assetId(), daiAssetId);
    assertEq(daiVault.hub(), address(hub1));

    assertEq(daiVault.PERMIT_NONCE_NAMESPACE(), 0);

    assertEq(daiVault.totalAssets(), 0);
    assertEq(daiVault.totalSupply(), 0);
    assertEq(daiVault.balanceOf(vm.randomAddress()), 0);
  }

  function test_configuration() public view {
    ProxyAdmin proxyAdmin = ProxyAdmin(_getProxyAdminAddress(address(daiVault)));
    assertEq(proxyAdmin.owner(), ADMIN);
    assertEq(proxyAdmin.UPGRADE_INTERFACE_VERSION(), '5.0.0');
    assertEq(
      _getProxyInitializedVersion(address(daiVault)),
      TokenizationSpokeInstance(address(daiVault)).SPOKE_REVISION()
    );
    address implementation = _getImplementationAddress(address(daiVault));
    assertEq(_getProxyInitializedVersion(implementation), type(uint64).max);
  }
}
