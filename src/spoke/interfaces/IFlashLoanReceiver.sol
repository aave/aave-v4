// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IFlashLoanReceiver
/// @author Aave Labs
/// @notice Defines the callback of a multi-asset flashloan receiver.
/// @dev Matches the Aave V3 `IFlashLoanReceiver.executeOperation` callback.
interface IFlashLoanReceiver {
  /// @notice Executes an operation after receiving the flash-borrowed assets.
  /// @dev The receiver must hold `amounts[i] + premiums[i]` of each asset and approve the
  /// FlashLoanSpoke to pull it once the callback returns.
  /// @dev Anyone can trigger a flashloan to any receiver: the receiver must check that the caller is the
  /// FlashLoanSpoke and that `initiator` is trusted, otherwise it can be made to pay the premiums.
  /// @param assets The addresses of the flash-borrowed underlying assets.
  /// @param amounts The amounts of the flash-borrowed assets.
  /// @param premiums The premium owed on top of each flash-borrowed amount.
  /// @param initiator The address of the flashloan initiator.
  /// @param params The byte-encoded params passed when initiating the flashloan.
  /// @return True if the execution of the operation succeeds, false otherwise.
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool);
}
