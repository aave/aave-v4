// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {AddressesProviderInstance} from 'src/addresses-provider/instances/AddressesProviderInstance.sol';

/// @notice Tests the optional AddressesProvider registration during Hub asset and Spoke reserve
/// listings. The environment is intentionally left unseeded so the first listed asset/reserve has
/// id 0, which is the gate for registering a newly configured Hub/Spoke.
contract AddressesProviderRegistrationTest is BaseConfigEngineTest {
  IAddressesProvider internal provider;

  function setUp() public override {
    super.setUp();
    // The engine is the actor making the external calls in these tests, so it must own the provider.
    provider = _deployAddressesProvider(address(engine));
  }

  function _registration(
    IAddressesProvider addressesProvider,
    string memory name
  ) internal pure returns (IAaveV4ConfigEngine.AddressesProviderRegistration memory) {
    return
      IAaveV4ConfigEngine.AddressesProviderRegistration({
        addressesProvider: addressesProvider,
        register: true,
        name: name
      });
  }

  function _deployAddressesProvider(address owner) internal returns (IAddressesProvider) {
    return
      IAddressesProvider(
        address(
          new TransparentUpgradeableProxy(
            address(new AddressesProviderInstance()),
            ADMIN,
            abi.encodeCall(AddressesProviderInstance.initialize, (owner))
          )
        )
      );
  }

  // Hub registration

  function test_executeHubAssetListings_registersHub() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    listing.hubRegistration = _registration(provider, 'CORE');

    engine.executeHubAssetListings(_toAssetListingArray(listing));

    assertEq(hub1().getAssetId(address(weth)), 0);
    assertEq(provider.getCanonicalHub('CORE'), address(hub1()));
  }

  function test_executeHubAssetListings_registerHub_revertsWhenNotFirstAsset() public {
    IAaveV4ConfigEngine.AssetListing memory first = _defaultAssetListing();
    first.underlying = address(weth);
    engine.executeHubAssetListings(_toAssetListingArray(first));

    // usdx becomes asset id 1 on hub1, so registering the hub during its listing is rejected
    IAaveV4ConfigEngine.AssetListing memory second = _defaultAssetListing();
    second.underlying = address(usdx);
    second.hubRegistration = _registration(provider, 'CORE');

    vm.expectRevert(HubEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeHubAssetListings(_toAssetListingArray(second));
  }

  function test_executeHubAssetListings_registerHub_revertsWhenNoProvider() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    listing.hubRegistration = _registration(IAddressesProvider(address(0)), 'CORE');

    vm.expectRevert(HubEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_registerHub_revertsWhenNoName() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    listing.hubRegistration = _registration(provider, '');

    vm.expectRevert(HubEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_registerHub_revertsWhenFieldsSetWithoutRegister() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    listing.hubRegistration.name = 'CORE';

    vm.expectRevert(HubEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_registerHub_revertsWhenAlreadyRegistered() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    listing.hubRegistration = _registration(provider, 'CORE');
    engine.executeHubAssetListings(_toAssetListingArray(listing));

    // listing on another fresh hub (asset id 0) but reusing the same name reverts in the provider
    IAaveV4ConfigEngine.AssetListing memory second = _defaultAssetListing();
    second.hub = address(hub2());
    second.underlying = address(weth);
    second.irStrategy = address(irStrategy2());
    second.hubRegistration = _registration(provider, 'CORE');

    vm.expectRevert(
      abi.encodeWithSelector(
        IAddressesProvider.AddressAlreadySet.selector,
        provider.getId('CORE', provider.CANONICAL_HUB_TAG())
      )
    );
    engine.executeHubAssetListings(_toAssetListingArray(second));
  }

  // Tokenization spoke registration

  function test_executeHubAssetListings_registersTokenizationSpoke() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1_000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Aave WETH',
      symbol: 'aWETH'
    });
    listing.tokenizationSpokeRegistration = _registration(provider, 'CORE_WETH');

    address expectedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(weth),
      'Aave WETH',
      'aWETH',
      PROXY_ADMIN_OWNER
    );

    engine.executeHubAssetListings(_toAssetListingArray(listing));

    assertEq(provider.getTokenizationSpoke('CORE_WETH'), expectedProxy);
  }

  function test_executeHubAssetListings_registerTokenizationSpoke_revertsWhenNotDeployed() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    // no tokenization name/symbol => no TokenizationSpoke deployed
    listing.tokenizationSpokeRegistration = _registration(provider, 'CORE_WETH');

    vm.expectRevert(HubEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_registerTokenizationSpoke_revertsWhenFieldsSetWithoutRegister()
    public
  {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    listing.tokenizationSpokeRegistration.name = 'CORE_WETH';

    vm.expectRevert(HubEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_registersHubAndTokenizationSpoke() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(weth);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1_000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Aave WETH',
      symbol: 'aWETH'
    });
    listing.hubRegistration = _registration(provider, 'CORE');
    listing.tokenizationSpokeRegistration = _registration(provider, 'CORE_WETH');

    address expectedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(weth),
      'Aave WETH',
      'aWETH',
      PROXY_ADMIN_OWNER
    );

    engine.executeHubAssetListings(_toAssetListingArray(listing));

    assertEq(provider.getCanonicalHub('CORE'), address(hub1()));
    assertEq(provider.getTokenizationSpoke('CORE_WETH'), expectedProxy);
  }

  // Canonical spoke registration

  function test_executeSpokeReserveListings_registersSpoke() public {
    _seedAsset(hub1(), irStrategy1(), address(weth), 18);
    address priceSource = _deployMockPriceFeed(spoke1(), tokenList[TOKEN_WETH].priceFeed);

    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();
    listing.underlying = address(weth);
    listing.priceSource = priceSource;
    listing.spokeRegistration = _registration(provider, 'MAIN');

    engine.executeSpokeReserveListings(_toReserveListingArray(listing));

    assertEq(spoke1().getReserveId(address(hub1()), 0), 0);
    assertEq(provider.getCanonicalSpoke('MAIN'), address(spoke1()));
  }

  function test_executeSpokeReserveListings_registerSpoke_revertsWhenNotFirstReserve() public {
    _seedAsset(hub1(), irStrategy1(), address(weth), 18);
    _seedAsset(hub1(), irStrategy1(), address(usdx), 6);

    IAaveV4ConfigEngine.ReserveListing memory first = _defaultReserveListing();
    first.underlying = address(weth);
    first.priceSource = _deployMockPriceFeed(spoke1(), tokenList[TOKEN_WETH].priceFeed);
    engine.executeSpokeReserveListings(_toReserveListingArray(first));

    // usdx becomes reserve id 1 on spoke1, so registering the spoke during its listing is rejected
    IAaveV4ConfigEngine.ReserveListing memory second = _defaultReserveListing();
    second.underlying = address(usdx);
    second.priceSource = _deployMockPriceFeed(spoke1(), tokenList[TOKEN_USDX].priceFeed);
    second.spokeRegistration = _registration(provider, 'MAIN');

    vm.expectRevert(SpokeEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeSpokeReserveListings(_toReserveListingArray(second));
  }

  function test_executeSpokeReserveListings_registerSpoke_revertsWhenNoProvider() public {
    _seedAsset(hub1(), irStrategy1(), address(weth), 18);

    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();
    listing.underlying = address(weth);
    listing.priceSource = _deployMockPriceFeed(spoke1(), tokenList[TOKEN_WETH].priceFeed);
    listing.spokeRegistration = _registration(IAddressesProvider(address(0)), 'MAIN');

    vm.expectRevert(SpokeEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }

  function test_executeSpokeReserveListings_registerSpoke_revertsWhenNoName() public {
    _seedAsset(hub1(), irStrategy1(), address(weth), 18);

    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();
    listing.underlying = address(weth);
    listing.priceSource = _deployMockPriceFeed(spoke1(), tokenList[TOKEN_WETH].priceFeed);
    listing.spokeRegistration = _registration(provider, '');

    vm.expectRevert(SpokeEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }

  function test_executeSpokeReserveListings_registerSpoke_revertsWhenFieldsSetWithoutRegister()
    public
  {
    _seedAsset(hub1(), irStrategy1(), address(weth), 18);

    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();
    listing.underlying = address(weth);
    listing.priceSource = _deployMockPriceFeed(spoke1(), tokenList[TOKEN_WETH].priceFeed);
    listing.spokeRegistration.name = 'MAIN';

    vm.expectRevert(SpokeEngine.InvalidAddressesProviderRegistration.selector);
    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }
}
