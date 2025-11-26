// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ERC4626, ERC20, IERC20Metadata, IERC4626, Math} from 'src/dependencies/openzeppelin/ERC4626.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IVaultSpoke} from 'src/spoke/interfaces/IVaultSpoke.sol';
import {SafeTransferLib} from 'src/dependencies/solady/SafeTransferLib.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

/// @title VaultSpoke
/// @author Aave Labs
/// @notice ERC4626 compliant vault for hub's listed asset position management.
/// @dev Connects to one listed asset, only responsible for tokenizing positions, share price is maintained by the Hub.
contract VaultSpoke is IVaultSpoke, ERC4626 {
  using SafeTransferLib for address;

  IHub public immutable HUB;
  uint256 public immutable ASSET_ID;

  constructor(
    address hub_,
    uint256 assetId_,
    address underlying_
  )
    ERC4626(IERC20Metadata(underlying_))
    ERC20(
      string.concat('Vault Spoke (', IERC20Metadata(underlying_).name(), ')'),
      string.concat('v', IERC20Metadata(underlying_).symbol())
    )
  {
    HUB = IHub(hub_);
    ASSET_ID = assetId_;
    require(HUB.getAsset(ASSET_ID).underlying == underlying_, InvalidAddress()); // hub zero addr check covered
  }

  function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external returns (uint256) {
    try
      IERC20Permit(asset()).permit({
        owner: msg.sender, // deposit only mints for caller
        spender: address(this),
        value: assets,
        deadline: deadline,
        v: permitV,
        r: permitR,
        s: permitS
      })
    {} catch {}
    return deposit(assets, receiver);
  }

  function totalAssets() public view override returns (uint256) {
    // does not revert since `ASSET_ID` existence is checked on construction
    return HUB.previewRemoveByShares(ASSET_ID, totalSupply());
  }

  function maxDeposit(address) public view override returns (uint256) {
    IHub.SpokeConfig memory config = HUB.getSpokeConfig(ASSET_ID, address(this));
    if (config.active == false) {
      return 0;
    }
    uint256 allowed = config.addCap * MathUtils.uncheckedExp(10, decimals());
    uint256 balance = totalAssets();
    return Math.ternary(allowed > balance, allowed - balance, 0);
  }

  function maxMint(address owner) public view override returns (uint256) {
    return _convertToShares(maxDeposit(owner), Math.Rounding.Floor);
  }

  function maxWithdraw(address owner) public view override returns (uint256) {
    return _convertToAssets(maxRedeem(owner), Math.Rounding.Floor);
  }

  function maxRedeem(address owner) public view override returns (uint256) {
    IHub.SpokeConfig memory config = HUB.getSpokeConfig(ASSET_ID, address(this));
    if (config.active == false) {
      return 0;
    }
    return balanceOf(owner);
  }

  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal override {
    asset().safeTransferFrom(caller, address(HUB), assets);
    HUB.add(ASSET_ID, assets);
    _mint(receiver, shares);
    emit Deposit(caller, receiver, assets, shares);
  }

  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal override {
    if (caller != owner) {
      _spendAllowance(owner, caller, shares);
    }
    HUB.remove(ASSET_ID, assets, receiver);
    _burn(owner, shares);
    emit Withdraw(caller, receiver, owner, assets, shares);
  }

  // @dev Share price is maintained on the Hub.
  function _convertToShares(
    uint256 assets,
    Math.Rounding rounding
  ) internal view override returns (uint256) {
    if (rounding == Math.Rounding.Ceil) {
      return HUB.previewRemoveByAssets(ASSET_ID, assets);
    }
    return HUB.previewAddByAssets(ASSET_ID, assets);
  }

  // @dev Share price is maintained on the Hub.
  function _convertToAssets(
    uint256 shares,
    Math.Rounding rounding
  ) internal view override returns (uint256) {
    if (rounding == Math.Rounding.Ceil) {
      return HUB.previewAddByShares(ASSET_ID, shares);
    }
    return HUB.previewRemoveByShares(ASSET_ID, shares);
  }
}
