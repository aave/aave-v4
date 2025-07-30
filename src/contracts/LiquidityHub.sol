// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/libraries/logic/AssetLogic.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract LiquidityHub is ILiquidityHub, AccessManaged {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for DataTypes.Asset;

  uint8 public constant MAX_ALLOWED_ASSET_DECIMALS = 18;

  uint256 internal _assetCount;
  mapping(uint256 assetId => DataTypes.Asset assetData) internal _assets;
  mapping(uint256 assetId => mapping(address spoke => DataTypes.SpokeData spokeData))
    internal _spokes;
  mapping(uint256 assetId => EnumerableSet.AddressSet spoke) internal _assetToSpokes;

  /**
   * @dev Constructor.
   * @dev The authority contract must implement the AccessManaged interface for access control.
   * @param authority_ The address of the authority contract which manages permissions.
   */
  constructor(address authority_) AccessManaged(authority_) {
    // Intentionally left blank
  }

  /// @inheritdoc ILiquidityHub
  function addAsset(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata data
  ) external restricted returns (uint256) {
    require(underlying != address(0), InvalidUnderlying());
    require(decimals <= MAX_ALLOWED_ASSET_DECIMALS, InvalidAssetDecimals());
    require(feeReceiver != address(0), InvalidFeeReceiver());
    require(irStrategy != address(0), InvalidIrStrategy());

    uint256 assetId = _assetCount++;
    IAssetInterestRateStrategy(irStrategy).setInterestRateData(assetId, data);
    uint256 baseBorrowRate = IAssetInterestRateStrategy(irStrategy).calculateInterestRate({
      assetId: assetId,
      availableLiquidity: 0,
      baseDebt: 0,
      premiumDebt: 0
    });

    uint256 baseDebtIndex = WadRayMath.RAY;
    uint256 lastUpdateTimestamp = block.timestamp;
    DataTypes.AssetConfig memory config = DataTypes.AssetConfig({
      feeReceiver: feeReceiver,
      liquidityFee: 0,
      irStrategy: irStrategy
    });
    _assets[assetId] = DataTypes.Asset({
      underlying: underlying,
      decimals: decimals,
      suppliedShares: 0,
      availableLiquidity: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      baseDebtIndex: baseDebtIndex,
      baseBorrowRate: baseBorrowRate,
      lastUpdateTimestamp: lastUpdateTimestamp,
      config: config
    });

    emit AssetAdded(assetId, underlying, decimals);
    emit AssetConfigUpdated(assetId, config);
    emit AssetUpdated(assetId, baseDebtIndex, baseBorrowRate, lastUpdateTimestamp);

    return assetId;
  }

  /// @inheritdoc ILiquidityHub
  function updateAssetConfig(
    uint256 assetId,
    DataTypes.AssetConfig calldata config
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    require(config.liquidityFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidityFee());
    require(config.feeReceiver != address(0), InvalidFeeReceiver());
    require(config.irStrategy != address(0), InvalidIrStrategy());

    DataTypes.Asset storage asset = _assets[assetId];
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    asset.config = config;
    asset.updateBorrowRate(assetId);

    emit AssetConfigUpdated(assetId, config);
  }

  function addSpoke(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    require(spoke != address(0), InvalidSpoke());
    require(!_assetToSpokes[assetId].contains(spoke), SpokeAlreadyListed());

    _assetToSpokes[assetId].add(spoke);
    _spokes[assetId][spoke].config = config;

    emit SpokeAdded(assetId, spoke);
    emit SpokeConfigUpdated(assetId, spoke, config);
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external restricted {
    require(_assetToSpokes[assetId].contains(spoke), SpokeNotListed());
    _spokes[assetId][spoke].config = config;
    emit SpokeConfigUpdated(assetId, spoke, config);
  }

  /// @inheritdoc ILiquidityHub
  function setInterestRateData(uint256 assetId, bytes calldata data) external restricted {
    DataTypes.Asset storage asset = _assets[assetId];
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    IAssetInterestRateStrategy(asset.config.irStrategy).setInterestRateData(assetId, data);
  }

  // /////
  // Spoke Actions
  // /////

  /// @inheritdoc ILiquidityHub
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateAdd(asset, spoke, amount, from);

    // todo: Mitigate inflation attack
    uint256 suppliedShares = previewAddByAssets(assetId, amount);
    require(suppliedShares != 0, InvalidSharesAmount());
    asset.suppliedShares += suppliedShares;
    spoke.suppliedShares += suppliedShares;
    asset.availableLiquidity += amount;

    asset.updateBorrowRate(assetId);

    // TODO: fee-on-transfer
    IERC20(asset.underlying).safeTransferFrom(from, address(this), amount);

    emit Add(assetId, msg.sender, suppliedShares, amount);

    return suppliedShares;
  }

  /// @inheritdoc ILiquidityHub
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateRemove(asset, spoke, amount, to);

    uint256 withdrawnShares = previewRemoveByAssets(assetId, amount); // non zero since we round up
    asset.suppliedShares -= withdrawnShares;
    spoke.suppliedShares -= withdrawnShares;
    asset.availableLiquidity -= amount;

    asset.updateBorrowRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Remove(assetId, msg.sender, withdrawnShares, amount);

    return withdrawnShares;
  }

  /// @inheritdoc ILiquidityHub
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateDraw(asset, spoke, amount, to);

    uint256 drawnShares = previewDrawByAssets(assetId, amount); // non zero since we round up
    asset.baseDrawnShares += drawnShares;
    spoke.baseDrawnShares += drawnShares;
    asset.availableLiquidity -= amount;

    asset.updateBorrowRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, drawnShares, amount);

    return drawnShares;
  }

  /// @inheritdoc ILiquidityHub
  function restore(
    uint256 assetId,
    uint256 baseAmount,
    uint256 premiumAmount,
    address from
  ) external returns (uint256) {
    // global & spoke premiumDebt (ghost, offset, realized) is *expected* to be updated on the `refreshPremiumDebt` callback

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    _validateRestore(asset, spoke, baseAmount, premiumAmount, from);

    uint256 baseDrawnSharesRestored = previewRestoreByAssets(assetId, baseAmount);
    asset.baseDrawnShares -= baseDrawnSharesRestored;
    spoke.baseDrawnShares -= baseDrawnSharesRestored;
    uint256 totalRestoredAmount = baseAmount + premiumAmount;
    asset.availableLiquidity += totalRestoredAmount;

    /// @dev premium debt must be restored in `refreshPremiumDebt` before calling this function
    asset.updateBorrowRate(assetId);

    IERC20(asset.underlying).safeTransferFrom(from, address(this), totalRestoredAmount);

    emit Restore(assetId, msg.sender, baseDrawnSharesRestored, totalRestoredAmount);

    return baseDrawnSharesRestored;
  }

  /// @inheritdoc ILiquidityHub
  function refreshPremiumDebt(
    uint256 assetId,
    int256 premiumDrawnShareDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) external {
    require(_spokes[assetId][msg.sender].config.active, SpokeNotActive());

    DataTypes.Asset storage asset = _assets[assetId];

    uint256 premiumDebtBefore = asset.premiumDebt();
    _refresh(
      assetId,
      msg.sender,
      premiumDrawnShareDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
    uint256 premiumDebtAfter = asset.premiumDebt();
    // can increase due to precision loss on premium debt (base unchanged)
    // todo mathematically find premium diff ceiling and replace the `2`
    // if no premium debt is restored, premium debt remains unchanged
    require(premiumDebtAfter + realizedPremiumTaken - premiumDebtBefore <= 2, InvalidDebtChange());
  }

  /// @inheritdoc ILiquidityHub
  function payFee(uint256 assetId, uint256 feeShares) external {
    DataTypes.SpokeData storage sender = _spokes[assetId][msg.sender];
    _validatePayFee(sender, feeShares);

    address feeReceiver = _assets[assetId].config.feeReceiver;
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage receiver = _spokes[assetId][feeReceiver];

    asset.accrue(assetId, receiver);

    uint256 suppliedShares = sender.suppliedShares;
    uint256 suppliedAssets = asset.toSuppliedAssetsDown(suppliedShares);
    uint256 feeAmount = asset.toSuppliedAssetsDown(feeShares);
    require(feeAmount <= suppliedAssets, SuppliedAmountExceeded(suppliedAssets));

    sender.suppliedShares = suppliedShares - feeShares;
    receiver.suppliedShares += feeShares;

    emit Remove(assetId, msg.sender, feeShares, feeAmount);
    emit Add(assetId, feeReceiver, feeShares, feeAmount);
  }

  function _refresh(
    uint256 assetId,
    address spokeAddress,
    int256 premiumDrawnShareDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) internal {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][spokeAddress];

    // accrue interest and liquidity fees
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    asset.premiumDrawnShares = _add(asset.premiumDrawnShares, premiumDrawnShareDelta);
    asset.premiumOffset = _add(asset.premiumOffset, premiumOffsetDelta);
    asset.realizedPremium = asset.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    spoke.premiumDrawnShares = _add(spoke.premiumDrawnShares, premiumDrawnShareDelta);
    spoke.premiumOffset = _add(spoke.premiumOffset, premiumOffsetDelta);
    spoke.realizedPremium = spoke.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    emit RefreshPremiumDebt(
      assetId,
      spokeAddress,
      premiumDrawnShareDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
  }

  /// @inheritdoc ILiquidityHub
  function getAssetCount() external view override returns (uint256) {
    return _assetCount;
  }

  /// @inheritdoc ILiquidityHub
  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory) {
    return _assets[assetId];
  }

  /// @inheritdoc ILiquidityHub
  function getSpokeCount(uint256 assetId) external view returns (uint256) {
    return _assetToSpokes[assetId].length();
  }

  /// @inheritdoc ILiquidityHub
  function getSpokeAddress(uint256 assetId, uint256 index) external view returns (address) {
    return _assetToSpokes[assetId].at(index);
  }

  /// @inheritdoc ILiquidityHub
  function isSpokeListed(uint256 assetId, address spoke) external view returns (bool) {
    return _assetToSpokes[assetId].contains(spoke);
  }

  function getSpoke(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeData memory) {
    return _spokes[assetId][spoke];
  }

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory) {
    return _spokes[assetId][spoke].config;
  }

  /// @inheritdoc ILiquidityHub
  function previewAddByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toSuppliedSharesDown(assets);
  }

  /// @inheritdoc ILiquidityHub
  function previewAddByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
    return _assets[assetId].toSuppliedAssetsUp(shares);
  }

  /// @inheritdoc ILiquidityHub
  function previewRemoveByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toSuppliedSharesUp(assets);
  }

  /// @inheritdoc ILiquidityHub
  function previewRemoveByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
    return _assets[assetId].toSuppliedAssetsDown(shares);
  }

  /// @inheritdoc ILiquidityHub
  function previewDrawByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toDrawnSharesUp(assets);
  }

  /// @inheritdoc ILiquidityHub
  function previewDrawByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
    return _assets[assetId].toDrawnAssetsDown(shares);
  }

  /// @inheritdoc ILiquidityHub
  function previewRestoreByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toDrawnSharesDown(assets);
  }

  /// @inheritdoc ILiquidityHub
  function previewRestoreByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
    return _assets[assetId].toDrawnAssetsUp(shares);
  }

  /// @inheritdoc ILiquidityHub
  function convertToSuppliedAssets(
    uint256 assetId,
    uint256 shares
  ) external view returns (uint256) {
    return _assets[assetId].toSuppliedAssetsDown(shares);
  }

  /// @inheritdoc ILiquidityHub
  function convertToSuppliedShares(
    uint256 assetId,
    uint256 assets
  ) external view returns (uint256) {
    return _assets[assetId].toSuppliedSharesDown(assets);
  }

  /// @inheritdoc ILiquidityHub
  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsUp(shares);
  }

  /// @inheritdoc ILiquidityHub
  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toDrawnSharesDown(assets);
  }

  /// @inheritdoc ILiquidityHub
  function getAssetDrawnIndex(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].getDrawnIndex();
  }

  function getBaseInterestRate(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].baseBorrowRate;
  }

  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return (asset.baseDebt(), asset.premiumDebt());
  }

  function getAssetTotalDebt(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].totalDebt();
  }

  function getSpokeDebt(uint256 assetId, address spoke) external view returns (uint256, uint256) {
    return _getSpokeDebt(_assets[assetId], _spokes[assetId][spoke]);
  }

  function getSpokeTotalDebt(uint256 assetId, address spoke) external view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getSpokeDebt(
      _assets[assetId],
      _spokes[assetId][spoke]
    );
    return baseDebt + premiumDebt;
  }

  function getAssetSuppliedAmount(uint256 assetId) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return asset.toSuppliedAssetsDown(asset.suppliedShares);
  }

  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].suppliedShares;
  }

  function getTotalSuppliedAssets(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalSuppliedAssets();
  }

  function getTotalSuppliedShares(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalSuppliedShares();
  }

  function getSpokeSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    if (spoke == asset.config.feeReceiver) {
      return
        asset.toSuppliedAssetsDown(
          _spokes[assetId][spoke].suppliedShares + asset.unrealizedFeeShares()
        );
    }
    return asset.toSuppliedAssetsDown(_spokes[assetId][spoke].suppliedShares);
  }

  function getSpokeSuppliedShares(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    if (spoke == asset.config.feeReceiver) {
      return _spokes[assetId][spoke].suppliedShares + asset.unrealizedFeeShares();
    }
    return _spokes[assetId][spoke].suppliedShares;
  }

  function getAvailableLiquidity(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].availableLiquidity;
  }

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory) {
    return _assets[assetId].config;
  }

  //
  // Internal
  //

  function _validateAdd(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address from
  ) internal view {
    require(from != address(this), InvalidFromAddress());
    require(amount > 0, InvalidAddAmount());
    require(spoke.config.active, SpokeNotActive());
    uint256 supplyCap = spoke.config.supplyCap;
    require(
      supplyCap == type(uint256).max ||
        supplyCap >= asset.toSuppliedAssetsUp(spoke.suppliedShares) + amount,
      SupplyCapExceeded(supplyCap)
    );
  }

  function _validateRemove(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidToAddress());
    require(amount > 0, InvalidRemoveAmount());
    require(spoke.config.active, SpokeNotActive());
    uint256 withdrawable = asset.toSuppliedAssetsDown(spoke.suppliedShares);
    require(amount <= withdrawable, SuppliedAmountExceeded(withdrawable));
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateDraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidToAddress());
    require(amount > 0, InvalidDrawAmount());
    require(spoke.config.active, SpokeNotActive());
    uint256 drawCap = spoke.config.drawCap;
    (uint256 drawn, uint256 premium) = _getSpokeDebt(asset, spoke);
    require(
      drawCap == type(uint256).max || drawCap >= drawn + premium + amount,
      DrawCapExceeded(drawCap)
    );
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateRestore(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 baseAmountRestored,
    uint256 premiumAmountRestored,
    address from
  ) internal view {
    require(from != address(this), InvalidFromAddress());
    require(baseAmountRestored + premiumAmountRestored > 0, InvalidRestoreAmount());
    require(spoke.config.active, SpokeNotActive());
    (uint256 baseDebt, ) = _getSpokeDebt(asset, spoke);
    require(baseAmountRestored <= baseDebt, SurplusAmountRestored(baseDebt));
    // we should have already restored premium debt
  }

  function _getSpokeDebt(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke
  ) internal view returns (uint256, uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(spoke.premiumDrawnShares) - spoke.premiumOffset;
    return (asset.toDrawnAssetsUp(spoke.baseDrawnShares), spoke.realizedPremium + accruedPremium);
  }

  // handles underflow
  function _add(uint256 a, int256 b) internal pure returns (uint256) {
    if (b >= 0) return a + uint256(b);
    return a - uint256(-b);
  }

  function _validatePayFee(
    DataTypes.SpokeData storage senderSpoke,
    uint256 feeShares
  ) internal view {
    require(senderSpoke.config.active, SpokeNotActive());
    require(feeShares != 0, InvalidFeeShares());
  }
}
