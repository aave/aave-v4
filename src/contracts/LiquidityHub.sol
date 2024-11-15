// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {IPriceOracle} from './IPriceOracle.sol';
import {WadRayMath} from './WadRayMath.sol';
import {SharesMath} from './SharesMath.sol';
import {MathUtils} from './MathUtils.sol';
import {IBorrowModule} from '../interfaces/IBorrowModule.sol';
import {ILiquidityHub} from '../interfaces/ILiquidityHub.sol';

import 'forge-std/console2.sol';

contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;

  event Supply(uint256 indexed reserve, address indexed spoke, uint256 amount);

  event Withdraw(
    uint256 indexed reserve,
    address indexed spoke,
    address indexed to,
    uint256 amount
  );

  event Draw(uint256 indexed reserve, address indexed to, uint256 amount);

  event Restore(uint256 indexed reserve, address indexed spoke, uint256 amount);

  struct SpokeConfig {
    uint256 drawCap;
    uint256 drawnLiquidity;
  }

  struct Reserve {
    uint256 id;
    uint256 totalShares;
    uint256 totalAssets;
    uint256 totalDrawn;
    uint256 lastUpdateTimestamp;
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 decimals;
    bool active; // TODO: frozen, paused
    uint256 supplyCap;
    address irStrategy;
  }

  // asset id => reserve data
  mapping(uint256 => Reserve) public reserves;
  address[] public reservesList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public reserveCount;

  // asset id => spoke address => spoke config
  mapping(uint256 => mapping(address => SpokeConfig)) public spokeReserveConfigs;

  // asset id => weighted average risk premium of asset
  mapping(uint256 => uint256) public weightedAverageRiskPremium;

  function getReserve(uint256 assetId) external view returns (Reserve memory) {
    return reserves[assetId];
  }

  // TODO: convert all user-related functions to draw modules
  function getSpokeReserveConfig(
    uint256 assetId,
    address spoke
  ) external view returns (SpokeConfig memory) {
    return spokeReserveConfigs[assetId][spoke];
  }

  function getSpokeBalance(uint256 assetId, address spoke) external view returns (uint256) {
    SpokeConfig memory s = spokeReserveConfigs[assetId][spoke];

    return s.shares.toAssetsDown(reserves[assetId].totalAssets, reserves[assetId].totalShares);
  }

  // /////
  // Governance
  // /////

  function addReserve(ReserveConfig memory params, address asset) external {
    // TODO: AccessControl
    reservesList.push(asset);
    reserves[reserveCount] = Reserve({
      id: reserveCount,
      totalShares: 0,
      totalAssets: 0,
      totalDrawn: 0,
      lastUpdateTimestamp: block.timestamp,
      config: ReserveConfig({
        decimals: params.decimals,
        active: params.active,
        supplyCap: params.supplyCap
      })
    });
    reserveCount++;
  }

  function updateReserve(uint256 assetId, ReserveConfig memory params) external {
    // TODO: More sophisticated
    // TODO: AccessControl
    reserves[assetId].config = ReserveConfig({
      decimals: params.decimals,
      active: params.active,
      supplyCap: params.supplyCap
    });
  }

  function updateSpokeConfig(uint256 assetId, address spoke, uint256 drawCap) external {
    // TODO: AccessControl
    spokeReserveConfigs[assetId][spoke].drawCap = drawCap;
  }

  // /////
  // Users
  // /////

  function supply(uint256 assetId, uint256 amount, uint256 riskPremium) external {
    Reserve storage reserve = reserves[assetId];
    SpokeConfig storage spoke = spokeReserveConfigs[assetId][msg.sender];

    _validateSupply(reserve, amount);

    // update indexes and IRs
    _updateState(reserve, riskPremium); // TODO
    // TODO: init user lastUpdateIndex
    // TODO Set as collateral if first supply?

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onSupply( assetData, amount);
    // TODO Mitigate inflation attack (burn some amount if first supply)

    uint256 sharesAmount = amount.toSharesDown(reserve.totalAssets, reserve.totalShares);
    // console2.log(
    //   'supply sharesAmount %e, %e, %e',
    //   sharesAmount,
    //   reserve.totalAssets,
    //   reserve.totalShares
    // );
    require(sharesAmount > 0, 'INVALID_AMOUNT');
    reserve.totalShares += sharesAmount;
    reserve.totalAssets += amount;

    // TODO: update avgRiskPremium if collateral
    _updateRiskPremium();

    // transferFrom
    IERC20(reservesList[assetId]).safeTransferFrom(msg.sender, address(this), amount); // TODO: fee-on-transfer

    emit Supply(assetId, msg.sender, amount);
  }

  function withdraw(uint256 assetId, address to, uint256 amount, uint256 riskPremium) external {
    Reserve storage reserve = reserves[assetId];
    SpokeConfig storage spoke = spokeReserveConfigs[assetId][msg.sender];

    // asset can be withdrawn
    _validateWithdraw(reserve, amount);

    // TODO HF check

    // update indexes and IRs
    _updateState(reserve, riskPremium);

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onWithdraw( assetData, amount);

    uint256 sharesAmount = amount.toSharesUp(reserve.totalAssets, reserve.totalShares);
    reserve.totalShares -= sharesAmount;
    reserve.totalAssets -= amount;

    // TODO: update avgRiskPremium if collateral
    _updateRiskPremium();

    // transfer
    IERC20(reservesList[assetId]).safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);
  }

  // TODO: authorization - only borrow module
  function draw(uint256 assetId, address to, uint256 amount, uint256 riskPremium) external {
    Reserve storage reserve = reserves[assetId];

    _validateDrawLiquidity(reserve, amount);

    // update indexes and IRs
    _updateState(reserve, riskPremium);

    // TODO: update avgRiskPremium if collateral
    _updateRiskPremium();

    // updates accounting
    reserve.totalDrawn += amount;

    // directly transfer funds to bm so that allowance doesn't need to be reset
    IERC20(reservesList[assetId]).safeTransfer(to, amount);

    emit Draw(assetId, to, amount);
  }

  function restore(uint256 assetId, uint256 amount, uint256 riskPremium) external {
    Reserve storage reserve = reserves[assetId];

    _validateRestore(reserve, amount);

    _updateState(reserve, riskPremium);

    _updateRiskPremium();

    reserve.totalDrawn -= amount;

    IERC20(reservesList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

    emit Restore(assetId, msg.sender, amount);
  }

  //
  // Internal
  //
  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    // asset is listed
    require(reservesList[reserve.id] != address(0), 'ASSET_NOT_LISTED');
    // asset can be supplied
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');
    // supply cap not reached
    require(
      reserve.config.supplyCap == type(uint256).max ||
        reserve.totalAssets + amount <= reserve.config.supplyCap,
      'CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Other cases of status (frozen, paused)
    // asset can be withdrawn
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');
    // reserve with available liquidity
    require(amount <= reserve.totalAssets - reserve.totalDrawn, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateDrawLiquidity(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Other cases of status (frozen, paused)
    // asset can be borrowed
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');
    // draw cap not reached
    require(
      reserve.config.drawCap == type(uint256).max ||
        amount + reserve.totalDrawn <= reserve.config.drawCap,
      'CAP_EXCEEDED'
    );
    // Check enough liquidity (amount < liquidity)
    require(amount <= reserve.totalAssets - reserve.totalDrawn, 'INVALID_AMOUNT');
  }

  function _validateRestore(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Other cases of status (frozen, paused)
    // asset can be borrowed
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');

    // Sanity check, already checked in spoke
    require(amount <= reserve.totalDrawn, 'INVALID_AMOUNT');
  }

  function _updateState(Reserve storage reserve, uint256 riskPremium) internal {
    // Update interest rates
    uint256 borrowRate = IBorrowModule(reserve.config.borrowModule).getInterestRate(reserve.id); // TODO: coupling here, must be more abstract?
    // TODO: only borrowRate? supplyRate can be calculated using borrowRate and RF
    // borrow module and liquidity hub coupling

    // Update indexes
    _accrueReserveInterest(reserve, borrowRate); // TODO rate accruing is actually less than borrowRate
    // TODO borrowIndex
    // _accrueReserveInterest(reserve.borrowIndex, reserve.borrowRate, elapsed);
    // Accrue RF?
  }

  function _accrueReserveInterest(Reserve storage r, uint256 borrowRate) internal {
    uint256 elapsed = block.timestamp - r.lastUpdateTimestamp;
    if (elapsed > 0) {
      console2.log('_accrueReserveInterest');
      // linear interest
      uint256 cumulated = r.totalDrawn.rayMul(
        MathUtils.calculateLinearInterest(borrowRate, uint40(r.lastUpdateTimestamp))
      ); // TODO rounding
      console2.log(
        'cumulated: %e, drawn: %e, cumulatedInterest: %e',
        cumulated,
        r.totalDrawn,
        (cumulated - r.totalDrawn)
      );
      r.totalAssets += (cumulated - r.totalDrawn); // add delta, ie cumulated interest to totalAssets
      r.totalDrawn = cumulated;

      // TODO: fee shares
      r.lastUpdateTimestamp = block.timestamp;
    }
  }

  function _updateRiskPremium(address user) internal {
    uint256 wAvg;
    uint256 sumW;

    uint256 wData; // data weight * data value
    // data weight = price * amount
    // data value = liquidityPremium
    for (uint256 assetId = 0; assetId < reservesList.length; assetId++) {
      // TODO: if collateral enabled
      wData = _getUserAssets(assetId, user) * IPriceOracle(oracle).getAssetPrice(assetId);
      sumW += wData;

      wData = wData * reserves[assetId].config.liquidityPremium; // bps
      wAvg += wData;
    }
    if (sumW != 0) wAvg /= sumW;

    userRiskPremium[user] = wAvg;
  }
}
