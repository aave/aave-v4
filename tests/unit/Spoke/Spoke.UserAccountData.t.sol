// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeUserAccountDataTest is SpokeBase {
  address internal user = makeAddr('user');
  MockSpoke internal spoke;

  MockSpoke.AccountDataInfo internal accountDataInfo;

  function setUp() public override {
    super.setUp();
    spoke = MockSpoke(address(spoke1));
    address mockSpokeImpl = address(
      new MockSpoke(address(spoke.ORACLE()), Constants.MAX_ALLOWED_USER_RESERVES_LIMIT)
    );
    vm.etch(address(spoke1), mockSpokeImpl.code);

    _updateCollateralFactor(spoke, _wethReserveId(spoke), 80_00);
    _updateCollateralFactor(spoke, _wbtcReserveId(spoke), 70_00);
    _updateCollateralFactor(spoke, _usdxReserveId(spoke), 72_00);
    _updateCollateralFactor(spoke, _daiReserveId(spoke), 75_00);

    _updateCollateralRisk(spoke, _wethReserveId(spoke), 5_00);
    _updateCollateralRisk(spoke, _wbtcReserveId(spoke), 15_00);
    _updateCollateralRisk(spoke, _usdxReserveId(spoke), 10_00);
    _updateCollateralRisk(spoke, _daiReserveId(spoke), 12_00);
  }

  // Simple scenario: 1 collateral, 1 debt, no refresh config, latest config key
  function test_userAccountData_scenario1() public {
    // Collateral: 100 USDX
    // Debt: 0.025 + 0.005 + 0.0075 = 0.0375 WETH = 0.0375 * $2000 = $75
    // Health Factor: $100 * 0.72 / $75 = 0.96
    // Avg Collateral Factor: 72%
    // Risk Premium: 10%
    // Supplied Collaterals Count: 1
    // Borrowed Reserves Count: 1
    accountDataInfo.collateralReserveIds.push(_usdxReserveId(spoke));
    accountDataInfo.collateralAmounts.push(100e6);
    accountDataInfo.collateralDynamicConfigKeys.push(
      _getLastReserveConfigKey(_usdxReserveId(spoke))
    );
    accountDataInfo.debtReserveIds.push(_wethReserveId(spoke));
    accountDataInfo.drawnDebtAmounts.push(0.025e18);
    accountDataInfo.realizedPremiumAmountsRay.push(0.005e18 * WadRayMath.RAY);
    accountDataInfo.accruedPremiumAmounts.push(0.0075e18);

    _checkedUserAccountData(
      false,
      ISpoke.UserAccountData({
        totalCollateralValue: 100e26,
        totalDebtValue: 75e26,
        avgCollateralFactor: 0.72e18,
        healthFactor: 0.96e18,
        riskPremium: 10_00,
        activeCollateralCount: 1,
        borrowCount: 1
      })
    );
  }

  // 1 collateral, 1 debt, no refresh config, old config key
  function test_userAccountData_scenario2() public {
    uint256 configKeyBefore = _getLastReserveConfigKey(_usdxReserveId(spoke));
    _updateCollateralFactor(spoke, _usdxReserveId(spoke), 80_00);

    // Collateral: 100 USDX
    // Debt: 0.025 + 0.005 + 0.0075 = 0.0375 WETH = 0.0375 * $2000 = $75
    // Health Factor: $100 * 0.72 / $75 = 0.96
    // Avg Collateral Factor: 72%
    // Risk Premium: 10%
    // Supplied Collaterals Count: 1
    // Borrowed Reserves Count: 1
    accountDataInfo.collateralReserveIds.push(_usdxReserveId(spoke));
    accountDataInfo.collateralAmounts.push(100e6);
    accountDataInfo.collateralDynamicConfigKeys.push(configKeyBefore);
    accountDataInfo.debtReserveIds.push(_wethReserveId(spoke));
    accountDataInfo.drawnDebtAmounts.push(0.025e18);
    accountDataInfo.realizedPremiumAmountsRay.push(0.005e18 * WadRayMath.RAY);
    accountDataInfo.accruedPremiumAmounts.push(0.0075e18);

    _checkedUserAccountData(
      false,
      ISpoke.UserAccountData({
        totalCollateralValue: 100e26,
        totalDebtValue: 75e26,
        avgCollateralFactor: 0.72e18,
        healthFactor: 0.96e18,
        riskPremium: 10_00,
        activeCollateralCount: 1,
        borrowCount: 1
      })
    );
  }

  // 1 collateral, 1 debt, refresh config, old config key
  function test_userAccountData_scenario3() public {
    uint256 configKeyBefore = _getLastReserveConfigKey(_usdxReserveId(spoke));
    _updateCollateralFactor(spoke, _usdxReserveId(spoke), 96_00);

    // Collateral: 100 USDX
    // Debt: 0.025 + 0.005 + 0.0075 = 0.0375 WETH = 0.0375 * $2000 = $75
    // Health Factor: $100 * 0.96 / $75 = 1.28
    // Avg Collateral Factor: 96%
    // Risk Premium: 10%
    // Supplied Collaterals Count: 1
    // Borrowed Reserves Count: 1
    accountDataInfo.collateralReserveIds.push(_usdxReserveId(spoke));
    accountDataInfo.collateralAmounts.push(100e6);
    accountDataInfo.collateralDynamicConfigKeys.push(configKeyBefore);
    accountDataInfo.debtReserveIds.push(_wethReserveId(spoke));
    accountDataInfo.drawnDebtAmounts.push(0.025e18);
    accountDataInfo.realizedPremiumAmountsRay.push(0.005e18 * WadRayMath.RAY);
    accountDataInfo.accruedPremiumAmounts.push(0.0075e18);

    _checkedUserAccountData(
      true,
      ISpoke.UserAccountData({
        totalCollateralValue: 100e26,
        totalDebtValue: 75e26,
        avgCollateralFactor: 0.96e18,
        healthFactor: 1.28e18,
        riskPremium: 10_00,
        activeCollateralCount: 1,
        borrowCount: 1
      })
    );
  }

  // 2 collaterals, 1 other supplied asset, 1 debt, refresh config, old config key
  function test_userAccountData_scenario4() public {
    uint256 usdxConfigKeyBefore = _getLastReserveConfigKey(_usdxReserveId(spoke));
    uint256 wbtcConfigKeyBefore = _getLastReserveConfigKey(_wbtcReserveId(spoke));
    _updateCollateralFactor(spoke, _usdxReserveId(spoke), 96_00);
    _updateCollateralFactor(spoke, _wbtcReserveId(spoke), 50_00);

    // Collateral: 100 USDX, 0.1 WBTC = 0.1 * $50000 = $5000
    // Supplied Assets: 1 WETH
    // Debt: 0.3 + 0.15 + 0.05 = 0.5 WETH = 0.5 * $2000 = $1000
    // Health Factor: ($100 * 0.96 + $5000 * 0.5) / $1000 = 2.596
    // Avg Collateral Factor: (0.96 * $100 + 0.5 * $5000) / ($100 + $5000) = 0.509019608
    // Risk Premium: (0.1 * $100 + 0.15 * $900) / $1000 = 0.145
    // Supplied Collaterals Count: 2
    // Borrowed Reserves Count: 1
    accountDataInfo.collateralReserveIds.push(_usdxReserveId(spoke));
    accountDataInfo.collateralAmounts.push(100e6);
    accountDataInfo.collateralDynamicConfigKeys.push(usdxConfigKeyBefore);
    accountDataInfo.collateralReserveIds.push(_wbtcReserveId(spoke));
    accountDataInfo.collateralAmounts.push(0.1e8);
    accountDataInfo.collateralDynamicConfigKeys.push(wbtcConfigKeyBefore);
    accountDataInfo.suppliedAssetsReserveIds.push(_wethReserveId(spoke));
    accountDataInfo.suppliedAssetsAmounts.push(1e18);
    accountDataInfo.debtReserveIds.push(_wethReserveId(spoke));
    accountDataInfo.drawnDebtAmounts.push(0.3e18);
    accountDataInfo.realizedPremiumAmountsRay.push(0.15e18 * WadRayMath.RAY);
    accountDataInfo.accruedPremiumAmounts.push(0.05e18);

    _checkedUserAccountData(
      true,
      ISpoke.UserAccountData({
        totalCollateralValue: 5100e26,
        totalDebtValue: 1000e26,
        avgCollateralFactor: 0.509019608e18,
        healthFactor: 2.596e18,
        riskPremium: 14_50,
        activeCollateralCount: 2,
        borrowCount: 1
      })
    );
  }

  // in deficit, 2 collaterals (one empty), 2 debts, no refresh config, latest config key
  function test_userAccountData_scenario5() public {
    // Collateral: 100 USDX
    // Debt: 0.0375 WETH = 0.0375 * $2000 = $75, 0.001 WBTC = 0.001 * $50000 = $50
    // Health Factor: $100 * 0.72 / $125 = 0.576
    // Avg Collateral Factor: 72%
    // Risk Premium: 10%
    // Supplied Collaterals Count: 1
    // Borrowed Reserves Count: 2
    accountDataInfo.collateralReserveIds.push(_usdxReserveId(spoke));
    accountDataInfo.collateralAmounts.push(100e6);
    accountDataInfo.collateralDynamicConfigKeys.push(
      _getLastReserveConfigKey(_usdxReserveId(spoke))
    );
    accountDataInfo.collateralReserveIds.push(_wbtcReserveId(spoke));
    accountDataInfo.collateralAmounts.push(0);
    accountDataInfo.collateralDynamicConfigKeys.push(
      _getLastReserveConfigKey(_wbtcReserveId(spoke))
    );
    accountDataInfo.debtReserveIds.push(_wethReserveId(spoke));
    accountDataInfo.drawnDebtAmounts.push(0.025e18);
    accountDataInfo.realizedPremiumAmountsRay.push(0.005e18 * WadRayMath.RAY);
    accountDataInfo.accruedPremiumAmounts.push(0.0075e18);
    accountDataInfo.debtReserveIds.push(_wbtcReserveId(spoke));
    accountDataInfo.drawnDebtAmounts.push(0.001e8);
    accountDataInfo.realizedPremiumAmountsRay.push(0 * WadRayMath.RAY);
    accountDataInfo.accruedPremiumAmounts.push(0);

    _checkedUserAccountData(
      false,
      ISpoke.UserAccountData({
        totalCollateralValue: 100e26,
        totalDebtValue: 125e26,
        avgCollateralFactor: 0.72e18,
        healthFactor: 0.576e18,
        riskPremium: 10_00,
        activeCollateralCount: 1,
        borrowCount: 2
      })
    );
  }

  // 2 collaterals (one with collateral factor 0), 1 debt, no refresh config, latest config key
  function test_userAccountData_scenario6() public {
    _updateCollateralFactor(spoke, _wbtcReserveId(spoke), 0);

    // Collateral: 100 USDX
    // Debt: 0.0375 WETH = 0.0375 * $2000 = $75
    // Health Factor: $100 * 0.72 / $75 = 0.96
    // Avg Collateral Factor: 72%
    // Risk Premium: 10%
    // Supplied Collaterals Count: 1
    // Borrowed Reserves Count: 1
    accountDataInfo.collateralReserveIds.push(_usdxReserveId(spoke));
    accountDataInfo.collateralAmounts.push(100e6);
    accountDataInfo.collateralDynamicConfigKeys.push(
      _getLastReserveConfigKey(_usdxReserveId(spoke))
    );
    accountDataInfo.collateralReserveIds.push(_wbtcReserveId(spoke));
    accountDataInfo.collateralAmounts.push(1e8);
    accountDataInfo.collateralDynamicConfigKeys.push(
      _getLastReserveConfigKey(_wbtcReserveId(spoke))
    );
    accountDataInfo.debtReserveIds.push(_wethReserveId(spoke));
    accountDataInfo.drawnDebtAmounts.push(0.025e18);
    accountDataInfo.realizedPremiumAmountsRay.push(0.005e18 * WadRayMath.RAY);
    accountDataInfo.accruedPremiumAmounts.push(0.0075e18);

    _checkedUserAccountData(
      false,
      ISpoke.UserAccountData({
        totalCollateralValue: 100e26,
        totalDebtValue: 75e26,
        avgCollateralFactor: 0.72e18,
        healthFactor: 0.96e18,
        riskPremium: 10_00,
        activeCollateralCount: 1,
        borrowCount: 1
      })
    );
  }

  function _checkedUserAccountData(
    bool refreshConfig,
    ISpoke.UserAccountData memory expectedUserAccountData
  ) internal {
    spoke.mockStorage(user, accountDataInfo);

    ISpoke.UserAccountData memory userAccountData = spoke.calculateUserAccountData(
      user,
      refreshConfig
    );
    assertApproxEq(userAccountData, expectedUserAccountData);
  }

  function _getLastReserveConfigKey(uint256 reserveId) internal view returns (uint24) {
    return spoke.getReserve(reserveId).dynamicConfigKey;
  }

  function assertApproxEq(
    ISpoke.UserAccountData memory a,
    ISpoke.UserAccountData memory b
  ) internal pure {
    assertEq(a.totalCollateralValue, b.totalCollateralValue, 'totalCollateralValue');
    assertEq(a.totalDebtValue, b.totalDebtValue, 'totalDebtValue');
    assertApproxEqAbs(a.avgCollateralFactor, b.avgCollateralFactor, 1e12, 'avgCollateralFactor');
    assertApproxEqAbs(a.healthFactor, b.healthFactor, 1e12, 'healthFactor');
    assertApproxEqAbs(a.riskPremium, b.riskPremium, 1, 'riskPremium');
    assertEq(a.activeCollateralCount, b.activeCollateralCount, 'activeCollateralCount');
    assertEq(a.borrowCount, b.borrowCount, 'borrowCount');
  }
}
