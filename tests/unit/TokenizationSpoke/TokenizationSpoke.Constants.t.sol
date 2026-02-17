// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

contract TokenizationSpokeConstantsTest is TokenizationSpokeBaseTest {
  function test_eip712Domain() public {
    ITokenizationSpoke instance = _deployTokenizationSpoke(
      hub1,
      daiAssetId,
      'Core Hub DAI',
      'chDAI',
      ADMIN
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
    assertEq(name, 'Tokenization Spoke');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    ITokenizationSpoke instance = _deployTokenizationSpoke(
      hub1,
      daiAssetId,
      'Core Hub DAI',
      'chDAI',
      ADMIN
    );
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('Tokenization Spoke'),
        keccak256('1'),
        block.chainid,
        address(instance)
      )
    );
    assertEq(instance.DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  function test_deposit_typeHash() public view {
    assertEq(daiVault.DEPOSIT_TYPEHASH(), vm.eip712HashType('TokenizedDeposit'));
    assertEq(
      daiVault.DEPOSIT_TYPEHASH(),
      keccak256(
        'TokenizedDeposit(address depositor,uint256 assets,address receiver,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_mint_typeHash() public view {
    assertEq(daiVault.MINT_TYPEHASH(), vm.eip712HashType('TokenizedMint'));
    assertEq(
      daiVault.MINT_TYPEHASH(),
      keccak256(
        'TokenizedMint(address depositor,uint256 shares,address receiver,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_withdraw_typeHash() public view {
    assertEq(daiVault.WITHDRAW_TYPEHASH(), vm.eip712HashType('TokenizedWithdraw'));
    assertEq(
      daiVault.WITHDRAW_TYPEHASH(),
      keccak256(
        'TokenizedWithdraw(address owner,uint256 assets,address receiver,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_redeem_typeHash() public view {
    assertEq(daiVault.REDEEM_TYPEHASH(), vm.eip712HashType('TokenizedRedeem'));
    assertEq(
      daiVault.REDEEM_TYPEHASH(),
      keccak256(
        'TokenizedRedeem(address owner,uint256 shares,address receiver,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_permit_typeHash() public view {
    assertEq(daiVault.PERMIT_TYPEHASH(), vm.eip712HashType('Permit'));
    assertEq(
      daiVault.PERMIT_TYPEHASH(),
      keccak256(
        'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
      )
    );
  }
}
