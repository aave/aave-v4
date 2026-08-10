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

    assertEq(provider.getIdCount('PERIPHERY'), 1);
    assertEq(provider.getIds('PERIPHERY', 0, 1)[0], id);

    assertEq(provider.getTagCount(), 1);
    assertEq(provider.getTags(0, 1)[0], 'PERIPHERY');

    assertEq(provider.getAddressIdCount(configEngine), 1);
    assertEq(provider.getAddressIds(configEngine, 0, 1)[0], id);
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
    assertEq(provider.getIdCount('PERIPHERY'), 0);
    assertEq(provider.getTagCount(), 0);
    assertEq(provider.getAddressIdCount(configEngine), 0);
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

    assertEq(provider.getIdCount('PERIPHERY'), 1);
    assertEq(provider.getIds('PERIPHERY', 0, 1)[0], id);
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

    assertEq(provider.getIdCount('PERIPHERY'), 2);
    bytes32[] memory peripheryIds = provider.getIds('PERIPHERY', 0, 2);
    assertEq(peripheryIds[0], _id('CONFIG_ENGINE', 'PERIPHERY'));
    assertEq(peripheryIds[1], _id('ENGINE', 'PERIPHERY'));

    assertEq(provider.getTagCount(), 3);
    string[] memory tags = provider.getTags(0, 3);
    assertEq(tags[0], 'PERIPHERY');
    assertEq(tags[1], 'ENGINE');
    assertEq(tags[2], 'V3_PERIPHERY');

    // the reverse map tracks every identifier the address is registered under
    assertEq(provider.getAddressIdCount(configEngine), 4);
    bytes32[] memory addressIds = provider.getAddressIds(configEngine, 0, 4);
    assertEq(addressIds.length, 4);
    assertEq(addressIds[0], _id('CONFIG_ENGINE', 'PERIPHERY'));
    assertEq(addressIds[1], _id('ENGINE', 'PERIPHERY'));
    assertEq(addressIds[2], _id('CONFIG_ENGINE', 'ENGINE'));
    assertEq(addressIds[3], _id('V3_CONFIG_ENGINE', 'V3_PERIPHERY'));

    IAddressesProvider.Entry[] memory entries = provider.getEntries(configEngine, 0, 4);
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
    assertEq(provider.getIdCount('PERIPHERY'), 1);
    assertEq(provider.getAddressIdCount(configEngine), 3);
  }

  function test_setEntry_sameAddressAcrossTags() public {
    address sharedSpoke = makeAddr('SHARED_SPOKE');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'MAIN', tag: 'CANONICAL_SPOKE', newAddress: sharedSpoke});
    provider.setEntry({name: 'MAIN', tag: 'TOKENIZATION_SPOKE', newAddress: sharedSpoke});
    provider.setEntry({name: 'MAIN', tag: 'TREASURY_SPOKE', newAddress: sharedSpoke});
    vm.stopPrank();

    assertEq(provider.getAddress({name: 'MAIN', tag: 'CANONICAL_SPOKE'}), sharedSpoke);
    assertEq(provider.getAddress({name: 'MAIN', tag: 'TOKENIZATION_SPOKE'}), sharedSpoke);
    assertEq(provider.getAddress({name: 'MAIN', tag: 'TREASURY_SPOKE'}), sharedSpoke);

    assertEq(provider.getIdCount('CANONICAL_SPOKE'), 1);
    assertEq(provider.getAddresses('CANONICAL_SPOKE', 0, 1)[0], sharedSpoke);
    assertEq(provider.getIdCount('TOKENIZATION_SPOKE'), 1);
    assertEq(provider.getAddresses('TOKENIZATION_SPOKE', 0, 1)[0], sharedSpoke);
    assertEq(provider.getIdCount('TREASURY_SPOKE'), 1);
    assertEq(provider.getAddresses('TREASURY_SPOKE', 0, 1)[0], sharedSpoke);

    IAddressesProvider.Entry[] memory entries = provider.getEntries(sharedSpoke, 0, 3);
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
    provider.setEntry({name: 'MAIN', tag: provider.CANONICAL_SPOKE_TAG(), newAddress: spoke});
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

  function test_isRegistered_multipleEntriesSameTag() public {
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    provider.setEntry({name: 'ENGINE', tag: 'PERIPHERY', newAddress: configEngine});

    provider.setEntry({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    assertTrue(provider.isRegistered(configEngine, 'PERIPHERY'));

    provider.setEntry({name: 'ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    assertFalse(provider.isRegistered(configEngine, 'PERIPHERY'));
    vm.stopPrank();
  }

  function test_setEntry_sameNameAcrossTags() public {
    address mainSpoke = makeAddr('MAIN_SPOKE');
    address treasurySpoke = makeAddr('TREASURY_SPOKE');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'MAIN', tag: 'CANONICAL_SPOKE', newAddress: mainSpoke});
    provider.setEntry({name: 'MAIN', tag: 'TREASURY_SPOKE', newAddress: treasurySpoke});
    vm.stopPrank();

    assertEq(provider.getAddress({name: 'MAIN', tag: 'CANONICAL_SPOKE'}), mainSpoke);
    assertEq(provider.getAddress({name: 'MAIN', tag: 'TREASURY_SPOKE'}), treasurySpoke);
  }

  function test_setEntry_removeLastEntryOfTag() public {
    vm.startPrank(OWNER);
    provider.setEntry({name: 'MAIN', tag: 'CANONICAL_SPOKE', newAddress: makeAddr('MAIN_SPOKE')});
    provider.setEntry({
      name: 'MAIN',
      tag: 'TREASURY_SPOKE',
      newAddress: makeAddr('TREASURY_SPOKE')
    });

    provider.setEntry({name: 'MAIN', tag: 'TREASURY_SPOKE', newAddress: address(0)});
    vm.stopPrank();

    assertEq(provider.getIdCount('TREASURY_SPOKE'), 0);

    assertEq(provider.getTagCount(), 1);
    assertEq(provider.getTags(0, 1)[0], 'CANONICAL_SPOKE');
  }

  function test_getTags() public {
    vm.startPrank(OWNER);
    provider.setEntry({name: 'CORE', tag: 'CANONICAL_HUB', newAddress: makeAddr('CORE_HUB')});
    provider.setEntry({name: 'MAIN', tag: 'CANONICAL_SPOKE', newAddress: makeAddr('MAIN_SPOKE')});
    provider.setEntry({
      name: 'CORE_WETH',
      tag: 'TOKENIZATION_SPOKE',
      newAddress: makeAddr('CORE_WETH_TOKENIZATION_SPOKE')
    });
    provider.setEntry({
      name: 'MAIN',
      tag: 'TREASURY_SPOKE',
      newAddress: makeAddr('TREASURY_SPOKE')
    });
    vm.stopPrank();

    assertEq(provider.getTagCount(), 4);

    string[] memory tags = provider.getTags(0, 4);
    assertEq(tags.length, 4);
    assertEq(tags[0], 'CANONICAL_HUB');
    assertEq(tags[1], 'CANONICAL_SPOKE');
    assertEq(tags[2], 'TOKENIZATION_SPOKE');
    assertEq(tags[3], 'TREASURY_SPOKE');
  }

  function test_getTags_bounded() public {
    vm.startPrank(OWNER);
    provider.setEntry({name: 'CORE', tag: 'CANONICAL_HUB', newAddress: makeAddr('CORE_HUB')});
    provider.setEntry({name: 'MAIN', tag: 'CANONICAL_SPOKE', newAddress: makeAddr('MAIN_SPOKE')});
    provider.setEntry({
      name: 'CORE_WETH',
      tag: 'TOKENIZATION_SPOKE',
      newAddress: makeAddr('CORE_WETH_TOKENIZATION_SPOKE')
    });
    provider.setEntry({
      name: 'MAIN',
      tag: 'TREASURY_SPOKE',
      newAddress: makeAddr('TREASURY_SPOKE')
    });
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
    provider.setEntry({name: 'CORE', tag: 'CANONICAL_HUB', newAddress: makeAddr('CORE_HUB')});
    provider.setEntry({name: 'PLUS', tag: 'CANONICAL_HUB', newAddress: makeAddr('PLUS_HUB')});
    provider.setEntry({name: 'PRIME', tag: 'CANONICAL_HUB', newAddress: makeAddr('PRIME_HUB')});
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
    provider.setEntry({name: 'CORE', tag: 'CANONICAL_HUB', newAddress: coreHub});
    provider.setEntry({name: 'PLUS', tag: 'CANONICAL_HUB', newAddress: plusHub});
    provider.setEntry({name: 'PRIME', tag: 'CANONICAL_HUB', newAddress: primeHub});
    vm.stopPrank();

    address[] memory firstTwo = provider.getAddresses('CANONICAL_HUB', 0, 2);
    assertEq(firstTwo.length, 2);
    assertEq(firstTwo[0], coreHub);
    assertEq(firstTwo[1], plusHub);

    address[] memory last = provider.getAddresses('CANONICAL_HUB', 2, 100);
    assertEq(last.length, 1);
    assertEq(last[0], primeHub);
  }

  function test_getAddressIds_bounded() public {
    address shared = makeAddr('SHARED');

    vm.startPrank(OWNER);
    provider.setEntry({name: 'CORE', tag: 'CANONICAL_HUB', newAddress: shared});
    provider.setEntry({name: 'MAIN', tag: 'CANONICAL_SPOKE', newAddress: shared});
    provider.setEntry({name: 'MAIN', tag: 'TREASURY_SPOKE', newAddress: shared});
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
