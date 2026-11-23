// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IRevenueSplitter
/// @author Aave Labs
/// @notice Interface for the RevenueSplitter.
interface IRevenueSplitter {
  /// @notice Emitted when revenue of an underlying asset is distributed to the recipients.
  /// @param hub The address of the Hub the revenue was withdrawn from.
  /// @param underlying The address of the underlying asset.
  /// @param amount The total amount distributed.
  event SplitRevenue(address indexed hub, address indexed underlying, uint256 amount);

  /// @notice Thrown when a zero address is provided.
  error InvalidAddress();

  /// @notice Thrown when fewer than two recipients are provided.
  error InvalidRecipientsCount();

  /// @notice Thrown when a recipient is provided more than once.
  error DuplicateRecipient();

  /// @notice Thrown when a split is zero or the splits do not sum to `PERCENTAGE_FACTOR`.
  error InvalidSplit();

  /// @notice Thrown when paired input arrays have different lengths.
  error MismatchedLengths();

  /// @notice Withdraws the available revenue from the TreasurySpoke and distributes it to the recipients.
  /// @dev Withdraws up to the minimum of the TreasurySpoke minted supplied assets and the Hub liquidity.
  /// @dev Accrued fees not yet minted to the TreasurySpoke are left for a later call.
  /// @dev Distributes the entire balance of each underlying held by this contract. Each recipient but the last
  /// receives its split rounded down; the last recipient receives the remainder.
  /// @param hubs The addresses of the Hubs.
  /// @param underlyings The addresses of the underlying assets, one per Hub.
  function splitRevenue(address[] calldata hubs, address[] calldata underlyings) external;

  /// @notice Returns the address of the TreasurySpoke revenue is withdrawn from.
  function TREASURY_SPOKE() external view returns (address);

  /// @notice Returns the recipients and their splits.
  /// @return The addresses of the recipients.
  /// @return The splits of the recipients, expressed in BPS.
  function getRecipients() external view returns (address[] memory, uint256[] memory);
}
