// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IERC2612, IERC20Permit} from 'src/dependencies/openzeppelin/IERC2612.sol';
import {IERC4626} from 'src/dependencies/openzeppelin/IERC4626.sol';
import {IIntentConsumer} from 'src/interfaces/IIntentConsumer.sol';

/// @title ITokenizationSpoke
/// @author Aave Labs
interface ITokenizationSpoke is IERC4626, IERC2612, IIntentConsumer {
  /// @notice Intent data to deposit assets into the vault.
  /// @param depositor The address of the user depositing assets.
  /// @param assets The amount of assets to deposit.
  /// @param receiver The address that will receive the minted shares.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct VaultDeposit {
    address depositor;
    uint256 assets;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to mint shares from the vault.
  /// @param depositor The address of the user depositing assets.
  /// @param shares The amount of shares to mint.
  /// @param receiver The address that will receive the minted shares.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct VaultMint {
    address depositor;
    uint256 shares;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to withdraw assets from the vault.
  /// @param owner The address of the user withdrawing assets.
  /// @param assets The amount of assets to withdraw.
  /// @param receiver The address that will receive the withdrawn assets.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct VaultWithdraw {
    address owner;
    uint256 assets;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Intent data to redeem shares from the vault.
  /// @param owner The address of the user redeeming shares.
  /// @param shares The amount of shares to redeem.
  /// @param receiver The address that will receive the redeemed assets.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  struct VaultRedeem {
    address owner;
    uint256 shares;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

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

  /// @notice Sets approval for `spender` to spend `owner`'s share tokens via EIP712-typed signature.
  /// @dev Uses keyed-nonces where the share token permit nonce is consumed sequentially at key=PERMIT_NONCE_NAMESPACE.
  /// @dev Implements EIP-2612 permit functionality for the vault share token.
  /// @param owner The address of the token owner granting approval.
  /// @param spender The address being granted approval to spend tokens.
  /// @param value The amount of tokens approved for spending.
  /// @param deadline The timestamp by which the permit must be used.
  /// @param v The recovery byte of the signature.
  /// @param r The first 32 bytes of the signature.
  /// @param s The second 32 bytes of the signature.
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /// @notice Revokes the current PERMIT_NAMESPACE_NONCE of `owner` & increments the nonce at this key.
  /// @param owner The owner of the nonce to consume.
  /// @return The consumed keyed-nonce.
  function usePermitNonce(address owner) external returns (uint256);

  /// @notice Resets the allowance of an owner for the caller.
  /// @param owner The owner of the allowance to renounce.
  function renounceAllowance(address owner) external;

  /// @notice Returns the address of the associated Hub.
  function hub() external view returns (address);

  /// @notice Returns the identifier of the associated asset.
  function assetId() external view returns (uint256);

  /// @notice Returns the maximum allowed spoke cap.
  function MAX_ALLOWED_SPOKE_CAP() external view returns (uint40);

  /// @notice Returns the nonce namespace for share token EIP-2612 permit signatures.
  /// @dev Share token permits strictly use this dedicated namespace in the keyed-nonce system as the nonce key.
  /// @dev Other vault intent operations can also use the this namespace as the nonce key.
  function PERMIT_NONCE_NAMESPACE() external pure returns (uint192);

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

  /// @notice Returns the EIP-712 domain separator.
  function DOMAIN_SEPARATOR()
    external
    view
    override(IERC20Permit, IIntentConsumer)
    returns (bytes32);
}
