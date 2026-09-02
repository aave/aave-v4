# pragma version 0.5.0b1

from position_manager import PositionManagerBase
from position_manager.libraries import EIP712Hash
from utils import NoncesKeyed
from spoke.interfaces import ISpoke
from position_manager.interfaces import ISignatureGateway

implements: ISignatureGateway

initializes: PositionManagerBase
initializes: NoncesKeyed
exports: PositionManagerBase.__interface__
exports: NoncesKeyed.__interface__


SUPPLY_TYPEHASH: public(constant(bytes32)) = 0xe85497eb293c001e8483fe105efadd1d50aa0dadfc0570b27058031dfceab2e6
WITHDRAW_TYPEHASH: public(constant(bytes32)) = 0x0bc73eb58cf4068a29b9593ef18c0d26b3b4453bd2155424a90cb26a22f41d7f
BORROW_TYPEHASH: public(constant(bytes32)) = 0xe248895a233688ba2a70b6f560472dbc27e35ece0d86914f7d43bf2f7df8025b
REPAY_TYPEHASH: public(constant(bytes32)) = 0xd23fe99a7aac398d03952a098faa8889259d062784bd80ea0f159e4af604c045
SET_USING_AS_COLLATERAL_TYPEHASH: public(constant(bytes32)) = 0xd4350e1f25ecd62a35b50e8cd1e00bc34331ae8c728ee4dbb69ecf1023daecf7
UPDATE_USER_RISK_PREMIUM_TYPEHASH: public(constant(bytes32)) = 0x915106098e3eee1fbe90aebcbfd68e931c539495af63e24066ebeebb638d3023
UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH: public(constant(bytes32)) = 0x4a168dd8b32d260d07d6f0be832e23035a65a47f788675b0b02270c68b987886
DOMAIN_TYPEHASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
NAME_HASH: constant(bytes32) = keccak256("SignatureGateway")
VERSION_HASH: constant(bytes32) = keccak256("1")


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
def _verify(signer: address, intent_hash: bytes32, nonce: uint256, deadline: uint256, signature: Bytes[INF]):
    if block.timestamp > deadline or len(signature) != 65:
        raise ISignatureGateway.InvalidSignature()
    digest: bytes32 = keccak256(concat(b"\x19\x01", self._domain_separator(), intent_hash))
    r: bytes32 = convert(slice(signature, 0, 32), bytes32)
    s: bytes32 = convert(slice(signature, 32, 32), bytes32)
    v: uint256 = convert(slice(signature, 64, 1), uint256)
    recovered: address = ecrecover(digest, v, r, s)
    if recovered == empty(address) or recovered != signer:
        raise ISignatureGateway.InvalidSignature()
    NoncesKeyed._use_checked_nonce(signer, nonce)


@internal
@view
def _reserve(spoke: address, reserve_id: uint256) -> ISpoke.Reserve:
    return staticcall ISpoke(spoke).getReserve(reserve_id)


@internal
def _safe_transfer(token: address, to: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(method_id("transfer(address,uint256)"), convert(to, bytes32), convert(amount, bytes32)),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@internal
def _safe_transfer_from(token: address, owner: address, to: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(method_id("transferFrom(address,address,uint256)"), convert(owner, bytes32), convert(to, bytes32), convert(amount, bytes32)),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@internal
def _force_approve(token: address, spender: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(method_id("approve(address,uint256)"), convert(spender, bytes32), convert(amount, bytes32)),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@external
@view
def DOMAIN_SEPARATOR() -> bytes32:
    return self._domain_separator()


@external
@view
def eip712Domain() -> (bytes1, String[32], String[8], uint256, address, bytes32, DynArray[uint256, INF]):
    extensions: DynArray[uint256, INF] = []
    return 0x0f, "SignatureGateway", "1", chain.id, self, empty(bytes32), extensions


@external
def supplyWithSig(params: ISignatureGateway.Action, signature: Bytes[INF]) -> (uint256, uint256):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_action(SUPPLY_TYPEHASH, params.spoke, params.reserveId, params.amount, params.onBehalfOf, params.nonce, params.deadline)
    self._verify(params.onBehalfOf, intent_hash, params.nonce, params.deadline, signature)
    reserve: ISpoke.Reserve = self._reserve(params.spoke, params.reserveId)
    self._safe_transfer_from(reserve.underlying, params.onBehalfOf, self, params.amount)
    self._force_approve(reserve.underlying, params.spoke, params.amount)
    return extcall ISpoke(params.spoke).supply(params.reserveId, params.amount, params.onBehalfOf)


@external
def withdrawWithSig(params: ISignatureGateway.Action, signature: Bytes[INF]) -> (uint256, uint256):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_action(WITHDRAW_TYPEHASH, params.spoke, params.reserveId, params.amount, params.onBehalfOf, params.nonce, params.deadline)
    self._verify(params.onBehalfOf, intent_hash, params.nonce, params.deadline, signature)
    reserve: ISpoke.Reserve = self._reserve(params.spoke, params.reserveId)
    shares: uint256 = 0
    withdrawn: uint256 = 0
    shares, withdrawn = extcall ISpoke(params.spoke).withdraw(params.reserveId, params.amount, params.onBehalfOf)
    self._safe_transfer(reserve.underlying, params.onBehalfOf, withdrawn)
    return shares, withdrawn


@external
def borrowWithSig(params: ISignatureGateway.Action, signature: Bytes[INF]) -> (uint256, uint256):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_action(BORROW_TYPEHASH, params.spoke, params.reserveId, params.amount, params.onBehalfOf, params.nonce, params.deadline)
    self._verify(params.onBehalfOf, intent_hash, params.nonce, params.deadline, signature)
    reserve: ISpoke.Reserve = self._reserve(params.spoke, params.reserveId)
    shares: uint256 = 0
    borrowed: uint256 = 0
    shares, borrowed = extcall ISpoke(params.spoke).borrow(params.reserveId, params.amount, params.onBehalfOf)
    self._safe_transfer(reserve.underlying, params.onBehalfOf, borrowed)
    return shares, borrowed


@external
def repayWithSig(params: ISignatureGateway.Action, signature: Bytes[INF]) -> (uint256, uint256):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_action(REPAY_TYPEHASH, params.spoke, params.reserveId, params.amount, params.onBehalfOf, params.nonce, params.deadline)
    self._verify(params.onBehalfOf, intent_hash, params.nonce, params.deadline, signature)
    reserve: ISpoke.Reserve = self._reserve(params.spoke, params.reserveId)
    debt: uint256 = staticcall ISpoke(params.spoke).getUserTotalDebt(params.reserveId, params.onBehalfOf)
    repay_amount: uint256 = min(params.amount, debt)
    self._safe_transfer_from(reserve.underlying, params.onBehalfOf, self, repay_amount)
    self._force_approve(reserve.underlying, params.spoke, repay_amount)
    return extcall ISpoke(params.spoke).repay(params.reserveId, repay_amount, params.onBehalfOf)


@external
def setUsingAsCollateralWithSig(params: ISignatureGateway.SetUsingAsCollateral, signature: Bytes[INF]):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_collateral(params.spoke, params.reserveId, params.useAsCollateral, params.onBehalfOf, params.nonce, params.deadline)
    self._verify(params.onBehalfOf, intent_hash, params.nonce, params.deadline, signature)
    extcall ISpoke(params.spoke).setUsingAsCollateral(params.reserveId, params.useAsCollateral, params.onBehalfOf)


@external
def updateUserRiskPremiumWithSig(params: ISignatureGateway.UpdateUserConfig, signature: Bytes[INF]):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_update(UPDATE_USER_RISK_PREMIUM_TYPEHASH, params.spoke, params.onBehalfOf, params.nonce, params.deadline)
    self._verify(params.onBehalfOf, intent_hash, params.nonce, params.deadline, signature)
    extcall ISpoke(params.spoke).updateUserRiskPremium(params.onBehalfOf)


@external
def updateUserDynamicConfigWithSig(params: ISignatureGateway.UpdateUserConfig, signature: Bytes[INF]):
    PositionManagerBase._check_registered(params.spoke)
    intent_hash: bytes32 = EIP712Hash.hash_update(UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH, params.spoke, params.onBehalfOf, params.nonce, params.deadline)
    self._verify(params.onBehalfOf, intent_hash, params.nonce, params.deadline, signature)
    extcall ISpoke(params.spoke).updateUserDynamicConfig(params.onBehalfOf)


@external
@payable
def __default__():
    pass
