// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {AccessManagedUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/AccessManagedUpgradeable.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {TransientFlashLoanMap} from 'src/spoke/libraries/TransientFlashLoanMap.sol';
import {IFlashLoanReceiver} from 'src/spoke/interfaces/IFlashLoanReceiver.sol';
import {IFlashLoanSimpleReceiver} from 'src/spoke/interfaces/IFlashLoanSimpleReceiver.sol';
import {IFlashLoanSpoke} from 'src/spoke/interfaces/IFlashLoanSpoke.sol';
import {FlashLoanSpokeStorage} from 'src/spoke/FlashLoanSpokeStorage.sol';

/// @title FlashLoanSpoke
/// @author Aave Labs
/// @notice Spoke lending the liquidity of the connected Hub for the duration of a single call.
/// @dev Repayment is always pulled from the receiver: an unpaid flashloan reverts and never opens a debt position.
/// @dev Outside of an ongoing flashloan, holds no funds and no Hub position other than the drawn shares left by
/// fee-waived flashloans, restored out of the next fees or with `repayRoundingDebt`.
abstract contract FlashLoanSpoke is
  IFlashLoanSpoke,
  FlashLoanSpokeStorage,
  AccessManagedUpgradeable
{
  using SafeCast for uint256;
  using SafeERC20 for IERC20;
  using PercentageMath for uint256;

  /// @inheritdoc IFlashLoanSpoke
  uint16 public constant DEFAULT_PREMIUM = 5;

  /// @inheritdoc IFlashLoanSpoke
  uint16 public constant USE_DEFAULT_PREMIUM = type(uint16).max;

  /// @dev To be overridden by the inheriting FlashLoanSpoke instance contract.
  function initialize(address authority, address hub) external virtual;

  /// @inheritdoc IFlashLoanSpoke
  function updateAssetConfig(address underlying, uint16 premium, bool enabled) external restricted {
    require(
      premium <= PercentageMath.PERCENTAGE_FACTOR || premium == USE_DEFAULT_PREMIUM,
      InvalidPremium()
    );
    uint16 assetId = _hub.getAssetId(underlying).toUint16();
    FlashLoanAsset storage asset = _assets[underlying];
    asset.assetId = assetId;
    asset.premium = premium;
    asset.enabled = enabled;
    emit UpdateAssetConfig(underlying, assetId, premium, enabled);
  }

  /// @inheritdoc IFlashLoanSpoke
  function updateFlashBorrower(address borrower, bool authorized) external restricted {
    _flashBorrowers[borrower] = authorized;
    emit UpdateFlashBorrower(borrower, authorized);
  }

  /// @inheritdoc IFlashLoanSpoke
  function repayRoundingDebt(address underlying) external restricted returns (uint256) {
    IHubBase hub = _hub;
    uint256 assetId = hub.getAssetId(underlying);
    uint256 roundingDebt = hub.previewRestoreByShares(
      assetId,
      hub.getSpokeDrawnShares(assetId, address(this))
    );
    _assets[underlying].hasRoundingDebt = false;
    IERC20(underlying).safeTransferFrom(msg.sender, address(hub), roundingDebt);
    hub.restore(
      assetId,
      roundingDebt,
      IHubBase.PremiumDelta({sharesDelta: 0, offsetRayDelta: 0, restoredPremiumRay: 0})
    );
    emit RepayRoundingDebt(underlying, msg.sender, roundingDebt);
    return roundingDebt;
  }

  /// @inheritdoc IFlashLoanSpoke
  function flashLoan(
    address receiver,
    address[] calldata assets,
    uint256[] calldata amounts,
    bytes calldata params
  ) external {
    uint256 length = assets.length;
    require(length == amounts.length, InconsistentFlashLoanParams());

    IHubBase hub = _hub;
    uint256[] memory assetIds = new uint256[](length);
    uint256[] memory fees = new uint256[](length);
    uint256[] memory premiums = new uint256[](length);
    for (uint256 i; i < length; ++i) {
      (assetIds[i], fees[i], premiums[i]) = _draw(hub, receiver, assets[i], amounts[i]);
    }

    require(
      IFlashLoanReceiver(receiver).executeOperation(assets, amounts, premiums, msg.sender, params),
      InvalidFlashLoanExecutorReturn()
    );

    for (uint256 i; i < length; ++i) {
      _repay(hub, receiver, assets[i], assetIds[i], amounts[i], premiums[i], fees[i]);
    }
  }

  /// @inheritdoc IFlashLoanSpoke
  function flashLoanSimple(
    address receiver,
    address asset,
    uint256 amount,
    bytes calldata params
  ) external {
    IHubBase hub = _hub;
    (uint256 assetId, uint256 fee, uint256 premium) = _draw(hub, receiver, asset, amount);

    require(
      IFlashLoanSimpleReceiver(receiver).executeOperation(
        asset,
        amount,
        premium,
        msg.sender,
        params
      ),
      InvalidFlashLoanExecutorReturn()
    );

    _repay(hub, receiver, asset, assetId, amount, premium, fee);
  }

  /// @inheritdoc IFlashLoanSpoke
  function getFlashLoanAsset(address underlying) external view returns (FlashLoanAsset memory) {
    return _assets[underlying];
  }

  /// @inheritdoc IFlashLoanSpoke
  function isFlashBorrower(address borrower) external view returns (bool) {
    return _flashBorrowers[borrower];
  }

  /// @inheritdoc IFlashLoanSpoke
  function getHub() external view returns (IHubBase) {
    return _hub;
  }

  /// @dev Draws `amount` of `underlying` from the Hub to `receiver`, and records it as an ongoing flashloan.
  /// @return The identifier of the asset in the Hub.
  /// @return The part of the premium owed to the Hub fee receiver.
  /// @return The premium owed by the receiver on top of `amount`.
  function _draw(
    IHubBase hub,
    address receiver,
    address underlying,
    uint256 amount
  ) internal returns (uint256, uint256, uint256) {
    FlashLoanAsset memory asset = _assets[underlying];
    require(asset.enabled, FlashLoanDisabled());

    (uint256 flashAmount, uint256 accruedFee) = TransientFlashLoanMap.get(underlying);
    TransientFlashLoanMap.set(underlying, flashAmount + amount, accruedFee);

    uint256 drawnShares = hub.draw(asset.assetId, amount, receiver);

    if (_flashBorrowers[msg.sender]) {
      // restoring `amount` leaves the rounded up part of the drawn shares, restored out of the next fees
      if (!asset.hasRoundingDebt) {
        _assets[underlying].hasRoundingDebt = true;
      }
      return (asset.assetId, 0, 0);
    }

    uint256 fee = amount.percentMulUp(
      asset.premium == USE_DEFAULT_PREMIUM ? DEFAULT_PREMIUM : asset.premium
    );
    // drawn shares are rounded up, so restoring all of them can cost slightly more than `amount`;
    // this rounding is paid out of the fee, and only charged on top when it exceeds the fee
    uint256 rounding = hub.previewRestoreByShares(asset.assetId, drawnShares) - amount;
    uint256 premium = fee > rounding ? fee : rounding;

    return (asset.assetId, premium - rounding, premium);
  }

  /// @dev Pulls `amount + premium` of `underlying` from `receiver` into the Hub and restores the drawn
  /// liquidity. Accrues `fee`, paid once all ongoing flashloans of `underlying` are repaid.
  function _repay(
    IHubBase hub,
    address receiver,
    address underlying,
    uint256 assetId,
    uint256 amount,
    uint256 premium,
    uint256 fee
  ) internal {
    uint256 amountPlusPremium = amount + premium;
    IERC20(underlying).safeTransferFrom(receiver, address(hub), amountPlusPremium);
    hub.restore(
      assetId,
      amountPlusPremium - fee,
      IHubBase.PremiumDelta({sharesDelta: 0, offsetRayDelta: 0, restoredPremiumRay: 0})
    );

    (uint256 flashAmount, uint256 accruedFee) = TransientFlashLoanMap.get(underlying);
    flashAmount -= amount;
    accruedFee += fee;
    if (flashAmount == 0) {
      TransientFlashLoanMap.set(underlying, 0, 0);
      if (accruedFee > 0) {
        _payFee(hub, underlying, assetId, accruedFee);
      }
    } else {
      TransientFlashLoanMap.set(underlying, flashAmount, accruedFee);
    }

    emit FlashLoan(receiver, msg.sender, underlying, amount, premium);
  }

  /// @dev Pays `fee` of `underlying`, with the pending fee, to the Hub fee receiver.
  /// @dev The fee tokens are already in the Hub, so `restore` and `add` account them without a transfer.
  /// @dev The fee first restores the rounding debt of the asset. A fee not covering it, or too small to mint
  /// one added share, stays in the Hub as untracked liquidity and is recorded as pending, to be paid with the
  /// next fee of the asset.
  function _payFee(IHubBase hub, address underlying, uint256 assetId, uint256 fee) internal {
    FlashLoanAsset storage asset = _assets[underlying];
    uint256 pendingFee = asset.pendingFee;
    fee += pendingFee;
    if (asset.hasRoundingDebt) {
      uint256 roundingDebt = hub.previewRestoreByShares(
        assetId,
        hub.getSpokeDrawnShares(assetId, address(this))
      );
      if (fee < roundingDebt) {
        asset.pendingFee = fee.toUint120();
        return;
      }
      asset.hasRoundingDebt = false;
      if (roundingDebt > 0) {
        hub.restore(
          assetId,
          roundingDebt,
          IHubBase.PremiumDelta({sharesDelta: 0, offsetRayDelta: 0, restoredPremiumRay: 0})
        );
        fee -= roundingDebt;
      }
    }
    if (hub.previewAddByAssets(assetId, fee) == 0) {
      asset.pendingFee = fee.toUint120();
    } else {
      if (pendingFee > 0) {
        asset.pendingFee = 0;
      }
      hub.payFeeShares(assetId, hub.add(assetId, fee));
    }
  }
}
