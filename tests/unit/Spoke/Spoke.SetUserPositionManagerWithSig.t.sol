// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeSetUserPositionManagerWithSigTest is SpokeBase {
  using SafeCast for *;

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

  function test_setUserPositionManager_typeHash() public pure {
    assertEq(
      Constants.SET_USER_POSITION_MANAGER_TYPEHASH,
      vm.eip712HashType('SetUserPositionManager')
    );
    assertEq(
      Constants.SET_USER_POSITION_MANAGER_TYPEHASH,
      keccak256(
        'SetUserPositionManager(address positionManager,address user,bool approve,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_setUserPositionManagerWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.SetUserPositionManager memory params = _setUserPositionManagerData(alice, deadline);
    bytes32 digest = _getTypedDataHash(spoke1, params);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.nonce,
      params.deadline,
      signature
    );
  }

  function test_setUserPositionManagerWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.assume(randomUser != alice);
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.SetUserPositionManager memory params = _setUserPositionManagerData(alice, deadline);
    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomUserPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.nonce,
      params.deadline,
      signature
    );
  }

  function test_setUserPositionManagerWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    address positionManager = vm.randomAddress();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(positionManager, true);
    uint256 deadline = _warpBeforeRandomDeadline();

    uint192 nonceKey = _randomNonceKey();
    EIP712Types.SetUserPositionManager memory params = _setUserPositionManagerData(user, deadline);
    uint256 currentNonce = _burnRandomNoncesAtKey(spoke1, params.user, nonceKey);
    params.nonce = _getRandomInvalidNonceAtKey(spoke1, params.user, nonceKey);

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, params.user, currentNonce)
    );
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.nonce,
      params.deadline,
      signature
    );
  }

  function test_setUserPositionManagerWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    uint256 deadline = _warpBeforeRandomDeadline();
    EIP712Types.SetUserPositionManager memory params = _setUserPositionManagerData(user, deadline);
    params.nonce = _burnRandomNoncesAtKey(spoke1, params.user);

    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(params.user, params.positionManager, params.approve);

    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.nonce,
      params.deadline,
      signature
    );

    _assertNonceIncrement(spoke1, params.user, params.nonce);
    assertEq(spoke1.isPositionManager(params.user, params.positionManager), params.approve);
  }

  function test_setUserPositionManagerWithSig_ERC1271_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    EIP712Types.SetUserPositionManager memory params = _setUserPositionManagerData(
      address(smartWallet),
      _warpAfterRandomDeadline()
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    vm.prank(alice);
    smartWallet.approveHash(digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.nonce,
      params.deadline,
      signature
    );
  }

  function test_setUserPositionManagerWithSig_ERC1271_revertsWith_InvalidSignature_dueTo_InvalidHash()
    public
  {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    address maliciousManager = makeAddr('maliciousManager');
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(maliciousManager, true);
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.SetUserPositionManager memory params = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    EIP712Types.SetUserPositionManager memory invalidParams = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );
    invalidParams.positionManager = maliciousManager;

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(spoke1, invalidParams));
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.prank(alice);
    smartWallet.approveHash(digest);

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      invalidParams.positionManager,
      invalidParams.user,
      invalidParams.approve,
      params.nonce,
      invalidParams.deadline,
      signature
    );
  }

  function test_setUserPositionManagerWithSig_ERC1271_revertsWith_InvalidAccountNonce(
    bytes32
  ) public {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(alice);
    uint256 deadline = _warpBeforeRandomDeadline();

    uint192 nonceKey = _randomNonceKey();
    EIP712Types.SetUserPositionManager memory params = _setUserPositionManagerData(
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
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.nonce,
      params.deadline,
      signature
    );
  }

  function test_setUserPositionManagerWithSig_ERC1271() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    MockERC1271Wallet smartWallet = new MockERC1271Wallet(user);
    vm.label(user, 'user');
    vm.label(address(smartWallet), 'smartWallet');
    address positionManager = vm.randomAddress();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(positionManager, true);
    uint256 deadline = _warpBeforeRandomDeadline();

    EIP712Types.SetUserPositionManager memory params = _setUserPositionManagerData(
      address(smartWallet),
      deadline
    );
    bytes32 digest = _getTypedDataHash(spoke1, params);

    vm.prank(user);
    smartWallet.approveHash(digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(params.user, params.positionManager, params.approve);

    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.nonce,
      params.deadline,
      signature
    );

    _assertNonceIncrement(spoke1, params.user, params.nonce);
    assertEq(spoke1.isPositionManager(params.user, params.positionManager), params.approve);
  }

  function _setUserPositionManagerData(
    address user,
    uint256 deadline
  ) internal returns (EIP712Types.SetUserPositionManager memory) {
    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: POSITION_MANAGER,
      user: user,
      approve: vm.randomBool(),
      nonce: spoke1.nonces(user, _randomNonceKey()),
      deadline: deadline
    });
    return params;
  }
}
