// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IBabylonAaveAdapter
/// @author Aave Labs
/// @notice Getters of Babylon's AaveAdapter read by the Babylon market scripts.
interface IBabylonAaveAdapter {
  /// @notice Returns the BabylonSpoke the adapter operates on.
  function BTC_VAULT_CORE_SPOKE() external view returns (address);

  /// @notice Returns the Hub of the vaultBTC reserve.
  function BTC_VAULT_HUB() external view returns (address);

  /// @notice Returns vaultBTC.
  function VAULT_BTC() external view returns (address);

  /// @notice Returns the identifier of the vaultBTC reserve on the BabylonSpoke.
  function VAULT_BTC_RESERVE_ID() external view returns (uint256);

  /// @notice Returns the identifier of the exit reserve on the BabylonSpoke.
  function EXIT_BTC_RESERVE_ID() external view returns (uint256);

  /// @notice Returns the fee charged on the liquidation bonus, expressed in BPS.
  function liquidationFeeBps() external view returns (uint256);
}

/// @title IBabylonVaultBTC
/// @author Aave Labs
/// @notice Getters of Babylon's vaultBTC read by the Babylon market scripts.
interface IBabylonVaultBTC {
  /// @notice Returns the only minter and burner of vaultBTC.
  function adapter() external view returns (address);

  /// @notice Returns the Hub vaultBTC can be transferred to.
  function HUB() external view returns (address);
}

/// @title IBabylonBTCVaultSwap
/// @author Aave Labs
/// @notice Getters of Babylon's BTCVaultSwap read by the Babylon market scripts.
interface IBabylonBTCVaultSwap {
  /// @notice Returns the AaveAdapter BTCVaultSwap liquidates for.
  function ADAPTER() external view returns (address);

  /// @notice Returns the Hub BTCVaultSwap draws the exit asset from.
  function HUB() external view returns (address);

  /// @notice Returns the exit asset.
  function EXIT_BTC() external view returns (address);

  /// @notice Returns the identifier of the exit asset on the Hub.
  function EXIT_BTC_ASSET_ID() external view returns (uint256);

  /// @notice Returns the sell discount, expressed in BPS.
  function sellDiscountBps() external view returns (uint256);

  /// @notice Returns the minimum profit threshold, expressed in BPS.
  function minimumProfitThresholdBps() external view returns (uint256);
}
