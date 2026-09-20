// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

contract FeeSharesMinterEngineTest is BaseConfigEngineTest {
  FeeSharesMinter internal minter;

  bytes32 internal constant WORKFLOW_ID = keccak256('fee-minter:test');
  bytes32 internal constant WORKFLOW_ID_2 = keccak256('fee-minter:test-2');
  bytes10 internal constant WORKFLOW_NAME = bytes10('fee-minter');

  function setUp() public override {
    super.setUp();
    _seedFullEnvironment();
    minter = _deployFeeSharesMinter(address(engine));
  }

  function test_executeFeeSharesMinterConfigs_setsValue() public {
    uint256 assetId = _getAssetId(0, TOKEN_WETH);

    vm.expectCall(
      address(minter),
      abi.encodeCall(IFeeSharesMinter.setConfig, (address(hub1()), assetId, 1_25))
    );

    vm.expectEmit(address(minter));
    emit IFeeSharesMinter.ConfigUpdated(address(hub1()), assetId, 1_25);

    engine.executeFeeSharesMinterConfigs(
      _toFeeSharesMinterConfigArray(_buildConfig(assetId, 1_25))
    );

    assertEq(minter.getConfig(address(hub1()), assetId), 1_25);
  }

  function test_executeFeeSharesMinterConfigs_zeroDisables() public {
    uint256 assetId = _getAssetId(0, TOKEN_DAI);

    engine.executeFeeSharesMinterConfigs(
      _toFeeSharesMinterConfigArray(_buildConfig(assetId, 5_00))
    );
    assertEq(minter.getConfig(address(hub1()), assetId), 5_00);

    engine.executeFeeSharesMinterConfigs(_toFeeSharesMinterConfigArray(_buildConfig(assetId, 0)));
    assertEq(minter.getConfig(address(hub1()), assetId), 0);
  }

  function test_executeFeeSharesMinterConfigs_multiple() public {
    IAaveV4ConfigEngine.FeeSharesMinterConfig[]
      memory configs = new IAaveV4ConfigEngine.FeeSharesMinterConfig[](3);
    configs[0] = _buildConfig(_getAssetId(0, TOKEN_WETH), 1_00);
    configs[1] = _buildConfig(_getAssetId(0, TOKEN_USDX), 2_00);
    configs[2] = _buildConfig(_getAssetId(0, TOKEN_DAI), 3_00);

    engine.executeFeeSharesMinterConfigs(configs);

    assertEq(minter.getConfig(address(hub1()), _getAssetId(0, TOKEN_WETH)), 1_00);
    assertEq(minter.getConfig(address(hub1()), _getAssetId(0, TOKEN_USDX)), 2_00);
    assertEq(minter.getConfig(address(hub1()), _getAssetId(0, TOKEN_DAI)), 3_00);
    assertEq(minter.getConfig(address(hub1()), _getAssetId(0, TOKEN_WBTC)), 0);
  }

  function test_executeFeeSharesMinterConfigs_acrossHubs() public {
    IAaveV4ConfigEngine.FeeSharesMinterConfig[]
      memory configs = new IAaveV4ConfigEngine.FeeSharesMinterConfig[](2);
    configs[0] = IAaveV4ConfigEngine.FeeSharesMinterConfig({
      feeSharesMinter: address(minter),
      hub: address(hub1()),
      assetId: _getAssetId(0, TOKEN_WETH),
      minAccruedFeesPercent: 1_00
    });
    configs[1] = IAaveV4ConfigEngine.FeeSharesMinterConfig({
      feeSharesMinter: address(minter),
      hub: address(hub2()),
      assetId: _getAssetId(1, TOKEN_WETH),
      minAccruedFeesPercent: 4_00
    });

    engine.executeFeeSharesMinterConfigs(configs);

    assertEq(minter.getConfig(address(hub1()), _getAssetId(0, TOKEN_WETH)), 1_00);
    assertEq(minter.getConfig(address(hub2()), _getAssetId(1, TOKEN_WETH)), 4_00);
  }

  function test_executeFeeSharesMinterConfigs_emptyArray_noOp() public {
    vm.recordLogs();
    engine.executeFeeSharesMinterConfigs(new IAaveV4ConfigEngine.FeeSharesMinterConfig[](0));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_executeFeeSharesMinterConfigs_revertsWith_unauthorized() public {
    FeeSharesMinter externalMinter = new FeeSharesMinter(ADMIN);

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(engine))
    );
    engine.executeFeeSharesMinterConfigs(
      _toFeeSharesMinterConfigArray(
        IAaveV4ConfigEngine.FeeSharesMinterConfig({
          feeSharesMinter: address(externalMinter),
          hub: address(hub1()),
          assetId: _getAssetId(0, TOKEN_WETH),
          minAccruedFeesPercent: 1_00
        })
      )
    );
  }

  function test_executeFeeSharesMinterConfigs_revertsWith_invalidPercent() public {
    uint16 invalid = uint16(PercentageMath.PERCENTAGE_FACTOR) + 1;
    vm.expectRevert(abi.encodeWithSelector(IFeeSharesMinter.InvalidConfig.selector, invalid));
    engine.executeFeeSharesMinterConfigs(
      _toFeeSharesMinterConfigArray(_buildConfig(_getAssetId(0, TOKEN_WETH), invalid))
    );
  }

  function test_executeFeeSharesMinterConfigs_revertsWith_assetNotListed() public {
    uint256 invalidAssetId = hub1().getAssetCount();

    vm.expectRevert(IHub.AssetNotListed.selector);
    engine.executeFeeSharesMinterConfigs(
      _toFeeSharesMinterConfigArray(_buildConfig(invalidAssetId, 1_00))
    );
  }

  function test_fuzz_executeFeeSharesMinterConfigs(uint16 minAccruedFeesPercent) public {
    minAccruedFeesPercent = uint16(
      bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
    );
    uint256 assetId = _getAssetId(0, TOKEN_WETH);

    engine.executeFeeSharesMinterConfigs(
      _toFeeSharesMinterConfigArray(_buildConfig(assetId, minAccruedFeesPercent))
    );

    assertEq(minter.getConfig(address(hub1()), assetId), minAccruedFeesPercent);
  }

  function test_fuzz_executeFeeSharesMinterConfigs_revertsWith_invalidPercent(
    uint16 minAccruedFeesPercent
  ) public {
    minAccruedFeesPercent = uint16(
      bound(minAccruedFeesPercent, PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IFeeSharesMinter.InvalidConfig.selector, minAccruedFeesPercent)
    );
    engine.executeFeeSharesMinterConfigs(
      _toFeeSharesMinterConfigArray(_buildConfig(_getAssetId(0, TOKEN_WETH), minAccruedFeesPercent))
    );
  }

  function test_executeFeeSharesMinterHubConfigs_setsAllAssetsInHub() public {
    uint256 assetCount = hub1().getAssetCount();
    assertGt(assetCount, 0, 'preflight');

    for (uint256 i; i < assetCount; ++i) {
      vm.expectEmit(address(minter));
      emit IFeeSharesMinter.ConfigUpdated(address(hub1()), i, 2_50);
    }

    engine.executeFeeSharesMinterHubConfigs(
      _toFeeSharesMinterHubConfigArray(_buildHubConfig(address(hub1()), 2_50))
    );

    for (uint256 i; i < assetCount; ++i) {
      assertEq(minter.getConfig(address(hub1()), i), 2_50);
    }
  }

  function test_executeFeeSharesMinterHubConfigs_overwritesExisting() public {
    engine.executeFeeSharesMinterConfigs(
      _toFeeSharesMinterConfigArray(_buildConfig(_getAssetId(0, TOKEN_WETH), 9_00))
    );
    assertEq(minter.getConfig(address(hub1()), _getAssetId(0, TOKEN_WETH)), 9_00);

    engine.executeFeeSharesMinterHubConfigs(
      _toFeeSharesMinterHubConfigArray(_buildHubConfig(address(hub1()), 2_50))
    );

    uint256 assetCount = hub1().getAssetCount();
    for (uint256 i; i < assetCount; ++i) {
      assertEq(minter.getConfig(address(hub1()), i), 2_50);
    }
  }

  function test_executeFeeSharesMinterHubConfigs_isolatesOtherHubs() public {
    engine.executeFeeSharesMinterHubConfigs(
      _toFeeSharesMinterHubConfigArray(_buildHubConfig(address(hub1()), 2_50))
    );

    uint256 hub2AssetCount = hub2().getAssetCount();
    for (uint256 i; i < hub2AssetCount; ++i) {
      assertEq(minter.getConfig(address(hub2()), i), 0);
    }
  }

  function test_executeFeeSharesMinterHubConfigs_multipleHubs() public {
    IAaveV4ConfigEngine.FeeSharesMinterHubConfig[]
      memory configs = new IAaveV4ConfigEngine.FeeSharesMinterHubConfig[](2);
    configs[0] = _buildHubConfig(address(hub1()), 1_00);
    configs[1] = _buildHubConfig(address(hub2()), 5_00);

    engine.executeFeeSharesMinterHubConfigs(configs);

    uint256 hub1AssetCount = hub1().getAssetCount();
    for (uint256 i; i < hub1AssetCount; ++i) {
      assertEq(minter.getConfig(address(hub1()), i), 1_00);
    }
    uint256 hub2AssetCount = hub2().getAssetCount();
    for (uint256 i; i < hub2AssetCount; ++i) {
      assertEq(minter.getConfig(address(hub2()), i), 5_00);
    }
  }

  function test_executeFeeSharesMinterHubConfigs_emptyHub_noOp() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();
    newSpoke; // unused

    address freshHub = makeAddr('fresh-hub');
    vm.mockCall(
      freshHub,
      abi.encodeWithSelector(IHub.getAssetCount.selector),
      abi.encode(uint256(0))
    );

    vm.recordLogs();
    engine.executeFeeSharesMinterHubConfigs(
      _toFeeSharesMinterHubConfigArray(_buildHubConfig(freshHub, 1_00))
    );
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_executeFeeSharesMinterHubConfigs_emitsPerAsset() public {
    vm.recordLogs();
    engine.executeFeeSharesMinterHubConfigs(
      _toFeeSharesMinterHubConfigArray(_buildHubConfig(address(hub1()), 7_50))
    );
    assertEq(vm.getRecordedLogs().length, hub1().getAssetCount());
  }

  function test_executeFeeSharesMinterHubConfigs_revertsWith_invalidPercent() public {
    uint16 invalid = uint16(PercentageMath.PERCENTAGE_FACTOR) + 1;
    vm.expectRevert(abi.encodeWithSelector(IFeeSharesMinter.InvalidConfig.selector, invalid));
    engine.executeFeeSharesMinterHubConfigs(
      _toFeeSharesMinterHubConfigArray(_buildHubConfig(address(hub1()), invalid))
    );
  }

  function test_executeFeeSharesMinterHubConfigs_revertsWith_unauthorized() public {
    FeeSharesMinter externalMinter = new FeeSharesMinter(ADMIN);

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(engine))
    );
    engine.executeFeeSharesMinterHubConfigs(
      _toFeeSharesMinterHubConfigArray(
        IAaveV4ConfigEngine.FeeSharesMinterHubConfig({
          feeSharesMinter: address(externalMinter),
          hub: address(hub1()),
          minAccruedFeesPercent: 1_00
        })
      )
    );
  }

  function test_fuzz_executeFeeSharesMinterHubConfigs(uint16 minAccruedFeesPercent) public {
    minAccruedFeesPercent = uint16(
      bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
    );

    engine.executeFeeSharesMinterHubConfigs(
      _toFeeSharesMinterHubConfigArray(_buildHubConfig(address(hub1()), minAccruedFeesPercent))
    );

    uint256 assetCount = hub1().getAssetCount();
    for (uint256 i; i < assetCount; ++i) {
      assertEq(minter.getConfig(address(hub1()), i), minAccruedFeesPercent);
    }
  }

  function test_executeFeeSharesMinterWorkflowConfigs_setsConfig() public {
    IFeeSharesMinter.WorkflowConfig memory cfg = _defaultWorkflowConfig();

    vm.expectCall(
      address(minter),
      abi.encodeCall(IFeeSharesMinter.setWorkflowConfig, (WORKFLOW_ID, cfg))
    );

    vm.expectEmit(address(minter));
    emit IFeeSharesMinter.WorkflowConfigUpdated(
      WORKFLOW_ID,
      cfg.forwarder,
      cfg.owner,
      cfg.name,
      cfg.isActive
    );

    engine.executeFeeSharesMinterWorkflowConfigs(
      _toFeeSharesMinterWorkflowConfigArray(_buildWorkflowConfig(WORKFLOW_ID, cfg))
    );

    IFeeSharesMinter.WorkflowConfig memory stored = minter.getWorkflowConfig(WORKFLOW_ID);
    assertEq(stored.forwarder, cfg.forwarder);
    assertEq(stored.owner, cfg.owner);
    assertEq(stored.name, cfg.name);
    assertTrue(stored.isActive);
  }

  function test_executeFeeSharesMinterWorkflowConfigs_multiple() public {
    IFeeSharesMinter.WorkflowConfig memory cfg1 = _defaultWorkflowConfig();
    IFeeSharesMinter.WorkflowConfig memory cfg2 = IFeeSharesMinter.WorkflowConfig({
      forwarder: makeAddr('forwarder-2'),
      owner: makeAddr('owner-2'),
      name: bytes10('second-wf'),
      isActive: true
    });

    IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig[]
      memory configs = new IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig[](2);
    configs[0] = _buildWorkflowConfig(WORKFLOW_ID, cfg1);
    configs[1] = _buildWorkflowConfig(WORKFLOW_ID_2, cfg2);

    engine.executeFeeSharesMinterWorkflowConfigs(configs);

    IFeeSharesMinter.WorkflowConfig memory stored1 = minter.getWorkflowConfig(WORKFLOW_ID);
    IFeeSharesMinter.WorkflowConfig memory stored2 = minter.getWorkflowConfig(WORKFLOW_ID_2);

    assertEq(stored1.forwarder, cfg1.forwarder);
    assertEq(stored1.owner, cfg1.owner);
    assertEq(stored1.name, cfg1.name);
    assertEq(stored2.forwarder, cfg2.forwarder);
    assertEq(stored2.owner, cfg2.owner);
    assertEq(stored2.name, cfg2.name);
  }

  function test_executeFeeSharesMinterWorkflowConfigs_overwrite() public {
    IFeeSharesMinter.WorkflowConfig memory cfg = _defaultWorkflowConfig();
    engine.executeFeeSharesMinterWorkflowConfigs(
      _toFeeSharesMinterWorkflowConfigArray(_buildWorkflowConfig(WORKFLOW_ID, cfg))
    );

    IFeeSharesMinter.WorkflowConfig memory cfg2 = IFeeSharesMinter.WorkflowConfig({
      forwarder: makeAddr('updated-forwarder'),
      owner: makeAddr('updated-owner'),
      name: bytes10('updated-wf'),
      isActive: false
    });
    engine.executeFeeSharesMinterWorkflowConfigs(
      _toFeeSharesMinterWorkflowConfigArray(_buildWorkflowConfig(WORKFLOW_ID, cfg2))
    );

    IFeeSharesMinter.WorkflowConfig memory stored = minter.getWorkflowConfig(WORKFLOW_ID);
    assertEq(stored.forwarder, cfg2.forwarder);
    assertEq(stored.owner, cfg2.owner);
    assertEq(stored.name, cfg2.name);
    assertFalse(stored.isActive);
  }

  function test_executeFeeSharesMinterWorkflowConfigs_canDeactivate() public {
    IFeeSharesMinter.WorkflowConfig memory cfg = _defaultWorkflowConfig();
    engine.executeFeeSharesMinterWorkflowConfigs(
      _toFeeSharesMinterWorkflowConfigArray(_buildWorkflowConfig(WORKFLOW_ID, cfg))
    );

    cfg.isActive = false;
    engine.executeFeeSharesMinterWorkflowConfigs(
      _toFeeSharesMinterWorkflowConfigArray(_buildWorkflowConfig(WORKFLOW_ID, cfg))
    );

    IFeeSharesMinter.WorkflowConfig memory stored = minter.getWorkflowConfig(WORKFLOW_ID);
    assertFalse(stored.isActive);
  }

  function test_executeFeeSharesMinterWorkflowConfigs_emptyArray_noOp() public {
    vm.recordLogs();
    engine.executeFeeSharesMinterWorkflowConfigs(
      new IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig[](0)
    );
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_executeFeeSharesMinterWorkflowConfigs_revertsWith_unauthorized() public {
    FeeSharesMinter externalMinter = new FeeSharesMinter(ADMIN);

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(engine))
    );
    engine.executeFeeSharesMinterWorkflowConfigs(
      _toFeeSharesMinterWorkflowConfigArray(
        IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig({
          feeSharesMinter: address(externalMinter),
          workflowId: WORKFLOW_ID,
          config: _defaultWorkflowConfig()
        })
      )
    );
  }

  function test_fuzz_executeFeeSharesMinterWorkflowConfigs(
    bytes32 workflowId,
    address forwarder,
    address owner,
    bytes10 name,
    bool isActive
  ) public {
    IFeeSharesMinter.WorkflowConfig memory cfg = IFeeSharesMinter.WorkflowConfig({
      forwarder: forwarder,
      owner: owner,
      name: name,
      isActive: isActive
    });

    engine.executeFeeSharesMinterWorkflowConfigs(
      _toFeeSharesMinterWorkflowConfigArray(_buildWorkflowConfig(workflowId, cfg))
    );

    IFeeSharesMinter.WorkflowConfig memory stored = minter.getWorkflowConfig(workflowId);
    assertEq(stored.forwarder, forwarder);
    assertEq(stored.owner, owner);
    assertEq(stored.name, name);
    assertEq(stored.isActive, isActive);
  }

  function _buildConfig(
    uint256 assetId,
    uint16 minAccruedFeesPercent
  ) internal view returns (IAaveV4ConfigEngine.FeeSharesMinterConfig memory) {
    return
      IAaveV4ConfigEngine.FeeSharesMinterConfig({
        feeSharesMinter: address(minter),
        hub: address(hub1()),
        assetId: assetId,
        minAccruedFeesPercent: minAccruedFeesPercent
      });
  }

  function _buildHubConfig(
    address hub,
    uint16 minAccruedFeesPercent
  ) internal view returns (IAaveV4ConfigEngine.FeeSharesMinterHubConfig memory) {
    return
      IAaveV4ConfigEngine.FeeSharesMinterHubConfig({
        feeSharesMinter: address(minter),
        hub: hub,
        minAccruedFeesPercent: minAccruedFeesPercent
      });
  }

  function _buildWorkflowConfig(
    bytes32 workflowId,
    IFeeSharesMinter.WorkflowConfig memory cfg
  ) internal view returns (IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig memory) {
    return
      IAaveV4ConfigEngine.FeeSharesMinterWorkflowConfig({
        feeSharesMinter: address(minter),
        workflowId: workflowId,
        config: cfg
      });
  }
}
