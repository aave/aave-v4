// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IFlashLoanReceiver} from 'src/spoke/interfaces/IFlashLoanReceiver.sol';
import {IFlashLoanSimpleReceiver} from 'src/spoke/interfaces/IFlashLoanSimpleReceiver.sol';

contract MockFlashLoanReceiver is IFlashLoanReceiver, IFlashLoanSimpleReceiver {
  address public immutable FLASH_LOAN_SPOKE;

  bool public returnValue = true;
  uint256 public shortfall;
  bytes internal _nestedCall;

  constructor(address flashLoanSpoke) {
    FLASH_LOAN_SPOKE = flashLoanSpoke;
  }

  function setReturnValue(bool value) external {
    returnValue = value;
  }

  function setShortfall(uint256 value) external {
    shortfall = value;
  }

  /// @dev Calldata sent to the FlashLoanSpoke from within the next callback, once.
  function setNestedCall(bytes calldata data) external {
    _nestedCall = data;
  }

  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address,
    bytes calldata
  ) external returns (bool) {
    _executeNestedCall();
    for (uint256 i; i < assets.length; ++i) {
      _approveRepayment(assets[i], amounts[i] + premiums[i]);
    }
    return returnValue;
  }

  function executeOperation(
    address asset,
    uint256 amount,
    uint256 premium,
    address,
    bytes calldata
  ) external returns (bool) {
    _executeNestedCall();
    _approveRepayment(asset, amount + premium);
    return returnValue;
  }

  function _executeNestedCall() internal {
    bytes memory data = _nestedCall;
    if (data.length > 0) {
      delete _nestedCall;
      (bool success, bytes memory result) = FLASH_LOAN_SPOKE.call(data);
      if (!success) {
        assembly ('memory-safe') {
          revert(add(result, 32), mload(result))
        }
      }
    }
  }

  function _approveRepayment(address asset, uint256 amount) internal {
    uint256 allowance = IERC20(asset).allowance(address(this), FLASH_LOAN_SPOKE);
    IERC20(asset).approve(FLASH_LOAN_SPOKE, allowance + amount - shortfall);
  }
}
