// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

interface IWrappedTokenGatewayV4 {
  error InvalidAddress();
  error InvalidAmount();
  error InvalidReserveId();
  error NativeAmountMismatch();
  error NativeTransferFailed();
  error FallbackForbidden();
  error ReceiveNotAllowed();

  function supplyNative(uint256 reserveId, uint256 amount) external payable;
  function withdrawNative(uint256 reserveId, uint256 amount, address receiver) external;
  function borrowNative(uint256 reserveId, uint256 amount, address receiver) external;
  function repayNative(uint256 reserveId, uint256 amount) external payable;
  function setUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}
