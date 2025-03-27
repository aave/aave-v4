// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_updateReserveConfig() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.Reserve memory reserveData = spoke1.getReserve(daiReserveId);

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 10, // decimals won't get updated
      active: !reserveData.config.active,
      frozen: !reserveData.config.frozen,
      paused: !reserveData.config.paused,
      collateralFactor: reserveData.config.collateralFactor + 1,
      liquidationBonus: reserveData.config.liquidationBonus + 1,
      liquidityPremium: reserveData.config.liquidityPremium + 1,
      borrowable: !reserveData.config.borrowable,
      collateral: !reserveData.config.collateral
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    reserveData = spoke1.getReserve(daiReserveId);

    assertEq(
      reserveData.config.collateralFactor,
      newReserveConfig.collateralFactor,
      'wrong collateralFactor'
    );
    assertEq(
      reserveData.config.liquidationBonus,
      newReserveConfig.liquidationBonus,
      'wrong liquidationBonus'
    );
    assertEq(
      reserveData.config.liquidityPremium,
      newReserveConfig.liquidityPremium,
      'wrong liquidityPremium'
    );
    assertEq(reserveData.config.borrowable, newReserveConfig.borrowable, 'wrong borrowable');
    assertEq(reserveData.config.collateral, newReserveConfig.collateral, 'wrong collateral');
  }

  function test_updateReserveConfig_cannot_update_decimals() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;

    uint256 oldDecimals = config.decimals;
    uint256 newDecimals = 12;
    // new decimals value attempted
    assertNotEq(oldDecimals, newDecimals);

    // decimals should not update
    config.decimals = newDecimals;

    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);

    config = spoke1.getReserve(daiReserveId).config;
    assertEq(config.decimals, oldDecimals, 'wrong decimals');
  }

  function test_setUsingAsCollateral_revertsWith_ReserveCannotBeUsedAsCollateral() public {
    bool newCollateralFlag = false;
    bool usingAsCollateral = true;
    uint256 daiReserveId = _daiReserveId(spoke1);
    updateCollateralFlag(spoke1, daiReserveId, newCollateralFlag);

    vm.expectRevert(
      abi.encodeWithSelector(ISpoke.ReserveCannotBeUsedAsCollateral.selector, daiReserveId)
    );
    vm.prank(SPOKE_ADMIN);
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, usingAsCollateral);
  }

  function test_setUsingAsCollateral_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.frozen);
    vm.startPrank(SPOKE_ADMIN);

    // disallow when activating
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, true);

    // allow when deactivating
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, false);
  }

  function test_setUsingAsCollateral_revertsWith_ReserveNotActive() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    updateReserveActiveFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.prank(SPOKE_ADMIN);
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, true);
  }

  function test_setUsingAsCollateral_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(SPOKE_ADMIN);
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, true);
  }

  function test_setUsingAsCollateral() public {
    bool newCollateralFlag = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    uint256 daiReserveId = _daiReserveId(spoke1);

    // ensure DAI is allowed as collateral
    updateCollateralFlag(spoke1, daiReserveId, newCollateralFlag);

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, daiAmount);
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiAmount, bob);

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.UsingAsCollateral(daiReserveId, bob, usingAsCollateral);
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, usingAsCollateral);

    DataTypes.UserPosition memory userData = spoke1.getUserPosition(daiReserveId, bob);
    assertEq(userData.usingAsCollateral, usingAsCollateral, 'wrong usingAsCollateral');
  }

  function test_updateReserveConfig_revertsWith_InvalidLiquidityPremium() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;

    config.liquidityPremium = PercentageMath.PERCENTAGE_FACTOR * 10 + 1;

    vm.expectRevert(ISpoke.InvalidLiquidityPremium.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidReserve() public {
    uint256 invalidReserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory config;

    vm.expectRevert(ISpoke.InvalidReserve.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(invalidReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidCollateralFactor() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.collateralFactor = PercentageMath.PERCENTAGE_FACTOR + 1;

    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidLiquidationBonus() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.liquidationBonus = PercentageMath.PERCENTAGE_FACTOR + 1;

    vm.expectRevert(ISpoke.InvalidLiquidationBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_addReserve() public {
    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: true,
      paused: true,
      collateralFactor: 10_00,
      liquidationBonus: 10_00,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveAdded(reserveId, wethAssetId);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(wethAssetId, newReserveConfig);

    DataTypes.Reserve memory reserveData = spoke1.getReserve(reserveId);

    assertEq(
      reserveData.config.collateralFactor,
      newReserveConfig.collateralFactor,
      'wrong collateralFactor'
    );
    assertEq(reserveData.config.liquidationBonus, newReserveConfig.liquidationBonus, 'wrong lb');
    assertEq(
      reserveData.config.liquidityPremium,
      newReserveConfig.liquidityPremium,
      'wrong liquidityPremium'
    );
    assertEq(reserveData.config.borrowable, newReserveConfig.borrowable, 'wrong borrowable');
    assertEq(reserveData.config.collateral, newReserveConfig.collateral, 'wrong collateral');
  }

  function test_addReserve_reverts_invalid_assetId() public {
    uint256 assetId = hub.assetCount(); // invalid assetId

    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: true,
      paused: true,
      collateralFactor: 10_00,
      liquidationBonus: 10_00,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });

    vm.expectRevert(); // error from LH in reading invalid index from assetList array
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(assetId, newReserveConfig);
  }

  function test_addReserve_revertsWith_InvalidReserveDecimals() public {
    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, // invalid decimals
      active: true,
      frozen: true,
      paused: true,
      collateralFactor: 10_00,
      liquidationBonus: 10_00,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });

    vm.expectRevert(ISpoke.InvalidReserveDecimals.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(reserveId, newReserveConfig);
  }
}
