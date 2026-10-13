// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';
import {BabylonLiquidationLogicWrapper} from 'tests/helpers/mocks/BabylonLiquidationLogicWrapper.sol';

/// @dev Base for the babylon liquidation library tests, mirroring `LiquidationLogicBaseTest`. The
/// expected amounts are re-derived here from the sizing rules, independently of the library.
contract BabylonLiquidationLogicBaseTest is Base {
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  BabylonLiquidationLogicWrapper public babylonLiquidationLogicWrapper;

  function setUp() public virtual override {
    super.setUp();
    babylonLiquidationLogicWrapper = new BabylonLiquidationLogicWrapper(
      makeAddr('borrower'),
      makeAddr('liquidator')
    );
  }

  /// @dev Bounds the sizing params to valid protocol ranges and mocks a random collateral supply
  /// share price on hub1. The removable shares cap is left to the caller.
  function _bound(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal virtual returns (BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory) {
    params.liquidationBonus = bound(
      params.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );
    params.collateralAssetUnit =
      10 **
      bound(
        params.collateralAssetUnit,
        MIN_ALLOWED_UNDERLYING_DECIMALS,
        MAX_ALLOWED_UNDERLYING_DECIMALS
      );
    params.debtAssetUnit =
      10 **
      bound(params.debtAssetUnit, MIN_ALLOWED_UNDERLYING_DECIMALS, MAX_ALLOWED_UNDERLYING_DECIMALS);
    params.collateralAssetPrice = bound(params.collateralAssetPrice, 1, MAX_ASSET_PRICE);
    params.drawnIndex = bound(params.drawnIndex, MIN_DRAWN_INDEX, MAX_DRAWN_INDEX);
    params.drawnShares = bound(params.drawnShares, 0, MAX_SUPPLY_AMOUNT / params.drawnIndex);
    params.premiumDebtRay = bound(
      params.premiumDebtRay,
      0,
      MAX_SUPPLY_AMOUNT - params.drawnShares * params.drawnIndex
    );
    uint256 debtRay = params.drawnShares * params.drawnIndex + params.premiumDebtRay;
    params.debtAssetPrice = bound(
      params.debtAssetPrice,
      1,
      MAX_SUPPLY_AMOUNT /
        _max(1, _convertAmountToValue(debtRay.fromRayUp(), 1, params.debtAssetUnit))
    );
    params.debtToCover = bound(params.debtToCover, 0, MAX_SUPPLY_AMOUNT);

    uint256 hubAddedShares = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    uint256 hubAddedAssets = vm.randomUint(
      hubAddedShares,
      MAX_SUPPLY_AMOUNT.min(
        MAX_SUPPLY_PRICE * (hubAddedShares + SharesMath.VIRTUAL_SHARES) - SharesMath.VIRTUAL_ASSETS
      )
    );
    params.collateralReserveHub = hub1;
    params.collateralReserveAssetId = bound(
      params.collateralReserveAssetId,
      0,
      IHub(address(params.collateralReserveHub)).getAssetCount() - 1
    );
    _mockSupplySharePrice({
      hub: IHub(address(params.collateralReserveHub)),
      assetId: params.collateralReserveAssetId,
      totalAddedAssets: hubAddedAssets,
      addedShares: hubAddedShares,
      spoke: address(spoke1)
    });

    return params;
  }

  /// @dev The unbounded sizing: premium debt first, then drawn debt, up to `debtToCover` and the
  /// user's debt; the collateral is the canonical bonus pricing of the repaid value.
  function _calculateRawLiquidationAmounts(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal view returns (BabylonLiquidationLogic.LiquidationAmounts memory) {
    uint256 premiumDebtRayToLiquidate = params.premiumDebtRay;
    if (params.debtToCover < premiumDebtRayToLiquidate.fromRayUp()) {
      premiumDebtRayToLiquidate = params.debtToCover.toRay();
    }
    uint256 drawnSharesToLiquidate;
    if (premiumDebtRayToLiquidate == params.premiumDebtRay) {
      drawnSharesToLiquidate = Math
        .mulDiv(
          params.debtToCover - premiumDebtRayToLiquidate.fromRayUp(),
          WadRayMath.RAY,
          params.drawnIndex,
          Math.Rounding.Floor
        )
        .min(params.drawnShares);
    }

    uint256 debtRayToLiquidate = drawnSharesToLiquidate * params.drawnIndex +
      premiumDebtRayToLiquidate;
    uint256 collateralToLiquidate = Math.mulDiv(
      debtRayToLiquidate,
      params.debtAssetPrice * params.collateralAssetUnit * params.liquidationBonus,
      params.debtAssetUnit *
        params.collateralAssetPrice *
        PercentageMath.PERCENTAGE_FACTOR *
        WadRayMath.RAY,
      Math.Rounding.Floor
    );

    return
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: params.collateralReserveHub.previewAddByAssets(
          params.collateralReserveAssetId,
          collateralToLiquidate
        ),
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate
      });
  }

  /// @dev The cap-bounded sizing: the removed shares are exactly the cap and the repayment is the
  /// inverse bonus pricing of their value, premium debt first, mirroring the canonical
  /// full-collateral sizing.
  function _calculateCappedLiquidationAmounts(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) internal view returns (BabylonLiquidationLogic.LiquidationAmounts memory) {
    uint256 debtRayToLiquidate = Math.mulDiv(
      params.collateralReserveHub.previewAddByShares(
        params.collateralReserveAssetId,
        params.maxRemovableShares
      ),
      params.collateralAssetPrice *
        params.debtAssetUnit *
        PercentageMath.PERCENTAGE_FACTOR *
        WadRayMath.RAY,
      params.debtAssetPrice * params.collateralAssetUnit * params.liquidationBonus,
      Math.Rounding.Ceil
    );

    uint256 premiumDebtRayToLiquidate;
    uint256 drawnSharesToLiquidate;
    if (debtRayToLiquidate <= params.premiumDebtRay) {
      premiumDebtRayToLiquidate = debtRayToLiquidate.fromRayUp().toRay().min(params.premiumDebtRay);
    } else {
      premiumDebtRayToLiquidate = params.premiumDebtRay;
      drawnSharesToLiquidate = (debtRayToLiquidate - premiumDebtRayToLiquidate).divUp(
        params.drawnIndex
      );
    }

    return
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: params.maxRemovableShares,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate
      });
  }

  function assertEq(
    BabylonLiquidationLogic.LiquidationAmounts memory a,
    BabylonLiquidationLogic.LiquidationAmounts memory b
  ) internal pure {
    assertEq(
      a.collateralSharesToLiquidate,
      b.collateralSharesToLiquidate,
      'collateralSharesToLiquidate'
    );
    assertEq(a.drawnSharesToLiquidate, b.drawnSharesToLiquidate, 'drawnSharesToLiquidate');
    assertEq(a.premiumDebtRayToLiquidate, b.premiumDebtRayToLiquidate, 'premiumDebtRayToLiquidate');
  }
}
