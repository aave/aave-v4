// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/tokenization-spoke/TokenizationSpoke.Base.t.sol';
import {BeaconProxy} from 'src/dependencies/openzeppelin/BeaconProxy.sol';
import {UpgradeableBeacon} from 'src/dependencies/openzeppelin/UpgradeableBeacon.sol';

contract TokenizationSpokeConfigTest is TokenizationSpokeBaseTest {
  function test_initialize_reverts_when_invalid_setup() public {
    address beacon = _deployTokenizationSpokeBeacon(ADMIN);

    address invalidUnderlying = vm.randomAddress();
    while (hub1.isUnderlyingListed(invalidUnderlying)) invalidUnderlying = vm.randomAddress();

    vm.expectRevert(IHub.AssetNotListed.selector);
    new BeaconProxy(
      beacon,
      abi.encodeCall(
        TokenizationSpokeInstance.initialize,
        (address(hub1), invalidUnderlying, SHARE_NAME, SHARE_SYMBOL)
      )
    );

    vm.expectRevert();
    new BeaconProxy(
      beacon,
      abi.encodeCall(
        TokenizationSpokeInstance.initialize,
        (address(0), vm.randomAddress(), SHARE_NAME, SHARE_SYMBOL)
      )
    );
  }

  function test_initialize_asset_correctly_set() public {
    uint256 assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    address underlying = hub1.getAsset(assetId).underlying;
    ITokenizationSpoke instance = _deployTokenizationSpoke(
      hub1,
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      ADMIN
    );
    assertEq(instance.hub(), address(hub1));
    assertEq(instance.assetId(), assetId);
    assertEq(instance.asset(), underlying);
    assertEq(instance.decimals(), hub1.getAsset(assetId).decimals);
    assertEq(instance.MAX_ALLOWED_SPOKE_CAP(), hub1.MAX_ALLOWED_SPOKE_CAP());
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
    UpgradeableBeacon beacon = UpgradeableBeacon(ProxyHelper.getBeacon(address(daiVault)));
    assertEq(beacon.owner(), ADMIN);
    assertEq(
      ProxyHelper.getProxyInitializedVersion(address(daiVault)),
      TokenizationSpokeInstance(address(daiVault)).SPOKE_REVISION()
    );
    address implementation = beacon.implementation();
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
  }
}
