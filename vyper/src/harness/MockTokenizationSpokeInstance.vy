# pragma version 0.5.0b2
from hub.interfaces import IHub


error InvalidInitialization:
    pass

event SetTokenizationSpokeImmutables:
    hub: indexed(address)
    assetId: indexed(uint256)

event Initialized:
    version: uint64


spoke_revision: immutable(uint64)
HUB: immutable(address)
ASSET_ID: immutable(uint256)

token_name: String[128]
token_symbol: String[128]
initialized_state: uint256


@deploy
def __init__(revision: uint64, hub: address, underlying: address):
    spoke_revision = revision
    HUB = hub
    ASSET_ID = staticcall IHub(hub).getAssetId(underlying)
    self.initialized_state = convert(max_value(uint64), uint256)
    log Initialized(version=max_value(uint64))


@external
@view
def SPOKE_REVISION() -> uint64:
    return spoke_revision


@external
def initialize(shareName: String[128], shareSymbol: String[128]):
    initialized: uint64 = convert(self.initialized_state & (2**64 - 1), uint64)
    if (self.initialized_state & (1 << 64)) != 0 or initialized >= spoke_revision:
        raise InvalidInitialization()
    self.initialized_state = convert(spoke_revision, uint256)
    self.token_name = shareName
    self.token_symbol = shareSymbol
    log SetTokenizationSpokeImmutables(hub=HUB, assetId=ASSET_ID)
    log Initialized(version=spoke_revision)


@external
@view
def name() -> String[128]:
    return self.token_name


@external
@view
def symbol() -> String[128]:
    return self.token_symbol
