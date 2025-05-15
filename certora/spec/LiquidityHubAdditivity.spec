
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";
import "./LiquidityHub.spec";

methods {

}

rule addAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    requireAllInvariants(assetId,e);
    storage init = lastStorage;

    add(e, assetId, amountX, from);
    add(e, assetId, amountY, from);
    uint256 afterTwoSteps = getSpokeSuppliedShares(assetId, spoke);

    //expecting the code to enforce that amountX+amountY can not overflow
    add(e, assetId, assert_uint256(amountX + amountY), from)at init;
    uint256 afterOneStep = getSpokeSuppliedShares(assetId, spoke);

    //rounding should be in favor of the house
    assert afterOneStep >= afterTwoSteps;
    satisfy afterOneStep > afterTwoSteps;
}

rule removeAdditivity(uint256 assetId, uint256 amountX, uint256 amountY, address from) {
    env e;
    address spoke = e.msg.sender;
    requireAllInvariants(assetId,e);
    storage init = lastStorage;

    remove(e, assetId, amountX, from);
    remove(e, assetId, amountY, from);
    uint256 afterTwoSteps = getSpokeSuppliedShares(assetId, spoke);

    //expecting the code to enforce that amountX+amountY can not overflow
    remove(e, assetId, assert_uint256(amountX + amountY), from)at init;
    uint256 afterOneStep = getSpokeSuppliedShares(assetId, spoke);

    //rounding should be in favor of the house
    assert afterOneStep >= afterTwoSteps;
    satisfy afterOneStep > afterTwoSteps;
}
