// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/liquidation/Spoke.BabylonLiquidationCall.Base.t.sol';

/// @dev Fuzz matrix mirroring the canonical `SpokeLiquidationCallHelperTest` shapes for the
/// babylon liquidation call. The ManyCollaterals shapes are dropped (users register a single
/// collateral) and the canonical `receiveShares` dimension is replaced by fuzzing the removal
/// cap and the debt reserve arrays. The LiquidationFeeZero variant is dropped (the fee is never
/// charged) along with TargetHealthFactorOne (no target health factor sizing).
abstract contract SpokeBabylonLiquidationCallHelperTest is SpokeBabylonLiquidationCallBaseTest {
  using WadRayMath for uint256;
  using SafeCast for uint256;
  using PercentageMath for uint256;

  ISpoke public spoke;
  address public user = makeAddr('user');

  uint256 public skipTime;
  uint256 public baseAmountValue;

  function setUp() public virtual override {
    super.setUp();
    spoke = spoke4;
  }

  /// @dev Bounds the managed collateral reserve over all reserves and the debt reserve over the
  /// borrowable reserves, excluding the collateral so its supply share price stays at one.
  function _bound(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal view returns (uint256, uint256) {
    uint256 reserveCount = spoke.getReserveCount();
    collateralReserveId = bound(collateralReserveId, 0, reserveCount - 1);
    uint256[] memory candidates = new uint256[](reserveCount);
    uint256 count;
    for (uint256 i = 0; i < reserveCount; ++i) {
      if (i != collateralReserveId && spoke.getReserveConfig(i).borrowable) {
        candidates[count++] = i;
      }
    }
    return (collateralReserveId, candidates[bound(debtReserveId, 0, count - 1)]);
  }

  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual {
    skipTime = vm.randomUint(0, 10 * 365 days);
    baseAmountValue = vm.randomUint(MIN_AMOUNT_IN_BASE_CURRENCY, MAX_AMOUNT_IN_BASE_CURRENCY);

    _updateLiquidationConfig(
      spoke,
      ISpoke.LiquidationConfig({
        targetHealthFactor: vm
          .randomUint(MIN_TARGET_HEALTH_FACTOR, MAX_TARGET_HEALTH_FACTOR)
          .toUint128(),
        healthFactorForMaxBonus: vm
          .randomUint(0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1)
          .toUint64(),
        liquidationBonusFactor: vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR).toUint16()
      })
    );

    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      _updateMaxLiquidationBonus(spoke, i, _randomMaxLiquidationBonus(spoke, i));
      _updateCollateralFactor(spoke, i, 1); // temporary value to have full range of possibility for liquidation fee
      _updateLiquidationFee(
        spoke,
        i,
        vm.randomUint(MIN_LIQUIDATION_FEE, MAX_LIQUIDATION_FEE).toUint16()
      );
      _updateCollateralFactor(spoke, i, _randomCollateralFactor(spoke, i));
      _updateCollateralRisk(
        spoke,
        i,
        vm.randomUint(MIN_COLLATERAL_RISK_BPS, MAX_COLLATERAL_RISK_BPS).toUint24()
      );
      _setConstantDrawnRateBps(
        _hub(spoke, i),
        _reserveAssetId(spoke, i),
        vm.randomUint(MIN_ALLOWED_DRAWN_RATE, MAX_ALLOWED_DRAWN_RATE).toUint32()
      );
    }
  }

  function _testLiquidationCall(
    uint256 debtReserveId,
    uint256 debtToCover,
    uint256 maxCollateralToRemove,
    bool isSolvent
  ) internal virtual {
    skip(skipTime);

    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    uint256 newHealthFactor; // new health factor of user, just before liquidation
    if (isSolvent) {
      // health factor of user should be at least its average collateral factor
      newHealthFactor = vm.randomUint(
        userAccountData.avgCollateralFactor + 0.0000001e18,
        PercentageMath.PERCENTAGE_FACTOR.bpsToWad() - 0.0000001e18
      );
    } else {
      newHealthFactor = vm.randomUint(
        _min(userAccountData.avgCollateralFactor - 0.0000001e18, 0.1e18),
        userAccountData.avgCollateralFactor - 0.0000001e18
      );
    }
    _makeUserLiquidatable(spoke, user, debtReserveId, newHealthFactor);

    // repay all borrowed reserves; the fuzzed cover seeds the primary debt reserve. The cover
    // must repay at least one drawn share, so the repayment cannot floor to a zero restore
    uint256[] memory debtReserveIds = _userDebtReserveIds();
    uint256[] memory debtToCoverAmounts = new uint256[](debtReserveIds.length);
    for (uint256 i = 0; i < debtReserveIds.length; ++i) {
      uint256 userDebt = spoke.getUserTotalDebt(debtReserveIds[i], user);
      uint256 minCover = _reserveDrawnIndex(spoke, debtReserveIds[i]).fromRayUp();
      uint256 maxCover = _max(minCover, userDebt * 2);
      debtToCoverAmounts[i] = debtReserveIds[i] == debtReserveId
        ? bound(debtToCover, minCover, maxCover)
        : vm.randomUint(minCover, maxCover);
      _fundLiquidationManager(debtReserveIds[i], maxCover);
    }

    // the cap spans from a single collateral share's worth up to twice the user's collateral
    maxCollateralToRemove = bound(
      maxCollateralToRemove,
      _hub(spoke, collateralReserveId).previewAddByShares(
        _reserveAssetId(spoke, collateralReserveId),
        1
      ),
      spoke.getUserSuppliedAssets(collateralReserveId, user) * 2
    );

    _checkedBabylonLiquidationCall(
      CheckedBabylonLiquidationCallParams({
        debtReserveIds: debtReserveIds,
        debtToCoverAmounts: debtToCoverAmounts,
        user: user,
        maxCollateralToRemove: maxCollateralToRemove,
        isSolvent: isSolvent
      })
    );
  }

  function test_liquidationCall_fuzz_OneCollateral_OneDebt_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    uint256 maxCollateralToRemove
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(collateralReserveId, debtReserveId);
    _setManagedCollateralReserve(collateralReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, baseAmountValue),
      user
    );

    _testLiquidationCall({
      debtReserveId: debtReserveId,
      debtToCover: debtToCover,
      maxCollateralToRemove: maxCollateralToRemove,
      isSolvent: true
    });
  }

  function test_liquidationCall_fuzz_OneCollateral_OneDebt_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    uint256 maxCollateralToRemove
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(collateralReserveId, debtReserveId);
    _setManagedCollateralReserve(collateralReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, baseAmountValue),
      user
    );

    _testLiquidationCall({
      debtReserveId: debtReserveId,
      debtToCover: debtToCover,
      maxCollateralToRemove: maxCollateralToRemove,
      isSolvent: false
    });
  }

  function test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    uint256 maxCollateralToRemove
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(collateralReserveId, debtReserveId);
    _setManagedCollateralReserve(collateralReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, baseAmountValue),
      user
    );

    _processAdditionalDebtReserves();

    _testLiquidationCall({
      debtReserveId: debtReserveId,
      debtToCover: debtToCover,
      maxCollateralToRemove: maxCollateralToRemove,
      isSolvent: true
    });
  }

  function test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    uint256 maxCollateralToRemove
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(collateralReserveId, debtReserveId);
    _setManagedCollateralReserve(collateralReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, baseAmountValue),
      user
    );

    _processAdditionalDebtReserves();

    _testLiquidationCall({
      debtReserveId: debtReserveId,
      debtToCover: debtToCover,
      maxCollateralToRemove: maxCollateralToRemove,
      isSolvent: false
    });
  }

  /// @dev The debt reserves the user borrows, in reserve id order.
  function _userDebtReserveIds() internal view returns (uint256[] memory ids) {
    uint256 reserveCount = spoke.getReserveCount();
    uint256[] memory borrowed = new uint256[](reserveCount);
    uint256 count;
    for (uint256 i = 0; i < reserveCount; ++i) {
      if (_isBorrowing(spoke, i, user)) {
        borrowed[count++] = i;
      }
    }
    ids = new uint256[](count);
    for (uint256 i = 0; i < count; ++i) {
      ids[i] = borrowed[i];
    }
  }

  // calculates the max borrow amount that ensures user will be healthy after skipping time as well
  function _calculateMaxHealthyBorrowValue(address addr) internal returns (uint256) {
    uint256 maxBorrowValue = _getRequiredDebtValueForHf(
      spoke,
      addr,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    // buffer
    maxBorrowValue /= 2;
    // account for drawn rate and time
    maxBorrowValue = maxBorrowValue.percentDivDown(
      PercentageMath.PERCENTAGE_FACTOR + (_spokeMaxDrawnRate(spoke) * skipTime) / 365 days
    );
    // account for premium debt
    maxBorrowValue = maxBorrowValue.percentDivDown(
      PercentageMath.PERCENTAGE_FACTOR +
        (_spokeMaxCollateralRisk(spoke) + PercentageMath.PERCENTAGE_FACTOR)
    );

    return maxBorrowValue;
  }

  function _processAdditionalDebtReserves() internal {
    uint256 count = vm.randomUint(1, spoke.getReserveCount() * 2);
    // accounts for borrow share price increase due to time skip (and borrow drawn rate)
    // ensures user is healthy enough to borrow
    uint256 borrowableValue = _calculateMaxHealthyBorrowValue(user);
    uint256 borrows;
    for (uint256 i = 0; i < count; i++) {
      uint256 reserveId = vm.randomUint(0, spoke.getReserveCount() - 1);
      // never borrow the managed collateral: its supply share price must stay at one
      if (reserveId == collateralReserveId || !spoke.getReserveConfig(reserveId).borrowable) {
        continue;
      }
      uint256 maxBorrowAmount = _min(
        _convertValueToAmount(spoke, reserveId, borrowableValue),
        _calculateMaxSupplyAmount(spoke, reserveId)
      );
      if (maxBorrowAmount == 0) {
        require(borrows > 0, 'No borrow operations');
        break;
      }
      uint256 amount = vm.randomUint(1, maxBorrowAmount);
      borrowableValue -= _convertAmountToValue(spoke, reserveId, amount);
      _increaseReserveDebtNoCollateral(spoke, reserveId, amount, user);
      borrows++;
    }
  }
}

contract SpokeBabylonLiquidationCallTest_SmallPosition is SpokeBabylonLiquidationCallHelperTest {
  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    baseAmountValue = vm.randomUint(MIN_AMOUNT_IN_BASE_CURRENCY, 10_000e26);
  }
}

contract SpokeBabylonLiquidationCallTest_LargePosition is SpokeBabylonLiquidationCallHelperTest {
  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    baseAmountValue = vm.randomUint(100_000e26, MAX_AMOUNT_IN_BASE_CURRENCY);
  }
}

contract SpokeBabylonLiquidationCallTest_NoLiquidationBonus is
  SpokeBabylonLiquidationCallHelperTest
{
  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    _updateMaxLiquidationBonus(spoke, collateralReserveId, 100_00);
  }

  function _assertBeforeBabylonLiquidation(
    CheckedBabylonLiquidationCallParams memory /* params */,
    BabylonAccountsSnapshot memory /* accountsInfoBefore */,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal view virtual override {
    assertEq(liquidationMetadata.liquidationBonus, 100_00, 'Liquidation bonus');
  }
}

contract SpokeBabylonLiquidationCallTest_SmallLiquidationBonus is
  SpokeBabylonLiquidationCallHelperTest
{
  using PercentageMath for *;
  using SafeCast for uint256;

  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    _updateCollateralFactor(spoke, collateralReserveId, 1); // temporary value to have full range of possibility for liquidation bonus
    _updateMaxLiquidationBonus(
      spoke,
      collateralReserveId,
      vm.randomUint(MIN_LIQUIDATION_BONUS, MIN_LIQUIDATION_BONUS.percentMulUp(102_00)).toUint32()
    );
    _updateLiquidationBonusFactor(spoke, 100_00);
    _updateCollateralFactor(
      spoke,
      collateralReserveId,
      _randomCollateralFactor(spoke, collateralReserveId)
    );
  }

  function _assertBeforeBabylonLiquidation(
    CheckedBabylonLiquidationCallParams memory /* params */,
    BabylonAccountsSnapshot memory /* accountsInfoBefore */,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal view virtual override {
    assertLe(
      liquidationMetadata.liquidationBonus,
      MIN_LIQUIDATION_BONUS.percentMulUp(102_00),
      'Liquidation bonus'
    );
  }
}

contract SpokeBabylonLiquidationCallTest_LargeLiquidationBonus is
  SpokeBabylonLiquidationCallHelperTest
{
  using PercentageMath for *;
  using SafeCast for *;

  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    _updateCollateralFactor(spoke, collateralReserveId, 1); // temporary value to have full range of possibility for liquidation bonus
    _updateMaxLiquidationBonus(
      spoke,
      collateralReserveId,
      vm.randomUint(MAX_LIQUIDATION_BONUS.percentMulDown(97_00), MAX_LIQUIDATION_BONUS).toUint32()
    );
    _updateLiquidationBonusFactor(spoke, 100_00);
    _updateCollateralFactor(
      spoke,
      collateralReserveId,
      _randomCollateralFactor(spoke, collateralReserveId)
    );
  }

  function _assertBeforeBabylonLiquidation(
    CheckedBabylonLiquidationCallParams memory /* params */,
    BabylonAccountsSnapshot memory /* accountsInfoBefore */,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal view virtual override {
    assertGe(
      liquidationMetadata.liquidationBonus,
      MAX_LIQUIDATION_BONUS.percentMulDown(97_00),
      'Liquidation bonus'
    );
  }
}

contract SpokeBabylonLiquidationCallTest_NoPremium is SpokeBabylonLiquidationCallHelperTest {
  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      _updateCollateralRisk(spoke, i, 0);
    }
  }

  function _assertBeforeBabylonLiquidation(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonAccountsSnapshot memory /* accountsInfoBefore */,
    BabylonLiquidationMetadata memory /* liquidationMetadata */
  ) internal view virtual override {
    for (uint256 i = 0; i < params.debtReserveIds.length; i++) {
      (, uint256 premiumDebt) = spoke.getUserDebt(params.debtReserveIds[i], params.user);
      assertEq(premiumDebt, 0, 'No premium');
    }
  }
}

contract SpokeBabylonLiquidationCallTest_Premium is SpokeBabylonLiquidationCallHelperTest {
  using SafeCast for uint256;
  using PercentageMath for uint256;

  uint256 internal premiumDebtReserveId;

  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    premiumDebtReserveId = debtReserveId;
    skipTime = vm.randomUint(1, 10 * 365 days);
    _updateCollateralRisk(
      spoke,
      collateralReserveId,
      vm.randomUint(1, MAX_COLLATERAL_RISK_BPS).toUint24()
    );
    _setConstantDrawnRateBps(
      _hub(spoke, debtReserveId),
      _reserveAssetId(spoke, debtReserveId),
      vm.randomUint(1, MAX_ALLOWED_DRAWN_RATE).toUint32()
    );
    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, baseAmountValue),
      user
    );
    _increaseReserveDebtNoCollateral(
      spoke,
      debtReserveId,
      _convertValueToAmount(spoke, debtReserveId, _calculateMaxHealthyBorrowValue(user)),
      user
    );
    skip(1 seconds);
  }

  function _assertBeforeBabylonLiquidation(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonAccountsSnapshot memory /* accountsInfoBefore */,
    BabylonLiquidationMetadata memory /* liquidationMetadata */
  ) internal view virtual override {
    (, uint256 premiumDebt) = spoke.getUserDebt(premiumDebtReserveId, params.user);
    assertGt(premiumDebt, 0, 'User should have premium debt');
  }
}

contract SpokeBabylonLiquidationCallTest_NoTimeSkip is SpokeBabylonLiquidationCallHelperTest {
  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    skipTime = 0;
  }

  function _assertBeforeBabylonLiquidation(
    CheckedBabylonLiquidationCallParams memory /* params */,
    BabylonAccountsSnapshot memory /* accountsInfoBefore */,
    BabylonLiquidationMetadata memory /* liquidationMetadata */
  ) internal view virtual override {
    uint256 reserveCount = spoke.getReserveCount();
    for (uint256 i = 0; i < reserveCount; i++) {
      assertEq(_reserveDrawnIndex(spoke, i), 1e27, 'drawn index');
      IHub hub = _hub(spoke, i);
      uint256 assetId = _reserveAssetId(spoke, i);
      assertEq(hub.getAddedAssets(assetId), hub.getAddedShares(assetId), 'supply share price');
    }
  }
}

contract SpokeBabylonLiquidationCallTest_LiquidatorHistory is
  SpokeBabylonLiquidationCallHelperTest
{
  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);

    // the liquidation manager holds its own position: a single registered collateral with
    // borrow history, never borrowing the managed collateral
    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, 1_000e26),
      liquidationManager
    );
    uint256 count = vm.randomUint(1, spoke.getReserveCount() * 2);
    for (uint256 i = 0; i < count; ++i) {
      uint256 reserveId = vm.randomUint(0, spoke.getReserveCount() - 1);
      if (reserveId == collateralReserveId || !spoke.getReserveConfig(reserveId).borrowable) {
        continue;
      }
      ISpoke.UserAccountData memory managerAccountData = spoke.getUserAccountData(
        liquidationManager
      );
      uint256 maxBorrowAmount = _convertValueToAmount(
        spoke,
        reserveId,
        managerAccountData.healthFactor <= 1.5e18
          ? 0
          : _getRequiredDebtValueForHf(spoke, liquidationManager, 1.5e18)
      );
      if (maxBorrowAmount == 0) {
        break;
      }
      _increaseReserveDebtNoCollateral(
        spoke,
        reserveId,
        vm.randomUint(1, maxBorrowAmount),
        liquidationManager
      );
      skip(1 days);
    }

    // make the manager unhealthy now, but it might get healthy when the liquidation happens
    if (
      spoke.getUserAccountData(liquidationManager).healthFactor >
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    ) {
      _makeUserLiquidatable(
        spoke,
        liquidationManager,
        debtReserveId,
        vm.randomUint(0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.0000001e18)
      );
    }
  }
}
