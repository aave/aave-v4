/**
 * @title LiquidationLogic_Bonus Spec
 * @notice Specification for LiquidationLogic.calculateLiquidationBonus
 * 
 * The function calculates liquidation bonus based on health factor:
 * - If healthFactor <= healthFactorForMaxBonus: returns maxLiquidationBonus
 * - Otherwise: linear interpolation between minLiquidationBonus and maxLiquidationBonus
 */

using LiquidationLogicHarness as harness;

methods {
    function calculateLiquidationBonus(
        uint256 healthFactorForMaxBonus,
        uint256 liquidationBonusFactor,
        uint256 healthFactor,
        uint256 maxLiquidationBonus
    ) external returns (uint256) envfree;
}

// Constants
definition PERCENTAGE_FACTOR() returns uint256 = 10000; // 100% in BPS
definition HEALTH_FACTOR_LIQUIDATION_THRESHOLD() returns uint256 = 10^18;

/// @title Sanity check - function can succeed
rule sanityCheck() {
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 healthFactor;
    uint256 maxLiquidationBonus;
    
    uint256 result = harness.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        healthFactor,
        maxLiquidationBonus
    );
    
    satisfy true;
}

/**
 * @title When healthFactor <= healthFactorForMaxBonus, returns maxLiquidationBonus
 * @link_property LiquidationLogic library integrity
 */
rule maxBonusWhenLowHealthFactor() {
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 healthFactor;
    uint256 maxLiquidationBonus;
    
    require healthFactor <= healthFactorForMaxBonus;
    
    uint256 result = harness.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        healthFactor,
        maxLiquidationBonus
    );
    
    assert result == maxLiquidationBonus;
}

/**
 * @title Result is always >= PERCENTAGE_FACTOR (no negative bonus)
 * @link_property LiquidationLogic library integrity
 */
rule bonusIsAtLeastNoBonus() {
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 healthFactor;
    uint256 maxLiquidationBonus;
    
    // Preconditions for valid inputs
    require maxLiquidationBonus >= PERCENTAGE_FACTOR();
    require healthFactorForMaxBonus < HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    require healthFactor <= HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    
    uint256 result = harness.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        healthFactor,
        maxLiquidationBonus
    );
    
    assert result >= PERCENTAGE_FACTOR();
}

/**
 * @title Result is always <= maxLiquidationBonus
 * @link_property LiquidationLogic library integrity
 */
rule bonusDoesNotExceedMax() {
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 healthFactor;
    uint256 maxLiquidationBonus;
    
    uint256 result = harness.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        healthFactor,
        maxLiquidationBonus
    );
    
    assert result <= maxLiquidationBonus;
}

/**
 * @title Monotonicity: higher healthFactor results in lower or equal bonus
 * @link_property LiquidationLogic library integrity
 */
rule monotonicityOfBonus() {
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 healthFactor1;
    uint256 healthFactor2;
    uint256 maxLiquidationBonus;
    
    require healthFactor1 < healthFactor2;
    require healthFactor2 <= HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    require healthFactorForMaxBonus < HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    
    uint256 result1 = harness.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        healthFactor1,
        maxLiquidationBonus
    );
    
    uint256 result2 = harness.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        healthFactor2,
        maxLiquidationBonus
    );
    
    assert result1 >= result2;
}

/**
 * @title At threshold, bonus equals minLiquidationBonus
 * @link_property LiquidationLogic library integrity
 */
rule bonusAtThreshold() {
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 maxLiquidationBonus;
    
    require healthFactorForMaxBonus < HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    require maxLiquidationBonus >= PERCENTAGE_FACTOR();
    
    uint256 result = harness.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
        maxLiquidationBonus
    );
    
    // At threshold, should return minLiquidationBonus which is computed as:
    // (maxLiquidationBonus - PERCENTAGE_FACTOR).percentMulDown(liquidationBonusFactor) + PERCENTAGE_FACTOR
    mathint expectedMin = ((maxLiquidationBonus - PERCENTAGE_FACTOR()) * liquidationBonusFactor / PERCENTAGE_FACTOR()) + PERCENTAGE_FACTOR();
    
    assert result == assert_uint256(expectedMin);
}

/**
 * @title Zero bonus factor means min bonus equals PERCENTAGE_FACTOR
 * @link_property LiquidationLogic library integrity
 */
rule zeroBonusFactorMeansNoMinBonus() {
    uint256 healthFactorForMaxBonus;
    uint256 healthFactor;
    uint256 maxLiquidationBonus;
    
    require healthFactor > healthFactorForMaxBonus;
    require healthFactor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    require maxLiquidationBonus >= PERCENTAGE_FACTOR();
    
    uint256 result = harness.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        0, // zero bonus factor
        healthFactor,
        maxLiquidationBonus
    );
    
    assert result == PERCENTAGE_FACTOR();
}

