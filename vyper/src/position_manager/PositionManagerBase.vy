# pragma version 0.5.0b1
from spoke.interfaces import ISpoke
from position_manager.interfaces import IPositionManager

MAX_CALLS: constant(uint256) = 4
MAX_CALLDATA: constant(uint256) = 512
MAX_RETURN_DATA: constant(uint256) = 256
MAX_SIGNATURE: constant(uint256) = 256


owner_address: address
pending_owner_address: address
registered_spokes: HashMap[address, bool]


@pure
@abstract
def _multicall_enabled() -> bool:
    ...


@internal
def _initialize_owner(initial_owner: address):
    if initial_owner == empty(address):
        raise IPositionManager.OwnableInvalidOwner(initial_owner)
    self.owner_address = initial_owner
    log IPositionManager.OwnershipTransferred(previousOwner=empty(address), newOwner=initial_owner)


@internal
@view
def _check_owner():
    if msg.sender != self.owner_address:
        raise IPositionManager.OwnableUnauthorizedAccount(msg.sender)


@internal
@view
def _check_registered(spoke: address):
    if not self.registered_spokes[spoke]:
        raise IPositionManager.SpokeNotRegistered()


@internal
def _safe_transfer(token: address, to: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transfer(address,uint256)"),
            convert(to, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@external
@view
def owner() -> address:
    return self.owner_address


@external
@view
def pendingOwner() -> address:
    return self.pending_owner_address


@external
def transferOwnership(newOwner: address):
    self._check_owner()
    self.pending_owner_address = newOwner
    log IPositionManager.OwnershipTransferStarted(previousOwner=self.owner_address, newOwner=newOwner)


@external
def acceptOwnership():
    if msg.sender != self.pending_owner_address:
        raise IPositionManager.OwnableUnauthorizedAccount(msg.sender)
    old_owner: address = self.owner_address
    self.pending_owner_address = empty(address)
    self.owner_address = msg.sender
    log IPositionManager.OwnershipTransferred(previousOwner=old_owner, newOwner=msg.sender)


@external
def renounceOwnership():
    self._check_owner()
    old_owner: address = self.owner_address
    self.pending_owner_address = empty(address)
    self.owner_address = empty(address)
    log IPositionManager.OwnershipTransferred(previousOwner=old_owner, newOwner=empty(address))


@external
def registerSpoke(spoke: address, registered: bool):
    self._check_owner()
    if spoke == empty(address):
        raise IPositionManager.InvalidAddress()
    self.registered_spokes[spoke] = registered
    log IPositionManager.RegisterSpoke(spoke=spoke, registered=registered)


@external
@view
def isSpokeRegistered(spoke: address) -> bool:
    return self.registered_spokes[spoke]


@external
@view
def getReserveUnderlying(spoke: address, reserveId: uint256) -> address:
    reserve: ISpoke.Reserve = staticcall ISpoke(spoke).getReserve(reserveId)
    return reserve.underlying


@external
def setSelfAsUserPositionManagerWithSig(
    spoke: address,
    onBehalfOf: address,
    approve: bool,
    nonce: uint256,
    deadline: uint256,
    signature: Bytes[INF],
):
    self._check_registered(spoke)
    updates: DynArray[ISpoke.PositionManagerUpdate, 1] = [
        ISpoke.PositionManagerUpdate(positionManager=self, approve=approve)
    ]
    params: ISpoke.SetUserPositionManagers = ISpoke.SetUserPositionManagers(
        onBehalfOf=onBehalfOf,
        updates=updates,
        nonce=nonce,
        deadline=deadline,
    )
    success: bool = raw_call(
        spoke,
        concat(
            method_id("setUserPositionManagersWithSig((address,(address,bool)[],uint256,uint256),bytes)"),
            abi_encode(params, signature),
        ),
        revert_on_failure=False,
    )
    # This convenience method intentionally ignores a failed permit-style call.


@external
def permitReserveUnderlying(
    spoke: address,
    reserveId: uint256,
    onBehalfOf: address,
    permitValue: uint256,
    deadline: uint256,
    permitV: uint8,
    permitR: bytes32,
    permitS: bytes32,
):
    self._check_registered(spoke)
    reserve: ISpoke.Reserve = staticcall ISpoke(spoke).getReserve(reserveId)
    underlying: address = reserve.underlying
    success: bool = raw_call(
        underlying,
        concat(
            method_id("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)"),
            abi_encode(onBehalfOf, self, permitValue, deadline, permitV, permitR, permitS),
        ),
        revert_on_failure=False,
    )


@external
def renouncePositionManagerRole(spoke: address, user: address):
    self._check_owner()
    self._check_registered(spoke)
    extcall ISpoke(spoke).renouncePositionManagerRole(user)


@external
def multicall(data: DynArray[Bytes[MAX_CALLDATA], MAX_CALLS]) -> DynArray[Bytes[MAX_RETURN_DATA], MAX_CALLS]:
    if not self._multicall_enabled():
        raise IPositionManager.UnsupportedAction()
    results: DynArray[Bytes[MAX_RETURN_DATA], MAX_CALLS] = []
    for call_data: Bytes[MAX_CALLDATA] in data:
        success: bool = False
        result: Bytes[MAX_RETURN_DATA] = b""
        success, result = raw_call(
            self,
            call_data,
            max_outsize=MAX_RETURN_DATA,
            is_delegate_call=True,
            revert_on_failure=False,
        )
        if not success:
            # Preserve arbitrary downstream revert data; it cannot be represented by a static error.
            raw_revert(result)
        results.append(result)
    return results


@external
def rescueToken(token: address, to: address, amount: uint256):
    self._check_owner()
    self._safe_transfer(token, to, amount)


@external
def rescueNative(to: address, amount: uint256):
    self._check_owner()
    raw_call(to, b"", value=amount)


@external
@view
def rescueGuardian() -> address:
    return self.owner_address
