// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseState} from 'tests/setup/BaseState.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {HubActions} from 'tests/helpers/hub/HubActions.sol';

/// @title BaseHelpers
/// @notice Aggregates hub and spoke helpers and adds cross-layer assertion helpers.
///         Provides convenience overloads that default admin and threshold arguments.
abstract contract BaseHelpers is BaseState {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   RESERVE ID LOOKUPS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _usdxReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdx.reserveId;
  }

  function _usdyReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdy.reserveId;
  }

  function _daiReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }

  function _wethReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].weth.reserveId;
  }

  function _wbtcReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].wbtc.reserveId;
  }

  function _usdzReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdz.reserveId;
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

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   CROSS-LAYER ASSERTIONS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _checkSupplyRateIncreasing(
    uint256 oldRate,
    uint256 newRate,
    string memory label
  ) internal pure {
    assertGe(newRate, oldRate, string.concat('supply rate monotonically increasing ', label));
  }

  function _checkDebtRateConstant(
    uint256 oldRate,
    uint256 newRate,
    string memory label
  ) internal pure {
    assertEq(newRate, oldRate, string.concat('debt rate should be constant ', label));
  }

  function assertEq(SpokePosition memory a, AssetPosition memory b) internal pure {
    assertEq(a.assetId, b.assetId, 'assetId');
    assertEq(a.addedShares, b.addedShares, 'addedShares');
    assertEq(a.addedAmount, b.addedAmount, 'addedAmount');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.drawn, b.drawn, 'drawnDebt');
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffsetRay, b.premiumOffsetRay, 'premiumOffsetRay');
    assertEq(a.premium, b.premium, 'premium');
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                        SETUP HELPERS                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _withdrawLiquidityFees(
    IHub hub,
    uint256 assetId,
    uint256 amount,
    address admin
  ) internal {
    ITreasurySpoke treasurySpoke = ITreasurySpoke(_getFeeReceiver(hub, assetId));
    address treasuryAdmin = Ownable(address(treasurySpoke)).owner();

    HubActions.mintFeeShares({hub: hub, assetId: assetId, caller: admin});
    uint256 fees = hub.getSpokeAddedAssets(assetId, address(treasurySpoke));

    if (amount > fees) {
      amount = fees;
    }
    if (amount == 0) {
      return; // nothing to withdraw
    }
    (address underlying, ) = hub.getAssetUnderlyingAndDecimals(assetId);
    vm.prank(treasuryAdmin);
    treasurySpoke.withdraw(address(hub), underlying, amount);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   SETUP OVERLOADS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _addLiquidity(IHub hub, uint256 assetId, uint256 amount) public {
    _addLiquidity(hub, assetId, amount, HUB_ADMIN, MAX_ALLOWED_COLLATERAL_RISK);
  }

  function _drawLiquidity(IHub hub, uint256 assetId, uint256 amount, bool premium) internal {
    _drawLiquidity(hub, assetId, amount, premium, HUB_ADMIN, MAX_ALLOWED_COLLATERAL_RISK);
  }

  function _drawLiquidityViaTempSpoke(
    IHub hub,
    uint256 assetId,
    uint256 amount,
    bool withPremium,
    bool skipTime
  ) internal {
    _drawLiquidityViaTempSpoke(
      hub,
      assetId,
      amount,
      withPremium,
      skipTime,
      HUB_ADMIN,
      MAX_ALLOWED_COLLATERAL_RISK
    );
  }

  function _mockSupplySharePrice(
    IHub hub,
    uint256 assetId,
    uint256 totalAddedAssets,
    uint256 addedShares,
    address spoke
  ) internal {
    _mockSupplySharePrice(
      hub,
      assetId,
      totalAddedAssets,
      addedShares,
      spoke,
      HUB_ADMIN,
      MAX_ALLOWED_COLLATERAL_RISK
    );
  }

  function _setConstantDrawnRateBps(IHub hub, uint256 assetId, uint32 drawnRateBps) internal {
    _setConstantDrawnRateBps(hub, assetId, drawnRateBps, HUB_ADMIN);
  }

  function _updateLiquidityFee(IHub hub, uint256 assetId, uint256 liquidityFee) internal {
    _updateLiquidityFee(hub, assetId, liquidityFee, HUB_ADMIN);
  }

  function _updateSpokeHalted(IHub hub, uint256 assetId, address spoke, bool halted) internal {
    _updateSpokeHalted(hub, assetId, spoke, halted, HUB_ADMIN);
  }

  function _updateSpokeActive(IHub hub, uint256 assetId, address spoke, bool newActive) internal {
    _updateSpokeActive(hub, assetId, spoke, newActive, HUB_ADMIN);
  }

  function _updateAddCap(IHub hub, uint256 assetId, address spoke, uint40 newAddCap) internal {
    _updateAddCap(hub, assetId, spoke, newAddCap, HUB_ADMIN);
  }

  function _updateDrawCap(IHub hub, uint256 assetId, address spoke, uint40 newDrawCap) internal {
    _updateDrawCap(hub, assetId, spoke, newDrawCap, HUB_ADMIN);
  }

  function _updateAssetReinvestmentController(
    IHub hub,
    uint256 assetId,
    address newReinvestmentController
  ) internal {
    _updateAssetReinvestmentController(hub, assetId, newReinvestmentController, HUB_ADMIN);
  }

  function _updateSpokeRiskPremiumThreshold(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint24 newRiskPremiumThreshold
  ) internal {
    _updateSpokeRiskPremiumThreshold(hub, assetId, spoke, newRiskPremiumThreshold, HUB_ADMIN);
  }

  function _grantDeficitEliminatorRole(IHub hub, address target) internal {
    _grantDeficitEliminatorRole(hub, target, ADMIN);
  }

  function _openDebtPosition(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    bool withPremium
  ) internal returns (address) {
    return _openDebtPosition(spoke, reserveId, amount, withPremium, SPOKE_ADMIN);
  }

  function _borrowToBeLiquidatableWithPriceChange(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 collateralReserveId,
    uint256 desiredHf,
    uint256 pricePercentage
  ) internal returns (ISpoke.UserAccountData memory) {
    return
      _borrowToBeLiquidatableWithPriceChange(
        spoke,
        user,
        reserveId,
        collateralReserveId,
        desiredHf,
        pricePercentage,
        SPOKE_ADMIN
      );
  }

  function _mockReservePrice(ISpoke spoke, uint256 reserveId, uint256 price) internal {
    _mockReservePrice(spoke, reserveId, price, SPOKE_ADMIN);
  }

  function _mockReservePriceByPercent(
    ISpoke spoke,
    uint256 reserveId,
    uint256 percentage
  ) internal {
    _mockReservePriceByPercent(spoke, reserveId, percentage, SPOKE_ADMIN);
  }

  function _updateReserveFrozenFlag(ISpoke spoke, uint256 reserveId, bool newFrozenFlag) internal {
    _updateReserveFrozenFlag(spoke, reserveId, newFrozenFlag, SPOKE_ADMIN);
  }

  function _updateReservePausedFlag(ISpoke spoke, uint256 reserveId, bool paused) internal {
    _updateReservePausedFlag(spoke, reserveId, paused, SPOKE_ADMIN);
  }

  function _updateReserveBorrowableFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newBorrowable
  ) internal {
    _updateReserveBorrowableFlag(spoke, reserveId, newBorrowable, SPOKE_ADMIN);
  }

  function _updateCollateralRisk(
    ISpoke spoke,
    uint256 reserveId,
    uint24 newCollateralRisk
  ) internal {
    _updateCollateralRisk(spoke, reserveId, newCollateralRisk, SPOKE_ADMIN);
  }

  function _updateLiquidationConfig(ISpoke spoke, ISpoke.LiquidationConfig memory config) internal {
    _updateLiquidationConfig(spoke, config, SPOKE_ADMIN);
  }

  function _updateMaxLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint32 newMaxLiquidationBonus
  ) internal returns (uint32) {
    return _updateMaxLiquidationBonus(spoke, reserveId, newMaxLiquidationBonus, SPOKE_ADMIN);
  }

  function _updateLiquidationFee(
    ISpoke spoke,
    uint256 reserveId,
    uint16 newLiquidationFee
  ) internal returns (uint32) {
    return _updateLiquidationFee(spoke, reserveId, newLiquidationFee, SPOKE_ADMIN);
  }

  function _updateCollateralFactorAndLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor,
    uint256 newLiquidationBonus
  ) internal returns (uint32) {
    return
      _updateCollateralFactorAndLiquidationBonus(
        spoke,
        reserveId,
        newCollateralFactor,
        newLiquidationBonus,
        SPOKE_ADMIN
      );
  }

  function _updateCollateralFactor(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor
  ) internal returns (uint32) {
    return _updateCollateralFactor(spoke, reserveId, newCollateralFactor, SPOKE_ADMIN);
  }

  function _addDynamicReserveConfig(
    ISpoke spoke,
    uint256 reserveId,
    ISpoke.DynamicReserveConfig memory config
  ) internal returns (uint32) {
    return _addDynamicReserveConfig(spoke, reserveId, config, SPOKE_ADMIN);
  }

  function _updateTargetHealthFactor(ISpoke spoke, uint128 newTargetHealthFactor) internal {
    _updateTargetHealthFactor(spoke, newTargetHealthFactor, SPOKE_ADMIN);
  }

  function _updateLiquidationBonusFactor(ISpoke spoke, uint16 newLiquidationBonusFactor) internal {
    _updateLiquidationBonusFactor(spoke, newLiquidationBonusFactor, SPOKE_ADMIN);
  }
}
