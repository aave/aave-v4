// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.24;

import {SlotDerivation} from 'src/dependencies/openzeppelin/SlotDerivation.sol';
import {TransientSlot} from 'src/dependencies/openzeppelin/TransientSlot.sol';

/// @title TransientFlashLoanMap Library
/// @author Aave Labs
/// @notice Transient storage mapping from underlying asset addresses to their ongoing flashloans data.
/// @dev Each underlying asset maps to two consecutive transient slots: slot S for the flash-borrowed amount
/// not repaid yet, and slot S+1 for the fee accrued by the repaid flashloans.
library TransientFlashLoanMap {
  using SlotDerivation for bytes32;
  using TransientSlot for *;

  /// @dev keccak256(abi.encode(uint256(keccak256("aave-v4.transient.FlashLoanSpoke")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant BASE_SLOT =
    0x3f63dc6780cae8e8976956b5e2e1b5f3d3707afe531cb6370167e8b083c68e00;

  /// @notice Stores the ongoing flashloans data of an underlying asset.
  /// @param underlying The address of the underlying asset.
  /// @param amount The flash-borrowed amount not repaid yet.
  /// @param accruedFee The fee accrued by the repaid flashloans.
  function set(address underlying, uint256 amount, uint256 accruedFee) internal {
    bytes32 slot = BASE_SLOT.deriveMapping(underlying);
    slot.asUint256().tstore(amount);
    slot.offset(1).asUint256().tstore(accruedFee);
  }

  /// @notice Loads the ongoing flashloans data of an underlying asset.
  /// @param underlying The address of the underlying asset.
  /// @return amount The flash-borrowed amount not repaid yet.
  /// @return accruedFee The fee accrued by the repaid flashloans.
  function get(address underlying) internal view returns (uint256 amount, uint256 accruedFee) {
    bytes32 slot = BASE_SLOT.deriveMapping(underlying);
    return (slot.asUint256().tload(), slot.offset(1).asUint256().tload());
  }
}
