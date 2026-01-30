// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';

abstract contract SpokeLiquidationCallHelperTest is SpokeLiquidationCallBaseTest {
  using WadRayMath for uint256;
  using SafeCast for uint256;
  using PercentageMath for uint256;

  ISpoke spoke;
  address user = makeAddr('user');
  address liquidator = makeAddr('liquidator');

  function setUp() public virtual override {
    super.setUp();
    spoke = spoke1;

    _updateTargetHealthFactor(spoke, vm.randomUint(MIN_CLOSE_FACTOR, MAX_CLOSE_FACTOR).toUint128());
    _updateLiquidationConfig(
      spoke,
      ISpoke.LiquidationConfig({
        targetHealthFactor: vm.randomUint(MIN_CLOSE_FACTOR, MAX_CLOSE_FACTOR).toUint128(),
        healthFactorForMaxBonus: vm
          .randomUint(0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1)
          .toUint64(),
        liquidationBonusFactor: vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR).toUint16()
      })
    );

    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      _updateMaxLiquidationBonus(spoke, i, _randomMaxLiquidationBonus(spoke, i));
      _updateCollateralFactor(spoke, i, 1); // temporary value to have full range of possibility for liquidation fee
      _updateLiquidationFee(
        spoke,
        i,
        vm.randomUint(MIN_LIQUIDATION_FEE, MAX_LIQUIDATION_FEE).toUint16()
      );
      _updateCollateralFactor(spoke, i, _randomCollateralFactor(spoke, i));
      _updateCollateralRisk(
        spoke,
        i,
        vm.randomUint(MIN_COLLATERAL_RISK_BPS, MAX_COLLATERAL_RISK_BPS).toUint24()
      );
    }
  }

  function _baseAmountValue() internal virtual returns (uint256) {
    return vm.randomUint(MIN_AMOUNT_IN_BASE_CURRENCY, MAX_AMOUNT_IN_BASE_CURRENCY);
  }

  function _skipTime() internal virtual returns (uint256) {
    return vm.randomUint(0, 10 * 365 days);
  }

  function _processAdditionalSetup(
    uint256 /* collateralReserveId */,
    uint256 /* debtReserveId */
  ) internal virtual {
    // user enables more collaterals, but still has deficit given that only one collateral is supplied
    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); reserveId++) {
      if (vm.randomBool()) {
        Utils.setUsingAsCollateral(spoke, reserveId, user, true, user);
      }
    }
  }

  function _processAdditionalCollateralReserves(uint256 debtReserveId) internal {
    // division by 100 accounts for supply share price increase due to time skip (and interest rate) and user's avg collateral factor
    // ensures debt required to make user liquidatable does not exceed max supply amount
    uint256 suppliableValue = (_convertAmountToValue(
      spoke,
      debtReserveId,
      _calculateMaxSupplyAmount(spoke, debtReserveId)
    ) - _baseAmountValue()) / 100;

    uint256 count = vm.randomUint(1, spoke.getReserveCount() * 2);
    for (uint256 i = 0; i < count; i++) {
      uint256 reserveId = vm.randomUint(0, spoke.getReserveCount() - 1);
      uint256 maxAmount = _convertValueToAmount(spoke, reserveId, suppliableValue);
      if (maxAmount == 0) {
        require(i > 0, 'No supply operations');
        break;
      }
      uint256 amount = vm.randomUint(1, maxAmount);
      suppliableValue -= _convertAmountToValue(spoke, reserveId, amount);
      _increaseCollateralSupply(spoke, reserveId, amount, user);
    }
  }

  function _processAdditionalDebtReserves() internal {
    uint256 count = vm.randomUint(1, spoke.getReserveCount() * 2);
    // accounts for borrow share price increase due to time skip (and borrow interest rate)
    // ensures user is healthy enough to borrow
    uint256 borrowableValue = _getRequiredDebtValueForHf(
      spoke,
      user,
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD * (2 + _skipTime() / 365 days)
    ).percentDivDown(2 * PercentageMath.PERCENTAGE_FACTOR + _spokeMaxCollateralRisk(spoke));
    for (uint256 i = 0; i < count; i++) {
      uint256 reserveId = vm.randomUint(0, spoke.getReserveCount() - 1);
      uint256 maxBorrowAmount = _convertValueToAmount(spoke, reserveId, borrowableValue);
      if (maxBorrowAmount == 0) {
        require(i > 0, 'No borrow operations');
        break;
      }
      uint256 amount = vm.randomUint(1, maxBorrowAmount);
      borrowableValue -= _convertAmountToValue(spoke, reserveId, amount);
      _increaseReserveDebt(spoke, reserveId, amount, user);
    }
  }

  function _testLiquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool isSolvent,
    bool receiveShares
  ) internal virtual {
    skip(_skipTime());

    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    uint256 newHealthFactor; // new health factor of user, just before liquidation
    if (isSolvent) {
      // health factor of user should be at least its average collateral factor
      newHealthFactor = vm.randomUint(
        userAccountData.avgCollateralFactor + 0.0000001e18,
        PercentageMath.PERCENTAGE_FACTOR.bpsToWad() - 0.0000001e18
      );
    } else {
      newHealthFactor = vm.randomUint(0.01e18, userAccountData.avgCollateralFactor - 0.0000001e18);
    }
    _makeUserLiquidatable(spoke, user, debtReserveId, newHealthFactor);

    debtToCover = _boundDebtToCoverNoDustRevert(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator
    );

    _checkedLiquidationCall(
      CheckedLiquidationCallParams({
        spoke: spoke,
        collateralReserveId: collateralReserveId,
        debtReserveId: debtReserveId,
        user: user,
        debtToCover: debtToCover,
        liquidator: liquidator,
        isSolvent: isSolvent,
        receiveShares: receiveShares
      })
    );
  }

  function test_liquidationCall_fuzz_OneCollateral_OneDebt_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(spoke, collateralReserveId, debtReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _testLiquidationCall(collateralReserveId, debtReserveId, debtToCover, true, receiveShares);
  }

  function test_liquidationCall_fuzz_OneCollateral_OneDebt_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(spoke, collateralReserveId, debtReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _testLiquidationCall(collateralReserveId, debtReserveId, debtToCover, false, receiveShares);
  }

  function test_liquidationCall_fuzz_ManyCollaterals_OneDebt_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(spoke, collateralReserveId, debtReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalCollateralReserves(debtReserveId);

    _testLiquidationCall(collateralReserveId, debtReserveId, debtToCover, true, receiveShares);
  }

  function test_liquidationCall_fuzz_ManyCollaterals_OneDebt_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(spoke, collateralReserveId, debtReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalCollateralReserves(debtReserveId);

    _testLiquidationCall(collateralReserveId, debtReserveId, debtToCover, false, receiveShares);
  }

  function test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(spoke, collateralReserveId, debtReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalDebtReserves();

    _testLiquidationCall(collateralReserveId, debtReserveId, debtToCover, true, receiveShares);
  }

  function test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(spoke, collateralReserveId, debtReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalDebtReserves();

    _testLiquidationCall(collateralReserveId, debtReserveId, debtToCover, false, receiveShares);
  }

  function test_liquidationCall_fuzz_ManyCollaterals_ManyDebts_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(spoke, collateralReserveId, debtReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalCollateralReserves(debtReserveId);
    _processAdditionalDebtReserves();

    _testLiquidationCall(collateralReserveId, debtReserveId, debtToCover, true, receiveShares);
  }

  function test_liquidationCall_fuzz_ManyCollaterals_ManyDebts_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId) = _bound(spoke, collateralReserveId, debtReserveId);
    _processAdditionalSetup(collateralReserveId, debtReserveId);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalCollateralReserves(debtReserveId);
    _processAdditionalDebtReserves();

    _testLiquidationCall(collateralReserveId, debtReserveId, debtToCover, false, receiveShares);
  }
}

contract SpokeLiquidationCallTest_SmallPosition is SpokeLiquidationCallHelperTest {
  function _baseAmountValue() internal virtual override returns (uint256) {
    return vm.randomUint(1e26, 10_000e26);
  }
}

contract SpokeLiquidationCallTest_LargePosition is SpokeLiquidationCallHelperTest {
  function _baseAmountValue() internal virtual override returns (uint256) {
    return vm.randomUint(100_000e26, 1_000_000_000e26);
  }
}

contract SpokeLiquidationCallTest_NoLiquidationBonus is SpokeLiquidationCallHelperTest {
  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    _updateMaxLiquidationBonus(spoke, collateralReserveId, 100_00);
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory /* params */,
    AccountsInfo memory /* accountsInfoBefore */,
    LiquidationMetadata memory liquidationMetadata
  ) internal view virtual override {
    assertEq(liquidationMetadata.liquidationBonus, 100_00, 'Liquidation bonus');
  }
}

contract SpokeLiquidationCallTest_SmallLiquidationBonus is SpokeLiquidationCallHelperTest {
  using PercentageMath for *;
  using SafeCast for uint256;

  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    _updateCollateralFactor(spoke, collateralReserveId, 1); // temporary value to have full range of possibility for liquidation bonus
    _updateMaxLiquidationBonus(
      spoke,
      collateralReserveId,
      vm.randomUint(MIN_LIQUIDATION_BONUS, MIN_LIQUIDATION_BONUS.percentMulUp(102_00)).toUint32()
    );
    _updateLiquidationBonusFactor(spoke, 100_00);
    _updateCollateralFactor(
      spoke,
      collateralReserveId,
      _randomCollateralFactor(spoke, collateralReserveId)
    );
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory /* params */,
    AccountsInfo memory /* accountsInfoBefore */,
    LiquidationMetadata memory liquidationMetadata
  ) internal view virtual override {
    assertLe(
      liquidationMetadata.liquidationBonus,
      MAX_LIQUIDATION_BONUS.percentMulUp(102_00),
      'Liquidation bonus'
    );
  }
}

contract SpokeLiquidationCallTest_LargeLiquidationBonus is SpokeLiquidationCallHelperTest {
  using PercentageMath for *;
  using SafeCast for *;

  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    _updateCollateralFactor(spoke, collateralReserveId, 1); // temporary value to have full range of possibility for liquidation bonus
    _updateMaxLiquidationBonus(
      spoke,
      collateralReserveId,
      vm.randomUint(MAX_LIQUIDATION_BONUS.percentMulDown(97_00), MAX_LIQUIDATION_BONUS).toUint32()
    );
    _updateLiquidationBonusFactor(spoke, 100_00);
    _updateCollateralFactor(
      spoke,
      collateralReserveId,
      _randomCollateralFactor(spoke, collateralReserveId)
    );
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory /* params */,
    AccountsInfo memory /* accountsInfoBefore */,
    LiquidationMetadata memory liquidationMetadata
  ) internal view virtual override {
    assertGe(
      liquidationMetadata.liquidationBonus,
      MAX_LIQUIDATION_BONUS.percentMulDown(97_00),
      'Liquidation bonus'
    );
  }
}

contract SpokeLiquidationCallTest_LiquidationFeeZero is SpokeLiquidationCallHelperTest {
  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    _updateLiquidationFee(spoke, collateralReserveId, 0);
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory /* accountsInfoBefore */,
    LiquidationMetadata memory /* liquidationMetadata */
  ) internal view virtual override {
    assertEq(
      _getLiquidationFee(params.spoke, params.collateralReserveId, params.user),
      0,
      'Liquidation fee'
    );
  }
}

contract SpokeLiquidationCallTest_NoPremium is SpokeLiquidationCallHelperTest {
  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      _updateCollateralRisk(spoke, i, 0);
    }
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory /* accountsInfoBefore */,
    LiquidationMetadata memory /* liquidationMetadata */
  ) internal view virtual override {
    (, uint256 premiumDebt) = params.spoke.getUserDebt(params.debtReserveId, params.user);
    assertEq(premiumDebt, 0, 'No premium');
  }
}

contract SpokeLiquidationCallTest_Premium is SpokeLiquidationCallHelperTest {
  using SafeCast for uint256;
  using PercentageMath for uint256;

  function _skipTime() internal virtual override returns (uint256) {
    return vm.randomUint(1, 10 * 365 days);
  }

  function _processAdditionalSetup(
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual override {
    super._processAdditionalSetup(collateralReserveId, debtReserveId);
    _updateCollateralRisk(
      spoke,
      collateralReserveId,
      vm.randomUint(1, MAX_COLLATERAL_RISK_BPS).toUint24()
    );
    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );
    _increaseReserveDebt(
      spoke,
      debtReserveId,
      _convertValueToAmount(
        spoke,
        debtReserveId,
        _getRequiredDebtValueForHf(
          spoke,
          user,
          Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD * (2 + (2 * _skipTime()) / 365 days)
        )
      ).percentDivDown(2 * PercentageMath.PERCENTAGE_FACTOR + _spokeMaxCollateralRisk(spoke)),
      user
    );
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory /* accountsInfoBefore */,
    LiquidationMetadata memory /* liquidationMetadata */
  ) internal view virtual override {
    (, uint256 premiumDebt) = params.spoke.getUserDebt(params.debtReserveId, params.user);
    assertGt(premiumDebt, 0, 'User should have premium debt');
  }
}

contract SpokeLiquidationCallTest_NoTimeSkip is SpokeLiquidationCallHelperTest {
  function _skipTime() internal virtual override returns (uint256) {
    return 0;
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory /* accountsInfoBefore */,
    LiquidationMetadata memory /* liquidationMetadata */
  ) internal view virtual override {
    uint256 reserveCount = params.spoke.getReserveCount();
    for (uint256 i = 0; i < reserveCount; i++) {
      assertEq(_reserveDrawnIndex(params.spoke, i), 1e27, 'drawn index');
      IHub hub = _hub(params.spoke, i);
      uint256 assetId = _reserveAssetId(params.spoke, i);
      assertEq(hub.getAddedAssets(assetId), hub.getAddedShares(assetId), 'supply share price');
    }
  }
}

contract SpokeLiquidationCallTest_TargetHealthFactorOne is SpokeLiquidationCallHelperTest {
  function setUp() public virtual override {
    super.setUp();
    _updateTargetHealthFactor(spoke, 1e18);
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory /* accountsInfoBefore */,
    LiquidationMetadata memory /* liquidationMetadata */
  ) internal view virtual override {
    assertEq(params.spoke.getLiquidationConfig().targetHealthFactor, 1e18, 'Target health factor');
  }
}

contract SpokeLiquidationCallTest_LiquidatorHistory is SpokeLiquidationCallHelperTest {
  function setUp() public virtual override {
    super.setUp();

    ISpoke.UserAccountData memory liquidatorAccountData;
    uint256 count = vm.randomUint(1, spoke.getReserveCount() * 2);
    for (uint256 i = 0; i < count; i++) {
      uint256 reserveId = vm.randomUint(0, spoke.getReserveCount() - 1);
      _increaseCollateralSupply(
        spoke,
        reserveId,
        _convertValueToAmount(spoke, reserveId, _baseAmountValue()),
        liquidator
      );
      liquidatorAccountData = spoke.getUserAccountData(liquidator);
      if (liquidatorAccountData.healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
        break;
      }
      uint256 maxBorrowAmount = _convertValueToAmount(
        spoke,
        reserveId,
        _getRequiredDebtValueForHf(spoke, liquidator, Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD)
      );
      if (maxBorrowAmount == 0) {
        break;
      }
      uint256 amount = vm.randomUint(1, maxBorrowAmount);
      _increaseReserveDebt(spoke, reserveId, amount, liquidator);
      skip(365 days);
    }

    // make liquidator unhealthy now, but might get healthy when liquidation happens
    liquidatorAccountData = spoke.getUserAccountData(liquidator);
    if (liquidatorAccountData.healthFactor > Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      _makeUserLiquidatable(
        spoke,
        liquidator,
        vm.randomUint(0, spoke.getReserveCount() - 1),
        vm.randomUint(0.01e18, Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.0000001e18)
      );
    }
  }
}
