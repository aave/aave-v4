// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {AddressesProviderInstance} from 'src/addresses-provider/instances/AddressesProviderInstance.sol';
import {IAddressesProvider} from 'src/addresses-provider/interfaces/IAddressesProvider.sol';
import {EngineUtils} from 'src/config-engine/libraries/EngineUtils.sol';

/// @dev Wrapper to call EngineUtils library functions externally.
contract EngineUtilsHarness {
  function requireRegisteredHub(IAddressesProvider addressesProvider, address hub) external view {
    EngineUtils.requireRegisteredHub(addressesProvider, hub);
  }

  function requireRegisteredSpoke(
    IAddressesProvider addressesProvider,
    address spoke
  ) external view {
    EngineUtils.requireRegisteredSpoke(addressesProvider, spoke);
  }

  function requireRegisteredCanonicalSpoke(
    IAddressesProvider addressesProvider,
    address spoke
  ) external view {
    EngineUtils.requireRegisteredCanonicalSpoke(addressesProvider, spoke);
  }
}

contract EngineUtilsTest is Test {
  address internal HUB = makeAddr('HUB');
  address internal SPOKE = makeAddr('SPOKE');

  EngineUtilsHarness internal _harness;
  IAddressesProvider internal _provider;

  function setUp() public {
    _harness = new EngineUtilsHarness();
    _provider = IAddressesProvider(
      address(
        new TransparentUpgradeableProxy(
          address(new AddressesProviderInstance()),
          makeAddr('PROXY_ADMIN_OWNER'),
          abi.encodeCall(AddressesProviderInstance.initialize, (address(this)))
        )
      )
    );
  }

  function test_requireRegisteredHub() public {
    _provider.setCanonicalHub('CORE', HUB);
    _harness.requireRegisteredHub(_provider, HUB);
  }

  function test_requireRegisteredHub_revertsWith_HubNotRegistered() public {
    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, HUB));
    _harness.requireRegisteredHub(_provider, HUB);
  }

  function test_requireRegisteredHub_revertsWith_HubNotRegistered_otherTag() public {
    _provider.setEntry({name: 'CORE', tag: 'PERIPHERY', newAddress: HUB});

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, HUB));
    _harness.requireRegisteredHub(_provider, HUB);
  }

  function test_requireRegisteredHub_revertsWith_HubNotRegistered_spokeTag() public {
    _provider.setCanonicalSpoke('CORE', HUB);

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.HubNotRegistered.selector, HUB));
    _harness.requireRegisteredHub(_provider, HUB);
  }

  function test_requireRegisteredSpoke_canonicalTag() public {
    _provider.setCanonicalSpoke('MAIN', SPOKE);
    _harness.requireRegisteredSpoke(_provider, SPOKE);
  }

  function test_requireRegisteredSpoke_tokenizationTag() public {
    _provider.setTokenizationSpoke('MAIN', SPOKE);
    _harness.requireRegisteredSpoke(_provider, SPOKE);
  }

  function test_requireRegisteredSpoke_treasuryTag() public {
    _provider.setTreasurySpoke('MAIN', SPOKE);
    _harness.requireRegisteredSpoke(_provider, SPOKE);
  }

  function test_requireRegisteredSpoke_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(abi.encodeWithSelector(EngineUtils.SpokeNotRegistered.selector, SPOKE));
    _harness.requireRegisteredSpoke(_provider, SPOKE);
  }

  function test_requireRegisteredSpoke_revertsWith_SpokeNotRegistered_hubTag() public {
    _provider.setCanonicalHub('MAIN', SPOKE);

    vm.expectRevert(abi.encodeWithSelector(EngineUtils.SpokeNotRegistered.selector, SPOKE));
    _harness.requireRegisteredSpoke(_provider, SPOKE);
  }

  function test_requireRegisteredCanonicalSpoke() public {
    _provider.setCanonicalSpoke('MAIN', SPOKE);
    _harness.requireRegisteredCanonicalSpoke(_provider, SPOKE);
  }

  function test_requireRegisteredCanonicalSpoke_revertsWith_CanonicalSpokeNotRegistered() public {
    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, SPOKE)
    );
    _harness.requireRegisteredCanonicalSpoke(_provider, SPOKE);
  }

  function test_requireRegisteredCanonicalSpoke_revertsWith_CanonicalSpokeNotRegistered_tokenizationTag()
    public
  {
    _provider.setTokenizationSpoke('MAIN', SPOKE);

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, SPOKE)
    );
    _harness.requireRegisteredCanonicalSpoke(_provider, SPOKE);
  }

  function test_requireRegisteredCanonicalSpoke_revertsWith_CanonicalSpokeNotRegistered_treasuryTag()
    public
  {
    _provider.setTreasurySpoke('MAIN', SPOKE);

    vm.expectRevert(
      abi.encodeWithSelector(EngineUtils.CanonicalSpokeNotRegistered.selector, SPOKE)
    );
    _harness.requireRegisteredCanonicalSpoke(_provider, SPOKE);
  }
}
