// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/tokenization-spoke/TokenizationSpoke.Base.t.sol';
import {LegacyTokenizationSpokeInstance} from 'tests/helpers/mocks/LegacyTokenizationSpokeInstance.sol';

/// @dev Upgrades a revision 1 proxy (Hub binding in implementation immutables) to the canonical implementation.
contract TokenizationSpokeLegacyUpgradeTest is TokenizationSpokeBaseTest {
  bytes32 internal constant TOKENIZATION_SPOKE_STORAGE_SLOT =
    0x245f623a0b50d834ae2ab712581dfcde6f97f1be388fe2ccaeb274dc99041500;

  ITokenizationSpoke internal legacyVault;
  TestnetERC20 internal asset;

  struct Snapshot {
    string name;
    string symbol;
    uint8 decimals;
    address hub;
    uint256 assetId;
    address asset;
    uint40 maxAllowedSpokeCap;
    bytes32 domainSeparator;
    uint256 totalSupply;
    uint256 totalAssets;
    uint256 aliceShares;
    uint256 bobShares;
    uint256 allowance;
    uint256 alicePermitNonce;
    uint256 aliceKeyedNonce;
    uint256 maxDeposit;
  }

  function setUp() public override {
    super.setUp();
    asset = tokenList.dai;
    legacyVault = ITokenizationSpoke(
      address(
        new TransparentUpgradeableProxy(
          address(new LegacyTokenizationSpokeInstance(address(hub1), address(asset))),
          ADMIN,
          abi.encodeCall(LegacyTokenizationSpokeInstance.initialize, (SHARE_NAME, SHARE_SYMBOL))
        )
      )
    );
    _registerTokenizationSpoke(hub1, daiAssetId, legacyVault, ADMIN);

    _deposit(alice, 1_000e18);
    _deposit(bob, 250e18);
    _simulateYield(legacyVault, 100e18);

    vm.startPrank(alice);
    legacyVault.approve(bob, 123e18);
    legacyVault.usePermitNonce();
    legacyVault.useNonce(7);
    vm.stopPrank();
  }

  function test_upgrade_preserves_state() public {
    assertEq(ProxyHelper.getProxyInitializedVersion(address(legacyVault)), 1);
    assertEq(vm.load(address(legacyVault), TOKENIZATION_SPOKE_STORAGE_SLOT), bytes32(0));
    assertEq(
      vm.load(address(legacyVault), bytes32(uint256(TOKENIZATION_SPOKE_STORAGE_SLOT) + 1)),
      bytes32(0)
    );

    Snapshot memory pre = _snapshot();
    address newImpl = address(new TokenizationSpokeInstance());

    vm.expectEmit(address(legacyVault));
    emit ITokenizationSpoke.SetTokenizationSpokeImmutables(address(hub1), daiAssetId);
    vm.expectEmit(address(legacyVault));
    emit Initializable.Initialized(2);
    _upgrade(newImpl);

    assertEq(ProxyHelper.getImplementation(address(legacyVault)), newImpl);
    assertEq(ProxyHelper.getProxyInitializedVersion(address(legacyVault)), 2);
    _assertEq(_snapshot(), pre);
  }

  function test_upgrade_operations_after_upgrade() public {
    _upgrade(address(new TokenizationSpokeInstance()));

    uint256 aliceShares = legacyVault.balanceOf(alice);
    uint256 expectedAssets = legacyVault.previewRedeem(aliceShares);
    uint256 aliceBalanceBefore = asset.balanceOf(alice);

    vm.prank(alice);
    assertEq(legacyVault.redeem(aliceShares, alice, alice), expectedAssets);
    assertEq(asset.balanceOf(alice), aliceBalanceBefore + expectedAssets);
    assertEq(legacyVault.balanceOf(alice), 0);

    uint256 bobShares = legacyVault.balanceOf(bob);
    assertEq(_deposit(bob, 10e18), legacyVault.balanceOf(bob) - bobShares);
  }

  function test_upgrade_revertsWith_InvalidInitialization_on_reinitialize() public {
    _upgrade(address(new TokenizationSpokeInstance()));

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(alice);
    TokenizationSpokeInstance(address(legacyVault)).initialize(
      address(hub1),
      address(tokenList.usdx),
      SHARE_NAME,
      SHARE_SYMBOL
    );
  }

  function _upgrade(address newImpl) internal {
    vm.prank(ProxyHelper.getProxyAdmin(address(legacyVault)));
    ITransparentUpgradeableProxy(address(legacyVault)).upgradeToAndCall(
      newImpl,
      abi.encodeCall(
        TokenizationSpokeInstance.initialize,
        (address(hub1), address(asset), SHARE_NAME, SHARE_SYMBOL)
      )
    );
  }

  function _deposit(address user, uint256 assets) internal returns (uint256) {
    asset.mint(user, assets);
    SpokeActions.approve({vault: legacyVault, owner: user, amount: assets});
    vm.prank(user);
    return legacyVault.deposit(assets, user);
  }

  function _snapshot() internal view returns (Snapshot memory s) {
    s.name = legacyVault.name();
    s.symbol = legacyVault.symbol();
    s.decimals = legacyVault.decimals();
    s.hub = legacyVault.hub();
    s.assetId = legacyVault.assetId();
    s.asset = legacyVault.asset();
    s.maxAllowedSpokeCap = legacyVault.MAX_ALLOWED_SPOKE_CAP();
    s.domainSeparator = legacyVault.DOMAIN_SEPARATOR();
    s.totalSupply = legacyVault.totalSupply();
    s.totalAssets = legacyVault.totalAssets();
    s.aliceShares = legacyVault.balanceOf(alice);
    s.bobShares = legacyVault.balanceOf(bob);
    s.allowance = legacyVault.allowance(alice, bob);
    s.alicePermitNonce = legacyVault.nonces(alice);
    s.aliceKeyedNonce = legacyVault.nonces(alice, 7);
    s.maxDeposit = legacyVault.maxDeposit(alice);
  }

  function _assertEq(Snapshot memory a, Snapshot memory b) internal pure {
    assertEq(a.name, b.name, 'name');
    assertEq(a.symbol, b.symbol, 'symbol');
    assertEq(a.decimals, b.decimals, 'decimals');
    assertEq(a.hub, b.hub, 'hub');
    assertEq(a.assetId, b.assetId, 'assetId');
    assertEq(a.asset, b.asset, 'asset');
    assertEq(a.maxAllowedSpokeCap, b.maxAllowedSpokeCap, 'maxAllowedSpokeCap');
    assertEq(a.domainSeparator, b.domainSeparator, 'domainSeparator');
    assertEq(a.totalSupply, b.totalSupply, 'totalSupply');
    assertEq(a.totalAssets, b.totalAssets, 'totalAssets');
    assertEq(a.aliceShares, b.aliceShares, 'aliceShares');
    assertEq(a.bobShares, b.bobShares, 'bobShares');
    assertEq(a.allowance, b.allowance, 'allowance');
    assertEq(a.alicePermitNonce, b.alicePermitNonce, 'alicePermitNonce');
    assertEq(a.aliceKeyedNonce, b.aliceKeyedNonce, 'aliceKeyedNonce');
    assertEq(a.maxDeposit, b.maxDeposit, 'maxDeposit');
  }
}
