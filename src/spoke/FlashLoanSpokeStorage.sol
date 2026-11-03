// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IFlashLoanSpoke} from 'src/spoke/interfaces/IFlashLoanSpoke.sol';

/// @title FlashLoanSpokeStorage
/// @author Aave Labs
/// @notice Storage layout for the FlashLoanSpoke contract.
/// @dev This contract defines all storage variables used by the FlashLoanSpoke.
abstract contract FlashLoanSpokeStorage {
  /// @dev The associated Hub.
  IHubBase internal _hub;

  /// @dev Map of underlying asset addresses to their flashloan data.
  mapping(address underlying => IFlashLoanSpoke.FlashLoanAsset) internal _assets;

  /// @dev Map of flash borrower addresses to their premium waiver.
  mapping(address borrower => bool) internal _flashBorrowers;

  /// @dev Reserved storage space to allow for future layout updates.
  uint256[50] private __gap;
}
