// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {IPriceOracle} from './IPriceOracle.sol';
import {WadRayMath} from './WadRayMath.sol';
import {SharesMath} from './SharesMath.sol';
import {MathUtils} from './MathUtils.sol';
import {IBorrowModule} from './IBorrowModule.sol';
import {DataTypes} from './types/DataTypes.sol';
import {SupplyReserveConfiguration} from './SupplyReserveConfiguration.sol';
import {BorrowReserveConfiguration} from './BorrowReserveConfiguration.sol';

import 'forge-std/console2.sol';

contract LiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using SupplyReserveConfiguration for DataTypes.SupplyReserveConfig;
  using BorrowReserveConfiguration for DataTypes.BorrowReserveConfig;

  event Supply(
    uint256 indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );
  event Withdraw(uint256 indexed reserve, address indexed user, address indexed to, uint256 amount);

  event Draw(uint256 indexed reserve, address indexed borrowModule, uint256 amount);

  struct Reserve {
    uint256 id;
    uint256 totalShares;
    uint256 totalAssets;
    uint256 totalDrawn;
    uint256 lastUpdateTimestamp;
    address borrowModule;
    address supplyModule;
    DataTypes.SupplyReserveConfig supplyConfig;
    DataTypes.BorrowReserveConfig borrowConfig;
  }

  struct UserConfig {
    uint256 shares;
  }

  // asset id => reserve data
  mapping(uint256 => Reserve) public reserves;
  address[] public reservesList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public reserveCount;

  // asset id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;

  // asset id => user address => user's supply reserve config
  mapping(uint256 => mapping(address => DataTypes.SupplyReserveConfig))
    public userSupplyReserveConfigs;

  // asset id => user address => user's borrow reserve config
  mapping(uint256 => mapping(address => DataTypes.BorrowReserveConfig))
    public userBorrowReserveConfigs;
  mapping(address => uint256) userRiskPremium; // in base currency terms

  address public oracle;

  constructor(address oracleAddress) {
    oracle = oracleAddress;
  }

  function getReserve(uint256 assetId) external view returns (Reserve memory) {
    return reserves[assetId];
  }

  function getUser(uint256 assetId, address user) external view returns (UserConfig memory) {
    UserConfig memory u = users[assetId][user];

    return u;
  }

  function getUserSupplyReserveConfig(
    uint256 assetId,
    address user
  ) external view returns (DataTypes.SupplyReserveConfig memory) {
    DataTypes.SupplyReserveConfig memory c = userSupplyReserveConfigs[assetId][user];

    return c;
  }

  function getUserBorrowReserveConfig(
    uint256 assetId,
    address user
  ) external view returns (DataTypes.BorrowReserveConfig memory) {
    DataTypes.BorrowReserveConfig memory c = userBorrowReserveConfigs[assetId][user];

    return c;
  }

  function getUserBalance(uint256 assetId, address user) external view returns (uint256) {
    return _getUserAssets(assetId, user);
  }

  function getUserRiskPremium(address user) external view returns (uint256) {
    return userRiskPremium[user];
  }

  function _getUserAssets(uint256 assetId, address user) internal view returns (uint256) {
    UserConfig memory u = users[assetId][user];

    return u.shares.toAssetsDown(reserves[assetId].totalAssets, reserves[assetId].totalShares);
  }

  // /////
  // Governance
  // /////

  function addReserve(
    DataTypes.SupplyReserveConfigurationParams memory supplyParams,
    DataTypes.BorrowReserveConfigurationParams memory borrowParams,
    address asset
  ) external {
    // TODO: AccessControl
    DataTypes.SupplyReserveConfig memory supplyConfig = DataTypes.SupplyReserveConfig({data: 0});
    supplyConfig.setConfigFromParams(supplyParams);
    DataTypes.BorrowReserveConfig memory borrowConfig = DataTypes.BorrowReserveConfig({data: 0});
    borrowConfig.setConfigFromParams(borrowParams);

    reservesList.push(asset);
    reserves[reserveCount] = Reserve({
      id: reserveCount,
      totalShares: 0,
      totalAssets: 0,
      totalDrawn: 0,
      lastUpdateTimestamp: block.timestamp,
      borrowModule: supplyParams.borrowModule,
      supplyModule: supplyParams.supplyModule,
      supplyConfig: supplyConfig,
      borrowConfig: borrowConfig
    });
    reserveCount++;
  }

  function updateSupplyReserveParams(
    uint256 assetId,
    DataTypes.SupplyReserveConfigurationParams memory params
  ) external {
    // TODO: More sophisticated
    // TODO: AccessControl
    DataTypes.SupplyReserveConfig memory config = DataTypes.SupplyReserveConfig({data: 0});
    config.setConfigFromParams(params);
    reserves[assetId].supplyConfig = config;
  }

  function updateSupplyReserve(
    uint256 assetId,
    DataTypes.SupplyReserveConfig calldata config
  ) external {
    // TODO: AccessControl
    reserves[assetId].supplyConfig = config;
  }

  function updateBorrowReserveParams(
    uint256 assetId,
    DataTypes.BorrowReserveConfigurationParams memory params
  ) external {
    // TODO: AccessControl
    DataTypes.BorrowReserveConfig memory config = DataTypes.BorrowReserveConfig({data: 0});
    config.setConfigFromParams(params);
    reserves[assetId].borrowConfig = config;
  }

  function updateBorrowReserve(
    uint256 assetId,
    DataTypes.BorrowReserveConfig calldata config
  ) external {
    // TODO: AccessControl
    reserves[assetId].borrowConfig = config;
  }

  // /////
  // Users
  // /////

  function supply(
    uint256 assetId,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external {
    console2.log('- supply', msg.sender);
    console2.log('  params:', assetId, amount, onBehalfOf);
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][onBehalfOf];

    _validateSupply(reserve, amount);

    // update indexes and IRs
    _updateState(reserve); // TODO

    // Update user supply reserve config
    _updateUserSupplyReserveConfig(onBehalfOf, assetId);

    // TODO: init user lastUpdateIndex
    // TODO Set as collateral if first supply?

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onSupply( assetData, amount);
    // TODO Mitigate inflation attack (burn some amount if first supply)

    uint256 sharesAmount = amount.toSharesDown(reserve.totalAssets, reserve.totalShares);
    require(sharesAmount > 0, 'INVALID_AMOUNT');
    user.shares += sharesAmount;
    reserve.totalShares += sharesAmount;
    reserve.totalAssets += amount;

    // TODO: update avgRiskPremium if collateral
    _updateRiskPremium(onBehalfOf);

    // transferFrom
    IERC20(reservesList[assetId]).safeTransferFrom(msg.sender, address(this), amount); // TODO: fee-on-transfer

    emit Supply(assetId, msg.sender, onBehalfOf, amount, referralCode);
  }

  function withdraw(uint256 assetId, uint256 amount, address to) external {
    // TODO: onBehalf
    // TODO: onBehalf
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][msg.sender];

    // asset can be withdrawn
    _validateWithdraw(reserve, amount);

    // TODO HF check

    // update indexes and IRs
    _updateState(reserve);

    // Update user supply reserve config
    _updateUserSupplyReserveConfig(msg.sender, assetId);

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onWithdraw( assetData, amount);

    uint256 sharesAmount = amount.toSharesUp(reserve.totalAssets, reserve.totalShares);
    user.shares -= sharesAmount;
    reserve.totalShares -= sharesAmount;
    reserve.totalAssets -= amount;

    // TODO: update avgRiskPremium if collateral
    _updateRiskPremium(msg.sender);

    // transfer
    IERC20(reservesList[assetId]).safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);
  }

  function refreshUserRiskPremium(address user) external {
    _updateRiskPremium(user);
  }

  // TODO borrow name
  function borrow(uint256 assetId, uint256 amount) external {
    // TODO: onBehalf
    // TODO: onBehalf
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][msg.sender];

    _validateBorrow(reserve, amount);

    // update indexes and IRs
    _updateState(reserve);

    // Update user borrow reserve config
    _updateUserBorrowReserveConfig(msg.sender, assetId);

    // TODO: update avgRiskPremium if collateral
    // if collateral
    _updateRiskPremium(msg.sender);

    // updates accounting
    reserve.totalDrawn += amount;

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO
    // Allow transfer of funds for borrow module
    IERC20(reservesList[assetId]).forceApprove(reserve.borrowModule, amount);
    // TODO: transfer instead? the module can take less than approved
    IBorrowModule(reserve.borrowModule).onBorrow(
      assetId,
      msg.sender,
      userRiskPremium[msg.sender],
      amount
    );
    // reset allowance
    IERC20(reservesList[assetId]).forceApprove(reserve.borrowModule, 0);

    emit Draw(assetId, reserve.borrowModule, amount);
  }

  function repay(uint256 assetId, uint256 amount, address onBehalfOf) external {
    _updateUserBorrowReserveConfig(onBehalfOf, assetId);
  }

  //
  // Internal
  //
  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    // asset is listed
    require(reservesList[reserve.id] != address(0), 'ASSET_NOT_LISTED');
    // asset can be supplied
    require(reserve.supplyConfig.getActive(), 'RESERVE_NOT_ACTIVE');
    // supply cap not reached
    require(
      reserve.supplyConfig.getSupplyCap() == 0 ||
        reserve.supplyConfig.getSupplyCap() > reserve.totalAssets + amount,
      'CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(Reserve storage reserve, uint256 amount) internal view {
    // asset can be withdrawn
    require(reserve.supplyConfig.getActive(), 'RESERVE_NOT_ACTIVE');
    // reserve with available liquidity
    require(reserve.totalAssets >= amount, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    // asset can be borrowed
    require(reserve.borrowConfig.getActive(), 'RESERVE_NOT_ACTIVE');
    // TODO valid borrowModule
    // Check enough liquidity (liquidity > amount)
    require(reserve.totalAssets - reserve.totalDrawn >= amount, 'INVALID_AMOUNT');
    require(reserve.borrowConfig.getBorrowingEnabled(), 'RESERVE_NOT_BORROWABLE');
    // draw cap not reached
    require(
      reserve.borrowConfig.getDrawCap() == 0 ||
        reserve.borrowConfig.getDrawCap() > reserve.totalDrawn + amount,
      'CAP_EXCEEDED'
    );
  }

  function _updateState(Reserve storage reserve) internal {
    // Update interest rates
    uint256 borrowRate = IBorrowModule(reserve.borrowModule).calculateInterestRates(); // TODO: coupling here, must be more abstract?
    // TODO: only borrowRate? supplyRate can be calculated using borrowRate and RF
    // borrow module and liquidity hub coupling

    // Update indexes
    _accrueReserveInterest(reserve, borrowRate); // TODO rate accruing is actually less than borrowRate
    // TODO borrowIndex
    // _accrueReserveInterest(reserve.borrowIndex, reserve.borrowRate, elapsed);
    // Accrue RF?
  }

  function _accrueReserveInterest(Reserve storage r, uint256 borrowRate) internal {
    uint256 elapsed = block.timestamp - r.lastUpdateTimestamp;
    if (elapsed > 0) {
      console2.log('_accrueReserveInterest');
      // linear interest
      uint256 cumulated = MathUtils
        .calculateLinearInterest(borrowRate, uint40(r.lastUpdateTimestamp))
        .rayMul(r.totalAssets); // TODO rounding
      console2.log('cumulated %e', cumulated);
      r.totalAssets += cumulated;

      // TODO: fee shares

      r.lastUpdateTimestamp = block.timestamp;
    }
  }

  function _updateUserSupplyReserveConfig(address user, uint256 reserve) internal {
    userSupplyReserveConfigs[reserve][user] = reserves[reserve].supplyConfig;
  }

  function _updateUserBorrowReserveConfig(address user, uint256 reserve) internal {
    userBorrowReserveConfigs[reserve][user] = reserves[reserve].borrowConfig;
  }

  function _updateRiskPremium(address user) internal {
    uint256 wAvg;
    uint256 sumW;

    uint256 wData; // data weight * data value
    // data weight = price * amount
    // data value = liquidityPremium
    for (uint256 assetId = 0; assetId < reservesList.length; assetId++) {
      // TODO: if collateral enabled
      wData = _getUserAssets(assetId, user) * IPriceOracle(oracle).getAssetPrice(assetId);
      sumW += wData;

      wData = wData * reserves[assetId].supplyConfig.getLiquidityPremium(); // bps
      wAvg += wData;
    }
    if (sumW != 0) wAvg /= sumW;

    userRiskPremium[user] = wAvg;
  }
}
