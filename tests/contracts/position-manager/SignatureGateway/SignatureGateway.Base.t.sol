// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {SignatureGatewayHelpers} from 'tests/helpers/position-manager/signature-gateway/SignatureGatewayHelpers.sol';

contract SignatureGatewayBaseTest is Base, SignatureGatewayHelpers {
  ISignatureGateway public gateway;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    gateway = ISignatureGateway(new SignatureGateway(ADMIN));

    vm.prank(address(ADMIN));
    gateway.registerSpoke(address(spoke1), true);
  }

  function _supplyData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.Supply memory) {
    return _supplyData(gateway, spoke, user, deadline);
  }

  function _withdrawData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.Withdraw memory) {
    return _withdrawData(gateway, spoke, user, deadline);
  }

  function _borrowData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.Borrow memory) {
    return _borrowData(gateway, spoke, user, deadline);
  }

  function _repayData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.Repay memory) {
    return _repayData(gateway, spoke, user, deadline);
  }

  function _setAsCollateralData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.SetUsingAsCollateral memory) {
    return _setAsCollateralData(gateway, spoke, user, deadline);
  }

  function _updateRiskPremiumData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.UpdateUserRiskPremium memory) {
    return _updateRiskPremiumData(gateway, spoke, user, deadline);
  }

  function _updateDynamicConfigData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.UpdateUserDynamicConfig memory) {
    return _updateDynamicConfigData(gateway, spoke, user, deadline);
  }
}
