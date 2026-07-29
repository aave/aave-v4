// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EtherFiSpokeTestHelpers} from 'tests/etherfi/EtherFiSpokeTestBase.t.sol';

import {AaveOracleTest} from 'tests/contracts/spoke/AaveOracle.t.sol';
import {SpokeAccessTest} from 'tests/contracts/spoke/misc/Spoke.Access.t.sol';
import {SpokeGettersTest} from 'tests/contracts/spoke/misc/Spoke.Getters.t.sol';
import {SpokeMulticall} from 'tests/contracts/spoke/misc/Spoke.Multicall.t.sol';
import {SpokePermitReserveTest} from 'tests/contracts/spoke/misc/Spoke.PermitReserve.t.sol';
import {SpokeSetUsingAsCollateralTest} from 'tests/contracts/spoke/misc/Spoke.SetUsingAsCollateral.t.sol';
import {SpokeUpgradeableTest} from 'tests/contracts/spoke/misc/Spoke.Upgradeable.t.sol';
import {SpokeUserAccountDataTest} from 'tests/contracts/spoke/misc/Spoke.UserAccountData.t.sol';
import {SpokeConfigTest} from 'tests/contracts/spoke/configuration/Spoke.Config.t.sol';
import {SpokeDynamicConfigTest} from 'tests/contracts/spoke/configuration/Spoke.DynamicConfig.t.sol';
import {SpokeDynamicConfigTriggersTest} from 'tests/contracts/spoke/configuration/Spoke.DynamicConfig.Triggers.t.sol';
import {SpokeReserveConfigTest} from 'tests/contracts/spoke/configuration/Spoke.ReserveConfig.t.sol';
import {SpokeUpdateUserDynamicConfigTest} from 'tests/contracts/spoke/configuration/Spoke.UpdateUserDynamicConfig.t.sol';
import {SpokeConfiguratorTest} from 'tests/contracts/spoke/configurator/SpokeConfigurator.t.sol';
import {SpokeConfiguratorGranularAccessControlTest} from 'tests/contracts/spoke/configurator/SpokeConfigurator.GranularAccessControl.t.sol';
import {SpokePositionManagerTest} from 'tests/contracts/spoke/position-manager/Spoke.PositionManager.t.sol';
import {SpokeSetUserPositionManagersWithSigTest} from 'tests/contracts/spoke/position-manager/Spoke.SetUserPositionManagerWithSig.t.sol';
import {SpokeSupplyTest} from 'tests/contracts/spoke/supply/Spoke.Supply.t.sol';
import {SpokeBorrowTest} from 'tests/contracts/spoke/borrow/Spoke.Borrow.t.sol';
import {SpokeBorrowEdgeCasesTest} from 'tests/contracts/spoke/borrow/Spoke.Borrow.EdgeCases.t.sol';
import {SpokeBorrowHealthFactorTest} from 'tests/contracts/spoke/borrow/Spoke.Borrow.HealthFactor.t.sol';
import {SpokeBorrowScenarioTest} from 'tests/contracts/spoke/borrow/Spoke.Borrow.Scenario.t.sol';
import {SpokeBorrowValidationTest} from 'tests/contracts/spoke/borrow/Spoke.Borrow.Validation.t.sol';
import {SpokeWithdrawTest} from 'tests/contracts/spoke/withdraw/Spoke.Withdraw.t.sol';
import {SpokeWithdrawHealthFactorTest} from 'tests/contracts/spoke/withdraw/Spoke.Withdraw.HealthFactor.t.sol';
import {SpokeWithdrawScenarioTest} from 'tests/contracts/spoke/withdraw/Spoke.Withdraw.Scenario.t.sol';
import {SpokeWithdrawValidationTest} from 'tests/contracts/spoke/withdraw/Spoke.Withdraw.Validation.t.sol';
import {SpokeRepayTest} from 'tests/contracts/spoke/repay/Spoke.Repay.t.sol';
import {SpokeRepayEdgeCaseTest} from 'tests/contracts/spoke/repay/Spoke.Repay.EdgeCases.t.sol';
import {SpokeRepayScenarioTest} from 'tests/contracts/spoke/repay/Spoke.Repay.Scenario.t.sol';
import {SpokeRepayValidationTest} from 'tests/contracts/spoke/repay/Spoke.Repay.Validation.t.sol';
import {SpokeAccrueInterestTest} from 'tests/contracts/spoke/accrual/Spoke.AccrueInterest.t.sol';
import {SpokeAccrueInterestScenarioTest} from 'tests/contracts/spoke/accrual/Spoke.AccrueInterest.Scenario.t.sol';
import {SpokeAccrueLiquidityFeeTest} from 'tests/contracts/spoke/accrual/Spoke.AccrueLiquidityFee.t.sol';
import {SpokeAccrueLiquidityFeeEdgeCasesTest} from 'tests/contracts/spoke/accrual/Spoke.AccrueLiquidityFee.EdgeCases.t.sol';
import {SpokeRiskPremiumTest} from 'tests/contracts/spoke/risk-premium/Spoke.RiskPremium.t.sol';
import {SpokeRiskPremiumEdgeCasesTest} from 'tests/contracts/spoke/risk-premium/Spoke.RiskPremium.EdgeCases.t.sol';
import {SpokeRiskPremiumScenarioTest} from 'tests/contracts/spoke/risk-premium/Spoke.RiskPremium.Scenario.t.sol';
import {SpokeMultipleHubTest} from 'tests/contracts/spoke/multi-hub/Spoke.MultipleHub.t.sol';
import {SpokeLiquidationCallScenariosTest} from 'tests/contracts/spoke/liquidation/Spoke.LiquidationCall.Scenarios.t.sol';
import {SpokeLiquidationCallDustTest} from 'tests/contracts/spoke/liquidation/Spoke.LiquidationCall.Dust.t.sol';
import {
  SpokeLiquidationCallTest_SmallPosition,
  SpokeLiquidationCallTest_LargePosition,
  SpokeLiquidationCallTest_NoLiquidationBonus,
  SpokeLiquidationCallTest_SmallLiquidationBonus,
  SpokeLiquidationCallTest_LargeLiquidationBonus,
  SpokeLiquidationCallTest_LiquidationFeeZero,
  SpokeLiquidationCallTest_NoPremium,
  SpokeLiquidationCallTest_Premium,
  SpokeLiquidationCallTest_NoTimeSkip,
  SpokeLiquidationCallTest_TargetHealthFactorOne,
  SpokeLiquidationCallTest_LiquidatorHistory
} from 'tests/contracts/spoke/liquidation/Spoke.LiquidationCall.t.sol';
import {UserPositionUtilsTest} from 'tests/contracts/spoke/libraries/UserPositionUtils.t.sol';
import {PositionStatusMapTest} from 'tests/contracts/spoke/libraries/PositionStatusMap.t.sol';
import {SpokeUtilsTest} from 'tests/contracts/spoke/libraries/SpokeUtils.t.sol';
import {LiquidationLogicCollateralToLiquidateTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.CollateralToLiquidate.t.sol';
import {LiquidationLogicDebtToTargetHealthFactorTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.DebtToTargetHealthFactor.t.sol';
import {LiquidationLogicExecuteLiquidationTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.ExecuteLiquidation.t.sol';
import {LiquidationLogicLiquidateCollateralTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.LiquidateCollateral.t.sol';
import {LiquidationLogicLiquidateDebtTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.LiquidateDebt.t.sol';
import {LiquidationLogicLiquidateUserTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.LiquidateUser.t.sol';
import {LiquidationLogicLiquidationAmountsTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.LiquidationAmounts.t.sol';
import {LiquidationLogicLiquidationBonusTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.LiquidationBonus.t.sol';
import {LiquidationLogicValidateLiquidationCallTest} from 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.ValidateLiquidationCall.t.sol';

/// @dev Re-runs every Base-derived Spoke suite against EtherFiSpokeInstance: the fixtures
/// deploy the ether.fi spoke bytecode and etch an allow-all mock at the hardcoded
/// EtherFiDataProvider address (see EtherFiSpokeTestHelpers), making the borrow gate
/// transparent. Every test below must pass identically to its stock counterpart — this is the
/// proof that the gate override changes nothing outside the gate itself. Restricted
/// (deny-mode) borrow scenarios live in EtherFiSpokeGate.t.sol.
///
/// Each variant inherits exactly one suite (no mixin) and overrides only the _spokeBytecode()
/// hook, so it composes with any setUp/fixture overrides a suite may have. Pure-library suites
/// that never deploy a spoke (KeyValueList, EIP712Hash, ReserveFlagsMap) are not re-run. The
/// SpokeMultipleHubBase-derived suites (IsolationMode, SiloedBorrowing) are not re-run either:
/// their fixture path hardcodes the stock SpokeInstance bytecode and does not expose the hook.
contract EtherFi_AaveOracleTest is AaveOracleTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeAccessTest is SpokeAccessTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeGettersTest is SpokeGettersTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeMulticall is SpokeMulticall {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokePermitReserveTest is SpokePermitReserveTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeSetUsingAsCollateralTest is SpokeSetUsingAsCollateralTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeUpgradeableTest is SpokeUpgradeableTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeUserAccountDataTest is SpokeUserAccountDataTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeConfigTest is SpokeConfigTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeDynamicConfigTest is SpokeDynamicConfigTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeDynamicConfigTriggersTest is SpokeDynamicConfigTriggersTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeReserveConfigTest is SpokeReserveConfigTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeUpdateUserDynamicConfigTest is SpokeUpdateUserDynamicConfigTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeConfiguratorTest is SpokeConfiguratorTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeConfiguratorGranularAccessControlTest is
  SpokeConfiguratorGranularAccessControlTest
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokePositionManagerTest is SpokePositionManagerTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeSetUserPositionManagersWithSigTest is
  SpokeSetUserPositionManagersWithSigTest
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeSupplyTest is SpokeSupplyTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeBorrowTest is SpokeBorrowTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeBorrowEdgeCasesTest is SpokeBorrowEdgeCasesTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeBorrowHealthFactorTest is SpokeBorrowHealthFactorTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeBorrowScenarioTest is SpokeBorrowScenarioTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeBorrowValidationTest is SpokeBorrowValidationTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeWithdrawTest is SpokeWithdrawTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeWithdrawHealthFactorTest is SpokeWithdrawHealthFactorTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeWithdrawScenarioTest is SpokeWithdrawScenarioTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeWithdrawValidationTest is SpokeWithdrawValidationTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeRepayTest is SpokeRepayTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeRepayEdgeCaseTest is SpokeRepayEdgeCaseTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeRepayScenarioTest is SpokeRepayScenarioTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeRepayValidationTest is SpokeRepayValidationTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeAccrueInterestTest is SpokeAccrueInterestTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeAccrueInterestScenarioTest is SpokeAccrueInterestScenarioTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeAccrueLiquidityFeeTest is SpokeAccrueLiquidityFeeTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeAccrueLiquidityFeeEdgeCasesTest is SpokeAccrueLiquidityFeeEdgeCasesTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeRiskPremiumTest is SpokeRiskPremiumTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeRiskPremiumEdgeCasesTest is SpokeRiskPremiumEdgeCasesTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeRiskPremiumScenarioTest is SpokeRiskPremiumScenarioTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeMultipleHubTest is SpokeMultipleHubTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallScenariosTest is SpokeLiquidationCallScenariosTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallDustTest is SpokeLiquidationCallDustTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_SmallPosition is SpokeLiquidationCallTest_SmallPosition {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_LargePosition is SpokeLiquidationCallTest_LargePosition {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_NoLiquidationBonus is
  SpokeLiquidationCallTest_NoLiquidationBonus
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_SmallLiquidationBonus is
  SpokeLiquidationCallTest_SmallLiquidationBonus
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_LargeLiquidationBonus is
  SpokeLiquidationCallTest_LargeLiquidationBonus
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_LiquidationFeeZero is
  SpokeLiquidationCallTest_LiquidationFeeZero
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_NoPremium is SpokeLiquidationCallTest_NoPremium {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_Premium is SpokeLiquidationCallTest_Premium {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_NoTimeSkip is SpokeLiquidationCallTest_NoTimeSkip {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_TargetHealthFactorOne is
  SpokeLiquidationCallTest_TargetHealthFactorOne
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeLiquidationCallTest_LiquidatorHistory is
  SpokeLiquidationCallTest_LiquidatorHistory
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_UserPositionUtilsTest is UserPositionUtilsTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_PositionStatusMapTest is PositionStatusMapTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_SpokeUtilsTest is SpokeUtilsTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicCollateralToLiquidateTest is
  LiquidationLogicCollateralToLiquidateTest
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicDebtToTargetHealthFactorTest is
  LiquidationLogicDebtToTargetHealthFactorTest
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicExecuteLiquidationTest is LiquidationLogicExecuteLiquidationTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicLiquidateCollateralTest is
  LiquidationLogicLiquidateCollateralTest
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicLiquidateDebtTest is LiquidationLogicLiquidateDebtTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicLiquidateUserTest is LiquidationLogicLiquidateUserTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicLiquidationAmountsTest is LiquidationLogicLiquidationAmountsTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicLiquidationBonusTest is LiquidationLogicLiquidationBonusTest {
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
contract EtherFi_LiquidationLogicValidateLiquidationCallTest is
  LiquidationLogicValidateLiquidationCallTest
{
  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
