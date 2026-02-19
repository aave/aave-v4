// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract TokenizationSpokeBaseTest is Base {
  ITokenizationSpoke public daiVault;
  string public constant SHARE_NAME = 'Core Hub DAI';
  string public constant SHARE_SYMBOL = 'chDAI';

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    daiVault = _deployTokenizationSpoke(hub1, daiAssetId, SHARE_NAME, SHARE_SYMBOL, ADMIN);
    _registerTokenizationSpoke(hub1, daiAssetId, daiVault);
  }

  function _depositData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (ITokenizationSpoke.TokenizedDeposit memory) {
    return
      ITokenizationSpoke.TokenizedDeposit({
        depositor: who,
        assets: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _mintData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (ITokenizationSpoke.TokenizedMint memory) {
    return
      ITokenizationSpoke.TokenizedMint({
        depositor: who,
        shares: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _withdrawData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (ITokenizationSpoke.TokenizedWithdraw memory) {
    return
      ITokenizationSpoke.TokenizedWithdraw({
        owner: who,
        assets: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _redeemData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (ITokenizationSpoke.TokenizedRedeem memory) {
    return
      ITokenizationSpoke.TokenizedRedeem({
        owner: who,
        shares: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _permitData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Permit memory) {
    return
      EIP712Types.Permit({
        owner: who,
        spender: address(vault),
        value: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        deadline: deadline,
        nonce: vault.nonces(who, vault.PERMIT_NONCE_NAMESPACE()) // can only use permit nonce key namespace
      });
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    ITokenizationSpoke.TokenizedDeposit memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('TokenizedDeposit', abi.encode(params)));
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    ITokenizationSpoke.TokenizedMint memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('TokenizedMint', abi.encode(params)));
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    ITokenizationSpoke.TokenizedWithdraw memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('TokenizedWithdraw', abi.encode(params)));
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    ITokenizationSpoke.TokenizedRedeem memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('TokenizedRedeem', abi.encode(params)));
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    EIP712Types.Permit memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('Permit', abi.encode(params)));
  }

  function _typedDataHash(
    ITokenizationSpoke vault,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', vault.DOMAIN_SEPARATOR(), typeHash));
  }

  function _assertVaultHasNoBalanceOrAllowance(ITokenizationSpoke vault, address who) internal {
    _assertEntityHasNoBalanceOrAllowance({
      underlying: IERC20(vault.asset()),
      entity: address(vault),
      user: who
    });
  }

  function _simulateYield(ITokenizationSpoke vault, uint256 amount) internal {
    IHub hub = IHub(vault.hub());
    TestnetERC20 asset = TestnetERC20(vault.asset());
    uint256 assetId = vault.assetId();

    asset.mint(address(hub), amount);
    vm.startPrank(address(spoke2));
    hub.add(assetId, amount);
    _mockInterestRateBps(100_00);
    hub.draw(assetId, amount, address(spoke2));
    skip(365 days);
    asset.mint(address(hub), amount);
    hub.restore(assetId, amount, IHubBase.PremiumDelta(0, 0, 0));
    vm.stopPrank();
  }
}
