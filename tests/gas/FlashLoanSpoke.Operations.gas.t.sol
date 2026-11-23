// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/flashloan-spoke/FlashLoanSpoke.Base.t.sol';

/// forge-config: default.isolate = true
contract FlashLoanSpokeOperations_Gas_Tests is FlashLoanSpokeBaseTest {
  string internal constant NAMESPACE = 'FlashLoanSpoke.Operations';

  function test_flashLoanSimple() public {
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    vm.snapshotGasLastFrame(NAMESPACE, 'flashLoanSimple');
  }

  function test_flashLoanSimple_authorizedFlashBorrower() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);

    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    vm.snapshotGasLastFrame(NAMESPACE, 'flashLoanSimple: authorized flash borrower');
  }

  function test_flashLoanSimple_authorizedFlashBorrower_existingRoundingDebt() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    vm.startPrank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);

    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    vm.snapshotGasLastFrame(
      NAMESPACE,
      'flashLoanSimple: authorized flash borrower, existing rounding debt'
    );
    vm.stopPrank();
  }

  function test_flashLoanSimple_restoresRoundingDebt() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);

    vm.prank(bob);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    vm.snapshotGasLastFrame(NAMESPACE, 'flashLoanSimple: restores rounding debt');
  }

  function test_flashLoanSimple_nested() public {
    receiver.setNestedCall(
      abi.encodeCall(IFlashLoanSpoke.flashLoanSimple, (address(receiver), dai, 2_000e18, PARAMS))
    );

    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    vm.snapshotGasLastFrame(NAMESPACE, 'flashLoanSimple: nested, same asset');
  }

  function test_flashLoan_oneAsset() public {
    address[] memory assets = new address[](1);
    assets[0] = dai;
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1_000e18;

    vm.prank(alice);
    flashLoanSpoke.flashLoan(address(receiver), assets, amounts, PARAMS);
    vm.snapshotGasLastFrame(NAMESPACE, 'flashLoan: 1 asset');
  }

  function test_flashLoan_twoAssets() public {
    address[] memory assets = new address[](2);
    (assets[0], assets[1]) = (dai, usdx);
    uint256[] memory amounts = new uint256[](2);
    (amounts[0], amounts[1]) = (1_000e18, 1_000e6);

    vm.prank(alice);
    flashLoanSpoke.flashLoan(address(receiver), assets, amounts, PARAMS);
    vm.snapshotGasLastFrame(NAMESPACE, 'flashLoan: 2 assets');
  }

  function test_flashLoan_sameAssetTwice() public {
    address[] memory assets = new address[](2);
    (assets[0], assets[1]) = (dai, dai);
    uint256[] memory amounts = new uint256[](2);
    (amounts[0], amounts[1]) = (1_000e18, 2_000e18);

    vm.prank(alice);
    flashLoanSpoke.flashLoan(address(receiver), assets, amounts, PARAMS);
    vm.snapshotGasLastFrame(NAMESPACE, 'flashLoan: same asset twice');
  }
}
