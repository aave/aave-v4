// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/tokenization-spoke/TokenizationSpoke.Base.t.sol';
import {MockTokenizationSpokeInstance} from 'tests/helpers/mocks/MockTokenizationSpokeInstance.sol';
import {BeaconProxy} from 'src/dependencies/openzeppelin/BeaconProxy.sol';
import {UpgradeableBeacon} from 'src/dependencies/openzeppelin/UpgradeableBeacon.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';

contract TokenizationSpokeUpgradeableTest is TokenizationSpokeBaseTest {
  address internal beaconOwner = makeAddr('beaconOwner');

  function test_implementation_constructor_fuzz(uint64 revision) public {
    address vaultImplAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectEmit(vaultImplAddress);
    emit Initializable.Initialized(type(uint64).max);

    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(revision);

    assertEq(address(vaultImpl), vaultImplAddress);
    assertEq(vaultImpl.SPOKE_REVISION(), revision);
    assertEq(ProxyHelper.getProxyInitializedVersion(vaultImplAddress), type(uint64).max);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vaultImpl.initialize(address(hub1), address(tokenList.dai), SHARE_NAME, SHARE_SYMBOL);
  }

  function test_proxy_constructor_fuzz(uint64 revision) public {
    revision = uint64(bound(revision, 1, type(uint64).max));

    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(revision);
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), beaconOwner);

    address vaultProxyAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectEmit(vaultProxyAddress);
    emit IERC1967.BeaconUpgraded(address(beacon));
    vm.expectEmit(vaultProxyAddress);
    emit ITokenizationSpoke.SetTokenizationSpokeImmutables(address(hub1), daiAssetId);
    vm.expectEmit(vaultProxyAddress);
    emit Initializable.Initialized(revision);
    ITokenizationSpokeInstance vaultProxy = ITokenizationSpokeInstance(
      address(new BeaconProxy(address(beacon), _getInitializeCalldata()))
    );

    assertEq(address(vaultProxy), vaultProxyAddress);
    assertEq(ProxyHelper.getBeacon(address(vaultProxy)), address(beacon));
    assertEq(beacon.implementation(), address(vaultImpl));

    assertEq(ProxyHelper.getProxyInitializedVersion(address(vaultProxy)), revision);
    assertEq(vaultProxy.name(), SHARE_NAME);
    assertEq(vaultProxy.symbol(), SHARE_SYMBOL);
  }

  function test_proxy_reinitialization_fuzz(uint64 initialRevision) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max - 1));
    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(initialRevision);
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), beaconOwner);
    ITokenizationSpokeInstance vaultProxy = ITokenizationSpokeInstance(
      address(new BeaconProxy(address(beacon), _getInitializeCalldata()))
    );

    string memory originalName = vaultProxy.name();

    uint64 secondRevision = uint64(vm.randomUint(initialRevision + 1, type(uint64).max));
    TokenizationSpokeInstance vaultImpl2 = _deployMockTokenizationSpokeInstance(secondRevision);

    vm.prank(beaconOwner);
    beacon.upgradeTo(address(vaultImpl2));

    string memory newShareName = 'New Share Name';
    string memory newShareSymbol = 'New Share Symbol';
    vm.expectEmit(address(vaultProxy));
    emit ITokenizationSpoke.SetTokenizationSpokeImmutables(address(hub1), daiAssetId);
    vm.expectEmit(address(vaultProxy));
    emit Initializable.Initialized(secondRevision);
    vaultProxy.initialize(address(hub1), address(tokenList.dai), newShareName, newShareSymbol);

    assertEq(vaultProxy.name(), newShareName);
    assertEq(vaultProxy.symbol(), newShareSymbol);
    assertNotEq(vaultProxy.name(), originalName);
  }

  function test_proxy_constructor_revertsWith_InvalidInitialization_ZeroRevision() public {
    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(0);
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), beaconOwner);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    new BeaconProxy(address(beacon), _getInitializeCalldata());
  }

  function test_proxy_reinitialization_fuzz_revertsWith_InvalidInitialization(
    uint64 initialRevision
  ) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max));

    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(initialRevision);
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), beaconOwner);
    ITokenizationSpokeInstance vaultProxy = ITokenizationSpokeInstance(
      address(new BeaconProxy(address(beacon), _getInitializeCalldata()))
    );

    // Re-initializing at the same revision reverts.
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vaultProxy.initialize(address(hub1), address(tokenList.dai), SHARE_NAME, SHARE_SYMBOL);

    // Re-initializing after a downgrade to a lower revision reverts.
    uint64 secondRevision = uint64(vm.randomUint(0, initialRevision - 1));
    TokenizationSpokeInstance vaultImpl2 = _deployMockTokenizationSpokeInstance(secondRevision);
    vm.prank(beaconOwner);
    beacon.upgradeTo(address(vaultImpl2));

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vaultProxy.initialize(address(hub1), address(tokenList.dai), SHARE_NAME, SHARE_SYMBOL);
  }

  function test_beacon_upgrade_revertsWith_CallerNotOwner() public {
    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(1);
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), beaconOwner);
    new BeaconProxy(address(beacon), _getInitializeCalldata());

    TokenizationSpokeInstance vaultImpl2 = _deployMockTokenizationSpokeInstance(2);
    address notOwner = _makeUser();
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
    vm.prank(notOwner);
    beacon.upgradeTo(address(vaultImpl2));
  }

  function test_beacon_upgrade_propagatesImplementationToAllProxies() public {
    TokenizationSpokeInstance vaultImpl = _deployMockTokenizationSpokeInstance(1);
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), beaconOwner);

    ITokenizationSpokeInstance daiProxy = ITokenizationSpokeInstance(
      address(
        new BeaconProxy(
          address(beacon),
          abi.encodeCall(
            TokenizationSpokeInstance.initialize,
            (address(hub1), address(tokenList.dai), 'Core Hub DAI', 'chDAI')
          )
        )
      )
    );
    ITokenizationSpokeInstance usdxProxy = ITokenizationSpokeInstance(
      address(
        new BeaconProxy(
          address(beacon),
          abi.encodeCall(
            TokenizationSpokeInstance.initialize,
            (address(hub1), address(tokenList.usdx), 'Core Hub USDX', 'chUSDX')
          )
        )
      )
    );

    assertEq(ProxyHelper.getBeacon(address(daiProxy)), address(beacon));
    assertEq(ProxyHelper.getBeacon(address(usdxProxy)), address(beacon));
    assertEq(beacon.implementation(), address(vaultImpl));
    assertEq(daiProxy.SPOKE_REVISION(), 1);
    assertEq(usdxProxy.SPOKE_REVISION(), 1);

    TokenizationSpokeInstance vaultImpl2 = _deployMockTokenizationSpokeInstance(7);
    vm.expectEmit(address(beacon));
    emit UpgradeableBeacon.Upgraded(address(vaultImpl2));
    vm.prank(beaconOwner);
    beacon.upgradeTo(address(vaultImpl2));

    assertEq(beacon.implementation(), address(vaultImpl2));
    assertEq(daiProxy.SPOKE_REVISION(), 7);
    assertEq(usdxProxy.SPOKE_REVISION(), 7);

    assertEq(daiProxy.asset(), address(tokenList.dai));
    assertEq(daiProxy.symbol(), 'chDAI');
    assertEq(usdxProxy.asset(), address(tokenList.usdx));
    assertEq(usdxProxy.symbol(), 'chUSDX');
  }

  function _getInitializeCalldata() internal view returns (bytes memory) {
    return
      abi.encodeCall(
        TokenizationSpokeInstance.initialize,
        (address(hub1), address(tokenList.dai), SHARE_NAME, SHARE_SYMBOL)
      );
  }

  function _deployMockTokenizationSpokeInstance(
    uint64 revision
  ) internal returns (TokenizationSpokeInstance) {
    return TokenizationSpokeInstance(address(new MockTokenizationSpokeInstance(revision)));
  }
}
