// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract VaultSpokeBaseTest is Base {
  IVaultSpoke public daiVault;
  string public constant SHARE_NAME = 'Core Hub DAI';
  string public constant SHARE_SYMBOL = 'chDAI';

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    daiVault = _deployVaultSpoke(hub1, daiAssetId, SHARE_NAME, SHARE_SYMBOL, ADMIN);
    _configureVaultSpoke(daiVault, hub1, daiAssetId);
  }

  function _depositData(
    IVaultSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.VaultDeposit memory) {
    return
      EIP712Types.VaultDeposit({
        depositor: who,
        assets: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _depositData(
    IVaultSpoke vault,
    address who,
    uint256 amount,
    uint256 deadline
  ) internal view returns (EIP712Types.VaultDeposit memory) {
    return
      EIP712Types.VaultDeposit({
        depositor: who,
        assets: amount,
        receiver: who,
        nonce: vault.nonces(who),
        deadline: deadline
      });
  }

  function _mintData(
    IVaultSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.VaultMint memory) {
    return
      EIP712Types.VaultMint({
        depositor: who,
        shares: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _mintData(
    IVaultSpoke vault,
    address who,
    uint256 shares,
    uint256 deadline
  ) internal view returns (EIP712Types.VaultMint memory) {
    return
      EIP712Types.VaultMint({
        depositor: who,
        shares: shares,
        receiver: who,
        nonce: vault.nonces(who),
        deadline: deadline
      });
  }

  function _withdrawData(
    IVaultSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.VaultWithdraw memory) {
    return
      EIP712Types.VaultWithdraw({
        owner: who,
        assets: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _withdrawData(
    IVaultSpoke vault,
    address who,
    uint256 assets,
    uint256 deadline
  ) internal view returns (EIP712Types.VaultWithdraw memory) {
    return
      EIP712Types.VaultWithdraw({
        owner: who,
        assets: assets,
        receiver: who,
        nonce: vault.nonces(who),
        deadline: deadline
      });
  }

  function _redeemData(
    IVaultSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.VaultRedeem memory) {
    return
      EIP712Types.VaultRedeem({
        owner: who,
        shares: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _redeemData(
    IVaultSpoke vault,
    address who,
    uint256 shares,
    uint256 deadline
  ) internal view returns (EIP712Types.VaultRedeem memory) {
    return
      EIP712Types.VaultRedeem({
        owner: who,
        shares: shares,
        receiver: who,
        nonce: vault.nonces(who),
        deadline: deadline
      });
  }

  function _permitData(
    IVaultSpoke vault,
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
    IVaultSpoke vault,
    EIP712Types.VaultDeposit memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('VaultDeposit', abi.encode(params)));
  }

  function _getTypedDataHash(
    IVaultSpoke vault,
    EIP712Types.VaultMint memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('VaultMint', abi.encode(params)));
  }

  function _getTypedDataHash(
    IVaultSpoke vault,
    EIP712Types.VaultWithdraw memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('VaultWithdraw', abi.encode(params)));
  }

  function _getTypedDataHash(
    IVaultSpoke vault,
    EIP712Types.VaultRedeem memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('VaultRedeem', abi.encode(params)));
  }

  function _getTypedDataHash(
    IVaultSpoke vault,
    EIP712Types.Permit memory params
  ) internal view returns (bytes32) {
    return _typedDataHash(vault, vm.eip712HashStruct('Permit', abi.encode(params)));
  }

  function _typedDataHash(IVaultSpoke vault, bytes32 typeHash) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', vault.DOMAIN_SEPARATOR(), typeHash));
  }

  function _assertVaultHasNoBalanceOrAllowance(IVaultSpoke vault, address who) internal {
    _assertEntityHasNoBalanceOrAllowance({
      underlying: IERC20(vault.asset()),
      entity: address(vault),
      user: who
    });
  }

  function _deposit(IVaultSpoke vault, address user, uint256 amount) internal {
    deal(address(tokenList.dai), user, amount);

    vm.startPrank(user);
    tokenList.dai.approve(address(vault), amount);
    vault.deposit(amount, user);
    vm.stopPrank();
  }
}

contract VaultSpokeInitTest is VaultSpokeBaseTest {
  function test_constructor_reverts_when_invalid_setup() public {
    uint256 invalidAssetId = vm.randomUint(hub1.getAssetCount(), UINT256_MAX);
    vm.expectRevert();
    new VaultSpokeInstance(address(hub1), invalidAssetId);

    vm.expectRevert();
    new VaultSpokeInstance(address(0), vm.randomUint());
  }

  function test_constructor_asset_correctly_set() public {
    uint256 assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    VaultSpokeInstance instance = new VaultSpokeInstance(address(hub1), assetId);
    assertEq(instance.asset(), hub1.getAsset(assetId).underlying);
    assertEq(instance.decimals(), hub1.getAsset(assetId).decimals);
  }

  function test_deploy_reverts_InvalidHub() public {
    address invalidHub = address(0);
    vm.expectRevert();
    new VaultSpokeInstance(invalidHub, daiAssetId);
  }

  /// @dev Cannot directly initialize the implementation contract
  function test_cannot_init_impl() public {
    VaultSpokeInstance vaultImpl = new VaultSpokeInstance(address(hub1), daiAssetId);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vaultImpl.initialize('impl name', 'impl symbol');
  }

  function test_setUp() public {
    assertEq(daiVault.name(), SHARE_NAME);
    assertEq(daiVault.symbol(), SHARE_SYMBOL);
    assertEq(daiVault.decimals(), tokenList.dai.decimals());

    assertEq(daiVault.asset(), address(tokenList.dai));
    assertEq(daiVault.assetId(), daiAssetId);
    assertEq(daiVault.hub(), address(hub1));

    assertEq(daiVault.PERMIT_NONCE_KEY(), 0);
    assertEq(daiVault.MAX_ALLOWED_SPOKE_CAP(), hub1.MAX_ALLOWED_SPOKE_CAP());

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
      VaultSpokeInstance(address(daiVault)).SPOKE_REVISION()
    );
    address implementation = _getImplementationAddress(address(daiVault));
    assertEq(_getProxyInitializedVersion(implementation), type(uint64).max);
  }
}
