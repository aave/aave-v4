// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IFlashLoanSimpleReceiver
/// @author Aave Labs
/// @notice Defines the callback of a single-asset flashloan receiver.
/// @dev Matches the Aave V3 `IFlashLoanSimpleReceiver.executeOperation` callback.
interface IFlashLoanSimpleReceiver {
  /// @notice Executes an operation after receiving the flash-borrowed asset.
  /// @dev The receiver must hold `amount + premium` of the asset and approve the FlashLoanSpoke
  /// to pull it once the callback returns.
  /// @dev Anyone can trigger a flashloan to any receiver: the receiver must check that the caller is the
  /// FlashLoanSpoke and that `initiator` is trusted, otherwise it can be made to pay the premium.
  /// @param asset The address of the flash-borrowed underlying asset.
  /// @param amount The amount of the flash-borrowed asset.
  /// @param premium The premium owed on top of the flash-borrowed amount.
  /// @param initiator The address of the flashloan initiator.
  /// @param params The byte-encoded params passed when initiating the flashloan.
  /// @return True if the execution of the operation succeeds, false otherwise.
  function executeOperation(
    address asset,
    uint256 amount,
    uint256 premium,
    address initiator,
    bytes calldata params
  ) external returns (bool);
}
