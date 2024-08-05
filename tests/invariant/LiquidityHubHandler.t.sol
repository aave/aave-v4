// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import 'src/contracts/LiquidityHub.sol';
import 'src/contracts/BorrowModule.sol';
import 'src/dependencies/openzeppelin/IERC20.sol';
import '../mocks/ERC20Mock.sol';
import '../Utils.t.sol';

contract LiquidityHubHandler is Test {
  IERC20 public usdc;
  IERC20 public dai;
  IERC20 public usdt;

  LiquidityHub public hub;
  BorrowModule public bm;

  struct State {
    mapping(uint256 => uint256) reserveSupplied; // asset => supply
    mapping(uint256 => mapping(address => uint256)) userSupplied; // asset => user => supply
    mapping(address => uint256) assetDonated; // asset => donation
    mapping(uint256 => uint256) lastExchangeRate; // asset => supplyIndex
  }

  State internal s;

  constructor() {
    hub = new LiquidityHub();
    bm = new BorrowModule();
    usdc = new ERC20Mock();
    dai = new ERC20Mock();
    usdt = new ERC20Mock();

    // Add dai
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(bm),
        lt: 0,
        lb: 0,
        rf: 0,
        decimals: 18,
        active: true,
        borrowable: false,
        supplyCap: type(uint256).max,
        borrowCap: type(uint256).max
      }),
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
    if (user == address(hub) || user == address(0)) return;
    if (onBehalfOf == address(0)) return;
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    address asset = hub.reservesList(assetId);
    deal(asset, user, amount);
    Utils.supply(vm, hub, assetId, user, amount, onBehalfOf);

    _updateState(assetId);
    s.reserveSupplied[assetId] += amount;
    s.userSupplied[assetId][onBehalfOf] += amount;
  }

  function withdraw(uint256 assetId, address user, uint256 amount, address to) public {
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    amount = bound(amount, 1, hub.getUserBalance(assetId, user));

    Utils.withdraw(vm, hub, assetId, user, amount, to);

    _updateState(assetId);
    s.reserveSupplied[assetId] -= amount;
    s.userSupplied[assetId][user] -= amount;
  }

  function donate(uint256 assetId, address user, uint256 amount) public {
    if (user == address(hub) || user == address(0)) return;
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    address asset = hub.reservesList(assetId);

    deal(asset, user, amount);
    vm.prank(user);
    IERC20(asset).transfer(address(hub), amount);

    s.assetDonated[asset] += amount;
  }

  function _updateState(uint256 assetId) internal {
    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    s.lastExchangeRate[assetId] = reserveData.totalShares == 0
      ? 0
      : reserveData.totalAssets / reserveData.totalShares;
  }
}
