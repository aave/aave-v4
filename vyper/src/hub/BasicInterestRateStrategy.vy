#pragma version 0.5.0b2


@view
@abstract
def _calculate_interest_rate(
    asset_id: uint256,
    liquidity: uint256,
    drawn: uint256,
    deficit: uint256,
    swept: uint256,
) -> uint256:
    ...


@external
@view
def calculateInterestRate(
    assetId: uint256,
    liquidity: uint256,
    drawn: uint256,
    deficit: uint256,
    swept: uint256,
) -> uint256:
    return self._calculate_interest_rate(assetId, liquidity, drawn, deficit, swept)
