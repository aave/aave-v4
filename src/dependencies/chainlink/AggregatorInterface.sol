// SPDX-License-Identifier: MIT
// Imported from https://github.com/smartcontractkit/chainlink/blob/e8490e910274279a2c394ba37eb328943322ac6b/contracts/src/v0.8/shared/interfaces/AggregatorInterface.sol
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface AggregatorInterface {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}
