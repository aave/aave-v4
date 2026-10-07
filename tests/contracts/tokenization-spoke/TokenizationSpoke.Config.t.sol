// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/tokenization-spoke/TokenizationSpoke.Base.t.sol';
import {Errors} from 'src/dependencies/openzeppelin/Errors.sol';

contract TokenizationSpokeConfigTest is TokenizationSpokeBaseTest {
  function test_initialize_reverts_when_invalid_setup() public {
    address impl = address(new TokenizationSpokeInstance());
    address invalidUnderlying = vm.randomAddress();
    while (hub1.isUnderlyingListed(invalidUnderlying)) invalidUnderlying = vm.randomAddress();

    vm.expectRevert(IHub.AssetNotListed.selector);
    new TransparentUpgradeableProxy(
      impl,
      ADMIN,
      _initializeCalldata(address(hub1), invalidUnderlying)
    );

    vm.expectRevert(ITokenizationSpoke.InvalidAddress.selector);
    new TransparentUpgradeableProxy(
      impl,
      ADMIN,
      _initializeCalldata(address(0), address(tokenList.dai))
    );
  }

  function test_initialize_reverts_when_hub_has_no_code() public {
    address impl = address(new TokenizationSpokeInstance());
    address hubWithoutCode = makeAddr('hubWithoutCode');

    // the proxy constructor surfaces the empty revert from the call to a code-less hub as FailedCall
    vm.expectRevert(Errors.FailedCall.selector);
    new TransparentUpgradeableProxy(
      impl,
      ADMIN,
      _initializeCalldata(hubWithoutCode, address(tokenList.dai))
    );
  }

  function test_initialize_revertsWith_SafeCastOverflowedUintDowncast_assetId() public {
    uint256 assetId = uint256(type(uint96).max) + 1;
    vm.mockCall(
      address(hub1),
      abi.encodeCall(IHubBase.getAssetId, (address(tokenList.dai))),
      abi.encode(assetId)
    );
    vm.mockCall(
      address(hub1),
      abi.encodeCall(IHubBase.getAssetUnderlyingAndDecimals, (assetId)),
      abi.encode(address(tokenList.dai), tokenList.dai.decimals())
    );

    address impl = address(new TokenizationSpokeInstance());
    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 96, assetId)
    );
    new TransparentUpgradeableProxy(
      impl,
      ADMIN,
      _initializeCalldata(address(hub1), address(tokenList.dai))
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

  function test_implementation_holds_no_binding() public {
    TokenizationSpokeInstance impl = new TokenizationSpokeInstance();
    assertEq(impl.SPOKE_REVISION(), 2);
    assertEq(impl.hub(), address(0));
    assertEq(impl.assetId(), 0);
    assertEq(impl.asset(), address(0));
    assertEq(impl.decimals(), 0);
    assertEq(impl.MAX_ALLOWED_SPOKE_CAP(), 0);
  }

  function test_proxies_share_implementation() public {
    ITokenizationSpoke usdxVault = _deployTokenizationSpoke(
      hub1,
      address(tokenList.usdx),
      SHARE_NAME,
      SHARE_SYMBOL,
      ADMIN
    );
    assertEq(
      ProxyHelper.getImplementation(address(usdxVault)),
      ProxyHelper.getImplementation(address(daiVault))
    );
    assertEq(usdxVault.asset(), address(tokenList.usdx));
    assertEq(usdxVault.assetId(), usdxAssetId);
    assertEq(usdxVault.decimals(), tokenList.usdx.decimals());
    assertEq(daiVault.asset(), address(tokenList.dai));
    assertEq(daiVault.assetId(), daiAssetId);
    assertNotEq(usdxVault.DOMAIN_SEPARATOR(), daiVault.DOMAIN_SEPARATOR());
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
    ProxyAdmin proxyAdmin = ProxyAdmin(ProxyHelper.getProxyAdmin(address(daiVault)));
    assertEq(proxyAdmin.owner(), ADMIN);
    assertEq(proxyAdmin.UPGRADE_INTERFACE_VERSION(), '5.0.0');
    assertEq(
      ProxyHelper.getProxyInitializedVersion(address(daiVault)),
      TokenizationSpokeInstance(address(daiVault)).SPOKE_REVISION()
    );
    address implementation = ProxyHelper.getImplementation(address(daiVault));
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
  }

  function _initializeCalldata(
    address hub,
    address underlying
  ) internal pure returns (bytes memory) {
    return
      abi.encodeCall(
        TokenizationSpokeInstance.initialize,
        (hub, underlying, SHARE_NAME, SHARE_SYMBOL)
      );
  }
}
