// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicCollateralToLiquidateTest is LiquidationLogicBaseTest {
  using WadRayMath for uint256;

  function test_calculateCollateralToLiquidate_fuzz(
    LiquidationLogic.CalculateCollateralToLiquidateParams memory params
  ) public {
    params = _bound(params);

    uint256 collateralAmountToLiquidate = _calculateCollateralAmountToLiquidate(params);
    uint256 expectedCollateralSharesToLiquidate = _calculateCollateralSharesToLiquidate(
      params,
      collateralAmountToLiquidate
    );

    vm.expectCall(
      address(params.collateralReserveHub),
      abi.encodeWithSelector(
        IHubBase.previewAddByAssets.selector,
        params.collateralReserveAssetId,
        collateralAmountToLiquidate
      ),
      1
    );

    uint256 collateralSharesToLiquidate = liquidationLogicWrapper.calculateCollateralToLiquidate(
      params
    );

    assertEq(collateralSharesToLiquidate, expectedCollateralSharesToLiquidate);
  }

  function test_calculateCollateralAmountToLiquidate() public {
    // drawnIndex = 1.5, supply share price = 1.25
    // debt asset: weth, 18 decimals, price = 1000
    // collateral asset: usdx, 6 decimals, price = 0.98
    // liquidation bonus = 105%
    // drawn shares to liquidate = 3
    // premium debt ray to liquidate = 0.4
    // total debt to liquidate = 3 * 1.5 + 0.4 = 4.9
    // debt to collateral = 4.9 * 1000 / 0.98 = 5000
    // collateral with bonus = 5000 * 105% = 5250
    // collateral shares to liquidate = 5250 / 1.25 = 4200
    _mockSupplySharePrice(hub1, usdxAssetId, 12_500.25e6, 10_000e6);
    vm.expectCall(
      address(hub1),
      abi.encodeWithSelector(IHubBase.previewAddByAssets.selector, usdxAssetId, 5250e6),
      1
    );
    uint256 collateralSharesToLiquidate = liquidationLogicWrapper.calculateCollateralToLiquidate(
      LiquidationLogic.CalculateCollateralToLiquidateParams({
        collateralReserveHub: hub1,
        collateralReserveAssetId: usdxAssetId,
        collateralAssetUnit: 10 ** tokenList.usdx.decimals(),
        collateralAssetPrice: 0.98e8,
        drawnSharesToLiquidate: 3e18,
        premiumDebtRayToLiquidate: 0.4e18 * 1e27,
        drawnIndex: 1.5e27,
        debtAssetUnit: 10 ** tokenList.weth.decimals(),
        debtAssetPrice: 1000e8,
        liquidationBonus: 105_00
      })
    );
    assertEq(collateralSharesToLiquidate, 4200e6);
  }

  function _calculateCollateralAmountToLiquidate(
    LiquidationLogic.CalculateCollateralToLiquidateParams memory params
  ) internal pure returns (uint256) {
    uint256 debtRayToLiquidate = params.drawnSharesToLiquidate * params.drawnIndex +
      params.premiumDebtRayToLiquidate;

    uint256 collateralToLiquidate = Math.mulDiv(
      debtRayToLiquidate,
      params.debtAssetPrice * params.collateralAssetUnit * params.liquidationBonus,
      params.debtAssetUnit *
        params.collateralAssetPrice *
        PercentageMath.PERCENTAGE_FACTOR *
        WadRayMath.RAY,
      Math.Rounding.Floor
    );

    return collateralToLiquidate;
  }

  function _calculateCollateralSharesToLiquidate(
    LiquidationLogic.CalculateCollateralToLiquidateParams memory params,
    uint256 collateralAmountToLiquidate
  ) internal view returns (uint256) {
    return
      params.collateralReserveHub.previewAddByAssets(
        params.collateralReserveAssetId,
        collateralAmountToLiquidate
      );
  }
}
