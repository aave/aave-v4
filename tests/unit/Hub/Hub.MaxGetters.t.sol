// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubMaxGettersTest is HubBase {
  using SharesMath for uint256;

  function test_maxAdd_returns_zero_spoke_inactive() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, address(spoke1), DataTypes.SpokeConfig(false, 0, 0));

    assertEq(hub1.maxAdd(assetId, address(spoke1)), 0);
  }

  function test_maxAdd_returns_zero_nonexistent_spoke() public {
    uint256 assetId = _randomAssetId(hub1);
    assertEq(hub1.maxAdd(assetId, address(0)), 0);
  }

  function test_maxAdd_returns_zero_invalid_asset() public {
    assertEq(hub1.maxAdd(hub1.getAssetCount() + 1, address(spoke1)), 0);
  }

  function test_maxAdd_returns_max_uint256_max_cap() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, 0)
    );

    assertEq(hub1.maxAdd(assetId, address(spoke1)), UINT256_MAX);
  }

  /// @dev When max cap, maxAdd always returns max uint256
  function test_maxAdd_fuzz_no_cap(uint256 addAmount) public {
    addAmount = bound(addAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, 0)
    );

    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);

    assertEq(hub1.maxAdd(assetId, address(spoke1)), UINT256_MAX);
  }

  function test_maxAdd_fuzz_returns_cap(uint256 addCap) public {
    uint256 assetId = _randomAssetId(hub1);
    uint8 decimals = hub1.getAsset(assetId).decimals;
    addCap = bound(addCap, 1, Constants.MAX_CAP - 1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, uint56(addCap), 0)
    );

    assertEq(hub1.maxAdd(assetId, address(spoke1)), addCap * 10 ** decimals);
  }

  /// @dev Returns the difference between a non-max cap and added assets
  function test_maxAdd_fuzz(uint256 addAmount) public {
    uint256 assetId = _randomAssetId(hub1);
    uint256 cap = Constants.MAX_CAP - 1;
    uint8 decimals = hub1.getAsset(assetId).decimals;
    addAmount = bound(addAmount, 1, cap * 10 ** decimals);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, address(spoke1), DataTypes.SpokeConfig(true, uint56(cap), 0));

    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);

    assertEq(hub1.maxAdd(assetId, address(spoke1)), cap * 10 ** decimals - addAmount);
  }

  function test_maxRemove_returns_zero_invalid_spoke() public {
    uint256 assetId = _randomAssetId(hub1);

    assertEq(hub1.maxRemove(assetId, address(0)), 0);
  }

  function test_maxRemove_returns_zero_invalid_asset() public {
    assertEq(hub1.maxRemove(hub1.getAssetCount() + 1, address(spoke1)), 0);
  }

  function test_maxRemove_returns_zero_spoke_inactive() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, address(spoke1), DataTypes.SpokeConfig(false, 0, 0));

    assertEq(hub1.maxRemove(assetId, address(spoke1)), 0);
  }

  function test_maxRemove_returns_zero_spoke_inactive_with_added_shares() public {
    uint256 assetId = _randomAssetId(hub1);
    uint256 addAmount = 10 ** hub1.getAsset(assetId).decimals;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, 0)
    );
    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, address(spoke1), DataTypes.SpokeConfig(false, 0, 0));

    assertEq(hub1.maxRemove(assetId, address(spoke1)), 0);
  }

  function test_maxRemove_fuzz_returns_added_amount(uint256 addAmount) public {
    uint256 assetId = _randomAssetId(hub1);
    addAmount = bound(addAmount, 1, MAX_SUPPLY_AMOUNT);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, 0)
    );

    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);

    assertEq(hub1.maxRemove(assetId, address(spoke1)), addAmount);
  }

  function test_maxDraw_returns_zero_spoke_inactive() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, address(spoke1), DataTypes.SpokeConfig(false, 0, 0));

    assertEq(hub1.maxDraw(assetId, address(spoke1)), 0);
  }

  function test_maxDraw_returns_zero_spoke_inactive_with_liquidity() public {
    uint256 assetId = _randomAssetId(hub1);
    uint256 addAmount = 10 ** hub1.getAsset(assetId).decimals;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, Constants.MAX_CAP)
    );
    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(false, Constants.MAX_CAP, Constants.MAX_CAP)
    );

    assertEq(hub1.maxDraw(assetId, address(spoke1)), 0);
  }

  function test_maxDraw_returns_zero_invalid_asset() public {
    assertEq(hub1.maxDraw(hub1.getAssetCount() + 1, address(spoke1)), 0);
  }

  function test_maxDraw_returns_zero_no_liquidity() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, Constants.MAX_CAP)
    );

    assertEq(hub1.maxDraw(assetId, address(spoke1)), 0);
  }

  function test_maxDraw_fuzz_returns_liquidity(uint256 addAmount) public {
    uint256 assetId = _randomAssetId(hub1);
    addAmount = bound(addAmount, 1, MAX_SUPPLY_AMOUNT);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, Constants.MAX_CAP)
    );

    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);

    assertEq(hub1.maxDraw(assetId, address(spoke1)), addAmount);
  }

  function test_maxDraw_fuzz_returns_cap_if_less_than_liquidity(uint256 addAmount) public {
    uint256 assetId = _randomAssetId(hub1);
    uint8 decimals = hub1.getAsset(assetId).decimals;
    addAmount = bound(addAmount, 2 * 10 ** decimals, MAX_SUPPLY_AMOUNT);
    uint56 drawCap = uint56(addAmount / (2 * 10 ** decimals) - 1);
    uint256 assetsCap = drawCap * 10 ** decimals;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, uint56(drawCap))
    );

    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);

    assertEq(hub1.maxDraw(assetId, address(spoke1)), assetsCap);
  }

  function test_maxDraw_fuzz_returns_liquidity(uint256 addAmount, uint256 drawAmount) public {
    uint256 assetId = _randomAssetId(hub1);
    uint56 drawCap = Constants.MAX_CAP - 1;
    uint256 assetsCap = drawCap * 10 ** hub1.getAsset(assetId).decimals;
    addAmount = bound(addAmount, 2, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, _min(addAmount, assetsCap));
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, uint56(drawCap))
    );

    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);
    Utils.draw(hub1, assetId, address(spoke1), alice, drawAmount);

    assertEq(
      hub1.maxDraw(assetId, address(spoke1)),
      _min(addAmount - drawAmount, assetsCap - drawAmount)
    );
  }

  function test_maxRestore_returns_zero_invalid_asset() public {
    assertEq(hub1.maxRestore(hub1.getAssetCount() + 1, address(spoke1)), 0);
  }

  function test_maxRestore_returns_zero_invalid_spoke() public {
    uint256 assetId = _randomAssetId(hub1);

    assertEq(hub1.maxRestore(assetId, address(0)), 0);
  }

  function test_maxRestore_returns_zero_spoke_inactive() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(false, Constants.MAX_CAP, Constants.MAX_CAP)
    );

    assertEq(hub1.maxRestore(assetId, address(spoke1)), 0);
  }

  function test_maxRestore_returns_zero_spoke_inactive_with_drawn() public {
    uint256 assetId = _randomAssetId(hub1);
    uint256 drawAmount = 10 ** hub1.getAsset(assetId).decimals;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, Constants.MAX_CAP)
    );
    Utils.add(hub1, assetId, address(spoke1), drawAmount, bob);
    Utils.draw(hub1, assetId, address(spoke1), alice, drawAmount);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(false, Constants.MAX_CAP, Constants.MAX_CAP)
    );

    assertEq(hub1.maxRestore(assetId, address(spoke1)), 0);
  }

  function test_maxRestore_fuzz_returns_drawn(uint256 drawAmount) public {
    uint256 assetId = _randomAssetId(hub1);
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, Constants.MAX_CAP)
    );

    Utils.add(hub1, assetId, address(spoke1), drawAmount, bob);
    Utils.draw(hub1, assetId, address(spoke1), alice, drawAmount);

    assertEq(hub1.maxRestore(assetId, address(spoke1)), drawAmount);
  }

  function test_maxRestore_fuzz_returns_spoke_total_owed(uint256 drawAmount) public {
    uint256 assetId = _randomAssetId(hub1);
    drawAmount = bound(drawAmount, 1, MAX_SUPPLY_AMOUNT);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, Constants.MAX_CAP)
    );

    Utils.add(hub1, assetId, address(spoke1), drawAmount, bob);
    Utils.draw(hub1, assetId, address(spoke1), alice, drawAmount);

    skip(322 days);

    assertEq(
      hub1.maxRestore(assetId, address(spoke1)),
      hub1.getSpokeTotalOwed(assetId, address(spoke1))
    );
  }
}
