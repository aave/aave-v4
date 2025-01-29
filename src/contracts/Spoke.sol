// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IReserveInterestRateStrategy} from 'src/interfaces/IReserveInterestRateStrategy.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract Spoke is ISpoke {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeERC20 for IERC20;

  ILiquidityHub public liquidityHub;

  struct Reserve {
    uint256 id;
    address asset;
    // uint256 totalDebt;
    // uint256 lastUpdateIndex;
    // uint256 lastUpdateTimestamp;
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 lt; // 1e4 == 100%, BPS
    uint256 lb; // TODO: liquidationProtocolFee
    bool borrowable;
    bool collateral;
  }

  struct UserConfig {
    uint256 supplyShares;
    uint256 debt;
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

  // reserve id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;
  // reserve id => reserveData
  mapping(uint256 => Reserve) public reserves;
  uint256[] public reservesList; // assetIds
  uint256 public reserveCount;
  address public oracle;

  constructor(address liquidityHubAddress, address oracleAddress) {
    liquidityHub = ILiquidityHub(liquidityHubAddress);
    oracle = oracleAddress;
  }

  function getUserDebt(uint256 assetId, address user) external view returns (uint256) {
    UserConfig memory u = users[assetId][user];
    // TODO: Instead use a getter from liquidity hub to get up-to-date user debt (with accrued debt)
    return
      u.debt.rayMul(
        MathUtils.calculateCompoundedInterest(getInterestRate(assetId), uint40(0), block.timestamp)
      );
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
    (, uint256 userShares) = liquidityHub.supply(
      assetId,
      amount,
      newAggregatedRiskPremium,
      msg.sender // supplier
    );

    users[assetId][msg.sender].supplyShares += userShares;

    emit Supplied(assetId, msg.sender, amount);
  }

  function withdraw(uint256 assetId, address to, uint256 amount) external {
    Reserve storage r = reserves[assetId];
    UserConfig storage u = users[assetId][msg.sender];
    _validateWithdraw(assetId, r, u, amount);

    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    uint256 userShares = liquidityHub.withdraw(assetId, amount, newAggregatedRiskPremium, to);
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
    uint256 userDebt = liquidityHub.draw(assetId, amount, newAggregatedRiskPremium, to);
    // debt still goes to original msg.sender
    users[assetId][msg.sender].debt += userDebt;

    emit Borrowed(assetId, to, amount);
  }

  function repay(uint256 assetId, uint256 amount) external {
    // TODO: Implement repay, calls liquidity hub restore method
    // TODO: onBehalfOf

    UserConfig storage u = users[assetId][msg.sender];
    Reserve storage r = reserves[assetId];
    _validateRepay(assetId, u, amount);

    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    // TODO: Spoke should calculate the amountFromPremium and amountFromBase
    uint256 repaidDebt = liquidityHub.restore(
      assetId,
      amount,
      newAggregatedRiskPremium,
      msg.sender // repayer
    );
    users[assetId][msg.sender].debt -= repaidDebt;

    emit Repaid(assetId, msg.sender, amount);
  }

  function getUserRiskPremium(address user) external view returns (uint256) {
    (, , , uint256 userRiskPremium, ) = _calculateUserAccountData(user);
    return userRiskPremium;
  }

  function getHealthFactor(address user) external view returns (uint256) {
    (, , , , uint256 healthFactor) = _calculateUserAccountData(user);
    return healthFactor;
  }

  function setUsingAsCollateral(uint256 assetId, bool usingAsCollateral) external {
    _validateSetUsingAsCollateral(assetId, msg.sender);
    users[assetId][msg.sender].usingAsCollateral = usingAsCollateral;

    emit UsingAsCollateral(assetId, msg.sender, usingAsCollateral);
  }

  // TODO: Needed?
  function getInterestRate(uint256 assetId) public view returns (uint256) {
    // read from state, convert to ray
    // TODO: should be final IR rather than base?
    return ILiquidityHub(liquidityHub).getBaseInterestRate(assetId);
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
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
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
      liquidityHub.convertToAssetsDown(assetId, user.supplyShares) >= amount,
      'INSUFFICIENT_SUPPLY'
    );
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
    // TODO: validation on HF to allow borrowing amount
  }

  function _validateRepay(uint256 assetId, UserConfig storage user, uint256 amount) internal view {
    require(amount <= user.debt, 'REPAY_EXCEEDS_DEBT');
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
    return users[assetId][user].debt > 0;
  }

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
          liquidityHub.convertToAssetsDown(
            vars.assetId,
            _calculateAccruedInterest(vars.assetId, u.supplyShares)
          );
        vars.liquidityPremium = 1; // TODO: get LP from LH
        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        vars.avgLiquidationThreshold += vars.userCollateralInBaseCurrency * r.config.lt;
        vars.userRiskPremium += vars.userCollateralInBaseCurrency * vars.liquidityPremium;
      }

      vars.totalDebtInBaseCurrency += u.debt > 0
        ? vars.assetPrice * _calculateAccruedInterest(vars.assetId, u.debt)
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
    uint256 debt
  ) internal view returns (uint256) {
    // TODO: use lastUpdatedTimestamp in interest math, make sure total debt includes accrued interest
    return
      debt.rayMul(
        MathUtils.calculateCompoundedInterest(getInterestRate(assetId), uint40(0), block.timestamp)
      );
  }
}
