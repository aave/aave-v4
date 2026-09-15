// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/BabylonBase.t.sol';
import 'tests/contracts/spoke/liquidation/Spoke.LiquidationCall.Base.t.sol';
import {BabylonLiquidationLogicWrapper} from 'tests/helpers/mocks/BabylonLiquidationLogicWrapper.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';

/// @dev Assertion engine for the Babylon liquidation suites, mirroring the canonical
/// `SpokeLiquidationCallBaseTest` pipeline for the manager-gated, cap-bounded `liquidationCall`.
/// The engine relies on the managed collateral reserve keeping a supply share price of exactly
/// one (it is not borrowable in production), which it asserts, so the collateral preview taken
/// before the call stays exact.
contract SpokeBabylonLiquidationCallBaseTest is BabylonBase, SpokeLiquidationCallBaseTest {
  using SafeCast for *;
  using PercentageMath for *;
  using WadRayMath for *;
  using KeyValueList for KeyValueList.List;
  using MathUtils for uint256;

  struct CheckedBabylonLiquidationCallParams {
    uint256 debtReserveId;
    uint256 debtToCover;
    address user;
    uint256 maxCollateralToRemove;
    bool isSolvent;
  }

  struct BabylonLiquidationMetadata {
    uint256 maxRemovableShares;
    uint256 collateralSharesToLiquidate;
    uint256 collateralAmountRemoved;
    uint256 drawnSharesToLiquidate;
    uint256 premiumDebtRayToLiquidate;
    uint256 debtAssetsToRestore;
    IHubBase.PremiumDelta premiumDelta;
    uint256 liquidationBonus;
    bool fullDebtReserveLiquidated;
    bool collateralCapEnforced;
    bool hasDeficit;
  }

  struct BabylonAccountsSnapshot {
    ISpoke.UserAccountData userAccountData;
    uint256 userLastRiskPremium;
    LiquidationBalanceSnapshot userBalanceInfo;
    LiquidationBalanceSnapshot liquidatorBalanceInfo;
    LiquidationBalanceSnapshot debtHubBalanceInfo;
    LiquidationBalanceSnapshot spokeBalanceInfo;
    LiquidationBalanceSnapshot collateralHubBalanceInfo;
  }

  BabylonLiquidationLogicWrapper internal babylonLiquidationLogicWrapper;
  uint256 internal collateralReserveId;

  function setUp() public virtual override(BabylonBase, LiquidationLogicBaseTest) {
    super.setUp();
    babylonLiquidationLogicWrapper = new BabylonLiquidationLogicWrapper();
    collateralReserveId = _wbtcReserveId(spoke4);
  }

  /// @dev Points the Babylon liquidation config at another managed collateral reserve.
  function _setManagedCollateralReserve(uint256 reserveId) internal {
    collateralReserveId = reserveId;
    vm.prank(ADMIN);
    babylonSpoke.updateBabylonLiquidationConfig(liquidationManager, reserveId);
  }

  /// @dev Supplies `collateralValue` (in units of Value) of collateral for `user` and borrows the
  /// debt reserve so the user health factor lands at `healthFactor`.
  function _setUpLiquidatableUser(
    address user,
    uint256 debtReserveId,
    uint256 collateralValue,
    uint256 healthFactor
  ) internal {
    _increaseCollateralSupply(
      spoke4,
      collateralReserveId,
      _convertValueToAmount(spoke4, collateralReserveId, collateralValue),
      user
    );
    _makeUserLiquidatable(spoke4, user, debtReserveId, healthFactor);
    assertLt(
      _getUserHealthFactor(spoke4, user),
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'user should be liquidatable'
    );
  }

  /// @dev Seeds the debt liquidity without registering it as collateral: only the managed
  /// collateral reserve can be registered on the babylon spoke.
  function _makeUserLiquidatable(
    ISpoke spoke,
    address user,
    uint256 debtReserveId,
    uint256 newHealthFactor
  ) internal virtual override {
    _openSupplyPositionNoCollateral(
      spoke,
      debtReserveId,
      _getRequiredDebtAmountForHf(spoke, user, debtReserveId, newHealthFactor)
    );
    _borrowToBeAtHf(spoke, user, debtReserveId, newHealthFactor);
  }

  function _fundLiquidationManager(uint256 reserveId, uint256 amount) internal {
    _deal(spoke4, reserveId, liquidationManager, amount);
    SpokeActions.approve({
      spoke: spoke4,
      reserveId: reserveId,
      owner: liquidationManager,
      amount: UINT256_MAX
    });
  }

  /// @dev Expected removed collateral (in units of Value) for a repaid debt value, priced by the
  /// canonical bonus formula.
  function _expectedRemovedValue(
    address user,
    uint256 debtValueCovered
  ) internal view returns (uint256) {
    uint256 liquidationBonus = spoke4.getLiquidationBonus(
      collateralReserveId,
      user,
      spoke4.getUserAccountData(user).healthFactor
    );
    return debtValueCovered.percentMulDown(liquidationBonus);
  }

  /// @dev Expected repaid debt (in units of Value) for a removed collateral value, the inverse of
  /// the canonical bonus pricing.
  function _expectedRepaidValue(
    address user,
    uint256 removedValue
  ) internal view returns (uint256) {
    uint256 liquidationBonus = spoke4.getLiquidationBonus(
      collateralReserveId,
      user,
      spoke4.getUserAccountData(user).healthFactor
    );
    return removedValue.mulDivUp(PercentageMath.PERCENTAGE_FACTOR, liquidationBonus);
  }

  /// @dev Expected removed collateral shares for a removal cap expressed in asset units.
  function _expectedRemovedShares(uint256 maxCollateralToRemove) internal view returns (uint256) {
    return
      _hub(spoke4, collateralReserveId).previewAddByAssets(
        _reserveAssetId(spoke4, collateralReserveId),
        maxCollateralToRemove
      );
  }

  /// @dev Hook for child suites, mirroring the canonical `_assertBeforeLiquidation`.
  function _assertBeforeBabylonLiquidation(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonAccountsSnapshot memory accountsInfoBefore,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal view virtual {}

  function _getBabylonAccountsInfo(
    CheckedBabylonLiquidationCallParams memory params
  ) internal virtual returns (BabylonAccountsSnapshot memory snapshot) {
    snapshot.userAccountData = spoke4.getUserAccountData(params.user);
    snapshot.userLastRiskPremium = spoke4.getUserLastRiskPremium(params.user);
    snapshot.userBalanceInfo = _getBalanceInfo(
      spoke4,
      params.user,
      collateralReserveId,
      params.debtReserveId
    );
    snapshot.liquidatorBalanceInfo = _getBalanceInfo(
      spoke4,
      liquidationManager,
      collateralReserveId,
      params.debtReserveId
    );
    snapshot.debtHubBalanceInfo = _getBalanceInfo(
      spoke4,
      address(_hub(spoke4, params.debtReserveId)),
      collateralReserveId,
      params.debtReserveId
    );
    snapshot.spokeBalanceInfo = _getBalanceInfo(
      spoke4,
      address(spoke4),
      collateralReserveId,
      params.debtReserveId
    );
    snapshot.collateralHubBalanceInfo = _getBalanceInfo(
      spoke4,
      address(_hub(spoke4, collateralReserveId)),
      collateralReserveId,
      collateralReserveId
    );
  }

  function _getCalculateBabylonLiquidationAmountsParams(
    address user,
    uint256 debtReserveId,
    uint256 debtToCover,
    uint256 liquidationBonus,
    uint256 maxRemovableShares
  ) internal view returns (BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory) {
    return
      BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
        collateralReserveHub: _hub(spoke4, collateralReserveId),
        collateralReserveAssetId: _reserveAssetId(spoke4, collateralReserveId),
        collateralAssetUnit: 10 ** spoke4.getReserve(collateralReserveId).decimals,
        collateralAssetPrice: IPriceOracle(spoke4.ORACLE()).getReservePrice(collateralReserveId),
        liquidationBonus: liquidationBonus,
        drawnShares: spoke4.getUserPosition(debtReserveId, user).drawnShares,
        premiumDebtRay: _calculatePremiumDebtRay(spoke4, debtReserveId, user),
        drawnIndex: _reserveDrawnIndex(spoke4, debtReserveId),
        debtAssetUnit: 10 ** spoke4.getReserve(debtReserveId).decimals,
        debtAssetPrice: IPriceOracle(spoke4.ORACLE()).getReservePrice(debtReserveId),
        debtToCover: debtToCover,
        maxRemovableShares: maxRemovableShares
      });
  }

  function _getBabylonLiquidationMetadata(
    CheckedBabylonLiquidationCallParams memory params,
    ISpoke.UserAccountData memory userAccountDataBefore
  ) internal virtual returns (BabylonLiquidationMetadata memory metadata) {
    // the engine relies on the collateral preview taken before the call staying exact, which
    // holds if and only if the collateral supply share price is one
    IHubBase collateralHub = _hub(spoke4, collateralReserveId);
    uint256 collateralAssetId = _reserveAssetId(spoke4, collateralReserveId);
    assertEq(
      collateralHub.getAddedAssets(collateralAssetId),
      collateralHub.getAddedShares(collateralAssetId),
      'managed collateral share price must be one'
    );

    metadata.liquidationBonus = spoke4.getLiquidationBonus(
      collateralReserveId,
      params.user,
      userAccountDataBefore.healthFactor
    );
    metadata.maxRemovableShares = collateralHub
      .previewAddByAssets(collateralAssetId, params.maxCollateralToRemove)
      .min(spoke4.getUserPosition(collateralReserveId, params.user).suppliedShares);

    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getCalculateBabylonLiquidationAmountsParams(
          params.user,
          params.debtReserveId,
          params.debtToCover,
          metadata.liquidationBonus,
          metadata.maxRemovableShares
        )
      );
    // the cap is enforced if the unbounded sizing would remove more shares
    metadata.collateralCapEnforced =
      babylonLiquidationLogicWrapper
        .calculateLiquidationAmounts(
          _getCalculateBabylonLiquidationAmountsParams(
            params.user,
            params.debtReserveId,
            params.debtToCover,
            metadata.liquidationBonus,
            UINT256_MAX
          )
        )
        .collateralSharesToLiquidate > metadata.maxRemovableShares;

    metadata.collateralSharesToLiquidate = liquidationAmounts.collateralSharesToLiquidate;
    // exact at a collateral share price of one
    metadata.collateralAmountRemoved = collateralHub.previewRemoveByShares(
      collateralAssetId,
      liquidationAmounts.collateralSharesToLiquidate
    );
    metadata.drawnSharesToLiquidate = liquidationAmounts.drawnSharesToLiquidate;
    metadata.premiumDebtRayToLiquidate = liquidationAmounts.premiumDebtRayToLiquidate;
    metadata.debtAssetsToRestore = _calculateDebtAssetsToRestore({
      drawnSharesToLiquidate: liquidationAmounts.drawnSharesToLiquidate,
      premiumDebtRayToLiquidate: liquidationAmounts.premiumDebtRayToLiquidate,
      drawnIndex: _reserveDrawnIndex(spoke4, params.debtReserveId)
    });
    metadata.premiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke4,
      params.user,
      params.debtReserveId,
      metadata.debtAssetsToRestore
    );
    metadata.fullDebtReserveLiquidated =
      liquidationAmounts.drawnSharesToLiquidate ==
      _getUserDrawnShares(spoke4, params.debtReserveId, params.user);

    // the user borrows a single reserve, so the position is in deficit once its collateral is
    // exhausted with debt left in that reserve
    metadata.hasDeficit =
      metadata.collateralSharesToLiquidate ==
        spoke4.getUserPosition(collateralReserveId, params.user).suppliedShares &&
      !metadata.fullDebtReserveLiquidated;
  }

  // calculate expected user account data after liquidation; the user has a single registered
  // collateral and a single debt reserve by construction, which collapses the canonical recompute
  function _calculateExpectedBabylonUserAccountData(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal virtual returns (ISpoke.UserAccountData memory expectedUserAccountData) {
    uint256 userSuppliedShares = spoke4
      .getUserPosition(collateralReserveId, params.user)
      .suppliedShares - liquidationMetadata.collateralSharesToLiquidate;
    uint256 userSuppliedValue;

    if (
      userSuppliedShares > 0 && _getCollateralFactor(spoke4, collateralReserveId, params.user) > 0
    ) {
      IHubBase hub = _hub(spoke4, collateralReserveId);
      uint256 assetId = _reserveAssetId(spoke4, collateralReserveId);
      uint256 userSuppliedAssets = userSuppliedShares.mulDivDown(
        hub.getAddedAssets(assetId) - liquidationMetadata.collateralAmountRemoved + VIRTUAL_ASSETS,
        hub.getAddedShares(assetId) -
          liquidationMetadata.collateralSharesToLiquidate +
          VIRTUAL_SHARES
      );
      userSuppliedValue = _convertAmountToValue(spoke4, collateralReserveId, userSuppliedAssets);
      expectedUserAccountData.activeCollateralCount = 1;
      expectedUserAccountData.totalCollateralValue = userSuppliedValue;
      expectedUserAccountData.avgCollateralFactor =
        _getCollateralFactor(spoke4, collateralReserveId, params.user) * userSuppliedValue;
    }

    if (!liquidationMetadata.hasDeficit) {
      uint256 userDrawnShares = spoke4
        .getUserPosition(params.debtReserveId, params.user)
        .drawnShares - liquidationMetadata.drawnSharesToLiquidate;
      if (userDrawnShares > 0) {
        expectedUserAccountData.borrowCount = 1;
        expectedUserAccountData.totalDebtValueRay = _convertAmountToValue(
          spoke4,
          params.debtReserveId,
          userDrawnShares * _reserveDrawnIndex(spoke4, params.debtReserveId) +
            _calculatePremiumDebtRay(spoke4, params.debtReserveId, params.user) -
            liquidationMetadata.premiumDebtRayToLiquidate
        );
      }
    }

    if (expectedUserAccountData.totalDebtValueRay > 0) {
      expectedUserAccountData.healthFactor = Math.mulDiv(
        expectedUserAccountData.avgCollateralFactor,
        (WadRayMath.WAD * WadRayMath.RAY) / PercentageMath.PERCENTAGE_FACTOR,
        expectedUserAccountData.totalDebtValueRay,
        Math.Rounding.Floor
      );
    } else {
      expectedUserAccountData.healthFactor = UINT256_MAX;
    }

    if (expectedUserAccountData.totalCollateralValue != 0) {
      expectedUserAccountData.avgCollateralFactor = expectedUserAccountData
        .avgCollateralFactor
        .mulDivDown(
          WadRayMath.WAD / PercentageMath.PERCENTAGE_FACTOR,
          expectedUserAccountData.totalCollateralValue
        );
    }

    // risk premium waterfall over a single collateral
    uint256 debtToCoverValue = expectedUserAccountData.totalDebtValueRay.fromRayUp();
    expectedUserAccountData.riskPremium = _divUp(
      _getCollateralRisk(spoke4, collateralReserveId) * _min(userSuppliedValue, debtToCoverValue),
      _max(1, _min(debtToCoverValue, expectedUserAccountData.totalCollateralValue))
    );

    return expectedUserAccountData;
  }

  function _expectBabylonEventsAndCalls(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonAccountsSnapshot memory accountsInfoBefore,
    BabylonLiquidationMetadata memory liquidationMetadata,
    ISpoke.UserAccountData memory expectedUserAccountData
  ) internal virtual {
    IHubBase collateralHub = _hub(spoke4, collateralReserveId);
    uint256 collateralAssetId = _reserveAssetId(spoke4, collateralReserveId);

    // the liquidation fee is never charged: no fee shares are transferred or paid
    vm.expectCall(
      address(collateralHub),
      abi.encodeWithSelector(IHubBase.payFeeShares.selector, collateralAssetId),
      0
    );

    if (liquidationMetadata.collateralSharesToLiquidate > 0) {
      vm.expectCall(
        address(collateralHub),
        abi.encodeCall(
          IHubBase.remove,
          (collateralAssetId, liquidationMetadata.collateralAmountRemoved, liquidationManager)
        )
      );
    }
    vm.expectCall(
      address(_hub(spoke4, params.debtReserveId)),
      abi.encodeCall(
        IHubBase.restore,
        (
          _reserveAssetId(spoke4, params.debtReserveId),
          liquidationMetadata.debtAssetsToRestore -
            liquidationMetadata.premiumDebtRayToLiquidate.fromRayUp(),
          liquidationMetadata.premiumDelta
        )
      ),
      1
    );

    vm.expectEmit(address(babylonSpoke));
    emit IBabylonSpoke.BabylonLiquidationCall({
      collateralReserveId: collateralReserveId,
      debtReserveId: params.debtReserveId,
      user: params.user,
      liquidator: liquidationManager,
      debtAmountRestored: liquidationMetadata.debtAssetsToRestore,
      drawnSharesLiquidated: liquidationMetadata.drawnSharesToLiquidate,
      premiumDelta: liquidationMetadata.premiumDelta,
      collateralAmountRemoved: liquidationMetadata.collateralAmountRemoved,
      collateralSharesLiquidated: liquidationMetadata.collateralSharesToLiquidate
    });

    _expectBabylonPremiumRefreshOrDeficit(
      params,
      accountsInfoBefore,
      liquidationMetadata,
      expectedUserAccountData
    );
  }

  function _expectBabylonPremiumRefreshOrDeficit(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonAccountsSnapshot memory accountsInfoBefore,
    BabylonLiquidationMetadata memory liquidationMetadata,
    ISpoke.UserAccountData memory expectedUserAccountData
  ) internal virtual {
    bool riskPremiumOptimisation = accountsInfoBefore.userLastRiskPremium == 0 &&
      expectedUserAccountData.riskPremium == 0;

    ISpoke.UserPosition memory userReservePosition = spoke4.getUserPosition(
      params.debtReserveId,
      params.user
    );
    userReservePosition.drawnShares -= liquidationMetadata.drawnSharesToLiquidate.toUint120();
    userReservePosition.premiumShares = uint256(userReservePosition.premiumShares)
      .add(liquidationMetadata.premiumDelta.sharesDelta)
      .toUint120();
    userReservePosition.premiumOffsetRay = (userReservePosition.premiumOffsetRay +
      liquidationMetadata.premiumDelta.offsetRayDelta).toInt200();
    if (userReservePosition.drawnShares == 0) {
      return;
    }

    IHub targetHub = _hub(spoke4, params.debtReserveId);
    uint256 assetId = _reserveAssetId(spoke4, params.debtReserveId);
    uint256 userReserveDrawnDebt = targetHub.previewRestoreByShares(
      assetId,
      userReservePosition.drawnShares
    );

    if (liquidationMetadata.hasDeficit) {
      uint256 premiumDebtRay = _calculatePremiumDebtRay(
        targetHub,
        assetId,
        userReservePosition.premiumShares,
        userReservePosition.premiumOffsetRay
      );
      IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
        hub: targetHub,
        assetId: assetId,
        oldPremiumShares: userReservePosition.premiumShares,
        oldPremiumOffsetRay: userReservePosition.premiumOffsetRay,
        drawnShares: 0, // risk premium is 0
        riskPremium: 0,
        restoredPremiumRay: premiumDebtRay
      });

      vm.expectCall(
        address(targetHub),
        abi.encodeCall(IHubBase.reportDeficit, (assetId, userReserveDrawnDebt, premiumDelta)),
        1
      );
      vm.expectEmit(address(spoke4));
      emit ISpoke.ReportDeficit({
        reserveId: params.debtReserveId,
        user: params.user,
        drawnShares: userReservePosition.drawnShares,
        premiumDelta: premiumDelta
      });
      return;
    }

    vm.expectCall(
      address(targetHub),
      abi.encodeWithSelector(IHubBase.reportDeficit.selector, assetId),
      0
    );
    if (riskPremiumOptimisation) {
      vm.expectCall(
        address(targetHub),
        abi.encodeWithSelector(IHubBase.refreshPremium.selector, assetId),
        0
      );
      return;
    }

    IHubBase.PremiumDelta memory refreshDelta = _getExpectedPremiumDelta({
      hub: targetHub,
      assetId: assetId,
      oldPremiumShares: userReservePosition.premiumShares,
      oldPremiumOffsetRay: userReservePosition.premiumOffsetRay,
      drawnShares: userReservePosition.drawnShares,
      riskPremium: expectedUserAccountData.riskPremium,
      restoredPremiumRay: 0
    });
    vm.expectCall(
      address(targetHub),
      abi.encodeCall(IHubBase.refreshPremium, (assetId, refreshDelta)),
      1
    );
    vm.expectEmit(address(spoke4));
    emit ISpoke.RefreshPremiumDebt({
      reserveId: params.debtReserveId,
      user: params.user,
      premiumDelta: refreshDelta
    });
    vm.expectEmit(address(spoke4));
    emit ISpoke.UpdateUserRiskPremium({
      user: params.user,
      riskPremium: expectedUserAccountData.riskPremium
    });
  }

  function _checkBabylonHealthFactor(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonAccountsSnapshot memory accountsInfoBefore,
    BabylonLiquidationMetadata memory liquidationMetadata,
    ISpoke.UserAccountData memory userAccountDataAfter
  ) internal virtual {
    // the cap can never be exceeded, and is exactly consumed when enforced
    assertLe(
      liquidationMetadata.collateralSharesToLiquidate,
      liquidationMetadata.maxRemovableShares,
      'health factor: removal cap exceeded'
    );
    if (liquidationMetadata.collateralCapEnforced) {
      assertEq(
        liquidationMetadata.collateralSharesToLiquidate,
        liquidationMetadata.maxRemovableShares,
        'health factor: enforced removal cap not exactly consumed'
      );
    }

    if (liquidationMetadata.hasDeficit || userAccountDataAfter.totalDebtValueRay == 0) {
      assertEq(
        userAccountDataAfter.healthFactor,
        liquidationMetadata.hasDeficit ? userAccountDataAfter.healthFactor : UINT256_MAX,
        'health factor: no remaining debt'
      );
      return;
    }

    uint256 debtValueRayRepaid = _convertAmountToValue(
      spoke4,
      params.debtReserveId,
      liquidationMetadata.drawnSharesToLiquidate *
        _reserveDrawnIndex(spoke4, params.debtReserveId) +
        liquidationMetadata.premiumDebtRayToLiquidate
    );
    if (debtValueRayRepaid == 0) {
      return;
    }

    uint256 collateralValueRemoved = accountsInfoBefore.userAccountData.totalCollateralValue -
      userAccountDataAfter.totalCollateralValue;
    uint256 effectiveLiquidationBonusWad = Math.mulDiv(
      collateralValueRemoved,
      WadRayMath.RAY * WadRayMath.WAD,
      debtValueRayRepaid,
      Math.Rounding.Ceil
    );

    // health factor decreases if and only if lb * cf > hf before the liquidation
    if (
      effectiveLiquidationBonusWad *
        _getCollateralFactor(spoke4, collateralReserveId, params.user) >
      accountsInfoBefore.userAccountData.healthFactor * PercentageMath.PERCENTAGE_FACTOR
    ) {
      assertLe(
        userAccountDataAfter.healthFactor,
        accountsInfoBefore.userAccountData.healthFactor,
        'health factor: expected decrease'
      );
    } else {
      assertGe(
        userAccountDataAfter.healthFactor,
        accountsInfoBefore.userAccountData.healthFactor,
        'health factor: expected increase'
      );
    }
  }

  function _checkBabylonPositionStatus(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    assertEq(
      _isUsingAsCollateral(spoke4, collateralReserveId, params.user),
      true,
      'user position status: using as collateral'
    );
    bool isBorrowing = _isBorrowing(spoke4, params.debtReserveId, params.user);
    assertTrue(
      !liquidationMetadata.fullDebtReserveLiquidated
        ? (isBorrowing || liquidationMetadata.hasDeficit)
        : !isBorrowing,
      'user position status: borrowing'
    );
  }

  function _checkBabylonBalances(
    BabylonAccountsSnapshot memory accountsInfoBefore,
    BabylonAccountsSnapshot memory accountsInfoAfter,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    // collateral side: the liquidator always receives underlying assets
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.collateralErc20Balance,
      accountsInfoBefore.liquidatorBalanceInfo.collateralErc20Balance +
        liquidationMetadata.collateralAmountRemoved,
      'liquidator collateral erc20 balance'
    );
    assertEq(
      accountsInfoAfter.userBalanceInfo.collateralErc20Balance,
      accountsInfoBefore.userBalanceInfo.collateralErc20Balance,
      'user collateral erc20 balance'
    );
    assertEq(
      accountsInfoAfter.collateralHubBalanceInfo.collateralErc20Balance,
      accountsInfoBefore.collateralHubBalanceInfo.collateralErc20Balance -
        liquidationMetadata.collateralAmountRemoved,
      'collateral hub erc20 balance'
    );
    assertApproxEqAbs(
      accountsInfoAfter.userBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.userBalanceInfo.suppliedInSpoke -
        liquidationMetadata.collateralAmountRemoved,
      2,
      'user supplied in spoke'
    );
    // the liquidator never receives supplied shares
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.liquidatorBalanceInfo.suppliedInSpoke,
      'liquidator supplied in spoke'
    );

    // debt side
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.debtErc20Balance,
      accountsInfoBefore.liquidatorBalanceInfo.debtErc20Balance -
        liquidationMetadata.debtAssetsToRestore,
      'liquidator debt erc20 balance'
    );
    assertEq(
      accountsInfoAfter.debtHubBalanceInfo.debtErc20Balance,
      accountsInfoBefore.debtHubBalanceInfo.debtErc20Balance +
        liquidationMetadata.debtAssetsToRestore,
      'debt hub erc20 balance'
    );
    if (liquidationMetadata.hasDeficit) {
      assertEq(
        accountsInfoAfter.userBalanceInfo.borrowedFromSpoke,
        0,
        'user borrowed from spoke: deficit'
      );
    } else {
      assertApproxEqAbs(
        accountsInfoAfter.userBalanceInfo.borrowedFromSpoke,
        accountsInfoBefore.userBalanceInfo.borrowedFromSpoke -
          liquidationMetadata.debtAssetsToRestore,
        2,
        'user borrowed from spoke'
      );
    }
    assertEq(
      accountsInfoAfter.spokeBalanceInfo.debtErc20Balance,
      accountsInfoBefore.spokeBalanceInfo.debtErc20Balance,
      'spoke debt erc20 balance'
    );
  }

  /// @dev The returned data must match the sizing the call performed and the state it left.
  function _checkBabylonReturnData(
    BabylonLiquidationMetadata memory liquidationMetadata,
    BabylonAccountsSnapshot memory accountsInfoAfter,
    uint256 liquidationBonus,
    uint256 collateralAmountRemoved,
    ISpoke.UserAccountData memory userAccountDataAfter
  ) internal virtual {
    assertEq(liquidationBonus, liquidationMetadata.liquidationBonus, 'returned liquidation bonus');
    assertEq(
      collateralAmountRemoved,
      liquidationMetadata.collateralAmountRemoved,
      'returned collateral amount removed'
    );
    ISpoke.UserAccountData memory expectedUserAccountDataAfter;
    if (!liquidationMetadata.hasDeficit) {
      expectedUserAccountDataAfter = accountsInfoAfter.userAccountData;
    }
    assertEq(
      abi.encode(userAccountDataAfter),
      abi.encode(expectedUserAccountDataAfter),
      'returned user account data'
    );
  }

  function _checkedBabylonLiquidationCall(
    CheckedBabylonLiquidationCallParams memory params
  ) internal virtual {
    // guarantee hub liquidity so the collateral removal cannot fail for liquidity reasons
    _openSupplyPosition(
      spoke4,
      collateralReserveId,
      spoke4.getUserSuppliedAssets(collateralReserveId, params.user)
    );

    BabylonAccountsSnapshot memory accountsInfoBefore = _getBabylonAccountsInfo(params);
    BabylonLiquidationMetadata memory liquidationMetadata = _getBabylonLiquidationMetadata(
      params,
      accountsInfoBefore.userAccountData
    );
    ISpoke.UserAccountData
      memory expectedUserAccountData = _calculateExpectedBabylonUserAccountData(
        params,
        liquidationMetadata
      );

    _assertBeforeBabylonLiquidation(params, accountsInfoBefore, liquidationMetadata);
    _expectBabylonEventsAndCalls(
      params,
      accountsInfoBefore,
      liquidationMetadata,
      expectedUserAccountData
    );

    vm.prank(liquidationManager);
    (
      uint256 liquidationBonus,
      uint256 collateralAmountRemoved,
      ISpoke.UserAccountData memory userAccountDataAfter
    ) = babylonSpoke.liquidationCall(
        params.debtReserveId,
        params.debtToCover,
        params.user,
        params.maxCollateralToRemove
      );

    BabylonAccountsSnapshot memory accountsInfoAfter = _getBabylonAccountsInfo(params);

    if (!liquidationMetadata.hasDeficit) {
      assertEq(
        abi.encode(accountsInfoAfter.userAccountData),
        abi.encode(expectedUserAccountData),
        'user account data'
      );
    }
    _checkBabylonReturnData(
      liquidationMetadata,
      accountsInfoAfter,
      liquidationBonus,
      collateralAmountRemoved,
      userAccountDataAfter
    );
    _checkBabylonHealthFactor(
      params,
      accountsInfoBefore,
      liquidationMetadata,
      accountsInfoAfter.userAccountData
    );
    _checkBabylonPositionStatus(params, liquidationMetadata);
    _checkBabylonBalances(accountsInfoBefore, accountsInfoAfter, liquidationMetadata);

    _assertHubLiquidity(
      _hub(spoke4, collateralReserveId),
      _reserveAssetId(spoke4, collateralReserveId),
      'collateral'
    );
    _assertHubLiquidity(
      _hub(spoke4, params.debtReserveId),
      _reserveAssetId(spoke4, params.debtReserveId),
      'debt'
    );
  }
}
