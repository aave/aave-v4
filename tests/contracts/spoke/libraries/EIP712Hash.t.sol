// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {EIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';
import {Test} from 'forge-std/Test.sol';
import {SpokeEIP712HashWrapper} from 'tests/helpers/mocks/SpokeEIP712HashWrapper.sol';

contract EIP712HashTest is Test {
  using EIP712Hash for *;

  SpokeEIP712HashWrapper internal w;

  function setUp() public {
    w = new SpokeEIP712HashWrapper();
    if (vm.envOr('TEST_VYPER', false)) {
      vm.etch(address(w), vm.getDeployedCode('SpokeEIP712HashHarness.vy:SpokeEIP712HashHarness'));
    }
  }

  function test_constants() public view {
    assertEq(
      w.SET_USER_POSITION_MANAGERS_TYPEHASH(),
      keccak256(
        'SetUserPositionManagers(address onBehalfOf,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)'
      )
    );
    assertEq(
      w.SET_USER_POSITION_MANAGERS_TYPEHASH(),
      vm.eip712HashType('SetUserPositionManagers')
    );

    assertEq(
      w.POSITION_MANAGER_UPDATE(),
      keccak256('PositionManagerUpdate(address positionManager,bool approve)')
    );
    assertEq(w.POSITION_MANAGER_UPDATE(), vm.eip712HashType('PositionManagerUpdate'));

    assertEq(
      w.TOKENIZED_DEPOSIT_TYPEHASH(),
      keccak256(
        'TokenizedDeposit(address depositor,uint256 assets,address receiver,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.TOKENIZED_DEPOSIT_TYPEHASH(), vm.eip712HashType('TokenizedDeposit'));

    assertEq(
      w.TOKENIZED_MINT_TYPEHASH(),
      keccak256(
        'TokenizedMint(address depositor,uint256 shares,address receiver,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.TOKENIZED_MINT_TYPEHASH(), vm.eip712HashType('TokenizedMint'));

    assertEq(
      w.TOKENIZED_WITHDRAW_TYPEHASH(),
      keccak256(
        'TokenizedWithdraw(address owner,uint256 assets,address receiver,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.TOKENIZED_WITHDRAW_TYPEHASH(), vm.eip712HashType('TokenizedWithdraw'));

    assertEq(
      w.TOKENIZED_REDEEM_TYPEHASH(),
      keccak256(
        'TokenizedRedeem(address owner,uint256 shares,address receiver,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(w.TOKENIZED_REDEEM_TYPEHASH(), vm.eip712HashType('TokenizedRedeem'));
  }

  function test_hash_setUserPositionManagers_fuzz(
    ISpoke.SetUserPositionManagers calldata params
  ) public view {
    bytes32[] memory updatesHashes = new bytes32[](params.updates.length);
    for (uint256 i = 0; i < updatesHashes.length; ++i) {
      updatesHashes[i] = w.hashPositionManagerUpdate(params.updates[i]);
    }

    bytes32 expectedHash = keccak256(
      abi.encode(
        w.SET_USER_POSITION_MANAGERS_TYPEHASH(),
        params.onBehalfOf,
        keccak256(abi.encodePacked(updatesHashes)),
        params.nonce,
        params.deadline
      )
    );

    assertEq(w.hashSetUserPositionManagers(params), expectedHash);
    assertEq(
      w.hashSetUserPositionManagers(params),
      vm.eip712HashStruct('SetUserPositionManagers', abi.encode(params))
    );
  }

  function test_hash_positionManagerUpdate_fuzz(
    ISpoke.PositionManagerUpdate calldata params
  ) public view {
    bytes32 expectedHash = keccak256(
      abi.encode(w.POSITION_MANAGER_UPDATE(), params.positionManager, params.approve)
    );

    assertEq(w.hashPositionManagerUpdate(params), expectedHash);
    assertEq(
      w.hashPositionManagerUpdate(params),
      vm.eip712HashStruct('PositionManagerUpdate', abi.encode(params))
    );
  }

  function test_hash_tokenizedDeposit_fuzz(
    ITokenizationSpoke.TokenizedDeposit calldata params
  ) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.TOKENIZED_DEPOSIT_TYPEHASH(), params));
    assertEq(w.hashTokenizedDeposit(params), expectedHash);
    assertEq(w.hashTokenizedDeposit(params), vm.eip712HashStruct('TokenizedDeposit', abi.encode(params)));
  }

  function test_hash_tokenizedMint_fuzz(
    ITokenizationSpoke.TokenizedMint calldata params
  ) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.TOKENIZED_MINT_TYPEHASH(), params));
    assertEq(w.hashTokenizedMint(params), expectedHash);
    assertEq(w.hashTokenizedMint(params), vm.eip712HashStruct('TokenizedMint', abi.encode(params)));
  }

  function test_hash_tokenizedWithdraw_fuzz(
    ITokenizationSpoke.TokenizedWithdraw calldata params
  ) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.TOKENIZED_WITHDRAW_TYPEHASH(), params));
    assertEq(w.hashTokenizedWithdraw(params), expectedHash);
    assertEq(w.hashTokenizedWithdraw(params), vm.eip712HashStruct('TokenizedWithdraw', abi.encode(params)));
  }

  function test_hash_tokenizedRedeem_fuzz(
    ITokenizationSpoke.TokenizedRedeem calldata params
  ) public view {
    bytes32 expectedHash = keccak256(abi.encode(w.TOKENIZED_REDEEM_TYPEHASH(), params));
    assertEq(w.hashTokenizedRedeem(params), expectedHash);
    assertEq(w.hashTokenizedRedeem(params), vm.eip712HashStruct('TokenizedRedeem', abi.encode(params)));
  }
}
