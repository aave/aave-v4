// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ERC20} from 'src/dependencies/openzeppelin/ERC20.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IReserveInterestRateStrategy} from 'src/interfaces/IReserveInterestRateStrategy.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import 'forge-std/console2.sol';

contract Spoke is ISpoke {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeERC20 for IERC20;

  address public liquidityHub;

  struct Reserve {
    uint256 id;
    address asset;
    uint8 decimals;
    // uint256 totalDebt;
    // uint256 lastUpdateIndex;
    // uint256 lastUpdateTimestamp;
    ReserveConfig config;
  }

  // TODO: liquidation bonus
  struct ReserveConfig {
    uint256 lt; // 1e4 == 100%, BPS
    uint256 lb; // 1e4 == 100%, BPS
    uint256 lpfp; // liquidation protocol fee percentage, BPS
    bool borrowable;
    bool collateral;
  }

  struct UserConfig {
    uint256 supplyShares;
    uint256 debtShares;
    bool usingAsCollateral;
    // uint256 balance;
    // uint256 lastUpdateIndex;
    // uint256 lastUpdateTimestamp;
  }

  struct CalculateUserAccountDataVars {
    uint256 i;
    uint256 assetId;
    uint256 assetPrice;
    uint256 liquidityPremium;
    uint256 userCollateralInBaseCurrency;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLiquidationThreshold;
    uint256 userRiskPremium;
    uint256 healthFactor;
  }

  struct LiquidationCallLocalVars {
    uint256 actualDebtToCover;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationProtocolFeeAmount;
    uint256 userCollateralBalance;
    uint256 userDebtBalance;
    uint256 healthFactor;
    uint256 maxDebtToCover;
  }

  struct AvailableCollateralToLiquidateLocalVars {
    uint256 collateralAssetPrice;
    uint256 debtAssetPrice;
    uint256 maxCollateralToLiquidate;
    uint256 baseCollateral;
    uint256 bonusCollateral;
    uint256 debtAssetDecimals;
    uint256 collateralDecimals;
    uint256 collateralAssetUnit;
    uint256 debtAssetUnit;
    uint256 collateralAmount;
    uint256 debtAmountNeeded;
    uint256 liquidationProtocolFeePercentage;
    uint256 liquidationProtocolFeeAmount;
  }

  // reserve id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;
  // reserve id => reserveData
  mapping(uint256 => Reserve) public reserves;
  uint256[] public reservesList; // assetIds
  uint256 public reserveCount;
  address public oracle;
  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

  constructor(address liquidityHubAddress, address oracleAddress) {
    liquidityHub = liquidityHubAddress;
    oracle = oracleAddress;
  }

  function getReserveDebt(uint256 assetId) external view returns (uint256) {
    Reserve storage r = reserves[assetId];

    // TODO: Instead use a getter from liquidity hub to get up-to-date reserve debt (with accrued debt)
    // return
    //   r.totalDebt.rayMul(
    //     MathUtils.calculateCompoundedInterest(getInterestRate(assetId), uint40(0), block.timestamp)
    //   );
    return 0;
  }

  /// governance
  function updateReserveConfig(uint256 assetId, ReserveConfig calldata params) external {
    // TODO: AccessControl
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      lpfp: params.lpfp,
      borrowable: params.borrowable,
      collateral: params.collateral
    });

    emit ReserveConfigUpdated(assetId, params.lt, params.lb, params.borrowable, params.collateral);
  }

  // /////
  // Users
  // /////

  function supply(uint256 assetId, uint256 amount) external {
    Reserve storage r = reserves[assetId];

    _validateSupply(r, amount);

    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    IERC20(r.asset).safeTransferFrom(msg.sender, liquidityHub, amount);
    uint256 userShares = ILiquidityHub(liquidityHub).supply(
      assetId,
      amount,
      newAggregatedRiskPremium
    );

    users[assetId][msg.sender].supplyShares += userShares;

    emit Supplied(assetId, msg.sender, amount);
  }

  function withdraw(uint256 assetId, address to, uint256 amount) external {
    Reserve storage r = reserves[assetId];
    UserConfig storage u = users[assetId][msg.sender];
    _validateWithdraw(assetId, r, u, amount);

    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    uint256 userShares = ILiquidityHub(liquidityHub).withdraw(
      assetId,
      to,
      amount,
      newAggregatedRiskPremium
    );
    users[assetId][msg.sender].supplyShares -= userShares;

    emit Withdrawn(assetId, msg.sender, amount);
  }

  function borrow(uint256 assetId, address to, uint256 amount) external {
    // TODO: referral code
    // TODO: onBehalfOf with credit delegation
    Reserve storage r = reserves[assetId];
    _validateBorrow(r, amount);

    // TODO HF check
    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    uint256 userShares = ILiquidityHub(liquidityHub).draw(
      assetId,
      to,
      amount,
      newAggregatedRiskPremium
    );
    // debt still goes to original msg.sender
    users[assetId][msg.sender].debtShares += userShares;

    emit Borrowed(assetId, to, amount);
  }

  function repay(uint256 assetId, uint256 amount) external {
    // TODO: Implement repay, calls liquidity hub restore method
    // TODO: onBehalfOf

    UserConfig storage u = users[assetId][msg.sender];
    Reserve storage r = reserves[assetId];
    _validateRepay(assetId, u, amount);

    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    IERC20(r.asset).safeTransferFrom(msg.sender, liquidityHub, amount);
    uint256 userShares = ILiquidityHub(liquidityHub).restore(
      assetId,
      amount,
      newAggregatedRiskPremium
    );
    users[assetId][msg.sender].debtShares -= userShares;

    emit Repaid(assetId, msg.sender, amount);
  }

  function liquidationCall(
    uint256 collateralAssetId,
    uint256 debtAssetId,
    address user,
    uint256 debtToCover
  ) external {
    _executeLiquidationCall(debtToCover, collateralAssetId, debtAssetId, user);
  }

  function getUserRiskPremium(address user) external view returns (uint256) {
    (, , , uint256 userRiskPremium, ) = _calculateUserAccountData(user);
    return userRiskPremium;
  }

  function getHealthFactor(address user) external view returns (uint256) {
    (, , , , uint256 healthFactor) = _calculateUserAccountData(user);
    return healthFactor;
  }

  // /////
  // Governance
  // /////

  function addReserve(uint256 assetId, ReserveConfig memory params, address asset) external {
    // TODO: validate assetId does not exist already, valid asset
    // require(asset != address(0), 'INVALID_ASSET');
    // require(reserves[assetId].asset == address(0), 'RESERVE_ID_ALREADY_EXISTS');

    // TODO: AccessControl
    // TODO: assigning reserveId as the latest reserveCount
    reservesList.push(assetId);
    reserves[assetId].id = assetId;
    reserves[assetId].asset = asset;
    reserves[assetId].decimals = ERC20(asset).decimals();
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      lpfp: params.lpfp,
      borrowable: params.borrowable,
      collateral: params.collateral
    });
    reserveCount++;

    // emit event
  }

  function updateReserve(uint256 assetId, ReserveConfig memory params) external {
    // TODO: More sophisticated
    require(reserves[assetId].id != 0, 'INVALID_RESERVE');
    // TODO: AccessControl
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      lpfp: params.lpfp,
      borrowable: params.borrowable,
      collateral: params.collateral
    });
  }

  // public
  function getReserve(uint256 assetId) public view returns (Reserve memory) {
    return reserves[assetId];
  }

  function getUser(uint256 assetId, address user) public view returns (UserConfig memory) {
    UserConfig memory u = users[assetId][user];
    return u;
  }

  // TODO: Needed?
  function getInterestRate(uint256 assetId) public view returns (uint256) {
    // read from state, convert to ray
    // TODO: should be final IR rather than base?
    return ILiquidityHub(liquidityHub).getBaseInterestRate(assetId);
  }

  function getUserDebt(uint256 assetId, address user) public view returns (uint256) {
    UserConfig memory u = users[assetId][user];
    // TODO: Instead use a getter from liquidity hub to get up-to-date user debt (with accrued debt)
    return
      u.debtShares.rayMul(
        MathUtils.calculateCompoundedInterest(getInterestRate(assetId), uint40(0), block.timestamp)
      );
  }

  function setUsingAsCollateral(uint256 assetId, bool usingAsCollateral) public {
    _validateSetUsingAsCollateral(assetId, msg.sender);
    users[assetId][msg.sender].usingAsCollateral = usingAsCollateral;

    emit UsingAsCollateral(assetId, msg.sender, usingAsCollateral);
  }

  // internal
  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Decide where supply cap is checked
    require(reserve.asset != address(0), 'RESERVE_NOT_LISTED');
  }

  function _validateWithdraw(
    uint256 assetId,
    Reserve storage reserve,
    UserConfig storage user,
    uint256 amount
  ) internal view {
    require(
      ILiquidityHub(liquidityHub).convertSharesToAssetsDown(assetId, user.supplyShares) >= amount,
      'INSUFFICIENT_SUPPLY'
    );
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
    // TODO: validation on HF to allow borrowing amount
  }

  function _validateRepay(uint256 assetId, UserConfig storage user, uint256 amount) internal view {
    require(
      ILiquidityHub(liquidityHub).convertSharesToAssetsUp(assetId, user.debtShares) >= amount,
      'REPAY_EXCEEDS_DEBT'
    );
  }

  /**
  @return uint256 new risk premium
  @return uint256 new aggregated risk premium
  */
  function _refreshRiskPremium() internal returns (uint256, uint256) {
    // TODO: update state - debt shares

    // TODO: refresh risk premium of user, specific assets user has supplied
    uint256 newUserRiskPremium = 0;
    // TODO: aggregated risk premium, ie loop over all assets and sum up risk premium
    uint256 newAggregatedRiskPremium = 0;
    return (newUserRiskPremium, newAggregatedRiskPremium);
  }

  function _validateSetUsingAsCollateral(uint256 assetId, address user) internal view {
    require(reserves[assetId].config.collateral, 'RESERVE_NOT_COLLATERAL');
    require(users[assetId][user].supplyShares > 0, 'NO_SUPPLY');
  }

  function _usingAsCollateralOrBorrowing(
    uint256 assetId,
    address user
  ) internal view returns (bool) {
    return _usingAsCollateral(assetId, user) || _borrowing(assetId, user);
  }

  function _usingAsCollateral(uint256 assetId, address user) internal view returns (bool) {
    return users[assetId][user].usingAsCollateral;
  }

  function _borrowing(uint256 assetId, address user) internal view returns (bool) {
    return users[assetId][user].debtShares > 0;
  }

  /**
  @return totalCollateralInBaseCurrency
  @return totalDebtInBaseCurrency
  @return avgLiquidationThreshold
  @return userRiskPremium
  @return healthFactor
  */
  function _calculateUserAccountData(
    address user
  ) internal view returns (uint256, uint256, uint256, uint256, uint256) {
    CalculateUserAccountDataVars memory vars;
    uint256 reservesListLength = reservesList.length;
    while (vars.i < reservesListLength) {
      vars.assetId = reservesList[vars.i];
      if (!_usingAsCollateralOrBorrowing(vars.assetId, user)) {
        vars.i++;
        continue;
      }

      UserConfig memory u = getUser(vars.assetId, user);
      Reserve memory r = getReserve(vars.assetId);

      vars.assetPrice = IPriceOracle(oracle).getAssetPrice(vars.assetId);

      if (_usingAsCollateral(vars.assetId, user)) {
        vars.userCollateralInBaseCurrency =
          vars.assetPrice *
          ILiquidityHub(liquidityHub).convertSharesToAssetsDown(
            vars.assetId,
            _calculateAccruedInterest(vars.assetId, u.supplyShares) // TODO: create getUserSupply instead?
          );
        vars.liquidityPremium = 1; // TODO: get LP from LH
        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        vars.avgLiquidationThreshold += vars.userCollateralInBaseCurrency * r.config.lt;
        vars.userRiskPremium += vars.userCollateralInBaseCurrency * vars.liquidityPremium;
      }

      vars.totalDebtInBaseCurrency += u.debtShares > 0
        ? vars.assetPrice *
          ILiquidityHub(liquidityHub).convertSharesToAssetsUp(
            vars.assetId,
            _calculateAccruedInterest(vars.assetId, u.debtShares) // TODO: call getUserDebt instead?
          )
        : 0;

      vars.i++;
    }

    vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency == 0
      ? 0
      : vars.avgLiquidationThreshold / vars.totalCollateralInBaseCurrency;

    vars.userRiskPremium = vars.totalCollateralInBaseCurrency == 0
      ? 0
      : vars.userRiskPremium.wadDiv(vars.totalCollateralInBaseCurrency);

    vars.healthFactor = vars.totalDebtInBaseCurrency == 0
      ? type(uint256).max
      : (vars.totalCollateralInBaseCurrency.percentMul(vars.avgLiquidationThreshold)).wadDiv(
        vars.totalDebtInBaseCurrency
      ); // HF of 1 -> 1e18

    return (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.userRiskPremium,
      vars.healthFactor
    );
  }

  function _calculateAccruedInterest(
    uint256 assetId,
    uint256 shares
  ) internal view returns (uint256) {
    // TODO: use lastUpdatedTimestamp in interest math, make sure total shares includes accrued interest
    return
      shares.rayMul(
        MathUtils.calculateCompoundedInterest(getInterestRate(assetId), uint40(0), block.timestamp)
      );
  }

  function _executeLiquidationCall(
    uint256 debtToCover,
    uint256 collateralAssetId,
    uint256 debtAssetId,
    address user
  ) internal {
    // V3 implementation to liquidate undercollateralized positions to start out with.
    // v1 - allow the liquidator to liquidate up to 50% if HF goes below certain threshold

    require(debtToCover > 0, 'INVALID_DEBT_TO_COVER');

    LiquidationCallLocalVars memory vars;

    Reserve storage collateralReserve = reserves[collateralAssetId];
    Reserve storage debtReserve = reserves[debtAssetId];

    // TODO: accrue interest first?

    (
      vars.userCollateralBalance,
      vars.userDebtBalance,
      ,
      ,
      vars.healthFactor
    ) = _calculateUserAccountData(user);
    _validateLiquidationCall(collateralReserve, user, vars.userDebtBalance, vars.healthFactor); // TODO: involve healthFactor, hardcode 0 for now

    vars.actualDebtToCover = debtToCover > vars.userDebtBalance
      ? vars.userDebtBalance
      : debtToCover;

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = _calculateAvailableCollateralToLiquidate(
      collateralReserve,
      debtReserve,
      vars.actualDebtToCover,
      vars.userCollateralBalance,
      collateralReserve.config.lb
    );

    // TODO: call LH to liquidate
    // - withdraw collateral for user
    // - accounting here to update shares

    if (
      vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount ==
      vars.userCollateralBalance
    ) {
      setUsingAsCollateral(collateralReserve.id, false);
    }

    // IERC20(reservesList[debtAssetId]).safeTransferFrom(
    //   msg.sender,
    //   address(this), // liq hub
    //   vars.actualDebtToLiquidate
    // );

    // emit LiquidationCall(
    //   collateralAssetId,
    //   debtAssetId,
    //   user,
    //   vars.actualDebtToLiquidate, // TODO: actualDebtToLiquidate
    //   vars.actualCollateralToLiquidate, // TODO: liquidatedCollateralAmount
    //   msg.sender
    // );
  }

  function _validateLiquidationCall(
    Reserve memory collateralReserve,
    address user,
    uint256 userDebt,
    uint256 healthFactor
  ) internal view {
    require(userDebt > 0, 'SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER');
    require(
      healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'HEALTH_FACTOR_NOT_BELOW_THRESHOLD'
    );
  }

  function _calculateAvailableCollateralToLiquidate(
    Reserve memory collateralReserve,
    Reserve memory debtReserve,
    uint256 debtToCover,
    uint256 userCollateralBalance,
    uint256 liquidationBonus
  ) internal view returns (uint256, uint256, uint256) {
    AvailableCollateralToLiquidateLocalVars memory vars;

    vars.collateralAssetPrice = IPriceOracle(oracle).getAssetPrice(collateralReserve.id);
    vars.debtAssetPrice = IPriceOracle(oracle).getAssetPrice(debtReserve.id);

    vars.collateralAssetUnit = 10 ** collateralReserve.decimals;
    vars.debtAssetUnit = 10 ** debtReserve.decimals;

    vars.liquidationProtocolFeePercentage = collateralReserve.config.lpfp; // TODO: helper getLiquidationProtocolFee()?

    vars.baseCollateral =
      (vars.debtAssetPrice * debtToCover * vars.collateralAssetUnit) /
      (vars.collateralAssetPrice * vars.debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(liquidationBonus);

    if (vars.maxCollateralToLiquidate > userCollateralBalance) {
      // back calculate debt amount needed to cover the max allowed collateral
      vars.collateralAmount = userCollateralBalance;
      vars.debtAmountNeeded = ((vars.collateralAssetPrice *
        vars.collateralAmount *
        vars.debtAssetUnit) / (vars.debtAssetPrice * vars.collateralAssetUnit)).percentDiv(
          liquidationBonus
        );
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate;
      vars.debtAmountNeeded = debtToCover;
    }

    if (vars.liquidationProtocolFeePercentage != 0) {
      vars.bonusCollateral =
        vars.collateralAmount -
        vars.collateralAmount.percentDiv(liquidationBonus);

      vars.liquidationProtocolFeeAmount = vars.bonusCollateral.percentMul(
        vars.liquidationProtocolFeePercentage
      );

      return (
        vars.collateralAmount - vars.liquidationProtocolFeeAmount,
        vars.debtAmountNeeded,
        vars.liquidationProtocolFeeAmount
      );
    } else {
      return (vars.collateralAmount, vars.debtAmountNeeded, 0);
    }
  }
}
