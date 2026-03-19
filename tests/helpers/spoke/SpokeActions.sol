// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

library SpokeActions {
  using SafeERC20 for *;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  CORE USER ACTIONS                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function setUsingAsCollateral(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    bool usingAsCollateral,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  function supply(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.supply(reserveId, amount, onBehalfOf);
  }

  function supplyCollateral(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    supply(spoke, reserveId, caller, amount, onBehalfOf);
    setUsingAsCollateral({
      spoke: spoke,
      reserveId: reserveId,
      caller: caller,
      usingAsCollateral: true,
      onBehalfOf: onBehalfOf
    });
  }

  function withdraw(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.withdraw(reserveId, amount, onBehalfOf);
  }

  function borrow(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.borrow(reserveId, amount, onBehalfOf);
  }

  function repay(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.repay(reserveId, amount, onBehalfOf);
  }

  function liquidationCall(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares,
    address caller
  ) internal {
    vm.prank(caller);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, debtToCover, receiveShares);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  CONFIG ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function updateReserveConfig(
    ISpoke spoke,
    uint256 reserveId,
    ISpoke.ReserveConfig memory config,
    address caller
  ) internal {
    vm.prank(caller);
    spoke.updateReserveConfig(reserveId, config);
  }

  function addDynamicReserveConfig(
    ISpoke spoke,
    uint256 reserveId,
    ISpoke.DynamicReserveConfig memory config,
    address caller
  ) internal returns (uint32) {
    vm.prank(caller);
    return spoke.addDynamicReserveConfig(reserveId, config);
  }

  function updateDynamicReserveConfig(
    ISpoke spoke,
    uint256 reserveId,
    uint32 key,
    ISpoke.DynamicReserveConfig memory config,
    address caller
  ) internal {
    vm.prank(caller);
    spoke.updateDynamicReserveConfig(reserveId, key, config);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  TOKEN HELPERS                                            //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function approve(ISpoke spoke, uint256 reserveId, address owner, uint256 amount) internal {
    address underlying = spoke.getReserve(reserveId).underlying;
    _approve({
      underlying: IERC20(underlying),
      owner: owner,
      spender: address(spoke),
      amount: amount
    });
  }

  function approve(ISpoke spoke, address underlying, address owner, uint256 amount) internal {
    _approve({
      underlying: IERC20(underlying),
      owner: owner,
      spender: address(spoke),
      amount: amount
    });
  }

  function approve(
    ISpoke spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    IHub hub = IHub(address(spoke.getReserve(reserveId).hub));
    _approve(
      IERC20(hub.getAsset(spoke.getReserve(reserveId).assetId).underlying),
      owner,
      spender,
      amount
    );
  }

  function approve(ITokenizationSpoke vault, address owner, uint256 amount) internal {
    _approve({
      underlying: IERC20(vault.asset()),
      owner: owner,
      spender: address(vault),
      amount: amount
    });
  }

  function transferFrom(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    address from,
    address to,
    uint256 amount
  ) internal {
    _transferFrom({
      underlying: IERC20(spoke.getReserve(reserveId).underlying),
      caller: caller,
      from: from,
      to: to,
      amount: amount
    });
  }

  function _approve(IERC20 underlying, address owner, address spender, uint256 amount) private {
    vm.startPrank(owner);
    underlying.forceApprove(spender, amount);
    vm.stopPrank();
  }

  function _transferFrom(
    IERC20 underlying,
    address caller,
    address from,
    address to,
    uint256 amount
  ) private {
    vm.prank(caller);
    underlying.transferFrom(from, to, amount);
  }
}
