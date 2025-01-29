// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {LiquidityHub, Asset} from 'src/contracts/LiquidityHub.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import '../mocks/MockPriceOracle.sol';
import '../mocks/MockERC20.sol';
import '../Utils.t.sol';
import 'src/contracts/DefaultReserveInterestRateStrategy.sol';

contract LiquidityHubHandler is Test {
  IERC20 public usdc;
  IERC20 public dai;
  IERC20 public usdt;

  IPriceOracle public oracle;
  LiquidityHub public hub;
  Spoke public bm;
  DefaultReserveInterestRateStrategy creditLineIRStrategy;

  address internal mockAddressesProvider = makeAddr('mockAddressesProvider');

  struct State {
    mapping(uint256 => uint256) reserveSupplied; // asset => supply
    mapping(uint256 => mapping(address => uint256)) userSupplied; // asset => user => supply
    mapping(address => uint256) assetDonated; // asset => donation
    mapping(uint256 => uint256) lastExchangeRate; // asset => supplyIndex
  }

  State internal s;

  constructor() {
    creditLineIRStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
    oracle = new MockPriceOracle();
    hub = new LiquidityHub();
    bm = new Spoke(address(hub), address(oracle));
    usdc = new MockERC20();
    dai = new MockERC20();
    usdt = new MockERC20();

    // Add dai
    hub.addAsset(
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(0)}),
      address(dai)
    );
    bm.addReserve(
      0,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: false, collateral: false}),
      address(dai)
    );
  }

  function getReserveSupplied(uint256 assetId) public view returns (uint256) {
    return s.reserveSupplied[assetId];
  }

  function getUserSupplied(uint256 assetId, address user) public view returns (uint256) {
    return s.userSupplied[assetId][user];
  }

  function getAssetDonated(address asset) public view returns (uint256) {
    return s.assetDonated[asset];
  }

  function getLastExchangeRate(uint256 assetId) public view returns (uint256) {
    return s.lastExchangeRate[assetId];
  }

  function supply(uint256 assetId, address user, uint256 amount, address onBehalfOf) public {
    vm.assume(user != address(hub) && user != address(0) && onBehalfOf != address(0));
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    IERC20 asset = hub.assetsList(assetId);
    deal(address(asset), user, amount);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(bm),
      amount: amount,
      riskPremiumRad: 0,
      user: user,
      to: onBehalfOf
    });

    _updateState(assetId);
    s.reserveSupplied[assetId] += amount;
    s.userSupplied[assetId][onBehalfOf] += amount;
  }

  function withdraw(uint256 assetId, address user, uint256 amount, address to) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    // TODO: bound by bm user balance
    amount = bound(amount, 1, 2);

    Utils.withdraw({
      hub: hub,
      assetId: assetId,
      spoke: address(bm),
      amount: amount,
      riskPremiumRad: 0,
      to: to
    });

    _updateState(assetId);
    s.reserveSupplied[assetId] -= amount;
    s.userSupplied[assetId][user] -= amount;
  }

  function donate(uint256 assetId, address user, uint256 amount) public {
    vm.assume(user != address(hub) && user != address(0));
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    IERC20 asset = hub.assetsList(assetId);

    deal(address(asset), user, amount);
    vm.prank(user);
    asset.transfer(address(hub), amount);

    s.assetDonated[address(asset)] += amount;
  }

  function _updateState(uint256 assetId) internal {
    Asset memory reserveData = hub.getAsset(assetId);
    // todo: remove last exchange rate, bad idea to store like this, looses precision
    s.lastExchangeRate[assetId] = reserveData.suppliedShares == 0
      ? 0
      : hub.getTotalAssets(assetId) / reserveData.suppliedShares;
  }
}
