// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {CheckedActions} from 'tests/helpers/CheckedActions.sol';

contract SpokeBase is Base, CheckedActions {
  using SafeCast for *;
  using PercentageMath for *;
  using WadRayMath for *;
  using KeyValueList for KeyValueList.List;
  using ReserveFlagsMap for ReserveFlags;

  struct SupplyBorrowLocal {
    uint256 collateralReserveAssetId;
    uint256 borrowReserveAssetId;
    uint256 collateralSupplyShares;
    uint256 borrowSupplyShares;
    uint256 reserveSharesBefore;
    uint256 userSharesBefore;
    uint256 borrowerDrawnDebtBefore;
    uint256 reserveDrawnDebtBefore;
    uint256 borrowerDrawnDebtAfter;
    uint256 reserveDrawnDebtAfter;
  }

  struct CalculateRiskPremiumLocal {
    uint256 reserveCount;
    uint256 totalDebtValue;
    uint256 healthFactor;
    uint256 activeCollateralCount;
    uint32 dynamicConfigKey;
    uint256 collateralFactor;
    uint256 collateralValue;
    ISpoke.UserPosition pos;
    uint256 riskPremium;
    uint256 utilizedSupply;
    uint256 idx;
  }

  struct UserActionData {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 userBalanceBefore;
    uint256 userBalanceAfter;
    ISpoke.UserPosition userPosBefore;
    uint256 premiumDebtRayBefore;
  }

  struct BorrowTestData {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    UserActionData daiAlice;
    UserActionData wethAlice;
    UserActionData usdxAlice;
    UserActionData wbtcAlice;
    UserActionData daiBob;
    UserActionData wethBob;
    UserActionData usdxBob;
    UserActionData wbtcBob;
  }

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
  }

  /// @dev Opens a supply position for a random user
  function _openSupplyPosition(ISpoke spoke, uint256 reserveId, uint256 amount) public {
    _increaseCollateralSupply(spoke, reserveId, amount, makeUser());
  }

  /// @dev Increases the collateral supply for a user
  function _increaseCollateralSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    address user
  ) public {
    deal(spoke, reserveId, user, amount);
    Utils.approve(spoke, reserveId, user, UINT256_MAX);

    _checkedSupplyCollateral(
      CheckedSupplyCollateralParams({
        spoke: spoke,
        reserveId: reserveId,
        user: user,
        amount: amount,
        onBehalfOf: user
      })
    );
    // _checkedSupply already asserts supply shares and reserve supply increased
  }

  function _increaseReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    address user
  ) internal {
    _openSupplyPosition(
      spoke,
      reserveId,
      _max(_hub(spoke, reserveId).previewAddByShares(_reserveAssetId(spoke, reserveId), 1), amount)
    );
    Utils.borrow(spoke, reserveId, user, amount, user);
  }

  /// @dev Opens a debt position for a random user, using same asset as collateral and borrow
  function _openDebtPosition(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    bool withPremium
  ) internal returns (address) {
    address tempUser = makeUser();

    // add collateral
    uint256 supplyAmount = _calcMinimumCollAmount({
      spoke: spoke,
      collReserveId: reserveId,
      debtReserveId: reserveId,
      debtAmount: amount
    });

    deal(spoke, reserveId, tempUser, supplyAmount);
    Utils.approve(spoke, reserveId, tempUser, UINT256_MAX);

    Utils.supplyCollateral({
      spoke: spoke,
      reserveId: reserveId,
      caller: tempUser,
      amount: supplyAmount,
      onBehalfOf: tempUser
    });

    // debt
    uint24 cachedCollateralRisk;
    if (withPremium) {
      cachedCollateralRisk = _getCollateralRisk(spoke, reserveId);
      _updateCollateralRisk(spoke, reserveId, 50_00);
    }

    Utils.borrow({
      spoke: spoke,
      reserveId: reserveId,
      caller: tempUser,
      amount: amount,
      onBehalfOf: tempUser
    });
    skip(365 days);

    (uint256 drawnDebt, uint256 premiumDebt) = spoke.getReserveDebt(reserveId);
    assertGt(drawnDebt, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premiumDebt, 0);
      // restore cached collateral risk
      _updateCollateralRisk(spoke, reserveId, cachedCollateralRisk);
    }

    return tempUser;
  }

  // @dev Borrows reserve by minimum required collateral for the same reserve
  function _backedBorrow(
    ISpoke spoke,
    address user,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 borrowAmount
  ) internal {
    uint256 supplyAmount = _calcMinimumCollAmount(
      spoke,
      collateralReserveId,
      debtReserveId,
      borrowAmount
    ) * 5;
    deal(spoke, collateralReserveId, user, supplyAmount);
    Utils.approve(spoke, collateralReserveId, user, UINT256_MAX);
    Utils.supplyCollateral(spoke, collateralReserveId, user, supplyAmount, user);
    Utils.borrow(spoke, debtReserveId, user, borrowAmount, user);
  }

  function deal(ISpoke spoke, uint256 reserveId, address user, uint256 amount) internal {
    IERC20 underlying = getAssetUnderlyingByReserveId(spoke, reserveId);
    if (underlying.balanceOf(user) < amount) {
      deal(address(underlying), user, amount);
    }
  }

  // increase share conversion index on given reserve
  // bob supplies borrow asset
  // alice supply (weth) collateral asset, borrow asset, skip 1 year to increase index
  /// @return supply amount of collateral asset
  /// @return supply shares of collateral asset
  /// @return borrow amount of borrowed asset
  /// @return supply shares of borrowed asset
  /// @return supply amount of borrowed asset
  function _increaseReserveIndex(
    ISpoke spoke,
    uint256 reserveId
  ) internal returns (uint256, uint256, uint256, uint256, uint256) {
    SupplyBorrowLocal memory state;

    ReserveSetupParams memory collateral;
    collateral.reserveId = _wethReserveId(spoke);
    collateral.supplyAmount = 1_000e18;
    collateral.supplier = alice;

    ReserveSetupParams memory borrow;
    borrow.reserveId = reserveId;
    borrow.supplier = bob;
    borrow.borrower = alice;
    borrow.supplyAmount = 100e18;
    borrow.borrowAmount = borrow.supplyAmount / 2;

    (state.borrowReserveAssetId, ) = getAssetByReserveId(spoke, borrow.reserveId);
    (state.collateralSupplyShares, state.borrowSupplyShares) = _executeSpokeSupplyAndBorrow({
      spoke: spoke,
      collateral: collateral,
      borrow: borrow,
      rate: 0,
      isMockRate: false,
      skipTime: 365 days
    });

    // index has increased, ie now the shares are less than the amount
    assertGt(
      borrow.supplyAmount,
      hub1.previewAddByAssets(state.borrowReserveAssetId, borrow.supplyAmount)
    );

    return (
      collateral.supplyAmount,
      state.collateralSupplyShares,
      borrow.borrowAmount,
      state.borrowSupplyShares,
      borrow.supplyAmount
    );
  }

  // supply collateral asset, borrow asset, skip time to increase index on borrow asset
  /// @return supplyShares of collateral asset
  /// @return supplyShares of borrowed asset
  function _executeSpokeSupplyAndBorrow(
    ISpoke spoke,
    ReserveSetupParams memory collateral,
    ReserveSetupParams memory borrow,
    uint256 rate,
    bool isMockRate,
    uint256 skipTime
  ) internal returns (uint256, uint256) {
    if (isMockRate) {
      _mockInterestRateBps(rate);
    }

    // supply collateral asset
    CheckedSupplyResult memory collResult = _checkedSupplyCollateral(
      CheckedSupplyCollateralParams({
        spoke: spoke,
        reserveId: collateral.reserveId,
        user: collateral.supplier,
        amount: collateral.supplyAmount,
        onBehalfOf: collateral.supplier
      })
    );

    // other user supplies enough asset to be drawn
    CheckedSupplyResult memory supplyResult = _checkedSupply(
      CheckedSupplyParams({
        spoke: spoke,
        reserveId: borrow.reserveId,
        user: borrow.supplier,
        amount: borrow.supplyAmount,
        onBehalfOf: borrow.supplier
      })
    );

    // borrower borrows asset
    CheckedBorrowResult memory borrowResult = _checkedBorrow(
      CheckedBorrowParams({
        spoke: spoke,
        reserveId: borrow.reserveId,
        user: borrow.borrower,
        amount: borrow.borrowAmount,
        onBehalfOf: borrow.borrower
      })
    );

    // Assert borrow amount matches
    assertEq(
      borrowResult.userAfter.drawnDebt - borrowResult.userBefore.drawnDebt,
      borrow.borrowAmount
    );
    assertEq(
      borrowResult.reserveAfter.totalDrawnDebt - borrowResult.reserveBefore.totalDrawnDebt,
      borrow.borrowAmount
    );

    // skip time to increase index
    skip(skipTime);
    return (collResult.shares, supplyResult.shares);
  }

  function _repayAll(
    ISpoke spoke,
    function(ISpoke) view returns (uint256) _assetReserveId
  ) internal {
    uint256 reserveId = _assetReserveId(spoke);
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 assetOwedWithoutSpoke = hub1.getAssetTotalOwed(assetId) -
      hub1.getSpokeTotalOwed(assetId, address(spoke));

    address[4] memory users = [alice, bob, carol, derl];
    for (uint256 i; i < users.length; ++i) {
      address user = users[i];
      uint256 debt = spoke.getUserTotalDebt(reserveId, user);
      if (debt > 0) {
        deal(hub1.getAsset(assetId).underlying, user, debt);
        vm.prank(user);
        spoke.repay(reserveId, debt, user);
        assertEq(spoke.getUserTotalDebt(reserveId, user), 0, 'user debt not zero');
        assertFalse(_isBorrowing(spoke, reserveId, user));
        // If the user has no debt in any asset (hf will be max), user risk premium should be zero
        if (_getUserHealthFactor(spoke, user) == UINT256_MAX) {
          assertEq(_getUserRiskPremium(spoke, user), 0, 'user risk premium not zero');
        }
      }
    }

    assertEq(spoke.getReserveTotalDebt(reserveId), 0, 'reserve total debt not zero');
    assertEq(hub1.getSpokeTotalOwed(assetId, address(spoke)), 0, 'hub spoke total debt not zero');
    assertEq(
      hub1.getAssetTotalOwed(assetId),
      assetOwedWithoutSpoke,
      'hub asset total debt not settled'
    );
  }

  function getTokenBalances(
    IERC20 token,
    address spoke
  ) internal view returns (TokenBalances memory) {
    return
      TokenBalances({
        spokeBalance: token.balanceOf(spoke),
        hubBalance: token.balanceOf(address(hub1))
      });
  }

  function _calcMaxDebtAmount(
    ISpoke spoke,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 collAmount
  ) internal view returns (uint256) {
    IPriceOracle oracle = IPriceOracle(spoke.ORACLE());
    ISpoke.Reserve memory collData = spoke.getReserve(collReserveId);
    ISpoke.DynamicReserveConfig memory colDynConf = _getLatestDynamicReserveConfig(
      spoke,
      collReserveId
    );
    uint256 collPrice = oracle.getReservePrice(collReserveId);
    uint256 collAssetUnits = 10 ** hub1.getAsset(collData.assetId).decimals;

    ISpoke.Reserve memory debtData = spoke.getReserve(debtReserveId);
    uint256 debtAssetUnits = 10 ** hub1.getAsset(debtData.assetId).decimals;
    uint256 debtPrice = oracle.getReservePrice(debtReserveId);

    uint256 normalizedDebtAmount = (debtPrice).wadDivDown(debtAssetUnits);
    uint256 normalizedCollPrice = (collAmount * collPrice).wadDivDown(collAssetUnits);

    uint256 maxDebt = (
      (normalizedCollPrice.toWad().percentMulDown(colDynConf.collateralFactor) /
        normalizedDebtAmount.toWad())
    );

    return maxDebt > 1 ? maxDebt - 1 : maxDebt;
  }

  // assert that user's position and debt accounting matches expected
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

    // user position
    ISpoke.UserPosition memory userPos = getUserInfo(spoke, user, reserveId);
    ISpoke.UserPosition memory expectedUserPos = _calcUserPositionBySuppliedAndDebtAmount(
      spoke,
      user,
      expectedPremiumDebtRay,
      assetId,
      debtAmount,
      suppliedAmount
    );

    // user debt
    DebtData memory expectedUserDebt = _calcExpectedUserDebt(assetId, expectedUserPos);
    DebtData memory userDebt = _getUserDebt(spoke, reserveId, user);
    assertEq(_isBorrowing(spoke, reserveId, user), userDebt.totalDebt > 0);

    // assertions
    _assertUserPosition(userPos, expectedUserPos, label);
    _assertUserDebt(userDebt, expectedUserDebt, label);
  }

  function _calcExpectedUserDebt(
    uint256 assetId,
    ISpoke.UserPosition memory userPos
  ) internal view returns (DebtData memory userDebt) {
    userDebt.premiumDebt = _calculatePremiumDebt(
      hub1,
      assetId,
      userPos.premiumShares,
      userPos.premiumOffsetRay
    );
    userDebt.drawnDebt = hub1.previewRestoreByShares(assetId, userPos.drawnShares);
    userDebt.totalDebt = userDebt.drawnDebt + userDebt.premiumDebt;
  }

  function _getUserDrawnShares(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getUserPosition(reserveId, user).drawnShares;
  }

  function _getUserDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (DebtData memory) {
    DebtData memory userDebt;
    userDebt.totalDebt = spoke.getUserTotalDebt(reserveId, user);
    (userDebt.drawnDebt, userDebt.premiumDebt) = spoke.getUserDebt(reserveId, user);
    assertEq(userDebt.totalDebt, userDebt.drawnDebt + userDebt.premiumDebt);
    return userDebt;
  }

  // assert that user position matches expected
  function _assertUserPosition(
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

  function _assertUserDebt(
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

  // calculate expected user position using latest risk premium
  function _calcUserPositionBySuppliedAndDebtAmount(
    ISpoke spoke,
    address user,
    uint256 expectedPremiumDebtRay,
    uint256 assetId,
    uint256 debtAmount,
    uint256 suppliedAmount
  ) internal view returns (ISpoke.UserPosition memory userPos) {
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    userPos.drawnShares = hub1.previewRestoreByAssets(assetId, debtAmount).toUint120();
    userPos.premiumShares = hub1
      .previewRestoreByAssets(assetId, debtAmount)
      .percentMulUp(userAccountData.riskPremium)
      .toUint120();
    userPos.premiumOffsetRay =
      _calculatePremiumAssetsRay(hub1, assetId, userPos.premiumShares).toInt256().toInt200() -
      expectedPremiumDebtRay.toInt256().toInt200();
    userPos.suppliedShares = hub1.previewAddByAssets(assetId, suppliedAmount).toUint120();
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

    reserveDebt.totalDebt = spoke.getReserveTotalDebt(reserveId);
    (reserveDebt.drawnDebt, reserveDebt.premiumDebt) = spoke.getReserveDebt(reserveId);

    for (uint256 i = 0; i < users.length; ++i) {
      ISpoke.UserPosition memory userData = getUserInfo(spoke, users[i], reserveId);
      (uint256 drawnDebt, uint256 premiumDebt) = spoke.getUserDebt(reserveId, users[i]);

      usersDebt.drawnDebt += drawnDebt;
      usersDebt.premiumDebt += premiumDebt;
      usersDebt.totalDebt += drawnDebt + premiumDebt;

      assertEq(
        drawnDebt,
        hub1.previewRestoreByShares(assetId, userData.drawnShares),
        string.concat('user ', vm.toString(i), ' drawn debt ', label)
      );
      assertEq(
        premiumDebt,
        _calculatePremiumDebt(hub1, assetId, userData.premiumShares, userData.premiumOffsetRay),
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

  /// @dev get stored user risk premium from storage
  function _getUserRpStored(ISpoke spoke, address user) internal view returns (uint256) {
    return spoke.getUserLastRiskPremium(user);
  }

  function _isHealthy(ISpoke spoke, address user) internal view returns (bool) {
    return _isHealthy(spoke.getUserAccountData(user).healthFactor);
  }

  function _isHealthy(uint256 healthFactor) internal pure returns (bool) {
    return healthFactor >= Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
  }

  function _calculateExpectedUserRP(ISpoke spoke, address user) internal view returns (uint256) {
    return _calculateExpectedUserRP(spoke, user, false);
  }

  function _calculateExpectedUserRP(
    ISpoke spoke,
    address user,
    bool refreshDynamicConfig
  ) internal view returns (uint256) {
    CalculateRiskPremiumLocal memory vars;
    vars.reserveCount = spoke.getReserveCount();

    // Find all reserves user has supplied, adding up total debt
    for (uint256 reserveId; reserveId < vars.reserveCount; ++reserveId) {
      // totalDebtValue is scaled by RAY here, downscaled later
      vars.totalDebtValue += _convertAmountToValue(
        spoke,
        reserveId,
        spoke.getUserPosition(reserveId, user).drawnShares * _reserveDrawnIndex(spoke, reserveId) +
          _calculatePremiumDebtRay(spoke, reserveId, user)
      );

      if (_isUsingAsCollateral(spoke, reserveId, user)) {
        vars.dynamicConfigKey = refreshDynamicConfig
          ? spoke.getReserve(reserveId).dynamicConfigKey
          : spoke.getUserPosition(reserveId, user).dynamicConfigKey;
        vars.collateralFactor = spoke
          .getDynamicReserveConfig(reserveId, vars.dynamicConfigKey)
          .collateralFactor;

        vars.collateralValue = _convertAmountToValue(
          spoke,
          reserveId,
          spoke.getUserSuppliedAssets(reserveId, user)
        );
        vars.healthFactor += (vars.collateralValue * vars.collateralFactor);
        ++vars.activeCollateralCount;
      }
    }

    if (vars.totalDebtValue == 0) {
      return 0;
    }

    vars.totalDebtValue = vars.totalDebtValue.fromRayUp();

    // Gather up list of reserves as collateral to sort by collateral risk
    KeyValueList.List memory reserveCollateralRisk = KeyValueList.init(vars.activeCollateralCount);
    for (uint256 reserveId; reserveId < vars.reserveCount; ++reserveId) {
      if (_isUsingAsCollateral(spoke, reserveId, user)) {
        reserveCollateralRisk.add(vars.idx, _getCollateralRisk(spoke, reserveId), reserveId);
        ++vars.idx;
      }
    }

    // Sort supplied reserves by collateral risk
    reserveCollateralRisk.sortByKey();
    vars.idx = 0;

    // While user's normalized debt amount is non-zero, iterate through supplied reserves, and add up collateral risk
    while (vars.totalDebtValue > 0 && vars.idx < reserveCollateralRisk.length()) {
      (uint256 collateralRisk, uint256 reserveId) = reserveCollateralRisk.get(vars.idx);
      vars.collateralValue = _convertAmountToValue(
        spoke,
        reserveId,
        spoke.getUserSuppliedAssets(reserveId, user)
      );

      if (vars.collateralValue >= vars.totalDebtValue) {
        vars.riskPremium += vars.totalDebtValue * collateralRisk;
        vars.utilizedSupply += vars.totalDebtValue;
        vars.totalDebtValue = 0;
        break;
      } else {
        vars.riskPremium += vars.collateralValue * collateralRisk;
        vars.utilizedSupply += vars.collateralValue;
        vars.totalDebtValue -= vars.collateralValue;
      }

      ++vars.idx;
    }

    return _divUp(vars.riskPremium, vars.utilizedSupply);
  }

  function _getSpokeDynConfigKeys(
    ISpoke spoke
  ) internal view returns (DynamicConfigEntry[] memory) {
    uint256 reserveCount = spoke.getReserveCount();
    DynamicConfigEntry[] memory configs = new DynamicConfigEntry[](reserveCount);
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      configs[reserveId] = DynamicConfigEntry(spoke.getReserve(reserveId).dynamicConfigKey, true);
    }
    return configs;
  }

  // returns reserveId => User(DynamicConfigKey, usingAsCollateral) map.
  function _getUserDynConfigKeys(
    ISpoke spoke,
    address user
  ) internal view returns (DynamicConfigEntry[] memory) {
    uint256 reserveCount = spoke.getReserveCount();
    DynamicConfigEntry[] memory configs = new DynamicConfigEntry[](reserveCount);
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      configs[reserveId] = _getUserDynConfigKeys(spoke, user, reserveId);
    }
    return configs;
  }

  function _getUserDynConfig(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (ISpoke.DynamicReserveConfig memory) {
    return
      spoke.getDynamicReserveConfig(
        reserveId,
        spoke.getUserPosition(reserveId, user).dynamicConfigKey
      );
  }

  // deref and return current UserDynamicReserveConfig for a specific reserveId on user position.
  function _getUserDynConfigKeys(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (DynamicConfigEntry memory) {
    ISpoke.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    return DynamicConfigEntry(pos.dynamicConfigKey, _isUsingAsCollateral(spoke, reserveId, user));
  }

  function _randomReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(0, spoke.getReserveCount() - 1);
  }

  function _randomInvalidReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(spoke.getReserveCount(), UINT256_MAX);
  }

  function _randomConfigKey() internal returns (uint16) {
    return vm.randomUint(0, type(uint16).max).toUint16();
  }

  function _randomSpoke(IHub hub, uint256 assetId) internal returns (ISpoke) {
    uint256 spokeCount = hub.getSpokeCount(assetId);
    uint256 spokeIndex = vm.randomUint(0, spokeCount - 1);
    return ISpoke(hub.getSpokeAddress(assetId, spokeIndex));
  }

  function _reserveId(ISpoke spoke, uint256 assetId) internal view returns (uint256) {
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      if (spoke.getReserve(id).assetId == assetId) {
        return id;
      }
    }
    revert('not found');
  }

  function _nextDynamicConfigKey(ISpoke spoke, uint256 reserveId) internal view returns (uint32) {
    uint32 dynamicConfigKey = spoke.getReserve(reserveId).dynamicConfigKey;
    return (dynamicConfigKey + 1) % type(uint32).max;
  }

  function _randomUninitializedConfigKey(
    ISpoke spoke,
    uint256 reserveId
  ) internal returns (uint32) {
    uint32 dynamicConfigKey = _nextDynamicConfigKey(spoke, reserveId);
    if (spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey).maxLiquidationBonus != 0) {
      revert('no uninitialized config keys');
    }
    return vm.randomUint(dynamicConfigKey, type(uint32).max).toUint32();
  }

  function _randomInitializedConfigKey(ISpoke spoke, uint256 reserveId) internal returns (uint32) {
    uint32 dynamicConfigKey = _nextDynamicConfigKey(spoke, reserveId);
    if (spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey).maxLiquidationBonus != 0) {
      // all config keys are initialized
      return vm.randomUint(0, type(uint32).max).toUint32();
    }
    return vm.randomUint(0, spoke.getReserve(reserveId).dynamicConfigKey).toUint32();
  }

  function _maxLiquidationBonusUpperBound(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint32) {
    return
      _maxLiquidationBonusUpperBound(
        _getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor
      ).toUint32();
  }

  function _maxLiquidationBonusUpperBound(
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return
      collateralFactor == 0
        ? MIN_LIQUIDATION_BONUS
        : (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(collateralFactor).toUint32();
  }

  function _randomMaxLiquidationBonus(ISpoke spoke, uint256 reserveId) internal returns (uint32) {
    return
      vm
        .randomUint(MIN_LIQUIDATION_BONUS, _maxLiquidationBonusUpperBound(spoke, reserveId))
        .toUint32();
  }

  function _collateralFactorUpperBound(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint16) {
    return
      _collateralFactorUpperBound(
        _getLatestDynamicReserveConfig(spoke, reserveId).maxLiquidationBonus
      );
  }

  function _collateralFactorUpperBound(uint256 maxLiquidationBonus) internal pure returns (uint16) {
    return (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(maxLiquidationBonus).toUint16();
  }

  function _randomCollateralFactor(ISpoke spoke, uint256 reserveId) internal returns (uint16) {
    return vm.randomUint(10_00, _collateralFactorUpperBound(spoke, reserveId)).toUint16();
  }

  /// @dev Returns the id of the reserve corresponding to the given Liquidity Hub asset id
  function getReserveIdByAssetId(
    ISpoke spoke,
    IHub hub,
    uint256 assetId
  ) internal view returns (uint256) {
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
      if (address(hub) == address(reserve.hub) && assetId == reserve.assetId) {
        return reserveId;
      }
    }
    revert('not found');
  }

  /// @dev Borrow to be at a certain health factor
  function _borrowToBeAtHf(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 desiredHf
  ) internal returns (uint256, uint256) {
    uint256 requiredDebtAmount = _getRequiredDebtAmountForHf(spoke, user, reserveId, desiredHf);
    require(
      0 < requiredDebtAmount && requiredDebtAmount <= MAX_SUPPLY_AMOUNT,
      'required debt amount 0 or too high'
    );

    _borrowWithoutHfCheck(spoke, user, reserveId, requiredDebtAmount);

    uint256 finalHf = _getUserHealthFactor(spoke, user);
    assertApproxEqAbs(finalHf, desiredHf, 0.001e18);

    return (finalHf, requiredDebtAmount);
  }

  /// @dev Borrow to become liquidatable due to price change of asset.
  /// @param pricePercentage The resultant percentage of the original price of the asset, represented as a bps value. For example, 85_00 represents a 15% decrease in price.
  /// @return userAccountData The user account data after borrowing (prior to price change).
  function _borrowToBeLiquidatableWithPriceChange(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 collateralReserveId,
    uint256 desiredHf,
    uint256 pricePercentage
  ) internal returns (ISpoke.UserAccountData memory) {
    uint256 requiredDebtAmount = _getRequiredDebtAmountForHf(spoke, user, reserveId, desiredHf);
    require(requiredDebtAmount <= MAX_SUPPLY_AMOUNT, 'required debt amount too high');
    Utils.borrow(spoke, reserveId, user, requiredDebtAmount, user);
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    _mockReservePriceByPercent(spoke, collateralReserveId, pricePercentage);
    assertLt(_getUserHealthFactor(spoke, user), Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    return userAccountData;
  }

  /// @dev Helper function to borrow without health factor check
  function _borrowWithoutHfCheck(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 debtAmount
  ) internal {
    address mockSpoke = address(
      new MockSpoke(spoke.ORACLE(), Constants.MAX_ALLOWED_USER_RESERVES_LIMIT)
    );

    address implementation = _getImplementationAddress(address(spoke));

    vm.prank(_getProxyAdminAddress(address(spoke)));
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(address(mockSpoke), '');

    vm.prank(user);
    MockSpoke(address(spoke)).borrowWithoutHfCheck(reserveId, debtAmount, user);

    vm.prank(_getProxyAdminAddress(address(spoke)));
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(implementation, '');
  }

  function _getReserveIds(ISpoke spoke) internal view returns (ReserveIds memory) {
    return
      ReserveIds({
        dai: _daiReserveId(spoke),
        weth: _wethReserveId(spoke),
        usdx: _usdxReserveId(spoke),
        wbtc: _wbtcReserveId(spoke)
      });
  }

  /// @dev Helper to etch spoke's implementation with a new maxUserReservesLimit
  function _updateMaxUserReservesLimit(ISpoke spoke, uint16 newLimit) internal {
    address currentImpl = _getImplementationAddress(address(spoke));
    ISpokeInstance newImpl = DeployUtils.deploySpokeImplementation(spoke.ORACLE(), newLimit);
    vm.etch(currentImpl, address(newImpl).code);
  }
}
