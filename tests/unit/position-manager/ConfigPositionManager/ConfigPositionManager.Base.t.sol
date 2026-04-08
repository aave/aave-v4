// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract ConfigPositionManagerBaseTest is SpokeBase {
  using ConfigPermissionsMap for ConfigPermissions;

  ConfigPositionManager public positionManager;
  TestReturnValues public returnValues;

  ConfigPermissions emptyPermissions;

  function setUp() public virtual override {
    super.setUp();

    positionManager = new ConfigPositionManager(address(ADMIN));

    emptyPermissions = ConfigPermissions.wrap(0);

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function _setGlobalPermissionPermitData(
    address delegatee,
    address delegator,
    bool status,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetGlobalPermissionPermit memory) {
    return
      IConfigPositionManager.SetGlobalPermissionPermit({
        spoke: address(spoke1),
        delegator: delegator,
        delegatee: delegatee,
        status: status,
        nonce: positionManager.nonces(delegator, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _setCanSetUsingAsCollateralPermissionPermitData(
    address delegatee,
    address delegator,
    bool status,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit memory) {
    return
      IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit({
        spoke: address(spoke1),
        delegator: delegator,
        delegatee: delegatee,
        status: status,
        nonce: positionManager.nonces(delegator, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _setCanUpdateUserRiskPremiumPermissionPermitData(
    address delegatee,
    address delegator,
    bool status,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit memory) {
    return
      IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit({
        spoke: address(spoke1),
        delegator: delegator,
        delegatee: delegatee,
        status: status,
        nonce: positionManager.nonces(delegator, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _setCanUpdateUserDynamicConfigPermissionPermitData(
    address delegatee,
    address delegator,
    bool status,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit memory) {
    return
      IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit({
        spoke: address(spoke1),
        delegator: delegator,
        delegatee: delegatee,
        status: status,
        nonce: positionManager.nonces(delegator, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _getTypedDataHash(
    IConfigPositionManager _positionManager,
    IConfigPositionManager.SetGlobalPermissionPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _positionManager,
        vm.eip712HashStruct('SetGlobalPermissionPermit', abi.encode(_params))
      );
  }

  function _getTypedDataHash(
    IConfigPositionManager _positionManager,
    IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _positionManager,
        vm.eip712HashStruct('SetCanSetUsingAsCollateralPermissionPermit', abi.encode(_params))
      );
  }

  function _getTypedDataHash(
    IConfigPositionManager _positionManager,
    IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _positionManager,
        vm.eip712HashStruct('SetCanUpdateUserRiskPremiumPermissionPermit', abi.encode(_params))
      );
  }

  function _getTypedDataHash(
    IConfigPositionManager _positionManager,
    IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _positionManager,
        vm.eip712HashStruct('SetCanUpdateUserDynamicConfigPermissionPermit', abi.encode(_params))
      );
  }

  function _typedDataHash(
    IConfigPositionManager _positionManager,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _positionManager.DOMAIN_SEPARATOR(), typeHash));
  }

  function _canUpdateUsingAsCollateral(
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(spoke, delegator, delegatee);
    return permissions.canSetUsingAsCollateral;
  }

  function _canUpdateUserRiskPremium(
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(spoke, delegator, delegatee);
    return permissions.canUpdateUserRiskPremium;
  }

  function _canUpdateUserDynamicConfig(
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(spoke, delegator, delegatee);
    return permissions.canUpdateUserDynamicConfig;
  }
}
