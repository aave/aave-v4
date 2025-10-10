import "./HubBase.spec";

/***

Advance over-approximations summarization used in additivity rules.

***/

methods {

    function AssetLogic.getFeeShares(
        IHub.Asset storage asset,
        uint256 indexDelta
    ) internal returns (uint256) => SummaryLibrary.getFeeShares(asset, indexDelta);

    function AssetLogic.getDrawnIndex(IHub.Asset storage asset) internal returns (uint256) => SummaryLibrary.getDrawnIndex(asset);

    // todo prove getFeeShares function
    function SummaryLibrary.calcFees(uint256 indexDelta, uint256 totalDrawnShares, uint256 liquidityFee) internal  returns (uint256) => 
    calcFeesApproximation(indexDelta, totalDrawnShares, liquidityFee); 
}

ghost calcFeesApproximation(uint256 /*indexdelta*/, uint256 /* totalSrawnShares*/, uint256 /* liquidityFee*/) returns uint256 {
    axiom forall uint256 indexDelta1. forall uint256 indexDelta2. 
            forall uint256 totalDrawnShares1. forall uint256 totalDrawnShares2.
            forall uint256 liquidityFee. 
            // monotonic on indexDelta 
            ( indexDelta1 > indexDelta2 => calcFeesApproximation(indexDelta1, totalDrawnShares1, liquidityFee) >=
                calcFeesApproximation(indexDelta2, totalDrawnShares1, liquidityFee) ) 
            && 
            // monotonic on totalDrawnShares
            ( totalDrawnShares1 > totalDrawnShares2 => calcFeesApproximation(indexDelta1, totalDrawnShares1, liquidityFee) >=
                calcFeesApproximation(indexDelta1, totalDrawnShares2, liquidityFee) ) 
            && 
            // monotonic on both 
            ( (  indexDelta1 > indexDelta2 && totalDrawnShares1 > totalDrawnShares2) => calcFeesApproximation(indexDelta1, totalDrawnShares1, liquidityFee) >=
                calcFeesApproximation(indexDelta2, totalDrawnShares2, liquidityFee) ) 
            &&
            // max value
            calcFeesApproximation(indexDelta1, totalDrawnShares1, liquidityFee)  <= totalDrawnShares1;
}