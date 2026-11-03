// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {LegacySpokeInstance} from 'tests/helpers/mocks/LegacySpokeInstance.sol';

/// @dev Upgrades a revision 1 proxy (oracle and limit in implementation immutables) to the canonical implementation.
contract SpokeLegacyUpgradeTest is Base {
  /// @dev Slot holding the oracle and the max user reserves limit since revision 2.
  bytes32 internal constant ORACLE_SLOT = bytes32(uint256(8));
  uint16 internal constant LEGACY_LIMIT = 10;

  ISpoke internal legacySpoke;
  IAaveOracle internal legacyOracle;
  address internal spokeImpl;
  uint256 internal wethReserveId;
  uint256 internal daiReserveId;

  struct Snapshot {
    address oracle;
    uint16 maxUserReservesLimit;
    uint256 reserveCount;
    ISpoke.LiquidationConfig liquidationConfig;
    uint256 aliceSuppliedShares;
    uint256 aliceDrawnDebt;
    uint256 alicePremiumDebt;
    uint256 bobSuppliedShares;
    uint256 aliceHealthFactor;
    uint256 aliceRiskPremium;
    address authority;
  }

  function setUp() public override {
    super.setUp();
    spokeImpl = address(AaveV4TestOrchestration.deploySpokeImplementation());
    legacyOracle = new AaveOracle(8);
    legacySpoke = ISpoke(
      address(
        new TransparentUpgradeableProxy(
          address(new LegacySpokeInstance(address(legacyOracle), LEGACY_LIMIT)),
          ADMIN,
          abi.encodeCall(LegacySpokeInstance.initialize, (address(accessManager)))
        )
      )
    );
    legacyOracle.setSpoke(address(legacySpoke));
    setUpRoles(hub1, legacySpoke, accessManager);

    wethReserveId = _listReserve(wethAssetId, 2000e8);
    daiReserveId = _listReserve(daiAssetId, 1e8);

    vm.prank(alice);
    tokenList.weth.approve(address(legacySpoke), UINT256_MAX);
    vm.prank(bob);
    tokenList.dai.approve(address(legacySpoke), UINT256_MAX);
    vm.prank(alice);
    tokenList.dai.approve(address(legacySpoke), UINT256_MAX);

    SpokeActions.supply(legacySpoke, daiReserveId, bob, 10_000e18, bob);
    SpokeActions.supplyCollateral(legacySpoke, wethReserveId, alice, 10e18, alice);
    SpokeActions.borrow(legacySpoke, daiReserveId, alice, 5_000e18, alice);
    skip(30 days);
  }

  function test_upgrade_preserves_state() public {
    assertEq(ProxyHelper.getProxyInitializedVersion(address(legacySpoke)), 1);
    // revision 2 slot must be unused by revision 1
    assertEq(vm.load(address(legacySpoke), ORACLE_SLOT), bytes32(0));

    Snapshot memory before = _snapshot();
    assertEq(before.oracle, address(legacyOracle));
    assertEq(before.maxUserReservesLimit, LEGACY_LIMIT);

    _upgrade(address(legacyOracle), LEGACY_LIMIT);

    assertEq(ProxyHelper.getProxyInitializedVersion(address(legacySpoke)), 2);
    assertEq(abi.encode(_snapshot()), abi.encode(before));
  }

  function test_upgrade_operationsAfterUpgrade() public {
    _upgrade(address(legacyOracle), LEGACY_LIMIT);

    SpokeActions.borrow(legacySpoke, daiReserveId, alice, 1_000e18, alice);
    SpokeActions.repay(legacySpoke, daiReserveId, alice, UINT256_MAX, alice);
    (uint256 drawnDebt, uint256 premiumDebt) = legacySpoke.getUserDebt(daiReserveId, alice);
    assertEq(drawnDebt + premiumDebt, 0);
  }

  function test_upgrade_emitsSetSpokeImmutables() public {
    vm.expectEmit(address(legacySpoke));
    emit ISpoke.SetSpokeImmutables(address(legacyOracle), LEGACY_LIMIT);
    _upgrade(address(legacyOracle), LEGACY_LIMIT);
  }

  function _upgrade(address oracle, uint16 maxUserReservesLimit) internal {
    vm.prank(ProxyHelper.getProxyAdmin(address(legacySpoke)));
    ITransparentUpgradeableProxy(address(legacySpoke)).upgradeToAndCall(
      spokeImpl,
      abi.encodeCall(
        ISpokeInstance.initialize,
        (address(accessManager), oracle, maxUserReservesLimit)
      )
    );
  }

  function _snapshot() internal view returns (Snapshot memory s) {
    s.oracle = legacySpoke.ORACLE();
    s.maxUserReservesLimit = legacySpoke.MAX_USER_RESERVES_LIMIT();
    s.reserveCount = legacySpoke.getReserveCount();
    s.liquidationConfig = legacySpoke.getLiquidationConfig();
    s.aliceSuppliedShares = legacySpoke.getUserSuppliedShares(wethReserveId, alice);
    (s.aliceDrawnDebt, s.alicePremiumDebt) = legacySpoke.getUserDebt(daiReserveId, alice);
    s.bobSuppliedShares = legacySpoke.getUserSuppliedShares(daiReserveId, bob);
    ISpoke.UserAccountData memory accountData = legacySpoke.getUserAccountData(alice);
    s.aliceHealthFactor = accountData.healthFactor;
    s.aliceRiskPremium = accountData.riskPremium;
    s.authority = IAccessManaged(address(legacySpoke)).authority();
  }

  function _listReserve(uint256 assetId, uint256 price) internal returns (uint256 reserveId) {
    vm.prank(HUB_ADMIN);
    hub1.addSpoke(
      assetId,
      address(legacySpoke),
      IHub.SpokeConfig({
        active: true,
        halted: false,
        addCap: MAX_ALLOWED_SPOKE_CAP,
        drawCap: MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
      })
    );
    address priceFeed = address(new MockPriceFeed(8, 'mock price feed', price));
    vm.prank(SPOKE_ADMIN);
    reserveId = legacySpoke.addReserve(
      address(hub1),
      assetId,
      priceFeed,
      _getDefaultReserveConfig(10_00),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      })
    );
  }
}
