// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/babylon-spoke/BabylonSpoke.Base.t.sol';

contract BabylonSpokeLiquidationCallBypassTargetHealthFactorTest is BabylonSpokeBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  function setUp() public virtual override {
    super.setUp();

    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.02e18,
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 0
      })
    );
    _updateCollateralFactorAndLiquidationBonus(
      spoke1,
      _daiReserveId(spoke1),
      50_00,
      LIQUIDATION_BONUS.toUint32()
    );
  }

  /// @dev Canonical sizing stops at the target health factor; the flag on the collateral reserve
  /// lets the same call repay the full debt.
  function test_bypassTargetHealthFactor_onCollateralReserve_allowsFullRepay() public {
    _setupPosition(5000e18, 0.98e18);

    uint256 snapshotId = vm.snapshotState();
    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      UINT256_MAX,
      UINT256_MAX,
      false
    );
    // sized to the target health factor, debt remains
    assertGt(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0);
    assertApproxEqRel(
      _getUserHealthFactor(spoke1, alice),
      1.02e18,
      0.001e18,
      'health factor restored to target'
    );

    vm.revertToState(snapshotId);
    _updateLiquidationBypass(_daiReserveId(spoke1), false, true);
    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      UINT256_MAX,
      UINT256_MAX,
      false
    );

    assertEq(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0);
  }

  /// @dev The flag set on the debt reserve alone also bypasses the target health factor sizing.
  function test_bypassTargetHealthFactor_onDebtReserve_allowsFullRepay() public {
    _setupPosition(5000e18, 0.98e18);
    _updateLiquidationBypass(_usdxReserveId(spoke1), false, true);

    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      UINT256_MAX,
      UINT256_MAX,
      false
    );

    assertEq(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0);
  }

  /// @dev With the flag set, a partial debtToCover above the target sizing is honored exactly.
  function test_bypassTargetHealthFactor_partialDebtToCover() public {
    uint256 totalDebtBefore = _setupPosition(5000e18, 0.98e18);
    uint256 debtToCover = 1200e6;

    // the canonical target health factor sizing would repay less than debtToCover
    uint256 debtToTarget = liquidationLogicWrapper
      .calculateDebtToTargetHealthFactor(
        _getCalculateDebtToTargetHealthFactorParams(
          spoke1,
          _daiReserveId(spoke1),
          _usdxReserveId(spoke1),
          alice
        )
      )
      .fromRayUp();
    assertLt(debtToTarget, debtToCover);

    _updateLiquidationBypass(_daiReserveId(spoke1), false, true);
    vm.prank(liquidator);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      debtToCover,
      UINT256_MAX,
      false
    );

    uint256 debtRepaid = totalDebtBefore - spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice);
    assertApproxEqAbs(debtRepaid, debtToCover, 2, 'debt repaid');
  }
}
