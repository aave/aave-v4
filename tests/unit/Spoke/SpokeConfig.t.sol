// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_updateReserveConfig() public {
    uint256 daiReserveId = daiReserveId(spoke1);
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
    emit ISpoke.ReserveConfigUpdated(
      daiReserveId,
      newReserveConfig.active,
      newReserveConfig.frozen,
      newReserveConfig.paused,
      newReserveConfig.collateralFactor,
      newReserveConfig.liquidationBonus,
      newReserveConfig.liquidityPremium,
      newReserveConfig.borrowable,
      newReserveConfig.collateral
    );
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
    uint256 daiReserveId = daiReserveId(spoke1);
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
    uint256 daiReserveId = daiReserveId(spoke1);
    updateCollateralFlag(spoke1, daiReserveId, newCollateralFlag);

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(ISpoke.ReserveCannotBeUsedAsCollateral.selector, daiReserveId)
    );
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, usingAsCollateral);
  }

  function test_setUsingAsCollateral() public {
    bool newCollateralFlag = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    uint256 daiReserveId = daiReserveId(spoke1);

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
    uint256 daiReserveId = daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;

    config.liquidityPremium = PercentageMath.PERCENTAGE_FACTOR * 10 + 1;

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(ISpoke.InvalidLiquidityPremium.selector);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidReserve() public {
    uint256 invalidReserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory config;

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(ISpoke.InvalidReserve.selector);
    spoke1.updateReserveConfig(invalidReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_ReserveCannotBePaused() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.active = false;

    // supply some DAI to the reserve to prevent setting reserve inactive
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: daiReserveId,
      user: bob,
      amount: 100e18,
      onBehalfOf: bob
    });

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(ISpoke.ReserveCannotBeInactive.selector);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidCollateralFactor() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.collateralFactor = PercentageMath.PERCENTAGE_FACTOR + 1;

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidLiquidationBonus() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.liquidationBonus = PercentageMath.PERCENTAGE_FACTOR + 1;

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(ISpoke.InvalidLiquidationBonus.selector);
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

    vm.prank(SPOKE_ADMIN);
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveAdded(reserveId, wethAssetId);
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

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert();
    spoke1.addReserve(assetId, newReserveConfig);
  }

  function test_addReserve_revertsWith_InvalidReserveDecimals() public {
    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 19, // invalid decimals
      active: true,
      frozen: true,
      paused: true,
      collateralFactor: 10_00,
      liquidationBonus: 10_00,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(ISpoke.InvalidReserveDecimals.selector);
    spoke1.addReserve(wethAssetId, newReserveConfig);
  }
}
