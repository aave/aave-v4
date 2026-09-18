// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PostDeploymentVerificationBase} from 'tests/deployments/fork/PostDeploymentVerificationBase.t.sol';
import {AaveV4DeployBase} from 'scripts/deploy/AaveV4DeployBase.s.sol';
import {AaveV4BaseConfigEngine} from 'scripts/config/AaveV4BaseConfigEngine.sol';
import {AaveV4BaseConfigInputs} from 'scripts/config/AaveV4BaseConfigInputs.sol';
import {AaveV4BaseParameters} from 'scripts/config/AaveV4BaseParameters.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4BaseDeployConfigTest
/// @author Aave Labs
/// @notice Checks that config/base.json and config/base-config.json parse into the intended inputs,
///         and that a full deployment driven by those inputs sets every ownership as configured.
contract AaveV4BaseDeployConfigTest is PostDeploymentVerificationBase, AaveV4DeployBase {
  /// @dev `MiscEthereum.V4_SECURITY_COUNCIL`, which is the same address on Ethereum, Avalanche and
  ///      Arc and is expected to be the same on Base.
  address internal constant V4_SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;
  /// @dev `GovernanceV3Base.EXECUTOR_LVL_1`.
  address internal constant GOVERNANCE_EXECUTOR = 0x9390B1735def18560c509E2d0bc090E9d6BA257a;
  address internal constant WETH = 0x4200000000000000000000000000000000000006;
  address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
  /// @dev The `PriceCapAdapterStable` Aave V3 Base already prices USDC through, capped at $1.04.
  address internal constant USDC_PRICE_SOURCE = 0xf52D010c7d4ecBfda92c2509900593CE34535D86;
  uint256 internal constant BASE_CHAIN_ID = 8453;

  function setUp() public override(PostDeploymentVerificationBase) {
    _etchCreate2Factory();
    PostDeploymentVerificationBase.setUp();
  }

  function test_expectedChainId() public pure {
    assertEq(_expectedChainId(), BASE_CHAIN_ID);
  }

  /// @dev The Security Council owns the market outright. The V4 Security Council executor is not
  ///      deployed on Base yet, so both configurator domain admin fields are still the placeholder:
  ///      update these assertions together with config/base.json once it is.
  function test_deployInputs() public view {
    InputUtils.FullDeployInputs memory inputs = _getDeployInputs();

    assertEq(inputs.accessManagerAdmin, V4_SECURITY_COUNCIL, 'accessManagerAdmin');
    assertEq(inputs.proxyAdminOwner, V4_SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(inputs.treasurySpokeOwner, V4_SECURITY_COUNCIL, 'treasurySpokeOwner');
    assertEq(inputs.gatewayOwner, V4_SECURITY_COUNCIL, 'gatewayOwner');
    assertEq(inputs.positionManagerOwner, V4_SECURITY_COUNCIL, 'positionManagerOwner');

    // the domain admin roles end up with whoever executes the Council's configuration payloads,
    // which is not the Safe that owns the market
    assertEq(inputs.hubConfiguratorAdmin, PLACEHOLDER_ADDRESS, 'hubConfiguratorAdmin');
    assertEq(inputs.spokeConfiguratorAdmin, PLACEHOLDER_ADDRESS, 'spokeConfiguratorAdmin');

    // roles 100-103 and 300-302 are left unheld, as on the live Ethereum and Avalanche markets
    assertEq(inputs.hubAdmin, address(0), 'hubAdmin');
    assertEq(inputs.spokeAdmin, address(0), 'spokeAdmin');

    assertEq(inputs.nativeWrapper, WETH, 'nativeWrapper');
    assertTrue(inputs.deployNativeTokenGateway, 'deployNativeTokenGateway');
    assertTrue(inputs.deploySignatureGateway, 'deploySignatureGateway');
    assertTrue(inputs.deployPositionManagers, 'deployPositionManagers');
    // roles are granted by the configuration and handover scripts, not at deploy time
    assertFalse(inputs.grantRoles, 'grantRoles');

    assertEq(inputs.hubLabels.length, 1, 'hub count');
    assertEq(inputs.hubLabels[0], 'equities', 'hub label');
    assertEq(inputs.spokeLabels.length, 1, 'spoke count');
    assertEq(inputs.spokeLabels[0], 'mag7', 'spoke label');
    assertEq(inputs.spokeMaxReservesLimits.length, 0, 'spoke max reserves limits');
    assertTrue(inputs.salt != bytes32(0), 'salt');
  }

  /// @notice The handover targets are read off the same file the deploy is driven by.
  function test_handoverTargets() public view {
    AaveV4BaseConfigInputs.Handover memory targets = AaveV4BaseConfigInputs.readHandover();

    assertEq(targets.securityCouncil, V4_SECURITY_COUNCIL, 'securityCouncil');
    assertEq(targets.councilExecutor, PLACEHOLDER_ADDRESS, 'councilExecutor');
    assertEq(targets.governanceExecutor, GOVERNANCE_EXECUTOR, 'governanceExecutor');
    assertEq(targets.proxyAdminOwner, V4_SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(targets.treasurySpokeOwner, V4_SECURITY_COUNCIL, 'treasurySpokeOwner');
    assertEq(targets.gatewayOwner, V4_SECURITY_COUNCIL, 'gatewayOwner');
    assertEq(targets.positionManagerOwner, V4_SECURITY_COUNCIL, 'positionManagerOwner');
  }

  /// @notice The launch set is the seven Coinbase tokenized equities as collateral, plus USDC as the
  ///         only borrowable asset, each with the risk parameters it was signed off with.
  /// @dev Pins config/base-config.json against the risk provider's tables rather than against the
  ///      configuration code, which reads the file verbatim. Editing a parameter has to happen here
  ///      too, which is the point.
  function test_launchSetMatchesTheRiskParameters() public view {
    AaveV4BaseConfigInputs.Asset[] memory assets = AaveV4BaseConfigInputs.readAssets();

    string[7] memory symbols = ['AAPLc', 'AMZNc', 'GOOGLc', 'METAc', 'MSFTc', 'NVDAc', 'TSLAc'];
    address[7] memory underlyings = [
      0xb200000000000000000000C2e324d24d7eEcd1fb,
      0xb200000000000000000000d9192b6B456483C2E8,
      0xb2000000000000000000002D0BA3164cc74f58B7,
      0xb2000000000000000000008bC8786B856E61707C,
      0xB200000000000000000000Ab99cFa739E253872B,
      0xb20000000000000000000078ee7ce2fE4908108C,
      0xb2000000000000000000001e800a7f5189430cD0
    ];
    address[7] memory priceSources = [
      0x787f13dEa48Db0897CbCDD985de77809D837F988,
      0x06A8E4b3aBB3B7543d8396FB2B763d22820cB295,
      0x5bF49E0ffA937CE2FfF033c739aD7C634c4D34F2,
      0x6526aE6797A76123638b863AeE4dD27Ba4E4b27D,
      0xeB10A6c9aa7E537aEd766C08c35Dae35B321b18c,
      0x04689a41629776563E6822F76f2e57D148d28513,
      0xFaf869185383a24F8cb00e27BdA6b63B9905DCb4
    ];
    uint16[7] memory collateralFactors = [uint16(78_00), 73_00, 76_00, 65_00, 79_00, 70_00, 65_00];
    uint40[7] memory addCaps = [uint40(15_000), 10_500, 15_000, 5_800, 5_200, 24_000, 14_000];

    assertEq(assets.length, symbols.length + 1, 'asset count');

    for (uint256 i; i < symbols.length; ++i) {
      AaveV4BaseConfigInputs.Asset memory asset = assets[i];

      assertEq(asset.symbol, symbols[i], 'symbol');
      assertEq(asset.underlying, underlyings[i], 'underlying');
      assertEq(asset.priceSource, priceSources[i], 'price source');
      assertEq(asset.collateralFactor, collateralFactors[i], 'collateral factor');
      assertEq(asset.addCap, addCaps[i], 'add cap');

      // the equities are collateral only: a 5.50% maximum bonus with a 10% protocol cut, nothing
      // drawable, and no tokenization spoke
      assertEq(asset.maxLiquidationBonus, 105_50, 'max liquidation bonus');
      assertEq(asset.liquidationFee, 10_00, 'liquidation fee');
      assertTrue(asset.receiveSharesEnabled, 'receive shares');
      assertFalse(asset.borrowable, 'borrowable');
      assertEq(asset.drawCap, 0, 'draw cap');
      assertEq(asset.riskPremiumThreshold, 0, 'risk premium threshold');
      assertFalse(asset.tokenize, 'tokenize');

      // no liquidity fee, as every collateral-only asset of the live Ethereum and Avalanche markets
      // carries, and the flattest curve `AssetInterestRateStrategy` accepts since nothing accrues
      assertEq(asset.liquidityFee, 0, 'liquidity fee');
      assertEq(asset.optimalUsageRatio, 1_00, 'optimal usage ratio');
      assertEq(asset.baseDrawnRate, 0, 'base drawn rate');
      assertEq(asset.rateGrowthBeforeOptimal, 0, 'rate growth before optimal');
      assertEq(asset.rateGrowthAfterOptimal, 0, 'rate growth after optimal');
    }

    AaveV4BaseConfigInputs.Asset memory usdc = assets[assets.length - 1];

    assertEq(usdc.symbol, 'USDC', 'USDC symbol');
    assertEq(usdc.underlying, USDC, 'USDC underlying');
    assertEq(usdc.priceSource, USDC_PRICE_SOURCE, 'USDC price source');

    // borrowable and never collateral, so the bonus is the 0.00% floor the Spoke validation accepts
    assertTrue(usdc.borrowable, 'USDC borrowable');
    assertTrue(usdc.receiveSharesEnabled, 'USDC receive shares');
    assertEq(usdc.collateralFactor, 0, 'USDC collateral factor');
    assertEq(usdc.maxLiquidationBonus, 100_00, 'USDC max liquidation bonus');
    assertEq(usdc.liquidationFee, 0, 'USDC liquidation fee');
    assertEq(usdc.riskPremiumThreshold, 0, 'USDC risk premium threshold');

    assertEq(usdc.addCap, 32_000_000, 'USDC add cap');
    assertEq(usdc.drawCap, 21_000_000, 'USDC draw cap');

    // the borrow rate peaks at 24%, which is 0% + 4% up to the kink + 20% beyond it
    assertEq(usdc.liquidityFee, 10_00, 'USDC liquidity fee');
    assertEq(usdc.optimalUsageRatio, 90_00, 'USDC optimal usage ratio');
    assertEq(usdc.baseDrawnRate, 0, 'USDC base drawn rate');
    assertEq(usdc.rateGrowthBeforeOptimal, 4_00, 'USDC rate growth before optimal');
    assertEq(usdc.rateGrowthAfterOptimal, 20_00, 'USDC rate growth after optimal');

    // the supply-only spoke composable positions are built on
    assertTrue(usdc.tokenize, 'USDC tokenize');
    assertEq(usdc.tokenizationAddCap, 1_000_000, 'USDC tokenization add cap');
  }

  /// @notice The liquidation curve every reserve of a Spoke shares.
  function test_liquidationConfigMatchesTheRiskParameters() public pure {
    ISpoke.LiquidationConfig memory config = AaveV4BaseParameters.liquidationConfig();

    assertEq(config.targetHealthFactor, 1.24e18, 'target health factor');
    assertEq(config.healthFactorForMaxBonus, 0.90e18, 'health factor for max bonus');
    assertEq(config.liquidationBonusFactor, 90_00, 'liquidation bonus factor');
  }

  /// @notice A deploy on Base itself refuses to read the placeholder address.
  function test_deployRevertsOnBaseWithPlaceholders() public {
    vm.chainId(BASE_CHAIN_ID);
    vm.expectRevert(abi.encodeWithSelector(PlaceholderAddress.selector, 'hubConfiguratorAdmin'));
    this.readDeployInputs();
  }

  /// @dev Exposes the deploy inputs externally, so that `vm.expectRevert` sees a nested call.
  function readDeployInputs() external view returns (InputUtils.FullDeployInputs memory) {
    return _getDeployInputs();
  }

  /// @notice The config engine lands on the address `predictedAddress` computes for it.
  /// @dev That address is what governance payloads are built against, and nothing records it, so it
  ///      has to be recomputable rather than merely deterministic.
  function test_configEngineDeploysAtPredictedAddress() public {
    address predicted = AaveV4BaseConfigEngine.predictedAddress();
    assertEq(predicted.code.length, 0, 'already deployed');

    assertEq(AaveV4BaseConfigEngine.deploy(), predicted, 'deployed address');
    assertGt(predicted.code.length, 0, 'engine code');
  }

  function test_deployWithBaseConfig() public {
    InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
      _getDeployInputs(),
      _deployer
    );

    // the Council owns the proxies and the treasury spoke from the deploy transaction onwards
    assertEq(sanitizedInputs.proxyAdminOwner, V4_SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(sanitizedInputs.treasurySpokeOwner, V4_SECURITY_COUNCIL, 'treasurySpokeOwner');

    // the managers and gateways start on the deployer, which needs `onlyOwner` access to
    // `registerSpoke` during configuration
    assertEq(sanitizedInputs.gatewayOwner, _deployer, 'gatewayOwner');
    assertEq(sanitizedInputs.positionManagerOwner, _deployer, 'positionManagerOwner');

    _deployWriteReportAndVerify(sanitizedInputs);
  }

  /// @dev Tests are non-interactive.
  function _executeUserPrompt() internal override {}
}
