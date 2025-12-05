// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import 'src/Spoke/Instances/VaultSpokeInstance.sol';
import 'src/Spoke/Interfaces/IVaultSpoke.sol';

contract VaultSpokeBaseTest is SpokeBase {
  IVaultSpoke public vault;
  address public proxyAdminOwner = makeAddr('proxyAdminOwner');

  function setUp() public override {
    super.setUp();
    address deployer = makeAddr('deployer');
    address vaultImpl = address(new VaultSpokeInstance(address(hub1), daiAssetId));
    vault = IVaultSpoke(
      _proxify(
        deployer,
        vaultImpl,
        proxyAdminOwner,
        abi.encodeCall(VaultSpoke.initialize, ('hub1-DAI'))
      )
    );
    // Add VaultSpoke to Hub
    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK,
      active: true,
      paused: false
    });
    vm.prank(ADMIN);
    hub1.addSpoke(daiAssetId, address(vault), config);
  }

  function _depositFromUser(address user, uint256 amount) internal {
    deal(address(tokenList.dai), user, amount);

    vm.startPrank(user);
    tokenList.dai.approve(address(vault), amount);
    vault.deposit(amount, user);
    vm.stopPrank();
  }

  function _depositData(
    IVaultSpoke vault_,
    address who,
    uint256 amount,
    uint256 deadline
  ) internal view returns (EIP712Types.VaultDeposit memory) {
    return
      EIP712Types.VaultDeposit({
        depositor: who,
        assets: amount,
        receiver: who,
        nonce: vault_.nonces(who),
        deadline: deadline
      });
  }

  function _mintData(
    IVaultSpoke vault_,
    address who,
    uint256 shares,
    uint256 deadline
  ) internal view returns (EIP712Types.VaultMint memory) {
    return
      EIP712Types.VaultMint({
        depositor: who,
        shares: shares,
        receiver: who,
        nonce: vault_.nonces(who),
        deadline: deadline
      });
  }

  function _withdrawData(
    IVaultSpoke vault_,
    address who,
    uint256 assets,
    uint256 deadline
  ) internal view returns (EIP712Types.VaultWithdraw memory) {
    return
      EIP712Types.VaultWithdraw({
        owner: who,
        assets: assets,
        receiver: who,
        nonce: vault_.nonces(who),
        deadline: deadline
      });
  }

  function _redeemData(
    IVaultSpoke vault_,
    address who,
    uint256 shares,
    uint256 deadline
  ) internal view returns (EIP712Types.VaultRedeem memory) {
    return
      EIP712Types.VaultRedeem({
        owner: who,
        shares: shares,
        receiver: who,
        nonce: vault_.nonces(who),
        deadline: deadline
      });
  }

  function _getVaultSignature(
    uint256 userPk,
    bytes32 structHash
  ) internal view returns (bytes memory) {
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', vault.DOMAIN_SEPARATOR(), structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    return abi.encodePacked(r, s, v);
  }

  function _getTypedDataHash(
    IVaultSpoke _vault,
    EIP712Types.VaultDeposit memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_vault, vm.eip712HashStruct('VaultDeposit', abi.encode(_params)));
  }

  function _getTypedDataHash(
    IVaultSpoke _vault,
    EIP712Types.VaultMint memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_vault, vm.eip712HashStruct('VaultMint', abi.encode(_params)));
  }

  function _getTypedDataHash(
    IVaultSpoke _vault,
    EIP712Types.VaultWithdraw memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_vault, vm.eip712HashStruct('VaultWithdraw', abi.encode(_params)));
  }

  function _getTypedDataHash(
    IVaultSpoke _vault,
    EIP712Types.VaultRedeem memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_vault, vm.eip712HashStruct('VaultRedeem', abi.encode(_params)));
  }

  function _typedDataHash(IVaultSpoke _vault, bytes32 typeHash) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _vault.DOMAIN_SEPARATOR(), typeHash));
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    return abi.encodePacked(r, s, v);
  }
}
