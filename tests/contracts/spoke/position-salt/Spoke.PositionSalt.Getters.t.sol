// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokePositionSaltGettersTest is Base {
  bytes32 internal constant SALT_A = keccak256('position-salt-a');

  function test_getters_readSaltedPosition() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    // default position holds only a dai supply
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: 200e18,
      onBehalfOf: bob
    });

    // salted position holds weth collateral and a dai borrow
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: bob,
      amount: 10e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    skip(365 days);

    (bool usingColl, ) = spoke1.getUserReserveStatus(wethReserveId, bob, SALT_A);
    (, bool borrowing) = spoke1.getUserReserveStatus(daiReserveId, bob, SALT_A);
    assertTrue(usingColl);
    assertTrue(borrowing);
    (bool defaultUsingColl, bool defaultBorrowing) = spoke1.getUserReserveStatus(
      wethReserveId,
      bob
    );
    assertFalse(defaultUsingColl);
    assertFalse(defaultBorrowing);

    assertEq(
      spoke1.getUserSuppliedShares(wethReserveId, bob, SALT_A),
      spoke1.getUserPosition(wethReserveId, bob, SALT_A).suppliedShares
    );
    assertGt(spoke1.getUserSuppliedAssets(wethReserveId, bob, SALT_A), 0);
    assertEq(spoke1.getUserSuppliedShares(wethReserveId, bob), 0);

    (uint256 drawn, uint256 premium) = spoke1.getUserDebt(daiReserveId, bob, SALT_A);
    assertGt(drawn, 0);
    assertGt(premium, 0);
    assertEq(spoke1.getUserTotalDebt(daiReserveId, bob, SALT_A), drawn + premium);
    assertGt(spoke1.getUserPremiumDebtRay(daiReserveId, bob, SALT_A), 0);
    (uint256 defaultDrawn, ) = spoke1.getUserDebt(daiReserveId, bob);
    assertEq(defaultDrawn, 0);
    assertEq(spoke1.getUserTotalDebt(daiReserveId, bob), 0);

    ISpoke.UserAccountData memory saltedAccountData = spoke1.getUserAccountData(bob, SALT_A);
    assertGt(saltedAccountData.totalDebtValueRay, 0);
    assertGt(saltedAccountData.riskPremium, 0);
    assertEq(spoke1.getUserAccountData(bob).totalDebtValueRay, 0);

    assertGt(spoke1.getUserLastRiskPremium(bob, SALT_A), 0);
    assertEq(spoke1.getUserLastRiskPremium(bob), 0);
  }

  function test_getters_defaultSaltEquivalence() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: bob,
      amount: 10e18,
      onBehalfOf: bob
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob
    });
    skip(365 days);

    (bool collateral, bool borrowing) = spoke1.getUserReserveStatus(daiReserveId, bob);
    (bool collateralSalt, bool borrowingSalt) = spoke1.getUserReserveStatus(
      daiReserveId,
      bob,
      bytes32(0)
    );
    assertEq(collateral, collateralSalt);
    assertEq(borrowing, borrowingSalt);

    assertEq(
      spoke1.getUserSuppliedShares(wethReserveId, bob),
      spoke1.getUserSuppliedShares(wethReserveId, bob, bytes32(0))
    );
    assertEq(
      spoke1.getUserSuppliedAssets(wethReserveId, bob),
      spoke1.getUserSuppliedAssets(wethReserveId, bob, bytes32(0))
    );

    (uint256 drawn, uint256 premium) = spoke1.getUserDebt(daiReserveId, bob);
    (uint256 drawnSalt, uint256 premiumSalt) = spoke1.getUserDebt(daiReserveId, bob, bytes32(0));
    assertEq(drawn, drawnSalt);
    assertEq(premium, premiumSalt);
    assertEq(
      spoke1.getUserTotalDebt(daiReserveId, bob),
      spoke1.getUserTotalDebt(daiReserveId, bob, bytes32(0))
    );
    assertEq(
      spoke1.getUserPremiumDebtRay(daiReserveId, bob),
      spoke1.getUserPremiumDebtRay(daiReserveId, bob, bytes32(0))
    );
    assertEq(
      spoke1.getUserPosition(daiReserveId, bob),
      spoke1.getUserPosition(daiReserveId, bob, bytes32(0))
    );
    assertEq(spoke1.getUserLastRiskPremium(bob), spoke1.getUserLastRiskPremium(bob, bytes32(0)));
    assertEq(spoke1.getUserAccountData(bob), spoke1.getUserAccountData(bob, bytes32(0)));

    uint256 healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1;
    assertEq(
      spoke1.getLiquidationBonus(wethReserveId, bob, healthFactor),
      spoke1.getLiquidationBonus(wethReserveId, bob, bytes32(0), healthFactor)
    );
  }

  function test_getUserAccountData_fuzz_salt(bytes32 salt, uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1e18, MAX_SUPPLY_AMOUNT);
    uint256 reserveId = _daiReserveId(spoke1);
    deal(address(tokenList.dai), bob, supplyAmount);

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob,
      positionSalt: salt
    });

    ISpoke.UserAccountData memory accountData = spoke1.getUserAccountData(bob, salt);
    assertEq(accountData.totalDebtValueRay, 0);
    assertGt(accountData.totalCollateralValue, 0);
    assertEq(
      spoke1.getUserSuppliedShares(reserveId, bob, salt),
      hub1.previewAddByAssets(daiAssetId, supplyAmount)
    );

    bytes32 otherSalt = bytes32(uint256(salt) ^ 1);
    assertEq(spoke1.getUserAccountData(bob, otherSalt).totalCollateralValue, 0);
    assertEq(spoke1.getUserSuppliedShares(reserveId, bob, otherSalt), 0);
  }

  function test_getLiquidationBonus_fuzz_salt(bytes32 salt, uint256 healthFactor) public {
    uint256 reserveId = _daiReserveId(spoke1);
    healthFactor = bound(healthFactor, 0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    assertEq(
      spoke1.getLiquidationBonus(reserveId, bob, salt, healthFactor),
      spoke1.getLiquidationBonus(reserveId, bob, healthFactor)
    );
  }
}
