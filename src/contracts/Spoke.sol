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

  struct ReserveConfig {
    uint256 lt; // 1e4 == 100%, BPS
    uint256 lb; // BPS, 1e4 is 0% bonus, 1.1e4 is 10% bonus
    uint256 lpfp; // liquidation protocol fee percentage, BPS.
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

  // TODO: removed unneeded fields
  struct LiquidationCallLocalVars {
    uint256 actualDebtToCover;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationProtocolFeeAmount;
    uint256 userCollateralBalance;
    uint256 userDebtBalance;
    uint256 userCollateralBalanceInBaseCurrency;
    uint256 userDebtBalanceInBaseCurrency;
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
  address public RESERVE_TREASURY_ADDRESS = address(1); // TODO: implement this properly

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
    _executeLiquidationCall(collateralAssetId, debtAssetId, user, debtToCover);
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

  function updateReserveConfig(uint256 assetId, ReserveConfig calldata params) external {
    // TODO: AccessControl
    // TODO: validation on lb >= 1e4?
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      lpfp: params.lpfp,
      borrowable: params.borrowable,
      collateral: params.collateral
    });

    emit ReserveConfigUpdated(assetId, params.lt, params.lb, params.borrowable, params.collateral);
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

  // TODO: Needed?
  function getUserDebtInAssets(uint256 assetId, address user) public view returns (uint256) {
    return
      ILiquidityHub(liquidityHub).convertSharesToAssetsUp(
        assetId,
        getUserDebtInShares(assetId, user)
      );
  }

  // TODO: Needed?
  function getUserDebtInShares(uint256 assetId, address user) public view returns (uint256) {
    UserConfig memory u = users[assetId][user];
    // TODO: Instead use a getter from liquidity hub to get up-to-date user debt (with accrued debt)
    return _calculateAccruedInterest(assetId, u.debtShares);
  }

  // TODO: Needed?
  function getUserSupplyInAssets(uint256 assetId, address user) public view returns (uint256) {
    return
      ILiquidityHub(liquidityHub).convertSharesToAssetsDown(
        assetId,
        getUserSupplyInShares(assetId, user)
      );
  }

  // TODO: Needed?
  function getUserSupplyInShares(uint256 assetId, address user) public view returns (uint256) {
    UserConfig memory u = users[assetId][user];
    return _calculateAccruedInterest(assetId, u.supplyShares);
  }

  // TODO: Update when user config is finalized
  function setUsingAsCollateral(uint256 assetId, bool usingAsCollateral) public {
    _setUsingAsCollateral(msg.sender, assetId, usingAsCollateral);
  }

  // TODO: Update when reserve config is finalized
  function getLiquidationThreshold(uint256 assetId) public view returns (uint256) {
    return reserves[assetId].config.lt;
  }

  // TODO: Update when reserve config is finalized
  function getLiquidationProtocolFeePercentage(uint256 assetId) public view returns (uint256) {
    return reserves[assetId].config.lpfp;
  }

  // TODO: Update when reserve config is finalized
  function getLiquidationBonus(uint256 assetId) public view returns (uint256) {
    return reserves[assetId].config.lb;
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
          getUserSupplyInAssets(vars.assetId, user);
        vars.liquidityPremium = 1; // TODO: get LP from LH
        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        vars.avgLiquidationThreshold += vars.userCollateralInBaseCurrency * r.config.lt;
        vars.userRiskPremium += vars.userCollateralInBaseCurrency * vars.liquidityPremium;
      }

      vars.totalDebtInBaseCurrency += u.debtShares > 0
        ? vars.assetPrice * getUserDebtInAssets(vars.assetId, user)
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

    // console2.log('vars.totalCollateralInBaseCurrency %e', vars.totalCollateralInBaseCurrency);
    // console2.log('vars.totalDebtInBaseCurrency %e', vars.totalDebtInBaseCurrency);
    // console2.log('vars.avgLiquidationThreshold %e', vars.avgLiquidationThreshold);
    // console2.log('vars.userRiskPremium %e', vars.userRiskPremium);

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

  /**
  @param debtToCover amount of debt to cover in base currency, in WAD. 1e18 == $1
  */
  function _executeLiquidationCall(
    uint256 collateralAssetId,
    uint256 debtAssetId,
    address user,
    uint256 debtToCover
  ) internal {
    // v1 - allow the liquidator to liquidate full position if HF goes below certain threshold
    // v2 enhancement - allow liquidator to liquidate only the amount needed to bring HF to 1

    console2.log('----- liq -----');

    require(debtToCover > 0, 'INVALID_DEBT_TO_COVER');

    LiquidationCallLocalVars memory vars;
    Reserve memory collateralReserve = reserves[collateralAssetId];
    Reserve memory debtReserve = reserves[debtAssetId];

    // TODO: accrue interest first? / updateState
    (, vars.userDebtBalanceInBaseCurrency, , , vars.healthFactor) = _calculateUserAccountData(user);

    // console2.log('vars.healthFactor %e', vars.healthFactor);

    vars.actualDebtToLiquidate = _calculateDebt(
      debtToCover,
      vars.userDebtBalanceInBaseCurrency,
      vars.healthFactor
    );

    _validateLiquidationCall(collateralAssetId, debtAssetId, user, vars.healthFactor);

    // console2.log('collateral amt: %e', getUserSupplyInAsset(collateralAssetId, user));

    vars.userCollateralBalance = getUserSupplyInAssets(collateralAssetId, user);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = _calculateAvailableCollateralToLiquidate(
      collateralReserve,
      debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      collateralReserve.config.lb
    );

    console2.log('vars.userCollateralBalance %e', vars.userCollateralBalance);
    console2.log(
      'vars.actualCollateralToLiquidate %e %e shares',
      vars.actualCollateralToLiquidate,
      getUserSupplyInShares(collateralAssetId, user)
    );
    console2.log('vars.actualDebtToLiquidate %e', vars.actualDebtToLiquidate);
    console2.log('vars.liquidationProtocolFeeAmount %e', vars.liquidationProtocolFeeAmount);

    console2.log('total debt %e', vars.userDebtBalance);

    if (
      vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount ==
      vars.userCollateralBalance
    ) {
      _setUsingAsCollateral(user, collateralReserve.id, false);
    }

    // console2.log('vars.actualCollateralToLiquidate %e', vars.actualCollateralToLiquidate);
    // console2.log('vars.actualDebtToLiquidate %e', vars.actualDebtToLiquidate);

    // IERC20(reservesList[debtAssetId]).safeTransferFrom(
    //   msg.sender,
    //   liquidityHub,
    //   vars.actualDebtToLiquidate
    // );

    // risk premium needs to be updated bc collateral/debt has been updated
    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    // repay debt
    IERC20(debtReserve.asset).safeTransferFrom(
      msg.sender,
      liquidityHub,
      vars.actualDebtToLiquidate
    );
    uint256 userDebtShares = ILiquidityHub(liquidityHub).restore(
      debtAssetId,
      vars.actualDebtToLiquidate,
      newAggregatedRiskPremium
    );

    // risk premium needs to be updated bc collateral/debt has been updated
    (, newAggregatedRiskPremium) = _refreshRiskPremium();
    // liquidate collateral
    uint256 userCollateralShares = ILiquidityHub(liquidityHub).withdraw(
      collateralAssetId,
      address(this),
      vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount,
      newAggregatedRiskPremium
    );

    // accounting
    users[collateralAssetId][user].supplyShares -= userCollateralShares;
    users[debtAssetId][user].debtShares -= userDebtShares;

    // transfer assets
    IERC20(collateralReserve.asset).safeTransfer(msg.sender, vars.actualCollateralToLiquidate);
    if (vars.liquidationProtocolFeeAmount > 0) {
      IERC20(collateralReserve.asset).safeTransfer(
        RESERVE_TREASURY_ADDRESS,
        vars.liquidationProtocolFeeAmount
      );
    }

    emit LiquidationCall(
      collateralAssetId,
      debtAssetId,
      user,
      vars.actualDebtToLiquidate,
      vars.actualCollateralToLiquidate,
      msg.sender
    );
  }

  function _validateLiquidationCall(
    uint256 collateralAssetId,
    uint256 debtAssetId,
    address user,
    uint256 healthFactor
  ) internal view {
    // TODO: checks on reserve inactive, paused?
    // TODO: isLiquidationAllowed?
    // TODO: grace period?

    bool isCollateralEnabled = _usingAsCollateral(collateralAssetId, user) &&
      getLiquidationThreshold(collateralAssetId) != 0;

    require(
      healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'HEALTH_FACTOR_NOT_BELOW_THRESHOLD'
    );
    require(isCollateralEnabled, 'COLLATERAL_CANNOT_BE_LIQUIDATED');
    require(getUserDebtInShares(debtAssetId, user) > 0, 'SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER');
  }

  /**
   * @notice Calculates the total debt of the user and the actual amount to liquidate depending on the health factor.
   * @param debtToCover The desired amount of debt to cover in base currency
   * @param userDebtBalanceInBaseCurrency The total debt of the user in base currency
   * @param healthFactor The health factor of the user
   * @return The actual debt that can be liquidated in base currency
   */
  function _calculateDebt(
    uint256 debtToCover,
    uint256 userDebtBalanceInBaseCurrency,
    uint256 healthFactor
  ) internal view returns (uint256) {
    // TODO: calculate maxLiquidatableDebt, find amount needed to restore HF to 1
    // for now, it is equal to the total debt of the liquidated user
    uint256 maxLiquidatableDebtInBaseCurrency = userDebtBalanceInBaseCurrency;

    uint256 actualDebtToLiquidateInBaseCurrency = debtToCover > maxLiquidatableDebtInBaseCurrency
      ? maxLiquidatableDebtInBaseCurrency
      : debtToCover;

    return actualDebtToLiquidateInBaseCurrency;
  }

  /**
   * @return The maximum collateral amount that is possible to liquidate given all the liquidation constraints (liquidation bonus, liquidationProtocolFeePercentage)
   * @return The amount to repay with the liquidation
   * @return The fee taken from the liquidation bonus amount to be paid to the protocol
   */
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

    // console2.log('vars.collateralAssetPrice %e', vars.collateralAssetPrice);
    // console2.log('vars.debtAssetPrice %e', vars.debtAssetPrice);
    // console2.log('userCollateralBalance %e', userCollateralBalance);

    vars.liquidationProtocolFeePercentage = getLiquidationProtocolFeePercentage(
      collateralReserve.id
    );

    // find collateral amount that corresponds to the debt to cover
    vars.baseCollateral =
      (vars.debtAssetPrice * debtToCover * vars.collateralAssetUnit) /
      (vars.collateralAssetPrice * vars.debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(liquidationBonus);

    // TODO: enhancement, calculate critical threshold value of collateral to liquidate to end up with HF == 1
    // instead of userCollateralBalance being max collateral to liquidate, it should be the critical threshold value
    if (vars.maxCollateralToLiquidate > userCollateralBalance) {
      console2.log('maxCollateralToLiquidate > userCollateralBalance');
      // back calculate debt amount needed to cover the max allowed collateral
      vars.collateralAmount = userCollateralBalance;
      vars.debtAmountNeeded = ((vars.collateralAssetPrice *
        vars.collateralAmount *
        vars.debtAssetUnit) / (vars.debtAssetPrice * vars.collateralAssetUnit)).percentDiv(
          liquidationBonus
        );
    } else {
      console2.log('maxCollateralToLiquidate <= userCollateralBalance');
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

  function _setUsingAsCollateral(address user, uint256 assetId, bool usingAsCollateral) internal {
    _validateSetUsingAsCollateral(assetId, user);
    users[assetId][user].usingAsCollateral = usingAsCollateral;

    emit UsingAsCollateral(assetId, user, usingAsCollateral);
  }
}
