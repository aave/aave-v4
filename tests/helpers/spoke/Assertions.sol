// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {QueryHelpers} from 'tests/helpers/spoke/QueryHelpers.sol';
import {Vm} from 'forge-std/Vm.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';

/// @title Assertions
/// @notice Spoke-level assertion helpers for the Aave V4 test suite.
abstract contract Assertions is QueryHelpers {
  using ReserveFlagsMap for ReserveFlags;
  using SafeCast for *;
  using PercentageMath for uint256;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     STATE ASSERTIONS                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _assertUserPositionApprox(
    ISpoke.UserPosition memory userPos,
    ISpoke.UserPosition memory expectedUserPos,
    string memory label
  ) internal pure {
    assertEq(
      userPos.suppliedShares,
      expectedUserPos.suppliedShares,
      string.concat('user supplied shares ', label)
    );
    assertEq(
      userPos.drawnShares,
      expectedUserPos.drawnShares,
      string.concat('user drawnShares ', label)
    );
    assertEq(
      userPos.premiumShares,
      expectedUserPos.premiumShares,
      string.concat('user premiumShares ', label)
    );
    assertApproxEqAbs(
      userPos.premiumOffsetRay,
      expectedUserPos.premiumOffsetRay,
      1,
      string.concat('user premiumOffsetRay ', label)
    );
  }

  function _assertDebtDataEq(
    DebtData memory userDebt,
    DebtData memory expectedUserDebt,
    string memory label
  ) internal pure {
    assertEq(
      userDebt.drawnDebt,
      expectedUserDebt.drawnDebt,
      string.concat('user drawn debt ', label)
    );
    assertApproxEqAbs(
      userDebt.premiumDebt,
      expectedUserDebt.premiumDebt,
      1,
      string.concat('user premium debt ', label)
    );
    assertApproxEqAbs(
      userDebt.totalDebt,
      expectedUserDebt.totalDebt,
      1,
      string.concat('user total debt ', label)
    );
  }

  function _assertUserRpUnchanged(ISpoke spoke, address user) internal view {
    uint256 riskPremiumPreview = spoke.getUserAccountData(user).riskPremium;
    uint256 riskPremiumStored = _getUserRpStored(spoke, user);
    assertEq(riskPremiumStored, riskPremiumPreview, 'user risk premium mismatch vs preview');
  }

  /// after a repay action, the stored user risk premium should not match the on-the-fly calculation, due to lack of notify
  /// instead RP should remain same as prior value
  function _assertUserRpUnchangedAfterRepay(
    ISpoke spoke,
    address user,
    uint256 expectedRP
  ) internal view {
    uint256 riskPremiumPreview = spoke.getUserAccountData(user).riskPremium;
    uint256 riskPremiumStored = _getUserRpStored(spoke, user);
    assertEq(riskPremiumStored, expectedRP, 'user risk premium mismatch vs expected');
    assertNotEq(
      riskPremiumStored,
      riskPremiumPreview,
      'user risk premium expected mismatch without notify'
    );
  }

  function _assertUserPositionAndDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 debtAmount,
    uint256 suppliedAmount,
    uint256 expectedPremiumDebtRay,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);

    // actual
    ISpoke.UserPosition memory userPos = _getUserInfo(spoke, user, reserveId);
    DebtData memory userDebt = _getUserDebt(spoke, user, reserveId);

    // expected position
    uint120 premiumShares = hub
      .previewRestoreByAssets(assetId, debtAmount)
      .percentMulUp(_getUserRpStored(spoke, user))
      .toUint120();
    ISpoke.UserPosition memory expectedUserPos = ISpoke.UserPosition({
      suppliedShares: hub.previewAddByAssets(assetId, suppliedAmount).toUint120(),
      drawnShares: hub.previewRestoreByAssets(assetId, debtAmount).toUint120(),
      premiumShares: premiumShares,
      premiumOffsetRay: _calculatePremiumAssetsRay(hub, assetId, premiumShares)
        .toInt256()
        .toInt200() - expectedPremiumDebtRay.toInt256().toInt200(),
      dynamicConfigKey: userPos.dynamicConfigKey
    });

    // expected debt
    DebtData memory expectedUserDebt;
    expectedUserDebt.premiumDebt = _calculatePremiumDebt(
      hub,
      assetId,
      expectedUserPos.premiumShares,
      expectedUserPos.premiumOffsetRay
    );
    expectedUserDebt.drawnDebt = hub.previewRestoreByShares(assetId, expectedUserPos.drawnShares);
    expectedUserDebt.totalDebt = expectedUserDebt.drawnDebt + expectedUserDebt.premiumDebt;

    // assertions
    assertEq(_isBorrowing(spoke, reserveId, user), userDebt.totalDebt > 0);
    _assertUserPositionApprox(userPos, expectedUserPos, label);
    _assertDebtDataEq(userDebt, expectedUserDebt, label);
  }

  /// assert that sum across User storage debt matches Reserve storage debt
  function _assertUsersAndReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    address[] memory users,
    string memory label
  ) internal view {
    DebtData memory reserveDebt;
    DebtData memory usersDebt;
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);

    reserveDebt.totalDebt = spoke.getReserveTotalDebt(reserveId);
    (reserveDebt.drawnDebt, reserveDebt.premiumDebt) = spoke.getReserveDebt(reserveId);

    for (uint256 i = 0; i < users.length; ++i) {
      ISpoke.UserPosition memory userData = _getUserInfo(spoke, users[i], reserveId);
      (uint256 drawnDebt, uint256 premiumDebt) = spoke.getUserDebt(reserveId, users[i]);

      usersDebt.drawnDebt += drawnDebt;
      usersDebt.premiumDebt += premiumDebt;
      usersDebt.totalDebt += drawnDebt + premiumDebt;

      assertEq(
        drawnDebt,
        hub.previewRestoreByShares(assetId, userData.drawnShares),
        string.concat('user ', vm.toString(i), ' drawn debt ', label)
      );
      assertEq(
        premiumDebt,
        _calculatePremiumDebt(hub, assetId, userData.premiumShares, userData.premiumOffsetRay),
        string.concat('user ', vm.toString(i), ' premium debt ', label)
      );
    }

    assertEq(
      reserveDebt.drawnDebt,
      usersDebt.drawnDebt,
      string.concat('reserve vs sum users drawn debt ', label)
    );
    assertEq(
      reserveDebt.premiumDebt,
      usersDebt.premiumDebt,
      string.concat('reserve vs sum users premium debt ', label)
    );
    assertEq(
      reserveDebt.totalDebt,
      usersDebt.totalDebt,
      string.concat('reserve vs sum users total debt ', label)
    );
  }

  function _assertUserDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = spoke.getUserDebt(reserveId, user);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('user drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('user premium debt ', label)
    );
    assertApproxEqAbs(
      spoke.getUserTotalDebt(reserveId, user),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('user total debt ', label)
    );
  }

  function _assertReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = spoke.getReserveDebt(reserveId);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('reserve drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('reserve premium debt ', label)
    );
    assertApproxEqAbs(
      spoke.getReserveTotalDebt(reserveId),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('reserve total debt ', label)
    );
  }

  function _assertUserSupply(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    assertApproxEqAbs(
      spoke.getUserSuppliedAssets(reserveId, user),
      expectedSuppliedAmount,
      3,
      string.concat('user supplied amount ', label)
    );
  }

  function _assertReserveSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    assertApproxEqAbs(
      spoke.getReserveSuppliedAssets(reserveId),
      expectedSuppliedAmount,
      3,
      string.concat('reserve supplied amount ', label)
    );
  }

  function _assertSpokeDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = hub.getSpokeOwed(
      assetId,
      address(spoke)
    );
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('spoke drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('spoke premium debt ', label)
    );
    assertApproxEqAbs(
      hub.getSpokeTotalOwed(assetId, address(spoke)),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('spoke total debt ', label)
    );
  }

  function _assertAssetDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = hub.getAssetOwed(assetId);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('asset drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('asset premium debt ', label)
    );
    assertApproxEqAbs(
      hub.getAssetTotalOwed(assetId),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('asset total debt ', label)
    );
  }

  function _assertSpokeSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);
    assertApproxEqAbs(
      hub.getSpokeAddedAssets(assetId, address(spoke)),
      expectedSuppliedAmount,
      3,
      string.concat('spoke supplied amount ', label)
    );
  }

  function _assertAssetSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);
    assertApproxEqAbs(
      hub.getAddedAssets(assetId) - _calculateBurntInterest(hub, assetId),
      expectedSuppliedAmount,
      3,
      string.concat('asset supplied amount ', label)
    );
  }

  function _assertOnlyOneUserSupply(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    _assertUserSupply(spoke, reserveId, user, expectedSuppliedAmount, label);
    _assertReserveSupply(spoke, reserveId, expectedSuppliedAmount, label);
    _assertSpokeSupply(spoke, reserveId, expectedSuppliedAmount, label);
    _assertAssetSupply(spoke, reserveId, expectedSuppliedAmount, label);
  }

  function _assertOnlyOneUserDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    _assertUserDebt(spoke, reserveId, user, expectedDrawnDebt, expectedPremiumDebt, label);
    _assertReserveDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);
    _assertSpokeDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);
    _assertAssetDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);
  }

  function _assertSuppliedAmounts(
    uint256 assetId,
    uint256 reserveId,
    ISpoke spoke,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    IHub hub = _hub(spoke, reserveId);
    uint256 expectedSuppliedShares = hub.previewAddByAssets(assetId, expectedSuppliedAmount);
    assertEq(
      hub.getAddedShares(assetId),
      expectedSuppliedShares,
      string(abi.encodePacked('asset supplied shares ', label))
    );
    assertEq(
      hub.getAddedAssets(assetId) - _calculateBurntInterest(hub, assetId),
      expectedSuppliedAmount,
      string(abi.encodePacked('asset supplied amount ', label))
    );
    assertEq(
      hub.getSpokeAddedShares(assetId, address(spoke)),
      expectedSuppliedShares,
      string(abi.encodePacked('spoke supplied shares ', label))
    );
    assertEq(
      hub.getSpokeAddedAssets(assetId, address(spoke)),
      expectedSuppliedAmount,
      string(abi.encodePacked('spoke supplied amount ', label))
    );
    assertEq(
      spoke.getReserveSuppliedShares(reserveId),
      expectedSuppliedShares,
      string(abi.encodePacked('reserve supplied shares ', label))
    );
    assertEq(
      spoke.getReserveSuppliedAssets(reserveId),
      expectedSuppliedAmount,
      string(abi.encodePacked('reserve supplied amount ', label))
    );
    assertEq(
      spoke.getUserSuppliedShares(reserveId, user),
      expectedSuppliedShares,
      string(abi.encodePacked('user supplied shares ', label))
    );
    assertEq(
      spoke.getUserSuppliedAssets(reserveId, user),
      expectedSuppliedAmount,
      string(abi.encodePacked('user supplied amount ', label))
    );
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    ASSERTEQ OVERLOADS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _assertDynamicConfigRefreshEventsNotEmitted() internal {
    _assertEventsNotEmitted(
      ISpoke.RefreshAllUserDynamicConfig.selector,
      ISpoke.RefreshSingleUserDynamicConfig.selector
    );
  }

  function _assertEntityHasNoBalanceOrAllowance(
    IERC20 underlying,
    address entity,
    address user
  ) internal {
    assertEq(underlying.balanceOf(entity), 0);
    assertEq(underlying.allowance({owner: user, spender: entity}), 0);
    assertEq(underlying.allowance({owner: entity, spender: vm.randomAddress()}), 0);
  }

  function assertEq(
    ISpoke.LiquidationConfig memory a,
    ISpoke.LiquidationConfig memory b
  ) internal pure {
    assertEq(a.targetHealthFactor, b.targetHealthFactor, 'targetHealthFactor');
    assertEq(a.liquidationBonusFactor, b.liquidationBonusFactor, 'liquidationBonusFactor');
    assertEq(a.healthFactorForMaxBonus, b.healthFactorForMaxBonus, 'healthFactorForMaxBonus');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(ISpoke.ReserveConfig memory a, ISpoke.ReserveConfig memory b) internal pure {
    assertEq(a.paused, b.paused, 'paused');
    assertEq(a.frozen, b.frozen, 'frozen');
    assertEq(a.borrowable, b.borrowable, 'borrowable');
    assertEq(a.receiveSharesEnabled, b.receiveSharesEnabled, 'receiveSharesEnabled');
    assertEq(a.collateralRisk, b.collateralRisk, 'collateralRisk');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    ISpoke.DynamicReserveConfig memory a,
    ISpoke.DynamicReserveConfig memory b
  ) internal pure {
    assertEq(a.collateralFactor, b.collateralFactor, 'collateralFactor');
    assertEq(a.maxLiquidationBonus, b.maxLiquidationBonus, 'maxLiquidationBonus');
    assertEq(a.liquidationFee, b.liquidationFee, 'liquidationFee');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(ISpoke.Reserve memory a, ISpoke.Reserve memory b) internal pure {
    assertEq(address(a.hub), address(b.hub), 'hub');
    assertEq(a.assetId, b.assetId, 'asset Id');
    assertEq(a.decimals, b.decimals, 'decimals');
    assertEq(a.dynamicConfigKey, b.dynamicConfigKey, 'dynamicConfigKey');
    assertEq(a.flags.paused(), b.flags.paused(), 'paused');
    assertEq(a.flags.frozen(), b.flags.frozen(), 'frozen');
    assertEq(a.flags.borrowable(), b.flags.borrowable(), 'borrowable');
    assertEq(
      a.flags.receiveSharesEnabled(),
      b.flags.receiveSharesEnabled(),
      'receiveSharesEnabled'
    );
    assertEq(a.collateralRisk, b.collateralRisk, 'collateralRisk');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(ISpoke.UserPosition memory a, ISpoke.UserPosition memory b) internal pure {
    assertEq(a.suppliedShares, b.suppliedShares, 'suppliedShares');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffsetRay, b.premiumOffsetRay, 'premiumOffsetRay');
    assertEq(a.dynamicConfigKey, b.dynamicConfigKey, 'dynamicConfigKey');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(
    ISpoke.UserAccountData memory a,
    ISpoke.UserAccountData memory b
  ) internal pure {
    assertEq(a.riskPremium, b.riskPremium, 'riskPremium');
    assertEq(a.avgCollateralFactor, b.avgCollateralFactor, 'avgCollateralFactor');
    assertEq(a.totalCollateralValue, b.totalCollateralValue, 'totalCollateralValue');
    assertEq(a.totalDebtValueRay, b.totalDebtValueRay, 'totalDebtValueRay');
    assertEq(a.healthFactor, b.healthFactor, 'healthFactor');
    assertEq(a.activeCollateralCount, b.activeCollateralCount, 'activeCollateralCount');
    assertEq(a.borrowCount, b.borrowCount, 'borrowCount');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(
    IAssetInterestRateStrategy.InterestRateData memory a,
    IAssetInterestRateStrategy.InterestRateData memory b
  ) internal pure {
    assertEq(a.optimalUsageRatio, b.optimalUsageRatio, 'optimalUsageRatio');
    assertEq(a.baseDrawnRate, b.baseDrawnRate, 'baseDrawnRate');
    assertEq(a.rateGrowthBeforeOptimal, b.rateGrowthBeforeOptimal, 'rateGrowthBeforeOptimal');
    assertEq(a.rateGrowthAfterOptimal, b.rateGrowthAfterOptimal, 'rateGrowthAfterOptimal');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(DebtData memory a, DebtData memory b) internal pure {
    assertEq(a.drawnDebt, b.drawnDebt, 'drawn debt');
    assertEq(a.premiumDebt, b.premiumDebt, 'premium debt');
    assertEq(a.totalDebt, b.totalDebt, 'total debt');
    assertEq(keccak256(abi.encode(a)), keccak256(abi.encode(b)), 'debt data'); // sanity
  }

  function assertEq(DynamicConfigEntry memory a, DynamicConfigEntry memory b) internal pure {
    assertEq(a.key, b.key, 'key');
    assertEq(a.enabled, b.enabled, 'enabled');
    assertEq(abi.encode(a), abi.encode(b)); // sanity
  }

  function assertEq(DynamicConfigEntry[] memory a, DynamicConfigEntry[] memory b) internal pure {
    require(a.length == b.length);
    for (uint256 i; i < a.length; ++i) {
      if (a[i].enabled && b[i].enabled) {
        assertEq(a[i].key, b[i].key, string.concat('reserve ', vm.toString(i)));
      }
    }
  }

  function assertNotEq(DynamicConfigEntry[] memory a, DynamicConfigEntry[] memory b) internal pure {
    require(a.length == b.length);
    for (uint256 i; i < a.length; ++i) {
      if (a[i].enabled && b[i].enabled) {
        assertNotEq(a[i].key, b[i].key, string.concat('reserve ', vm.toString(i)));
      }
    }
  }

  function assertEq(SpokePosition memory a, SpokePosition memory b) internal pure {
    assertEq(a.reserveId, b.reserveId, 'reserveId');
    assertEq(a.assetId, b.assetId, 'assetId');
    assertEq(a.addedShares, b.addedShares, 'addedShares');
    assertEq(a.addedAmount, b.addedAmount, 'addedAmount');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.drawn, b.drawn, 'drawn');
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffsetRay, b.premiumOffsetRay, 'premiumOffsetRay');
    assertEq(a.premium, b.premium, 'premium');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }
}
