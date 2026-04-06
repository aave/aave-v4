
methods {
    function _.previewRemoveByShares(uint256 assetId, uint256 shares) external with (env e) => previewRemoveBySharesCVL(assetId, shares, e) expect uint256;

    function _.previewAddByAssets(uint256 assetId, uint256 assets) external with (env e) => previewAddByAssetsCVL(assetId, assets, e) expect uint256;

    function _.previewRemoveByAssets(uint256 assetId, uint256 assets) external with (env e) => previewRemoveByAssetsCVL(assetId, assets, e) expect uint256;

    function _.previewDrawByShares(uint256 assetId, uint256 shares) external with (env e) => previewDrawBySharesCVL(assetId, shares, e) expect uint256;

    function _.previewRestoreByShares(uint256 assetId, uint256 shares) external with (env e) => previewRestoreBySharesCVL(assetId, shares, e) expect uint256;

    function _.getAssetDrawnIndex(uint256 assetId) external with (env e) => getAssetDrawnIndexCVL(assetId, e) expect uint256;


// Supply Operations
    function _.add(uint256 assetId, uint256 amount) external with (env e) => addSummaryCVL(assetId, amount, e) expect uint256;
// Withdraw Operations  
    function _.remove(uint256 assetId, uint256 amount, address to) external with (env e) => removeSummaryCVL(assetId, amount, to, e) expect uint256;
// Borrow Operations
    function _.draw(uint256 assetId, uint256 amount, address to) external with (env e) => drawSummaryCVL(assetId, amount, to, e) expect uint256;
// Repay Operations
    function _.restore(uint256 assetId, uint256 drawnAmount, IHubBase.PremiumDelta premiumDelta) external with (env e) => restoreSummaryCVL(assetId, drawnAmount, premiumDelta, e) expect uint256;
// Report Deficit Operations
    function _.reportDeficit(uint256 assetId, uint256 drawnAmount, IHubBase.PremiumDelta premiumDelta) external with (env e) => previewRestoreByAssetsCVL(assetId, drawnAmount, e) expect uint256;
// Eliminate Deficit Operations
    function _.eliminateDeficit(uint256 assetId, uint256 amount, address spokeAddress) external with (env e)  => previewRemoveByAssetsCVL(assetId, amount, e) expect uint256; 
//refresh premium
    function _.refreshPremium(uint256 assetId, IHubBase.PremiumDelta premiumDelta) external => HAVOC_ECF;

// Pay Fee Shares Operations
    function _.payFeeShares(uint256 assetId, uint256 shares) external => NONDET;

    function _.getAssetUnderlyingAndDecimals(uint256 assetId) external => getAssetUnderlyingAndDecimalsCVL(assetId) expect (address, uint8);

}


// symbolic debt index: for each assetId and block timestamp there is an index
// the index is monotonic increasing
persistent ghost mapping(uint256 /*assetId */ => mapping(uint256 /* blockTimestamp */ => uint256)) indexOfAssetPerBlock {
    axiom forall uint256 assetId. forall uint256 blockTimestamp. forall uint256 blockTimestamp2.
        blockTimestamp < blockTimestamp2 => indexOfAssetPerBlock[assetId][blockTimestamp] <= indexOfAssetPerBlock[assetId][blockTimestamp2];
    axiom forall uint256 assetId. forall uint256 blockTimestamp. indexOfAssetPerBlock[assetId][blockTimestamp] >= RAY;
}

// symbolic assets to share ratio:
persistent ghost mapping(uint256 /*assetId */ => mapping(uint256 /*blockTimestamp*/ => uint256)) shareToAssetsRatio {
    axiom forall uint256 assetId. forall uint256 blockTimestamp. forall uint256 blockTimestamp2.
        blockTimestamp < blockTimestamp2 => shareToAssetsRatio[assetId][blockTimestamp] <= shareToAssetsRatio[assetId][blockTimestamp2];
    // at least RAY assets per share
    axiom forall uint256 assetId. forall uint256 blockTimestamp. shareToAssetsRatio[assetId][blockTimestamp] >= RAY;
}

// toAddedSharesDown : assets.toSharesDown(asset.totalAddedAssets(), asset.totalAddedShares());
function previewAddByAssetsCVL(uint256 assetId, uint256 assets, env e) returns (uint256) {
    uint256 ratio = shareToAssetsRatio[assetId][e.block.timestamp];
    return require_uint256(((assets * RAY) + ratio -1) / ratio);
}

// toAddedAssetsDown : shares.toAssetsDown(asset.totalAddedAssets(), asset.totalAddedShares());
function previewRemoveBySharesCVL(uint256 assetId, uint256 shares, env e) returns (uint256) {
    uint256 ratio = shareToAssetsRatio[assetId][e.block.timestamp];
    return require_uint256(shares * ratio / RAY);
}

// toAddedSharesUp :assets.toSharesUp(asset.totalAddedAssets(), asset.totalAddedShares());
function previewRemoveByAssetsCVL(uint256 assetId, uint256 assets, env e) returns (uint256) {
    uint256 ratio = shareToAssetsRatio[assetId][e.block.timestamp];
    return require_uint256(((assets * RAY) + ratio -1) / ratio);
}

// toDrawnAssetsDown : shares.rayMulDown(asset.getDrawnIndex())
function previewDrawBySharesCVL(uint256 assetId, uint256 shares, env e) returns (uint256) {
    uint256 ratio = indexOfAssetPerBlock[assetId][e.block.timestamp];
    return require_uint256((shares * ratio) / RAY);
}

// toDrawnSharesUp : assets.rayDivUp(asset.getDrawnIndex())
function previewDrawByAssetsCVL(uint256 assetId, uint256 assets, env e) returns (uint256) {
    uint256 ratio = indexOfAssetPerBlock[assetId][e.block.timestamp];
    return require_uint256(((assets * RAY) + ratio -1) / ratio);

}
// toDrawnAssetsUp : shares.rayMulUp(asset.getDrawnIndex());
function previewRestoreBySharesCVL(uint256 assetId, uint256 shares, env e) returns (uint256) {
    uint256 ratio = indexOfAssetPerBlock[assetId][e.block.timestamp];
    return require_uint256(((shares * ratio) + RAY - 1) / RAY);
}

// toDrawnSharesDown : assets.rayDivDown(asset.getDrawnIndex());
function previewRestoreByAssetsCVL(uint256 assetId, uint256 assets, env e) returns (uint256) {
    uint256 ratio = indexOfAssetPerBlock[assetId][e.block.timestamp];
    return require_uint256(((assets * RAY) + ratio -1) / ratio);
}

// getAssetDrawnIndex: returns the drawn index for an asset at a given block timestamp
function getAssetDrawnIndexCVL(uint256 assetId, env e) returns (uint256) {
    return indexOfAssetPerBlock[assetId][e.block.timestamp];
}

// CVL function summarizations for Hub operations with zero amount checks
function addSummaryCVL(uint256 assetId, uint256 amount, env e) returns (uint256) {
    require amount > 0;
    // Return computed shares based on amount and asset using existing preview function
    return previewAddByAssetsCVL(assetId, amount, e);
}

function removeSummaryCVL(uint256 assetId, uint256 amount, address to, env e) returns (uint256) {
    require amount > 0;
    // Return computed shares based on amount and asset using existing preview function
    return previewRemoveByAssetsCVL(assetId, amount, e);
}

function drawSummaryCVL(uint256 assetId, uint256 amount, address to, env e) returns (uint256) {
    require amount > 0;
    // Return computed drawn shares based on amount and asset using existing preview function
    return previewDrawByAssetsCVL(assetId, amount, e);
}

function restoreSummaryCVL(uint256 assetId, uint256 drawnAmount, IHubBase.PremiumDelta premiumDelta,  env e) returns (uint256) {
    require drawnAmount > 0 ;
    // Return computed restored shares based on drawn amount using existing preview function
    return previewRestoreByAssetsCVL(assetId, drawnAmount, e);
}


ghost mapping(uint256 /*assetId*/ => address /*underlying*/) assetUnderlying;

ghost mapping(uint256 /*assetId*/ => uint8 /*decimals*/) assetDecimals;

function getAssetUnderlyingAndDecimalsCVL(uint256 assetId) returns (address, uint8) {
    return (assetUnderlying[assetId], assetDecimals[assetId]);
}
