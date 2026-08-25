// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {EngineUtils} from 'src/config-engine/libraries/EngineUtils.sol';

/// @notice Tests the AddressesProvider integration of the config engine: entry updates via the
/// dedicated action, and the requirement that Hubs and Spokes targeted by engine actions are
/// registered on the AddressesProvider.
contract AddressesProviderRegistrationTest is BaseConfigEngineTest {
  function _entryUpdate(
    string memory name,
    string memory tag,
    address addr
  ) internal pure returns (IAaveV4ConfigEngine.AddressesProviderEntryUpdate[] memory) {
    return
      _toAddressesProviderEntryUpdateArray(
        IAaveV4ConfigEngine.AddressesProviderEntryUpdate({name: name, tag: tag, addr: addr})
      );
  }

  function _unregisterHub1() internal {
    engine.executeAddressesProviderEntryUpdates(
      _entryUpdate('HUB_1', addressesProvider.CANONICAL_HUB_TAG(), address(0))
    );
  }

  function _unregisterSpoke1() internal {
    engine.executeAddressesProviderEntryUpdates(
      _entryUpdate('SPOKE_1', addressesProvider.CANONICAL_SPOKE_TAG(), address(0))
    );
  }

  // Entry updates

  function test_executeAddressesProviderEntryUpdates_registers() public {
    address configEngine = makeAddr('CONFIG_ENGINE');

    engine.executeAddressesProviderEntryUpdates(
      _entryUpdate('CONFIG_ENGINE', 'PERIPHERY', configEngine)
    );

    assertEq(addressesProvider.getAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'}), configEngine);
    assertTrue(addressesProvider.isRegistered(configEngine, 'PERIPHERY'));
  }

  function test_executeAddressesProviderEntryUpdates_unregisters() public {
    assertTrue(
      addressesProvider.isRegistered(address(hub1()), addressesProvider.CANONICAL_HUB_TAG())
    );

    _unregisterHub1();

    assertFalse(
      addressesProvider.isRegistered(address(hub1()), addressesProvider.CANONICAL_HUB_TAG())
    );
  }

  function test_executeAddressesProviderEntryUpdates_multiple() public {
    IAaveV4ConfigEngine.AddressesProviderEntryUpdate[]
      memory updates = new IAaveV4ConfigEngine.AddressesProviderEntryUpdate[](2);
    updates[0] = IAaveV4ConfigEngine.AddressesProviderEntryUpdate({
      name: 'HUB_1',
      tag: addressesProvider.CANONICAL_HUB_TAG(),
      addr: address(0)
    });
    updates[1] = IAaveV4ConfigEngine.AddressesProviderEntryUpdate({
      name: 'CORE',
      tag: addressesProvider.CANONICAL_HUB_TAG(),
      addr: address(hub1())
    });

    engine.executeAddressesProviderEntryUpdates(updates);

    assertEq(
      addressesProvider.getAddress({name: 'HUB_1', tag: addressesProvider.CANONICAL_HUB_TAG()}),
      address(0)
    );
    assertEq(
      addressesProvider.getAddress({name: 'CORE', tag: addressesProvider.CANONICAL_HUB_TAG()}),
      address(hub1())
    );
  }

  function test_executeAddressesProviderEntryUpdates_revertsWith_AddressAlreadySet() public {
    string memory tag = addressesProvider.CANONICAL_HUB_TAG();
    bytes32 id = addressesProvider.getId('HUB_1', tag);
    IAaveV4ConfigEngine.AddressesProviderEntryUpdate[] memory updates = _entryUpdate(
      'HUB_1',
      tag,
      address(hub2())
    );

    vm.expectRevert(abi.encodeWithSelector(IAddressesProvider.AddressAlreadySet.selector, id));
    engine.executeAddressesProviderEntryUpdates(updates);
  }

  function test_executeAddressesProviderEntryUpdates_revertsWith_OwnableUnauthorizedAccount()
    public
  {
    vm.prank(address(engine));
    AddressesProviderInstance(address(addressesProvider)).transferOwnership(ADMIN);
    vm.prank(ADMIN);
    AddressesProviderInstance(address(addressesProvider)).acceptOwnership();

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(engine))
    );
    engine.executeAddressesProviderEntryUpdates(
      _entryUpdate('CONFIG_ENGINE', 'PERIPHERY', makeAddr('CONFIG_ENGINE'))
    );
  }

  // Hub actions require a registered Hub

  function test_executeHubAssetListings_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubAssetListings(_toAssetListingArray(_defaultAssetListing()));
  }

  function test_executeHubAssetConfigUpdates_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(_defaultAssetConfigUpdate()));
  }

  function test_executeHubSpokeToAssetsAdditions_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    IAaveV4ConfigEngine.SpokeToAssetsAddition memory addition = IAaveV4ConfigEngine
      .SpokeToAssetsAddition({
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        spoke: address(spoke1()),
        assets: new IAaveV4ConfigEngine.SpokeAssetConfig[](0)
      });

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  function test_executeHubSpokeConfigUpdates_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(_defaultSpokeConfigUpdate()));
  }

  function test_executeHubAssetHalts_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubAssetHalts(
      _toAssetHaltArray(
        IAaveV4ConfigEngine.AssetHalt({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          underlying: address(weth)
        })
      )
    );
  }

  function test_executeHubAssetDeactivations_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubAssetDeactivations(
      _toAssetDeactivationArray(
        IAaveV4ConfigEngine.AssetDeactivation({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          underlying: address(weth)
        })
      )
    );
  }

  function test_executeHubAssetCapsResets_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubAssetCapsResets(
      _toAssetCapsResetArray(
        IAaveV4ConfigEngine.AssetCapsReset({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          underlying: address(weth)
        })
      )
    );
  }

  function test_executeHubSpokeDeactivations_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubSpokeDeactivations(
      _toSpokeDeactivationArray(
        IAaveV4ConfigEngine.SpokeDeactivation({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          spoke: address(spoke1())
        })
      )
    );
  }

  function test_executeHubSpokeCapsResets_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeHubSpokeCapsResets(
      _toSpokeCapsResetArray(
        IAaveV4ConfigEngine.SpokeCapsReset({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          spoke: address(spoke1())
        })
      )
    );
  }

  // Spoke actions require a registered Spoke

  function test_executeSpokeReserveListings_revertsWith_CanonicalSpokeNotRegistered() public {
    _unregisterSpoke1();

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, address(spoke1()))
    );
    engine.executeSpokeReserveListings(_toReserveListingArray(_defaultReserveListing()));
  }

  function test_executeSpokeReserveListings_revertsWith_HubNotRegistered() public {
    _unregisterHub1();

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, address(hub1())));
    engine.executeSpokeReserveListings(_toReserveListingArray(_defaultReserveListing()));
  }

  function test_executeSpokeReserveConfigUpdates_revertsWith_CanonicalSpokeNotRegistered() public {
    _unregisterSpoke1();

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, address(spoke1()))
    );
    engine.executeSpokeReserveConfigUpdates(
      _toReserveConfigUpdateArray(_defaultReserveConfigUpdate())
    );
  }

  function test_executeSpokeLiquidationConfigUpdates_revertsWith_CanonicalSpokeNotRegistered()
    public
  {
    _unregisterSpoke1();

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, address(spoke1()))
    );
    engine.executeSpokeLiquidationConfigUpdates(
      _toLiquidationConfigUpdateArray(_defaultLiquidationConfigUpdate())
    );
  }

  function test_executeSpokeDynamicReserveConfigAdditions_revertsWith_CanonicalSpokeNotRegistered()
    public
  {
    _unregisterSpoke1();

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, address(spoke1()))
    );
    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(_defaultDynamicReserveConfigAddition())
    );
  }

  function test_executeSpokeDynamicReserveConfigUpdates_revertsWith_CanonicalSpokeNotRegistered()
    public
  {
    _unregisterSpoke1();

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, address(spoke1()))
    );
    engine.executeSpokeDynamicReserveConfigUpdates(
      _toDynamicReserveConfigUpdateArray(_defaultDynamicReserveConfigUpdate())
    );
  }

  function test_executeSpokePositionManagerUpdates_revertsWith_CanonicalSpokeNotRegistered()
    public
  {
    _unregisterSpoke1();

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, address(spoke1()))
    );
    engine.executeSpokePositionManagerUpdates(
      _toPositionManagerUpdateArray(_defaultPositionManagerUpdate())
    );
  }

  // Spokes attached to a Hub asset require registration

  function test_executeHubSpokeToAssetsAdditions_revertsWith_SpokeNotRegistered() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();

    IAaveV4ConfigEngine.SpokeToAssetsAddition memory addition = IAaveV4ConfigEngine
      .SpokeToAssetsAddition({
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        spoke: address(newSpoke),
        assets: new IAaveV4ConfigEngine.SpokeAssetConfig[](0)
      });

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.SpokeNotRegistered.selector, address(newSpoke))
    );
    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  // Spoke actions require the canonical Spoke tag specifically

  function test_spokeActions_revertWith_CanonicalSpokeNotRegistered_tokenizationTag() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();
    engine.executeAddressesProviderEntryUpdates(
      _entryUpdate('NEW', addressesProvider.TOKENIZATION_SPOKE_TAG(), address(newSpoke))
    );

    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();
    update.spoke = address(newSpoke);

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, address(newSpoke))
    );
    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));
  }

  function test_spokeActions_revertWith_CanonicalSpokeNotRegistered_treasuryTag() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();
    engine.executeAddressesProviderEntryUpdates(
      _entryUpdate('NEW', addressesProvider.TREASURY_SPOKE_TAG(), address(newSpoke))
    );

    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();
    update.spoke = address(newSpoke);

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, address(newSpoke))
    );
    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));
  }

  // Hub-side Spoke references accept any spoke tag

  function test_executeHubSpokeConfigUpdates_revertsWith_SpokeNotRegistered() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.spoke = address(newSpoke);

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.SpokeNotRegistered.selector, address(newSpoke))
    );
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeDeactivations_revertsWith_SpokeNotRegistered() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.SpokeNotRegistered.selector, address(newSpoke))
    );
    engine.executeHubSpokeDeactivations(
      _toSpokeDeactivationArray(
        IAaveV4ConfigEngine.SpokeDeactivation({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          spoke: address(newSpoke)
        })
      )
    );
  }

  function test_executeHubSpokeCapsResets_revertsWith_SpokeNotRegistered() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.SpokeNotRegistered.selector, address(newSpoke))
    );
    engine.executeHubSpokeCapsResets(
      _toSpokeCapsResetArray(
        IAaveV4ConfigEngine.SpokeCapsReset({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          spoke: address(newSpoke)
        })
      )
    );
  }

  function test_hubSpokeActions_allowAnySpokeTag() public {
    _seedAsset(hub1(), irStrategy1(), address(weth), 18);
    (ISpoke newSpoke, ) = _deployNewSpoke();
    engine.executeAddressesProviderEntryUpdates(
      _entryUpdate('NEW', addressesProvider.TOKENIZATION_SPOKE_TAG(), address(newSpoke))
    );

    IAaveV4ConfigEngine.SpokeAssetConfig[]
      memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](1);
    assets[0] = IAaveV4ConfigEngine.SpokeAssetConfig({
      underlying: address(weth),
      config: IHub.SpokeConfig({
        addCap: 1000,
        drawCap: 500,
        riskPremiumThreshold: 100,
        active: true,
        halted: false
      })
    });
    engine.executeHubSpokeToAssetsAdditions(
      _toSpokeToAssetsAdditionArray(
        IAaveV4ConfigEngine.SpokeToAssetsAddition({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          spoke: address(newSpoke),
          assets: assets
        })
      )
    );

    engine.executeHubSpokeDeactivations(
      _toSpokeDeactivationArray(
        IAaveV4ConfigEngine.SpokeDeactivation({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          spoke: address(newSpoke)
        })
      )
    );

    assertFalse(hub1().getSpokeConfig(0, address(newSpoke)).active);
  }

  // Register-then-act within the same flow

  function test_registerThenList() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();
    _seedAsset(hub1(), irStrategy1(), address(weth), 18);

    engine.executeAddressesProviderEntryUpdates(
      _entryUpdate('NEW', addressesProvider.CANONICAL_SPOKE_TAG(), address(newSpoke))
    );

    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();
    listing.spoke = address(newSpoke);
    listing.priceSource = _deployMockPriceFeed(newSpoke, tokenList[TOKEN_WETH].priceFeed);

    engine.executeSpokeReserveListings(_toReserveListingArray(listing));

    assertEq(newSpoke.getReserveId(address(hub1()), 0), 0);
  }

  // Tokenization spoke auto-registration

  function test_executeHubAssetListings_registersTokenizationSpoke() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1_000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Aave WETH',
      symbol: 'aWETH',
      registrationName: 'HUB1_WETH'
    });

    address expectedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(weth),
      'Aave WETH',
      'aWETH',
      PROXY_ADMIN_OWNER
    );

    engine.executeHubAssetListings(_toAssetListingArray(listing));

    assertEq(
      addressesProvider.getAddress({
        name: 'HUB1_WETH',
        tag: addressesProvider.TOKENIZATION_SPOKE_TAG()
      }),
      expectedProxy
    );
    assertTrue(
      addressesProvider.isRegistered(expectedProxy, addressesProvider.TOKENIZATION_SPOKE_TAG())
    );
  }

  function test_executeHubAssetListings_revertsWith_InvalidTokenizationSpokeConfig_whenNoRegistrationName()
    public
  {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1_000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Aave WETH',
      symbol: 'aWETH',
      registrationName: ''
    });

    vm.expectRevert(HubEngine.InvalidTokenizationSpokeConfig.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_revertsWith_InvalidTokenizationSpokeConfig_whenOnlyRegistrationName()
    public
  {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.tokenization.registrationName = 'HUB1_WETH';

    vm.expectRevert(HubEngine.InvalidTokenizationSpokeConfig.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }
}
