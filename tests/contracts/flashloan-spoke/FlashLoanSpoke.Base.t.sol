// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';
import {FlashLoanSpokeInstance} from 'src/spoke/instances/FlashLoanSpokeInstance.sol';
import {IFlashLoanSpoke} from 'src/spoke/interfaces/IFlashLoanSpoke.sol';
import {IFlashLoanReceiver} from 'src/spoke/interfaces/IFlashLoanReceiver.sol';
import {IFlashLoanSimpleReceiver} from 'src/spoke/interfaces/IFlashLoanSimpleReceiver.sol';
import {MockFlashLoanReceiver} from 'tests/helpers/mocks/MockFlashLoanReceiver.sol';

contract FlashLoanSpokeBaseTest is Base {
  /// @dev Default premium the assets are configured with.
  uint16 internal constant PREMIUM = 5;
  bytes internal constant PARAMS = 'params';

  IFlashLoanSpoke internal flashLoanSpoke;
  MockFlashLoanReceiver internal receiver;
  address internal dai;
  address internal usdx;

  function setUp() public virtual override {
    super.setUp();
    dai = address(tokenList.dai);
    usdx = address(tokenList.usdx);

    flashLoanSpoke = IFlashLoanSpoke(
      AaveV4TestOrchestration.proxify(
        address(new FlashLoanSpokeInstance()),
        ADMIN,
        abi.encodeCall(FlashLoanSpokeInstance.initialize, (address(accessManager), address(hub1)))
      )
    );
    receiver = new MockFlashLoanReceiver(address(flashLoanSpoke));

    _registerFlashLoanSpoke(daiAssetId, dai);
    _registerFlashLoanSpoke(usdxAssetId, usdx);

    _addLiquidity(hub1, daiAssetId, 1_000_000e18);
    _addLiquidity(hub1, usdxAssetId, 1_000_000e6);
    // grows the drawn index and the added share price above 1
    _drawLiquidity(hub1, daiAssetId, 500_000e18, false);
    _drawLiquidity(hub1, usdxAssetId, 500_000e6, false);

    deal(dai, address(receiver), 1_000_000e18);
    deal(usdx, address(receiver), 1_000_000e6);
  }

  function _registerFlashLoanSpoke(uint256 assetId, address underlying) internal {
    vm.startPrank(ADMIN);
    hub1.addSpoke(
      assetId,
      address(flashLoanSpoke),
      IHub.SpokeConfig({
        addCap: MAX_ALLOWED_SPOKE_CAP,
        drawCap: MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    );
    flashLoanSpoke.updateAssetConfig(underlying, flashLoanSpoke.USE_DEFAULT_PREMIUM(), true);
    vm.stopPrank();
  }

  /// @dev Extra cost of restoring the shares drawn for `amount`.
  function _rounding(uint256 assetId, uint256 amount) internal view returns (uint256) {
    uint256 drawnShares = hub1.previewDrawByAssets(assetId, amount);
    return hub1.previewRestoreByShares(assetId, drawnShares) - amount;
  }

  /// @dev Drawn shares left by restoring `amount` after drawing it.
  function _dustShares(uint256 assetId, uint256 amount) internal view returns (uint256) {
    return hub1.previewDrawByAssets(assetId, amount) - hub1.previewRestoreByAssets(assetId, amount);
  }

  function _expectedPremium(
    uint256 assetId,
    uint256 amount,
    uint256 fee
  ) internal view returns (uint256) {
    uint256 rounding = _rounding(assetId, amount);
    return fee > rounding ? fee : rounding;
  }

  /// @dev Part of the premium paid to the Hub fee receiver.
  function _expectedFee(
    uint256 assetId,
    uint256 amount,
    uint256 fee
  ) internal view returns (uint256) {
    return _expectedPremium(assetId, amount, fee) - _rounding(assetId, amount);
  }

  function _assertNoPosition(uint256 assetId) internal view {
    assertEq(hub1.getSpokeDrawnShares(assetId, address(flashLoanSpoke)), 0);
    (uint256 premiumShares, int256 premiumOffsetRay) = hub1.getSpokePremiumData(
      assetId,
      address(flashLoanSpoke)
    );
    assertEq(premiumShares, 0);
    assertEq(premiumOffsetRay, 0);
    assertEq(hub1.getSpokeAddedShares(assetId, address(flashLoanSpoke)), 0);
    assertEq(IERC20(hub1.getAsset(assetId).underlying).balanceOf(address(flashLoanSpoke)), 0);
  }
}
