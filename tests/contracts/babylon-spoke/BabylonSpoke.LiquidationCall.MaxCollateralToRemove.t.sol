// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/babylon-spoke/BabylonSpoke.Base.t.sol';

contract BabylonSpokeLiquidationCallMaxCollateralToRemoveTest is BabylonSpokeBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  function setUp() public virtual override {
    super.setUp();

    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.1e18,
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 0
      })
    );
    _updateCollateralFactorAndLiquidationBonus(
      spoke1,
      _daiReserveId(spoke1),
      80_00,
      LIQUIDATION_BONUS.toUint32()
    );
  }

  /// @dev The cap binds below the debtToCover seizure: the repayment is resized to consume the cap.
  function test_maxCollateralToRemove_capBinds_resizesRepayment() public {
    uint256 totalDebtBefore = _setupPosition(2100e18, 0.98e18);
    uint256 suppliedBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);
    uint256 maxCollateralToRemove = 500e18;

    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      1200e6,
      maxCollateralToRemove,
      false
    );

    uint256 collateralRemoved = suppliedBefore -
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);
    assertApproxEqAbs(collateralRemoved, maxCollateralToRemove, 2, 'collateral removed');

    // dai and usdx are both worth $1: repaid debt is the cap discounted by the liquidation bonus
    uint256 debtRepaid = totalDebtBefore - spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice);
    assertApproxEqAbs(debtRepaid, _capToDebtRepaid(maxCollateralToRemove), 2, 'debt repaid');
    assertGt(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0);
  }

  /// @dev A cap above the debtToCover seizure has no effect on the liquidation outcome.
  function test_maxCollateralToRemove_capNotBinding_noEffect() public {
    _setupPosition(2100e18, 0.98e18);

    uint256 snapshotId = vm.snapshotState();
    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      300e6,
      UINT256_MAX,
      false
    );
    uint256 uncappedSupplied = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);
    uint256 uncappedDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice);

    vm.revertToState(snapshotId);
    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      300e6,
      2000e18,
      false
    );

    assertEq(spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice), uncappedSupplied);
    assertEq(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), uncappedDebt);
  }

  /// @dev The cap binds and would leave collateral dust while debt remains.
  function test_maxCollateralToRemove_revertsWith_MustNotLeaveDust_collateral() public {
    uint256 totalDebtBefore = _setupPosition(2100e18, 0.85e18);
    uint256 maxCollateralToRemove = 1150e18;

    // seizing the cap leaves dust collateral while the remaining debt is above the threshold
    assertLt(
      _getCollateralValue(spoke1, _daiReserveId(spoke1), alice) -
        _convertAmountToValue(spoke1, _daiReserveId(spoke1), maxCollateralToRemove),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );
    assertGt(
      _convertAmountToValue(
        spoke1,
        _usdxReserveId(spoke1),
        totalDebtBefore - _capToDebtRepaid(maxCollateralToRemove)
      ),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );

    vm.prank(liquidator);
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      UINT256_MAX,
      maxCollateralToRemove,
      false
    );
  }

  /// @dev Same conditions as the collateral dust revert, allowed with the flag on the collateral reserve.
  function test_maxCollateralToRemove_bypassLiquidationDust_onCollateralReserve() public {
    _setupPosition(2100e18, 0.85e18);
    _updateLiquidationBypass(_daiReserveId(spoke1), true, false);

    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      UINT256_MAX,
      1150e18,
      false
    );

    uint256 collateralValueRemaining = _getCollateralValue(spoke1, _daiReserveId(spoke1), alice);
    assertGt(collateralValueRemaining, 0);
    assertLt(collateralValueRemaining, LiquidationLogic.DUST_LIQUIDATION_THRESHOLD);
    assertGt(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0);
  }

  /// @dev The flag set on the debt reserve alone also bypasses the dust protection.
  function test_maxCollateralToRemove_bypassLiquidationDust_onDebtReserve() public {
    _setupPosition(2100e18, 0.85e18);
    _updateLiquidationBypass(_usdxReserveId(spoke1), true, false);

    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      UINT256_MAX,
      1150e18,
      false
    );

    assertLt(
      _getCollateralValue(spoke1, _daiReserveId(spoke1), alice),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );
  }

  /// @dev The cap binds and would leave debt dust while collateral remains.
  function test_maxCollateralToRemove_revertsWith_MustNotLeaveDust_debt() public {
    uint256 totalDebtBefore = _setupPosition(2100e18, 0.98e18);
    uint256 maxCollateralToRemove = 1000e18;

    // seizing the cap leaves dust debt while the remaining collateral is above the threshold
    assertGt(
      _getCollateralValue(spoke1, _daiReserveId(spoke1), alice) -
        _convertAmountToValue(spoke1, _daiReserveId(spoke1), maxCollateralToRemove),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );
    assertLt(
      _convertAmountToValue(
        spoke1,
        _usdxReserveId(spoke1),
        totalDebtBefore - _capToDebtRepaid(maxCollateralToRemove)
      ),
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD
    );

    vm.prank(liquidator);
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      UINT256_MAX,
      maxCollateralToRemove,
      false
    );

    // allowed once the dust protection is bypassed
    _updateLiquidationBypass(_usdxReserveId(spoke1), true, false);
    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      UINT256_MAX,
      maxCollateralToRemove,
      false
    );

    uint256 debtValueRemaining = _convertAmountToValue(
      spoke1,
      _usdxReserveId(spoke1),
      spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice)
    );
    assertGt(debtValueRemaining, 0);
    assertLt(debtValueRemaining, LiquidationLogic.DUST_LIQUIDATION_THRESHOLD);
  }

  /// @dev Without a cap, the flag lets a partial liquidation leave dust instead of forcing a full
  /// collateral liquidation or reverting.
  function test_bypassLiquidationDust_withoutCap_partialLiquidationStands() public {
    uint256 totalDebtBefore = _setupPosition(2100e18, 0.85e18);
    uint256 debtToCover = 1000e6;

    // covering the debt leaves both collateral and debt dust
    vm.prank(liquidator);
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      debtToCover,
      UINT256_MAX,
      false
    );

    _updateLiquidationBypass(_daiReserveId(spoke1), true, false);
    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      debtToCover,
      UINT256_MAX,
      false
    );

    // the partial liquidation stands: the collateral reserve is not fully liquidated
    uint256 debtRepaid = totalDebtBefore - spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice);
    assertApproxEqAbs(debtRepaid, debtToCover, 2, 'debt repaid');
    uint256 collateralValueRemaining = _getCollateralValue(spoke1, _daiReserveId(spoke1), alice);
    assertGt(collateralValueRemaining, 0);
    assertLt(collateralValueRemaining, LiquidationLogic.DUST_LIQUIDATION_THRESHOLD);
  }
}
