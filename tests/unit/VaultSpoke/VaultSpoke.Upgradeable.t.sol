// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/VaultSpoke/VaultSpoke.Base.t.sol';
import {MockVaultSpokeInstance} from 'tests/mocks/MockVaultSpokeInstance.sol';

contract VaultSpokeUpgradeableTest is VaultSpokeBaseTest {
  address internal proxyAdminOwner = makeAddr('proxyAdminOwner');

  function test_implementation_constructor_fuzz(uint64 revision) public {
    address vaultImplAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectEmit(vaultImplAddress);
    emit Initializable.Initialized(type(uint64).max);

    VaultSpokeInstance vaultImpl = _deployMockVaultSpokeInstance(revision);

    assertEq(address(vaultImpl), vaultImplAddress);
    assertEq(vaultImpl.SPOKE_REVISION(), revision);
    assertEq(_getProxyInitializedVersion(vaultImplAddress), type(uint64).max);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vaultImpl.initialize(PREFIX);
  }

  function test_proxy_constructor_fuzz(uint64 revision) public {
    revision = uint64(bound(revision, 1, type(uint64).max));

    VaultSpokeInstance vaultImpl = _deployMockVaultSpokeInstance(revision);
    address vaultProxyAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    address proxyAdminAddress = vm.computeCreateAddress(vaultProxyAddress, 1);

    vm.expectEmit(vaultProxyAddress);
    emit IERC1967.Upgraded(address(vaultImpl));
    vm.expectEmit(vaultProxyAddress);
    emit Initializable.Initialized(revision);
    vm.expectEmit(proxyAdminAddress);
    emit Ownable.OwnershipTransferred(address(0), proxyAdminOwner);
    vm.expectEmit(vaultProxyAddress);
    emit IERC1967.AdminChanged(address(0), proxyAdminAddress);
    IVaultSpoke vaultProxy = IVaultSpoke(
      address(
        new TransparentUpgradeableProxy(
          address(vaultImpl),
          proxyAdminOwner,
          abi.encodeCall(VaultSpokeInstance.initialize, (PREFIX))
        )
      )
    );

    assertEq(address(vaultProxy), vaultProxyAddress);
    assertEq(_getProxyAdminAddress(address(vaultProxy)), proxyAdminAddress);
    assertEq(_getImplementationAddress(address(vaultProxy)), address(vaultImpl));

    assertEq(_getProxyInitializedVersion(address(vaultProxy)), revision);
    assertEq(vaultProxy.name(), string.concat(PREFIX, ' ', tokenList.dai.name()));
    assertEq(vaultProxy.symbol(), string.concat('h', tokenList.dai.symbol()));
  }

  function test_proxy_reinitialization_fuzz(uint64 initialRevision) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max - 1));
    VaultSpokeInstance vaultImpl = _deployMockVaultSpokeInstance(initialRevision);
    ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(vaultImpl),
          proxyAdminOwner,
          abi.encodeCall(VaultSpokeInstance.initialize, (PREFIX))
        )
      )
    );

    string memory originalName = IVaultSpoke(address(vaultProxy)).name();

    uint64 secondRevision = uint64(vm.randomUint(initialRevision + 1, type(uint64).max));
    VaultSpokeInstance vaultImpl2 = _deployMockVaultSpokeInstance(secondRevision);

    string memory newPrefix = 'New Prefix';
    vm.expectEmit(address(vaultProxy));
    emit Initializable.Initialized(secondRevision);
    vm.recordLogs();
    vm.prank(_getProxyAdminAddress(address(vaultProxy)));
    vaultProxy.upgradeToAndCall(address(vaultImpl2), _getInitializeCalldata(newPrefix));

    assertEq(
      IVaultSpoke(address(vaultProxy)).name(),
      string.concat(newPrefix, ' ', tokenList.dai.name())
    );
    assertEq(IVaultSpoke(address(vaultProxy)).symbol(), string.concat('h', tokenList.dai.symbol()));
    assertNotEq(IVaultSpoke(address(vaultProxy)).name(), originalName);
    // Symbol doesn't change with prefix - it's always 'h' + asset.symbol()
  }

  function test_proxy_constructor_revertsWith_InvalidInitialization_ZeroRevision() public {
    VaultSpokeInstance vaultImpl = _deployMockVaultSpokeInstance(0);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    new TransparentUpgradeableProxy(
      address(vaultImpl),
      proxyAdminOwner,
      abi.encodeCall(VaultSpokeInstance.initialize, (PREFIX))
    );
  }

  function test_proxy_constructor_fuzz_revertsWith_InvalidInitialization(
    uint64 initialRevision
  ) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max));

    VaultSpokeInstance vaultImpl = _deployMockVaultSpokeInstance(initialRevision);
    ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(vaultImpl),
          proxyAdminOwner,
          _getInitializeCalldata(PREFIX)
        )
      )
    );

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(vaultProxy)));
    vaultProxy.upgradeToAndCall(address(vaultImpl), _getInitializeCalldata(PREFIX));

    uint64 secondRevision = uint64(vm.randomUint(0, initialRevision - 1));
    VaultSpokeInstance vaultImpl2 = _deployMockVaultSpokeInstance(secondRevision);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(vaultProxy)));
    vaultProxy.upgradeToAndCall(address(vaultImpl2), _getInitializeCalldata(PREFIX));
  }

  function test_proxy_reinitialization_revertsWith_CallerNotProxyAdmin() public {
    VaultSpokeInstance vaultImpl = _deployMockVaultSpokeInstance(1);
    ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(vaultImpl),
          proxyAdminOwner,
          _getInitializeCalldata(PREFIX)
        )
      )
    );

    VaultSpokeInstance vaultImpl2 = _deployMockVaultSpokeInstance(2);
    vm.expectRevert();
    vm.prank(makeUser());
    vaultProxy.upgradeToAndCall(address(vaultImpl2), _getInitializeCalldata(PREFIX));
  }

  function _getInitializeCalldata(string memory prefix) internal pure returns (bytes memory) {
    return abi.encodeCall(VaultSpokeInstance.initialize, prefix);
  }

  function _deployMockVaultSpokeInstance(uint64 revision) internal returns (VaultSpokeInstance) {
    return
      VaultSpokeInstance(address(new MockVaultSpokeInstance(revision, address(hub1), daiAssetId)));
  }
}
