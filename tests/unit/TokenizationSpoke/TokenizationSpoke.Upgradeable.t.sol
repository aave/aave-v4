// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';
import {MockTokenizationSpokeInstance} from 'tests/mocks/MockTokenizationSpokeInstance.sol';

contract TokenizationSpokeUpgradeableTest is TokenizationSpokeBaseTest {
  address internal proxyAdminOwner = makeAddr('proxyAdminOwner');

  function test_implementation_constructor_fuzz(uint64 revision) public {
    address vaultImplAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectEmit(vaultImplAddress);
    emit Initializable.Initialized(type(uint64).max);

    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(revision);

    assertEq(address(vaultImpl), vaultImplAddress);
    assertEq(vaultImpl.SPOKE_REVISION(), revision);
    assertEq(_getProxyInitializedVersion(vaultImplAddress), type(uint64).max);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vaultImpl.initialize(SHARE_NAME, SHARE_SYMBOL);
  }

  function test_proxy_constructor_fuzz(uint64 revision) public {
    revision = uint64(bound(revision, 1, type(uint64).max));

    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(revision);
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
    ITokenizationSpoke vaultProxy = ITokenizationSpoke(
      address(
        new TransparentUpgradeableProxy(
          address(vaultImpl),
          proxyAdminOwner,
          abi.encodeCall(TokenizationSpokeInstance.initialize, (SHARE_NAME, SHARE_SYMBOL))
        )
      )
    );

    assertEq(address(vaultProxy), vaultProxyAddress);
    assertEq(_getProxyAdminAddress(address(vaultProxy)), proxyAdminAddress);
    assertEq(_getImplementationAddress(address(vaultProxy)), address(vaultImpl));

    assertEq(_getProxyInitializedVersion(address(vaultProxy)), revision);
    assertEq(vaultProxy.name(), SHARE_NAME);
    assertEq(vaultProxy.symbol(), SHARE_SYMBOL);
  }

  function test_proxy_reinitialization_fuzz(uint64 initialRevision) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max - 1));
    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(initialRevision);
    ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(vaultImpl),
          proxyAdminOwner,
          abi.encodeCall(TokenizationSpokeInstance.initialize, (SHARE_NAME, SHARE_SYMBOL))
        )
      )
    );

    string memory originalName = ITokenizationSpoke(address(vaultProxy)).name();

    uint64 secondRevision = uint64(vm.randomUint(initialRevision + 1, type(uint64).max));
    TokenizationSpokeInstance vaultImpl2 = _deployMockTokenizationSpokeInstance(secondRevision);

    string memory newShareName = 'New Share Name';
    string memory newShareSymbol = 'New Share Symbol';
    vm.expectEmit(address(vaultProxy));
    emit Initializable.Initialized(secondRevision);
    vm.recordLogs();
    vm.prank(_getProxyAdminAddress(address(vaultProxy)));
    vaultProxy.upgradeToAndCall(
      address(vaultImpl2),
      _getInitializeCalldata(newShareName, newShareSymbol)
    );

    assertEq(ITokenizationSpoke(address(vaultProxy)).name(), newShareName);
    assertEq(ITokenizationSpoke(address(vaultProxy)).symbol(), newShareSymbol);
    assertNotEq(ITokenizationSpoke(address(vaultProxy)).name(), originalName);
  }

  function test_proxy_constructor_revertsWith_InvalidInitialization_ZeroRevision() public {
    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(0);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    new TransparentUpgradeableProxy(
      address(vaultImpl),
      proxyAdminOwner,
      abi.encodeCall(TokenizationSpokeInstance.initialize, (SHARE_NAME, SHARE_SYMBOL))
    );
  }

  function test_proxy_constructor_fuzz_revertsWith_InvalidInitialization(
    uint64 initialRevision
  ) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max));

    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(initialRevision);
    ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(vaultImpl),
          proxyAdminOwner,
          _getInitializeCalldata(SHARE_NAME, SHARE_SYMBOL)
        )
      )
    );

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(vaultProxy)));
    vaultProxy.upgradeToAndCall(
      address(vaultImpl),
      _getInitializeCalldata(SHARE_NAME, SHARE_SYMBOL)
    );

    uint64 secondRevision = uint64(vm.randomUint(0, initialRevision - 1));
    TokenizationSpokeInstance vaultImpl2 = _deployMockTokenizationSpokeInstance(secondRevision);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(vaultProxy)));
    vaultProxy.upgradeToAndCall(
      address(vaultImpl2),
      _getInitializeCalldata(SHARE_NAME, SHARE_SYMBOL)
    );
  }

  function test_proxy_reinitialization_revertsWith_CallerNotProxyAdmin() public {
    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(1);
    ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(vaultImpl),
          proxyAdminOwner,
          _getInitializeCalldata(SHARE_NAME, SHARE_SYMBOL)
        )
      )
    );

    TokenizationSpokeInstance vaultImpl2 = _deployMockTokenizationSpokeInstance(2);
    vm.expectRevert();
    vm.prank(makeUser());
    vaultProxy.upgradeToAndCall(
      address(vaultImpl2),
      _getInitializeCalldata(SHARE_NAME, SHARE_SYMBOL)
    );
  }

  function _getInitializeCalldata(
    string memory shareName,
    string memory shareSymbol
  ) internal pure returns (bytes memory) {
    return abi.encodeCall(TokenizationSpokeInstance.initialize, (shareName, shareSymbol));
  }

  function _deployMockTokenizationSpokeInstance(
    uint64 revision
  ) internal returns (TokenizationSpokeInstance) {
    return
      TokenizationSpokeInstance(
        address(new MockTokenizationSpokeInstance(revision, address(hub1), daiAssetId))
      );
  }
}
