// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
// import '../mocks/MockSpokeExposedMethods.sol';

contract LiquidationCallVariableLiquidationBonusTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // variable liquidation bonus

  function test_required_debt() public {}

  function _borrowToBeBelowHf(address user, uint256 assetId, uint256 desiredHf) internal {
    // uint256 requiredDebtInBase = _getRequiredBorrowsForHfBelow(user, desiredHf);
    // uint256 amount = (requiredBorrowsInBase * (10 ** IERC20Detailed(assetToBorrow).decimals())) /
    //   contracts.aaveOracle.getAssetPrice(assetToBorrow);
    // vm.mockCall(
    //   address(contracts.aaveOracle),
    //   abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetToBorrow),
    //   abi.encode(0)
    // );
    // vm.prank(user);
    // contracts.poolProxy.borrow(assetToBorrow, amount, 2, 0, user);
    // vm.clearMockedCalls();
  }

  /**
   * @notice Returns the required debt amount in base currency to reach a certain health factor
   */
  function _getRequiredDebtForLtHf(
    ISpoke spoke,
    address user,
    uint256 desiredHf
  ) internal view returns (uint256) {
    (
      ,
      uint256 currentAvgCollateralFactor,
      ,
      uint256 totalCollateralBase,
      uint256 totalBorrowsBase
    ) = spoke.getUserAccountData(user);
    return
      ((totalCollateralBase.percentMul(currentAvgCollateralFactor + 1) *
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD) / desiredHf) - totalBorrowsBase;
  }
}
