// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {OwnableUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/OwnableUpgradeable.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {AddressesProvider} from 'src/addresses-provider/AddressesProvider.sol';
import {AddressesProviderInstance} from 'src/addresses-provider/instances/AddressesProviderInstance.sol';
import {IAddressesProvider} from 'src/addresses-provider/interfaces/IAddressesProvider.sol';

contract AddressesProviderTest is Test {
  address internal OWNER = makeAddr('OWNER');
  address internal PROXY_ADMIN_OWNER = makeAddr('PROXY_ADMIN_OWNER');

  AddressesProvider internal provider;

  function setUp() public {
    provider = AddressesProvider(
      address(
        new TransparentUpgradeableProxy(
          address(new AddressesProviderInstance()),
          PROXY_ADMIN_OWNER,
          abi.encodeCall(AddressesProviderInstance.initialize, (OWNER))
        )
      )
    );
  }

  function _id(string memory name, string memory tag) internal pure returns (bytes32) {
    return keccak256(abi.encode(name, tag));
  }

  function test_initialize() public view {
    assertEq(provider.owner(), OWNER);
    assertEq(provider.CANONICAL_HUB_TAG(), 'CANONICAL_HUB');
    assertEq(provider.CANONICAL_SPOKE_TAG(), 'CANONICAL_SPOKE');
    assertEq(provider.TOKENIZATION_SPOKE_TAG(), 'TOKENIZATION_SPOKE');
    assertEq(provider.TREASURY_SPOKE_TAG(), 'TREASURY_SPOKE');
  }

  function test_transferOwnership_twoStep() public {
    address newOwner = makeAddr('NEW_OWNER');

    vm.prank(OWNER);
    provider.transferOwnership(newOwner);

    assertEq(provider.owner(), OWNER);
    assertEq(provider.pendingOwner(), newOwner);

    vm.prank(newOwner);
    provider.acceptOwnership();

    assertEq(provider.owner(), newOwner);
    assertEq(provider.pendingOwner(), address(0));
  }

  function test_getId() public view {
    assertEq(
      provider.getId({name: 'CORE', tag: provider.CANONICAL_HUB_TAG()}),
      keccak256(abi.encode('CORE', 'CANONICAL_HUB'))
    );
    assertEq(
      provider.getId({name: 'MAIN', tag: provider.CANONICAL_SPOKE_TAG()}),
      keccak256(abi.encode('MAIN', 'CANONICAL_SPOKE'))
    );
    assertEq(
      provider.getId({name: 'CORE_WETH', tag: provider.TOKENIZATION_SPOKE_TAG()}),
      keccak256(abi.encode('CORE_WETH', 'TOKENIZATION_SPOKE'))
    );
    assertEq(
      provider.getId({name: 'MAIN', tag: provider.TREASURY_SPOKE_TAG()}),
      keccak256(abi.encode('MAIN', 'TREASURY_SPOKE'))
    );
  }

  function test_setEntry() public {
    bytes32 id = _id('CONFIG_ENGINE', 'PERIPHERY');
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.expectEmit(address(provider));
    emit IAddressesProvider.SetEntry(id, 'CONFIG_ENGINE', 'PERIPHERY', address(0), configEngine);

    vm.prank(OWNER);
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});

    assertEq(provider.getAddress(id), configEngine);
    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'}), configEngine);

    IAddressesProvider.Entry memory entry = provider.getEntry(id);
    assertEq(entry.addr, configEngine);
    assertEq(entry.name, 'CONFIG_ENGINE');
    assertEq(entry.tag, 'PERIPHERY');

    bytes32[] memory ids = provider.getIds('PERIPHERY');
    assertEq(ids.length, 1);
    assertEq(ids[0], id);

    string[] memory tags = provider.getTags();
    assertEq(tags.length, 1);
    assertEq(tags[0], 'PERIPHERY');

    bytes32[] memory addressIds = provider.getAddressIds(configEngine);
    assertEq(addressIds.length, 1);
    assertEq(addressIds[0], id);
  }

  function test_setEntry_remove() public {
    bytes32 id = _id('CONFIG_ENGINE', 'PERIPHERY');
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    vm.stopPrank();

    assertEq(provider.getAddress(id), address(0));
    assertEq(provider.getEntry(id).tag, '');
    assertEq(provider.getEntry(id).name, '');
    assertEq(provider.getIds('PERIPHERY').length, 0);
    assertEq(provider.getTags().length, 0);
    assertEq(provider.getAddressIds(configEngine).length, 0);
  }

  function test_setEntry_removeThenSet() public {
    bytes32 id = _id('CONFIG_ENGINE', 'PERIPHERY');
    address newConfigEngine = makeAddr('NEW_CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setEntry({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('CONFIG_ENGINE')
    });
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: newConfigEngine});
    vm.stopPrank();

    assertEq(provider.getAddress(id), newConfigEngine);

    bytes32[] memory ids = provider.getIds('PERIPHERY');
    assertEq(ids.length, 1);
    assertEq(ids[0], id);
  }

  function test_setEntry_revertsWith_AddressAlreadySet() public {
    bytes32 id = _id('CONFIG_ENGINE', 'PERIPHERY');
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});

    vm.expectRevert(abi.encodeWithSelector(IAddressesProvider.AddressAlreadySet.selector, id));
    provider.setEntry({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('NEW_CONFIG_ENGINE')
    });

    vm.expectRevert(abi.encodeWithSelector(IAddressesProvider.AddressAlreadySet.selector, id));
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    vm.stopPrank();
  }

  function test_setEntry_noIdCollision() public {
    // With abi.encode, ('A_B', 'C') and ('A', 'B_C') resolve to distinct identifiers.
    bytes32 firstId = _id('A_B', 'C');
    bytes32 secondId = _id('A', 'B_C');
    assertNotEq(firstId, secondId);
    assertEq(provider.getId({name: 'A_B', tag: 'C'}), firstId);
    assertEq(provider.getId({name: 'A', tag: 'B_C'}), secondId);

    address first = makeAddr('FIRST');
    address second = makeAddr('SECOND');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'A_B', tag: 'C', newAddress: first});
    provider.setEntry({name: 'A', tag: 'B_C', newAddress: second});
    vm.stopPrank();

    assertEq(provider.getAddress({name: 'A_B', tag: 'C'}), first);
    assertEq(provider.getAddress({name: 'A', tag: 'B_C'}), second);
  }

  function test_setEntry_sameAddressUnderMultipleIds() public {
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    provider.setEntry({name: 'ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'ENGINE', newAddress: configEngine});
    provider.setEntry({name: 'V3_CONFIG_ENGINE', tag: 'V3_PERIPHERY', newAddress: configEngine});
    vm.stopPrank();

    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'}), configEngine);
    assertEq(provider.getAddress({name: 'ENGINE', tag: 'PERIPHERY'}), configEngine);
    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'ENGINE'}), configEngine);
    assertEq(provider.getAddress({name: 'V3_CONFIG_ENGINE', tag: 'V3_PERIPHERY'}), configEngine);

    bytes32[] memory peripheryIds = provider.getIds('PERIPHERY');
    assertEq(peripheryIds.length, 2);
    assertEq(peripheryIds[0], _id('CONFIG_ENGINE', 'PERIPHERY'));
    assertEq(peripheryIds[1], _id('ENGINE', 'PERIPHERY'));

    string[] memory tags = provider.getTags();
    assertEq(tags.length, 3);
    assertEq(tags[0], 'PERIPHERY');
    assertEq(tags[1], 'ENGINE');
    assertEq(tags[2], 'V3_PERIPHERY');

    // the reverse map tracks every identifier the address is registered under
    assertEq(provider.getAddressIdCount(configEngine), 4);
    bytes32[] memory addressIds = provider.getAddressIds(configEngine);
    assertEq(addressIds.length, 4);
    assertEq(addressIds[0], _id('CONFIG_ENGINE', 'PERIPHERY'));
    assertEq(addressIds[1], _id('ENGINE', 'PERIPHERY'));
    assertEq(addressIds[2], _id('CONFIG_ENGINE', 'ENGINE'));
    assertEq(addressIds[3], _id('V3_CONFIG_ENGINE', 'V3_PERIPHERY'));

    IAddressesProvider.Entry[] memory entries = provider.getEntries(configEngine);
    assertEq(entries.length, 4);
    assertEq(entries[0].name, 'CONFIG_ENGINE');
    assertEq(entries[0].tag, 'PERIPHERY');
    assertEq(entries[0].addr, configEngine);
    assertEq(entries[3].name, 'V3_CONFIG_ENGINE');
    assertEq(entries[3].tag, 'V3_PERIPHERY');

    // removing one entry does not affect the other entries of the same address
    vm.prank(OWNER);
    provider.setEntry({name: 'ENGINE', tag: 'PERIPHERY', newAddress: address(0)});

    assertEq(provider.getAddress({name: 'ENGINE', tag: 'PERIPHERY'}), address(0));
    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'}), configEngine);
    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'ENGINE'}), configEngine);
    assertEq(provider.getIds('PERIPHERY').length, 1);
    assertEq(provider.getAddressIdCount(configEngine), 3);
  }

  function test_setHubAndSpoke_sameAddressAcrossTags() public {
    address sharedSpoke = makeAddr('SHARED_SPOKE');

    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', sharedSpoke);
    provider.setTokenizationSpoke('MAIN', sharedSpoke);
    provider.setTreasurySpoke('MAIN', sharedSpoke);
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), sharedSpoke);
    assertEq(provider.getTokenizationSpoke('MAIN'), sharedSpoke);
    assertEq(provider.getTreasurySpoke('MAIN'), sharedSpoke);

    address[] memory canonicalSpokes = provider.getCanonicalSpokes();
    assertEq(canonicalSpokes.length, 1);
    assertEq(canonicalSpokes[0], sharedSpoke);

    address[] memory tokenizationSpokes = provider.getTokenizationSpokes();
    assertEq(tokenizationSpokes.length, 1);
    assertEq(tokenizationSpokes[0], sharedSpoke);

    address[] memory treasurySpokes = provider.getTreasurySpokes();
    assertEq(treasurySpokes.length, 1);
    assertEq(treasurySpokes[0], sharedSpoke);

    IAddressesProvider.Entry[] memory entries = provider.getEntries(sharedSpoke);
    assertEq(entries.length, 3);
    assertEq(entries[0].tag, 'CANONICAL_SPOKE');
    assertEq(entries[1].tag, 'TOKENIZATION_SPOKE');
    assertEq(entries[2].tag, 'TREASURY_SPOKE');
  }

  function test_setEntry_remove_revertsWith_AddressNotSet() public {
    bytes32 id = _id('CONFIG_ENGINE', 'PERIPHERY');

    vm.startPrank(OWNER);
    vm.expectRevert(abi.encodeWithSelector(IAddressesProvider.AddressNotSet.selector, id));
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});

    provider.setEntry({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('CONFIG_ENGINE')
    });
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});

    vm.expectRevert(abi.encodeWithSelector(IAddressesProvider.AddressNotSet.selector, id));
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    vm.stopPrank();
  }

  function test_setEntry_revertsWith_InvalidName() public {
    vm.expectRevert(IAddressesProvider.InvalidName.selector);
    vm.prank(OWNER);
    provider.setEntry({name: '', tag: 'PERIPHERY', newAddress: makeAddr('CONFIG_ENGINE')});
  }

  function test_setEntry_revertsWith_InvalidTag() public {
    vm.expectRevert(IAddressesProvider.InvalidTag.selector);
    vm.prank(OWNER);
    provider.setEntry({name: 'CONFIG_ENGINE', tag: '', newAddress: makeAddr('CONFIG_ENGINE')});
  }

  function test_setEntry_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = makeAddr('caller');

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    vm.prank(caller);
    provider.setEntry({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('CONFIG_ENGINE')
    });
  }

  function test_isRegistered() public {
    address configEngine = makeAddr('CONFIG_ENGINE');

    assertFalse(provider.isRegistered(configEngine, 'PERIPHERY'));

    vm.prank(OWNER);
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});

    assertTrue(provider.isRegistered(configEngine, 'PERIPHERY'));
    assertFalse(provider.isRegistered(configEngine, 'MISC'));
    assertFalse(provider.isRegistered(makeAddr('OTHER'), 'PERIPHERY'));
  }

  function test_isRegistered_multipleTags() public {
    address spoke = makeAddr('SPOKE');

    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', spoke);
    provider.setEntry({name: 'MAIN', tag: 'BABYLON', newAddress: spoke});
    vm.stopPrank();

    assertTrue(provider.isRegistered(spoke, provider.CANONICAL_SPOKE_TAG()));
    assertTrue(provider.isRegistered(spoke, 'BABYLON'));
    assertFalse(provider.isRegistered(spoke, provider.CANONICAL_HUB_TAG()));
  }

  function test_isRegistered_afterRemove() public {
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    vm.stopPrank();

    assertFalse(provider.isRegistered(configEngine, 'PERIPHERY'));
  }

  function test_setCanonicalHub() public {
    address coreHub = makeAddr('CORE_HUB');
    address plusHub = makeAddr('PLUS_HUB');
    address primeHub = makeAddr('PRIME_HUB');

    vm.startPrank(OWNER);
    vm.expectEmit(address(provider));
    emit IAddressesProvider.SetEntry(
      _id('CORE', 'CANONICAL_HUB'),
      'CORE',
      'CANONICAL_HUB',
      address(0),
      coreHub
    );
    provider.setCanonicalHub('CORE', coreHub);
    provider.setCanonicalHub('PLUS', plusHub);
    provider.setCanonicalHub('PRIME', primeHub);
    vm.stopPrank();

    assertEq(provider.getCanonicalHub('CORE'), coreHub);
    assertEq(provider.getCanonicalHub('PLUS'), plusHub);
    assertEq(provider.getCanonicalHub('PRIME'), primeHub);
    assertEq(provider.getAddress(_id('CORE', 'CANONICAL_HUB')), coreHub);

    IAddressesProvider.Entry memory entry = provider.getEntry(_id('CORE', 'CANONICAL_HUB'));
    assertEq(entry.name, 'CORE');
    assertEq(entry.tag, 'CANONICAL_HUB');

    bytes32[] memory hubIds = provider.getIds('CANONICAL_HUB');
    assertEq(hubIds.length, 3);
    assertEq(hubIds[0], _id('CORE', 'CANONICAL_HUB'));
    assertEq(hubIds[1], _id('PLUS', 'CANONICAL_HUB'));
    assertEq(hubIds[2], _id('PRIME', 'CANONICAL_HUB'));

    address[] memory hubs = provider.getCanonicalHubs();
    assertEq(hubs.length, 3);
    assertEq(hubs[0], coreHub);
    assertEq(hubs[1], plusHub);
    assertEq(hubs[2], primeHub);
    assertEq(provider.getAddresses(provider.CANONICAL_HUB_TAG()), hubs);
  }

  function test_setCanonicalHub_removeThenSet() public {
    address coreHub = makeAddr('CORE_HUB');
    address newCoreHub = makeAddr('NEW_CORE_HUB');

    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', coreHub);
    provider.setCanonicalHub('CORE', address(0));

    vm.expectEmit(address(provider));
    emit IAddressesProvider.SetEntry(
      _id('CORE', 'CANONICAL_HUB'),
      'CORE',
      'CANONICAL_HUB',
      address(0),
      newCoreHub
    );
    provider.setCanonicalHub('CORE', newCoreHub);
    vm.stopPrank();

    assertEq(provider.getCanonicalHub('CORE'), newCoreHub);
    assertEq(provider.getCanonicalHubs().length, 1);
  }

  function test_setCanonicalHub_revertsWith_AddressAlreadySet() public {
    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAddressesProvider.AddressAlreadySet.selector,
        _id('CORE', 'CANONICAL_HUB')
      )
    );
    provider.setCanonicalHub('CORE', makeAddr('NEW_CORE_HUB'));
    vm.stopPrank();
  }

  function test_setCanonicalHub_remove() public {
    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));
    provider.setCanonicalHub('PLUS', makeAddr('PLUS_HUB'));
    provider.setCanonicalHub('CORE', address(0));
    vm.stopPrank();

    assertEq(provider.getCanonicalHub('CORE'), address(0));

    address[] memory hubs = provider.getCanonicalHubs();
    assertEq(hubs.length, 1);
    assertEq(hubs[0], provider.getCanonicalHub('PLUS'));
  }

  function test_setCanonicalHub_remove_revertsWith_AddressNotSet() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAddressesProvider.AddressNotSet.selector,
        _id('CORE', 'CANONICAL_HUB')
      )
    );
    vm.prank(OWNER);
    provider.setCanonicalHub('CORE', address(0));
  }

  function test_setCanonicalHub_revertsWith_InvalidName() public {
    vm.expectRevert(IAddressesProvider.InvalidName.selector);
    vm.prank(OWNER);
    provider.setCanonicalHub('', makeAddr('CORE_HUB'));
  }

  function test_setCanonicalHub_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = makeAddr('caller');

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    vm.prank(caller);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));
  }

  function test_setCanonicalHub_fuzz(string memory name, address hub) public {
    vm.assume(bytes(name).length > 0);
    vm.assume(hub != address(0));

    vm.prank(OWNER);
    provider.setCanonicalHub(name, hub);

    assertEq(provider.getCanonicalHub(name), hub);

    address[] memory hubs = provider.getCanonicalHubs();
    assertEq(hubs.length, 1);
    assertEq(hubs[0], hub);
  }

  function test_setCanonicalSpoke() public {
    address mainSpoke = makeAddr('MAIN_SPOKE');
    address bluechipSpoke = makeAddr('BLUECHIP_SPOKE');
    address forexSpoke = makeAddr('FOREX_SPOKE');

    vm.startPrank(OWNER);
    vm.expectEmit(address(provider));
    emit IAddressesProvider.SetEntry(
      _id('MAIN', 'CANONICAL_SPOKE'),
      'MAIN',
      'CANONICAL_SPOKE',
      address(0),
      mainSpoke
    );
    provider.setCanonicalSpoke('MAIN', mainSpoke);
    provider.setCanonicalSpoke('BLUECHIP', bluechipSpoke);
    provider.setCanonicalSpoke('FOREX', forexSpoke);
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), mainSpoke);
    assertEq(provider.getCanonicalSpoke('BLUECHIP'), bluechipSpoke);
    assertEq(provider.getCanonicalSpoke('FOREX'), forexSpoke);
    assertEq(provider.getAddress(_id('MAIN', 'CANONICAL_SPOKE')), mainSpoke);

    address[] memory canonicalSpokes = provider.getCanonicalSpokes();
    assertEq(canonicalSpokes.length, 3);
    assertEq(canonicalSpokes[0], mainSpoke);
    assertEq(canonicalSpokes[1], bluechipSpoke);
    assertEq(canonicalSpokes[2], forexSpoke);
  }

  function test_setTokenizationSpoke() public {
    address coreWethSpoke = makeAddr('CORE_WETH_TOKENIZATION_SPOKE');
    address primeGhoSpoke = makeAddr('PRIME_GHO_TOKENIZATION_SPOKE');

    vm.startPrank(OWNER);
    provider.setTokenizationSpoke('CORE_WETH', coreWethSpoke);
    provider.setTokenizationSpoke('PRIME_GHO', primeGhoSpoke);
    vm.stopPrank();

    assertEq(provider.getTokenizationSpoke('CORE_WETH'), coreWethSpoke);
    assertEq(provider.getTokenizationSpoke('PRIME_GHO'), primeGhoSpoke);
    assertEq(provider.getAddress(_id('CORE_WETH', 'TOKENIZATION_SPOKE')), coreWethSpoke);

    address[] memory tokenizationSpokes = provider.getTokenizationSpokes();
    assertEq(tokenizationSpokes.length, 2);
    assertEq(tokenizationSpokes[0], coreWethSpoke);
    assertEq(tokenizationSpokes[1], primeGhoSpoke);
  }

  function test_setTreasurySpoke() public {
    address treasurySpoke = makeAddr('TREASURY_SPOKE');

    vm.prank(OWNER);
    provider.setTreasurySpoke('MAIN', treasurySpoke);

    assertEq(provider.getTreasurySpoke('MAIN'), treasurySpoke);
    assertEq(provider.getAddress(_id('MAIN', 'TREASURY_SPOKE')), treasurySpoke);

    address[] memory treasurySpokes = provider.getTreasurySpokes();
    assertEq(treasurySpokes.length, 1);
    assertEq(treasurySpokes[0], treasurySpoke);
  }

  function test_setSpoke_sameNameAcrossTags() public {
    address mainSpoke = makeAddr('MAIN_SPOKE');
    address treasurySpoke = makeAddr('TREASURY_SPOKE');

    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', mainSpoke);
    provider.setTreasurySpoke('MAIN', treasurySpoke);
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), mainSpoke);
    assertEq(provider.getTreasurySpoke('MAIN'), treasurySpoke);
  }

  function test_setSpoke_removeThenSet() public {
    address mainSpoke = makeAddr('MAIN_SPOKE');
    address newMainSpoke = makeAddr('NEW_MAIN_SPOKE');

    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', mainSpoke);
    provider.setCanonicalSpoke('MAIN', address(0));
    provider.setCanonicalSpoke('MAIN', newMainSpoke);
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), newMainSpoke);
    assertEq(provider.getCanonicalSpokes().length, 1);
  }

  function test_setSpoke_revertsWith_AddressAlreadySet() public {
    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAddressesProvider.AddressAlreadySet.selector,
        _id('MAIN', 'CANONICAL_SPOKE')
      )
    );
    provider.setCanonicalSpoke('MAIN', makeAddr('NEW_MAIN_SPOKE'));
    vm.stopPrank();
  }

  function test_setSpoke_remove() public {
    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));
    provider.setCanonicalSpoke('BLUECHIP', makeAddr('BLUECHIP_SPOKE'));
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));

    provider.setCanonicalSpoke('MAIN', address(0));
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), address(0));

    address[] memory canonicalSpokes = provider.getCanonicalSpokes();
    assertEq(canonicalSpokes.length, 1);
    assertEq(canonicalSpokes[0], provider.getCanonicalSpoke('BLUECHIP'));
    assertEq(provider.getTreasurySpokes().length, 1);
  }

  function test_setSpoke_removeLastIdOfTag() public {
    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));

    provider.setTreasurySpoke('MAIN', address(0));
    vm.stopPrank();

    assertEq(provider.getTreasurySpokes().length, 0);

    string[] memory tags = provider.getTags();
    assertEq(tags.length, 1);
    assertEq(tags[0], 'CANONICAL_SPOKE');
  }

  function test_setSpoke_remove_revertsWith_AddressNotSet() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAddressesProvider.AddressNotSet.selector,
        _id('MAIN', 'CANONICAL_SPOKE')
      )
    );
    vm.prank(OWNER);
    provider.setCanonicalSpoke('MAIN', address(0));
  }

  function test_setSpoke_revertsWith_InvalidName() public {
    vm.startPrank(OWNER);

    vm.expectRevert(IAddressesProvider.InvalidName.selector);
    provider.setCanonicalSpoke('', makeAddr('MAIN_SPOKE'));

    vm.expectRevert(IAddressesProvider.InvalidName.selector);
    provider.setTokenizationSpoke('', makeAddr('CORE_WETH_TOKENIZATION_SPOKE'));

    vm.expectRevert(IAddressesProvider.InvalidName.selector);
    provider.setTreasurySpoke('', makeAddr('TREASURY_SPOKE'));

    vm.stopPrank();
  }

  function test_setSpoke_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = makeAddr('caller');
    vm.startPrank(caller);

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    provider.setTokenizationSpoke('CORE_WETH', makeAddr('CORE_WETH_TOKENIZATION_SPOKE'));

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));

    vm.stopPrank();
  }

  function test_setSpoke_fuzz(string memory name, address spoke) public {
    vm.assume(bytes(name).length > 0);
    vm.assume(spoke != address(0));

    vm.prank(OWNER);
    provider.setCanonicalSpoke(name, spoke);

    assertEq(provider.getCanonicalSpoke(name), spoke);

    address[] memory canonicalSpokes = provider.getCanonicalSpokes();
    assertEq(canonicalSpokes.length, 1);
    assertEq(canonicalSpokes[0], spoke);
  }

  function test_getTags() public {
    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));
    provider.setTokenizationSpoke('CORE_WETH', makeAddr('CORE_WETH_TOKENIZATION_SPOKE'));
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));
    vm.stopPrank();

    assertEq(provider.getTagCount(), 4);

    string[] memory tags = provider.getTags();
    assertEq(tags.length, 4);
    assertEq(tags[0], 'CANONICAL_HUB');
    assertEq(tags[1], 'CANONICAL_SPOKE');
    assertEq(tags[2], 'TOKENIZATION_SPOKE');
    assertEq(tags[3], 'TREASURY_SPOKE');
  }

  function test_getTags_bounded() public {
    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));
    provider.setTokenizationSpoke('CORE_WETH', makeAddr('CORE_WETH_TOKENIZATION_SPOKE'));
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));
    vm.stopPrank();

    string[] memory firstTwo = provider.getTags(0, 2);
    assertEq(firstTwo.length, 2);
    assertEq(firstTwo[0], 'CANONICAL_HUB');
    assertEq(firstTwo[1], 'CANONICAL_SPOKE');

    string[] memory lastTwo = provider.getTags(2, 4);
    assertEq(lastTwo.length, 2);
    assertEq(lastTwo[0], 'TOKENIZATION_SPOKE');
    assertEq(lastTwo[1], 'TREASURY_SPOKE');

    // end is capped to the number of tags
    string[] memory clamped = provider.getTags(3, 100);
    assertEq(clamped.length, 1);
    assertEq(clamped[0], 'TREASURY_SPOKE');

    // start beyond the number of tags yields an empty slice
    assertEq(provider.getTags(10, 20).length, 0);
  }

  function test_getIds_bounded() public {
    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));
    provider.setCanonicalHub('PLUS', makeAddr('PLUS_HUB'));
    provider.setCanonicalHub('PRIME', makeAddr('PRIME_HUB'));
    vm.stopPrank();

    assertEq(provider.getIdCount('CANONICAL_HUB'), 3);

    bytes32[] memory firstTwo = provider.getIds('CANONICAL_HUB', 0, 2);
    assertEq(firstTwo.length, 2);
    assertEq(firstTwo[0], _id('CORE', 'CANONICAL_HUB'));
    assertEq(firstTwo[1], _id('PLUS', 'CANONICAL_HUB'));

    bytes32[] memory last = provider.getIds('CANONICAL_HUB', 2, 100);
    assertEq(last.length, 1);
    assertEq(last[0], _id('PRIME', 'CANONICAL_HUB'));

    assertEq(provider.getIds('CANONICAL_HUB', 5, 10).length, 0);
  }

  function test_getAddresses_bounded() public {
    address coreHub = makeAddr('CORE_HUB');
    address plusHub = makeAddr('PLUS_HUB');
    address primeHub = makeAddr('PRIME_HUB');

    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', coreHub);
    provider.setCanonicalHub('PLUS', plusHub);
    provider.setCanonicalHub('PRIME', primeHub);
    vm.stopPrank();

    address[] memory firstTwo = provider.getAddresses('CANONICAL_HUB', 0, 2);
    assertEq(firstTwo.length, 2);
    assertEq(firstTwo[0], coreHub);
    assertEq(firstTwo[1], plusHub);

    address[] memory last = provider.getAddresses('CANONICAL_HUB', 2, 100);
    assertEq(last.length, 1);
    assertEq(last[0], primeHub);
  }

  function test_getCanonicalHubs_bounded() public {
    address coreHub = makeAddr('CORE_HUB');
    address plusHub = makeAddr('PLUS_HUB');
    address primeHub = makeAddr('PRIME_HUB');

    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', coreHub);
    provider.setCanonicalHub('PLUS', plusHub);
    provider.setCanonicalHub('PRIME', primeHub);
    vm.stopPrank();

    address[] memory firstTwo = provider.getCanonicalHubs(0, 2);
    assertEq(firstTwo.length, 2);
    assertEq(firstTwo[0], coreHub);
    assertEq(firstTwo[1], plusHub);

    address[] memory last = provider.getCanonicalHubs(2, 100);
    assertEq(last.length, 1);
    assertEq(last[0], primeHub);
  }

  function test_getSpokes_bounded() public {
    address mainSpoke = makeAddr('MAIN_SPOKE');
    address extraSpoke = makeAddr('EXTRA_SPOKE');
    address tokenizationSpoke = makeAddr('TOKENIZATION_SPOKE');
    address treasurySpoke = makeAddr('TREASURY_SPOKE');

    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', mainSpoke);
    provider.setCanonicalSpoke('EXTRA', extraSpoke);
    provider.setTokenizationSpoke('CORE_WETH', tokenizationSpoke);
    provider.setTreasurySpoke('MAIN', treasurySpoke);
    vm.stopPrank();

    address[] memory canonicalSpokes = provider.getCanonicalSpokes(1, 100);
    assertEq(canonicalSpokes.length, 1);
    assertEq(canonicalSpokes[0], extraSpoke);

    address[] memory tokenizationSpokes = provider.getTokenizationSpokes(0, 100);
    assertEq(tokenizationSpokes.length, 1);
    assertEq(tokenizationSpokes[0], tokenizationSpoke);

    address[] memory treasurySpokes = provider.getTreasurySpokes(0, 100);
    assertEq(treasurySpokes.length, 1);
    assertEq(treasurySpokes[0], treasurySpoke);
  }

  function test_getAddressIds_bounded() public {
    address shared = makeAddr('SHARED');

    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', shared);
    provider.setCanonicalSpoke('MAIN', shared);
    provider.setTreasurySpoke('MAIN', shared);
    vm.stopPrank();

    assertEq(provider.getAddressIdCount(shared), 3);

    bytes32[] memory firstTwo = provider.getAddressIds(shared, 0, 2);
    assertEq(firstTwo.length, 2);
    assertEq(firstTwo[0], _id('CORE', 'CANONICAL_HUB'));
    assertEq(firstTwo[1], _id('MAIN', 'CANONICAL_SPOKE'));

    IAddressesProvider.Entry[] memory entries = provider.getEntries(shared, 1, 3);
    assertEq(entries.length, 2);
    assertEq(entries[0].tag, 'CANONICAL_SPOKE');
    assertEq(entries[1].tag, 'TREASURY_SPOKE');

    assertEq(provider.getAddressIds(shared, 5, 10).length, 0);
  }
}
