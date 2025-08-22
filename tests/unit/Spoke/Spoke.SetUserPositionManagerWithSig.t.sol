// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeSetUserPositionManagerWithSigTest is SpokeBase {
  function setUp() public override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(POSITION_MANAGER, true);
  }

  function test_eip712Domain() public {
    Spoke spoke = new Spoke{salt: bytes32(vm.randomUint())}(address(accessManager));
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
    Spoke spoke = new Spoke{salt: bytes32(vm.randomUint())}(address(accessManager));
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
    uint256 deadline = vm.randomUint(0, MAX_SKIP_TIME - 1);
    vm.warp(deadline + 1);

    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: POSITION_MANAGER,
      user: alice,
      approve: vm.randomBool(),
      nonce: spoke1.nonces(alice),
      deadline: deadline
    });
    bytes32 digest = _getTypedDataHash(spoke1, params);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.deadline,
      v,
      r,
      s
    );
  }

  function test_setUserPositionManagerWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.assume(randomUser != alice);
    uint256 deadline = vm.randomUint(1, MAX_SKIP_TIME);
    vm.warp(deadline - 1);

    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: POSITION_MANAGER,
      user: alice,
      approve: vm.randomBool(),
      nonce: spoke1.nonces(alice),
      deadline: deadline
    });
    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomUserPk, digest);

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.deadline,
      v,
      r,
      s
    );
  }

  function test_setUserPositionManagerWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce()
    public
  {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    uint256 deadline = vm.randomUint(0, MAX_SKIP_TIME - 1);
    vm.warp(deadline + 1);

    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: POSITION_MANAGER,
      user: alice,
      approve: vm.randomBool(),
      nonce: spoke1.nonces(alice),
      deadline: deadline
    });

    uint256 count = vm.randomUint(1, 100);
    while (--count > 0) {
      vm.prank(alice);
      spoke1.useNonce();
    }

    params.nonce = vm.randomUint(0, spoke1.nonces(alice) - 1);
    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.deadline,
      v,
      r,
      s
    );
  }

  function test_setUserPositionManagerWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    address positionManager = vm.randomAddress();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(positionManager, true);

    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: positionManager,
      user: user,
      approve: vm.randomBool(),
      nonce: spoke1.nonces(user),
      deadline: vm.randomUint(vm.getBlockTimestamp(), MAX_SKIP_TIME)
    });
    bytes32 digest = _getTypedDataHash(spoke1, params);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(params.user, params.positionManager, params.approve);

    vm.prank(vm.randomAddress());
    spoke1.setUserPositionManagerWithSig(
      params.positionManager,
      params.user,
      params.approve,
      params.deadline,
      v,
      r,
      s
    );

    assertEq(spoke1.isPositionManager(user, params.positionManager), params.approve);
  }

  function test_useNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(spoke1));
    address user = vm.randomAddress();

    uint256 currentNonce = spoke1.nonces(user);
    vm.assume(currentNonce != UINT256_MAX);

    vm.prank(user);
    spoke1.useNonce();

    assertEq(spoke1.nonces(user), currentNonce + 1);
  }
}
