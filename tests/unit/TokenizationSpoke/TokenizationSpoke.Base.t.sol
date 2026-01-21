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
  ) internal returns (ITokenizationSpoke.VaultDeposit memory) {
    return
      ITokenizationSpoke.VaultDeposit({
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
  ) internal returns (ITokenizationSpoke.VaultMint memory) {
    return
      ITokenizationSpoke.VaultMint({
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
  ) internal returns (ITokenizationSpoke.VaultWithdraw memory) {
    return
      ITokenizationSpoke.VaultWithdraw({
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
  ) internal returns (ITokenizationSpoke.VaultRedeem memory) {
    return
      ITokenizationSpoke.VaultRedeem({
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
        nonce: vault.nonces(who, vault.PERMIT_NONCE_KEY()) // can only use permit nonce key namespace
      });
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    ITokenizationSpoke.VaultDeposit memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('VaultDeposit', abi.encode(params)));
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    ITokenizationSpoke.VaultMint memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('VaultMint', abi.encode(params)));
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    ITokenizationSpoke.VaultWithdraw memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('VaultWithdraw', abi.encode(params)));
  }

  function _getTypedDataHash(
    ITokenizationSpoke vault,
    ITokenizationSpoke.VaultRedeem memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('VaultRedeem', abi.encode(params)));
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
}

contract TokenizationSpokeInitTest is TokenizationSpokeBaseTest {
  function test_constructor_reverts_when_invalid_setup() public {
    uint256 invalidAssetId = vm.randomUint(hub1.getAssetCount(), UINT256_MAX);
    vm.expectRevert();
    new TokenizationSpokeInstance(address(hub1), invalidAssetId);

    vm.expectRevert();
    new TokenizationSpokeInstance(address(0), vm.randomUint());
  }

  function test_constructor_asset_correctly_set() public {
    uint256 assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    TokenizationSpokeInstance instance = new TokenizationSpokeInstance(address(hub1), assetId);
    assertEq(instance.asset(), hub1.getAsset(assetId).underlying);
    assertEq(instance.decimals(), hub1.getAsset(assetId).decimals);
  }

  function test_setUp() public {
    assertEq(daiVault.name(), SHARE_NAME);
    assertEq(daiVault.symbol(), SHARE_SYMBOL);
    assertEq(daiVault.decimals(), tokenList.dai.decimals());

    assertEq(daiVault.asset(), address(tokenList.dai));
    assertEq(daiVault.assetId(), daiAssetId);
    assertEq(daiVault.hub(), address(hub1));

    assertEq(daiVault.PERMIT_NONCE_KEY(), 0);

    assertEq(daiVault.totalAssets(), 0);
    assertEq(daiVault.totalSupply(), 0);
    assertEq(daiVault.balanceOf(vm.randomAddress()), 0);
  }

  function test_configuration() public view {
    ProxyAdmin proxyAdmin = ProxyAdmin(_getProxyAdminAddress(address(daiVault)));
    assertEq(proxyAdmin.owner(), ADMIN);
    assertEq(proxyAdmin.UPGRADE_INTERFACE_VERSION(), '5.0.0');
    assertEq(
      _getProxyInitializedVersion(address(daiVault)),
      TokenizationSpokeInstance(address(daiVault)).SPOKE_REVISION()
    );
    address implementation = _getImplementationAddress(address(daiVault));
    assertEq(_getProxyInitializedVersion(implementation), type(uint64).max);
  }
}
