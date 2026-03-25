// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ITransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {DeployUtils} from 'tests/helpers/deploy/DeployUtils.sol';
import {ISpokeInstance} from 'tests/helpers/mocks/ISpokeInstance.sol';
import {MockSpoke} from 'tests/helpers/mocks/MockSpoke.sol';
import {SpokeActions} from 'tests/helpers/spoke/SpokeActions.sol';
import {CheckedActions} from 'tests/helpers/spoke/CheckedActions.sol';
import {ConfigHelpers} from 'tests/helpers/spoke/ConfigHelpers.sol';
import {MockHelpers} from 'tests/helpers/spoke/MockHelpers.sol';
/// @title SetupHelpers
/// @notice Spoke-level state-mutating test setup utilities.
abstract contract SetupHelpers is CheckedActions, ConfigHelpers, MockHelpers {
  using SafeCast for *;
  using WadRayMath for *;
  using PercentageMath for uint256;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  ACTIONS HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Opens a supply position for a random user
  function _openSupplyPosition(ISpoke spoke, uint256 reserveId, uint256 amount) public {
    _increaseCollateralSupply(spoke, reserveId, amount, _makeUser());
  }

  /// @dev Increases the collateral supply for a user
  function _increaseCollateralSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    address user
  ) public {
    uint256 assetId = _reserveAssetId(spoke, reserveId);
    IHub hub = _hub(spoke, reserveId);
    uint256 initialLiq = hub.getAssetLiquidity(assetId);

    _deal(spoke, reserveId, user, amount);
    SpokeActions.approve({spoke: spoke, reserveId: reserveId, owner: user, amount: UINT256_MAX});

    _checkedSupplyCollateral(
      CheckedSupplyCollateralParams({
        spoke: spoke,
        reserveId: reserveId,
        user: user,
        amount: amount,
        onBehalfOf: user
      })
    );

    assertEq(hub.getAssetLiquidity(assetId), initialLiq + amount);
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
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: reserveId,
      caller: user,
      amount: amount,
      onBehalfOf: user
    });
  }

  /// @dev Opens a debt position for a random user, using same asset as collateral and borrow
  function _openDebtPosition(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    bool withPremium,
    address spokeAdmin
  ) internal returns (address) {
    address tempUser = _makeUser();

    // add collateral
    uint256 supplyAmount = _calcMinimumCollAmount({
      spoke: spoke,
      collReserveId: reserveId,
      debtReserveId: reserveId,
      debtAmount: amount
    });

    _deal(spoke, reserveId, tempUser, supplyAmount);
    SpokeActions.approve({
      spoke: spoke,
      reserveId: reserveId,
      owner: tempUser,
      amount: UINT256_MAX
    });

    SpokeActions.supplyCollateral({
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
      _updateCollateralRisk(spoke, reserveId, 50_00, spokeAdmin);
    }

    SpokeActions.borrow({
      spoke: spoke,
      reserveId: reserveId,
      caller: tempUser,
      amount: amount,
      onBehalfOf: tempUser
    });
    skip(365 days);

    (uint256 drawnDebt, uint256 premiumDebt) = spoke.getReserveDebt(reserveId);
    assertGt(drawnDebt, 0); // non-zero drawn debt

    if (withPremium) {
      assertGt(premiumDebt, 0);
      // restore cached collateral risk
      _updateCollateralRisk(spoke, reserveId, cachedCollateralRisk, spokeAdmin);
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
    uint256 supplyAmount = _calcMinimumCollAmount({
      spoke: spoke,
      collReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      debtAmount: borrowAmount
    }) * 5;
    _deal(spoke, collateralReserveId, user, supplyAmount);
    SpokeActions.approve({
      spoke: spoke,
      reserveId: collateralReserveId,
      owner: user,
      amount: UINT256_MAX
    });
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: collateralReserveId,
      caller: user,
      amount: supplyAmount,
      onBehalfOf: user
    });
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: debtReserveId,
      caller: user,
      amount: borrowAmount,
      onBehalfOf: user
    });
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
    assertApproxEqRel(
      finalHf,
      desiredHf,
      0.01e18, // 1%
      'final health factor should be close to desired health factor'
    );

    return (finalHf, requiredDebtAmount);
  }

  /// @dev Borrow to become liquidatable due to price change of asset.
  function _borrowToBeLiquidatableWithPriceChange(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 collateralReserveId,
    uint256 desiredHf,
    uint256 pricePercentage,
    address spokeAdmin
  ) internal returns (ISpoke.UserAccountData memory) {
    uint256 requiredDebtAmount = _getRequiredDebtAmountForHf(spoke, user, reserveId, desiredHf);
    require(requiredDebtAmount <= MAX_SUPPLY_AMOUNT, 'required debt amount too high');
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: reserveId,
      caller: user,
      amount: requiredDebtAmount,
      onBehalfOf: user
    });
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    _mockReservePriceByPercent(spoke, collateralReserveId, pricePercentage, spokeAdmin);
    assertLt(_getUserHealthFactor(spoke, user), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    return userAccountData;
  }

  /// @dev Helper function to borrow without health factor check
  function _borrowWithoutHfCheck(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 debtAmount
  ) internal {
    address mockSpoke = address(new MockSpoke(spoke.ORACLE(), MAX_ALLOWED_USER_RESERVES_LIMIT));

    address implementation = _getImplementationAddress(address(spoke));

    vm.prank(_getProxyAdminAddress(address(spoke)));
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(address(mockSpoke), '');

    vm.prank(user);
    MockSpoke(address(spoke)).borrowWithoutHfCheck(reserveId, debtAmount, user);

    vm.prank(_getProxyAdminAddress(address(spoke)));
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(implementation, '');
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
    uint256 skipTime,
    address irStrategy
  ) internal returns (uint256, uint256) {
    if (isMockRate) {
      _mockDrawnRateBps(irStrategy, rate);
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
      borrowResult.ownerAfter.drawnDebt - borrowResult.ownerBefore.drawnDebt,
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

  function _repayAll(ISpoke spoke, uint256 reserveId, address[] memory users) internal {
    IHub hub = _hub(spoke, reserveId);
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 assetOwedWithoutSpoke = hub.getAssetTotalOwed(assetId) -
      hub.getSpokeTotalOwed(assetId, address(spoke));

    for (uint256 i; i < users.length; ++i) {
      address user = users[i];
      uint256 debt = spoke.getUserTotalDebt(reserveId, user);
      if (debt > 0) {
        deal(hub.getAsset(assetId).underlying, user, debt);
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
    assertEq(hub.getSpokeTotalOwed(assetId, address(spoke)), 0, 'hub spoke total debt not zero');
    assertEq(
      hub.getAssetTotalOwed(assetId),
      assetOwedWithoutSpoke,
      'hub asset total debt not settled'
    );
  }

  // increase share conversion index on given reserve
  /// @return supply amount of collateral asset
  /// @return supply shares of collateral asset
  /// @return borrow amount of borrowed asset
  /// @return supply shares of borrowed asset
  /// @return supply amount of borrowed asset
  function _increaseReserveIndex(
    ISpoke spoke,
    uint256 reserveId,
    uint256 collateralReserveId,
    address collateralSupplier,
    address borrowSupplier
  ) internal returns (uint256, uint256, uint256, uint256, uint256) {
    SupplyBorrowLocal memory state;

    ReserveSetupParams memory collateral;
    collateral.reserveId = collateralReserveId;
    collateral.supplyAmount = 1_000e18;
    collateral.supplier = collateralSupplier;

    ReserveSetupParams memory borrow;
    borrow.reserveId = reserveId;
    borrow.supplier = borrowSupplier;
    borrow.borrower = collateralSupplier;
    borrow.supplyAmount = 100e18;
    borrow.borrowAmount = borrow.supplyAmount / 2;

    IHub hub = _hub(spoke, borrow.reserveId);
    (state.borrowReserveAssetId, ) = _getAssetByReserveId(spoke, borrow.reserveId);
    (state.collateralSupplyShares, state.borrowSupplyShares) = _executeSpokeSupplyAndBorrow({
      spoke: spoke,
      collateral: collateral,
      borrow: borrow,
      rate: 0,
      isMockRate: false,
      skipTime: 365 days,
      irStrategy: address(0)
    });

    // index has increased, ie now the shares are less than the amount
    assertGt(
      borrow.supplyAmount,
      hub.previewAddByAssets(state.borrowReserveAssetId, borrow.supplyAmount)
    );

    return (
      collateral.supplyAmount,
      state.collateralSupplyShares,
      borrow.borrowAmount,
      state.borrowSupplyShares,
      borrow.supplyAmount
    );
  }

  /// @dev Helper to etch spoke's implementation with a new maxUserReservesLimit
  function _updateMaxUserReservesLimit(ISpoke spoke, uint16 newLimit) internal {
    address currentImpl = _getImplementationAddress(address(spoke));
    ISpokeInstance newImpl = DeployUtils.deploySpokeImplementation(spoke.ORACLE(), newLimit);
    vm.etch(currentImpl, address(newImpl).code);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  DEPLOYMENT HELPERS                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _deploySpokeWithOracle(
    address proxyAdminOwner,
    address _accessManager
  ) internal pausePrank returns (ISpoke, IAaveOracle) {
    return _deploySpokeWithOracle(proxyAdminOwner, _accessManager, MAX_ALLOWED_USER_RESERVES_LIMIT);
  }

  function _deploySpokeWithOracle(
    address proxyAdminOwner,
    address _accessManager,
    uint16 maxUserReservesLimit
  ) internal pausePrank returns (ISpoke, IAaveOracle) {
    address deployer = makeAddr('deployer');

    vm.startPrank(deployer);
    IAaveOracle oracle = new AaveOracle(8);

    ISpoke spoke = DeployUtils.deploySpoke(
      address(oracle),
      maxUserReservesLimit,
      proxyAdminOwner,
      abi.encodeCall(ISpokeInstance.initialize, (_accessManager))
    );

    oracle.setSpoke(address(spoke));
    vm.stopPrank();

    assertEq(spoke.ORACLE(), address(oracle));
    assertEq(oracle.spoke(), address(spoke));

    return (spoke, oracle);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                        TOKEN HELPERS                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _deal(ISpoke spoke, uint256 reserveId, address user, uint256 amount) internal {
    IERC20 underlying = _getAssetUnderlyingByReserveId(spoke, reserveId);
    if (underlying.balanceOf(user) < amount) {
      deal(address(underlying), user, amount);
    }
  }

  function _approveAllUnderlying(ISpoke spoke, address owner, address spender) internal {
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      address underlying_ = spoke.getReserve(reserveId).underlying;
      vm.prank(owner);
      IERC20(underlying_).approve(spender, UINT256_MAX);
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  RANDOM UTILITIES                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _randomReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(0, spoke.getReserveCount() - 1);
  }

  function _randomInvalidReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(spoke.getReserveCount(), UINT256_MAX);
  }

  function _randomConfigKey() internal returns (uint16) {
    return vm.randomUint(0, type(uint16).max).toUint16();
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

  function _randomMaxLiquidationBonus(ISpoke spoke, uint256 reserveId) internal returns (uint32) {
    return
      vm
        .randomUint(MIN_LIQUIDATION_BONUS, _maxLiquidationBonusUpperBound(spoke, reserveId))
        .toUint32();
  }

  function _randomCollateralFactor(ISpoke spoke, uint256 reserveId) internal returns (uint16) {
    return vm.randomUint(10_00, _collateralFactorUpperBound(spoke, reserveId)).toUint16();
  }
}
