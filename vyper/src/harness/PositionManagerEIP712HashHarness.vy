# pragma version 0.5.0b2

from position_manager.libraries import EIP712Hash

struct Action:
    spoke: address
    reserveId: uint256
    amount: uint256
    onBehalfOf: address
    nonce: uint256
    deadline: uint256

struct SetUsingAsCollateral:
    spoke: address
    reserveId: uint256
    useAsCollateral: bool
    onBehalfOf: address
    nonce: uint256
    deadline: uint256

struct UpdateUserConfig:
    spoke: address
    onBehalfOf: address
    nonce: uint256
    deadline: uint256

struct ReservePermit:
    spoke: address
    reserveId: uint256
    owner: address
    spender: address
    amount: uint256
    nonce: uint256
    deadline: uint256


@external
@pure
def SUPPLY_TYPEHASH() -> bytes32: return EIP712Hash.SUPPLY_TYPEHASH
@external
@pure
def WITHDRAW_TYPEHASH() -> bytes32: return EIP712Hash.WITHDRAW_TYPEHASH
@external
@pure
def BORROW_TYPEHASH() -> bytes32: return EIP712Hash.BORROW_TYPEHASH
@external
@pure
def REPAY_TYPEHASH() -> bytes32: return EIP712Hash.REPAY_TYPEHASH
@external
@pure
def SET_USING_AS_COLLATERAL_TYPEHASH() -> bytes32: return EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH
@external
@pure
def UPDATE_USER_RISK_PREMIUM_TYPEHASH() -> bytes32: return EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH
@external
@pure
def UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH() -> bytes32: return EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH
@external
@pure
def WITHDRAW_PERMIT_TYPEHASH() -> bytes32: return EIP712Hash.WITHDRAW_PERMIT_TYPEHASH
@external
@pure
def BORROW_PERMIT_TYPEHASH() -> bytes32: return EIP712Hash.BORROW_PERMIT_TYPEHASH


@external
@pure
def hashSupply(params: Action) -> bytes32:
    return EIP712Hash.hash_action(EIP712Hash.SUPPLY_TYPEHASH, params.spoke, params.reserveId, params.amount, params.onBehalfOf, params.nonce, params.deadline)

@external
@pure
def hashWithdraw(params: Action) -> bytes32:
    return EIP712Hash.hash_action(EIP712Hash.WITHDRAW_TYPEHASH, params.spoke, params.reserveId, params.amount, params.onBehalfOf, params.nonce, params.deadline)

@external
@pure
def hashBorrow(params: Action) -> bytes32:
    return EIP712Hash.hash_action(EIP712Hash.BORROW_TYPEHASH, params.spoke, params.reserveId, params.amount, params.onBehalfOf, params.nonce, params.deadline)

@external
@pure
def hashRepay(params: Action) -> bytes32:
    return EIP712Hash.hash_action(EIP712Hash.REPAY_TYPEHASH, params.spoke, params.reserveId, params.amount, params.onBehalfOf, params.nonce, params.deadline)

@external
@pure
def hashSetUsingAsCollateral(params: SetUsingAsCollateral) -> bytes32:
    return EIP712Hash.hash_collateral(params.spoke, params.reserveId, params.useAsCollateral, params.onBehalfOf, params.nonce, params.deadline)

@external
@pure
def hashUpdateUserRiskPremium(params: UpdateUserConfig) -> bytes32:
    return EIP712Hash.hash_update(EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH, params.spoke, params.onBehalfOf, params.nonce, params.deadline)

@external
@pure
def hashUpdateUserDynamicConfig(params: UpdateUserConfig) -> bytes32:
    return EIP712Hash.hash_update(EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH, params.spoke, params.onBehalfOf, params.nonce, params.deadline)

@external
@pure
def hashWithdrawPermit(params: ReservePermit) -> bytes32:
    return EIP712Hash.hash_reserve_permit(EIP712Hash.WITHDRAW_PERMIT_TYPEHASH, params.spoke, params.reserveId, params.owner, params.spender, params.amount, params.nonce, params.deadline)

@external
@pure
def hashBorrowPermit(params: ReservePermit) -> bytes32:
    return EIP712Hash.hash_reserve_permit(EIP712Hash.BORROW_PERMIT_TYPEHASH, params.spoke, params.reserveId, params.owner, params.spender, params.amount, params.nonce, params.deadline)
