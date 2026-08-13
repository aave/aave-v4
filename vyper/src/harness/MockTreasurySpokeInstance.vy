# pragma version 0.5.0a3


event OwnershipTransferred:
    previousOwner: indexed(address)
    newOwner: indexed(address)

event Initialized:
    version: uint64


spoke_revision: immutable(uint64)

# Match the ERC-7201 Initializable and OwnableUpgradeable storage namespaces.
owner_address: address
pending_owner_address: address
initialized_state: uint256


@deploy
def __init__(revision: uint64):
    spoke_revision = revision
    self.initialized_state = convert(max_value(uint64), uint256)
    log Initialized(version=max_value(uint64))


@external
@view
def SPOKE_REVISION() -> uint64:
    return spoke_revision


@external
def initialize(owner: address):
    initialized: uint64 = convert(self.initialized_state & (2**64 - 1), uint64)
    initializing: bool = (self.initialized_state & (1 << 64)) != 0
    if initializing or initialized >= spoke_revision:
        raw_revert(method_id("InvalidInitialization()"))
    if owner == empty(address):
        raw_revert(
            concat(
                method_id("OwnableInvalidOwner(address)"),
                convert(owner, bytes32),
            )
        )
    self.initialized_state = convert(spoke_revision, uint256)
    previous_owner: address = self.owner_address
    self.pending_owner_address = empty(address)
    self.owner_address = owner
    log OwnershipTransferred(previousOwner=previous_owner, newOwner=owner)
    log Initialized(version=spoke_revision)


@external
@view
def owner() -> address:
    return self.owner_address


@external
@view
def pendingOwner() -> address:
    return self.pending_owner_address
