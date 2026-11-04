// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

/// forge-config: default.isolate = true
contract FeeSharesMinterOperations_Gas_Tests is Base {
  FeeSharesMinter internal minter;

  address internal FORWARDER;
  address internal WORKFLOW_OWNER;
  bytes10 internal constant WORKFLOW_NAME = bytes10('fee-minter');
  bytes32 internal constant WORKFLOW_ID = keccak256('FeeSharesMinter:gas');

  function setUp() public override {
    super.setUp();
    minter = new FeeSharesMinter(ADMIN);

    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_FEE_MINTER_ROLE, address(minter), 0);

    FORWARDER = makeAddr('forwarder');
    WORKFLOW_OWNER = makeAddr('workflow-owner');
  }

  function test_setConfig() public {
    vm.startPrank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 100);
    vm.snapshotGasLastCall('FeeSharesMinter.Operations', 'setConfig: cold');

    minter.setConfig(address(hub1), daiAssetId, 250);
    vm.snapshotGasLastCall('FeeSharesMinter.Operations', 'setConfig: warm');

    minter.setConfig(address(hub1), daiAssetId, 0);
    vm.snapshotGasLastCall('FeeSharesMinter.Operations', 'setConfig: disable');
    vm.stopPrank();
  }

  function test_setWorkflowConfig() public {
    IFeeSharesMinter.WorkflowConfig memory cfg = IFeeSharesMinter.WorkflowConfig({
      forwarder: FORWARDER,
      owner: WORKFLOW_OWNER,
      name: WORKFLOW_NAME,
      isActive: true
    });

    vm.startPrank(ADMIN);
    minter.setWorkflowConfig(WORKFLOW_ID, cfg);
    vm.snapshotGasLastCall('FeeSharesMinter.Operations', 'setWorkflowConfig: cold');

    cfg.forwarder = makeAddr('forwarder-2');
    minter.setWorkflowConfig(WORKFLOW_ID, cfg);
    vm.snapshotGasLastCall('FeeSharesMinter.Operations', 'setWorkflowConfig: warm');

    cfg.isActive = false;
    minter.setWorkflowConfig(WORKFLOW_ID, cfg);
    vm.snapshotGasLastCall('FeeSharesMinter.Operations', 'setWorkflowConfig: deactivate');
    vm.stopPrank();
  }

  function test_onReport() public {
    vm.startPrank(ADMIN);
    minter.setWorkflowConfig(
      WORKFLOW_ID,
      IFeeSharesMinter.WorkflowConfig({
        forwarder: FORWARDER,
        owner: WORKFLOW_OWNER,
        name: WORKFLOW_NAME,
        isActive: true
      })
    );
    minter.setConfig(address(hub1), daiAssetId, 10);
    vm.stopPrank();

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 900e18,
      skipTime: 365 days
    });

    bytes memory metadata = abi.encodePacked(WORKFLOW_ID, WORKFLOW_NAME, WORKFLOW_OWNER);
    bytes memory report = abi.encode(address(hub1), daiAssetId);

    address feeReceiver = _getFeeReceiver(hub1, daiAssetId);
    uint256 sharesBefore = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    uint256 expectedMintedShares = hub1.previewAddByAssets(
      daiAssetId,
      hub1.getAssetAccruedFees(daiAssetId)
    );
    assertGt(expectedMintedShares, 0, 'expected minted shares must be greater than 0');

    vm.prank(FORWARDER);
    minter.onReport(metadata, report);
    vm.snapshotGasLastCall('FeeSharesMinter.Operations', 'onReport');

    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, feeReceiver) - sharesBefore,
      expectedMintedShares,
      'fee shares minted to receiver'
    );
  }
}
