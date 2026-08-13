#pragma version 0.5.0a3


interface IHub:
    def getAssetId(underlying: address) -> uint256: view
    def getSpokeAddedAssets(assetId: uint256, spoke: address) -> uint256: view
    def getSpokeAddedShares(assetId: uint256, spoke: address) -> uint256: view
    def add(assetId: uint256, amount: uint256) -> uint256: nonpayable
    def remove(assetId: uint256, amount: uint256, to: address) -> uint256: nonpayable


event OwnershipTransferred:
    previousOwner: indexed(address)
    newOwner: indexed(address)


event OwnershipTransferStarted:
    previousOwner: indexed(address)
    newOwner: indexed(address)


event Initialized:
    version: uint64


SPOKE_REVISION: public(constant(uint64)) = 1

# These variables are assigned to their matching ERC-7201 namespaces by the build layout.
owner_address: address
pending_owner_address: address
initialized_state: uint256


@internal
@view
def _check_owner():
    if msg.sender != self.owner_address:
        raw_revert(
            concat(
                method_id("OwnableUnauthorizedAccount(address)"),
                convert(msg.sender, bytes32),
            )
        )


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
def _supply(hub: address, underlying: address, amount: uint256, skim: bool) -> (uint256, uint256):
    asset_id: uint256 = staticcall IHub(hub).getAssetId(underlying)
    if not skim:
        self._safe_transfer_from(underlying, msg.sender, hub, amount)
    shares: uint256 = extcall IHub(hub).add(asset_id, amount)
    return shares, amount


@deploy
def __init__():
    self.initialized_state = convert(max_value(uint64), uint256)
    log Initialized(version=max_value(uint64))


@external
def initialize(owner: address):
    initialized: uint64 = convert(self.initialized_state & (2**64 - 1), uint64)
    initializing: bool = (self.initialized_state & (1 << 64)) != 0
    if initializing or initialized >= SPOKE_REVISION:
        raw_revert(method_id("InvalidInitialization()"))
    if owner == empty(address):
        raw_revert(
            concat(
                method_id("OwnableInvalidOwner(address)"),
                convert(owner, bytes32),
            )
        )

    self.initialized_state = convert(SPOKE_REVISION, uint256)
    previous_owner: address = self.owner_address
    self.pending_owner_address = empty(address)
    self.owner_address = owner
    log OwnershipTransferred(previousOwner=previous_owner, newOwner=owner)
    log Initialized(version=SPOKE_REVISION)


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
    log OwnershipTransferStarted(previousOwner=self.owner_address, newOwner=newOwner)


@external
def acceptOwnership():
    if msg.sender != self.pending_owner_address:
        raw_revert(
            concat(
                method_id("OwnableUnauthorizedAccount(address)"),
                convert(msg.sender, bytes32),
            )
        )
    previous_owner: address = self.owner_address
    self.pending_owner_address = empty(address)
    self.owner_address = msg.sender
    log OwnershipTransferred(previousOwner=previous_owner, newOwner=msg.sender)


@external
def renounceOwnership():
    self._check_owner()
    previous_owner: address = self.owner_address
    self.pending_owner_address = empty(address)
    self.owner_address = empty(address)
    log OwnershipTransferred(previousOwner=previous_owner, newOwner=empty(address))


@external
def supply(hub: address, underlying: address, amount: uint256) -> (uint256, uint256):
    self._check_owner()
    return self._supply(hub, underlying, amount, False)


@external
def supplySkimmed(hub: address, underlying: address, amount: uint256) -> (uint256, uint256):
    self._check_owner()
    return self._supply(hub, underlying, amount, True)


@external
def withdraw(hub: address, underlying: address, amount: uint256) -> (uint256, uint256):
    self._check_owner()
    asset_id: uint256 = staticcall IHub(hub).getAssetId(underlying)
    supplied_assets: uint256 = staticcall IHub(hub).getSpokeAddedAssets(asset_id, self)
    withdrawn_amount: uint256 = min(amount, supplied_assets)
    withdrawn_shares: uint256 = extcall IHub(hub).remove(asset_id, withdrawn_amount, msg.sender)
    return withdrawn_shares, withdrawn_amount


@external
def transfer(token: address, to: address, amount: uint256):
    self._check_owner()
    self._safe_transfer(token, to, amount)


@external
@view
def getSuppliedAssets(hub: address, underlying: address) -> uint256:
    asset_id: uint256 = staticcall IHub(hub).getAssetId(underlying)
    return staticcall IHub(hub).getSpokeAddedAssets(asset_id, self)


@external
@view
def getSuppliedShares(hub: address, underlying: address) -> uint256:
    asset_id: uint256 = staticcall IHub(hub).getAssetId(underlying)
    return staticcall IHub(hub).getSpokeAddedShares(asset_id, self)
