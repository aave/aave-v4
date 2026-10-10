// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract FeeSharesMinterTest is Base {
  using SafeCast for uint256;
  using PercentageMath for uint256;

  FeeSharesMinter internal minter;

  address internal FORWARDER;
  address internal WORKFLOW_OWNER;
  bytes10 internal constant WORKFLOW_NAME = bytes10('fee-minter');
  bytes32 internal constant WORKFLOW_ID = keccak256('FeeSharesMinter:test');

  function setUp() public override {
    super.setUp();
    minter = new FeeSharesMinter(ADMIN);

    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_FEE_MINTER_ROLE, address(minter), 0);

    FORWARDER = makeAddr('forwarder');
    WORKFLOW_OWNER = makeAddr('workflow-owner');

    vm.prank(ADMIN);
    minter.setWorkflowConfig(
      WORKFLOW_ID,
      IFeeSharesMinter.WorkflowConfig({
        forwarder: FORWARDER,
        owner: WORKFLOW_OWNER,
        name: WORKFLOW_NAME,
        isActive: true
      })
    );
  }

  function test_supportsInterface() public view {
    assertTrue(minter.supportsInterface(type(IReceiver).interfaceId));
    assertTrue(minter.supportsInterface(type(IERC165).interfaceId));
    assertFalse(minter.supportsInterface(0xffffffff));
  }

  function test_setConfig_revertsWith_OwnableUnauthorized() public {
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
    minter.setConfig(address(hub1), daiAssetId, 100);
  }

  function test_fuzz_setConfig(uint16 minAccruedFeesPercent) public {
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    vm.expectEmit(address(minter));
    emit IFeeSharesMinter.ConfigUpdated(address(hub1), daiAssetId, minAccruedFeesPercent);

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, minAccruedFeesPercent);

    assertEq(minter.getConfig(address(hub1), daiAssetId), minAccruedFeesPercent);
  }

  function test_setConfig_independentPerPair() public {
    uint16 config1 = 100;
    uint16 config2 = 200;

    vm.startPrank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config1);
    minter.setConfig(address(hub1), wethAssetId, config2);
    vm.stopPrank();

    assertEq(minter.getConfig(address(hub1), daiAssetId), config1, 'daiAssetId config');
    assertEq(minter.getConfig(address(hub1), wethAssetId), config2, 'wethAssetId config');
    assertEq(minter.getConfig(address(hub1), usdxAssetId), 0, 'usdxAssetId should be unset');
  }

  function test_setConfig_zeroDisables() public {
    _setupHappyPath(daiAssetId, 1);

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 0);
    assertEq(minter.getConfig(address(hub1), daiAssetId), 0);

    _assertCannotMint(address(hub1), daiAssetId);
  }

  function test_fuzz_setConfig_revertsWith_InvalidConfig(uint16 minAccruedFeesPercent) public {
    minAccruedFeesPercent = bound(
      minAccruedFeesPercent,
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint16).max
    ).toUint16();

    vm.prank(ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(IFeeSharesMinter.InvalidConfig.selector, minAccruedFeesPercent)
    );
    minter.setConfig(address(hub1), daiAssetId, minAccruedFeesPercent);
  }

  function test_setConfig_revertsWith_AssetNotListed() public {
    uint256 invalidAssetId = hub1.getAssetCount();
    vm.prank(ADMIN);
    vm.expectRevert(IHub.AssetNotListed.selector);
    minter.setConfig(address(hub1), invalidAssetId, 100);
  }

  function test_getConfig_returnsZero_whenUnset() public view {
    assertEq(minter.getConfig(address(hub1), daiAssetId), 0);
  }

  function test_getConfig_returnsLatestSetValue() public {
    vm.startPrank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 100);
    assertEq(minter.getConfig(address(hub1), daiAssetId), 100);

    minter.setConfig(address(hub1), daiAssetId, 250);
    vm.stopPrank();
    assertEq(minter.getConfig(address(hub1), daiAssetId), 250);
  }

  function test_getConfig_isIndependentPerHub() public {
    address otherHub = makeAddr('other-hub');
    vm.mockCall(
      otherHub,
      abi.encodeWithSelector(IHub.getAssetCount.selector),
      abi.encode(uint256(10))
    );

    vm.startPrank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 100);
    minter.setConfig(otherHub, daiAssetId, 200);
    vm.stopPrank();

    assertEq(minter.getConfig(address(hub1), daiAssetId), 100);
    assertEq(minter.getConfig(otherHub, daiAssetId), 200);
  }

  function test_getWorkflowConfig_returnsZeroStruct_whenUnset() public view {
    bytes32 unknownId = keccak256('never-registered');
    IFeeSharesMinter.WorkflowConfig memory stored = minter.getWorkflowConfig(unknownId);
    assertEq(stored.forwarder, address(0));
    assertEq(stored.owner, address(0));
    assertEq(stored.name, bytes10(0));
    assertFalse(stored.isActive);
  }

  function test_getWorkflowConfig_returnsDefault() public view {
    IFeeSharesMinter.WorkflowConfig memory stored = minter.getWorkflowConfig(WORKFLOW_ID);
    assertEq(stored.forwarder, FORWARDER);
    assertEq(stored.owner, WORKFLOW_OWNER);
    assertEq(stored.name, WORKFLOW_NAME);
    assertTrue(stored.isActive);
  }

  function test_getWorkflowConfig_returnsLatestSetValue() public {
    address forwarder2 = makeAddr('forwarder-2');
    address owner2 = makeAddr('owner-2');
    bytes10 name2 = bytes10('updated-wf');

    vm.prank(ADMIN);
    minter.setWorkflowConfig(
      WORKFLOW_ID,
      IFeeSharesMinter.WorkflowConfig({
        forwarder: forwarder2,
        owner: owner2,
        name: name2,
        isActive: false
      })
    );

    IFeeSharesMinter.WorkflowConfig memory stored = minter.getWorkflowConfig(WORKFLOW_ID);
    assertEq(stored.forwarder, forwarder2);
    assertEq(stored.owner, owner2);
    assertEq(stored.name, name2);
    assertFalse(stored.isActive);
  }

  function test_getWorkflowConfig_isIndependentPerWorkflowId() public {
    bytes32 otherId = keccak256('workflow-other');
    address otherForwarder = makeAddr('forwarder-other');
    address otherOwner = makeAddr('owner-other');
    bytes10 otherName = bytes10('other-name');

    vm.prank(ADMIN);
    minter.setWorkflowConfig(
      otherId,
      IFeeSharesMinter.WorkflowConfig({
        forwarder: otherForwarder,
        owner: otherOwner,
        name: otherName,
        isActive: true
      })
    );

    IFeeSharesMinter.WorkflowConfig memory defaultCfg = minter.getWorkflowConfig(WORKFLOW_ID);
    IFeeSharesMinter.WorkflowConfig memory otherCfg = minter.getWorkflowConfig(otherId);

    assertEq(defaultCfg.forwarder, FORWARDER);
    assertEq(otherCfg.forwarder, otherForwarder);
    assertTrue(defaultCfg.forwarder != otherCfg.forwarder);
  }

  function test_setWorkflowConfig_revertsWith_OwnableUnauthorized() public {
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
    minter.setWorkflowConfig(WORKFLOW_ID, _defaultWorkflowConfig());
  }

  function test_setWorkflowConfig_emitsEvent() public {
    bytes32 newId = keccak256('another-workflow');
    address newForwarder = makeAddr('forwarder-2');
    address newOwner = makeAddr('owner-2');
    bytes10 newName = bytes10('other-name');

    vm.expectEmit(address(minter));
    emit IFeeSharesMinter.WorkflowConfigUpdated(newId, newForwarder, newOwner, newName, true);

    vm.prank(ADMIN);
    minter.setWorkflowConfig(
      newId,
      IFeeSharesMinter.WorkflowConfig({
        forwarder: newForwarder,
        owner: newOwner,
        name: newName,
        isActive: true
      })
    );

    IFeeSharesMinter.WorkflowConfig memory stored = minter.getWorkflowConfig(newId);
    assertEq(stored.forwarder, newForwarder);
    assertEq(stored.owner, newOwner);
    assertEq(stored.name, newName);
    assertTrue(stored.isActive);
  }

  function test_setWorkflowConfig_multipleWorkflows() public {
    _setupHappyPath(daiAssetId, 1);

    bytes32 secondId = keccak256('workflow-2');
    address secondForwarder = makeAddr('forwarder-2');
    address secondOwner = makeAddr('owner-2');
    bytes10 secondName = bytes10('second-wf');

    vm.prank(ADMIN);
    minter.setWorkflowConfig(
      secondId,
      IFeeSharesMinter.WorkflowConfig({
        forwarder: secondForwarder,
        owner: secondOwner,
        name: secondName,
        isActive: true
      })
    );

    // Both workflows can independently submit valid reports
    _callOnReport(FORWARDER, WORKFLOW_ID, WORKFLOW_NAME, WORKFLOW_OWNER, address(hub1), daiAssetId);

    _setupHappyPath(wethAssetId, 1);
    _callOnReport(secondForwarder, secondId, secondName, secondOwner, address(hub1), wethAssetId);
  }

  function test_setWorkflowConfig_canDeactivate() public {
    _setupHappyPath(daiAssetId, 1);

    IFeeSharesMinter.WorkflowConfig memory disabled = _defaultWorkflowConfig();
    disabled.isActive = false;

    vm.prank(ADMIN);
    minter.setWorkflowConfig(WORKFLOW_ID, disabled);

    vm.expectRevert(
      abi.encodeWithSelector(IFeeSharesMinter.WorkflowNotActive.selector, WORKFLOW_ID)
    );
    _callOnReportDefault(address(hub1), daiAssetId);
  }

  function test_onReport_revertsWith_WorkflowNotActive_unknownWorkflow() public {
    _setupHappyPath(daiAssetId, 1);

    bytes32 unknownId = keccak256('unknown');
    vm.expectRevert(abi.encodeWithSelector(IFeeSharesMinter.WorkflowNotActive.selector, unknownId));
    _callOnReport(FORWARDER, unknownId, WORKFLOW_NAME, WORKFLOW_OWNER, address(hub1), daiAssetId);
  }

  function test_onReport_revertsWith_InvalidWorkflowForwarder() public {
    _setupHappyPath(daiAssetId, 1);

    address wrongForwarder = makeAddr('wrong-forwarder');
    vm.expectRevert(
      abi.encodeWithSelector(
        IFeeSharesMinter.InvalidWorkflowForwarder.selector,
        wrongForwarder,
        FORWARDER
      )
    );
    _callOnReport(
      wrongForwarder,
      WORKFLOW_ID,
      WORKFLOW_NAME,
      WORKFLOW_OWNER,
      address(hub1),
      daiAssetId
    );
  }

  function test_onReport_revertsWith_InvalidWorkflowOwner() public {
    _setupHappyPath(daiAssetId, 1);

    address wrongOwner = makeAddr('wrong-owner');
    vm.expectRevert(
      abi.encodeWithSelector(
        IFeeSharesMinter.InvalidWorkflowOwner.selector,
        wrongOwner,
        WORKFLOW_OWNER
      )
    );
    _callOnReport(FORWARDER, WORKFLOW_ID, WORKFLOW_NAME, wrongOwner, address(hub1), daiAssetId);
  }

  function test_onReport_revertsWith_InvalidWorkflowName() public {
    _setupHappyPath(daiAssetId, 1);

    bytes10 wrongName = bytes10('wrong-name');
    vm.expectRevert(
      abi.encodeWithSelector(
        IFeeSharesMinter.InvalidWorkflowName.selector,
        wrongName,
        WORKFLOW_NAME
      )
    );
    _callOnReport(FORWARDER, WORKFLOW_ID, wrongName, WORKFLOW_OWNER, address(hub1), daiAssetId);
  }

  function test_onReport_success() public {
    _performAndAssertSuccess({
      addAmount: 1000e18,
      drawAmount: 900e18,
      skipTime: 365 days,
      minAccruedFeesPercent: 10
    });
  }

  function test_fuzz_onReport_success(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint16 minAccruedFeesPercent
  ) public {
    addAmount = bound(addAmount, 100e18, 1e26);
    drawAmount = bound(drawAmount, addAmount / 2, (addAmount * 9) / 10);
    skipTime = bound(skipTime, 365 days, MAX_SKIP_TIME);
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 1, 10).toUint16();

    _performAndAssertSuccess(addAmount, drawAmount, skipTime, minAccruedFeesPercent);
  }

  function test_canMint_returnsTrue_whenAllConditionsMet() public {
    _setupHappyPath(daiAssetId, 1);
    _assertCanMint(address(hub1), daiAssetId);
  }

  function test_canMint_returnsFalse_unconfigured() public view {
    // No prior setConfig — the threshold defaults to 0.
    assertEq(minter.getConfig(address(hub1), daiAssetId), 0);
    _assertCannotMint(address(hub1), daiAssetId);
  }

  function test_canMint_returnsFalse_disabledByZeroConfig() public {
    _setupHappyPath(daiAssetId, 1);

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 0);

    _assertCannotMint(address(hub1), daiAssetId);
  }

  function test_canMint_returnsFalse_noAddedAssets() public {
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 1);

    assertEq(hub1.getAddedAssets(daiAssetId), 0);
    _assertCannotMint(address(hub1), daiAssetId);
  }

  function test_canMint_returnsFalse_ratioBelowThreshold() public {
    _setupHappyPath(daiAssetId, 1);

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 50_00);

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertLt(
      fees,
      hub1.getAddedAssets(daiAssetId).percentMulDown(50_00),
      'fees must be below threshold'
    );
    _assertCannotMint(address(hub1), daiAssetId);
  }

  function test_canMint_returnsFalse_sharesRoundToZero() public {
    // Tiny add/draw so the first mint inflates the exchange rate enough that
    // subsequent fees round to zero shares.
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 1);
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 300 wei,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 200 wei,
      skipTime: MAX_SKIP_TIME - 110 days
    });
    _assertCanMint(address(hub1), daiAssetId);

    _callOnReportDefault(address(hub1), daiAssetId);
    skip(110 days);

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, 0, 'fees must accrue');
    assertEq(hub1.previewAddByAssets(daiAssetId, fees), 0, 'shares must round to zero');
    _assertCannotMint(address(hub1), daiAssetId);
  }

  function test_onReport_revertsWith_ConditionsNotMet_noFees() public {
    _setupHappyPath(daiAssetId, 1);

    _callOnReportDefault(address(hub1), daiAssetId);
    assertEq(hub1.getAssetAccruedFees(daiAssetId), 0, 'Fees should be zero');

    _assertCannotMint(address(hub1), daiAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    _callOnReportDefault(address(hub1), daiAssetId);
  }

  function test_onReport_revertsWith_ConditionsNotMet_noAddedAssets() public {
    _setupHappyPath(daiAssetId, 1);

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), wethAssetId, 1);
    assertEq(hub1.getAddedAssets(wethAssetId), 0, 'Total added assets should be zero');

    _assertCannotMint(address(hub1), wethAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    _callOnReportDefault(address(hub1), wethAssetId);
  }

  function test_onReport_revertsWith_ConditionsNotMet_percentThresholdNotMet_withMinShares()
    public
  {
    _setupHappyPath(daiAssetId, 1);

    uint16 highThreshold = 50_00;
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, highThreshold);

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(hub1.previewAddByAssets(daiAssetId, fees), 0, 'At least 1 share would be minted');
    assertLt(
      fees,
      hub1.getAddedAssets(daiAssetId).percentMulDown(highThreshold),
      'Fees must be < threshold of total'
    );

    _assertCannotMint(address(hub1), daiAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    _callOnReportDefault(address(hub1), daiAssetId);
  }

  function test_fuzz_onReport_revertsWith_ConditionsNotMet_thresholdAboveRatio(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint16 setupPercent,
    uint16 newThreshold
  ) public {
    addAmount = bound(addAmount, 100e18, 1e26);
    drawAmount = bound(drawAmount, addAmount / 2, (addAmount * 9) / 10);
    skipTime = bound(skipTime, 365 days, MAX_SKIP_TIME);
    setupPercent = bound(setupPercent, 1, 10).toUint16();

    _setupHappyPath(daiAssetId, setupPercent, addAmount, drawAmount, skipTime);

    uint256 currentRatio = hub1.getAssetAccruedFees(daiAssetId).percentDivDown(
      hub1.getAddedAssets(daiAssetId)
    );
    vm.assume(currentRatio < PercentageMath.PERCENTAGE_FACTOR);
    newThreshold = bound(newThreshold, currentRatio + 1, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, newThreshold);

    _assertCannotMint(address(hub1), daiAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    _callOnReportDefault(address(hub1), daiAssetId);
  }

  function test_onReport_revertsWith_ConditionsNotMet_MinShareNotMet_nonzeroFees() public {
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 1);
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 300 wei,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 200 wei,
      skipTime: MAX_SKIP_TIME - 110 days
    });
    _assertCanMint(address(hub1), daiAssetId);

    // Single change: mint to inflate exchange rate, then skip a short period so the
    // newly-accrued fees round to zero shares
    _callOnReportDefault(address(hub1), daiAssetId);
    skip(110 days);

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, 0, 'Fees must be nonzero');
    assertEq(hub1.previewAddByAssets(daiAssetId, fees), 0, 'Shares must round to zero');

    _assertCannotMint(address(hub1), daiAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    _callOnReportDefault(address(hub1), daiAssetId);
  }

  function test_rescueToken() public {
    uint256 amount = 1000e18;

    MockERC20 token = new MockERC20();
    token.mint(address(minter), amount);

    assertEq(token.balanceOf(address(minter)), amount, 'Minter should have tokens');

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    minter.rescueToken(address(token), bob, amount);

    vm.prank(ADMIN);
    minter.rescueToken(address(token), ADMIN, amount);

    assertEq(token.balanceOf(address(minter)), 0, 'Minter should be empty');
    assertEq(token.balanceOf(ADMIN), amount, 'Admin should have tokens');
  }

  function test_transferOwnership_2Step() public {
    address newOwner = makeAddr('newOwner');

    vm.prank(ADMIN);
    minter.transferOwnership(newOwner);

    assertEq(minter.owner(), ADMIN, 'Owner should still be ADMIN');
    assertEq(minter.pendingOwner(), newOwner, 'Pending owner should be newOwner');

    vm.prank(newOwner);
    minter.acceptOwnership();

    assertEq(minter.owner(), newOwner, 'Owner should now be newOwner');
    assertEq(minter.pendingOwner(), address(0), 'Pending owner should be cleared');
  }

  function _setupHappyPath(uint256 assetId, uint16 minAccruedFeesPercent) internal {
    _setupHappyPath(assetId, minAccruedFeesPercent, 1000e18, 900e18, 365 days);
  }

  function _setupHappyPath(
    uint256 assetId,
    uint16 minAccruedFeesPercent,
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime
  ) internal {
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), assetId, minAccruedFeesPercent);
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: assetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: addAmount,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });
    _assertCanMint(address(hub1), assetId);
  }

  function _performAndAssertSuccess(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint16 minAccruedFeesPercent
  ) internal {
    _setupHappyPath(daiAssetId, minAccruedFeesPercent, addAmount, drawAmount, skipTime);

    address feeReceiver = _getFeeReceiver(hub1, daiAssetId);
    uint256 sharesBefore = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    uint256 expectedMintedShares = hub1.previewAddByAssets(
      daiAssetId,
      hub1.getAssetAccruedFees(daiAssetId)
    );

    vm.expectCall(address(hub1), abi.encodeCall(IHub.mintFeeShares, (daiAssetId)));
    _callOnReportDefault(address(hub1), daiAssetId);

    uint256 sharesAfter = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    assertEq(sharesAfter - sharesBefore, expectedMintedShares, 'fee shares minted to receiver');
    _assertCannotMint(address(hub1), daiAssetId);
  }

  function _defaultWorkflowConfig() internal view returns (IFeeSharesMinter.WorkflowConfig memory) {
    return
      IFeeSharesMinter.WorkflowConfig({
        forwarder: FORWARDER,
        owner: WORKFLOW_OWNER,
        name: WORKFLOW_NAME,
        isActive: true
      });
  }

  function _buildMetadata(
    bytes32 workflowId,
    bytes10 workflowName,
    address workflowOwner
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(workflowId, workflowName, workflowOwner);
  }

  function _callOnReport(
    address caller,
    bytes32 workflowId,
    bytes10 workflowName,
    address workflowOwner,
    address hub,
    uint256 assetId
  ) internal {
    bytes memory metadata = _buildMetadata(workflowId, workflowName, workflowOwner);
    bytes memory report = abi.encode(hub, assetId);
    vm.prank(caller);
    minter.onReport(metadata, report);
  }

  function _callOnReportDefault(address hub, uint256 assetId) internal {
    _callOnReport(FORWARDER, WORKFLOW_ID, WORKFLOW_NAME, WORKFLOW_OWNER, hub, assetId);
  }

  function _assertCanMint(address hub, uint256 assetId) internal view {
    assertTrue(minter.canMint(hub, assetId), 'canMint should be true');
  }

  function _assertCannotMint(address hub, uint256 assetId) internal view {
    assertFalse(minter.canMint(hub, assetId), 'canMint should be false');
  }
}
