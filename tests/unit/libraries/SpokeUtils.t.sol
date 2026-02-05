// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeUtilsTest is SpokeBase {
  SpokeUtilsWrapper internal w;

  ISpoke.Reserve reserve0;
  ISpoke.Reserve reserve1;
  ISpoke.Reserve reserve2;

  function setUp() public virtual override {
    super.setUp();

    w = new SpokeUtilsWrapper();

    reserve0 = ISpoke.Reserve({
      underlying: address(tokenList.usdx),
      hub: IHubBase(address(1)),
      assetId: 1,
      decimals: 6,
      dynamicConfigKey: 0,
      collateralRisk: 10_00,
      flags: ReserveFlagsMap.create(false, false, true, true)
    });

    reserve1 = ISpoke.Reserve({
      underlying: address(tokenList.weth),
      hub: IHubBase(address(2)),
      assetId: 2,
      decimals: 18,
      dynamicConfigKey: 3,
      collateralRisk: 15_00,
      flags: ReserveFlagsMap.create(false, false, true, true)
    });

    reserve2 = ISpoke.Reserve({
      underlying: address(tokenList.dai),
      hub: IHubBase(address(0)),
      assetId: 3,
      decimals: 18,
      dynamicConfigKey: 1,
      collateralRisk: 20_00,
      flags: ReserveFlagsMap.create(false, false, true, true)
    });
  }

  function _populateReserves() public {
    w.setReserve(0, reserve0);
    w.setReserve(1, reserve1);
    w.setReserve(2, reserve2);
  }

  function test_get_revertsWith_ReserveNotListed() public {
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    w.get(0);
    _populateReserves();
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    w.get(2);
  }

  function test_get() public {
    _populateReserves();
    assertEq(w.get(0), reserve0);
    assertEq(w.get(1), reserve1);
  }

  // Reverts if asset uses more than 18 decimals.
  function test_toValue_revertsWith_ArithmeticUnderflow() public {
    vm.expectRevert(stdError.arithmeticError);
    w.toValue(1, 19, 1e8);
  }

  // Reverts if multiplication overflows.
  function test_toValue_revertsWith_ArithmeticOverflow() public {
    vm.expectRevert(stdError.arithmeticError);
    w.toValue(1e50, 6, 1e16);
  }

  function test_toValue() public view {
    assertEq(w.toValue(4.2e6, 6, 200e8), 840e26);
  }

  function test_fuzz_toValue(uint256 amount, uint256 decimals, uint256 price) public view {
    amount = bound(amount, 0, MAX_SUPPLY_AMOUNT);
    decimals = bound(decimals, MIN_TOKEN_DECIMALS_SUPPORTED, MAX_TOKEN_DECIMALS_SUPPORTED);
    price = bound(price, 0, MAX_ASSET_PRICE);
    assertEq(w.toValue(amount, decimals, price), amount * price * (10 ** (18 - decimals)));
  }
}
