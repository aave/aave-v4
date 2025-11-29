// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

import {UserPositionDebtWrapper} from 'tests/mocks/UserPositionDebtWrapper.sol';

contract UserPositionDebtTest is Base {
  using SafeCast for *;
  using WadRayMath for *;
  using MathUtils for uint256;

  struct BoundParams {
    uint256 drawnShares;
    uint256 premiumShares;
    int256 premiumOffsetRay;
    uint256 drawnSharesTaken;
    uint256 drawnIndex;
    uint256 riskPremium;
    uint256 restoredPremiumRay;
  }

  UserPositionDebtWrapper internal u;

  uint256 internal constant DRAWN_SHARES = 200e18;
  uint256 internal constant PREMIUM_SHARES = 99e18;
  int256 internal constant PREMIUM_OFFSET_RAY = -100e18 * 1e27;
  uint256 internal constant DRAWN_INDEX = 1.5e27;

  IHub internal hub;
  uint256 internal assetId;

  function setUp() public override {
    u = new UserPositionDebtWrapper();
    hub = hub1;
    assetId = wethAssetId;

    _mockUserDrawnShares(DRAWN_SHARES);
    _mockUserPremiumData(PREMIUM_SHARES, PREMIUM_OFFSET_RAY);
    _mockHubDrawnIndex(DRAWN_INDEX);
  }

  function test_fuzz_applyPremiumDelta(IHubBase.PremiumDelta memory premiumDelta) public {
    premiumDelta = _bound(premiumDelta);

    u.applyPremiumDelta(premiumDelta);
    assertEq(u.getUserPosition().premiumShares, PREMIUM_SHARES.add(premiumDelta.sharesDelta));
    assertEq(
      u.getUserPosition().premiumOffsetRay,
      PREMIUM_OFFSET_RAY + premiumDelta.offsetRayDelta
    );
  }

  function test_applyPremiumDelta() public {
    u.applyPremiumDelta(
      IHubBase.PremiumDelta({
        sharesDelta: -10e18,
        offsetRayDelta: 10e18 * 1e27,
        restoredPremiumRay: vm.randomUint()
      })
    );
    assertEq(u.getUserPosition().premiumShares, 89e18);
    assertEq(u.getUserPosition().premiumOffsetRay, -90e18 * 1e27);
  }

  function test_fuzz_getPremiumDelta(BoundParams memory params) public {
    params = _bound(params);
    _mockUserDrawnShares(params.drawnShares);
    _mockUserPremiumData(params.premiumShares, params.premiumOffsetRay);
    assertEq(
      u.getPremiumDelta(
        params.drawnSharesTaken,
        params.drawnIndex,
        params.riskPremium,
        params.restoredPremiumRay
      ),
      _getExpectedPremiumDelta({
        drawnIndex: params.drawnIndex,
        oldPremiumShares: params.premiumShares,
        oldPremiumOffsetRay: params.premiumOffsetRay,
        drawnShares: params.drawnShares - params.drawnSharesTaken,
        riskPremium: params.riskPremium,
        restoredPremiumRay: params.restoredPremiumRay
      })
    );
  }

  function test_getPremiumDelta() public view {
    assertEq(
      u.getPremiumDelta(0, DRAWN_INDEX, 20_00, 48.5e18 * 1e27),
      IHubBase.PremiumDelta({
        sharesDelta: -59e18, // 40 - 99
        offsetRayDelta: -40e18 * 1e27, // (60 - (248.5 - 48.5)) - (-100)
        restoredPremiumRay: 48.5e18 * 1e27
      })
    );
  }

  function test_fuzz_calculatePremiumRay(
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) public {
    (premiumShares, premiumOffsetRay, drawnIndex) = _bound({
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    _mockUserPremiumData(premiumShares, premiumOffsetRay);
    assertEq(
      u.calculatePremiumRay(drawnIndex),
      _calculatePremiumDebtRay(premiumShares, premiumOffsetRay, drawnIndex)
    );
  }

  function test_calculatePremiumRay() public {
    _mockUserPremiumData(PREMIUM_SHARES, PREMIUM_OFFSET_RAY);
    assertEq(u.calculatePremiumRay(DRAWN_INDEX), 248.5e18 * 1e27);
  }

  function test_fuzz_getUserDebt_HubAndAssetId(
    uint256 drawnShares,
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) public {
    (drawnShares, premiumShares, premiumOffsetRay, drawnIndex) = _bound({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      drawnIndex: drawnIndex
    });

    _mockUserDrawnShares(drawnShares);
    _mockUserPremiumData(premiumShares, premiumOffsetRay);
    _mockHubDrawnIndex(drawnIndex);

    (uint256 drawnDebt, uint256 premiumDebtRay) = u.getDebt(hub, assetId);
    assertEq(drawnDebt, drawnShares.rayMulUp(drawnIndex));
    uint256 expectedPremiumDebtRay = _calculatePremiumDebtRay(
      premiumShares,
      premiumOffsetRay,
      drawnIndex
    );
    assertEq(premiumDebtRay, expectedPremiumDebtRay);
  }

  function test_getUserDebt_HubAndAssetId() public {
    (uint256 drawnDebt, uint256 premiumDebtRay) = u.getDebt(hub, assetId);
    assertEq(drawnDebt, 300e18);
    assertEq(premiumDebtRay, 248.5e18 * 1e27);

    _mockUserPremiumData(70e18, 0);
    _mockHubDrawnIndex(1.777777777777777777777777777e27);
    (drawnDebt, premiumDebtRay) = u.getDebt(hub, assetId);
    assertEq(drawnDebt, 355.555555555555555556e18);
    assertEq(premiumDebtRay, 124.44444444444444444444444439e45);
  }

  function test_fuzz_getUserDebt_DrawnIndex(
    uint256 drawnShares,
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) public {
    (drawnShares, premiumShares, premiumOffsetRay, drawnIndex) = _bound({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    _mockUserDrawnShares(drawnShares);
    _mockUserPremiumData(premiumShares, premiumOffsetRay);

    (uint256 drawnDebt, uint256 premiumDebtRay) = u.getDebt(drawnIndex);
    assertEq(drawnDebt, drawnShares.rayMulUp(drawnIndex));
    uint256 expectedPremiumDebtRay = _calculatePremiumDebtRay(
      premiumShares,
      premiumOffsetRay,
      drawnIndex
    );
    assertEq(premiumDebtRay, expectedPremiumDebtRay);
  }

  function test_getUserDebt_DrawnIndex() public {
    (uint256 drawnDebt, uint256 premiumDebtRay) = u.getDebt(DRAWN_INDEX);
    assertEq(drawnDebt, 300e18);
    assertEq(premiumDebtRay, 248.5e18 * 1e27);

    _mockUserPremiumData(70e18, 0);
    (drawnDebt, premiumDebtRay) = u.getDebt(1.777777777777777777777777777e27);
    assertEq(drawnDebt, 355.555555555555555556e18);
    assertEq(premiumDebtRay, 124.44444444444444444444444439e45);
  }

  function test_fuzz_calculateRestoreAmount(
    uint256 drawnShares,
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex,
    uint256 amount
  ) public {
    (drawnShares, premiumShares, premiumOffsetRay, drawnIndex) = _bound({
      drawnShares: drawnShares,
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    amount = bound(amount, 0, 1e40);
    _mockUserDrawnShares(drawnShares);
    _mockUserPremiumData(premiumShares, premiumOffsetRay);

    (uint256 drawnDebt, uint256 premiumDebtRay) = u.getDebt(drawnIndex);

    (uint256 restoredDrawnDebt, uint256 restoredPremiumDebtRay) = u.calculateRestoreAmount(
      drawnIndex,
      amount
    );

    if (amount >= drawnDebt + premiumDebtRay.fromRayUp()) {
      assertEq(restoredDrawnDebt, drawnDebt);
      assertEq(restoredPremiumDebtRay, premiumDebtRay);
    } else if (amount < premiumDebtRay.fromRayUp()) {
      assertEq(restoredDrawnDebt, 0);
      assertEq(restoredPremiumDebtRay, amount.toRay());
    } else {
      assertEq(restoredDrawnDebt, amount - premiumDebtRay.fromRayUp());
      assertEq(restoredPremiumDebtRay, premiumDebtRay);
    }
  }

  function test_calculateRestoreAmount() public {
    (uint256 restoredDrawnDebt, uint256 restoredPremiumDebtRay) = u.calculateRestoreAmount(
      DRAWN_INDEX,
      400e18
    );
    assertEq(restoredDrawnDebt, 151.5e18);
    assertEq(restoredPremiumDebtRay, 2.485e47);

    _mockUserPremiumData(70e18, 0);
    (restoredDrawnDebt, restoredPremiumDebtRay) = u.calculateRestoreAmount(1.75e27, 372.5e18);
    assertEq(restoredDrawnDebt, 250e18);
    assertEq(restoredPremiumDebtRay, 1.225e47);
  }

  function _mockUserDrawnShares(uint256 drawnShares) internal {
    ISpoke.UserPosition memory userPosition = u.getUserPosition();
    userPosition.drawnShares = drawnShares.toUint120();
    u.setUserPosition(userPosition);
  }

  function _mockUserPremiumData(uint256 premiumShares, int256 premiumOffsetRay) internal {
    ISpoke.UserPosition memory userPosition = u.getUserPosition();
    userPosition.premiumShares = premiumShares.toUint120();
    userPosition.premiumOffsetRay = premiumOffsetRay.toInt200();
    u.setUserPosition(userPosition);
  }

  function _mockHubDrawnIndex(uint256 drawnIndex) internal {
    vm.mockCall(
      address(hub),
      abi.encodeCall(IHubBase.getAssetDrawnIndex, (assetId)),
      abi.encode(drawnIndex)
    );
  }

  function _bound(
    IHubBase.PremiumDelta memory premiumDelta
  ) internal pure returns (IHubBase.PremiumDelta memory) {
    premiumDelta.sharesDelta = bound(premiumDelta.sharesDelta, -PREMIUM_SHARES.toInt256(), 1e30);
    premiumDelta.offsetRayDelta = bound(premiumDelta.offsetRayDelta, -1e30, 1e30);
    return premiumDelta;
  }

  function _bound(
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) internal pure returns (uint256, int256, uint256) {
    drawnIndex = bound(drawnIndex, WadRayMath.RAY, 100 * WadRayMath.RAY);
    premiumShares = bound(premiumShares, 0, 1e30);
    premiumOffsetRay = bound(premiumOffsetRay, -1e30, (premiumShares * drawnIndex).toInt256());
    return (premiumShares, premiumOffsetRay, drawnIndex);
  }

  function _bound(
    uint256 drawnShares,
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) internal pure returns (uint256, uint256, int256, uint256) {
    (premiumShares, premiumOffsetRay, drawnIndex) = _bound({
      premiumShares: premiumShares,
      premiumOffsetRay: premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    drawnShares = bound(drawnShares, 0, 1e30);
    return (drawnShares, premiumShares, premiumOffsetRay, drawnIndex);
  }

  function _bound(BoundParams memory params) internal pure returns (BoundParams memory) {
    (params.drawnShares, params.premiumShares, params.premiumOffsetRay, params.drawnIndex) = _bound(
      params.drawnShares,
      params.premiumShares,
      params.premiumOffsetRay,
      params.drawnIndex
    );
    params.drawnSharesTaken = bound(params.drawnSharesTaken, 0, params.drawnShares);
    params.riskPremium = bound(params.riskPremium, 0, MAX_COLLATERAL_RISK_BPS);
    params.restoredPremiumRay = bound(
      params.restoredPremiumRay,
      0,
      _calculatePremiumDebtRay(params.premiumShares, params.premiumOffsetRay, params.drawnIndex)
    );
    return params;
  }
}
