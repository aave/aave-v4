// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {IRevenueSplitter} from 'src/treasury/interfaces/IRevenueSplitter.sol';

/// @title RevenueSplitter
/// @author Aave Labs
/// @notice Withdraws revenue from a TreasurySpoke and distributes it to a fixed set of recipients.
/// @dev Must be set as the claimer of the TreasurySpoke. Recipients and splits cannot be changed after deployment.
contract RevenueSplitter is IRevenueSplitter, ReentrancyGuardTransient {
  using SafeERC20 for IERC20;
  using PercentageMath for uint256;

  /// @inheritdoc IRevenueSplitter
  address public immutable TREASURY_SPOKE;

  address[] internal _recipients;
  uint256[] internal _splits;

  /// @dev Constructor.
  /// @param treasurySpoke_ The address of the TreasurySpoke.
  /// @param recipients_ The addresses of the recipients.
  /// @param splits_ The splits of the recipients, expressed in BPS and summing to `PERCENTAGE_FACTOR`.
  constructor(address treasurySpoke_, address[] memory recipients_, uint256[] memory splits_) {
    require(treasurySpoke_ != address(0), InvalidAddress());
    require(recipients_.length == splits_.length, MismatchedLengths());
    require(recipients_.length > 1, InvalidRecipientsCount());

    uint256 totalSplit;
    for (uint256 i; i < recipients_.length; ++i) {
      require(recipients_[i] != address(0), InvalidAddress());
      for (uint256 j; j < i; ++j) {
        require(recipients_[i] != recipients_[j], DuplicateRecipient());
      }
      require(splits_[i] > 0 && splits_[i] < PercentageMath.PERCENTAGE_FACTOR, InvalidSplit());
      totalSplit += splits_[i];
    }
    require(totalSplit == PercentageMath.PERCENTAGE_FACTOR, InvalidSplit());

    TREASURY_SPOKE = treasurySpoke_;
    _recipients = recipients_;
    _splits = splits_;
  }

  /// @inheritdoc IRevenueSplitter
  function splitRevenue(
    address[] calldata hubs,
    address[] calldata underlyings
  ) external nonReentrant {
    require(hubs.length == underlyings.length, MismatchedLengths());
    for (uint256 i; i < hubs.length; ++i) {
      _withdraw(hubs[i], underlyings[i]);
      _distribute(hubs[i], underlyings[i]);
    }
  }

  /// @inheritdoc IRevenueSplitter
  function getRecipients() external view returns (address[] memory, uint256[] memory) {
    return (_recipients, _splits);
  }

  /// @dev Clamped to the Hub liquidity so that high utilization does not block distribution.
  function _withdraw(address hub, address underlying) internal {
    IHubBase targetHub = IHubBase(hub);
    uint256 assetId = targetHub.getAssetId(underlying);
    uint256 amount = MathUtils.min(
      targetHub.getSpokeAddedAssets(assetId, TREASURY_SPOKE),
      targetHub.getAssetLiquidity(assetId)
    );
    if (amount > 0) {
      ITreasurySpoke(TREASURY_SPOKE).withdraw(hub, underlying, amount);
    }
  }

  function _distribute(address hub, address underlying) internal {
    uint256 balance = IERC20(underlying).balanceOf(address(this));
    if (balance == 0) {
      return;
    }

    uint256 lastIndex = _recipients.length - 1;
    uint256 remaining = balance;
    for (uint256 i; i < lastIndex; ++i) {
      uint256 amount = balance.percentMulDown(_splits[i]);
      remaining -= amount;
      _transfer(underlying, _recipients[i], amount);
    }
    _transfer(underlying, _recipients[lastIndex], remaining);

    emit SplitRevenue(hub, underlying, balance);
  }

  /// @dev Skips zero amounts, as some tokens revert on zero-value transfers.
  function _transfer(address token, address to, uint256 amount) internal {
    if (amount > 0) {
      IERC20(token).safeTransfer(to, amount);
    }
  }
}
