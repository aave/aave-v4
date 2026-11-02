// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPositionManagerGate} from 'src/spoke/interfaces/IPositionManagerGate.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @title EmaBorrowLimitGate
/// @author Aave Labs
/// @notice POC gate tightening a Spoke reserve's effective draw cap towards its recent drawn amount
/// when net borrow volume accelerates.
/// @dev For an EMA with time constant `tau`, `drawn - ema(drawn) = tau * ema(borrows - repays)`, so
/// bounding drawn above its EMA bounds the EMA of net borrow volume. Borrows are allowed while
/// `drawn + amount <= ema + max(ema * maxGrowth, minHeadroom)`. All state is scoped by the calling Spoke.
contract EmaBorrowLimitGate is ISpokeGate, AccessManaged {
  /// @dev tau The EMA time constant, in seconds. Zero disables the limit.
  /// @dev maxGrowth The allowed growth of drawn above its EMA, in BPS.
  /// @dev minHeadroom The minimum allowed growth above the EMA, in asset units.
  struct Config {
    uint32 tau;
    uint16 maxGrowth;
    uint128 minHeadroom;
  }

  struct State {
    uint128 emaDrawn;
    uint40 lastUpdate;
  }

  /// @notice Gate used to authorize delegated calls. Zero means self-only calls.
  IPositionManagerGate public immutable POSITION_MANAGER_GATE;

  mapping(address spoke => mapping(uint256 reserveId => Config)) public configs;
  mapping(address spoke => mapping(uint256 reserveId => State)) public states;

  constructor(address authority_, address positionManagerGate_) AccessManaged(authority_) {
    POSITION_MANAGER_GATE = IPositionManagerGate(positionManagerGate_);
  }

  /// @notice Sets the limit of a Spoke reserve and seeds its EMA with the current drawn amount.
  function setConfig(address spoke, uint256 reserveId, Config calldata config) external restricted {
    configs[spoke][reserveId] = config;
    states[spoke][reserveId] = State(uint128(_getDrawn(spoke, reserveId)), uint40(block.timestamp));
  }

  /// @inheritdoc ISpokeGate
  function isCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata data
  ) external returns (bool) {
    if (!_isAuthorized(msg.sender, caller, onBehalfOf)) return false;
    if (bytes4(data) != ISpoke.borrow.selector) return true;

    (uint256 reserveId, uint256 amount, ) = abi.decode(data[4:], (uint256, uint256, address));
    Config memory config = configs[msg.sender][reserveId];
    if (config.tau == 0) return true;

    uint256 drawn = _getDrawn(msg.sender, reserveId);
    uint256 emaDrawn = _nextEma(states[msg.sender][reserveId], config.tau, drawn);
    states[msg.sender][reserveId] = State(uint128(emaDrawn), uint40(block.timestamp));

    return drawn + amount <= _drawLimit(config, emaDrawn);
  }

  /// @notice Returns the maximum drawn amount currently allowed for a Spoke reserve.
  function getDrawLimit(address spoke, uint256 reserveId) external view returns (uint256) {
    Config memory config = configs[spoke][reserveId];
    if (config.tau == 0) return type(uint256).max;
    return
      _drawLimit(
        config,
        _nextEma(states[spoke][reserveId], config.tau, _getDrawn(spoke, reserveId))
      );
  }

  function _isAuthorized(
    address spoke,
    address caller,
    address onBehalfOf
  ) internal view returns (bool) {
    if (caller == onBehalfOf) return true;
    if (address(POSITION_MANAGER_GATE) == address(0)) return false;
    return POSITION_MANAGER_GATE.isPositionManager(spoke, onBehalfOf, caller);
  }

  function _getDrawn(address spoke, uint256 reserveId) internal view returns (uint256 drawn) {
    ISpoke.Reserve memory reserve = ISpoke(spoke).getReserve(reserveId);
    (drawn, ) = reserve.hub.getSpokeOwed(reserve.assetId, spoke);
  }

  /// @dev Moves the EMA towards `drawn` with weight `dt / (dt + tau)`, a cheap approximation of
  /// `1 - exp(-dt / tau)`. Same-block calls do not move the EMA, so bursts share one allowance.
  function _nextEma(
    State memory state,
    uint256 tau,
    uint256 drawn
  ) internal view returns (uint256) {
    uint256 dt = block.timestamp - state.lastUpdate;
    if (drawn >= state.emaDrawn) {
      return state.emaDrawn + ((drawn - state.emaDrawn) * dt) / (dt + tau);
    }
    return state.emaDrawn - ((state.emaDrawn - drawn) * dt) / (dt + tau);
  }

  function _drawLimit(Config memory config, uint256 emaDrawn) internal pure returns (uint256) {
    uint256 headroom = (emaDrawn * config.maxGrowth) / 10_000;
    return emaDrawn + (headroom > config.minHeadroom ? headroom : config.minHeadroom);
  }
}
