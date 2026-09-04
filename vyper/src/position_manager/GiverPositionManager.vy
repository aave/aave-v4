# pragma version 0.5.0b2

from position_manager import PositionManagerBase
from spoke.interfaces import ISpoke
from position_manager.interfaces import IGiverPositionManager

implements: IGiverPositionManager

initializes: PositionManagerBase
exports: PositionManagerBase.__interface__


@deploy
def __init__(initialOwner: address):
    PositionManagerBase._initialize_owner(initialOwner)


@pure
@override(PositionManagerBase)
def _multicall_enabled() -> bool:
    return True


@internal
def _safe_transfer_from(token: address, owner: address, to: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transferFrom(address,address,uint256)"),
            convert(owner, bytes32),
            convert(to, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@internal
def _force_approve(token: address, spender: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(
            method_id("approve(address,uint256)"),
            convert(spender, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@external
def supplyOnBehalfOf(
    spoke: address,
    reserveId: uint256,
    amount: uint256,
    onBehalfOf: address,
) -> (uint256, uint256):
    PositionManagerBase._check_registered(spoke)
    reserve: ISpoke.Reserve = staticcall ISpoke(spoke).getReserve(reserveId)
    self._safe_transfer_from(reserve.underlying, msg.sender, self, amount)
    self._force_approve(reserve.underlying, spoke, amount)
    supplied_shares: uint256 = 0
    supplied_amount: uint256 = 0
    supplied_shares, supplied_amount = extcall ISpoke(spoke).supply(
        reserveId, amount, onBehalfOf
    )
    log IGiverPositionManager.SupplyOnBehalfOf(
        spoke=spoke,
        caller=msg.sender,
        onBehalfOf=onBehalfOf,
        reserveId=reserveId,
        suppliedShares=supplied_shares,
        suppliedAmount=supplied_amount,
    )
    return supplied_shares, supplied_amount


@external
def repayOnBehalfOf(
    spoke: address,
    reserveId: uint256,
    amount: uint256,
    onBehalfOf: address,
) -> (uint256, uint256):
    PositionManagerBase._check_registered(spoke)
    if amount == max_value(uint256):
        raise IGiverPositionManager.RepayOnBehalfMaxUintNotAllowed()
    reserve: ISpoke.Reserve = staticcall ISpoke(spoke).getReserve(reserveId)
    total_debt: uint256 = staticcall ISpoke(spoke).getUserTotalDebt(reserveId, onBehalfOf)
    repay_amount: uint256 = min(amount, total_debt)
    self._safe_transfer_from(reserve.underlying, msg.sender, self, repay_amount)
    self._force_approve(reserve.underlying, spoke, repay_amount)
    repaid_shares: uint256 = 0
    repaid_amount: uint256 = 0
    repaid_shares, repaid_amount = extcall ISpoke(spoke).repay(
        reserveId, repay_amount, onBehalfOf
    )
    log IGiverPositionManager.RepayOnBehalfOf(
        spoke=spoke,
        caller=msg.sender,
        onBehalfOf=onBehalfOf,
        reserveId=reserveId,
        repaidShares=repaid_shares,
        repaidAmount=repaid_amount,
    )
    return repaid_shares, repaid_amount


@external
@payable
def __default__():
    pass
