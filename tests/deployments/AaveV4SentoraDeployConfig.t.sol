// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PostDeploymentVerificationBase} from 'tests/deployments/fork/PostDeploymentVerificationBase.t.sol';
import {AaveV4DeploySentora} from 'scripts/deploy/AaveV4DeploySentora.s.sol';
import {AaveV4SentoraConfigEngine} from 'scripts/config/AaveV4SentoraConfigEngine.sol';
import {AaveV4SentoraConfigInputs} from 'scripts/config/AaveV4SentoraConfigInputs.sol';
import {AaveV4SentoraParameters} from 'scripts/config/AaveV4SentoraParameters.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4SentoraDeployConfigTest
/// @author Aave Labs
/// @notice Checks that config/sentora.json and config/sentora-config.json parse into the inputs the
///         ARFC sets out, and that a full deployment driven by those inputs sets every ownership as
///         configured.
contract AaveV4SentoraDeployConfigTest is PostDeploymentVerificationBase, AaveV4DeploySentora {
  address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  uint256 internal constant ETHEREUM_CHAIN_ID = 1;
  /// @dev The V4 Security Council Safe on Ethereum, which admins the AccessManager and owns the
  ///      ProxyAdmins.
  address internal constant SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;
  /// @dev Sentora's Emergency Operator, which holds the emergency role alongside the Security
  ///      Council.
  address internal constant EMERGENCY_OPERATOR = 0x37409c868BA42B91ff7E7b64D5BC020897444fAf;

  function setUp() public override(PostDeploymentVerificationBase) {
    _etchCreate2Factory();
    PostDeploymentVerificationBase.setUp();
  }

  function test_expectedChainId() public pure {
    assertEq(_expectedChainId(), ETHEREUM_CHAIN_ID);
  }

  /// @notice The Security Council admins the AccessManager and owns the ProxyAdmins, and the
  ///         Sentora Executor owns every other contract.
  function test_deployInputs() public view {
    InputUtils.FullDeployInputs memory inputs = _getDeployInputs();
    address sentoraExecutor = AaveV4SentoraConfigInputs.SENTORA_EXECUTOR_PLACEHOLDER;

    assertEq(inputs.accessManagerAdmin, SECURITY_COUNCIL, 'accessManagerAdmin');
    assertEq(inputs.proxyAdminOwner, SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(inputs.treasurySpokeOwner, sentoraExecutor, 'treasurySpokeOwner');
    assertEq(inputs.gatewayOwner, sentoraExecutor, 'gatewayOwner');
    assertEq(inputs.positionManagerOwner, sentoraExecutor, 'positionManagerOwner');

    // roles 100-103 and 300-302 are left unheld, as on the live Ethereum and Avalanche markets, and
    // roles 200 and 400 are granted at handover
    assertEq(inputs.hubAdmin, address(0), 'hubAdmin');
    assertEq(inputs.spokeAdmin, address(0), 'spokeAdmin');
    assertEq(inputs.hubConfiguratorAdmin, address(0), 'hubConfiguratorAdmin');
    assertEq(inputs.spokeConfiguratorAdmin, address(0), 'spokeConfiguratorAdmin');

    assertEq(inputs.nativeWrapper, WETH, 'nativeWrapper');
    assertTrue(inputs.deployNativeTokenGateway, 'deployNativeTokenGateway');
    assertTrue(inputs.deploySignatureGateway, 'deploySignatureGateway');
    assertTrue(inputs.deployPositionManagers, 'deployPositionManagers');
    // roles are granted by the configuration and handover scripts, not at deploy time
    assertFalse(inputs.grantRoles, 'grantRoles');

    assertEq(inputs.hubLabels.length, 1, 'hub count');
    assertEq(inputs.hubLabels[0], 'sentora', 'hub label');
    assertEq(inputs.spokeLabels.length, 3, 'spoke count');
    assertEq(inputs.spokeLabels[0], 'rlusdYield', 'spoke label');
    assertEq(inputs.spokeLabels[1], 'ousdYield', 'spoke label');
    assertEq(inputs.spokeLabels[2], 'bluechip', 'spoke label');
    assertEq(inputs.spokeMaxReservesLimits.length, 0, 'spoke max reserves limits');
    assertTrue(inputs.salt != bytes32(0), 'salt');
  }

  /// @notice The handover targets are read off the same file the deploy is driven by.
  /// @dev The Sentora Executor and Risk Steward are placeholders until they are known: replace the
  ///      assertions and config/sentora.json together.
  function test_handoverTargets() public view {
    AaveV4SentoraConfigInputs.Handover memory targets = AaveV4SentoraConfigInputs.readHandover();
    address sentoraExecutor = AaveV4SentoraConfigInputs.SENTORA_EXECUTOR_PLACEHOLDER;

    assertEq(targets.admin, SECURITY_COUNCIL, 'admin');
    assertEq(targets.proxyAdminOwner, SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(targets.treasurySpokeOwner, sentoraExecutor, 'treasurySpokeOwner');
    assertEq(targets.gatewayOwner, sentoraExecutor, 'gatewayOwner');
    assertEq(targets.positionManagerOwner, sentoraExecutor, 'positionManagerOwner');
    assertEq(targets.sentoraExecutor, sentoraExecutor, 'sentoraExecutor');
    assertEq(
      targets.riskSteward,
      AaveV4SentoraConfigInputs.RISK_STEWARD_PLACEHOLDER,
      'riskSteward'
    );
    assertEq(targets.emergencyOperator, EMERGENCY_OPERATOR, 'emergencyOperator');
  }

  /// @notice The Hub assets and rate curves of the ARFC, OUSD being Open USD. No price source is an
  ///         SVR feed: Aave's capped adapters for RLUSD and PYUSD, the capped USDT/USD the V4
  ///         Ethena Spokes price USDe with, Chainlink MWIN NAV and Chainlink BTC/USD. OUSD, PRIME and
  ///         PST carry no price source until their adapters are deployed, which blocks configuration.
  function test_launchAssets() public view {
    AaveV4SentoraConfigInputs.Asset[] memory assets = AaveV4SentoraConfigInputs.readAssets();
    assertEq(assets.length, 8, 'asset count');

    _assertAsset(
      assets[0],
      'RLUSD',
      0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD,
      0xf0eaC18E908B34770FDEe46d069c846bDa866759,
      true
    );
    _assertAsset(
      assets[1],
      'PYUSD',
      0x6c3ea9036406852006290770BEdFcAbA0e23A0e8,
      0x36964C0579D02E0a5AaAb89E24Cf8d7CDF3549EE,
      true
    );
    _assertAsset(assets[2], 'OUSD', 0x9f6F3991D525015a6F8CaF062C83b62fD3AC4436, address(0), true);
    _assertAsset(
      assets[3],
      'USDe',
      0x4c9EDD5852cd905f086C759E8383e09bff1E68B3,
      0xC26D4a1c46d884cfF6dE9800B6aE7A8Cf48B4Ff8,
      false
    );
    _assertAsset(assets[4], 'PRIME', 0x19ebb35279A16207Ec4ba82799CC64715065F7F6, address(0), false);
    _assertAsset(
      assets[5],
      'mWIN',
      0x4E72025984424E52838cf8953E2863eFf036B67A,
      0x3EC0233530c548Ab984eb06BEE8a2E404aeA7557,
      false
    );
    _assertAsset(assets[6], 'PST', 0x22aE3D9a738471f405169Af055d31c687087d4c7, address(0), false);
    _assertAsset(
      assets[7],
      'kBTC',
      0x73E0C0d45E048D25Fc26Fa3159b0aA04BfA4Db98,
      0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
      false
    );
  }

  /// @notice The Spoke reserves, caps and risk parameters of the ARFC.
  function test_launchReserves() public view {
    AaveV4SentoraConfigInputs.Reserve[] memory reserves = AaveV4SentoraConfigInputs.readReserves(
      AaveV4SentoraConfigInputs.readAssets()
    );
    assertEq(reserves.length, 14, 'reserve count');

    _assertBorrowable(reserves[0], 0, 0, 100_000_000, 90_000_000);
    _assertCollateral(reserves[1], 0, 3, 50_000_000, 91_50, 103_50, 6_25, 3_50);
    _assertCollateral(reserves[2], 0, 4, 15_000_000, 89_50, 105_00, 18_75, 5_00);
    _assertCollateral(reserves[3], 0, 5, 75, 84_60, 107_50, 0, 7_50);
    _assertCollateral(reserves[4], 0, 6, 20_000_000, 87_50, 105_00, 75_00, 5_00);

    _assertBorrowable(reserves[5], 1, 2, 10_000_000, 9_000_000);
    _assertCollateral(reserves[6], 1, 3, 5_000_000, 91_50, 103_50, 6_25, 3_50);
    _assertCollateral(reserves[7], 1, 4, 1_500_000, 89_50, 105_00, 18_75, 5_00);
    _assertCollateral(reserves[8], 1, 5, 7, 84_60, 107_50, 0, 7_50);
    _assertCollateral(reserves[9], 1, 6, 2_000_000, 87_50, 105_00, 75_00, 5_00);

    _assertBorrowable(reserves[10], 2, 0, 33_300_000, 30_000_000);
    _assertBorrowable(reserves[11], 2, 1, 33_300_000, 30_000_000);
    _assertBorrowable(reserves[12], 2, 2, 5_000_000, 4_500_000);
    _assertCollateral(reserves[13], 2, 7, 580, 86_00, 104_50, 0, 4_50);
  }

  function _assertAsset(
    AaveV4SentoraConfigInputs.Asset memory asset,
    string memory symbol,
    address underlying,
    address priceSource,
    bool borrowable
  ) internal pure {
    assertEq(asset.symbol, symbol, 'symbol');
    assertEq(asset.underlying, underlying, string.concat(symbol, ' underlying'));
    assertEq(asset.priceSource, priceSource, string.concat(symbol, ' price source'));
    assertEq(asset.optimalUsageRatio, 90_00, string.concat(symbol, ' optimal usage ratio'));
    assertFalse(asset.tokenize, string.concat(symbol, ' tokenize'));

    // borrowables share one curve; collateral-only assets are flat at 0%
    assertEq(asset.liquidityFee, borrowable ? 20_00 : 0, string.concat(symbol, ' liquidity fee'));
    assertEq(asset.baseDrawnRate, borrowable ? 50 : 0, string.concat(symbol, ' base rate'));
    assertEq(
      asset.rateGrowthBeforeOptimal,
      borrowable ? 3_50 : 0,
      string.concat(symbol, ' rate growth before optimal')
    );
    assertEq(
      asset.rateGrowthAfterOptimal,
      borrowable ? 12_00 : 0,
      string.concat(symbol, ' rate growth after optimal')
    );
  }

  /// @dev A borrowable reserve is never collateral, and its risk premium is left unbounded so
  ///      that borrowing against collateral with a collateral risk is not rejected by the Hub.
  function _assertBorrowable(
    AaveV4SentoraConfigInputs.Reserve memory reserve,
    uint256 spokeIndex,
    uint256 assetIndex,
    uint40 addCap,
    uint40 drawCap
  ) internal pure {
    _assertReserveKey(reserve, spokeIndex, assetIndex);
    assertEq(reserve.addCap, addCap, 'add cap');
    assertEq(reserve.drawCap, drawCap, 'draw cap');
    assertEq(reserve.riskPremiumThreshold, type(uint24).max, 'risk premium threshold');
    assertTrue(reserve.borrowable, 'borrowable');
    assertEq(reserve.collateralFactor, 0, 'collateral factor');
    assertEq(reserve.maxLiquidationBonus, 100_00, 'max liquidation bonus');
    assertEq(reserve.liquidationFee, 0, 'liquidation fee');
    assertEq(reserve.collateralRisk, 0, 'collateral risk');
  }

  function _assertCollateral(
    AaveV4SentoraConfigInputs.Reserve memory reserve,
    uint256 spokeIndex,
    uint256 assetIndex,
    uint40 addCap,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint24 collateralRisk,
    uint16 liquidationFee
  ) internal pure {
    _assertReserveKey(reserve, spokeIndex, assetIndex);
    assertEq(reserve.addCap, addCap, 'add cap');
    assertEq(reserve.drawCap, 0, 'draw cap');
    assertEq(reserve.riskPremiumThreshold, 0, 'risk premium threshold');
    assertFalse(reserve.borrowable, 'borrowable');
    assertEq(reserve.collateralFactor, collateralFactor, 'collateral factor');
    assertEq(reserve.maxLiquidationBonus, maxLiquidationBonus, 'max liquidation bonus');
    assertEq(reserve.liquidationFee, liquidationFee, 'liquidation fee');
    assertEq(reserve.collateralRisk, collateralRisk, 'collateral risk');
  }

  function _assertReserveKey(
    AaveV4SentoraConfigInputs.Reserve memory reserve,
    uint256 spokeIndex,
    uint256 assetIndex
  ) internal pure {
    assertEq(reserve.spokeIndex, spokeIndex, string.concat(reserve.spoke, ' spoke index'));
    assertEq(reserve.assetIndex, assetIndex, string.concat(reserve.asset, ' asset index'));
    assertTrue(reserve.receiveSharesEnabled, 'receive shares');
  }

  /// @notice The liquidation curve every reserve of a Spoke shares.
  function test_liquidationConfig() public pure {
    ISpoke.LiquidationConfig memory config = AaveV4SentoraParameters.liquidationConfig();

    assertEq(config.targetHealthFactor, 1.24e18, 'target health factor');
    assertEq(config.healthFactorForMaxBonus, 0.9e18, 'health factor for max bonus');
    assertEq(config.liquidationBonusFactor, 90_00, 'liquidation bonus factor');
  }

  /// @notice A deploy on Ethereum refuses to run while any handover target is still a
  ///         placeholder, starting with the first one read.
  function test_deployInputsRejectPlaceholderOnEthereum() public {
    vm.chainId(ETHEREUM_CHAIN_ID);

    vm.expectRevert(
      abi.encodeWithSelector(
        AaveV4SentoraConfigInputs.PlaceholderAddress.selector,
        'treasurySpokeOwner'
      )
    );
    this.readDeployInputs();
  }

  /// @dev Exposes the deploy inputs externally, so that `vm.expectRevert` sees a nested call.
  function readDeployInputs() external view returns (InputUtils.FullDeployInputs memory) {
    return _getDeployInputs();
  }

  /// @notice The config engine lands on the address `predictedAddress` computes for it.
  /// @dev That address is what configuration payloads are built against, and nothing records it, so
  ///      it has to be recomputable rather than merely deterministic.
  function test_configEngineDeploysAtPredictedAddress() public {
    address predicted = AaveV4SentoraConfigEngine.predictedAddress();
    assertEq(predicted.code.length, 0, 'already deployed');

    assertEq(AaveV4SentoraConfigEngine.deploy(), predicted, 'deployed address');
    assertGt(predicted.code.length, 0, 'engine code');
  }

  function test_deployWithSentoraConfig() public {
    InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
      _getDeployInputs(),
      _deployer
    );

    // the Hub and Spoke ProxyAdmins have their end-state owner from the deploy transaction onwards
    assertEq(sanitizedInputs.proxyAdminOwner, SECURITY_COUNCIL, 'proxyAdminOwner');

    // the managers and gateways start on the deployer, which needs `onlyOwner` access to
    // `registerSpoke` during configuration, and so does the treasury spoke, whose ProxyAdmin the
    // deploy gives the same owner and the handover then splits off
    assertEq(sanitizedInputs.gatewayOwner, _deployer, 'gatewayOwner');
    assertEq(sanitizedInputs.positionManagerOwner, _deployer, 'positionManagerOwner');
    assertEq(sanitizedInputs.treasurySpokeOwner, _deployer, 'treasurySpokeOwner');

    _deployWriteReportAndVerify(sanitizedInputs);
  }

  /// @dev Tests are non-interactive.
  function _executeUserPrompt() internal override {}
}
