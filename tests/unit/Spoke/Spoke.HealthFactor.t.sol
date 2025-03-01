// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract HealthFactorTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_getHealthFactor_no_supplied() public view {
    // should have no collateral amount
    (, , , uint256 totalCollateralInBaseCurrency, ) = spoke1.calculateUserAccountData(alice);
    assertEq(totalCollateralInBaseCurrency, 0);

    // without any supply/borrow, health factor should be max
    assertEq(spoke1.getHealthFactor(alice), type(uint256).max, 'wrong health factor');
  }

  function test_getHealthFactor_no_borrowed() public {
    uint256 daiAmount = 100e18;

    // alice supply dai into spoke1
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].dai.reserveId, true);

    assertEq(spoke1.getUserCumulativeDebt(spokeInfo[spoke1].dai.reserveId, alice), 0);

    uint256 healthFactor = spoke1.getHealthFactor(alice);
    assertEq(healthFactor, type(uint256).max, 'wrong health factor');
  }

  function test_getHealthFactor_single_borrowed_asset() public {
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 wethAmount = 10e18; // 10 eth -> $20k
    // total collateral -> $30k
    uint256 usdxBorrowAmount = 15_000e6; // 15k usdx -> $15k

    // set Lt to 100% for both assets
    updateLiquidationThreshold(spoke1, spokeInfo[spoke1].dai.reserveId, 1e4);
    updateLiquidationThreshold(spoke1, spokeInfo[spoke1].weth.reserveId, 1e4);

    // alice supply dai into spoke1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].dai.reserveId, true);

    // alice supply eth into spoke1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].weth.reserveId, alice, wethAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].weth.reserveId, true);

    // bob supply usdc into spoke1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].usdx.reserveId, bob, usdxBorrowAmount, bob);

    // alice borrow usdc
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].usdx.reserveId, alice, usdxBorrowAmount, alice);

    uint256 healthFactor = ISpoke(spoke1).getHealthFactor(alice);
    // uint256 expectedHF = _calculateHealthFactor([daiAssetId, wethAssetId, usdxAssetId]);
    assertEq(healthFactor, 2 * WadRayMath.WAD, 'wrong health factor');
  }

  function test_getHealthFactor_multi_asset_price_changes() public {
    uint256 daiAmount = 10_000 *
      10 ** _getAssetConfig(spoke1, spokeInfo[spoke1].dai.reserveId).decimals; // 10k dai -> $10k
    uint256 wethAmount = 10 *
      10 ** _getAssetConfig(spoke1, spokeInfo[spoke1].weth.reserveId).decimals; // 10 eth -> $20k
    // total collateral -> $30k
    uint256 usdxBorrowAmount = 15_000 *
      10 ** _getAssetConfig(spoke1, spokeInfo[spoke1].usdx.reserveId).decimals; // 15k usdc -> $15k
    uint256 wbtcBorrowAmount = 0.1e1 *
      10 ** _getAssetConfig(spoke1, spokeInfo[spoke1].wbtc.reserveId).decimals; // 0.1 wbtc -> $5k
    // total borrowed -> $20k
    bool newCollateral = true;
    bool usingAsCollateral = true;

    // alice supply dai into spoke1
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].dai.reserveId, usingAsCollateral);

    // alice supply weth into spoke1
    deal(address(tokenList.weth), alice, wethAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].weth.reserveId, alice, wethAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].weth.reserveId, usingAsCollateral);

    // bob supply usdc into spoke1
    deal(address(tokenList.usdx), bob, usdxBorrowAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].usdx.reserveId, bob, usdxBorrowAmount, bob);

    // bob supply wbtc into spoke1
    deal(address(tokenList.wbtc), bob, wbtcBorrowAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].wbtc.reserveId, bob, wbtcBorrowAmount, bob);

    // alice borrow usdc
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].usdx.reserveId, alice, usdxBorrowAmount, alice);

    // alice borrow wbtc
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].wbtc.reserveId, alice, wbtcBorrowAmount, alice);

    uint256[] memory reserveIds = new uint256[](4);
    reserveIds[0] = spokeInfo[spoke1].dai.reserveId;
    reserveIds[1] = spokeInfo[spoke1].weth.reserveId;
    reserveIds[2] = spokeInfo[spoke1].usdx.reserveId;
    reserveIds[3] = spokeInfo[spoke1].wbtc.reserveId;

    // initial health factor
    uint256 healthFactor = ISpoke(spoke1).getHealthFactor(alice);
    uint256 expectedHealthFactor = _calculateExpectedHealthFactor(spoke1, alice, reserveIds);
    assertEq(healthFactor, expectedHealthFactor, 'wrong health factor initial');

    // double price changes for both supplied/borrowed assets, HF stays the same
    oracle.setAssetPrice(daiAssetId, oracle.getAssetPrice(daiAssetId) * 2);
    oracle.setAssetPrice(wethAssetId, oracle.getAssetPrice(wethAssetId) * 2);
    oracle.setAssetPrice(usdxAssetId, oracle.getAssetPrice(usdxAssetId) * 2);
    oracle.setAssetPrice(wbtcAssetId, oracle.getAssetPrice(wbtcAssetId) * 2);

    // same health factor
    healthFactor = ISpoke(spoke1).getHealthFactor(alice);
    assertEq(healthFactor, expectedHealthFactor, 'wrong health factor final');
  }

  struct HFCalcLocal {
    uint256 totalCollateral;
    uint256 totalDebt;
    uint256 avgLiquidationThreshold;
    uint256 assetId;
    uint256 i;
    uint256 assetPrice;
    uint256 assetUnit;
    uint256 userCollateral;
  }
  function _calculateExpectedHealthFactor(
    Spoke spoke,
    address user,
    uint256[] memory reserveIds
  ) internal returns (uint256) {
    HFCalcLocal memory vars;

    for (vars.i = 0; vars.i < reserveIds.length; vars.i++) {
      (vars.assetId, ) = getAssetInfo(spoke, reserveIds[vars.i]);
      vars.assetPrice = oracle.getAssetPrice(vars.assetId);
      vars.assetUnit = 10 ** _getAssetConfig(spoke, reserveIds[vars.i]).decimals;
      vars.userCollateral =
        (hub.convertToAssets(vars.assetId, spoke1.getSuppliedAmount(reserveIds[vars.i], user)) *
          vars.assetPrice) /
        vars.assetUnit;
      vars.totalCollateral += vars.userCollateral;

      vars.totalDebt +=
        (spoke.getUserCumulativeDebt(reserveIds[vars.i], user) * vars.assetPrice) /
        vars.assetUnit;
      vars.avgLiquidationThreshold +=
        vars.userCollateral *
        spoke1.getLiquidationThreshold(reserveIds[vars.i]);
    }

    vars.avgLiquidationThreshold = vars.totalCollateral != 0
      ? vars.avgLiquidationThreshold / vars.totalCollateral
      : 0;
    return
      vars.totalDebt == 0
        ? type(uint256).max
        : (vars.totalCollateral.percentMul(vars.avgLiquidationThreshold)).wadDiv(vars.totalDebt);
  }

  function _daiReserveId(Spoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }

  function getAssetInfo(Spoke spoke, uint256 reserveId) internal view returns (uint256, IERC20) {
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    return (reserve.assetId, IERC20(reserve.asset));
  }

  function _getAssetConfig(
    Spoke spoke,
    uint256 reserveId
  ) internal returns (DataTypes.AssetConfig memory) {
    (uint256 assetId, ) = getAssetInfo(spoke, reserveId);
    return hub.getAsset(assetId).config;
  }
}
