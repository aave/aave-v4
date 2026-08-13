# pragma version 0.5.0a3

from position_manager import PositionManagerBase
from position_manager.libraries import EIP712Hash
from utils import NoncesKeyed

initializes: PositionManagerBase
initializes: EIP712Hash
initializes: NoncesKeyed
exports: PositionManagerBase.__interface__
exports: NoncesKeyed.__interface__


struct Reserve:
    underlying: address
    hub: address
    assetId: uint16
    decimals: uint8
    collateralRisk: uint24
    flags: uint8
    dynamicConfigKey: uint32

struct Permit:
    spoke: address
    reserveId: uint256
    owner: address
    spender: address
    amount: uint256
    nonce: uint256
    deadline: uint256

interface ISpoke:
    def getReserve(reserveId: uint256) -> Reserve: view
    def getUserSuppliedAssets(reserveId: uint256, user: address) -> uint256: view
    def getUserTotalDebt(reserveId: uint256, user: address) -> uint256: view
    def withdraw(reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256): nonpayable
    def borrow(reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256): nonpayable


event WithdrawApproval:
    spoke: indexed(address)
    owner: indexed(address)
    spender: indexed(address)
    reserveId: uint256
    amount: uint256

event BorrowApproval:
    spoke: indexed(address)
    owner: indexed(address)
    spender: indexed(address)
    reserveId: uint256
    amount: uint256

event WithdrawOnBehalfOf:
    spoke: indexed(address)
    caller: indexed(address)
    onBehalfOf: indexed(address)
    reserveId: uint256
    withdrawnShares: uint256
    withdrawnAmount: uint256

event BorrowOnBehalfOf:
    spoke: indexed(address)
    caller: indexed(address)
    onBehalfOf: indexed(address)
    reserveId: uint256
    drawnShares: uint256
    drawnAmount: uint256


WITHDRAW_PERMIT_TYPEHASH: public(constant(bytes32)) = 0x9e6642fd4c06a4c1a5e201f1e41c6b7892fcf06859c796b054c510b80e2a0a3f
BORROW_PERMIT_TYPEHASH: public(constant(bytes32)) = 0x14236ea048da65ffb52a9b32a2c840f24ab374cc31f65faeb7877d22ceca144e
DOMAIN_TYPEHASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
NAME_HASH: constant(bytes32) = keccak256("TakerPositionManager")
VERSION_HASH: constant(bytes32) = keccak256("1")

withdraw_allowances: HashMap[address, HashMap[uint256, HashMap[address, HashMap[address, uint256]]]]
borrow_allowances: HashMap[address, HashMap[uint256, HashMap[address, HashMap[address, uint256]]]]


@deploy
def __init__(initialOwner: address):
    PositionManagerBase._initialize_owner(initialOwner)


@pure
@override(PositionManagerBase)
def _multicall_enabled() -> bool:
    return True


@internal
@view
def _domain_separator() -> bytes32:
    return keccak256(abi_encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, chain.id, self))


@internal
def _verify(signer: address, intent_hash: bytes32, nonce: uint256, deadline: uint256, signature: Bytes[65]):
    if block.timestamp > deadline or len(signature) != 65:
        raw_revert(method_id("InvalidSignature()"))
    digest: bytes32 = keccak256(concat(b"\x19\x01", self._domain_separator(), intent_hash))
    r: bytes32 = convert(slice(signature, 0, 32), bytes32)
    s: bytes32 = convert(slice(signature, 32, 32), bytes32)
    v: uint256 = convert(slice(signature, 64, 1), uint256)
    recovered: address = ecrecover(digest, v, r, s)
    if recovered == empty(address) or recovered != signer:
        raw_revert(method_id("InvalidSignature()"))
    NoncesKeyed._use_checked_nonce(signer, nonce)


@internal
def _update_withdraw(spoke: address, reserve_id: uint256, owner: address, spender: address, amount: uint256):
    self.withdraw_allowances[spoke][reserve_id][owner][spender] = amount
    log WithdrawApproval(spoke=spoke, owner=owner, spender=spender, reserveId=reserve_id, amount=amount)


@internal
def _update_borrow(spoke: address, reserve_id: uint256, owner: address, spender: address, amount: uint256):
    self.borrow_allowances[spoke][reserve_id][owner][spender] = amount
    log BorrowApproval(spoke=spoke, owner=owner, spender=spender, reserveId=reserve_id, amount=amount)


@internal
def _safe_transfer(token: address, to: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(method_id("transfer(address,uint256)"), convert(to, bytes32), convert(amount, bytes32)),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@external
@view
def DOMAIN_SEPARATOR() -> bytes32:
    return self._domain_separator()


@external
@view
def eip712Domain() -> (bytes1, String[32], String[8], uint256, address, bytes32, DynArray[uint256, 1]):
    extensions: DynArray[uint256, 1] = []
    return 0x0f, "TakerPositionManager", "1", chain.id, self, empty(bytes32), extensions


@external
def approveWithdraw(spoke: address, reserveId: uint256, spender: address, amount: uint256):
    PositionManagerBase._check_registered(spoke)
    self._update_withdraw(spoke, reserveId, msg.sender, spender, amount)


@external
def approveBorrow(spoke: address, reserveId: uint256, spender: address, amount: uint256):
    PositionManagerBase._check_registered(spoke)
    self._update_borrow(spoke, reserveId, msg.sender, spender, amount)


@external
def approveWithdrawWithSig(params: Permit, signature: Bytes[65]):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_reserve_permit(
        WITHDRAW_PERMIT_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.owner,
        params.spender,
        params.amount,
        params.nonce,
        params.deadline,
    )
    self._verify(params.owner, intent_hash, params.nonce, params.deadline, signature)
    self._update_withdraw(params.spoke, params.reserveId, params.owner, params.spender, params.amount)


@external
def approveBorrowWithSig(params: Permit, signature: Bytes[65]):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_reserve_permit(
        BORROW_PERMIT_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.owner,
        params.spender,
        params.amount,
        params.nonce,
        params.deadline,
    )
    self._verify(params.owner, intent_hash, params.nonce, params.deadline, signature)
    self._update_borrow(params.spoke, params.reserveId, params.owner, params.spender, params.amount)


@external
def renounceWithdrawAllowance(spoke: address, reserveId: uint256, owner: address):
    PositionManagerBase._check_registered(spoke)
    if self.withdraw_allowances[spoke][reserveId][owner][msg.sender] != 0:
        self._update_withdraw(spoke, reserveId, owner, msg.sender, 0)


@external
def renounceBorrowAllowance(spoke: address, reserveId: uint256, owner: address):
    PositionManagerBase._check_registered(spoke)
    if self.borrow_allowances[spoke][reserveId][owner][msg.sender] != 0:
        self._update_borrow(spoke, reserveId, owner, msg.sender, 0)


@external
@view
def withdrawAllowance(spoke: address, reserveId: uint256, owner: address, spender: address) -> uint256:
    return self.withdraw_allowances[spoke][reserveId][owner][spender]


@external
@view
def borrowAllowance(spoke: address, reserveId: uint256, owner: address, spender: address) -> uint256:
    return self.borrow_allowances[spoke][reserveId][owner][spender]


@external
def withdrawOnBehalfOf(spoke: address, reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256):
    PositionManagerBase._check_registered(spoke)
    reserve: Reserve = staticcall ISpoke(spoke).getReserve(reserveId)
    allowance: uint256 = self.withdraw_allowances[spoke][reserveId][onBehalfOf][msg.sender]
    if allowance < amount:
        raw_revert(concat(method_id("InsufficientWithdrawAllowance(uint256,uint256)"), convert(allowance, bytes32), convert(amount, bytes32)))
    supplied_before: uint256 = 0
    if allowance != max_value(uint256):
        supplied_before = staticcall ISpoke(spoke).getUserSuppliedAssets(reserveId, onBehalfOf)
    shares: uint256 = 0
    withdrawn: uint256 = 0
    shares, withdrawn = extcall ISpoke(spoke).withdraw(reserveId, amount, onBehalfOf)
    if allowance != max_value(uint256):
        supplied_after: uint256 = staticcall ISpoke(spoke).getUserSuppliedAssets(reserveId, onBehalfOf)
        consumed: uint256 = supplied_before - supplied_after
        self._update_withdraw(spoke, reserveId, onBehalfOf, msg.sender, allowance - min(allowance, consumed))
    self._safe_transfer(reserve.underlying, msg.sender, withdrawn)
    log WithdrawOnBehalfOf(spoke=spoke, caller=msg.sender, onBehalfOf=onBehalfOf, reserveId=reserveId, withdrawnShares=shares, withdrawnAmount=withdrawn)
    return shares, withdrawn


@external
def borrowOnBehalfOf(spoke: address, reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256):
    PositionManagerBase._check_registered(spoke)
    reserve: Reserve = staticcall ISpoke(spoke).getReserve(reserveId)
    allowance: uint256 = self.borrow_allowances[spoke][reserveId][onBehalfOf][msg.sender]
    if allowance < amount:
        raw_revert(concat(method_id("InsufficientBorrowAllowance(uint256,uint256)"), convert(allowance, bytes32), convert(amount, bytes32)))
    borrowed_before: uint256 = 0
    if allowance != max_value(uint256):
        borrowed_before = staticcall ISpoke(spoke).getUserTotalDebt(reserveId, onBehalfOf)
    shares: uint256 = 0
    borrowed: uint256 = 0
    shares, borrowed = extcall ISpoke(spoke).borrow(reserveId, amount, onBehalfOf)
    if allowance != max_value(uint256):
        borrowed_after: uint256 = staticcall ISpoke(spoke).getUserTotalDebt(reserveId, onBehalfOf)
        consumed: uint256 = borrowed_after - borrowed_before
        self._update_borrow(spoke, reserveId, onBehalfOf, msg.sender, allowance - min(allowance, consumed))
    self._safe_transfer(reserve.underlying, msg.sender, borrowed)
    log BorrowOnBehalfOf(spoke=spoke, caller=msg.sender, onBehalfOf=onBehalfOf, reserveId=reserveId, drawnShares=shares, drawnAmount=borrowed)
    return shares, borrowed


@external
@payable
def __default__():
    pass
