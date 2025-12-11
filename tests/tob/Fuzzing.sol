pragma solidity 0.8.28;
pragma experimental ABIEncoderV2;

import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Spoke} from 'src/spoke/Spoke.sol';

import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {FuzzingBase} from 'tests/tob/FuzzingBase.sol';

contract FuzzingTob is FuzzingBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  // This won't work if the fuzzer will be able to add new assets
  uint256 constant assetCount = 3;
  mapping(uint256 => uint256) asset_previous_exchange_rate;
  mapping(uint256 => uint256) asset_previous_drawn_index;

  mapping(address spoke => mapping(uint256 user_index => ISpoke.UserAccountData)) user_previous_account_data;
  mapping(address spoke => mapping(uint256 user_index => mapping(uint256 reserve_id => ISpoke.UserPosition))) user_previous_position;

  constructor() FuzzingBase() {}

  //modifier check_global_invariants(uint256 spokeId, uint256 reserveId, uint256 amount) {
  modifier check_global_invariants() {
    _before_check_global_invariants();
    _;
    _after_check_global_invariants();
  }

  function _before_check_global_invariants() internal {
    for (uint256 i = 0; i < spokes.length; i++) {
      address spoke = address(spokes[i]);
      for (uint256 u = 0; u < USERS.length; u++) {
        address user = USERS[u];
        ISpoke.UserAccountData memory userAccountData = ISpoke(spoke).getUserAccountData(user);
        user_previous_account_data[spoke][u] = userAccountData;
        for (uint256 r = 0; r < ISpoke(spoke).getReserveCount(); r++) {
          ISpoke.UserPosition memory userPosition = ISpoke(spoke).getUserPosition(r, user);
          user_previous_position[spoke][u][r] = userPosition;
        }
      }
    }
  }

  function _after_check_global_invariants() internal {
    // the array position corresponds to the asset id
    uint256[assetCount] memory total_added_shares_sum_spoke;
    uint256[assetCount] memory total_deficit_sum_spoke;

    for (uint256 i = 0; i < spokes_with_feeReceiver.length; i++) {
      address spoke = spokes_with_feeReceiver[i];
      // We don't want to check the user position in the fee receiver spoke
      if (i != spokes_with_feeReceiver.length - 1) {
        for (uint256 u = 0; u < USERS.length; u++) {
          address user = USERS[u];
          ISpoke.UserAccountData memory userAccountData = ISpoke(spoke).getUserAccountData(user);
          if (userAccountData.totalCollateralValue == 0) {
            assertEq(
              userAccountData.totalDebtValue,
              0,
              'AAVE-GINV-10 user has no collateral but has debt'
            );
          }
          for (uint256 r = 0; r < Spoke(spoke).getReserveCount(); r++) {
            ISpoke.UserPosition memory userPosition = ISpoke(spoke).getUserPosition(r, user);
            if (user_previous_account_data[spoke][u].healthFactor < uint256(1e18)) {
              // It can decrease when repaying
              assertGte(
                user_previous_position[spoke][u][r].drawnShares,
                userPosition.drawnShares,
                'AAVE-GINV-11 user cannot borrow more when unhealthy'
              );
            }
          }
        }
      }

      for (uint256 j = 0; j < assetCount; j++) {
        uint256 spoke_added_shares = hub1.getSpokeAddedShares(j, spoke);
        total_added_shares_sum_spoke[j] += spoke_added_shares;
        total_deficit_sum_spoke[j] += hub1.getSpokeDeficitRay(j, spoke);
        if (hub1.getSpokeAddedAssets(j, spoke) > 0) {
          assertNeq(
            hub1.getSpokeDrawnShares(j, spoke) + spoke_added_shares,
            0,
            'AAVE-GINV-9 spoke cannot have added assets != 0 with drawn + added shares = 0'
          );
        }
      }
    }

    for (uint256 i = 0; i < assetCount; i++) {
      IHub.Asset memory asset = hub1.getAsset(i);
      uint256 asset_added_shares = hub1.getAddedShares(i);
      assertEq(
        total_added_shares_sum_spoke[i],
        asset_added_shares,
        'AAVE-GINV-2 total added shares should be equal to spokes added shares'
      );
      assertGte(
        IERC20(asset.underlying).balanceOf(address(hub1)),
        asset.liquidity - asset.swept,
        'AAVE-GINV-3 underlying balance should be greater than or equal to asset liquidity - asset swept'
      );
      assertNeq(
        uint256(uint160(asset.irStrategy)),
        0,
        'AAVE-GINV-4 asset irStrategy should not be 0'
      );
      assertGte(
        hub1.previewRestoreByShares(i, asset.premiumShares).toRay(),
        asset.premiumOffsetRay.toUint256(),
        'AAVE-GINV-5 asset premium shares should be greater than or equal to asset premium offset'
      );
      assertEq(
        total_deficit_sum_spoke[i],
        asset.deficitRay,
        'AAVE-GINV-6 total deficit should be equal to asset deficit'
      );
      // Note consider virtual assets and shares
      uint256 new_exchange_rate = (hub1.getAddedAssets(i) + 1e6) / (asset_added_shares + 1e6);
      assertGte(
        new_exchange_rate,
        asset_previous_exchange_rate[i],
        'AAVE-GINV-7 exchange rate should be greater than or equal to previous exchange rate'
      );
      asset_previous_exchange_rate[i] = new_exchange_rate;
      uint256 new_drawn_index = hub1.getAssetDrawnIndex(i);
      assertGte(
        new_drawn_index,
        asset_previous_drawn_index[i],
        'AAVE-GINV-8 drawn index should be greater than or equal to previous drawn index'
      );
      asset_previous_drawn_index[i] = new_drawn_index;
    }
  }

  function supply_must_succeed(
    uint256 spokeId,
    uint256 reserveId,
    uint256 amount
  ) external check_global_invariants {
    ISpoke spoke = spokes[clampBetween(spokeId, 0, spokes.length - 1)];
    reserveId = spokeInfo[spoke].reserveIds[
      clampBetween(reserveId, 0, spokeInfo[spoke].reserveIds.length - 1)
    ];
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    IHub hub = IHub(address(reserve.hub));
    // Assume addCap is unlimited
    amount = clampBetween(amount, hub.previewAddByShares(reserve.assetId, 1), 10 ** 30);

    // For now we set every asset supplied as collateral
    vm.prank(msg.sender);
    spoke.setUsingAsCollateral(reserveId, true, msg.sender);

    TestnetERC20(reserve.underlying).mint(msg.sender, amount);
    vm.prank(msg.sender);
    TestnetERC20(reserve.underlying).approve(address(spoke), amount);
    uint256 oldUserShares = spoke.getUserSuppliedShares(reserveId, msg.sender);
    uint256 oldHubUnderlyingBalance = TestnetERC20(reserve.underlying).balanceOf(address(hub));
    uint256 oldUserUnderlyingBalance = TestnetERC20(reserve.underlying).balanceOf(msg.sender);
    IHub.Asset memory oldAsset = hub.getAsset(reserve.assetId);
    IHub.SpokeData memory oldSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
    uint256 unrealizedFeeShares = hub.getSpokeAddedShares(reserve.assetId, oldAsset.feeReceiver) -
      hub.getSpoke(reserve.assetId, oldAsset.feeReceiver).addedShares;
    vm.prank(msg.sender);

    try spoke.supply(reserveId, amount, msg.sender) returns (uint256 shares, uint256 amount_) {
      assertGt(shares, 0, 'AAVE-INV-1 shares supplied should be greater than 0');
      assertGt(amount_, 0, 'AAVE-INV-2 amount supplied should be greater than 0');
      assertEq(
        spoke.getUserSuppliedShares(reserveId, msg.sender),
        oldUserShares + shares,
        'AAVE-INV-4 user shares should be equal to old user shares plus shares supplied'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(address(hub)),
        oldHubUnderlyingBalance + amount_,
        'AAVE-INV-5 hub underlying balance should be equal to old hub underlying balance plus amount supplied'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(msg.sender),
        oldUserUnderlyingBalance - amount_,
        'AAVE-INV-6 user underlying balance should be equal to old user underlying balance minus amount supplied'
      );
      IHub.Asset memory newAsset = hub.getAsset(reserve.assetId);
      assertEq(
        newAsset.liquidity,
        oldAsset.liquidity + amount_,
        'AAVE-INV-7 asset liquidity should be equal to old asset liquidity plus amount supplied'
      );
      assertEq(
        newAsset.addedShares - unrealizedFeeShares,
        oldAsset.addedShares + shares,
        'AAVE-INV-8 asset added shares should be equal to old asset added shares plus shares supplied'
      );
      IHub.SpokeData memory newSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
      assertEq(
        newSpokeData.addedShares,
        oldSpokeData.addedShares + shares,
        'AAVE-INV-9 spoke added shares should be equal to old spoke added shares plus shares supplied'
      );
    } catch (bytes memory data) {
      // Note we assume addCap is unlimited and all the reserves are active
      emit LogString('AAVE-INV-3: supply must succeed if the preconditions are met');
      emit LogBytes(data);
      assert(false);
    }
  }

  function withdraw_must_succeed(
    uint256 spokeId,
    uint256 reserveId,
    uint256 amount
  ) external check_global_invariants {
    ISpoke spoke = spokes[clampBetween(spokeId, 0, spokes.length - 1)];
    reserveId = spokeInfo[spoke].reserveIds[
      clampBetween(reserveId, 0, spokeInfo[spoke].reserveIds.length - 1)
    ];
    uint256 oldUserShares = spoke.getUserSuppliedShares(reserveId, msg.sender);
    require(oldUserShares > 0);
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    IHub hub = IHub(address(reserve.hub));

    ISpoke.UserAccountData memory oldAccountData = spoke.getUserAccountData(msg.sender);
    {
      uint256 maxAmount = oldAccountData
        .totalCollateralValue
        .percentMulDown(oldAccountData.avgCollateralFactor / 1e14)
        .percentMulDown(99_00) - oldAccountData.totalDebtValue;
      maxAmount = _convertValueToAmount(
        spoke,
        reserveId,
        maxAmount,
        TestnetERC20(reserve.underlying).decimals()
      );
      amount = clampBetween(amount, 1, maxAmount);
    }

    OldBalances memory oldBalances;
    oldBalances.hubUnderlying = TestnetERC20(reserve.underlying).balanceOf(address(hub));
    oldBalances.userUnderlying = TestnetERC20(reserve.underlying).balanceOf(msg.sender);
    IHub.Asset memory oldAsset = hub.getAsset(reserve.assetId);
    require(oldAsset.liquidity >= amount);
    IHub.SpokeData memory oldSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
    uint256 unrealizedFeeShares = hub.getSpokeAddedShares(reserve.assetId, oldAsset.feeReceiver) -
      hub.getSpoke(reserve.assetId, oldAsset.feeReceiver).addedShares;
    vm.prank(msg.sender);

    try spoke.withdraw(reserveId, amount, msg.sender) returns (uint256 shares, uint256 amount_) {
      assertGt(shares, 0, 'AAVE-INV-10 shares withdrawn should be greater than 0');
      assertGt(amount_, 0, 'AAVE-INV-11 amount withdrawn should be greater than 0');
      assertEq(
        spoke.getUserSuppliedShares(reserveId, msg.sender),
        oldUserShares - shares,
        'AAVE-INV-12 user shares should be equal to old user shares minus shares withdrew'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(address(hub)),
        oldBalances.hubUnderlying - amount_,
        'AAVE-INV-13 hub underlying balance should be equal to old hub underlying balance minus amount withdrew'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(msg.sender),
        oldBalances.userUnderlying + amount_,
        'AAVE-INV-14 user underlying balance should be equal to old user underlying balance plus amount withdrew'
      );
      IHub.Asset memory newAsset = hub.getAsset(reserve.assetId);
      assertEq(
        newAsset.liquidity,
        oldAsset.liquidity - amount_,
        'AAVE-INV-15 asset liquidity should be equal to old asset liquidity minus amount withdrew'
      );
      // @note we remove the unrealizedFeeShares to account for the accrued interest
      assertEq(
        newAsset.addedShares - unrealizedFeeShares,
        oldAsset.addedShares - shares,
        'AAVE-INV-16 asset added shares should be equal to old asset added shares minus shares withdrew'
      );
      IHub.SpokeData memory newSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
      assertEq(
        newSpokeData.addedShares,
        oldSpokeData.addedShares - shares,
        'AAVE-INV-17 spoke added shares should be equal to old spoke added shares minus shares withdrew'
      );
      ISpoke.UserAccountData memory newAccountData = spoke.getUserAccountData(msg.sender);
      emit HFF(
        newAccountData.healthFactor,
        newAccountData.totalCollateralValue,
        newAccountData.totalDebtValue,
        newAccountData.avgCollateralFactor,
        newAccountData.riskPremium
      );
      assertGte(
        oldAccountData.healthFactor,
        newAccountData.healthFactor,
        'AAVE-INV-18 user health factor does not increase when withdrawing'
      );
      assertGte(
        newAccountData.healthFactor,
        uint256(1e18),
        'AAVE-INV-19 user health factor does not go below HEALTH_FACTOR_LIQUIDATION_THRESHOLD when withdrawing'
      );
    } catch (bytes memory data) {
      // Note we assume addCap is unlimited and all the reserves are active
      emit LogString('AAVE-INV-20: withdraw must succeed if the preconditions are met');
      emit LogBytes(data);
    }
  }
  event HFF(
    uint256 healthFactor,
    uint256 totalCollateralValue,
    uint256 totalDebtValue,
    uint256 avgCollateralFactor,
    uint256 riskPremium
  );

  function borrow_must_succeed(
    uint256 spokeId,
    uint256 reserveId,
    uint256 amount
  ) external check_global_invariants {
    ISpoke spoke = spokes[clampBetween(spokeId, 0, spokes.length - 1)];
    ISpoke.UserAccountData memory oldAccountData = spoke.getUserAccountData(msg.sender);
    require(oldAccountData.totalCollateralValue > 0);
    reserveId = spokeInfo[spoke].reserveIds[
      clampBetween(reserveId, 0, spokeInfo[spoke].reserveIds.length - 1)
    ];
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    uint256 maxAmount = oldAccountData
      .totalCollateralValue
      .percentMulDown(oldAccountData.avgCollateralFactor / 1e14)
      .percentMulDown(99_00) - oldAccountData.totalDebtValue;
    maxAmount = _convertValueToAmount(
      spoke,
      reserveId,
      maxAmount,
      TestnetERC20(reserve.underlying).decimals()
    );
    amount = clampBetween(amount, 1, maxAmount);

    IHub hub = IHub(address(reserve.hub));

    OldBalances memory oldBalances;
    oldBalances.hubUnderlying = TestnetERC20(reserve.underlying).balanceOf(address(hub));
    oldBalances.userUnderlying = TestnetERC20(reserve.underlying).balanceOf(msg.sender);
    IHub.Asset memory oldAsset = hub.getAsset(reserve.assetId);
    require(oldAsset.liquidity >= amount);
    IHub.SpokeData memory oldSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
    ISpoke.UserPosition memory oldUserPosition = spoke.getUserPosition(reserveId, msg.sender);
    vm.prank(msg.sender);

    try spoke.borrow(reserveId, amount, msg.sender) returns (uint256 shares, uint256 amount_) {
      assertGt(shares, 0, 'AAVE-INV-21 shares borrowed should be greater than 0');
      assertGt(amount_, 0, 'AAVE-INV-22 amount borrowed should be greater than 0');
      assertEq(
        spoke.getUserPosition(reserveId, msg.sender).drawnShares,
        oldUserPosition.drawnShares + shares,
        'AAVE-INV-23 user drawn shares should be equal to old user drawn shares + drawn shares'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(address(hub)),
        oldBalances.hubUnderlying - amount_,
        'AAVE-INV-24 hub underlying balance should be equal to old hub underlying balance minus amount borrowed'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(msg.sender),
        oldBalances.userUnderlying + amount_,
        'AAVE-INV-25 user underlying balance should be equal to old user underlying balance plus amount borrowed'
      );
      IHub.Asset memory newAsset = hub.getAsset(reserve.assetId);
      assertEq(
        newAsset.liquidity,
        oldAsset.liquidity - amount_,
        'AAVE-INV-26 asset liquidity should be equal to old asset liquidity minus amount borrowed'
      );
      assertEq(
        newAsset.drawnShares,
        oldAsset.drawnShares + shares,
        'AAVE-INV-27 asset drawn shares should be equal to old asset drawn shares plus shares borrowed'
      );
      IHub.SpokeData memory newSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
      assertEq(
        newSpokeData.drawnShares,
        oldSpokeData.drawnShares + shares,
        'AAVE-INV-28 spoke drawn shares should be equal to old spoke drawn shares plus shares borrowed'
      );
      ISpoke.UserAccountData memory newAccountData = spoke.getUserAccountData(msg.sender);
      emit HFF(
        newAccountData.healthFactor,
        newAccountData.totalCollateralValue,
        newAccountData.totalDebtValue,
        newAccountData.avgCollateralFactor,
        newAccountData.riskPremium
      );
      assertGte(
        oldAccountData.healthFactor,
        newAccountData.healthFactor,
        'AAVE-INV-29 user health factor does not increase when borrowing'
      );
      assertGte(
        newAccountData.healthFactor,
        uint256(1e18),
        'AAVE-INV-30 user health factor does not go below HEALTH_FACTOR_LIQUIDATION_THRESHOLD when borrowing'
      );
    } catch (bytes memory data) {
      // Note we assume drawCap is unlimited and all the reserves are active
      emit LogString('AAVE-INV-31: borrow must succeed if the preconditions are met');
      emit LogBytes(data);
    }
  }

  function repay_must_succeed(
    uint256 spokeId,
    uint256 reserveId,
    uint256 amount
  ) external check_global_invariants {
    ISpoke spoke = spokes[clampBetween(spokeId, 0, spokes.length - 1)];
    ISpoke.UserAccountData memory oldAccountData = spoke.getUserAccountData(msg.sender);
    reserveId = spokeInfo[spoke].reserveIds[
      clampBetween(reserveId, 0, spokeInfo[spoke].reserveIds.length - 1)
    ];
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    (, , uint256 restoreAmount) = _calculateExactRestoreAmount(
      spoke,
      reserveId,
      msg.sender,
      amount,
      reserve.assetId
    );
    IHub hub = IHub(address(reserve.hub));

    TestnetERC20(reserve.underlying).mint(msg.sender, restoreAmount);
    vm.prank(msg.sender);
    TestnetERC20(reserve.underlying).approve(address(spoke), restoreAmount);

    OldBalances memory oldBalances;
    oldBalances.hubUnderlying = TestnetERC20(reserve.underlying).balanceOf(address(hub));
    oldBalances.userUnderlying = TestnetERC20(reserve.underlying).balanceOf(msg.sender);
    IHub.Asset memory oldAsset = hub.getAsset(reserve.assetId);
    IHub.SpokeData memory oldSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
    ISpoke.UserPosition memory oldUserPosition = spoke.getUserPosition(reserveId, msg.sender);
    vm.prank(msg.sender);

    try spoke.repay(reserveId, restoreAmount, msg.sender) returns (
      uint256 restoredShares,
      uint256 restoredAmount
    ) {
      assertGt(restoredAmount, 0, 'AAVE-INV-33 amount restored should be greater than 0');
      assertEq(
        spoke.getUserPosition(reserveId, msg.sender).drawnShares,
        oldUserPosition.drawnShares - restoredShares,
        'AAVE-INV-34 user drawn shares should be equal to old user drawn shares - restored shares'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(address(hub)),
        oldBalances.hubUnderlying + restoredAmount,
        'AAVE-INV-35 hub underlying balance should be equal to old hub underlying balance plus amount restored'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(msg.sender),
        oldBalances.userUnderlying - restoredAmount,
        'AAVE-INV-36 user underlying balance should be equal to old user underlying balance minus amount restored'
      );
      IHub.Asset memory newAsset = hub.getAsset(reserve.assetId);
      assertEq(
        newAsset.liquidity,
        oldAsset.liquidity + restoredAmount,
        'AAVE-INV-37 asset liquidity should be equal to old asset liquidity plus amount restored'
      );
      assertEq(
        newAsset.drawnShares,
        oldAsset.drawnShares - restoredShares,
        'AAVE-INV-38 asset drawn shares should be equal to old asset drawn shares minus restored shares'
      );
      IHub.SpokeData memory newSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
      assertEq(
        newSpokeData.drawnShares,
        oldSpokeData.drawnShares - restoredShares,
        'AAVE-INV-39 spoke drawn shares should be equal to old spoke drawn shares minus restored shares'
      );
      ISpoke.UserAccountData memory newAccountData = spoke.getUserAccountData(msg.sender);
      assertLte(
        oldAccountData.healthFactor,
        newAccountData.healthFactor,
        'AAVE-INV-40 user health factor does not decrease when repaying'
      );
    } catch (bytes memory data) {
      // Note we assume drawCap is unlimited and all the reserves are active
      emit LogString('AAVE-INV-41: repay must succeed if the preconditions are met');
      emit LogBytes(data);
      assert(false);
    }
  }
}
