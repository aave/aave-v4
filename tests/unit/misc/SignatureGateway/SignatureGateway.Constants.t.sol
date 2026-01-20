// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGatewayConstantsTest is SignatureGatewayBaseTest {
  function test_constructor() public {
    vm.expectRevert();
    new SignatureGateway(address(0), vm.randomAddress());

    vm.expectRevert();
    new SignatureGateway(vm.randomAddress(), address(0));

    assertEq(Ownable2Step(address(gateway)).owner(), ADMIN);
    assertEq(Ownable2Step(address(gateway)).pendingOwner(), address(0));
    assertEq(gateway.rescueGuardian(), ADMIN);
    assertEq(gateway.PERMIT2(), CANONICAL_PERMIT2);
  }

  function test_eip712Domain() public {
    SignatureGateway instance = new SignatureGateway{salt: bytes32(vm.randomUint())}(
      vm.randomAddress(),
      CANONICAL_PERMIT2
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
    assertEq(name, 'SignatureGateway');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    SignatureGateway instance = new SignatureGateway{salt: bytes32(vm.randomUint())}(
      vm.randomAddress(),
      CANONICAL_PERMIT2
    );
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('SignatureGateway'),
        keccak256('1'),
        block.chainid,
        address(instance)
      )
    );
    assertEq(instance.DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  function test_supply_typeHash() public view {
    assertEq(gateway.SUPPLY_TYPEHASH(), vm.eip712HashType('SupplyAction'));
  }

  function test_withdraw_typeHash() public view {
    assertEq(gateway.WITHDRAW_TYPEHASH(), vm.eip712HashType('WithdrawAction'));
  }

  function test_borrow_typeHash() public view {
    assertEq(gateway.BORROW_TYPEHASH(), vm.eip712HashType('BorrowAction'));
  }

  function test_repay_typeHash() public view {
    assertEq(gateway.REPAY_TYPEHASH(), vm.eip712HashType('RepayAction'));
  }

  function test_setUsingAsCollateral_typeHash() public view {
    assertEq(
      gateway.SET_USING_AS_COLLATERAL_TYPEHASH(),
      vm.eip712HashType('SetUsingAsCollateralAction')
    );
  }

  function test_updateUserRiskPremium_typeHash() public view {
    assertEq(
      gateway.UPDATE_USER_RISK_PREMIUM_TYPEHASH(),
      vm.eip712HashType('UpdateUserRiskPremiumAction')
    );
  }

  function test_updateUserDynamicConfig_typeHash() public view {
    assertEq(
      gateway.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH(),
      vm.eip712HashType('UpdateUserDynamicConfigAction')
    );
  }
}
