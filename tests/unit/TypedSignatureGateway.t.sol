// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {TypedSignatureGateway, ITypedSignatureGateway} from 'src/misc/TypedSignatureGateway.sol';

contract TypedSignatureGatewayTest is Base {
  ITypedSignatureGateway public gateway;

  function setUp() public override {
    super.setUp();
    gateway = ITypedSignatureGateway(new TypedSignatureGateway(address(spoke1)));
  }

  function test_constructor() public {
    vm.expectRevert();
    new TypedSignatureGateway(address(0));

    address spoke = vm.randomAddress();
    assertEq(address((new TypedSignatureGateway(spoke)).SPOKE()), spoke);
    assertEq(address(gateway.SPOKE()), address(spoke1));
  }

  function test_eip712Domain() public {
    TypedSignatureGateway instance = new TypedSignatureGateway{salt: bytes32(vm.randomUint())}(
      address(spoke1)
    );
    (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    ) = IERC5267(address(instance)).eip712Domain();

    assertEq(fields, bytes1(0x0f));
    assertEq(name, 'TypedSignatureGateway');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    TypedSignatureGateway instance = new TypedSignatureGateway{salt: bytes32(vm.randomUint())}(
      address(spoke1)
    );
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('TypedSignatureGateway'),
        keccak256('1'),
        block.chainid,
        address(instance)
      )
    );
    assertEq(instance.DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  function test_supply_typeHash() public view {
    assertEq(gateway.SUPPLY_TYPEHASH(), vm.eip712HashType('Supply'));
    assertEq(
      gateway.SUPPLY_TYPEHASH(),
      keccak256(
        'Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_withdraw_typeHash() public view {
    assertEq(gateway.WITHDRAW_TYPEHASH(), vm.eip712HashType('Withdraw'));
    assertEq(
      gateway.WITHDRAW_TYPEHASH(),
      keccak256(
        'Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_borrow_typeHash() public view {
    assertEq(gateway.BORROW_TYPEHASH(), vm.eip712HashType('Borrow'));
    assertEq(
      gateway.BORROW_TYPEHASH(),
      keccak256(
        'Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_repay_typeHash() public view {
    assertEq(gateway.REPAY_TYPEHASH(), vm.eip712HashType('Repay'));
    assertEq(
      gateway.REPAY_TYPEHASH(),
      keccak256(
        'Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (, uint256 alicePk) = makeAddrAndKey('alice');
    uint256 deadline = vm.randomUint(0, MAX_SKIP_TIME - 1);
    vm.warp(deadline + 1);

    EIP712Types.Supply memory params = EIP712Types.Supply({
      spoke: address(spoke1),
      reserveId: _randomReserveId(spoke1),
      amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      onBehalfOf: alice,
      nonce: spoke1.nonces(alice),
      deadline: deadline
    });
    bytes32 digest = _getTypedDataHash(gateway, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(
      params.reserveId,
      params.amount,
      params.onBehalfOf,
      params.deadline,
      abi.encodePacked(v, r, s)
    );
  }

  function _randomReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(0, spoke.getReserveCount() - 1);
  }

  function _getTypedDataHash(
    ITypedSignatureGateway _gateway,
    EIP712Types.Supply memory _params
  ) internal returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          _gateway.DOMAIN_SEPARATOR(),
          vm.eip712HashStruct('Supply', abi.encode(_params))
        )
      );
  }
}
