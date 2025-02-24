// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

interface IEventsMock {
  // Liquidity Hub Events
  event Supply(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event Withdraw(
    uint256 indexed assetId,
    address indexed spoke,
    address indexed to,
    uint256 amount
  );
  event Draw(uint256 indexed assetId, address indexed spoke, address indexed to, uint256 amount);
  event Restore(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event SpokeAdded(uint256 indexed assetId, address indexed spoke);

  // Spoke Events
  event Borrowed(uint256 indexed reserveId, uint256 amount, address indexed user);
  event Repaid(uint256 indexed reserveId, uint256 amount, address indexed user);
  event Supplied(uint256 indexed reserveId, uint256 amount, address indexed user);
  event Withdrawn(uint256 indexed reserveId, uint256 amount, address indexed user);
  event UsingAsCollateral(uint256 indexed reserveId, bool usingAsCollateral, address indexed user);
  event ReserveConfigUpdated(
    uint256 indexed reserveId,
    uint256 lt,
    uint256 lb,
    uint256 liquidityPremium,
    bool borrowable,
    bool collateral
  );
}

library LiquidityHubErrors {
  bytes constant MISMATCHED_CONFIGS = 'MISMATCHED_CONFIGS';
  bytes constant INVALID_SHARES_AMOUNT = 'INVALID_SHARES_AMOUNT';
  bytes constant INVALID_SUPPLY_AMOUNT = 'INVALID_SUPPLY_AMOUNT';
  bytes constant ASSET_NOT_LISTED = 'ASSET_NOT_LISTED';
  bytes constant ASSET_NOT_ACTIVE = 'ASSET_NOT_ACTIVE';
  bytes constant SUPPLY_CAP_EXCEEDED = 'SUPPLY_CAP_EXCEEDED';
  bytes constant INVALID_WITHDRAW_AMOUNT = 'INVALID_WITHDRAW_AMOUNT';
  bytes constant SUPPLIED_AMOUNT_EXCEEDED = 'SUPPLIED_AMOUNT_EXCEEDED';
  bytes constant NOT_AVAILABLE_LIQUIDITY = 'NOT_AVAILABLE_LIQUIDITY';
  bytes constant INVALID_DRAW_AMOUNT = 'INVALID_DRAW_AMOUNT';
  bytes constant DRAW_CAP_EXCEEDED = 'DRAW_CAP_EXCEEDED';
  bytes constant INVALID_RESTORE_AMOUNT = 'INVALID_RESTORE_AMOUNT';
  bytes constant INVALID_SPOKE = 'INVALID_SPOKE';
  bytes constant INVALID_BPS = 'INVALID_BPS';
}

library SpokeErrors {
  bytes constant INVALID_RESERVE = 'INVALID_RESERVE';
  bytes constant RESERVE_NOT_LISTED = 'RESERVE_NOT_LISTED';
  bytes constant INSUFFICIENT_SUPPLY = 'INSUFFICIENT_SUPPLY';
  bytes constant RESERVE_NOT_BORROWABLE = 'RESERVE_NOT_BORROWABLE';
  bytes constant REPAY_EXCEEDS_DEBT = 'REPAY_EXCEEDS_DEBT';
  bytes constant RESERVE_NOT_COLLATERAL = 'RESERVE_NOT_COLLATERAL';
}
