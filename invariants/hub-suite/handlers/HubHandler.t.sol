// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {IHubHandler} from './interfaces/IHubHandler.sol';

// Libraries
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

// Test Contracts
import {Actor} from '../../shared/utils/Actor.sol';
import {BaseHandler} from '../base/BaseHandler.t.sol';

/// @title HubHandler
/// @notice Handler for hub-level operations through actor-spokes
contract HubHandler is BaseHandler, IHubHandler {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      ACTIONS                                              //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function add(uint256 amount, uint8 i) public setup returns (uint256 addedShares) {
    uint256 assetId = _getRandomBaseAssetId(i);
    address underlying = assetIdToUnderlying[assetId];

    uint256 previewAddedShares = hub.previewAddByAssets(assetId, amount);

    uint256 assetsBefore = hub.getSpokeAddedAssets(assetId, address(actor));
    uint256 sharesBefore = hub.getSpokeAddedShares(assetId, address(actor));

    _mint(underlying, address(hub), amount);

    _before();
    (bool ok, bytes memory ret) = actor.proxy(
      address(hub),
      abi.encodeCall(IHubBase.add, (assetId, amount))
    );

    if (ok) {
      _after();

      addedShares = abi.decode(ret, (uint256));

      assertGe(
        assetsBefore + amount,
        hub.getSpokeAddedAssets(assetId, address(actor)),
        HSPOST_HUB_ERC4626_ADD_A
      );
      assertEq(
        sharesBefore + addedShares,
        hub.getSpokeAddedShares(assetId, address(actor)),
        HSPOST_HUB_ERC4626_ADD_B
      );

      assertLe(previewAddedShares, addedShares, HSPOST_HUB_ERC4626_ADD_C);
    } else {
      vm.assume(false);
    }
  }

  function remove(uint256 amount, uint8 i) public setup returns (uint256 removedShares) {
    uint256 assetId = _getRandomBaseAssetId(i);

    uint256 previewRemovedShares = hub.previewRemoveByAssets(assetId, amount);

    uint256 assetsBefore = hub.getSpokeAddedAssets(assetId, address(actor));
    uint256 sharesBefore = hub.getSpokeAddedShares(assetId, address(actor));

    _before();
    (bool ok, bytes memory ret) = actor.proxy(
      address(hub),
      abi.encodeCall(IHubBase.remove, (assetId, amount, address(actor)))
    );

    if (ok) {
      _after();

      removedShares = uint256(abi.decode(ret, (uint256)));

      assertGe(
        assetsBefore,
        hub.getSpokeAddedAssets(assetId, address(actor)) + amount,
        HSPOST_HUB_ERC4626_REMOVE_A
      );
      assertEq(
        sharesBefore,
        hub.getSpokeAddedShares(assetId, address(actor)) + removedShares,
        HSPOST_HUB_ERC4626_REMOVE_B
      );

      assertGe(previewRemovedShares, removedShares, HSPOST_HUB_ERC4626_REMOVE_C);
    } else {
      vm.assume(false);
    }
  }

  function draw(uint256 amount, uint8 i) public setup returns (uint256 drawnShares) {
    uint256 assetId = _getRandomBaseAssetId(i);

    uint256 previewDrawnShares = hub.previewDrawByAssets(assetId, amount);

    (uint256 drawnBefore, ) = hub.getSpokeOwed(assetId, address(actor));
    uint256 sharesBefore = hub.getSpokeDrawnShares(assetId, address(actor));

    _before();
    (bool ok, bytes memory ret) = actor.proxy(
      address(hub),
      abi.encodeCall(IHubBase.draw, (assetId, amount, address(actor)))
    );

    if (ok) {
      _after();

      drawnShares = uint256(abi.decode(ret, (uint256)));

      (uint256 drawnAfter, ) = hub.getSpokeOwed(assetId, address(actor));

      assertLe(drawnBefore + amount, drawnAfter, HSPOST_HUB_ERC4626_DRAW_A);
      assertEq(
        sharesBefore + drawnShares,
        hub.getSpokeDrawnShares(assetId, address(actor)),
        HSPOST_HUB_ERC4626_DRAW_B
      );

      assertGe(previewDrawnShares, drawnShares, HSPOST_HUB_ERC4626_DRAW_C);
    } else {
      vm.assume(false);
    }
  }

  function restore(
    uint256 drawnAmount,
    uint256 premiumAmount,
    int256 sharesDelta,
    uint8 i
  ) public setup returns (uint256 restoredDrawnShares) {
    uint256 assetId = _getRandomBaseAssetId(i);

    uint256 previewRestoredShares = hub.previewRestoreByAssets(assetId, drawnAmount);

    (uint256 drawnBefore, ) = hub.getSpokeOwed(assetId, address(actor));
    uint256 drawnSharesBefore = hub.getSpokeDrawnShares(assetId, address(actor));

    IHubBase.PremiumDelta memory premiumDelta = _calculatePremiumDelta(
      sharesDelta,
      premiumAmount,
      assetId
    );

    _mint(assetIdToUnderlying[assetId], address(hub), drawnAmount + premiumAmount);

    _before();
    (bool ok, bytes memory ret) = actor.proxy(
      address(hub),
      abi.encodeCall(IHubBase.restore, (assetId, drawnAmount, premiumDelta))
    );

    if (ok) {
      _after();

      restoredDrawnShares = uint256(abi.decode(ret, (uint256)));

      (uint256 drawnAfter, ) = hub.getSpokeOwed(assetId, address(actor));

      if (restoredDrawnShares > 0) {
        uint256 tolerance = hub.previewRestoreByShares(assetId, 1);
        assertApproxEqAbs(
          drawnBefore,
          drawnAfter + drawnAmount,
          tolerance,
          HSPOST_HUB_ERC4626_RESTORE_A
        );
      } else {
        // dust case, all restored assets donated
        assertEq(drawnAfter, drawnBefore, HSPOST_HUB_ERC4626_RESTORE_A);
      }
      assertEq(
        drawnSharesBefore,
        hub.getSpokeDrawnShares(assetId, address(actor)) + restoredDrawnShares,
        HSPOST_HUB_ERC4626_RESTORE_B
      );

      assertLe(previewRestoredShares, restoredDrawnShares, HSPOST_HUB_ERC4626_RESTORE_C);
    } else {
      vm.assume(false);
    }
  }

  function reportDeficit(
    uint256 drawnAmount,
    uint256 premiumAmount,
    int256 sharesDelta,
    uint8 i
  ) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);

    IHubBase.PremiumDelta memory premiumDelta = _calculatePremiumDelta(
      sharesDelta,
      premiumAmount,
      assetId
    );

    _before();
    (bool ok, ) = actor.proxy(
      address(hub),
      abi.encodeCall(IHubBase.reportDeficit, (assetId, drawnAmount, premiumDelta))
    );

    if (ok) {
      _after();
    } else {
      vm.assume(false);
    }
  }

  function eliminateDeficit(uint256 amount, uint8 i) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);
    // only spoke3 is given deficit eliminator role
    address spoke = address(userToActor[USER3]);

    _before();
    (bool ok, ) = actor.proxy(
      address(hub),
      abi.encodeCall(IHub.eliminateDeficit, (assetId, amount, spoke))
    );

    if (ok) {
      _after();
    } else {
      vm.assume(false);
    }
  }

  function refreshPremium(int256 sharesDelta, uint8 i) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);

    int256 offsetRayDelta = sharesDelta * int256(hub.getAssetDrawnIndex(assetId));
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: sharesDelta,
      offsetRayDelta: offsetRayDelta,
      restoredPremiumRay: 0
    });

    _before();
    (bool ok, ) = actor.proxy(
      address(hub),
      abi.encodeCall(IHubBase.refreshPremium, (assetId, premiumDelta))
    );

    if (ok) {
      _after();

      // HSPOST_HUB_M: refreshPremium cannot change total premium debt (only redistribution)
      assertEq(
        _assetVarsAfter(assetId).debt.premium,
        _assetVarsBefore(assetId).debt.premium,
        HSPOST_HUB_M
      );
    } else {
      vm.assume(false);
    }
  }

  // @dev broader `refreshPremium` to cover edge cases, above case exists for narrow happy path
  function refreshPremiumBroad(IHubBase.PremiumDelta memory premiumDelta, uint8 i) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);

    _before();
    (bool ok, ) = actor.proxy(
      address(hub),
      abi.encodeCall(IHubBase.refreshPremium, (assetId, premiumDelta))
    );

    if (ok) {
      _after();

      // HSPOST_HUB_M: refreshPremium cannot change total premium debt (only redistribution)
      assertEq(
        _assetVarsAfter(assetId).debt.premium,
        _assetVarsBefore(assetId).debt.premium,
        HSPOST_HUB_M
      );
    } else {
      vm.assume(false);
    }
  }

  function payFeeShares(uint256 shares, uint8 i) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);

    _before();
    (bool ok, ) = actor.proxy(
      address(hub),
      abi.encodeCall(IHubBase.payFeeShares, (assetId, shares))
    );
    if (ok) {
      _after();
    } else {
      vm.assume(false);
    }
  }

  function transferShares(uint256 shares, uint8 i, uint8 j) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);
    address toSpoke = _getRandomActor(j);

    _before();
    (bool ok, ) = actor.proxy(
      address(hub),
      abi.encodeCall(IHub.transferShares, (assetId, shares, toSpoke))
    );

    if (ok) {
      _after();
    } else {
      vm.assume(false);
    }
  }

  function sweep(uint256 amount, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);

    _before();
    // handler is the reinvestmentController
    try hub.sweep(assetId, amount) {
      _after();
    } catch {
      vm.assume(false);
    }
  }

  function reclaim(uint256 amount, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    address underlying = assetIdToUnderlying[assetId];

    _mint(underlying, address(hub), amount);

    _before();
    // handler is the reinvestmentController
    try hub.reclaim(assetId, amount) {
      _after();
    } catch {
      vm.assume(false);
    }
  }

  function mintFeeShares(uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    _before();
    try hub.mintFeeShares(assetId) {
      _after();
    } catch {
      vm.assume(false);
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                              ERC4626 ROUNDTRIP (STATELESS)                                //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Stateless roundtrip checks — pure preview calls, no state changes.

  /// @dev A: previewRemoveByShares(previewAddByAssets(a)) <= a
  function roundtrip_ERC4626_RT_A(uint256 amount, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    uint256 shares = hub.previewAddByAssets(assetId, amount);
    uint256 assets = hub.previewRemoveByShares(assetId, shares);
    assertLe(assets, amount, INV_HUB_ERC4626_RT_A);
  }

  /// @dev B: previewRemoveByAssets(a) >= previewAddByAssets(a)
  function roundtrip_ERC4626_RT_B(uint256 amount, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    uint256 sDeposit = hub.previewAddByAssets(assetId, amount);
    uint256 sWithdraw = hub.previewRemoveByAssets(assetId, amount);
    assertGe(sWithdraw, sDeposit, INV_HUB_ERC4626_RT_B);
  }

  /// @dev C: previewAddByAssets(previewRemoveByShares(s)) <= s
  function roundtrip_ERC4626_RT_C(uint256 shares, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    uint256 assets = hub.previewRemoveByShares(assetId, shares);
    uint256 resultShares = hub.previewAddByAssets(assetId, assets);
    assertLe(resultShares, shares, INV_HUB_ERC4626_RT_C);
  }

  /// @dev D: previewAddByShares(s) >= previewRemoveByShares(s)
  function roundtrip_ERC4626_RT_D(uint256 shares, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    uint256 aRedeem = hub.previewRemoveByShares(assetId, shares);
    uint256 aMint = hub.previewAddByShares(assetId, shares);
    assertGe(aMint, aRedeem, INV_HUB_ERC4626_RT_D);
  }

  /// @dev E: previewRemoveByAssets(previewAddByShares(s)) >= s
  function roundtrip_ERC4626_RT_E(uint256 shares, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    uint256 assets = hub.previewAddByShares(assetId, shares);
    uint256 resultShares = hub.previewRemoveByAssets(assetId, assets);
    assertGe(resultShares, shares, INV_HUB_ERC4626_RT_E);
  }

  /// @dev F: previewRemoveByShares(s) <= previewAddByShares(s)
  function roundtrip_ERC4626_RT_F(uint256 shares, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    uint256 aMint = hub.previewAddByShares(assetId, shares);
    uint256 aRedeem = hub.previewRemoveByShares(assetId, shares);
    assertLe(aRedeem, aMint, INV_HUB_ERC4626_RT_F);
  }

  /// @dev G: previewAddByShares(previewRemoveByAssets(a)) >= a
  function roundtrip_ERC4626_RT_G(uint256 amount, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    uint256 shares = hub.previewRemoveByAssets(assetId, amount);
    uint256 assets = hub.previewAddByShares(assetId, shares);
    assertGe(assets, amount, INV_HUB_ERC4626_RT_G);
  }

  /// @dev H: previewAddByAssets(a) <= previewRemoveByAssets(a)
  function roundtrip_ERC4626_RT_H(uint256 amount, uint8 i) external {
    uint256 assetId = _getRandomBaseAssetId(i);
    uint256 sWithdraw = hub.previewRemoveByAssets(assetId, amount);
    uint256 sDeposit = hub.previewAddByAssets(assetId, amount);
    assertLe(sDeposit, sWithdraw, INV_HUB_ERC4626_RT_H);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _calculatePremiumDelta(
    int256 sharesDelta,
    uint256 premiumAmount,
    uint256 assetId
  ) internal view returns (IHubBase.PremiumDelta memory) {
    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    // Calculate restoredPremiumRay from premiumAmount
    uint256 restoredPremiumRay = premiumAmount * WadRayMath.RAY;

    // Calculate offsetRayDelta to satisfy: (sharesDelta * drawnIndex) - offsetRayDelta + restoredPremiumRay == 0
    // Therefore: offsetRayDelta = (sharesDelta * drawnIndex) + restoredPremiumRay
    int256 offsetRayDelta = (sharesDelta * int256(drawnIndex)) + int256(restoredPremiumRay);

    return
      IHubBase.PremiumDelta({
        sharesDelta: sharesDelta,
        offsetRayDelta: offsetRayDelta,
        restoredPremiumRay: restoredPremiumRay
      });
  }
}
