// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

/// @dev Validates the Paxos TokenizationSpoke replacement on a devnet where the Security Council
/// activation batch (`output/paxos-tokenization-spokes-activation.json`) has been executed.
/// Skipped unless TENDERLY_DEVNET_RPC is set.
contract PaxosTokenizationSpokesActivationTest is Test {
  using SafeERC20 for IERC20;

  address internal constant PAXOS_HUB = 0x62d63197660c080236193CA60b70E49A08E90368;
  address internal constant PROTOCOL_SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;
  address internal constant PAYLOADS_CONTROLLER = 0xdAbad81aF85554E9ae636395611C58F7eC1aAEc5;
  address internal constant EXECUTOR_LVL_1 = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

  address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address internal constant PT_USDG_24SEP2026 = 0xc1906aeCf868749a2DeE203F59b904c0cf212140;

  uint256 internal constant PT_USDG_ASSET_ID = 0;
  uint256 internal constant USDC_ASSET_ID = 1;
  uint256 internal constant USDT_ASSET_ID = 2;

  address internal constant NEW_WA_PAXOS_USDC = 0xFaB44fbD00C5056956BC1c4d681A80563E10d2fD;
  address internal constant NEW_WA_PAXOS_USDT = 0xF38C21AE3b87981e954c4eF6b5C1Cbd4BfB00E27;
  address internal constant NEW_WA_PAXOS_PT_USDG = 0xB4086ae520EA1314b3EE7f899887acfD5ccdE406;

  address internal constant OLD_WA_PAXOS_USDC = 0x4131E0B2E7AFeCEAf3d3b4225aA61a3B2B7535b8;
  address internal constant OLD_WA_PAXOS_USDT = 0x8Dabe53E8cB991c57f0307F6f419E6D469b0deAA;
  address internal constant OLD_WA_PAXOS_PT_USDG = 0x27eF1140364948A0E30E248297FfDFE5a4091ec4;

  address internal constant OLD_WA_PAXOS_USDC_HOLDER = 0x9cCf93089cb14F94BAeB8822F8CeFfd91Bd71649;

  uint40 internal constant ADD_CAP = 13_000_000;

  address internal USER = makeAddr('USER');

  bool internal _devnetAvailable;

  modifier onlyDevnet() {
    vm.skip(!_devnetAvailable, 'TENDERLY_DEVNET_RPC not set');
    _;
  }

  function setUp() public {
    string memory rpc = vm.envOr('TENDERLY_DEVNET_RPC', string(''));
    if (bytes(rpc).length == 0) return;
    vm.createSelectFork(rpc);
    _devnetAvailable = true;
  }

  function test_newSpokes_proxyAdminOwnership() public onlyDevnet {
    address[3] memory spokes = [NEW_WA_PAXOS_USDC, NEW_WA_PAXOS_USDT, NEW_WA_PAXOS_PT_USDG];
    for (uint256 i; i < spokes.length; ++i) {
      address owner = Ownable(ProxyHelper.getProxyAdmin(spokes[i])).owner();
      assertEq(owner, PROTOCOL_SECURITY_COUNCIL);
      assertNotEq(owner, PAYLOADS_CONTROLLER);
      assertNotEq(owner, EXECUTOR_LVL_1);
    }
  }

  function test_newSpokes_activationState() public onlyDevnet {
    _assertSpokeConfig({
      assetId: USDC_ASSET_ID,
      spoke: NEW_WA_PAXOS_USDC,
      underlying: USDC,
      expectedAddCap: ADD_CAP
    });
    _assertSpokeConfig({
      assetId: USDT_ASSET_ID,
      spoke: NEW_WA_PAXOS_USDT,
      underlying: USDT,
      expectedAddCap: ADD_CAP
    });
    _assertSpokeConfig({
      assetId: PT_USDG_ASSET_ID,
      spoke: NEW_WA_PAXOS_PT_USDG,
      underlying: PT_USDG_24SEP2026,
      expectedAddCap: 0
    });
  }

  function test_oldSpokes_remainFrozen() public onlyDevnet {
    _assertSpokeConfig({
      assetId: USDC_ASSET_ID,
      spoke: OLD_WA_PAXOS_USDC,
      underlying: USDC,
      expectedAddCap: 0
    });
    _assertSpokeConfig({
      assetId: USDT_ASSET_ID,
      spoke: OLD_WA_PAXOS_USDT,
      underlying: USDT,
      expectedAddCap: 0
    });
    _assertSpokeConfig({
      assetId: PT_USDG_ASSET_ID,
      spoke: OLD_WA_PAXOS_PT_USDG,
      underlying: PT_USDG_24SEP2026,
      expectedAddCap: 0
    });
  }

  function test_newUsdcSpoke_depositAndRedeem() public onlyDevnet {
    _depositAndRedeem(NEW_WA_PAXOS_USDC, USDC, 1000e6);
  }

  function test_newUsdtSpoke_depositAndRedeem() public onlyDevnet {
    _depositAndRedeem(NEW_WA_PAXOS_USDT, USDT, 1000e6);
  }

  function test_newUsdcSpoke_depositAboveCapReverts() public onlyDevnet {
    uint256 amount = (uint256(ADD_CAP) + 1) * 1e6;
    deal(USDC, USER, amount);
    vm.startPrank(USER);
    IERC20(USDC).forceApprove(NEW_WA_PAXOS_USDC, amount);
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, ADD_CAP));
    ITokenizationSpoke(NEW_WA_PAXOS_USDC).deposit(amount, USER);
    vm.stopPrank();
  }

  function test_newPtSpoke_depositReverts_zeroCap() public onlyDevnet {
    deal(PT_USDG_24SEP2026, USER, 100e6);
    vm.startPrank(USER);
    IERC20(PT_USDG_24SEP2026).forceApprove(NEW_WA_PAXOS_PT_USDG, 100e6);
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, 0));
    ITokenizationSpoke(NEW_WA_PAXOS_PT_USDG).deposit(100e6, USER);
    vm.stopPrank();
  }

  function test_oldSpokes_depositsBlocked() public onlyDevnet {
    deal(USDC, USER, 100e6);
    deal(USDT, USER, 100e6);
    vm.startPrank(USER);

    IERC20(USDC).forceApprove(OLD_WA_PAXOS_USDC, 100e6);
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, 0));
    ITokenizationSpoke(OLD_WA_PAXOS_USDC).deposit(100e6, USER);

    IERC20(USDT).forceApprove(OLD_WA_PAXOS_USDT, 100e6);
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, 0));
    ITokenizationSpoke(OLD_WA_PAXOS_USDT).deposit(100e6, USER);

    vm.stopPrank();
  }

  function test_oldUsdcSpoke_withdrawalsOpen() public onlyDevnet {
    ITokenizationSpoke oldSpoke = ITokenizationSpoke(OLD_WA_PAXOS_USDC);
    uint256 shares = oldSpoke.balanceOf(OLD_WA_PAXOS_USDC_HOLDER);
    assertGt(shares, 0);

    uint256 balanceBefore = IERC20(USDC).balanceOf(OLD_WA_PAXOS_USDC_HOLDER);
    vm.prank(OLD_WA_PAXOS_USDC_HOLDER);
    uint256 assets = oldSpoke.redeem(shares, OLD_WA_PAXOS_USDC_HOLDER, OLD_WA_PAXOS_USDC_HOLDER);

    assertGt(assets, 0);
    assertEq(
      IERC20(USDC).balanceOf(OLD_WA_PAXOS_USDC_HOLDER),
      balanceBefore + assets,
      'holder should be able to fully exit the frozen spoke'
    );
    assertEq(oldSpoke.balanceOf(OLD_WA_PAXOS_USDC_HOLDER), 0);
  }

  function _depositAndRedeem(address spoke, address underlying, uint256 amount) internal {
    deal(underlying, USER, amount);
    vm.startPrank(USER);
    IERC20(underlying).forceApprove(spoke, amount);

    uint256 shares = ITokenizationSpoke(spoke).deposit(amount, USER);
    assertGt(shares, 0);
    assertEq(ITokenizationSpoke(spoke).balanceOf(USER), shares);

    uint256 assets = ITokenizationSpoke(spoke).redeem(shares, USER, USER);
    vm.stopPrank();

    assertEq(ITokenizationSpoke(spoke).balanceOf(USER), 0);
    assertApproxEqAbs(assets, amount, 2, 'redeem should return the deposited amount');
    assertEq(IERC20(underlying).balanceOf(USER), assets);
  }

  function _assertSpokeConfig(
    uint256 assetId,
    address spoke,
    address underlying,
    uint40 expectedAddCap
  ) internal view {
    IHub hub = IHub(PAXOS_HUB);
    assertTrue(hub.isSpokeListed(assetId, spoke));
    assertEq(ITokenizationSpoke(spoke).asset(), underlying);

    IHub.SpokeConfig memory config = hub.getSpokeConfig(assetId, spoke);
    assertEq(config.addCap, expectedAddCap);
    assertEq(config.drawCap, 0);
    assertEq(config.riskPremiumThreshold, 0);
    assertTrue(config.active);
    assertFalse(config.halted);
  }
}
