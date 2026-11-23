// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';

/// @title TreasurySpoke
/// @author Aave Labs
/// @notice Spoke contract used as a treasury where accumulated fees are treated as supplied assets.
/// @dev Dedicated to a single user, controlled by the owner.
/// @dev Allows withdraw to claim fees and supply to invest back into any Hub asset.
/// @dev The owner can appoint a claimer, which is only allowed to withdraw.
abstract contract TreasurySpoke is ITreasurySpoke, Ownable2StepUpgradeable {
  using SafeERC20 for IERC20;

  /// @custom:storage-location erc7201:aave-v4.storage.TreasurySpoke
  struct TreasurySpokeStorage {
    address claimer;
  }

  /// @dev The storage slot for the TreasurySpoke storage struct.
  bytes32 private constant NAMESPACE_SLOT =
    // keccak256(abi.encode(uint256(keccak256("aave-v4.storage.TreasurySpoke")) - 1)) & ~bytes32(uint256(0xff))
    0x1bd55573e426b29802faed3dc9cc719d77a1c32772e7e4624ead2291f5530800;

  /// @dev To be overridden by the inheriting TreasurySpoke instance contract.
  function initialize(address owner) external virtual;

  /// @inheritdoc ITreasurySpoke
  function setClaimer(address claimer) external onlyOwner {
    _getTreasurySpokeStorage().claimer = claimer;
    emit UpdateClaimer(claimer);
  }

  /// @inheritdoc ITreasurySpoke
  function supply(
    address hub,
    address underlying,
    uint256 amount
  ) external onlyOwner returns (uint256, uint256) {
    return _supply({hub: hub, underlying: underlying, amount: amount, skim: false});
  }

  /// @inheritdoc ITreasurySpoke
  function supplySkimmed(
    address hub,
    address underlying,
    uint256 amount
  ) external onlyOwner returns (uint256, uint256) {
    return _supply({hub: hub, underlying: underlying, amount: amount, skim: true});
  }

  /// @inheritdoc ITreasurySpoke
  function withdraw(
    address hub,
    address underlying,
    uint256 amount
  ) external returns (uint256, uint256) {
    require(
      msg.sender == owner() || msg.sender == _getTreasurySpokeStorage().claimer,
      OwnableUnauthorizedAccount(msg.sender)
    );
    IHubBase targetHub = IHubBase(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    // if amount to withdraw is greater than total supplied, withdraw all supplied assets
    uint256 withdrawnAmount = MathUtils.min(
      amount,
      targetHub.getSpokeAddedAssets(assetId, address(this))
    );
    uint256 withdrawnShares = targetHub.remove(assetId, withdrawnAmount, msg.sender);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ITreasurySpoke
  function transfer(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function getClaimer() external view returns (address) {
    return _getTreasurySpokeStorage().claimer;
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedAssets(address hub, address underlying) external view returns (uint256) {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    return targetHub.previewRemoveByShares(assetId, _getSuppliedShares(targetHub, assetId));
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedShares(address hub, address underlying) external view returns (uint256) {
    IHub targetHub = IHub(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    return _getSuppliedShares(targetHub, assetId);
  }

  /// @dev Common Supply workflow. When `skim` is true, it avoids pulling tokens from the caller and intends
  /// to skim or claim existing untracked liquidity on the `hub`.
  function _supply(
    address hub,
    address underlying,
    uint256 amount,
    bool skim
  ) internal returns (uint256, uint256) {
    IHubBase targetHub = IHubBase(hub);
    uint256 assetId = targetHub.getAssetId(underlying);

    if (!skim) {
      IERC20(underlying).safeTransferFrom(msg.sender, hub, amount);
    }
    uint256 shares = targetHub.add(assetId, amount);

    return (shares, amount);
  }

  /// @dev Includes the shares of accrued fees not yet minted, if this spoke is the fee receiver.
  function _getSuppliedShares(IHub hub, uint256 assetId) internal view returns (uint256) {
    uint256 shares = hub.getSpokeAddedShares(assetId, address(this));
    if (hub.getAssetConfig(assetId).feeReceiver == address(this)) {
      shares += hub.previewAddByAssets(assetId, hub.getAssetAccruedFees(assetId));
    }
    return shares;
  }

  /// @dev Loads the TreasurySpoke storage struct.
  function _getTreasurySpokeStorage() private pure returns (TreasurySpokeStorage storage $) {
    assembly ('memory-safe') {
      $.slot := NAMESPACE_SLOT
    }
  }
}
