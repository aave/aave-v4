// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/TypedSignatureGateway/TypedSignatureGateway.Base.t.sol';

contract TypedSignatureGatewayConstantsTest is TypedSignatureGatewayBaseTest {
  function test_constructor() public {
    vm.expectRevert();
    new TypedSignatureGateway(address(0), vm.randomAddress());
    vm.expectRevert();
    new TypedSignatureGateway(vm.randomAddress(), address(0));
    vm.expectRevert();
    new TypedSignatureGateway(address(0), address(0));

    address spoke = vm.randomAddress();
    assertEq(address((new TypedSignatureGateway(spoke, vm.randomAddress())).SPOKE()), spoke);
    assertEq(address(gateway.SPOKE()), address(spoke1));
  }

  function test_eip712Domain() public {
    TypedSignatureGateway instance = new TypedSignatureGateway{salt: bytes32(vm.randomUint())}(
      vm.randomAddress(),
      vm.randomAddress()
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
      vm.randomAddress(),
      vm.randomAddress()
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
}
