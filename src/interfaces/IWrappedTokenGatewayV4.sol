// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

interface IWrappedTokenGatewayV4 {
    error AmountNull();
    error AddressZero();
    error InvalidReserveId();
    error NativeAmountMismatch();
    error NativeTransferFailed();
    error FallbackForbidden();
    error ReceiveNotAllowed();

  function supplyNative(uint256 reserveId, uint256 amount, address onBehalfOf) external payable;
  function withdrawNative(uint256 reserveId, uint256 amount, address onBehalfOf) external;
  function borrowNative(uint256 reserveId, uint256 amount, address onBehalfOf) external;
  function repayNative(uint256 reserveId, uint256 amount, address onBehalfOf) external payable;
  function setUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}