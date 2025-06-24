// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {ITreasurySpoke} from 'src/interfaces/ITreasurySpoke.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

library Utils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // hub
  function add(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    address user,
    address to // todo: implement
  ) internal returns (uint256) {
    vm.startPrank(user);
    hub.assetsList(assetId).approve(address(hub), amount);
    vm.stopPrank();

    vm.prank(spoke);
    uint256 sharesAdded = hub.add(assetId, amount, user);

    checkBorrowRateInvariant(hub, assetId, 'hub.add');

    return sharesAdded;
  }

  function draw(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    address to,
    uint256 amount,
    address onBehalfOf // todo: implement
  ) internal returns (uint256) {
    vm.prank(spoke);
    uint256 drawnShares = hub.draw(assetId, amount, to);

    checkBorrowRateInvariant(hub, assetId, 'hub.draw');

    return drawnShares;
  }

  function remove(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    address to
  ) internal returns (uint256) {
    vm.prank(spoke);
    uint256 removedShares = hub.remove(assetId, amount, to);

    checkBorrowRateInvariant(hub, assetId, 'hub.remove');

    return removedShares;
  }

  function restore(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 baseAmount,
    uint256 premiumAmount,
    address repayer
  ) internal returns (uint256) {
    vm.startPrank(repayer);
    hub.assetsList(assetId).approve(address(hub), (baseAmount + premiumAmount));
    vm.stopPrank();

    vm.prank(spoke);
    uint256 restoredBaseShares = hub.restore(assetId, baseAmount, premiumAmount, repayer);

    checkBorrowRateInvariant(hub, assetId, 'hub.restore');

    return restoredBaseShares;
  }

  // spoke
  function supply(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(user);
    spoke.supply(reserveId, amount);

    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    checkBorrowRateInvariant(reserve.config.hub, reserve.assetId, 'spoke.supply');
  }

  function supply(ITreasurySpoke spoke, uint256 reserveId, address user, uint256 amount) internal {
    vm.prank(user);
    spoke.supply(reserveId, amount);

    checkBorrowRateInvariant(spoke.HUB(), reserveId, 'treasurySpoke.supply');
  }

  function supplyCollateral(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    supply(spoke, reserveId, user, amount, onBehalfOf);
    vm.prank(user);
    spoke.setUsingAsCollateral(reserveId, true);

    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    checkBorrowRateInvariant(reserve.config.hub, reserve.assetId, 'spoke.setUsingAsCollateral');
  }

  function withdraw(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(user);
    spoke.withdraw(reserveId, amount, user);

    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    checkBorrowRateInvariant(reserve.config.hub, reserve.assetId, 'spoke.withdraw');
  }

  function withdraw(
    ITreasurySpoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount
  ) internal {
    vm.prank(user);
    spoke.withdraw(reserveId, amount, user);

    checkBorrowRateInvariant(spoke.HUB(), reserveId, 'treasurySpoke.withdraw');
  }

  function borrow(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(user);
    spoke.borrow(reserveId, amount, user);

    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    checkBorrowRateInvariant(reserve.config.hub, reserve.assetId, 'spoke.borrow');
  }

  function repay(ISpoke spoke, uint256 reserveId, address user, uint256 amount) internal {
    vm.prank(user);
    spoke.repay(reserveId, amount);

    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    checkBorrowRateInvariant(reserve.config.hub, reserve.assetId, 'spoke.repay');
  }

  function checkBorrowRateInvariant(
    ILiquidityHub hub,
    uint256 assetId,
    string memory operation
  ) internal {
    DataTypes.Asset memory asset = hub.getAsset(assetId);
    (uint256 baseDebt, ) = hub.getAssetDebt(assetId);

    vm.assertEq(
      asset.baseBorrowRate,
      asset.config.irStrategy.calculateInterestRate(
        assetId,
        asset.availableLiquidity,
        baseDebt,
        0,
        0
      ),
      string.concat('base borrow rate after ', operation)
    );
  }
}
