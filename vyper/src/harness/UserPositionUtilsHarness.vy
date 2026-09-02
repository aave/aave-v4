# pragma version 0.5.0b1

from spoke.libraries import UserPositionUtils

initializes: UserPositionUtils


interface IHub:
    def getAssetDrawnIndex(assetId: uint256) -> uint256: view


user_position: UserPositionUtils.UserPosition


@external
def setUserPosition(position: UserPositionUtils.UserPosition):
    self.user_position = position


@external
@view
def getUserPosition() -> UserPositionUtils.UserPosition:
    return self.user_position


@external
def applyPremiumDelta(delta: UserPositionUtils.PremiumDelta):
    shares: int256 = convert(self.user_position.premiumShares, int256) + delta.sharesDelta
    offset: int256 = convert(self.user_position.premiumOffsetRay, int256) + delta.offsetRayDelta
    self.user_position.premiumShares = convert(shares, uint120)
    self.user_position.premiumOffsetRay = convert(offset, int200)


@external
@view
def calculatePremiumDelta(
    drawnSharesTaken: uint256,
    drawnIndex: uint256,
    riskPremium: uint256,
    restoredPremiumRay: uint256,
) -> UserPositionUtils.PremiumDelta:
    return UserPositionUtils.calculate_premium_delta(
        self.user_position,
        drawnSharesTaken,
        drawnIndex,
        riskPremium,
        restoredPremiumRay,
    )


@external
@view
def getDebtWithHub(hub: address, assetId: uint256) -> (uint256, uint256):
    drawn_index: uint256 = staticcall IHub(hub).getAssetDrawnIndex(assetId)
    return UserPositionUtils.get_debt(self.user_position, drawn_index)


@external
@view
def getDebt(drawnIndex: uint256) -> (uint256, uint256):
    return UserPositionUtils.get_debt(self.user_position, drawnIndex)


@external
@view
def calculateRestoreAmount(drawnIndex: uint256, amount: uint256) -> (uint256, uint256):
    return UserPositionUtils.calculate_restore_amount(self.user_position, drawnIndex, amount)


@external
@view
def calculatePremiumRay(drawnIndex: uint256) -> uint256:
    return UserPositionUtils.calculate_premium_ray(self.user_position, drawnIndex)
