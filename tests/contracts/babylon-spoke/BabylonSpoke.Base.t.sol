// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/liquidation/Spoke.LiquidationCall.Base.t.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {BabylonSpokeInstance} from 'src/spoke/instances/BabylonSpokeInstance.sol';

/// @dev Upgrades spoke1 to a BabylonSpokeInstance implementation, keeping its state.
abstract contract BabylonSpokeBaseTest is SpokeLiquidationCallBaseTest {
  uint256 internal constant LIQUIDATION_BONUS = 124_00;

  IBabylonSpoke public babylonSpoke;
  address public liquidator = makeAddr('liquidator');

  function setUp() public virtual override {
    super.setUp();

    BabylonSpokeInstance babylonImpl = new BabylonSpokeInstance(
      spoke1.ORACLE(),
      spoke1.MAX_USER_RESERVES_LIMIT()
    );
    vm.prank(ProxyHelper.getProxyAdmin(address(spoke1)));
    ITransparentUpgradeableProxy(address(spoke1)).upgradeToAndCall(address(babylonImpl), '');
    babylonSpoke = IBabylonSpoke(address(spoke1));

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IBabylonSpoke.updateLiquidationBypass.selector;
    vm.prank(ADMIN);
    accessManager.setTargetFunctionRole(
      address(babylonSpoke),
      selectors,
      Roles.SPOKE_CONFIGURATOR_ROLE
    );

    _deal(spoke1, _usdxReserveId(spoke1), liquidator, 1e30);
    SpokeActions.approve({
      spoke: spoke1,
      reserveId: _usdxReserveId(spoke1),
      owner: liquidator,
      amount: UINT256_MAX
    });

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 1e30);
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), 1e30);
  }

  function _updateLiquidationBypass(
    uint256 reserveId,
    bool bypassLiquidationDust,
    bool bypassTargetHealthFactor
  ) internal {
    vm.prank(SPOKE_ADMIN);
    babylonSpoke.updateLiquidationBypass(
      reserveId,
      IBabylonSpoke.LiquidationBypass({
        bypassLiquidationDust: bypassLiquidationDust,
        bypassTargetHealthFactor: bypassTargetHealthFactor
      })
    );
  }

  /// @dev Supplies dai collateral and borrows usdx up to the desired health factor.
  /// @return The user's total usdx debt.
  function _setupPosition(
    uint256 collateralAmount,
    uint256 healthFactor
  ) internal returns (uint256) {
    _increaseCollateralSupply(spoke1, _daiReserveId(spoke1), collateralAmount, alice);
    _borrowToBeAtHf(spoke1, alice, _usdxReserveId(spoke1), healthFactor);
    return spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice);
  }

  /// @dev Converts a collateral cap to the debt repaid when the cap binds (dai and usdx both $1).
  function _capToDebtRepaid(uint256 maxCollateralToRemove) internal view returns (uint256) {
    return
      Math.mulDiv(
        _convertAssetAmount(
          spoke1,
          _daiReserveId(spoke1),
          maxCollateralToRemove,
          _usdxReserveId(spoke1)
        ),
        PercentageMath.PERCENTAGE_FACTOR,
        LIQUIDATION_BONUS,
        Math.Rounding.Ceil
      );
  }

  function _getCollateralValue(
    ISpoke spoke,
    uint256 collateralReserveId,
    address user
  ) internal view returns (uint256) {
    return
      _convertAmountToValue(
        spoke,
        collateralReserveId,
        spoke.getUserSuppliedAssets(collateralReserveId, user)
      );
  }
}
