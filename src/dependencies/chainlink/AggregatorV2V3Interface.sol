// SPDX-License-Identifier: MIT
// Imported from https://github.com/smartcontractkit/chainlink/blob/e8490e910274279a2c394ba37eb328943322ac6b/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol
pragma solidity ^0.8.0;

import {AggregatorInterface} from "./AggregatorInterface.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

// solhint-disable-next-line interface-starts-with-i
interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}
