// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';

/// @title IFlashLoanSpoke
/// @author Aave Labs
/// @notice Interface for the FlashLoanSpoke.
interface IFlashLoanSpoke {
  /// @notice Flashloan data of an underlying asset.
  /// @dev assetId The identifier of the asset in the Hub.
  /// @dev premium The flashloan premium, expressed in BPS (e.g. 100_00 is 100.00%), or `USE_DEFAULT_PREMIUM`
  /// to use `DEFAULT_PREMIUM`.
  /// @dev enabled True if the asset can be flashloaned.
  /// @dev hasRoundingDebt True if fee-waived flashloans left drawn shares to be restored out of the next fees of the asset
  /// or with `repayRoundingDebt`.
  /// @dev pendingFee The fee already transferred to the Hub but not paid yet, either too small to mint an added share
  /// or not covering the rounding debt, paid with the next fee of the asset.
  struct FlashLoanAsset {
    uint16 assetId;
    uint16 premium;
    bool enabled;
    bool hasRoundingDebt;
    uint120 pendingFee;
  }

  /// @notice Emitted when the associated Hub is set.
  /// @param hub The address of the associated Hub.
  event UpdateHub(address indexed hub);

  /// @notice Emitted when the flashloan configuration of an underlying asset is updated.
  /// @param underlying The address of the underlying asset.
  /// @param assetId The identifier of the asset in the Hub.
  /// @param premium The flashloan premium, expressed in BPS (e.g. 100_00 is 100.00%), or `USE_DEFAULT_PREMIUM`.
  /// @param enabled True if the asset can be flashloaned.
  event UpdateAssetConfig(
    address indexed underlying,
    uint256 indexed assetId,
    uint16 premium,
    bool enabled
  );

  /// @notice Emitted when the premium waiver of a flash borrower is updated.
  /// @param borrower The address of the flash borrower.
  /// @param authorized True if the borrower is exempt from the flashloan premium.
  event UpdateFlashBorrower(address indexed borrower, bool authorized);

  /// @notice Emitted when the rounding debt of an underlying asset is repaid.
  /// @param underlying The address of the underlying asset.
  /// @param caller The address paying the rounding debt.
  /// @param amount The amount repaid.
  event RepayRoundingDebt(address indexed underlying, address indexed caller, uint256 amount);

  /// @notice Emitted on each flash-borrowed asset once repaid.
  /// @param receiver The address of the flashloan receiver.
  /// @param initiator The address of the flashloan initiator.
  /// @param asset The address of the flash-borrowed underlying asset.
  /// @param amount The amount flash-borrowed.
  /// @param premium The premium repaid on top of the flash-borrowed amount.
  event FlashLoan(
    address indexed receiver,
    address indexed initiator,
    address indexed asset,
    uint256 amount,
    uint256 premium
  );

  /// @notice Thrown when an address is invalid.
  error InvalidAddress();

  /// @notice Thrown when the flashloan premium exceeds 100.00% and is not `USE_DEFAULT_PREMIUM`.
  error InvalidPremium();

  /// @notice Thrown when the assets and amounts arrays have different lengths.
  error InconsistentFlashLoanParams();

  /// @notice Thrown when flashloaning an asset that is not enabled.
  error FlashLoanDisabled();

  /// @notice Thrown when the receiver callback does not return true.
  error InvalidFlashLoanExecutorReturn();

  /// @notice Updates the flashloan configuration of an underlying asset.
  /// @dev The underlying asset must be listed on the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param premium The flashloan premium, expressed in BPS (e.g. 100_00 is 100.00%), or `USE_DEFAULT_PREMIUM`
  /// to use `DEFAULT_PREMIUM`.
  /// @param enabled True if the asset can be flashloaned.
  function updateAssetConfig(address underlying, uint16 premium, bool enabled) external;

  /// @notice Updates the premium waiver of a flash borrower.
  /// @param borrower The address of the flash borrower.
  /// @param authorized True if the borrower is exempt from the flashloan premium.
  function updateFlashBorrower(address borrower, bool authorized) external;

  /// @notice Repays the rounding debt left by fee-waived flashloans of an underlying asset.
  /// @dev Pulls the rounding debt from the caller. Without it, the rounding debt is only restored out of the next
  /// fees of the asset, which never come for an asset without premium.
  /// @param underlying The address of the underlying asset.
  /// @return The amount repaid.
  function repayRoundingDebt(address underlying) external returns (uint256);

  /// @notice Flash-borrows multiple assets from the Hub within one transaction.
  /// @dev Each asset is repaid by pulling `amounts[i] + premiums[i]` from the receiver once the callback returns.
  /// @dev Each premium is the flashloan fee, or the Hub rounding on the drawn amount when larger. The rounding is
  /// deducted from the fee. Authorized flash borrowers pay no premium: their rounding is restored out of the next fees.
  /// @dev The fee of an asset is paid to the Hub fee receiver once all its ongoing flashloans are repaid.
  /// @param receiver The address of the contract receiving the assets, implementing `IFlashLoanReceiver`.
  /// @param assets The addresses of the underlying assets to flash-borrow.
  /// @param amounts The amounts to flash-borrow.
  /// @param params The byte-encoded params forwarded to the receiver.
  function flashLoan(
    address receiver,
    address[] calldata assets,
    uint256[] calldata amounts,
    bytes calldata params
  ) external;

  /// @notice Flash-borrows a single asset from the Hub within one transaction.
  /// @dev The asset is repaid by pulling `amount + premium` from the receiver once the callback returns.
  /// @dev The premium is the flashloan fee, or the Hub rounding on the drawn amount when larger. The rounding is
  /// deducted from the fee. Authorized flash borrowers pay no premium: their rounding is restored out of the next fees.
  /// @dev The fee is paid to the Hub fee receiver once all ongoing flashloans of the asset are repaid.
  /// @param receiver The address of the contract receiving the asset, implementing `IFlashLoanSimpleReceiver`.
  /// @param asset The address of the underlying asset to flash-borrow.
  /// @param amount The amount to flash-borrow.
  /// @param params The byte-encoded params forwarded to the receiver.
  function flashLoanSimple(
    address receiver,
    address asset,
    uint256 amount,
    bytes calldata params
  ) external;

  /// @notice Returns the flashloan data of an underlying asset.
  /// @param underlying The address of the underlying asset.
  /// @return The flashloan asset data.
  function getFlashLoanAsset(address underlying) external view returns (FlashLoanAsset memory);

  /// @notice Returns whether a flash borrower is exempt from the flashloan premium.
  /// @param borrower The address of the flash borrower.
  /// @return True if the borrower is exempt from the flashloan premium.
  function isFlashBorrower(address borrower) external view returns (bool);

  /// @notice Returns the address of the associated Hub.
  /// @return The associated Hub.
  function getHub() external view returns (IHubBase);

  /// @notice Returns the premium applied to assets configured with `USE_DEFAULT_PREMIUM`.
  /// @return The default premium, expressed in BPS (e.g. 100_00 is 100.00%).
  function DEFAULT_PREMIUM() external view returns (uint16);

  /// @notice Returns the premium value flagging an asset to use `DEFAULT_PREMIUM`.
  /// @return The flag premium value.
  function USE_DEFAULT_PREMIUM() external view returns (uint16);
}
