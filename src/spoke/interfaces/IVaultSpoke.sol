// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IERC4626} from 'src/dependencies/openzeppelin/IERC4626.sol';
import {IERC2612} from 'src/dependencies/openzeppelin/IERC2612.sol';
import {INoncesKeyed} from 'src/interfaces/INoncesKeyed.sol';

/// @title IVaultSpoke
/// @author Aave Labs
interface IVaultSpoke is IERC4626, IERC2612, INoncesKeyed {
  struct VaultDeposit {
    address depositor;
    uint256 assets;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  struct VaultMint {
    address depositor;
    uint256 shares;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  struct VaultWithdraw {
    address owner;
    uint256 assets;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  struct VaultRedeem {
    address owner;
    uint256 shares;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Thrown when the given signature is invalid.
  error InvalidSignature();

  /// @notice Thrown when the maximum deposit limit is exceeded.
  error MaxDepositExceeded(uint256 maxDeposit, uint256 requestedAssets);

  /// @notice Thrown when the maximum mint limit is exceeded.
  error MaxMintExceeded(uint256 maxMint, uint256 requestedShares);

  /// @notice Thrown when the maximum withdraw limit is exceeded.
  error MaxWithdrawExceeded(uint256 maxWithdraw, uint256 requestedAssets);

  /// @notice Thrown when the maximum redeem limit is exceeded.
  error MaxRedeemExceeded(uint256 maxRedeem, uint256 requestedShares);

  /// @notice Deposits assets into the vault with a signature.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The parameters for the deposit.
  /// @param signature The EIP712-typed signed bytes for the deposit.
  /// @return The amount of shares minted.
  function depositWithSig(
    VaultDeposit calldata params,
    bytes calldata signature
  ) external returns (uint256);

  /// @notice Mints shares of the vault with a signature.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The parameters for the mint.
  /// @param signature The EIP712-typed signed bytes for the mint.
  /// @return The amount of assets deposited.
  function mintWithSig(
    VaultMint calldata params,
    bytes calldata signature
  ) external returns (uint256);

  /// @notice Withdraws assets from the vault with a signature.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The parameters for the withdraw.
  /// @param signature The EIP712-typed signed bytes for the withdraw.
  /// @return The amount of shares burnt.
  function withdrawWithSig(
    VaultWithdraw calldata params,
    bytes calldata signature
  ) external returns (uint256);

  /// @notice Redeems shares from the vault with a signature.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The parameters for the redeem.
  /// @param signature The EIP712-typed signed bytes for the redeem.
  /// @return The amount of assets burnt.
  function redeemWithSig(
    VaultRedeem calldata params,
    bytes calldata signature
  ) external returns (uint256);

  /// @notice Deposits assets into the vault with an underlying asset ERC2612 typed permit.
  /// @param assets The amount of assets to deposit.
  /// @param receiver The receiver of the shares.
  /// @param deadline The deadline of the permit.
  /// @param v The v value of the permit.
  /// @param r The r value of the permit.
  /// @param s The s value of the permit.
  /// @return The amount of shares minted.
  function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256);

  /// @notice Resets the allowance of an owner for the caller.
  /// @param owner The owner of the allowance to renounce.
  function renounceAllowance(address owner) external;

  /// @notice Returns the address of the associated Hub.
  function hub() external view returns (address);

  /// @notice Returns the identifier of the associated asset.
  function assetId() external view returns (uint256);

  /// @notice Returns the maximum allowed spoke cap.
  function MAX_ALLOWED_SPOKE_CAP() external view returns (uint40);

  /// @notice Returns the nonce key for the share token permit EIP-712 typed signatures.
  /// @dev Share token permits nonces are always set at this specific key namespace.
  /// Once the 2 ^ 64 - 1 nonces are used, the nonce at this namespace will overflow and reset to 0; unexpired permits can be replayed then.
  function PERMIT_NONCE_KEY() external pure returns (uint192);

  /// @notice Returns the type hash for the deposit intent.
  function DEPOSIT_TYPEHASH() external pure returns (bytes32);

  /// @notice Returns the type hash for the mint intent.
  function MINT_TYPEHASH() external pure returns (bytes32);

  /// @notice Returns the type hash for the withdraw intent.
  function WITHDRAW_TYPEHASH() external pure returns (bytes32);

  /// @notice Returns the type hash for the redeem intent.
  function REDEEM_TYPEHASH() external pure returns (bytes32);

  /// @notice Returns the type hash for the share token permit intent.
  function PERMIT_TYPEHASH() external pure returns (bytes32);
}
