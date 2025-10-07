// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

/// collateral reserve (CR) has 2 relevant states: empty (E) and non-empty (N)
/// supplied collaterals count (SCC) has 2 relevant states: 1 (O) and >1 (M)
/// debt reserve (DR) has 2 relevant states: empty (E) and non-empty (N)
/// borrowed reserves count (BRC) has 2 relevant states: 1 (O) and >1 (M)
contract LiquidationLogicEvaluateDeficitTest is LiquidationLogicBaseTest {
  /// Collateral reserve empty (CRE), supplied collaterals count 1 (SCCO), debt reserve empty (DRE), borrowed reserves count 1 (BRCO)
  function test_evaluateDeficit_CRE_SCCO_DRE_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRE(),
      activeCollateralCount: SCCO(),
      isDebtPositionEmpty: DRE(),
      borrowedCount: BRCO()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve empty (CRE), supplied collaterals count 1 (SCCO), debt reserve empty (DRE), borrowed reserves count >1 (BRCM)
  function test_evaluateDeficit_CRE_SCCO_DRE_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRE(),
      activeCollateralCount: SCCO(),
      isDebtPositionEmpty: DRE(),
      borrowedCount: BRCM()
    });
    assertEq(hasDeficit, true);
  }

  /// Collateral reserve empty (CRE), supplied collaterals count 1 (SCCO), debt reserve non-empty (DRN), borrowed reserves count 1 (BRCO)
  function test_evaluateDeficit_CRE_SCCO_DRN_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRE(),
      activeCollateralCount: SCCO(),
      isDebtPositionEmpty: DRN(),
      borrowedCount: BRCO()
    });
    assertEq(hasDeficit, true);
  }

  /// Collateral reserve empty (CRE), supplied collaterals count 1 (SCCO), debt reserve non-empty (DRN), borrowed reserves count >1 (BRCM)
  function test_evaluateDeficit_CRE_SCCO_DRN_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRE(),
      activeCollateralCount: SCCO(),
      isDebtPositionEmpty: DRN(),
      borrowedCount: BRCM()
    });
    assertEq(hasDeficit, true);
  }

  /// Collateral reserve empty (CRE), supplied collaterals count >1 (SCCM), debt reserve empty (DRE), borrowed reserves count 1 (BRCO)
  function test_evaluateDeficit_CRE_SCCM_DRE_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRE(),
      activeCollateralCount: SCCM(),
      isDebtPositionEmpty: DRE(),
      borrowedCount: BRCO()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve empty (CRE), supplied collaterals count >1 (SCCM), debt reserve empty (DRE), borrowed reserves count >1 (BRCM)
  function test_evaluateDeficit_CRE_SCCM_DRE_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRE(),
      activeCollateralCount: SCCM(),
      isDebtPositionEmpty: DRE(),
      borrowedCount: BRCM()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve empty (CRE), supplied collaterals count >1 (SCCM), debt reserve non-empty (DRN), borrowed reserves count 1 (BRCO)
  function test_evaluateDeficit_CRE_SCCM_DRN_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRE(),
      activeCollateralCount: SCCM(),
      isDebtPositionEmpty: DRN(),
      borrowedCount: BRCO()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve empty (CRE), supplied collaterals count >1 (SCCM), debt reserve non-empty (DRN), borrowed reserves count >1 (BRCM)
  function test_evaluateDeficit_CRE_SCCM_DRN_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRE(),
      activeCollateralCount: SCCM(),
      isDebtPositionEmpty: DRN(),
      borrowedCount: BRCM()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve non-empty (CRN), supplied collaterals count 1 (SCCO), debt reserve empty (DRE), borrowed reserves count 1 (BRCO)
  function test_evaluateDeficit_CRN_SCCO_DRE_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRN(),
      activeCollateralCount: SCCO(),
      isDebtPositionEmpty: DRE(),
      borrowedCount: BRCO()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve non-empty (CRN), supplied collaterals count 1 (SCCO), debt reserve empty (DRE), borrowed reserves count >1 (BRCM)
  function test_evaluateDeficit_CRN_SCCO_DRE_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRN(),
      activeCollateralCount: SCCO(),
      isDebtPositionEmpty: DRE(),
      borrowedCount: BRCM()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve non-empty (CRN), supplied collaterals count 1 (SCCO), debt reserve non-empty (DRN), borrowed reserves count 1 (BRCO)
  function test_evaluateDeficit_CRN_SCCO_DRN_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRN(),
      activeCollateralCount: SCCO(),
      isDebtPositionEmpty: DRN(),
      borrowedCount: BRCO()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve non-empty (CRN), supplied collaterals count 1 (SCCO), debt reserve non-empty (DRN), borrowed reserves count >1 (BRCM)
  function test_evaluateDeficit_CRN_SCCO_DRN_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRN(),
      activeCollateralCount: SCCO(),
      isDebtPositionEmpty: DRN(),
      borrowedCount: BRCM()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve non-empty (CRN), supplied collaterals count >1 (SCCM), debt reserve empty (DRE), borrowed reserves count 1 (BRCO)
  function test_evaluateDeficit_CRN_SCCM_DRE_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRN(),
      activeCollateralCount: SCCM(),
      isDebtPositionEmpty: DRE(),
      borrowedCount: BRCO()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve non-empty (CRN), supplied collaterals count >1 (SCCM), debt reserve empty (DRE), borrowed reserves count >1 (BRCM)
  function test_evaluateDeficit_CRN_SCCM_DRE_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRN(),
      activeCollateralCount: SCCM(),
      isDebtPositionEmpty: DRE(),
      borrowedCount: BRCM()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve non-empty (CRN), supplied collaterals count >1 (SCCM), debt reserve non-empty (DRN), borrowed reserves count 1 (BRCO)
  function test_evaluateDeficit_CRN_SCCM_DRN_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRN(),
      activeCollateralCount: SCCM(),
      isDebtPositionEmpty: DRN(),
      borrowedCount: BRCO()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve non-empty (CRN), supplied collaterals count >1 (SCCM), debt reserve non-empty (DRN), borrowed reserves count >1 (BRCM)
  function test_evaluateDeficit_CRN_SCCM_DRN_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: CRN(),
      activeCollateralCount: SCCM(),
      isDebtPositionEmpty: DRN(),
      borrowedCount: BRCM()
    });
    assertEq(hasDeficit, false);
  }

  /// Collateral reserve empty (CRE)
  function CRE() internal pure returns (bool) {
    return true;
  }

  /// Collateral reserve non-empty (CRN)
  function CRN() internal pure returns (bool) {
    return false;
  }

  /// Supplied collaterals count 1 (SCCO)
  function SCCO() internal pure returns (uint256) {
    return 1;
  }

  /// Supplied collaterals count >1 (SCCM)
  function SCCM() internal pure returns (uint256) {
    return 2;
  }

  /// Debt reserve empty (DRE)
  function DRE() internal pure returns (bool) {
    return true;
  }

  /// Debt reserve non-empty (DRN)
  function DRN() internal pure returns (bool) {
    return false;
  }

  /// Borrowed reserves count 1 (BRCO)
  function BRCO() internal pure returns (uint256) {
    return 1;
  }

  /// Borrowed reserves count >1 (BRCM)
  function BRCM() internal pure returns (uint256) {
    return 2;
  }
}
