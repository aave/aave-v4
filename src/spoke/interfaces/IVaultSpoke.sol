// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IERC4626} from 'src/dependencies/openzeppelin/IERC4626.sol';
import {IERC2612} from 'src/dependencies/openzeppelin/IERC2612.sol';
import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';

/// @title IVaultSpoke
/// @author Aave Labs
interface IVaultSpoke is IERC4626, IERC2612 {
  /// @notice Thrown when the given signature is invalid.
  error InvalidSignature();

  /// @notice Thrown when the given address is invalid.
  error InvalidAddress();

  /// @notice Thrown when the maximum deposit limit is exceeded.
  error MaxDepositExceeded(uint256 maxDeposit, uint256 requestedAssets);

  /// @notice Thrown when the maximum mint limit is exceeded.
  error MaxMintExceeded(uint256 maxMint, uint256 requestedShares);

  /// @notice Thrown when the maximum withdraw limit is exceeded.
  error MaxWithdrawExceeded(uint256 maxWithdraw, uint256 requestedAssets);

  /// @notice Thrown when the maximum redeem limit is exceeded.
  error MaxRedeemExceeded(uint256 maxRedeem, uint256 requestedShares);

  function depositWithSig(
    EIP712Types.VaultDeposit calldata params,
    bytes calldata signature
  ) external returns (uint256 shares);

  function mintWithSig(
    EIP712Types.VaultMint calldata params,
    bytes calldata signature
  ) external returns (uint256 assets);

  function withdrawWithSig(
    EIP712Types.VaultWithdraw calldata params,
    bytes calldata signature
  ) external returns (uint256 shares);

  function redeemWithSig(
    EIP712Types.VaultRedeem calldata params,
    bytes calldata signature
  ) external returns (uint256 assets);

  function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 shares);

  /// @notice Returns the address of the associated Hub.
  function hub() external view returns (IHub);

  /// @notice Returns the identifier of the associated asset.
  function assetId() external view returns (uint256);
}
