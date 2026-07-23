// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

/// forge-config: default.isolate = true
contract SpokeOperations_Gas_Tests is Base {
  string internal NAMESPACE = 'Spoke.Operations';
  ReserveIds internal reserveId;
  ISpoke internal spoke;

  function setUp() public virtual override {
    super.setUp();
    spoke = spoke1;
    reserveId = _getReserveIds(spoke);
    _seed();
  }

  function _positionSalt() internal pure virtual returns (bytes32) {
    return bytes32(0);
  }

  function _opSupply(uint256 reserveId_, uint256 amount, address onBehalfOf) internal virtual {
    spoke.supply(reserveId_, amount, onBehalfOf);
  }

  function _opSetUsingAsCollateral(
    uint256 reserveId_,
    bool usingAsCollateral,
    address onBehalfOf
  ) internal virtual {
    spoke.setUsingAsCollateral(reserveId_, usingAsCollateral, onBehalfOf);
  }

  function _opWithdraw(uint256 reserveId_, uint256 amount, address onBehalfOf) internal virtual {
    spoke.withdraw(reserveId_, amount, onBehalfOf);
  }

  function _opBorrow(uint256 reserveId_, uint256 amount, address onBehalfOf) internal virtual {
    spoke.borrow(reserveId_, amount, onBehalfOf);
  }

  function _opRepay(uint256 reserveId_, uint256 amount, address onBehalfOf) internal virtual {
    spoke.repay(reserveId_, amount, onBehalfOf);
  }

  function _opLiquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) internal virtual {
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, debtToCover, receiveShares);
  }

  function _opUpdateUserRiskPremium(address onBehalfOf) internal virtual {
    spoke.updateUserRiskPremium(onBehalfOf);
  }

  function _opUpdateUserDynamicConfig(address onBehalfOf) internal virtual {
    spoke.updateUserDynamicConfig(onBehalfOf);
  }

  function test_supply() public {
    vm.startPrank(alice);
    _opSupply(reserveId.usdx, 1000e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'supply: 0 borrows, collateral disabled');

    _opSupply(reserveId.usdx, 1000e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'supply: second action, same reserve');

    _opSupply(reserveId.weth, 1000e18, alice);

    _opSetUsingAsCollateral(reserveId.weth, true, alice);
    _opSupply(reserveId.weth, 1e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'supply: 0 borrows, collateral enabled');
    vm.stopPrank();
  }

  function test_usingAsCollateral() public {
    vm.prank(bob);
    _opSupply(reserveId.dai, 1000e18, bob);

    vm.startPrank(alice);
    _opSetUsingAsCollateral(reserveId.usdx, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 0 borrows, enable');

    _opSupply(reserveId.usdx, 10000e6, alice);
    _opBorrow(reserveId.dai, 100e18, alice);
    skip(100);

    _opSetUsingAsCollateral(reserveId.weth, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 1 borrow, enable');

    _opSetUsingAsCollateral(reserveId.weth, false, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 1 borrow, disable');

    _opBorrow(reserveId.weth, 0.1e18, alice);
    skip(100);

    _opSetUsingAsCollateral(reserveId.wbtc, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 2 borrows, enable');

    _opSetUsingAsCollateral(reserveId.wbtc, false, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 2 borrows, disable');
    vm.stopPrank();
  }

  function test_withdraw() public {
    vm.startPrank(alice);
    _opSupply(reserveId.usdx, 100e6, alice);
    _opSetUsingAsCollateral(reserveId.usdx, true, alice);

    _opWithdraw(reserveId.usdx, 1e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: 0 borrows, partial');

    skip(100);

    _opWithdraw(reserveId.usdx, UINT256_MAX, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: 0 borrows, full');

    _opSupply(reserveId.usdx, 10000e6, alice);
    _opBorrow(reserveId.dai, 1e18, alice);
    skip(100);

    _opWithdraw(reserveId.usdx, 1e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: 1 borrow, partial');
    _opBorrow(reserveId.weth, 1e18, alice);

    _opWithdraw(reserveId.usdx, 1e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: 2 borrows, partial');
    _opSupply(reserveId.weth, 1000e18, alice);

    _opWithdraw(reserveId.weth, UINT256_MAX, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: non collateral');
    vm.stopPrank();
  }

  function test_borrow() public {
    vm.startPrank(bob);
    _opSupply(reserveId.dai, 1000e18, bob);
    _opSetUsingAsCollateral(reserveId.dai, true, bob);
    _opBorrow(reserveId.dai, 500e18, bob);
    skip(100);
    _opBorrow(reserveId.dai, 1e18, bob);
    vm.stopPrank();

    skip(100);

    vm.startPrank(alice);
    _opSupply(reserveId.usdx, 1000e6, alice);
    _opSetUsingAsCollateral(reserveId.usdx, true, alice);

    _opBorrow(reserveId.dai, 500e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'borrow: first');

    skip(100);

    _opBorrow(reserveId.dai, 1e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'borrow: second action, same reserve');
    vm.stopPrank();
  }

  function test_repay() public {
    vm.prank(bob);
    _opSupply(reserveId.dai, 1000e18, bob);

    vm.startPrank(alice);
    _opSupply(reserveId.usdx, 1000e6, alice);
    _opSetUsingAsCollateral(reserveId.usdx, true, alice);
    _opBorrow(reserveId.dai, 500e18, alice);

    _opRepay(reserveId.dai, 200e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'repay: partial');

    _opRepay(reserveId.dai, UINT256_MAX, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'repay: full');
    vm.stopPrank();
  }

  function test_liquidation_partial() public {
    _liquidationSetup(85_00);

    vm.startPrank(bob);
    _opLiquidationCall(reserveId.usdx, reserveId.dai, alice, 100_000e18, false);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall: partial');
    vm.stopPrank();
  }

  function test_liquidation_full() public {
    _liquidationSetup(85_00);

    vm.startPrank(bob);
    _opLiquidationCall(reserveId.usdx, reserveId.dai, alice, UINT256_MAX, false);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall: full');

    vm.stopPrank();
  }

  function test_liquidation_receiveShares_partial() public {
    _liquidationSetup(85_00);

    vm.startPrank(bob);
    _opLiquidationCall(reserveId.usdx, reserveId.dai, alice, 100_000e18, true);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall (receiveShares): partial');

    vm.stopPrank();
  }

  function test_liquidation_receiveShares_full() public {
    _liquidationSetup(85_00);

    vm.startPrank(bob);
    _opLiquidationCall(reserveId.usdx, reserveId.dai, alice, UINT256_MAX, true);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall (receiveShares): full');

    vm.stopPrank();
  }

  function test_liquidation_reportDeficit_full() public {
    _liquidationSetup(45_00);

    vm.startPrank(bob);
    _opLiquidationCall(reserveId.usdx, reserveId.dai, alice, UINT256_MAX, false);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall (reportDeficit): full');

    vm.stopPrank();
  }

  function test_updateRiskPremium() public {
    vm.prank(bob);
    _opSupply(reserveId.dai, 1000e18, bob);

    vm.startPrank(alice);
    _opSupply(reserveId.usdx, 2000e6, alice);
    _opSetUsingAsCollateral(reserveId.usdx, true, alice);

    _opBorrow(reserveId.dai, 500e18, alice);
    skip(100);

    _opUpdateUserRiskPremium(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremium: 1 borrow');

    _opBorrow(reserveId.usdx, 500e6, alice);
    skip(100);

    _opUpdateUserRiskPremium(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremium: 2 borrows');
    vm.stopPrank();
  }

  function test_updateUserDynamicConfig() public {
    vm.startPrank(alice);
    _opSetUsingAsCollateral(reserveId.usdx, true, alice);
    _updateLiquidationFee(spoke, reserveId.usdx, 10_00);

    _opUpdateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfig: 1 collateral');

    _opSetUsingAsCollateral(reserveId.dai, true, alice);
    _updateLiquidationFee(spoke, reserveId.dai, 15_00);

    _opUpdateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfig: 2 collaterals');
    vm.stopPrank();
  }

  function test_multicall_ops() public virtual {
    vm.startPrank(bob);
    spoke.supply(reserveId.dai, 1000e18, bob);
    spoke.supply(reserveId.usdx, 1000e6, bob);
    spoke.supply(reserveId.wbtc, 1e18, bob);

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature(
      'supply(uint256,uint256,address)',
      reserveId.dai,
      1000e18,
      bob
    );
    calls[1] = abi.encodeWithSignature(
      'setUsingAsCollateral(uint256,bool,address)',
      reserveId.dai,
      true,
      bob
    );

    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'supply + enable collateral (multicall)');

    // supplyWithPermit (dai)
    tokenList.dai.approve(address(spoke), 0);
    EIP712Types.Permit memory permit = EIP712Types.Permit({
      owner: bob,
      spender: address(spoke),
      value: 1000e6,
      nonce: tokenList.dai.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, _getTypedDataHash(tokenList.dai, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (reserveId.dai, permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeWithSignature(
      'supply(uint256,uint256,address)',
      reserveId.dai,
      permit.value,
      permit.owner
    );
    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'permitReserve + supply (multicall)');

    spoke.borrow(reserveId.usdx, 500e6, bob);

    // repayWithPermit (usdx)
    tokenList.usdx.approve(address(spoke), 0);
    permit = EIP712Types.Permit({
      owner: bob,
      spender: address(spoke),
      value: 500e6,
      nonce: tokenList.usdx.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (v, r, s) = vm.sign(bobPk, _getTypedDataHash(tokenList.usdx, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (reserveId.usdx, permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeWithSignature(
      'repay(uint256,uint256,address)',
      reserveId.usdx,
      permit.value,
      permit.owner
    );
    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'permitReserve + repay (multicall)');

    // supplyWithPermitAndEnableCollateral (wbtc)
    calls = new bytes[](3);
    tokenList.wbtc.approve(address(spoke), 0);
    permit = EIP712Types.Permit({
      owner: bob,
      spender: address(spoke),
      value: 1000e6,
      nonce: tokenList.wbtc.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (v, r, s) = vm.sign(bobPk, _getTypedDataHash(tokenList.wbtc, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (reserveId.wbtc, permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeWithSignature(
      'supply(uint256,uint256,address)',
      reserveId.wbtc,
      permit.value,
      permit.owner
    );
    calls[2] = abi.encodeWithSignature(
      'setUsingAsCollateral(uint256,bool,address)',
      reserveId.wbtc,
      true,
      permit.owner
    );
    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'permitReserve + supply + enable collateral (multicall)');

    vm.stopPrank();
  }

  function test_setUserPositionManagersWithSig() public virtual {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    address positionManager = makeAddr('positionManager');
    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager({positionManager: positionManager, active: true});

    uint192 nonceKey = 100;
    vm.prank(user);
    spoke.useNonce(nonceKey);

    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(positionManager, true);

    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      onBehalfOf: user,
      updates: updates,
      nonce: spoke.nonces(user, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(spoke, p));
    bytes memory signature = abi.encodePacked(r, s, v);

    spoke.setUserPositionManagersWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setUserPositionManagersWithSig: enable');

    p.updates[0].approve = false;
    p.nonce = spoke.nonces(user, nonceKey);
    (v, r, s) = vm.sign(userPk, _getTypedDataHash(spoke, p));
    signature = abi.encodePacked(r, s, v);

    spoke.setUserPositionManagersWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setUserPositionManagersWithSig: disable');
  }

  function _seed() internal {
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(bob, address(hub1), 10000e18);
    hub1.add(daiAssetId, 10000e18);
    tokenList.weth.transferFrom(bob, address(hub1), 1000e18);
    hub1.add(wethAssetId, 1000e18);
    tokenList.usdx.transferFrom(bob, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);
    tokenList.wbtc.transferFrom(bob, address(hub1), 1000e8);
    hub1.add(wbtcAssetId, 1000e8);
    vm.stopPrank();
  }

  function _liquidationSetup(uint256 pricePercentage) internal {
    _updateMaxLiquidationBonus(spoke, _usdxReserveId(spoke), 105_00);
    _updateLiquidationFee(spoke, _usdxReserveId(spoke), 10_00);

    vm.prank(bob);
    spoke.supply(reserveId.dai, 1_000_000e18, bob);

    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1_000_000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    vm.stopPrank();

    ISpoke.UserAccountData memory userAccountData = _borrowToBeLiquidatableWithPriceChange(
      spoke,
      alice,
      reserveId.dai,
      reserveId.usdx,
      1.05e18,
      pricePercentage
    );

    skip(100);

    if (keccak256(bytes(NAMESPACE)) == keccak256(bytes('Spoke.Operations.ZeroRiskPremium'))) {
      assertEq(userAccountData.riskPremium, 0); // rp after borrow should be 0
    } else {
      assertGt(userAccountData.riskPremium, 0); // rp after borrow should be non zero
    }
  }
}

/// forge-config: default.isolate = true
contract SpokeOperations_ZeroRiskPremium_Gas_Tests is SpokeOperations_Gas_Tests {
  function setUp() public override {
    super.setUp();
    NAMESPACE = 'Spoke.Operations.ZeroRiskPremium';

    _updateCollateralRisk(spoke, reserveId.dai, 0);
    _updateCollateralRisk(spoke, reserveId.weth, 0);
    _updateCollateralRisk(spoke, reserveId.usdx, 0);
    _updateCollateralRisk(spoke, reserveId.wbtc, 0);
  }
}

/// forge-config: default.isolate = true
contract SpokeOperations_PositionSalt_Gas_Tests is SpokeOperations_Gas_Tests {
  bytes32 internal constant SALT = keccak256('position-salt');

  function setUp() public override {
    super.setUp();
    NAMESPACE = 'Spoke.Operations.PositionSalt';
  }

  function _positionSalt() internal pure override returns (bytes32) {
    return SALT;
  }

  function _opSupply(uint256 reserveId_, uint256 amount, address onBehalfOf) internal override {
    spoke.supply(reserveId_, amount, onBehalfOf, SALT);
  }

  function _opSetUsingAsCollateral(
    uint256 reserveId_,
    bool usingAsCollateral,
    address onBehalfOf
  ) internal override {
    spoke.setUsingAsCollateral(reserveId_, usingAsCollateral, onBehalfOf, SALT);
  }

  function _opWithdraw(uint256 reserveId_, uint256 amount, address onBehalfOf) internal override {
    spoke.withdraw(reserveId_, amount, onBehalfOf, SALT);
  }

  function _opBorrow(uint256 reserveId_, uint256 amount, address onBehalfOf) internal override {
    spoke.borrow(reserveId_, amount, onBehalfOf, SALT);
  }

  function _opRepay(uint256 reserveId_, uint256 amount, address onBehalfOf) internal override {
    spoke.repay(reserveId_, amount, onBehalfOf, SALT);
  }

  function _opLiquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) internal override {
    spoke.liquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      bytes32(0),
      SALT,
      debtToCover,
      receiveShares
    );
  }

  function _opUpdateUserRiskPremium(address onBehalfOf) internal override {
    spoke.updateUserRiskPremium(onBehalfOf, SALT);
  }

  function _opUpdateUserDynamicConfig(address onBehalfOf) internal override {
    spoke.updateUserDynamicConfig(onBehalfOf, SALT);
  }

  function test_multicall_ops() public override {
    vm.startPrank(alice);
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature(
      'supply(uint256,uint256,address,bytes32)',
      reserveId.usdx,
      1000e6,
      alice,
      SALT
    );
    calls[1] = abi.encodeWithSignature(
      'setUsingAsCollateral(uint256,bool,address,bytes32)',
      reserveId.usdx,
      true,
      alice,
      SALT
    );
    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'supply + enable collateral (multicall)');
    vm.stopPrank();
  }

  // position managers are not scoped by position salt
  function test_setUserPositionManagersWithSig() public override {}
}
