// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/BabylonBase.t.sol';
import 'tests/contracts/spoke/liquidation/Spoke.LiquidationCall.Base.t.sol';
import {BabylonLiquidationLogicWrapper} from 'tests/helpers/mocks/BabylonLiquidationLogicWrapper.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';

/// @dev Assertion engine for the Babylon liquidation suites, mirroring the canonical
/// `SpokeLiquidationCallBaseTest` pipeline for the manager-gated, cap-bounded `liquidationCall`.
/// The engine relies on the managed collateral reserve keeping a supply share price of exactly
/// one (it is not borrowable in production), which it asserts, so collateral previews taken
/// before the call stay exact across the per debt reserve removals.
contract SpokeBabylonLiquidationCallBaseTest is BabylonBase, SpokeLiquidationCallBaseTest {
  using SafeCast for *;
  using PercentageMath for *;
  using WadRayMath for *;
  using KeyValueList for KeyValueList.List;
  using MathUtils for uint256;

  struct CheckedBabylonLiquidationCallParams {
    uint256[] debtReserveIds;
    uint256[] debtToCoverAmounts;
    address user;
    uint256 maxCollateralToRemove;
    bool isSolvent;
  }

  struct BabylonDebtReserveMetadata {
    uint256 debtReserveId;
    uint256 debtToCover;
    uint256 collateralSharesToLiquidate;
    uint256 collateralAmountRemoved;
    uint256 drawnSharesToLiquidate;
    uint256 premiumDebtRayToLiquidate;
    uint256 debtAssetsToRestore;
    IHubBase.PremiumDelta premiumDelta;
    bool fullDebtReserveLiquidated;
    bool skipped;
  }

  struct BabylonLiquidationMetadata {
    BabylonDebtReserveMetadata[] debtReserves;
    uint256 maxRemovableShares;
    uint256 totalCollateralSharesLiquidated;
    uint256 totalCollateralAmountRemoved;
    uint256 liquidationBonus;
    bool collateralCapEnforced;
    bool hasDeficit;
  }

  struct BabylonAccountsSnapshot {
    ISpoke.UserAccountData userAccountData;
    uint256 userLastRiskPremium;
    LiquidationBalanceSnapshot[] userBalanceInfo;
    LiquidationBalanceSnapshot[] liquidatorBalanceInfo;
    LiquidationBalanceSnapshot[] debtHubBalanceInfo;
    LiquidationBalanceSnapshot[] spokeBalanceInfo;
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
    uint256 debtReserveCount = params.debtReserveIds.length;
    snapshot.userAccountData = spoke4.getUserAccountData(params.user);
    snapshot.userLastRiskPremium = spoke4.getUserLastRiskPremium(params.user);
    snapshot.userBalanceInfo = new LiquidationBalanceSnapshot[](debtReserveCount);
    snapshot.liquidatorBalanceInfo = new LiquidationBalanceSnapshot[](debtReserveCount);
    snapshot.debtHubBalanceInfo = new LiquidationBalanceSnapshot[](debtReserveCount);
    snapshot.spokeBalanceInfo = new LiquidationBalanceSnapshot[](debtReserveCount);
    for (uint256 i = 0; i < debtReserveCount; i++) {
      uint256 debtReserveId = params.debtReserveIds[i];
      snapshot.userBalanceInfo[i] = _getBalanceInfo(
        spoke4,
        params.user,
        collateralReserveId,
        debtReserveId
      );
      snapshot.liquidatorBalanceInfo[i] = _getBalanceInfo(
        spoke4,
        liquidationManager,
        collateralReserveId,
        debtReserveId
      );
      snapshot.debtHubBalanceInfo[i] = _getBalanceInfo(
        spoke4,
        address(_hub(spoke4, debtReserveId)),
        collateralReserveId,
        debtReserveId
      );
      snapshot.spokeBalanceInfo[i] = _getBalanceInfo(
        spoke4,
        address(spoke4),
        collateralReserveId,
        debtReserveId
      );
    }
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
    // the engine relies on collateral previews taken before the call staying exact across the
    // per debt reserve removals, which holds if and only if the collateral supply share price is one
    IHubBase collateralHub = _hub(spoke4, collateralReserveId);
    uint256 collateralAssetId = _reserveAssetId(spoke4, collateralReserveId);
    assertEq(
      collateralHub.getAddedAssets(collateralAssetId),
      collateralHub.getAddedShares(collateralAssetId),
      'managed collateral share price must be one'
    );

    metadata.debtReserves = new BabylonDebtReserveMetadata[](params.debtReserveIds.length);
    metadata.liquidationBonus = spoke4.getLiquidationBonus(
      collateralReserveId,
      params.user,
      userAccountDataBefore.healthFactor
    );
    metadata.maxRemovableShares = collateralHub
      .previewAddByAssets(collateralAssetId, params.maxCollateralToRemove)
      .min(spoke4.getUserPosition(collateralReserveId, params.user).suppliedShares);

    uint256 remainingShares = metadata.maxRemovableShares;
    for (uint256 i = 0; i < params.debtReserveIds.length; i++) {
      BabylonDebtReserveMetadata memory debtReserveMetadata = metadata.debtReserves[i];
      debtReserveMetadata.debtReserveId = params.debtReserveIds[i];
      debtReserveMetadata.debtToCover = params.debtToCoverAmounts[i];

      if (spoke4.getUserPosition(debtReserveMetadata.debtReserveId, params.user).drawnShares == 0) {
        debtReserveMetadata.skipped = true;
        continue;
      }

      BabylonLiquidationLogic.LiquidationAmounts
        memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
          _getCalculateBabylonLiquidationAmountsParams(
            params.user,
            debtReserveMetadata.debtReserveId,
            debtReserveMetadata.debtToCover,
            metadata.liquidationBonus,
            remainingShares
          )
        );
      // the cap is enforced on this debt reserve if the unbounded sizing would remove more shares
      metadata.collateralCapEnforced =
        metadata.collateralCapEnforced ||
        babylonLiquidationLogicWrapper
          .calculateLiquidationAmounts(
            _getCalculateBabylonLiquidationAmountsParams(
              params.user,
              debtReserveMetadata.debtReserveId,
              debtReserveMetadata.debtToCover,
              metadata.liquidationBonus,
              UINT256_MAX
            )
          )
          .collateralSharesToLiquidate >
          remainingShares;

      debtReserveMetadata.collateralSharesToLiquidate = liquidationAmounts
        .collateralSharesToLiquidate;
      // exact at a collateral share price of one
      debtReserveMetadata.collateralAmountRemoved = collateralHub.previewRemoveByShares(
        collateralAssetId,
        liquidationAmounts.collateralSharesToLiquidate
      );
      debtReserveMetadata.drawnSharesToLiquidate = liquidationAmounts.drawnSharesToLiquidate;
      debtReserveMetadata.premiumDebtRayToLiquidate = liquidationAmounts.premiumDebtRayToLiquidate;
      debtReserveMetadata.debtAssetsToRestore = _calculateDebtAssetsToRestore({
        drawnSharesToLiquidate: liquidationAmounts.drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: liquidationAmounts.premiumDebtRayToLiquidate,
        drawnIndex: _reserveDrawnIndex(spoke4, debtReserveMetadata.debtReserveId)
      });
      debtReserveMetadata.premiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke4,
        params.user,
        debtReserveMetadata.debtReserveId,
        debtReserveMetadata.debtAssetsToRestore
      );
      debtReserveMetadata.fullDebtReserveLiquidated =
        liquidationAmounts.drawnSharesToLiquidate ==
        _getUserDrawnShares(spoke4, debtReserveMetadata.debtReserveId, params.user);

      metadata.totalCollateralSharesLiquidated += debtReserveMetadata.collateralSharesToLiquidate;
      metadata.totalCollateralAmountRemoved += debtReserveMetadata.collateralAmountRemoved;
      remainingShares -= debtReserveMetadata.collateralSharesToLiquidate;
      if (remainingShares == 0) {
        // the removal cap is consumed: the loop stops and later debt reserves are never processed
        for (uint256 j = i + 1; j < metadata.debtReserves.length; j++) {
          metadata.debtReserves[j].debtReserveId = params.debtReserveIds[j];
          metadata.debtReserves[j].debtToCover = params.debtToCoverAmounts[j];
          metadata.debtReserves[j].skipped = true;
        }
        break;
      }
    }

    metadata.hasDeficit =
      metadata.totalCollateralSharesLiquidated ==
        spoke4.getUserPosition(collateralReserveId, params.user).suppliedShares &&
      _userBorrowsAfterRepayments(params, metadata);
  }

  /// @dev True if the user still borrows any reserve after the expected repayments.
  function _userBorrowsAfterRepayments(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonLiquidationMetadata memory metadata
  ) internal view returns (bool) {
    for (uint256 reserveId = 0; reserveId < spoke4.getReserveCount(); reserveId++) {
      if (!_isBorrowing(spoke4, reserveId, params.user)) {
        continue;
      }
      uint256 drawnShares = spoke4.getUserPosition(reserveId, params.user).drawnShares;
      for (uint256 i = 0; i < metadata.debtReserves.length; i++) {
        if (
          metadata.debtReserves[i].debtReserveId == reserveId && !metadata.debtReserves[i].skipped
        ) {
          drawnShares -= metadata.debtReserves[i].drawnSharesToLiquidate;
        }
      }
      if (drawnShares > 0) {
        return true;
      }
    }
    return false;
  }

  // calculate expected user account data after liquidation; the user has a single registered
  // collateral by construction, which collapses the canonical multi-collateral recompute
  function _calculateExpectedBabylonUserAccountData(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal virtual returns (ISpoke.UserAccountData memory expectedUserAccountData) {
    uint256 userSuppliedShares = spoke4
      .getUserPosition(collateralReserveId, params.user)
      .suppliedShares - liquidationMetadata.totalCollateralSharesLiquidated;
    uint256 userSuppliedValue;

    if (
      userSuppliedShares > 0 && _getCollateralFactor(spoke4, collateralReserveId, params.user) > 0
    ) {
      IHubBase hub = _hub(spoke4, collateralReserveId);
      uint256 assetId = _reserveAssetId(spoke4, collateralReserveId);
      uint256 userSuppliedAssets = userSuppliedShares.mulDivDown(
        hub.getAddedAssets(assetId) -
          liquidationMetadata.totalCollateralAmountRemoved +
          VIRTUAL_ASSETS,
        hub.getAddedShares(assetId) -
          liquidationMetadata.totalCollateralSharesLiquidated +
          VIRTUAL_SHARES
      );
      userSuppliedValue = _convertAmountToValue(spoke4, collateralReserveId, userSuppliedAssets);
      expectedUserAccountData.activeCollateralCount = 1;
      expectedUserAccountData.totalCollateralValue = userSuppliedValue;
      expectedUserAccountData.avgCollateralFactor =
        _getCollateralFactor(spoke4, collateralReserveId, params.user) * userSuppliedValue;
    }

    for (
      uint256 reserveId = 0;
      reserveId < spoke4.getReserveCount() && !liquidationMetadata.hasDeficit;
      reserveId++
    ) {
      if (!_isBorrowing(spoke4, reserveId, params.user)) {
        continue;
      }

      uint256 userDrawnShares = spoke4.getUserPosition(reserveId, params.user).drawnShares;
      uint256 userPremiumDebtRay = _calculatePremiumDebtRay(spoke4, reserveId, params.user);
      for (uint256 i = 0; i < liquidationMetadata.debtReserves.length; i++) {
        BabylonDebtReserveMetadata memory debtReserveMetadata = liquidationMetadata.debtReserves[i];
        if (debtReserveMetadata.debtReserveId == reserveId && !debtReserveMetadata.skipped) {
          userDrawnShares -= debtReserveMetadata.drawnSharesToLiquidate;
          userPremiumDebtRay -= debtReserveMetadata.premiumDebtRayToLiquidate;
        }
      }
      if (userDrawnShares == 0) {
        continue;
      }
      expectedUserAccountData.borrowCount++;
      expectedUserAccountData.totalDebtValueRay += _convertAmountToValue(
        spoke4,
        reserveId,
        userDrawnShares * _reserveDrawnIndex(spoke4, reserveId) + userPremiumDebtRay
      );
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

    for (uint256 i = 0; i < liquidationMetadata.debtReserves.length; i++) {
      BabylonDebtReserveMetadata memory debtReserveMetadata = liquidationMetadata.debtReserves[i];
      if (debtReserveMetadata.skipped) {
        continue;
      }
      IHubBase debtHub = _hub(spoke4, debtReserveMetadata.debtReserveId);

      if (debtReserveMetadata.collateralSharesToLiquidate > 0) {
        vm.expectCall(
          address(collateralHub),
          abi.encodeCall(
            IHubBase.remove,
            (collateralAssetId, debtReserveMetadata.collateralAmountRemoved, liquidationManager)
          )
        );
      }
      vm.expectCall(
        address(debtHub),
        abi.encodeCall(
          IHubBase.restore,
          (
            _reserveAssetId(spoke4, debtReserveMetadata.debtReserveId),
            debtReserveMetadata.debtAssetsToRestore -
              debtReserveMetadata.premiumDebtRayToLiquidate.fromRayUp(),
            debtReserveMetadata.premiumDelta
          )
        ),
        1
      );

      vm.expectEmit(address(babylonSpoke));
      emit IBabylonSpoke.BabylonLiquidationCall({
        debtReserveId: debtReserveMetadata.debtReserveId,
        user: params.user,
        liquidator: liquidationManager,
        debtAmountRestored: debtReserveMetadata.debtAssetsToRestore,
        drawnSharesLiquidated: debtReserveMetadata.drawnSharesToLiquidate,
        premiumDelta: debtReserveMetadata.premiumDelta,
        collateralAmountRemoved: debtReserveMetadata.collateralAmountRemoved,
        collateralSharesLiquidated: debtReserveMetadata.collateralSharesToLiquidate
      });
    }

    vm.expectEmit(address(babylonSpoke));
    emit IBabylonSpoke.BabylonLiquidationCallSummary({
      user: params.user,
      liquidator: liquidationManager,
      collateralAmountRemoved: liquidationMetadata.totalCollateralAmountRemoved,
      collateralSharesLiquidated: liquidationMetadata.totalCollateralSharesLiquidated
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

    for (uint256 i = spoke4.getReserveCount(); i != 0; ) {
      i--;
      uint256 reserveId = i;
      if (!_isBorrowing(spoke4, reserveId, params.user)) {
        continue;
      }
      ISpoke.UserPosition memory userReservePosition = spoke4.getUserPosition(
        reserveId,
        params.user
      );

      for (uint256 j = 0; j < liquidationMetadata.debtReserves.length; j++) {
        BabylonDebtReserveMetadata memory debtReserveMetadata = liquidationMetadata.debtReserves[j];
        if (debtReserveMetadata.debtReserveId == reserveId && !debtReserveMetadata.skipped) {
          userReservePosition.drawnShares -= debtReserveMetadata.drawnSharesToLiquidate.toUint120();
          userReservePosition.premiumShares = uint256(userReservePosition.premiumShares)
            .add(debtReserveMetadata.premiumDelta.sharesDelta)
            .toUint120();
          userReservePosition.premiumOffsetRay = (userReservePosition.premiumOffsetRay +
            debtReserveMetadata.premiumDelta.offsetRayDelta).toInt200();
        }
      }
      if (userReservePosition.drawnShares == 0) {
        continue;
      }

      IHub targetHub = _hub(spoke4, reserveId);
      uint256 assetId = _reserveAssetId(spoke4, reserveId);
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
          reserveId: reserveId,
          user: params.user,
          drawnShares: userReservePosition.drawnShares,
          premiumDelta: premiumDelta
        });
      } else {
        vm.expectCall(
          address(targetHub),
          abi.encodeWithSelector(IHubBase.reportDeficit.selector, assetId),
          0
        );

        if (!riskPremiumOptimisation) {
          IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
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
            abi.encodeCall(IHubBase.refreshPremium, (assetId, premiumDelta)),
            1
          );
          vm.expectEmit(address(spoke4));
          emit ISpoke.RefreshPremiumDebt({
            reserveId: reserveId,
            user: params.user,
            premiumDelta: premiumDelta
          });
        } else {
          vm.expectCall(
            address(targetHub),
            abi.encodeWithSelector(IHubBase.refreshPremium.selector, assetId),
            0
          );
        }
      }
    }

    if (!liquidationMetadata.hasDeficit && !riskPremiumOptimisation) {
      vm.expectEmit(address(spoke4));
      emit ISpoke.UpdateUserRiskPremium({
        user: params.user,
        riskPremium: expectedUserAccountData.riskPremium
      });
    }
  }

  function _checkBabylonHealthFactor(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonAccountsSnapshot memory accountsInfoBefore,
    BabylonLiquidationMetadata memory liquidationMetadata,
    ISpoke.UserAccountData memory userAccountDataAfter
  ) internal virtual {
    // the cap can never be exceeded, and is exactly consumed when enforced
    assertLe(
      liquidationMetadata.totalCollateralSharesLiquidated,
      liquidationMetadata.maxRemovableShares,
      'health factor: removal cap exceeded'
    );
    if (liquidationMetadata.collateralCapEnforced) {
      assertEq(
        liquidationMetadata.totalCollateralSharesLiquidated,
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

    // aggregate debt value repaid across the debt reserves
    uint256 debtValueRayRepaid;
    for (uint256 i = 0; i < liquidationMetadata.debtReserves.length; i++) {
      BabylonDebtReserveMetadata memory debtReserveMetadata = liquidationMetadata.debtReserves[i];
      if (debtReserveMetadata.skipped) {
        continue;
      }
      debtValueRayRepaid += _convertAmountToValue(
        spoke4,
        debtReserveMetadata.debtReserveId,
        debtReserveMetadata.drawnSharesToLiquidate *
          _reserveDrawnIndex(spoke4, debtReserveMetadata.debtReserveId) +
          debtReserveMetadata.premiumDebtRayToLiquidate
      );
    }
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
    for (uint256 i = 0; i < liquidationMetadata.debtReserves.length; i++) {
      BabylonDebtReserveMetadata memory debtReserveMetadata = liquidationMetadata.debtReserves[i];
      if (debtReserveMetadata.skipped) {
        continue;
      }
      bool isBorrowing = _isBorrowing(spoke4, debtReserveMetadata.debtReserveId, params.user);
      assertTrue(
        !debtReserveMetadata.fullDebtReserveLiquidated
          ? (isBorrowing || liquidationMetadata.hasDeficit)
          : !isBorrowing,
        'user position status: borrowing'
      );
    }
  }

  function _checkBabylonBalances(
    CheckedBabylonLiquidationCallParams memory params,
    BabylonAccountsSnapshot memory accountsInfoBefore,
    BabylonAccountsSnapshot memory accountsInfoAfter,
    BabylonLiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    // collateral side: the liquidator always receives underlying assets
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo[0].collateralErc20Balance,
      accountsInfoBefore.liquidatorBalanceInfo[0].collateralErc20Balance +
        liquidationMetadata.totalCollateralAmountRemoved,
      'liquidator collateral erc20 balance'
    );
    assertEq(
      accountsInfoAfter.userBalanceInfo[0].collateralErc20Balance,
      accountsInfoBefore.userBalanceInfo[0].collateralErc20Balance,
      'user collateral erc20 balance'
    );
    assertEq(
      accountsInfoAfter.collateralHubBalanceInfo.collateralErc20Balance,
      accountsInfoBefore.collateralHubBalanceInfo.collateralErc20Balance -
        liquidationMetadata.totalCollateralAmountRemoved,
      'collateral hub erc20 balance'
    );
    assertApproxEqAbs(
      accountsInfoAfter.userBalanceInfo[0].suppliedInSpoke,
      accountsInfoBefore.userBalanceInfo[0].suppliedInSpoke -
        liquidationMetadata.totalCollateralAmountRemoved,
      2,
      'user supplied in spoke'
    );
    // the liquidator never receives supplied shares
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo[0].suppliedInSpoke,
      accountsInfoBefore.liquidatorBalanceInfo[0].suppliedInSpoke,
      'liquidator supplied in spoke'
    );

    // debt side, per debt reserve
    for (uint256 i = 0; i < liquidationMetadata.debtReserves.length; i++) {
      BabylonDebtReserveMetadata memory debtReserveMetadata = liquidationMetadata.debtReserves[i];
      uint256 restored = debtReserveMetadata.skipped ? 0 : debtReserveMetadata.debtAssetsToRestore;

      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo[i].debtErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo[i].debtErc20Balance -
          _restoredForReserve(liquidationMetadata, debtReserveMetadata.debtReserveId),
        'liquidator debt erc20 balance'
      );
      assertEq(
        accountsInfoAfter.debtHubBalanceInfo[i].debtErc20Balance,
        accountsInfoBefore.debtHubBalanceInfo[i].debtErc20Balance +
          _restoredForReserve(liquidationMetadata, debtReserveMetadata.debtReserveId),
        'debt hub erc20 balance'
      );
      if (liquidationMetadata.hasDeficit) {
        assertEq(
          accountsInfoAfter.userBalanceInfo[i].borrowedFromSpoke,
          0,
          'user borrowed from spoke: deficit'
        );
      } else if (!debtReserveMetadata.skipped) {
        assertApproxEqAbs(
          accountsInfoAfter.userBalanceInfo[i].borrowedFromSpoke,
          accountsInfoBefore.userBalanceInfo[i].borrowedFromSpoke - restored,
          2,
          'user borrowed from spoke'
        );
      }
      assertEq(
        accountsInfoAfter.spokeBalanceInfo[i].debtErc20Balance,
        accountsInfoBefore.spokeBalanceInfo[i].debtErc20Balance,
        'spoke debt erc20 balance'
      );
    }
  }

  /// @dev Total debt assets restored for a reserve across the metadata entries (a reserve appears at most once).
  function _restoredForReserve(
    BabylonLiquidationMetadata memory metadata,
    uint256 reserveId
  ) internal pure returns (uint256 restored) {
    for (uint256 i = 0; i < metadata.debtReserves.length; i++) {
      if (
        metadata.debtReserves[i].debtReserveId == reserveId && !metadata.debtReserves[i].skipped
      ) {
        restored += metadata.debtReserves[i].debtAssetsToRestore;
      }
    }
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
    babylonSpoke.liquidationCall(
      params.debtReserveIds,
      params.debtToCoverAmounts,
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
    _checkBabylonHealthFactor(
      params,
      accountsInfoBefore,
      liquidationMetadata,
      accountsInfoAfter.userAccountData
    );
    _checkBabylonPositionStatus(params, liquidationMetadata);
    _checkBabylonBalances(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);

    _assertHubLiquidity(
      _hub(spoke4, collateralReserveId),
      _reserveAssetId(spoke4, collateralReserveId),
      'collateral'
    );
    for (uint256 i = 0; i < params.debtReserveIds.length; i++) {
      _assertHubLiquidity(
        _hub(spoke4, params.debtReserveIds[i]),
        _reserveAssetId(spoke4, params.debtReserveIds[i]),
        'debt'
      );
    }
  }
}
