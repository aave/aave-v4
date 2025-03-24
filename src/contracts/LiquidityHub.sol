// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/contracts/AssetLogic.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for DataTypes.Asset;

  uint256 public constant MAX_ALLOWED_ASSET_DECIMALS = 18;
  uint256 public constant DEFAULT_ASSET_INDEX = WadRayMath.RAY;
  uint256 public constant DEFAULT_SPOKE_INDEX = 0;

  mapping(uint256 assetId => DataTypes.Asset assetData) internal _assets;
  mapping(uint256 assetId => mapping(address spokeAddress => DataTypes.SpokeData spokeData))
    internal _spokes;

  IERC20[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  // /////
  // Governance
  // /////

  function addAsset(DataTypes.AssetConfig calldata config, address asset) external {
    // TODO: AccessControl
    _validateAssetConfig(config, asset);
    assetsList.push(IERC20(asset));
    _assets[assetCount] = DataTypes.Asset({
      id: assetCount,
      suppliedShares: 0,
      availableLiquidity: 0,
      drawnShares: 0,
      premiumVirtualShares: 0,
      premiumVirtualOffset: 0,
      drawnAssets: 0,
      totalPremium: 0,
      baseBorrowRate: 0,
      lastUpdateTimestamp: block.timestamp,
      config: DataTypes.AssetConfig({
        decimals: config.decimals,
        active: config.active,
        frozen: config.frozen,
        paused: config.paused,
        irStrategy: config.irStrategy
      })
    });

    emit AssetAdded(assetCount++, asset);
  }

  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig calldata config) external {
    _validateAssetConfig(config, address(assetsList[assetId]));
    DataTypes.Asset storage asset = _assets[assetId];
    // TODO: AccessControl
    asset.config = DataTypes.AssetConfig({
      decimals: config.decimals,
      active: config.active,
      frozen: config.frozen,
      paused: config.paused,
      irStrategy: config.irStrategy
    });

    emit AssetConfigUpdated(assetId, config.decimals, config.active, config.irStrategy);
  }

  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory config, address spoke) external {
    // TODO: AccessControl
    _addSpoke(assetId, config, spoke);
  }

  function addSpokes(
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] memory configs,
    address spoke
  ) external {
    // TODO: AccessControl

    require(assetIds.length == configs.length, MismatchedConfigs());
    for (uint256 i; i < assetIds.length; i++) {
      _addSpoke(assetIds[i], configs[i], spoke);
    }
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory config
  ) external {
    // TODO: AccessControl
    _spokes[assetId][spoke].config = DataTypes.SpokeConfig({
      drawCap: config.drawCap,
      supplyCap: config.supplyCap
    });

    emit SpokeConfigUpdated(assetId, spoke, config.drawCap, config.supplyCap);
  }

  // /////
  // Users
  // /////

  /// @inheritdoc ILiquidityHub
  function supply(uint256 assetId, uint256 amount, address supplier) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrueInterest();
    _validateSupply(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});
    // todo: Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = asset.convertToSharesDown(amount);
    require(sharesAmount > 0, InvalidSharesAmount());

    asset.availableLiquidity += amount;
    asset.suppliedShares += sharesAmount;
    spoke.suppliedShares += sharesAmount;

    // TODO: fee-on-transfer
    assetsList[assetId].safeTransferFrom(supplier, address(this), amount);

    emit Supply(assetId, msg.sender, amount);

    return sharesAmount;
  }

  /// @inheritdoc ILiquidityHub
  function withdraw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrueInterest();
    _validateWithdraw(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});
    uint256 sharesAmount = asset.convertToSharesUp(amount);
    require(sharesAmount > 0, InvalidSharesAmount());

    asset.suppliedShares -= sharesAmount;
    asset.availableLiquidity -= amount;
    spoke.suppliedShares -= sharesAmount;

    assetsList[assetId].safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);

    return sharesAmount;
  }

  /// @inheritdoc ILiquidityHub
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrueInterest();
    _validateDraw(asset, amount, spoke.config.drawCap);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});
    uint256 sharesAmount = asset.convertToDrawnSharesUp(amount);
    require(sharesAmount > 0, InvalidSharesAmount());

    asset.drawnAssets += amount;
    asset.availableLiquidity -= amount;

    asset.drawnShares += sharesAmount;
    spoke.drawnShares += sharesAmount;

    assetsList[assetId].safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, to, amount);

    return amount;
  }

  /// @inheritdoc ILiquidityHub
  function restore(
    uint256 assetId,
    uint256 amount,
    uint256 premiumAmount,
    address repayer
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrueInterest();
    _validateRestore(asset, spoke, amount, premiumAmount);

    asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});
    uint256 sharesAmount = asset.convertToDrawnSharesDown(amount);
    require(sharesAmount > 0, InvalidSharesAmount());

    asset.drawnAssets -= amount;
    asset.availableLiquidity += amount;
    // premium amount change is applied in refresh
    // asset.totalPremium -= premiumAmount;

    asset.drawnShares -= sharesAmount;
    spoke.drawnShares -= sharesAmount;

    assetsList[assetId].safeTransferFrom(repayer, address(this), amount);

    emit Restore(assetId, msg.sender, amount);

    return amount;
  }

  /// @inheritdoc ILiquidityHub
  function accrueInterest(uint256 assetId) external {
    // TODO: authorization - only spokes
    _assets[assetId].accrueInterest();
  }

  /// @inheritdoc ILiquidityHub
  function refresh(
    uint256 assetId,
    int256 newPremiumDrawnSharesDelta,
    int256 newPremiumOffsetDelta,
    int256 newTotalPremiumDelta
  ) external returns (uint256) {
    // TODO: authorization - only spokes
    if (newPremiumDrawnSharesDelta > 0) {
      _assets[assetId].premiumVirtualShares += uint256(newPremiumDrawnSharesDelta);
      _spokes[assetId][msg.sender].premiumVirtualShares += uint256(newPremiumDrawnSharesDelta);
    } else {
      _assets[assetId].premiumVirtualShares -= uint256(newPremiumDrawnSharesDelta);
      _spokes[assetId][msg.sender].premiumVirtualShares -= uint256(newPremiumDrawnSharesDelta);
    }

    if (newPremiumOffsetDelta > 0) {
      _assets[assetId].premiumVirtualOffset += uint256(newPremiumOffsetDelta);
      _spokes[assetId][msg.sender].premiumVirtualOffset += uint256(newPremiumOffsetDelta);
    } else {
      _assets[assetId].premiumVirtualOffset -= uint256(newPremiumOffsetDelta);
      _spokes[assetId][msg.sender].premiumVirtualOffset -= uint256(newPremiumOffsetDelta);
    }

    if (newTotalPremiumDelta > 0) {
      _assets[assetId].totalPremium += uint256(newTotalPremiumDelta);
      _spokes[assetId][msg.sender].totalPremium += uint256(newTotalPremiumDelta);
    } else {
      _assets[assetId].totalPremium -= uint256(newTotalPremiumDelta);
      _spokes[assetId][msg.sender].totalPremium -= uint256(newTotalPremiumDelta);
    }
  }

  //
  // public
  //

  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory) {
    return _assets[assetId];
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

  function getTotalAssets(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].getTotalAssets();
  }

  function convertToAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(shares);
  }

  function convertToShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToSharesDown(assets);
  }

  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToDrawnAssetsUp(shares);
  }

  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToDrawnSharesDown(assets);
  }

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].baseBorrowRate;
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].getInterestRate();
  }

  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256) {
    // TODO opt: interest accrue twice
    return (_assets[assetId].getTotalDrawnAssets(), _assets[assetId].getTotalPremium());
  }

  function getAssetCumulativeDebt(uint256 assetId) external view returns (uint256) {
    // TODO opt: interest accrue twice
    return _assets[assetId].getTotalDrawnAssets() + _assets[assetId].getTotalPremium();
  }

  function getSpokeDebt(uint256 assetId, address spoke) external view returns (uint256, uint256) {
    DataTypes.Asset storage assetData = _assets[assetId];
    DataTypes.SpokeData storage spokeData = _spokes[assetId][spoke];
    return (
      _assets[assetId].convertToDrawnAssetsUp(spokeData.drawnShares),
      _getSpokeTotalPremium(assetData, spokeData)
    );
  }

  function getSpokeCumulativeDebt(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.SpokeData storage spokeData = _spokes[assetId][spoke];
    return
      _assets[assetId].convertToDrawnAssetsUp(spokeData.drawnShares) +
      _getSpokeTotalPremium(_assets[assetId], spokeData);
  }

  function getAssetSuppliedAmount(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(_assets[assetId].suppliedShares);
  }

  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].suppliedShares;
  }

  function getSpokeSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(_spokes[assetId][spoke].suppliedShares);
  }

  function getSpokeSuppliedShares(uint256 assetId, address spoke) external view returns (uint256) {
    return _spokes[assetId][spoke].suppliedShares;
  }

  function getAvailableLiquidity(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].availableLiquidity;
  }

  /// @inheritdoc ILiquidityHub
  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory) {
    return _assets[assetId].config;
  }

  //
  // Internal
  //

  function _validateSupply(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal view {
    require(amount > 0, InvalidSupplyAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    require(!asset.config.frozen, AssetFrozen());
    require(assetsList[asset.id] != IERC20(address(0)), AssetNotListed());
    require(
      spoke.config.supplyCap == type(uint256).max ||
        asset.convertToAssetsDown(spoke.suppliedShares) + amount <= spoke.config.supplyCap,
      SupplyCapExceeded(spoke.config.supplyCap)
    );
  }

  function _validateWithdraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal view {
    require(amount > 0, InvalidWithdrawAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    uint256 withdrawable = asset.convertToAssetsDown(spoke.suppliedShares);
    require(amount <= withdrawable, SuppliedAmountExceeded(withdrawable));
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateDraw(
    DataTypes.Asset storage asset,
    uint256 amount,
    uint256 drawCap
  ) internal view {
    require(amount > 0, InvalidDrawAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    require(!asset.config.frozen, AssetFrozen());
    require(
      drawCap == type(uint256).max || amount + asset.drawnAssets <= drawCap,
      DrawCapExceeded(drawCap)
    );
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateRestore(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amountRestored,
    uint256 premiumRestored
  ) internal view {
    require(amountRestored > 0, InvalidRestoreAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    // Ensure spoke is not restoring more than accrued drawn
    uint256 maxAllowedRestore = asset.convertToDrawnAssetsDown(spoke.drawnShares);
    require(
      amountRestored <= maxAllowedRestore,
      SurplusAmountRestored(maxAllowedRestore) // TODO: rename
    );
    require(premiumRestored <= spoke.totalPremium, SurplusAmountRestored(maxAllowedRestore)); // TODO: new error
  }

  function _accrueInterest(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke
  ) internal {
    asset.accrueInterest();
  }

  function _getSpokeTotalPremium(
    DataTypes.Asset storage assetData,
    DataTypes.SpokeData storage spokeData
  ) internal returns (uint256) {
    return
      spokeData.totalPremium +
      assetData.convertToDrawnAssetsUp(spokeData.premiumVirtualShares) -
      spokeData.premiumVirtualOffset;
  }

  function _addSpoke(uint256 assetId, DataTypes.SpokeConfig memory config, address spoke) internal {
    require(spoke != address(0), InvalidSpoke());
    _spokes[assetId][spoke] = DataTypes.SpokeData({
      suppliedShares: 0,
      drawnShares: 0,
      premiumVirtualShares: 0,
      premiumVirtualOffset: 0,
      totalPremium: 0,
      lastUpdateTimestamp: 0,
      config: config
    });

    emit SpokeAdded(assetId, spoke);
  }

  function _validateAssetConfig(
    DataTypes.AssetConfig calldata config,
    address asset
  ) internal pure {
    require(asset != address(0), InvalidAssetAddress());
    require(config.irStrategy != address(0), InvalidIrStrategy());
    require(config.decimals <= MAX_ALLOWED_ASSET_DECIMALS, InvalidAssetDecimals());
  }
}
