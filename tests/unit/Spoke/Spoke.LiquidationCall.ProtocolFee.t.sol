// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract LiquidationCallProtocolFeeTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  function test_liquidationCall_protocolFee() public {}
}
