// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubRefreshPremiumDebt is LiquidityHubBase {
  struct PremiumDataLocal {
    uint256 premiumDebtShares;
    uint256 premiumOffset;
    uint256 realizedPremium;
  }

  struct SignedPremiumDataLocal {
    int256 premiumDebtShares;
    int256 premiumOffset;
    int256 realizedPremium;
  }

  function _loadAssetPremiumData(uint256 assetId) internal view returns (PremiumDataLocal memory) {
    DataTypes.Asset memory assetData = hub.getAsset(assetId);
    return
      PremiumDataLocal(
        assetData.premiumDrawnShares,
        assetData.premiumOffset,
        assetData.realizedPremium
      );
  }

  function _loadSpokePremiumData(
    uint256 assetId,
    address spoke
  ) internal view returns (PremiumDataLocal memory) {
    DataTypes.SpokeData memory spokeData = hub.getSpoke(assetId, spoke);
    return
      PremiumDataLocal(
        spokeData.premiumDrawnShares,
        spokeData.premiumOffset,
        spokeData.realizedPremium
      );
  }

  function _assertPremiumData(PremiumDataLocal memory a, PremiumDataLocal memory b) internal pure {
    assertEq(a.premiumDebtShares, b.premiumDebtShares, 'premium debt shares do not match');
    assertEq(a.premiumOffset, b.premiumOffset, 'premium offset do not match');
    assertEq(a.realizedPremium, b.realizedPremium, 'realized premium do not match');
  }

  // only assets listed can be refreshed
  function test_refresh_revertsWith_AssetNotListed() public {
    uint256 notListedAsset = hub.assetCount() + 1;

    vm.expectRevert(ILiquidityHub.AssetNotListed.selector);
    vm.prank(address(spoke1));
    hub.refreshPremiumDebt(notListedAsset, 1, 1, 1);
  }

  // only authorized spokes can refresh
  function test_refresh_revertsWith_AuthorizedSpoke() public {
    // TODO
  }

  // refresh premium data from initial state
  function test_refresh_from_init() public {
    uint256 assetId = 0;
    _assertPremiumData(_loadAssetPremiumData(assetId), PremiumDataLocal(0, 0, 0));
    _assertPremiumData(_loadSpokePremiumData(assetId, address(spoke1)), PremiumDataLocal(0, 0, 0));

    vm.expectEmit(address(hub));
    emit ILiquidityHub.RefreshPremiumDebt(
      assetId,
      address(spoke1),
      int256(5),
      int256(10),
      int256(15)
    );
    vm.prank(address(spoke1));
    hub.refreshPremiumDebt(assetId, 5, 10, 15);

    _assertPremiumData(_loadAssetPremiumData(assetId), PremiumDataLocal(5, 10, 15));
    _assertPremiumData(
      _loadSpokePremiumData(assetId, address(spoke1)),
      PremiumDataLocal(5, 10, 15)
    );
  }

  // premium data values cannot go negative
  function test_refresh_from_init_revertsWith_underflow() public {
    uint256 assetId = 0;
    _assertPremiumData(_loadAssetPremiumData(assetId), PremiumDataLocal(0, 0, 0));
    _assertPremiumData(_loadSpokePremiumData(assetId, address(spoke1)), PremiumDataLocal(0, 0, 0));

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(address(spoke1));
    hub.refreshPremiumDebt(assetId, -1, -1, -1);
  }

  // refresh premium data with positive values from initial state
  function test_refresh_from_init_fuzz_positive_amounts(
    uint256 assetId,
    uint256 premiumDebtShares,
    uint256 premiumOffset,
    uint256 realizedPremium
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    premiumDebtShares = bound(premiumDebtShares, 0, MAX_SUPPLY_AMOUNT / 2);
    premiumOffset = bound(premiumOffset, 0, MAX_SUPPLY_AMOUNT / 2);
    realizedPremium = bound(realizedPremium, 0, MAX_SUPPLY_AMOUNT / 2);

    _assertPremiumData(_loadAssetPremiumData(assetId), PremiumDataLocal(0, 0, 0));
    _assertPremiumData(_loadSpokePremiumData(assetId, address(spoke1)), PremiumDataLocal(0, 0, 0));

    vm.expectEmit(address(hub));
    emit ILiquidityHub.RefreshPremiumDebt(
      assetId,
      address(spoke1),
      int256(premiumDebtShares),
      int256(premiumOffset),
      int256(realizedPremium)
    );
    vm.prank(address(spoke1));
    hub.refreshPremiumDebt(
      assetId,
      int256(premiumDebtShares),
      int256(premiumOffset),
      int256(realizedPremium)
    );

    _assertPremiumData(
      _loadAssetPremiumData(assetId),
      PremiumDataLocal(premiumDebtShares, premiumOffset, realizedPremium)
    );
    _assertPremiumData(
      _loadSpokePremiumData(assetId, address(spoke1)),
      PremiumDataLocal(premiumDebtShares, premiumOffset, realizedPremium)
    );
  }

  // refresh premium data
  function test_refresh_fuzz_amounts(
    uint256 assetId,
    uint256 initPremiumShares,
    uint256 initPremiumOffset,
    uint256 initRealizedPremium,
    uint256 premiumDebtShares,
    uint256 premiumOffset,
    uint256 realizedPremium
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    initPremiumShares = bound(initPremiumShares, 0, MAX_SUPPLY_AMOUNT / 2);
    initPremiumOffset = bound(initPremiumOffset, 0, MAX_SUPPLY_AMOUNT / 2);
    initRealizedPremium = bound(initRealizedPremium, 0, MAX_SUPPLY_AMOUNT / 2);
    premiumDebtShares = bound(premiumDebtShares, 0, MAX_SUPPLY_AMOUNT / 2);
    premiumOffset = bound(premiumOffset, 0, MAX_SUPPLY_AMOUNT / 2);
    realizedPremium = bound(realizedPremium, 0, MAX_SUPPLY_AMOUNT / 2);

    // random sign: negative if even
    int256 newPremiumShares = (initPremiumShares + premiumDebtShares) % 2 == 0
      ? -int256(premiumDebtShares)
      : int256(premiumDebtShares);
    int256 newPremiumOffset = (initPremiumOffset + premiumOffset) % 2 == 0
      ? -int256(premiumOffset)
      : int256(premiumOffset);
    int256 newRealizedPremium = (initRealizedPremium + realizedPremium) % 2 == 0
      ? -int256(realizedPremium)
      : int256(realizedPremium);

    // init state
    vm.prank(address(spoke1));
    hub.refreshPremiumDebt(
      assetId,
      int256(initPremiumShares),
      int256(initPremiumOffset),
      int256(initRealizedPremium)
    );
    _assertPremiumData(
      _loadAssetPremiumData(assetId),
      PremiumDataLocal(initPremiumShares, initPremiumOffset, initRealizedPremium)
    );
    _assertPremiumData(
      _loadSpokePremiumData(assetId, address(spoke1)),
      PremiumDataLocal(initPremiumShares, initPremiumOffset, initRealizedPremium)
    );

    // Detect underflow
    if (
      newPremiumShares + int256(initPremiumShares) < 0 ||
      newPremiumOffset + int256(initPremiumOffset) < 0 ||
      newRealizedPremium + int256(initRealizedPremium) < 0
    ) {
      vm.expectRevert(stdError.arithmeticError);
      vm.prank(address(spoke1));
      hub.refreshPremiumDebt(assetId, newPremiumShares, newPremiumOffset, newRealizedPremium);

      _assertPremiumData(
        _loadAssetPremiumData(assetId),
        PremiumDataLocal(initPremiumShares, initPremiumOffset, initRealizedPremium)
      );
      _assertPremiumData(
        _loadSpokePremiumData(assetId, address(spoke1)),
        PremiumDataLocal(initPremiumShares, initPremiumOffset, initRealizedPremium)
      );
    } else {
      vm.expectEmit(address(hub));
      emit ILiquidityHub.RefreshPremiumDebt(
        assetId,
        address(spoke1),
        int256(newPremiumShares),
        int256(newPremiumOffset),
        int256(newRealizedPremium)
      );
      vm.prank(address(spoke1));
      hub.refreshPremiumDebt(assetId, newPremiumShares, newPremiumOffset, newRealizedPremium);

      PremiumDataLocal memory newData = PremiumDataLocal(
        uint256(newPremiumShares + int256(initPremiumShares)),
        uint256(newPremiumOffset + int256(initPremiumOffset)),
        uint256(newRealizedPremium + int256(initRealizedPremium))
      );
      _assertPremiumData(_loadAssetPremiumData(assetId), newData);
      _assertPremiumData(_loadSpokePremiumData(assetId, address(spoke1)), newData);
    }
  }

  // refresh premium data of DAI by 3 different spokes
  /// forge-config: default.fuzz.runs = 100
  function test_refresh_fuzz_amounts_multiple(
    uint256 spokeIndex,
    uint256 initPremiumShares,
    uint256 initPremiumOffset,
    uint256 initRealizedPremium,
    uint256 targetToChange,
    uint256 newValue
  ) public {
    uint256 assetId = daiAssetId;
    address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];
    spokeIndex = bound(spokeIndex, 0, spokes.length - 1);
    initPremiumShares = bound(initPremiumShares, 0, MAX_SUPPLY_AMOUNT / 2);
    initPremiumOffset = bound(initPremiumOffset, 0, MAX_SUPPLY_AMOUNT / 2);
    initRealizedPremium = bound(initRealizedPremium, 0, MAX_SUPPLY_AMOUNT / 2);
    targetToChange = bound(targetToChange, 0, 3); // [premiumDebtShares, premiumOffset, realizedPremium]
    newValue = bound(newValue, 0, MAX_SUPPLY_AMOUNT / 2);

    for (uint256 i = 0; i < 10; i++) {
      // random sign: negative if even

      PremiumDataLocal memory assetDataBefore = _loadAssetPremiumData(assetId);
      PremiumDataLocal memory spokeDataBefore = _loadSpokePremiumData(assetId, spokes[spokeIndex]);

      // Choose which value to change and limit maximum amount to decrease (in case of negative)
      SignedPremiumDataLocal memory newData;
      // Detect first time
      if (
        spokeDataBefore.premiumDebtShares +
          spokeDataBefore.premiumOffset +
          spokeDataBefore.realizedPremium ==
        0
      ) {
        newData = SignedPremiumDataLocal(
          int256(initPremiumShares),
          int256(initPremiumOffset),
          int256(targetToChange)
        );
      } else {
        bool negative = (initPremiumShares + initPremiumOffset + initRealizedPremium) % 2 == 0;
        if (targetToChange == 0) {
          newData.premiumDebtShares = negative ? -int256(newValue) : int256(newValue);
          if (newData.premiumDebtShares + int256(spokeDataBefore.premiumDebtShares) < 0) {
            newData.premiumDebtShares = -int256(spokeDataBefore.premiumDebtShares);
          }
        } else if (targetToChange == 1) {
          newData.premiumOffset = negative ? -int256(newValue) : int256(newValue);
          if (newData.premiumOffset + int256(spokeDataBefore.premiumOffset) < 0) {
            newData.premiumOffset = -int256(spokeDataBefore.premiumOffset);
          }
        } else {
          newData.realizedPremium = negative ? -int256(newValue) : int256(newValue);
          if (newData.realizedPremium + int256(spokeDataBefore.realizedPremium) < 0) {
            newData.realizedPremium = -int256(spokeDataBefore.realizedPremium);
          }
        }
      }

      emit ILiquidityHub.RefreshPremiumDebt(
        assetId,
        spokes[spokeIndex],
        newData.premiumDebtShares,
        newData.premiumOffset,
        newData.realizedPremium
      );
      vm.prank(spokes[spokeIndex]);
      hub.refreshPremiumDebt(
        assetId,
        newData.premiumDebtShares,
        newData.premiumOffset,
        newData.realizedPremium
      );

      _assertPremiumData(
        _loadAssetPremiumData(assetId),
        PremiumDataLocal(
          uint256(newData.premiumDebtShares + int256(assetDataBefore.premiumDebtShares)),
          uint256(newData.premiumOffset + int256(assetDataBefore.premiumOffset)),
          uint256(newData.realizedPremium + int256(assetDataBefore.realizedPremium))
        )
      );
      _assertPremiumData(
        _loadSpokePremiumData(assetId, spokes[spokeIndex]),
        PremiumDataLocal(
          uint256(newData.premiumDebtShares + int256(spokeDataBefore.premiumDebtShares)),
          uint256(newData.premiumOffset + int256(spokeDataBefore.premiumOffset)),
          uint256(newData.realizedPremium + int256(spokeDataBefore.realizedPremium))
        )
      );
    }
  }
}
