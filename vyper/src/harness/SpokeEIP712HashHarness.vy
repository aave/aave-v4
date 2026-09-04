# pragma version 0.5.0b2

from spoke.libraries import EIP712Hash

MAX_UPDATES: constant(uint256) = 256

struct PositionManagerUpdate:
    positionManager: address
    approve: bool

struct SetUserPositionManagers:
    onBehalfOf: address
    updates: DynArray[PositionManagerUpdate, MAX_UPDATES]
    nonce: uint256
    deadline: uint256

struct TokenizedAction:
    actor: address
    amount: uint256
    receiver: address
    nonce: uint256
    deadline: uint256


@external
@pure
def SET_USER_POSITION_MANAGERS_TYPEHASH() -> bytes32: return EIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH
@external
@pure
def POSITION_MANAGER_UPDATE() -> bytes32: return EIP712Hash.POSITION_MANAGER_UPDATE
@external
@pure
def TOKENIZED_DEPOSIT_TYPEHASH() -> bytes32: return EIP712Hash.TOKENIZED_DEPOSIT_TYPEHASH
@external
@pure
def TOKENIZED_MINT_TYPEHASH() -> bytes32: return EIP712Hash.TOKENIZED_MINT_TYPEHASH
@external
@pure
def TOKENIZED_WITHDRAW_TYPEHASH() -> bytes32: return EIP712Hash.TOKENIZED_WITHDRAW_TYPEHASH
@external
@pure
def TOKENIZED_REDEEM_TYPEHASH() -> bytes32: return EIP712Hash.TOKENIZED_REDEEM_TYPEHASH


@external
@pure
def hashPositionManagerUpdate(params: PositionManagerUpdate) -> bytes32:
    return EIP712Hash.hash_position_manager_update(params.positionManager, params.approve)


@external
@pure
def hashSetUserPositionManagers(params: SetUserPositionManagers) -> bytes32:
    packed_hashes: Bytes[8192] = b""
    for update: PositionManagerUpdate in params.updates:
        packed_hashes = convert(
            concat(
                packed_hashes,
                EIP712Hash.hash_position_manager_update(update.positionManager, update.approve),
            ),
            Bytes[8192],
        )
    return keccak256(
        abi_encode(
            EIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
            params.onBehalfOf,
            keccak256(packed_hashes),
            params.nonce,
            params.deadline,
        )
    )


@external
@pure
def hashTokenizedDeposit(params: TokenizedAction) -> bytes32:
    return EIP712Hash.hash_tokenized(EIP712Hash.TOKENIZED_DEPOSIT_TYPEHASH, params.actor, params.amount, params.receiver, params.nonce, params.deadline)

@external
@pure
def hashTokenizedMint(params: TokenizedAction) -> bytes32:
    return EIP712Hash.hash_tokenized(EIP712Hash.TOKENIZED_MINT_TYPEHASH, params.actor, params.amount, params.receiver, params.nonce, params.deadline)

@external
@pure
def hashTokenizedWithdraw(params: TokenizedAction) -> bytes32:
    return EIP712Hash.hash_tokenized(EIP712Hash.TOKENIZED_WITHDRAW_TYPEHASH, params.actor, params.amount, params.receiver, params.nonce, params.deadline)

@external
@pure
def hashTokenizedRedeem(params: TokenizedAction) -> bytes32:
    return EIP712Hash.hash_tokenized(EIP712Hash.TOKENIZED_REDEEM_TYPEHASH, params.actor, params.amount, params.receiver, params.nonce, params.deadline)
