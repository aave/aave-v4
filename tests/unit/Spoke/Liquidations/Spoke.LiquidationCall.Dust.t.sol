// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';

contract SpokeLiquidationCallDustTest is SpokeLiquidationCallBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  ISpoke _spoke;
  address liquidator = makeAddr('liquidator');

  function setUp() public virtual override {
    super.setUp();
    _spoke = spoke1;

    vm.prank(SPOKE_ADMIN);
    _spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.000001e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 0
      })
    );

    _updateMaxLiquidationBonus(_spoke, _daiReserveId(_spoke), 111_00);
    _updateMaxLiquidationBonus(_spoke, _usdxReserveId(_spoke), 100_00);
    _updateMaxLiquidationBonus(_spoke, _usdyReserveId(_spoke), 100_00);

    deal(_spoke, _usdxReserveId(_spoke), liquidator, 1e30);
    deal(_spoke, _daiReserveId(_spoke), liquidator, 1e30);
    deal(_spoke, _usdyReserveId(_spoke), liquidator, 1e30);

    Utils.approve(_spoke, _usdxReserveId(_spoke), liquidator, type(uint256).max);
    Utils.approve(_spoke, _daiReserveId(_spoke), liquidator, type(uint256).max);
    Utils.approve(_spoke, _usdyReserveId(_spoke), liquidator, type(uint256).max);

    _updateCollateralFactor(_spoke, _daiReserveId(_spoke), 90_00);
    _updateCollateralFactor(_spoke, _usdxReserveId(_spoke), 99_99);
    _updateCollateralFactor(_spoke, _usdyReserveId(_spoke), 99_99);

    _openSupplyPosition(_spoke, _daiReserveId(_spoke), 1e30);
    _openSupplyPosition(_spoke, _usdxReserveId(_spoke), 1e30);
    _openSupplyPosition(_spoke, _usdyReserveId(_spoke), 1e30);
  }

  /// @dev debtToTarget is limiting factor that would result in dust collateral
  /// debtToLiquidate is adjusted to allow full liquidation
  function test_collateralDust_min_debtToTarget() public {
    uint256 collateralFactor = 80_00;
    uint256 liquidationBonus = 124_00;
    uint256 targetHealthFactor = 1.0001e18;

    vm.prank(SPOKE_ADMIN);
    _spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: targetHealthFactor.toUint128(),
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 0
      })
    );

    _updateCollateralFactorAndLiquidationBonus(
      _spoke,
      _daiReserveId(_spoke),
      collateralFactor,
      liquidationBonus
    );
    _increaseCollateralSupply(_spoke, _daiReserveId(_spoke), 1010e18, alice); // $1010
    _increaseCollateralSupply(_spoke, _usdyReserveId(_spoke), 10_000e18, alice);

    Utils.borrow({
      spoke: _spoke,
      reserveId: _usdyReserveId(_spoke),
      caller: alice,
      amount: 9_000e18,
      onBehalfOf: alice
    });
    _borrowToBeAtHf(_spoke, alice, _usdxReserveId(_spoke), 0.9999e18);

    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getCalculateDebtToTargetHealthFactorParams(
        _spoke,
        _daiReserveId(_spoke),
        _usdxReserveId(_spoke),
        alice
      )
    );

    // debtToTarget (~$11) as limiting factor would result in dust collateral
    assertLt(
      _getCollateralValue(_spoke, _daiReserveId(_spoke), alice) -
        _convertAmountToValue(_spoke, _usdxReserveId(_spoke), debtToTarget),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );

    // debtToTarget would result in dust collateral, therefore reverts
    vm.startPrank(liquidator);
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    _spoke.liquidationCall(
      _daiReserveId(_spoke),
      _usdxReserveId(_spoke),
      alice,
      debtToTarget,
      false
    );

    // valid debtToCover succeeds
    _spoke.liquidationCall(
      _daiReserveId(_spoke),
      _usdxReserveId(_spoke),
      alice,
      UINT256_MAX,
      false
    );
    vm.stopPrank();

    assertEq(_spoke.getUserSuppliedAssets(_daiReserveId(_spoke), alice), 0);
  }

  /// @dev debtToCover would theoretically results in debt dust, but is allowed to proceed because collateral reserve was fully liquidated
  function test_debtToCover_exceeds_collateralValue() public {
    uint256 collateralFactor = 80_00;
    uint256 liquidationBonus = 124_00;
    uint256 targetHealthFactor = 1.0001e18;

    vm.prank(SPOKE_ADMIN);
    _spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: targetHealthFactor.toUint128(),
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 0
      })
    );

    _updateCollateralFactorAndLiquidationBonus(
      _spoke,
      _daiReserveId(_spoke),
      collateralFactor,
      liquidationBonus
    );
    _increaseCollateralSupply(_spoke, _daiReserveId(_spoke), 1100e18, alice); // $1100
    _increaseCollateralSupply(_spoke, _usdyReserveId(_spoke), 10_000e18, alice);

    Utils.borrow({
      spoke: _spoke,
      reserveId: _usdyReserveId(_spoke),
      caller: alice,
      amount: 9_000e18,
      onBehalfOf: alice
    });
    _borrowToBeAtHf(_spoke, alice, _usdxReserveId(_spoke), 0.98e18);

    uint256 debtToCover = 1800e6;

    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getCalculateDebtToTargetHealthFactorParams(
        _spoke,
        _daiReserveId(_spoke),
        _usdxReserveId(_spoke),
        alice
      )
    );

    // debtToTarget > debtToCover, so debtToTarget doesn't come into play
    assertGt(debtToTarget, debtToCover);
    // debtToCover would result in debt dust
    uint256 theoreticalRemainingDebt = _spoke.getUserTotalDebt(_usdxReserveId(_spoke), alice) -
      debtToCover;
    assertLt(
      _convertAmountToValue(_spoke, _usdxReserveId(_spoke), theoreticalRemainingDebt),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );

    vm.startPrank(liquidator);
    // if debtToCover results in collateral dust, it should revert; $500 in collateral would remain
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    _spoke.liquidationCall(_daiReserveId(_spoke), _usdxReserveId(_spoke), alice, 600e6, false);

    _spoke.liquidationCall(
      _daiReserveId(_spoke),
      _usdxReserveId(_spoke),
      alice,
      debtToCover,
      false
    );
    vm.stopPrank();

    assertEq(_spoke.getUserSuppliedAssets(_daiReserveId(_spoke), alice), 0);
    // debtToLiquidate has been adjusted because collateral reserve was fully liquidated, so more debt remains than theoreticalRemainingDebt
    assertGt(_spoke.getUserTotalDebt(_usdxReserveId(_spoke), alice), theoreticalRemainingDebt);
  }

  /// @dev debt dust allowed if all collateral is liquidated
  function test_dustDebt_allowed() public {
    uint256 collateralFactor = 80_00;
    uint256 liquidationBonus = 124_00;
    uint256 targetHealthFactor = 1.1e18;

    vm.prank(SPOKE_ADMIN);
    _spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: targetHealthFactor.toUint128(),
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 0
      })
    );

    _updateCollateralFactorAndLiquidationBonus(
      _spoke,
      _daiReserveId(_spoke),
      collateralFactor,
      liquidationBonus
    );
    _increaseCollateralSupply(_spoke, _daiReserveId(_spoke), 1100e18, alice); // $1100
    _increaseCollateralSupply(_spoke, _usdyReserveId(_spoke), 10_000e18, alice);

    Utils.borrow({
      spoke: _spoke,
      reserveId: _usdyReserveId(_spoke),
      caller: alice,
      amount: 9_500e18,
      onBehalfOf: alice
    });
    _borrowToBeAtHf(_spoke, alice, _usdxReserveId(_spoke), 0.999e18);

    uint256 debtToCover = 1200e6; // $1200, enough to liquidate whole coll reserve

    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getCalculateDebtToTargetHealthFactorParams(
        _spoke,
        _daiReserveId(_spoke),
        _usdxReserveId(_spoke),
        alice
      )
    );
    // debtToTarget > debtToCover, so debtToTarget doesn't come into play
    assertGt(debtToTarget, debtToCover);

    vm.startPrank(liquidator);
    // if debtToCover results in collateral and dust, it will revert; $500 in collateral would remain
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    _spoke.liquidationCall(_daiReserveId(_spoke), _usdxReserveId(_spoke), alice, 600e6, false);

    _spoke.liquidationCall(
      _daiReserveId(_spoke),
      _usdxReserveId(_spoke),
      alice,
      debtToCover,
      false
    );
    vm.stopPrank();

    assertEq(_spoke.getUserSuppliedAssets(_daiReserveId(_spoke), alice), 0);
    // dust is allowed on debt reserve
    assertLt(
      _convertAmountToValue(
        _spoke,
        _usdxReserveId(_spoke),
        _spoke.getUserTotalDebt(_usdxReserveId(_spoke), alice)
      ),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );
  }

  /// @dev dust collateral allowed if all debt is liquidated
  function test_dustColl_allowed() public {
    uint256 collateralFactor = 80_00;
    uint256 liquidationBonus = 124_00;
    uint256 targetHealthFactor = 1.1e18;

    vm.prank(SPOKE_ADMIN);
    _spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: targetHealthFactor.toUint128(),
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 0
      })
    );

    _updateCollateralFactorAndLiquidationBonus(
      _spoke,
      _daiReserveId(_spoke),
      collateralFactor,
      liquidationBonus
    );
    _increaseCollateralSupply(_spoke, _daiReserveId(_spoke), 2100e18, alice); // $2100
    _increaseCollateralSupply(_spoke, _usdyReserveId(_spoke), 10_000e18, alice);

    Utils.borrow({
      spoke: _spoke,
      reserveId: _usdyReserveId(_spoke),
      caller: alice,
      amount: 10_500e18,
      onBehalfOf: alice
    });
    _borrowToBeAtHf(_spoke, alice, _usdxReserveId(_spoke), 0.999e18);

    uint256 debtToCover = 1200e6; // $1200, enough to liquidate whole coll reserve

    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getCalculateDebtToTargetHealthFactorParams(
        _spoke,
        _daiReserveId(_spoke),
        _usdxReserveId(_spoke),
        alice
      )
    );
    // debtToTarget > debtToCover, so debtToTarget doesn't come into play
    assertGt(debtToTarget, debtToCover);

    vm.startPrank(liquidator);
    // if debtToCover results in collateral and dust, it will revert; $500 in collateral would remain
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    _spoke.liquidationCall(_daiReserveId(_spoke), _usdxReserveId(_spoke), alice, 600e6, false);

    _spoke.liquidationCall(
      _daiReserveId(_spoke),
      _usdxReserveId(_spoke),
      alice,
      debtToCover,
      false
    );
    vm.stopPrank();

    assertEq(_spoke.getUserTotalDebt(_usdxReserveId(_spoke), alice), 0);
    // dust is allowed on coll reserve
    assertLt(
      _getCollateralValue(_spoke, _daiReserveId(_spoke), alice),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );
  }

  function _calculateDebtToTargetValue(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  ) internal returns (uint256) {
    return
      _convertAmountToValue(
        spoke,
        debtReserveId,
        liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
          _getCalculateDebtToTargetHealthFactorParams(
            spoke,
            collateralReserveId,
            debtReserveId,
            user
          )
        )
      );
  }

  function _getCollateralValue(
    ISpoke spoke,
    uint256 collateralReserveId,
    address user
  ) internal view returns (uint256) {
    return
      _convertAmountToValue(
        spoke,
        collateralReserveId,
        spoke.getUserSuppliedAssets(collateralReserveId, user)
      );
  }
}
