// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicEvaluateDeficitTest is LiquidationLogicBaseTest {
  /// collateral reserve (CR) has 2 relevant states: empty (E) and non-empty (N)
  /// supplied reserves count (SRC) has 2 relevant states: 1 (O) and >1 (M)
  /// debt reserve (DR) has 2 relevant states: empty (E) and non-empty (N)
  /// borrowed reserves count (BRC) has 2 relevant states: 1 (O) and >1 (M)

  function test_evaluateDeficit_CRE_SRCO_DRE_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: true,
      suppliedAssetsCount: 1,
      isDebtPositionEmpty: true,
      borrowedAssetsCount: 1
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRE_SRCO_DRE_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: true,
      suppliedAssetsCount: 1,
      isDebtPositionEmpty: true,
      borrowedAssetsCount: 2
    });
    assertEq(hasDeficit, true);
  }

  function test_evaluateDeficit_CRE_SRCO_DRN_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: true,
      suppliedAssetsCount: 1,
      isDebtPositionEmpty: false,
      borrowedAssetsCount: 1
    });
    assertEq(hasDeficit, true);
  }

  function test_evaluateDeficit_CRE_SRCO_DRN_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: true,
      suppliedAssetsCount: 1,
      isDebtPositionEmpty: false,
      borrowedAssetsCount: 2
    });
    assertEq(hasDeficit, true);
  }

  function test_evaluateDeficit_CRE_SRCM_DRE_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: true,
      suppliedAssetsCount: 2,
      isDebtPositionEmpty: true,
      borrowedAssetsCount: 1
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRE_SRCM_DRE_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: true,
      suppliedAssetsCount: 2,
      isDebtPositionEmpty: true,
      borrowedAssetsCount: 2
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRE_SRCM_DRN_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: true,
      suppliedAssetsCount: 2,
      isDebtPositionEmpty: false,
      borrowedAssetsCount: 1
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRE_SRCM_DRN_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: true,
      suppliedAssetsCount: 2,
      isDebtPositionEmpty: false,
      borrowedAssetsCount: 2
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRN_SRCO_DRE_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: false,
      suppliedAssetsCount: 1,
      isDebtPositionEmpty: true,
      borrowedAssetsCount: 1
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRN_SRCO_DRE_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: false,
      suppliedAssetsCount: 1,
      isDebtPositionEmpty: true,
      borrowedAssetsCount: 2
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRN_SRCO_DRN_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: false,
      suppliedAssetsCount: 1,
      isDebtPositionEmpty: false,
      borrowedAssetsCount: 1
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRN_SRCO_DRN_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: false,
      suppliedAssetsCount: 1,
      isDebtPositionEmpty: false,
      borrowedAssetsCount: 2
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRN_SRCM_DRE_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: false,
      suppliedAssetsCount: 2,
      isDebtPositionEmpty: true,
      borrowedAssetsCount: 1
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRN_SRCM_DRE_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: false,
      suppliedAssetsCount: 2,
      isDebtPositionEmpty: true,
      borrowedAssetsCount: 2
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRN_SRCM_DRN_BRCO() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: false,
      suppliedAssetsCount: 2,
      isDebtPositionEmpty: false,
      borrowedAssetsCount: 1
    });
    assertEq(hasDeficit, false);
  }

  function test_evaluateDeficit_CRN_SRCM_DRN_BRCM() public {
    bool hasDeficit = liquidationLogicWrapper.evaluateDeficit({
      isCollateralPositionEmpty: false,
      suppliedAssetsCount: 2,
      isDebtPositionEmpty: false,
      borrowedAssetsCount: 2
    });
    assertEq(hasDeficit, false);
  }
}
