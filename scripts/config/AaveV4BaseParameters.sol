// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4BaseParameters
/// @author Aave Labs
/// @notice The parameters every asset is listed with on the Base market at launch.
/// @dev The market launches halted, so these are not risk parameters in the usual sense: every
/// reserve is listed non-collateral, non-borrowable and with zero caps, and the Hub halt on top of
/// that closes it entirely. The real listing parameters arrive in the first governance payload,
/// through the config engine, once the market is live.
///
/// Each value is at the neutral end of what its own validation accepts rather than a literal zero,
/// because three of them reject zero. Those three are named below; everything else is zero.
library AaveV4BaseParameters {
  /// @dev No fee taken on liquidity.
  uint256 internal constant LIQUIDITY_FEE = 0;

  /// @dev `AssetInterestRateStrategy.MIN_OPTIMAL_RATIO`, the lowest value the strategy accepts.
  uint16 internal constant OPTIMAL_USAGE_RATIO = 1_00;
  uint32 internal constant BASE_DRAWN_RATE = 0;
  uint32 internal constant RATE_GROWTH_BEFORE_OPTIMAL = 0;
  uint32 internal constant RATE_GROWTH_AFTER_OPTIMAL = 0;

  /// @dev The Spoke can neither add nor draw the asset.
  uint40 internal constant ADD_CAP = 0;
  uint40 internal constant DRAW_CAP = 0;
  uint24 internal constant RISK_PREMIUM_THRESHOLD = 0;

  /// @dev The asset is not usable as collateral and is not borrowable.
  uint24 internal constant COLLATERAL_RISK = 0;
  uint16 internal constant COLLATERAL_FACTOR = 0;
  uint16 internal constant LIQUIDATION_FEE = 0;
  bool internal constant BORROWABLE = false;
  bool internal constant RECEIVE_SHARES_ENABLED = false;
  /// @dev `PercentageMath.PERCENTAGE_FACTOR`, a 0.00% bonus and the lowest value
  /// `Spoke._validateDynamicReserveConfig` accepts.
  uint32 internal constant MAX_LIQUIDATION_BONUS = 100_00;

  /// @dev `Spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD`, the lowest target health factor accepted.
  uint128 internal constant TARGET_HEALTH_FACTOR = 1e18;
  /// @dev Must be strictly below the liquidation threshold.
  uint64 internal constant HEALTH_FACTOR_FOR_MAX_BONUS = 1e18 - 1;
  uint16 internal constant LIQUIDATION_BONUS_FACTOR = 0;

  /// @dev Cap a tokenization spoke is registered on the Hub with. Zero like every other cap, so the
  /// share token exists and is wired but nothing can be added through it until governance raises it.
  uint40 internal constant TOKENIZATION_ADD_CAP = 0;

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

  /// @dev The Hub the tokenization spokes hang off, as it appears in their share token names. Must
  /// match the single entry of `hubLabels` in config/base.json.
  string internal constant HUB_NAME = 'Core';

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
