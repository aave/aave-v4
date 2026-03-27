// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/position-manager/ConfigPositionManager/ConfigPositionManager.Base.t.sol';

contract ConfigPositionManagerPermitTest is ConfigPositionManagerBaseTest {
  function test_eip712Domain() public {
    ConfigPositionManager instance = new ConfigPositionManager{salt: bytes32(vm.randomUint())}(
      vm.randomAddress()
    );
    (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    ) = IERC5267(address(instance)).eip712Domain();

    assertEq(fields, bytes1(0x0f));
    assertEq(name, 'ConfigPositionManager');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    ConfigPositionManager instance = new ConfigPositionManager{salt: bytes32(vm.randomUint())}(
      vm.randomAddress()
    );
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('ConfigPositionManager'),
        keccak256('1'),
        block.chainid,
        address(instance)
      )
    );
    assertEq(instance.DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  function test_setGlobalPermissionPermit_typeHash() public view {
    assertEq(
      positionManager.SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH(),
      vm.eip712HashType('SetGlobalPermissionPermit')
    );
    assertEq(
      positionManager.SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH(),
      keccak256(
        'SetGlobalPermissionPermit(address spoke,address delegator,address delegatee,bool status,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_setGlobalPermissionWithSig_fuzz(address delegatee, bool permission) public {
    vm.assume(delegatee != address(0));

    IConfigPositionManager.SetGlobalPermissionPermit memory p = _setGlobalPermissionPermitData(
      delegatee,
      alice,
      permission,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    ConfigPermissions expectedPermissions = emptyPermissions;

    if (permission) {
      expectedPermissions = ConfigPermissionsMap.setGlobalPermissions(permission);
      vm.expectEmit(address(positionManager));
      emit IConfigPositionManager.UpdateConfigPermissions(
        address(spoke1),
        alice,
        delegatee,
        emptyPermissions,
        expectedPermissions
      );
    }

    vm.prank(vm.randomAddress());
    positionManager.setGlobalPermissionWithSig(p, signature);

    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), delegatee, alice);
    assertEq(permissions.canSetUsingAsCollateral, permission);
    assertEq(permissions.canUpdateUserRiskPremium, permission);
    assertEq(permissions.canUpdateUserDynamicConfig, permission);
  }

  function test_setGlobalPermissionWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    IConfigPositionManager.SetGlobalPermissionPermit memory p = _setGlobalPermissionPermitData(
      vm.randomAddress(),
      alice,
      true,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.setGlobalPermissionWithSig(p, signature);
  }

  function test_setGlobalPermissionWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address delegator = vm.randomAddress();
    while (delegator == randomUser) delegator = vm.randomAddress();

    IConfigPositionManager.SetGlobalPermissionPermit memory p = _setGlobalPermissionPermitData(
      randomUser,
      delegator,
      true,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.setGlobalPermissionWithSig(p, signature);
  }

  function test_setGlobalPermissionWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    IConfigPositionManager.SetGlobalPermissionPermit memory p = _setGlobalPermissionPermitData(
      vm.randomAddress(),
      alice,
      true,
      _warpBeforeRandomDeadline()
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.delegator, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.delegator, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.delegator, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.setGlobalPermissionWithSig(p, signature);
  }

  function test_setGlobalPermissionWithSig_revertsWith_SpokeNotRegistered() public {
    IConfigPositionManager.SetGlobalPermissionPermit memory p = _setGlobalPermissionPermitData(
      bob,
      alice,
      true,
      _warpBeforeRandomDeadline()
    );
    p.spoke = address(spoke2);
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setGlobalPermissionWithSig(p, signature);
  }

  function test_setCanSetUsingAsCollateralPermissionPermit_typeHash() public view {
    assertEq(
      positionManager.SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH(),
      vm.eip712HashType('SetCanSetUsingAsCollateralPermissionPermit')
    );
    assertEq(
      positionManager.SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH(),
      keccak256(
        'SetCanSetUsingAsCollateralPermissionPermit(address spoke,address delegator,address delegatee,bool status,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_setCanSetUsingAsCollateralPermissionWithSig_fuzz(
    address delegatee,
    bool permission
  ) public {
    vm.assume(delegatee != address(0));

    IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit
      memory p = _setCanSetUsingAsCollateralPermissionPermitData(
        delegatee,
        alice,
        permission,
        _warpBeforeRandomDeadline()
      );
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.prank(vm.randomAddress());
    positionManager.setCanSetUsingAsCollateralPermissionWithSig(p, signature);

    assertEq(_canUpdateUsingAsCollateral(address(spoke1), delegatee, alice), permission);
  }

  function test_setCanSetUsingAsCollateralPermissionWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit
      memory p = _setCanSetUsingAsCollateralPermissionPermitData(
        vm.randomAddress(),
        alice,
        true,
        _warpAfterRandomDeadline()
      );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.setCanSetUsingAsCollateralPermissionWithSig(p, signature);
  }

  function test_setCanSetUsingAsCollateralPermissionWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address delegator = vm.randomAddress();
    while (delegator == randomUser) delegator = vm.randomAddress();

    IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit
      memory p = _setCanSetUsingAsCollateralPermissionPermitData(
        randomUser,
        delegator,
        true,
        _warpBeforeRandomDeadline()
      );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.setCanSetUsingAsCollateralPermissionWithSig(p, signature);
  }

  function test_setCanSetUsingAsCollateralPermissionWithSig_revertsWith_InvalidAccountNonce(
    bytes32
  ) public {
    IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit
      memory p = _setCanSetUsingAsCollateralPermissionPermitData(
        vm.randomAddress(),
        alice,
        true,
        _warpBeforeRandomDeadline()
      );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.delegator, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.delegator, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.delegator, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.setCanSetUsingAsCollateralPermissionWithSig(p, signature);
  }

  function test_setCanSetUsingAsCollateralPermissionWithSig_revertsWith_SpokeNotRegistered()
    public
  {
    IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit
      memory p = _setCanSetUsingAsCollateralPermissionPermitData(
        bob,
        alice,
        true,
        _warpBeforeRandomDeadline()
      );
    p.spoke = address(spoke2);
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermissionWithSig(p, signature);
  }

  function test_setCanUpdateUserRiskPremiumPermissionPermit_typeHash() public view {
    assertEq(
      positionManager.SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH(),
      vm.eip712HashType('SetCanUpdateUserRiskPremiumPermissionPermit')
    );
    assertEq(
      positionManager.SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH(),
      keccak256(
        'SetCanUpdateUserRiskPremiumPermissionPermit(address spoke,address delegator,address delegatee,bool status,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_setCanUpdateUserRiskPremiumPermissionWithSig_fuzz(
    address delegatee,
    bool permission
  ) public {
    vm.assume(delegatee != address(0));

    IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit
      memory p = _setCanUpdateUserRiskPremiumPermissionPermitData(
        delegatee,
        alice,
        permission,
        _warpBeforeRandomDeadline()
      );
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.prank(vm.randomAddress());
    positionManager.setCanUpdateUserRiskPremiumPermissionWithSig(p, signature);

    assertEq(_canUpdateUserRiskPremium(address(spoke1), delegatee, alice), permission);
  }

  function test_setCanUpdateUserRiskPremiumPermissionWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit
      memory p = _setCanUpdateUserRiskPremiumPermissionPermitData(
        vm.randomAddress(),
        alice,
        true,
        _warpAfterRandomDeadline()
      );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.setCanUpdateUserRiskPremiumPermissionWithSig(p, signature);
  }

  function test_setCanUpdateUserRiskPremiumPermissionWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address delegator = vm.randomAddress();
    while (delegator == randomUser) delegator = vm.randomAddress();

    IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit
      memory p = _setCanUpdateUserRiskPremiumPermissionPermitData(
        randomUser,
        delegator,
        true,
        _warpBeforeRandomDeadline()
      );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.setCanUpdateUserRiskPremiumPermissionWithSig(p, signature);
  }

  function test_setCanUpdateUserRiskPremiumPermissionWithSig_revertsWith_InvalidAccountNonce(
    bytes32
  ) public {
    IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit
      memory p = _setCanUpdateUserRiskPremiumPermissionPermitData(
        vm.randomAddress(),
        alice,
        true,
        _warpBeforeRandomDeadline()
      );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.delegator, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.delegator, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.delegator, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.setCanUpdateUserRiskPremiumPermissionWithSig(p, signature);
  }

  function test_setCanUpdateUserRiskPremiumPermissionWithSig_revertsWith_SpokeNotRegistered()
    public
  {
    IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit
      memory p = _setCanUpdateUserRiskPremiumPermissionPermitData(
        bob,
        alice,
        true,
        _warpBeforeRandomDeadline()
      );
    p.spoke = address(spoke2);
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermissionWithSig(p, signature);
  }

  function test_setCanUpdateUserDynamicConfigPermissionPermit_typeHash() public view {
    assertEq(
      positionManager.SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH(),
      vm.eip712HashType('SetCanUpdateUserDynamicConfigPermissionPermit')
    );
    assertEq(
      positionManager.SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH(),
      keccak256(
        'SetCanUpdateUserDynamicConfigPermissionPermit(address spoke,address delegator,address delegatee,bool status,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_setCanUpdateUserDynamicConfigPermissionWithSig_fuzz(
    address delegatee,
    bool permission
  ) public {
    vm.assume(delegatee != address(0));

    IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit
      memory p = _setCanUpdateUserDynamicConfigPermissionPermitData(
        delegatee,
        alice,
        permission,
        _warpBeforeRandomDeadline()
      );
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.prank(vm.randomAddress());
    positionManager.setCanUpdateUserDynamicConfigPermissionWithSig(p, signature);

    assertEq(_canUpdateUserDynamicConfig(address(spoke1), delegatee, alice), permission);
  }

  function test_setCanUpdateUserDynamicConfigPermissionWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit
      memory p = _setCanUpdateUserDynamicConfigPermissionPermitData(
        vm.randomAddress(),
        alice,
        true,
        _warpAfterRandomDeadline()
      );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.setCanUpdateUserDynamicConfigPermissionWithSig(p, signature);
  }

  function test_setCanUpdateUserDynamicConfigPermissionWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address delegator = vm.randomAddress();
    while (delegator == randomUser) delegator = vm.randomAddress();

    IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit
      memory p = _setCanUpdateUserDynamicConfigPermissionPermitData(
        randomUser,
        delegator,
        true,
        _warpBeforeRandomDeadline()
      );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.setCanUpdateUserDynamicConfigPermissionWithSig(p, signature);
  }

  function test_setCanUpdateUserDynamicConfigPermissionWithSig_revertsWith_InvalidAccountNonce(
    bytes32
  ) public {
    IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit
      memory p = _setCanUpdateUserDynamicConfigPermissionPermitData(
        vm.randomAddress(),
        alice,
        true,
        _warpBeforeRandomDeadline()
      );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.delegator, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.delegator, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.delegator, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.setCanUpdateUserDynamicConfigPermissionWithSig(p, signature);
  }

  function test_setCanUpdateUserDynamicConfigPermissionWithSig_revertsWith_SpokeNotRegistered()
    public
  {
    IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit
      memory p = _setCanUpdateUserDynamicConfigPermissionPermitData(
        bob,
        alice,
        true,
        _warpBeforeRandomDeadline()
      );
    p.spoke = address(spoke2);
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermissionWithSig(p, signature);
  }
}
