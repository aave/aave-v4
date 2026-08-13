// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ITakerPositionManager} from 'src/position-manager/interfaces/ITakerPositionManager.sol';

import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {PositionManagerEIP712HashWrapper} from 'tests/helpers/mocks/PositionManagerEIP712HashWrapper.sol';

contract PositionManagerEIP712HashTest is Test {
  using EIP712Hash for *;

  PositionManagerEIP712HashWrapper internal w;

  function setUp() public {
    w = new PositionManagerEIP712HashWrapper();
    if (vm.envOr('TEST_VYPER', false)) {
      vm.etch(
        address(w),
        vm.getDeployedCode(
          'PositionManagerEIP712HashHarness.vy:PositionManagerEIP712HashHarness'
        )
      );
    }
  }

  function test_constants() public view {
    assertEq(
      w.SUPPLY_TYPEHASH(),
      keccak256(
        'Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.SUPPLY_TYPEHASH(), vm.eip712HashType('Supply'));

    assertEq(
      w.WITHDRAW_TYPEHASH(),
      keccak256(
        'Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.WITHDRAW_TYPEHASH(), vm.eip712HashType('Withdraw'));

    assertEq(
      w.BORROW_TYPEHASH(),
      keccak256(
        'Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.BORROW_TYPEHASH(), vm.eip712HashType('Borrow'));

    assertEq(
      w.REPAY_TYPEHASH(),
      keccak256(
        'Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.REPAY_TYPEHASH(), vm.eip712HashType('Repay'));

    assertEq(
      w.SET_USING_AS_COLLATERAL_TYPEHASH(),
      keccak256(
        'SetUsingAsCollateral(address spoke,uint256 reserveId,bool useAsCollateral,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      w.SET_USING_AS_COLLATERAL_TYPEHASH(),
      vm.eip712HashType('SetUsingAsCollateral')
    );

    assertEq(
      w.UPDATE_USER_RISK_PREMIUM_TYPEHASH(),
      keccak256(
        'UpdateUserRiskPremium(address spoke,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      w.UPDATE_USER_RISK_PREMIUM_TYPEHASH(),
      vm.eip712HashType('UpdateUserRiskPremium')
    );

    assertEq(
      w.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH(),
      keccak256(
        'UpdateUserDynamicConfig(address spoke,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      w.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH(),
      vm.eip712HashType('UpdateUserDynamicConfig')
    );

    assertEq(
      w.WITHDRAW_PERMIT_TYPEHASH(),
      keccak256(
        'WithdrawPermit(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.WITHDRAW_PERMIT_TYPEHASH(), vm.eip712HashType('WithdrawPermit'));

    assertEq(
      w.BORROW_PERMIT_TYPEHASH(),
      keccak256(
        'BorrowPermit(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.BORROW_PERMIT_TYPEHASH(), vm.eip712HashType('BorrowPermit'));
  }

  // @dev all struct params should be hashed & placed in the same order as the typehash
  function test_hash_supply_fuzz(ISignatureGateway.Supply calldata params) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.SUPPLY_TYPEHASH(), params));
    assertEq(w.hashSupply(params), expectedHash);
    assertEq(w.hashSupply(params), vm.eip712HashStruct('Supply', abi.encode(params)));
  }

  function test_hash_withdraw_fuzz(ISignatureGateway.Withdraw calldata params) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.WITHDRAW_TYPEHASH(), params));
    assertEq(w.hashWithdraw(params), expectedHash);
    assertEq(w.hashWithdraw(params), vm.eip712HashStruct('Withdraw', abi.encode(params)));
  }

  function test_hash_borrow_fuzz(ISignatureGateway.Borrow calldata params) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.BORROW_TYPEHASH(), params));
    assertEq(w.hashBorrow(params), expectedHash);
    assertEq(w.hashBorrow(params), vm.eip712HashStruct('Borrow', abi.encode(params)));
  }

  function test_hash_repay_fuzz(ISignatureGateway.Repay calldata params) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.REPAY_TYPEHASH(), params));
    assertEq(w.hashRepay(params), expectedHash);
    assertEq(w.hashRepay(params), vm.eip712HashStruct('Repay', abi.encode(params)));
  }

  function test_hash_setUsingAsCollateral_fuzz(
    ISignatureGateway.SetUsingAsCollateral calldata params
  ) public view {
    bytes32 expectedHash = keccak256(
      abi.encode(w.SET_USING_AS_COLLATERAL_TYPEHASH(), params)
    );
    assertEq(w.hashSetUsingAsCollateral(params), expectedHash);
    assertEq(w.hashSetUsingAsCollateral(params), vm.eip712HashStruct('SetUsingAsCollateral', abi.encode(params)));
  }

  function test_hash_updateUserRiskPremium_fuzz(
    ISignatureGateway.UpdateUserRiskPremium calldata params
  ) public view {
    bytes32 expectedHash = keccak256(
      abi.encode(w.UPDATE_USER_RISK_PREMIUM_TYPEHASH(), params)
    );
    assertEq(w.hashUpdateUserRiskPremium(params), expectedHash);
    assertEq(w.hashUpdateUserRiskPremium(params), vm.eip712HashStruct('UpdateUserRiskPremium', abi.encode(params)));
  }

  function test_hash_updateUserDynamicConfig_fuzz(
    ISignatureGateway.UpdateUserDynamicConfig calldata params
  ) public view {
    bytes32 expectedHash = keccak256(
      abi.encode(w.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH(), params)
    );
    assertEq(w.hashUpdateUserDynamicConfig(params), expectedHash);
    assertEq(w.hashUpdateUserDynamicConfig(params), vm.eip712HashStruct('UpdateUserDynamicConfig', abi.encode(params)));
  }

  function test_hash_withdrawPermit_fuzz(
    ITakerPositionManager.WithdrawPermit calldata params
  ) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.WITHDRAW_PERMIT_TYPEHASH(), params));

    assertEq(w.hashWithdrawPermit(params), expectedHash);
  }

  function test_hash_borrowPermit_fuzz(
    ITakerPositionManager.BorrowPermit calldata params
  ) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.BORROW_PERMIT_TYPEHASH(), params));

    assertEq(w.hashBorrowPermit(params), expectedHash);
  }
}
