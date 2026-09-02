# pragma version 0.5.0b1

from position_manager import PositionManagerBase
from spoke.interfaces import ISpoke
from position_manager.interfaces import INativeTokenGateway
from position_manager.interfaces import IPositionManager

implements: INativeTokenGateway

initializes: PositionManagerBase
exports: PositionManagerBase.__interface__


NATIVE_TOKEN_WRAPPER: public(immutable(address))
reentrancy_lock: bool


@deploy
def __init__(nativeTokenWrapper: address, initialOwner: address):
    if nativeTokenWrapper == empty(address):
        raise IPositionManager.InvalidAddress()
    NATIVE_TOKEN_WRAPPER = nativeTokenWrapper
    PositionManagerBase._initialize_owner(initialOwner)


@pure
@override(PositionManagerBase)
def _multicall_enabled() -> bool:
    return False


@internal
def _enter():
    if self.reentrancy_lock:
        raise INativeTokenGateway.ReentrancyGuardReentrantCall()
    self.reentrancy_lock = True


@internal
def _exit():
    self.reentrancy_lock = False


@internal
@view
def _reserve_underlying(spoke: address, reserve_id: uint256) -> address:
    reserve: ISpoke.Reserve = staticcall ISpoke(spoke).getReserve(reserve_id)
    return reserve.underlying


@internal
@view
def _validate(underlying: address, amount: uint256):
    if underlying != NATIVE_TOKEN_WRAPPER:
        raise INativeTokenGateway.NotNativeWrappedAsset()
    if amount == 0:
        raise INativeTokenGateway.InvalidAmount()


@internal
def _force_approve(spender: address, amount: uint256):
    result: Bytes[32] = raw_call(
        NATIVE_TOKEN_WRAPPER,
        concat(
            method_id("approve(address,uint256)"),
            convert(spender, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@internal
def _wrap(amount: uint256):
    raw_call(NATIVE_TOKEN_WRAPPER, method_id("deposit()"), value=amount)


@internal
def _unwrap(amount: uint256):
    raw_call(
        NATIVE_TOKEN_WRAPPER,
        concat(method_id("withdraw(uint256)"), convert(amount, bytes32)),
    )


@internal
def _send_native(to: address, amount: uint256):
    raw_call(to, b"", value=amount)


@internal
def _supply_native(spoke: address, reserve_id: uint256, user: address, amount: uint256) -> (uint256, uint256):
    underlying: address = self._reserve_underlying(spoke, reserve_id)
    self._validate(underlying, amount)
    self._wrap(amount)
    self._force_approve(spoke, amount)
    return extcall ISpoke(spoke).supply(reserve_id, amount, user)


@external
@payable
def supplyNative(spoke: address, reserveId: uint256, amount: uint256) -> (uint256, uint256):
    self._enter()
    PositionManagerBase._check_registered(spoke)
    if msg.value != amount:
        raise INativeTokenGateway.NativeAmountMismatch()
    shares: uint256 = 0
    supplied: uint256 = 0
    shares, supplied = self._supply_native(spoke, reserveId, msg.sender, amount)
    self._exit()
    return shares, supplied


@external
@payable
def supplyAsCollateralNative(spoke: address, reserveId: uint256, amount: uint256) -> (uint256, uint256):
    self._enter()
    PositionManagerBase._check_registered(spoke)
    if msg.value != amount:
        raise INativeTokenGateway.NativeAmountMismatch()
    shares: uint256 = 0
    supplied: uint256 = 0
    shares, supplied = self._supply_native(spoke, reserveId, msg.sender, amount)
    extcall ISpoke(spoke).setUsingAsCollateral(reserveId, True, msg.sender)
    self._exit()
    return shares, supplied


@external
def withdrawNative(spoke: address, reserveId: uint256, amount: uint256) -> (uint256, uint256):
    self._enter()
    PositionManagerBase._check_registered(spoke)
    underlying: address = self._reserve_underlying(spoke, reserveId)
    self._validate(underlying, amount)
    shares: uint256 = 0
    withdrawn: uint256 = 0
    shares, withdrawn = extcall ISpoke(spoke).withdraw(reserveId, amount, msg.sender)
    self._unwrap(withdrawn)
    self._send_native(msg.sender, withdrawn)
    self._exit()
    return shares, withdrawn


@external
def borrowNative(spoke: address, reserveId: uint256, amount: uint256) -> (uint256, uint256):
    self._enter()
    PositionManagerBase._check_registered(spoke)
    underlying: address = self._reserve_underlying(spoke, reserveId)
    self._validate(underlying, amount)
    shares: uint256 = 0
    borrowed: uint256 = 0
    shares, borrowed = extcall ISpoke(spoke).borrow(reserveId, amount, msg.sender)
    self._unwrap(borrowed)
    self._send_native(msg.sender, borrowed)
    self._exit()
    return shares, borrowed


@external
@payable
def repayNative(spoke: address, reserveId: uint256, amount: uint256) -> (uint256, uint256):
    self._enter()
    PositionManagerBase._check_registered(spoke)
    if msg.value != amount:
        raise INativeTokenGateway.NativeAmountMismatch()
    underlying: address = self._reserve_underlying(spoke, reserveId)
    self._validate(underlying, amount)
    total_debt: uint256 = staticcall ISpoke(spoke).getUserTotalDebt(reserveId, msg.sender)
    repay_amount: uint256 = min(amount, total_debt)
    leftovers: uint256 = amount - repay_amount
    self._wrap(repay_amount)
    self._force_approve(spoke, repay_amount)
    shares: uint256 = 0
    repaid: uint256 = 0
    shares, repaid = extcall ISpoke(spoke).repay(reserveId, repay_amount, msg.sender)
    if leftovers > 0:
        self._send_native(msg.sender, leftovers)
    self._exit()
    return shares, repaid


@external
@payable
def __default__():
    if msg.sender != NATIVE_TOKEN_WRAPPER:
        raise IPositionManager.UnsupportedAction()
