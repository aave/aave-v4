// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4SentoraParameters
/// @author Aave Labs
/// @notice The launch parameters of the Sentora market that are not per-asset.
/// @dev The per-asset and per-reserve risk parameters live in config/sentora-config.json. What is
/// here is what the launch set does not vary: the liquidation curve a Spoke applies to every one of
/// its reserves, and the tokenization spoke share naming.
///
/// The ARFC does not set the liquidation curve, so it mirrors the Base market until Sentora does.
///
/// The market is listed with these parameters and then halted on the Hub, so nothing can be supplied
/// or borrowed until each asset-spoke pair is unhalted. See docs/sentora-deploy.md.
library AaveV4SentoraParameters {
  /// @dev The health factor a liquidation restores a position to, expressed in WAD.
  uint128 internal constant TARGET_HEALTH_FACTOR = 1.24e18;
  /// @dev The health factor at which the liquidation bonus reaches an asset's
  /// `maxLiquidationBonus`, expressed in WAD. Must be strictly below
  /// `Spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD`.
  uint64 internal constant HEALTH_FACTOR_FOR_MAX_BONUS = 0.9e18;
  /// @dev The share of `maxLiquidationBonus` paid at a health factor of 1.00, in BPS. The bonus
  /// grows from there to the full amount at `HEALTH_FACTOR_FOR_MAX_BONUS`.
  uint16 internal constant LIQUIDATION_BONUS_FACTOR = 90_00;

  /// @notice The liquidation configuration applied to every Spoke.
  /// @dev Per Spoke rather than per reserve, so it is set once before any asset is listed.
  /// @return The launch liquidation configuration.
  function liquidationConfig() internal pure returns (ISpoke.LiquidationConfig memory) {
    return
      ISpoke.LiquidationConfig({
        targetHealthFactor: TARGET_HEALTH_FACTOR,
        healthFactorForMaxBonus: HEALTH_FACTOR_FOR_MAX_BONUS,
        liquidationBonusFactor: LIQUIDATION_BONUS_FACTOR
      });
  }

  /// @dev The Hub the tokenization spokes hang off, as it appears in their share token names.
  string internal constant HUB_NAME = 'Sentora';

  /// @notice The share token name of an asset's tokenization spoke.
  /// @dev Follows the underlying's own symbol, as on Ethereum and Avalanche: the WAVAX share token
  /// of the Avalanche core hub is `Wrapped Aave Core WAVAX`.
  /// @param assetSymbol The underlying's symbol.
  /// @return The share token name.
  function tokenizationShareName(string memory assetSymbol) internal pure returns (string memory) {
    return string.concat('Wrapped Aave ', HUB_NAME, ' ', assetSymbol);
  }

  /// @notice The share token symbol of an asset's tokenization spoke.
  /// @param assetSymbol The underlying's symbol.
  /// @return The share token symbol.
  function tokenizationShareSymbol(
    string memory assetSymbol
  ) internal pure returns (string memory) {
    return string.concat('wa', HUB_NAME, assetSymbol);
  }
}
