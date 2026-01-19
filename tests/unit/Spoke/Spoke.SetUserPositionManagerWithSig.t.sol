// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {EIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';

contract SpokesetUserPositionManagersWithSigTest is SpokeBase {
  using SafeCast for *;

  mapping(address positionManager => bool approve) internal _lookup;

  function setUp() public override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(POSITION_MANAGER, true);
  }

  function test_useNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(spoke1));
    address user = vm.randomAddress();
    uint192 nonceKey = vm.randomUint(0, type(uint192).max).toUint192();

    (, uint64 nonce) = _unpackNonce(spoke1.nonces(user, nonceKey));

    vm.prank(user);
    spoke1.useNonce(nonceKey);

    // prettier-ignore
    unchecked { ++nonce; }

    assertEq(spoke1.nonces(user, nonceKey), _packNonce(nonceKey, nonce));
  }

  function test_eip712Domain() public {
    (ISpoke spoke, ) = _deploySpokeWithOracle(vm.randomAddress(), vm.randomAddress(), '');
    (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    ) = IERC5267(address(spoke)).eip712Domain();

    assertEq(fields, bytes1(0x0f));
    assertEq(name, 'Spoke');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(spoke));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    (ISpoke spoke, ) = _deploySpokeWithOracle(vm.randomAddress(), vm.randomAddress(), '');
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('Spoke'),
        keccak256('1'),
        block.chainid,
        address(spoke)
      )
    );
    assertEq(spoke.DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  function test_setUserPositionManager_typeHash() public view {
    assertEq(
      EIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      vm.eip712HashType('SetUserPositionManagers')
    );
    assertEq(
      EIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      keccak256(
        'SetUserPositionManagers(address user,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)'
      )
    );
    assertEq(
      EIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      spoke1.SET_USER_POSITION_MANAGERS_TYPEHASH()
    );
  }

  function test_positionManagerUpdate_typeHash() public pure {
    assertEq(
      EIP712Hash.POSITION_MANAGER_UPDATE,
      keccak256('PositionManagerUpdate(address positionManager,bool approve)')
    );
    assertEq(EIP712Hash.POSITION_MANAGER_UPDATE, vm.eip712HashType('PositionManagerUpdate'));
  }

  function test_setUserPositionManagersWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    uint256 deadline = _warpAfterRandomDeadline();

    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(alice, deadline);
    bytes32 digest = _getTypedDataHash(spoke1, params);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);
  }

  function test_setUserPositionManagersWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.assume(randomUser != alice);
    uint256 deadline = _warpAfterRandomDeadline();

    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(alice, deadline);
    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomUserPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);
  }

  function test_setUserPositionManagersWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    address positionManager = vm.randomAddress();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(positionManager, true);
    uint256 deadline = _warpBeforeRandomDeadline();

    uint192 nonceKey = _randomNonceKey();
    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(user, deadline);
    uint256 currentNonce = _burnRandomNoncesAtKey(spoke1, params.user, nonceKey);
    params.nonce = _getRandomInvalidNonceAtKey(spoke1, params.user, nonceKey);

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, params.user, currentNonce)
    );
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);
  }

  function test_setUserPositionManagersWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    uint256 deadline = _warpBeforeRandomDeadline();
    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(user, deadline);
    params.nonce = _burnRandomNoncesAtKey(spoke1, params.user);

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(
      params.user,
      params.updates[0].positionManager,
      params.updates[0].approve
    );

    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);

    _assertNonceIncrement(spoke1, params.user, params.nonce);
    assertEq(
      spoke1.isPositionManager(params.user, params.updates[0].positionManager),
      params.updates[0].approve
    );
  }

  function test_setUserPositionManagersWithSig_zero_updates() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    uint256 deadline = _warpBeforeRandomDeadline();
    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(user, deadline);
    params.updates = new ISpoke.PositionManagerUpdate[](0);
    params.nonce = _burnRandomNoncesAtKey(spoke1, params.user);

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.recordLogs();

    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);

    assertEq(vm.getRecordedLogs().length, 0);
    _assertNonceIncrement(spoke1, params.user, params.nonce);
  }

  function test_setUserPositionManagersWithSig_multiple_updates(
    ISpoke.PositionManagerUpdate[] memory updates
  ) public {
    vm.assume(updates.length < 1024); // for performance
    vm.setArbitraryStorage(address(spoke1)); // arbitrary nonce, position manager active state
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    uint256 deadline = _warpBeforeRandomDeadline();
    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(user, deadline);
    params.updates = updates;

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    for (uint256 i; i < updates.length; ++i) {
      address positionManager = params.updates[i].positionManager;
      bool approve = params.updates[i].approve;
      vm.expectEmit(address(spoke1));
      emit ISpoke.SetUserPositionManager(params.user, positionManager, approve);
      // overwrite cached lookup such that latest state is checked for duplicated entries
      _lookup[positionManager] = approve && spoke1.isPositionManagerActive(positionManager);
    }

    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);

    _assertNonceIncrement(spoke1, params.user, params.nonce);
    for (uint256 i; i < updates.length; ++i) {
      address positionManager = params.updates[i].positionManager;
      assertEq(
        spoke1.isPositionManager(params.user, positionManager),
        (positionManager == user) || _lookup[positionManager]
      );
    }
  }

  function test_setUserPositionManagersWithSig_ERC1271_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(
      address(smartWallet),
      _warpAfterRandomDeadline()
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    vm.prank(alice);
    smartWallet.approveHash(digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);
  }

  function test_setUserPositionManagersWithSig_ERC1271_revertsWith_InvalidSignature_dueTo_InvalidHash()
    public
  {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    address maliciousManager = makeAddr('maliciousManager');
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(maliciousManager, true);
    uint256 deadline = _warpAfterRandomDeadline();

    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    ISpoke.SetUserPositionManagers memory invalidParams = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );
    invalidParams.updates[0].positionManager = maliciousManager;

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(spoke1, invalidParams));
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.prank(alice);
    smartWallet.approveHash(digest);

    invalidParams.nonce = params.nonce;

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(invalidParams, signature);
  }

  function test_setUserPositionManagersWithSig_ERC1271_revertsWith_InvalidAccountNonce(
    bytes32
  ) public {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    uint256 deadline = _warpBeforeRandomDeadline();

    uint192 nonceKey = _randomNonceKey();
    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );

    uint256 currentNonce = _burnRandomNoncesAtKey(spoke1, address(smartWallet), nonceKey);
    params.nonce = _getRandomInvalidNonceAtKey(spoke1, address(smartWallet), nonceKey);

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.prank(alice);
    smartWallet.approveHash(digest);

    vm.expectRevert(
      abi.encodeWithSelector(
        INoncesKeyed.InvalidAccountNonce.selector,
        address(smartWallet),
        currentNonce
      )
    );
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);
  }

  function test_setUserPositionManagersWithSig_ERC1271() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(user);
    vm.label(user, 'user');
    vm.label(address(smartWallet), 'smartWallet');
    address positionManager = vm.randomAddress();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(positionManager, true);
    uint256 deadline = _warpBeforeRandomDeadline();

    ISpoke.SetUserPositionManagers memory params = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    vm.prank(user);
    smartWallet.approveHash(digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(
      params.user,
      params.updates[0].positionManager,
      params.updates[0].approve
    );

    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagersWithSig(params, signature);

    _assertNonceIncrement(spoke1, params.user, params.nonce);
    assertEq(
      spoke1.isPositionManager(params.user, params.updates[0].positionManager),
      params.updates[0].approve
    );
  }

  function _setUserPositionManagerData(
    address user,
    uint256 deadline
  ) internal returns (ISpoke.SetUserPositionManagers memory) {
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(POSITION_MANAGER, true);
    ISpoke.SetUserPositionManagers memory params = ISpoke.SetUserPositionManagers({
      user: user,
      updates: updates,
      nonce: spoke1.nonces(user, _randomNonceKey()),
      deadline: deadline
    });
    return params;
  }
}
