// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import 'src/contracts/LiquidityHub.sol';
import 'src/dependencies/openzeppelin/IERC20.sol';
import '../mocks/ERC20Mock.sol';
import '../Utils.t.sol';

contract LiquidityHubHandler is Test {
  IERC20 public usdc;
  IERC20 public dai;
  IERC20 public usdt;

  LiquidityHub public hub;

  struct State {
    mapping(uint256 => uint256) reserveSupplied; // asset => supply
    mapping(uint256 => mapping(address => uint256)) userSupplied; // asset => user => supply
    mapping(address => uint256) assetDonated; // asset => donation
  }

  State internal s;

  constructor() {
    hub = new LiquidityHub();
    usdc = new ERC20Mock();
    dai = new ERC20Mock();
    usdt = new ERC20Mock();

    // Add dai
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(0),
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

  function supply(uint256 assetId, uint256 userInt, uint256 amount, uint256 onBehalfOfInt) public {
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    userInt = bound(userInt, 1, type(uint160).max);
    onBehalfOfInt = bound(onBehalfOfInt, 1, type(uint160).max);
    amount = bound(amount, 0, type(uint128).max);

    address user = address(uint160(userInt));
    address onBehalfOf = address(uint160(onBehalfOfInt));
    address asset = hub.reservesList(assetId);

    if (amount > 0) {
      deal(asset, user, amount);

      Utils.supply(vm, hub, assetId, user, amount, onBehalfOf);

      s.reserveSupplied[assetId] += amount;
      s.userSupplied[assetId][onBehalfOf] += amount;
    }
  }

  function withdraw(uint256 assetId, uint256 userInt, uint256 amount, uint256 toInt) public {
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    userInt = bound(userInt, 1, type(uint160).max);
    toInt = bound(toInt, 1, type(uint160).max);

    address user = address(uint160(userInt));
    address to = address(uint160(toInt));
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, user);
    amount = bound(amount, 0, userData.principalBalance);

    if (amount > 0) {
      Utils.withdraw(vm, hub, assetId, user, amount, to);

      s.reserveSupplied[assetId] -= amount;
      s.userSupplied[assetId][user] -= amount;
    }
  }

  function donate(uint256 assetId, uint256 userInt, uint256 amount) public {
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    userInt = bound(userInt, 1, type(uint160).max);
    amount = bound(amount, 0, type(uint128).max);

    address user = address(uint160(userInt));
    address asset = hub.reservesList(assetId);

    deal(asset, user, amount);
    vm.startPrank(user);

    IERC20(asset).transfer(address(hub), amount);

    s.assetDonated[asset] += amount;

    vm.stopPrank();
  }
}
