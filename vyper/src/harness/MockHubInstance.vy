# pragma version 0.5.0b2
from hub import HubInstance
from hub.interfaces import IHub

initializes: HubInstance
exports: HubInstance.__interface__

@deploy
def __init__():
    HubInstance.__init__()


@external
def setAssetAddedShares(assetId: uint256, addedShares: uint256):
    asset: IHub.Asset = HubInstance._load_asset(assetId)
    asset.addedShares = HubInstance._u120(addedShares)
    HubInstance._store_asset(assetId, asset)
