// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

interface ISpokeInstance is ISpoke {
  function initialize(address _authority) external;

  function SPOKE_REVISION() external view returns (uint64);
}
