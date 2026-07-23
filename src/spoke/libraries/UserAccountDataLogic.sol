// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SpokeUtils} from 'src/spoke/libraries/SpokeUtils.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {UserPositionUtils} from 'src/spoke/libraries/UserPositionUtils.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {SpokeStorage} from 'src/spoke/SpokeStorage.sol';

/// @title UserAccountDataLogic library
/// @author Aave Labs
/// @notice Implements the logic to process a position's account data.
library UserAccountDataLogic {
  using SafeCast for *;
  using MathUtils for *;
  using PercentageMath for *;
  using WadRayMath for *;
  using SpokeUtils for *;
  using KeyValueList for KeyValueList.List;
  using PositionStatusMap for *;
  using UserPositionUtils for ISpoke.UserPosition;

  struct ProcessUserAccountDataParams {
    IAaveOracle oracle;
    uint256 reserveCount;
    bytes32 positionId;
  }

  /// @notice Process the user account data.
  /// @dev Collateral is rounded against the user, while debt is calculated with full precision.
  /// @dev If user has no debt, it returns health factor of `type(uint256).max` and risk premium of 0.
  /// @param reserves The mapping of reserves per reserve id.
  /// @param userPositions The mapping of user positions per position per reserve.
  /// @param positionStatus The mapping of position status per position.
  /// @param dynamicConfig The mapping of dynamic config per reserve per dynamic config key.
  /// @param params The process user account data params.
  /// @return accountData The user account data.
  function processUserAccountData(
    mapping(uint256 reserveId => ISpoke.Reserve) storage reserves,
    mapping(bytes32 positionId => mapping(uint256 reserveId => ISpoke.UserPosition)) storage userPositions,
    mapping(bytes32 positionId => ISpoke.PositionStatus) storage positionStatus,
    mapping(uint256 reserveId => mapping(uint32 dynamicConfigKey => ISpoke.DynamicReserveConfig)) storage dynamicConfig,
    ProcessUserAccountDataParams memory params
  ) external view returns (ISpoke.UserAccountData memory accountData) {
    ISpoke.PositionStatus storage userPositionStatus = positionStatus[params.positionId];

    uint256 reserveId = params.reserveCount;
    KeyValueList.List memory collateralInfo = KeyValueList.init(
      userPositionStatus.collateralCount(reserveId)
    );
    bool borrowing;
    bool collateral;
    while (true) {
      (reserveId, borrowing, collateral) = userPositionStatus.next(reserveId);
      if (reserveId == PositionStatusMap.NOT_FOUND) break;

      ISpoke.UserPosition storage userPosition = userPositions[params.positionId][reserveId];
      ISpoke.Reserve storage reserve = reserves[reserveId];

      uint256 assetPrice = params.oracle.getReservePrice(reserveId);
      uint256 assetDecimals = reserve.decimals;

      if (collateral) {
        uint256 collateralFactor = dynamicConfig[reserveId][userPosition.dynamicConfigKey]
          .collateralFactor;
        if (collateralFactor > 0) {
          uint256 suppliedShares = userPosition.suppliedShares;
          if (suppliedShares > 0) {
            // cannot round down to zero
            uint256 userCollateralValue = reserve
              .hub
              .previewRemoveByShares(reserve.assetId, suppliedShares)
              .toValue({decimals: assetDecimals, price: assetPrice});
            accountData.totalCollateralValue += userCollateralValue;
            collateralInfo.add(
              accountData.activeCollateralCount,
              reserve.collateralRisk,
              userCollateralValue
            );
            accountData.avgCollateralFactor += collateralFactor * userCollateralValue;
            accountData.activeCollateralCount = accountData.activeCollateralCount.uncheckedAdd(1);
          }
        }
      }

      if (borrowing) {
        UserPositionUtils.DebtComponents memory debtComponents = userPosition.getDebtComponents(
          reserve.hub,
          reserve.assetId
        );
        uint256 debtRay = debtComponents.drawnShares * debtComponents.drawnIndex +
          debtComponents.premiumDebtRay;
        accountData.totalDebtValueRay += debtRay.toValue({
          decimals: assetDecimals,
          price: assetPrice
        });
        accountData.borrowCount = accountData.borrowCount.uncheckedAdd(1);
      }
    }

    if (accountData.totalDebtValueRay > 0) {
      // at this point, `avgCollateralFactor` is the total collateral value weighted by collateral factors,
      // expressed in units of Value and scaled by BPS. We convert it from BPS to WAD, since this will
      // ultimately define the scaling factor of the health factor.
      accountData.healthFactor = Math.mulDiv(
        accountData.avgCollateralFactor.bpsToWad(),
        WadRayMath.RAY,
        accountData.totalDebtValueRay,
        Math.Rounding.Floor
      );
    } else {
      accountData.healthFactor = type(uint256).max;
    }

    if (accountData.totalCollateralValue > 0) {
      accountData.avgCollateralFactor =
        accountData.avgCollateralFactor.bpsToWad() / accountData.totalCollateralValue;
    }

    // sort by collateral risk in ASC, collateral value in DESC
    collateralInfo.sortByKey();

    // runs until either the collateral or debt is exhausted
    uint256 totalDebtValue = accountData.totalDebtValueRay.fromRayUp();
    uint256 debtValueLeftToCover = totalDebtValue;

    for (uint256 index = 0; index < collateralInfo.length(); ++index) {
      if (debtValueLeftToCover == 0) {
        break;
      }

      (uint256 collateralRisk, uint256 userCollateralValue) = collateralInfo.uncheckedAt(index);
      userCollateralValue = userCollateralValue.min(debtValueLeftToCover);
      accountData.riskPremium += userCollateralValue * collateralRisk;
      debtValueLeftToCover = debtValueLeftToCover.uncheckedSub(userCollateralValue);
    }

    if (debtValueLeftToCover < totalDebtValue) {
      accountData.riskPremium = accountData.riskPremium.divUp(
        totalDebtValue.uncheckedSub(debtValueLeftToCover)
      );
    }

    return accountData;
  }
}
