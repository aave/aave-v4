// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {VaultAdapter} from 'src/misc/VaultAdapter.sol';

contract VaultSpokeTests is SpokeBase {
  using SafeCast for *;
  VaultAdapter internal adapter;

  uint256 internal vDaiReserveId;
  uint256 internal vUsdxReserveId;
  uint256 internal vWethReserveId;

  function setUp() public override {
    deployFixtures();
    initEnvironment();

    adapter = new VaultAdapter(address(hub));
    // make usdx, weth borrowable
    _registerAdapterOnHub({assetId: usdxAssetId, drawCap: 1_000_000e6});
    _registerAdapterOnHub({assetId: wethAssetId, drawCap: 1_000e18});

    // make dai, usdx, weth suppliable
    vDaiReserveId = _registerAdapterOnSpoke({assetId: daiAssetId, initPrice: 1.002e8});
    vUsdxReserveId = _registerAdapterOnSpoke({assetId: usdxAssetId, initPrice: 1.003e8});
    vWethReserveId = _registerAdapterOnSpoke({assetId: wethAssetId, initPrice: 2000e8});

    _approveTokensToAdapter(alice);
  }

  // for equivalent actions through adapter/vault/safe; onBehalfOf action needed such that locked collateral
  // balance are synced
  function test_supply_through_spoke() public {
    uint256 amount = 1000e6;
    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(alice, address(adapter), amount);
    vm.prank(alice);
    spoke1.supply(vUsdxReserveId, amount);
  }

  function test_withdraw_through_spoke() public {
    uint256 amount = 1000e6;
    Utils.supply(spoke1, vUsdxReserveId, alice, amount, alice);

    address rec = makeAddr('rec');
    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(adapter), rec, amount);
    vm.prank(alice);
    spoke1.withdraw(vUsdxReserveId, amount, rec);
  }

  function test_borrow_through_spoke() public {
    uint256 usdxBorrowAmount = 500e6;
    uint256 wethBorrowAmount = 0.1e18;
    // seed liquidity for underlying asset through arbitrary spoke on canonical hub
    _openSupplyPosition(spoke2, _usdxReserveId(spoke2), usdxBorrowAmount);
    _openSupplyPosition(spoke2, _wethReserveId(spoke2), wethBorrowAmount);

    // note: no callback to adapter on enabling as collateral, potential for sync mismatch which is fine since no yield
    Utils.supplyCollateral(spoke1, vUsdxReserveId, alice, 3000e6, alice);

    address rec = makeAddr('rec');
    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(hub), rec, usdxBorrowAmount);
    vm.prank(alice);
    spoke1.borrow(vUsdxReserveId, usdxBorrowAmount, rec);

    // borrow existing reserve
    vm.expectEmit(address(tokenList.weth));
    emit IERC20.Transfer(address(hub), rec, wethBorrowAmount);
    vm.prank(alice);
    spoke1.borrow(_wethReserveId(spoke1), wethBorrowAmount, rec);
  }

  function test_repay_through_spoke() public {
    test_borrow_through_spoke();
    skip(232 days);

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(alice, address(hub), 10e6);
    vm.prank(alice);
    spoke1.repay(vUsdxReserveId, 10e6);
  }

  function test_liquidate_through_spoke() public {
    test_borrow_through_spoke();
    _mockReservePriceByPercent(spoke1, vUsdxReserveId, 1);

    vm.prank(alice);
    spoke1.liquidationCall(vUsdxReserveId, _wethReserveId(spoke1), alice, 0.1e18);
  }

  function test_looping() public {
    _openSupplyPosition(spoke2, _usdxReserveId(spoke2), 2800e6);

    Utils.supplyCollateral(spoke1, vUsdxReserveId, alice, 3000e6, alice);
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 2800e6, alice);
  }

  function _registerAdapterOnHub(uint256 assetId, uint256 drawCap) internal {
    vm.startPrank(HUB_ADMIN);
    hub.addSpoke(
      assetId,
      address(adapter),
      DataTypes.SpokeConfig({active: true, supplyCap: 0, drawCap: drawCap})
    );
  }

  function _registerAdapterOnSpoke(
    uint256 assetId,
    uint256 initPrice
  ) internal returns (uint256 registeredReserveId) {
    vm.startPrank(SPOKE_ADMIN);
    registeredReserveId = spoke1.addReserve({
      assetId: assetId,
      hub: address(adapter),
      priceSource: _deployMockPriceFeed(spoke1, initPrice),
      config: DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        liquidityPremium: vm.randomUint(0, 100_00),
        liquidationFee: 0,
        borrowable: true,
        collateral: true
      }),
      dynConfig: DataTypes.DynamicReserveConfig({
        collateralFactor: vm.randomUint(70_00, 100_00).toUint16(),
        liquidationBonus: 100_00
      })
    });
    vm.stopPrank();
    return registeredReserveId;
  }

  function _approveTokensToAdapter(address who) internal {
    vm.startPrank(who);
    tokenList.weth.approve(address(adapter), type(uint256).max);
    tokenList.usdx.approve(address(adapter), type(uint256).max);
    tokenList.dai.approve(address(adapter), type(uint256).max);
    tokenList.wbtc.approve(address(adapter), type(uint256).max);
    tokenList.usdy.approve(address(adapter), type(uint256).max);
    vm.stopPrank();
  }
}
