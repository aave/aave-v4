// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {PositionManagerGateEIP712Hash} from 'src/spoke/libraries/PositionManagerGateEIP712Hash.sol';

contract SpokeSetUserPositionManagersWithSigTest is Base {
  using SafeCast for *;

  mapping(address positionManager => bool approve) internal _lookup;

  function setUp() public override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    _updatePositionManager(spoke1, POSITION_MANAGER, true);
  }

  function test_useNonce_monotonic(bytes32) public {
    IPositionManagerGate gate = _positionManagerGate(spoke1);
    vm.setArbitraryStorage(address(gate));
    address user = vm.randomAddress();
    uint192 nonceKey = vm.randomUint(0, type(uint192).max).toUint192();

    (, uint64 nonce) = _unpackNonce(gate.nonces(user, nonceKey));

    vm.prank(user);
    gate.useNonce(nonceKey);

    // prettier-ignore
    unchecked { ++nonce; }

    assertEq(gate.nonces(user, nonceKey), _packNonce(nonceKey, nonce));
  }

  function test_eip712Domain() public {
    (ISpoke spoke, ) = _deploySpokeWithOracle(vm.randomAddress(), vm.randomAddress());
    (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    ) = IERC5267(spoke.GATE()).eip712Domain();

    assertEq(fields, bytes1(0x0f));
    assertEq(name, 'PositionManagerGate');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, spoke.GATE());
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    (ISpoke spoke, ) = _deploySpokeWithOracle(vm.randomAddress(), vm.randomAddress());
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('PositionManagerGate'),
        keccak256('1'),
        block.chainid,
        spoke.GATE()
      )
    );
    assertEq(IPositionManagerGate(spoke.GATE()).DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  function test_setUserPositionManager_typeHash() public view {
    assertEq(
      PositionManagerGateEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      vm.eip712HashType('SetUserPositionManagers')
    );
    assertEq(
      PositionManagerGateEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      keccak256(
        'SetUserPositionManagers(address spoke,address onBehalfOf,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)'
      )
    );
    assertEq(
      PositionManagerGateEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      IPositionManagerGate(spoke1.GATE()).SET_USER_POSITION_MANAGERS_TYPEHASH()
    );
  }

  function test_positionManagerUpdate_typeHash() public pure {
    assertEq(
      PositionManagerGateEIP712Hash.POSITION_MANAGER_UPDATE_TYPEHASH,
      keccak256('PositionManagerUpdate(address positionManager,bool approve)')
    );
    assertEq(
      PositionManagerGateEIP712Hash.POSITION_MANAGER_UPDATE_TYPEHASH,
      vm.eip712HashType('PositionManagerUpdate')
    );
  }

  function test_setUserPositionManagersWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline(MAX_SKIP_TIME);

    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      alice,
      deadline
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    _setUserPositionManagersWithSig(spoke1, params, signature);
  }

  function test_setUserPositionManagersWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.assume(randomUser != alice);
    uint256 deadline = _warpAfterRandomDeadline(MAX_SKIP_TIME);

    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      alice,
      deadline
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomUserPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    _setUserPositionManagersWithSig(spoke1, params, signature);
  }

  function test_setUserPositionManagersWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    address positionManager = vm.randomAddress();
    vm.prank(SPOKE_ADMIN);
    _updatePositionManager(spoke1, positionManager, true);
    uint256 deadline = _warpBeforeRandomDeadline(MAX_SKIP_TIME);

    uint192 nonceKey = _randomNonceKey();
    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      user,
      deadline
    );
    uint256 currentNonce = _burnRandomNoncesAtKey(
      IPositionManagerGate(spoke1.GATE()),
      params.onBehalfOf,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      IPositionManagerGate(spoke1.GATE()),
      params.onBehalfOf,
      nonceKey
    );

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(
      abi.encodeWithSelector(
        INoncesKeyed.InvalidAccountNonce.selector,
        params.onBehalfOf,
        currentNonce
      )
    );
    vm.prank(vm.randomAddress());
    _setUserPositionManagersWithSig(spoke1, params, signature);
  }

  function test_setUserPositionManagersWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    uint256 deadline = _warpBeforeRandomDeadline(MAX_SKIP_TIME);
    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      user,
      deadline
    );
    params.nonce = _burnRandomNoncesAtKey(IPositionManagerGate(spoke1.GATE()), params.onBehalfOf);

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectEmit(spoke1.GATE());
    emit IPositionManagerGate.SetUserPositionManager(
      address(spoke1),
      params.onBehalfOf,
      params.updates[0].positionManager,
      params.updates[0].approve
    );

    vm.prank(vm.randomAddress());
    _setUserPositionManagersWithSig(spoke1, params, signature);

    _assertNonceIncrement(IPositionManagerGate(spoke1.GATE()), params.onBehalfOf, params.nonce);
    assertEq(
      _isPositionManager(spoke1, params.onBehalfOf, params.updates[0].positionManager),
      params.updates[0].approve
    );
  }

  function test_setUserPositionManagersWithSig_zero_updates() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    uint256 deadline = _warpBeforeRandomDeadline(MAX_SKIP_TIME);
    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      user,
      deadline
    );
    params.updates = new IPositionManagerGate.PositionManagerUpdate[](0);
    params.nonce = _burnRandomNoncesAtKey(IPositionManagerGate(spoke1.GATE()), params.onBehalfOf);

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.recordLogs();

    vm.prank(vm.randomAddress());
    _setUserPositionManagersWithSig(spoke1, params, signature);

    assertEq(vm.getRecordedLogs().length, 0);
    _assertNonceIncrement(IPositionManagerGate(spoke1.GATE()), params.onBehalfOf, params.nonce);
  }

  function test_setUserPositionManagersWithSig_multiple_updates(
    IPositionManagerGate.PositionManagerUpdate[] memory updates
  ) public {
    vm.assume(updates.length < 1024); // for performance
    vm.setArbitraryStorage(spoke1.GATE()); // arbitrary nonce, position manager active state
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    uint256 deadline = _warpBeforeRandomDeadline(MAX_SKIP_TIME);
    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      user,
      deadline
    );
    params.updates = updates;

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    for (uint256 i; i < updates.length; ++i) {
      address positionManager = params.updates[i].positionManager;
      bool approve = params.updates[i].approve;
      vm.expectEmit(spoke1.GATE());
      emit IPositionManagerGate.SetUserPositionManager(
        address(spoke1),
        params.onBehalfOf,
        positionManager,
        approve
      );
      // overwrite cached lookup such that latest state is checked for duplicated entries
      _lookup[positionManager] = approve && _isPositionManagerActive(spoke1, positionManager);
    }

    vm.prank(vm.randomAddress());
    _setUserPositionManagersWithSig(spoke1, params, signature);

    _assertNonceIncrement(IPositionManagerGate(spoke1.GATE()), params.onBehalfOf, params.nonce);
    for (uint256 i; i < updates.length; ++i) {
      address positionManager = params.updates[i].positionManager;
      assertEq(
        _isPositionManager(spoke1, params.onBehalfOf, positionManager),
        (positionManager == user) || _lookup[positionManager]
      );
    }
  }

  function test_setUserPositionManagersWithSig_ERC1271_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      address(smartWallet),
      _warpAfterRandomDeadline(MAX_SKIP_TIME)
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    vm.prank(alice);
    smartWallet.approveHash(digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    _setUserPositionManagersWithSig(spoke1, params, signature);
  }

  function test_setUserPositionManagersWithSig_ERC1271_revertsWith_InvalidSignature_dueTo_InvalidHash()
    public
  {
    address maliciousManager = makeAddr('maliciousManager');
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    vm.prank(SPOKE_ADMIN);
    _updatePositionManager(spoke1, maliciousManager, true);
    uint256 deadline = _warpAfterRandomDeadline(MAX_SKIP_TIME);

    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    IPositionManagerGate.SetUserPositionManagers memory invalidParams = _setUserPositionManagerData(
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
    _setUserPositionManagersWithSig(spoke1, invalidParams, signature);
  }

  function test_setUserPositionManagersWithSig_ERC1271_revertsWith_InvalidAccountNonce(
    bytes32
  ) public {
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    uint256 deadline = _warpBeforeRandomDeadline(MAX_SKIP_TIME);

    uint192 nonceKey = _randomNonceKey();
    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );

    uint256 currentNonce = _burnRandomNoncesAtKey(
      IPositionManagerGate(spoke1.GATE()),
      address(smartWallet),
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      IPositionManagerGate(spoke1.GATE()),
      address(smartWallet),
      nonceKey
    );

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
    _setUserPositionManagersWithSig(spoke1, params, signature);
  }

  function test_setUserPositionManagersWithSig_ERC1271() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(user);
    vm.label(user, 'user');
    vm.label(address(smartWallet), 'smartWallet');
    address positionManager = vm.randomAddress();
    vm.prank(SPOKE_ADMIN);
    _updatePositionManager(spoke1, positionManager, true);
    uint256 deadline = _warpBeforeRandomDeadline(MAX_SKIP_TIME);

    IPositionManagerGate.SetUserPositionManagers memory params = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    vm.prank(user);
    smartWallet.approveHash(digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectEmit(spoke1.GATE());
    emit IPositionManagerGate.SetUserPositionManager(
      address(spoke1),
      params.onBehalfOf,
      params.updates[0].positionManager,
      params.updates[0].approve
    );

    vm.prank(vm.randomAddress());
    _setUserPositionManagersWithSig(spoke1, params, signature);

    _assertNonceIncrement(IPositionManagerGate(spoke1.GATE()), params.onBehalfOf, params.nonce);
    assertEq(
      _isPositionManager(spoke1, params.onBehalfOf, params.updates[0].positionManager),
      params.updates[0].approve
    );
  }

  function _setUserPositionManagerData(
    address user,
    uint256 deadline
  ) internal returns (IPositionManagerGate.SetUserPositionManagers memory) {
    IPositionManagerGate.PositionManagerUpdate[]
      memory updates = new IPositionManagerGate.PositionManagerUpdate[](1);
    updates[0] = IPositionManagerGate.PositionManagerUpdate(POSITION_MANAGER, true);
    IPositionManagerGate.SetUserPositionManagers memory params = IPositionManagerGate
      .SetUserPositionManagers({
        spoke: address(spoke1),
        onBehalfOf: user,
        updates: updates,
        nonce: IPositionManagerGate(spoke1.GATE()).nonces(user, _randomNonceKey()),
        deadline: deadline
      });
    return params;
  }
}
