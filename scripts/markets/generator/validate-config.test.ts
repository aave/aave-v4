import {describe, it, expect} from 'bun:test';
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {validate, type DeployConfig, type ValidationResult} from './validate-config.ts';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROD_CONFIG = JSON.parse(
  fs.readFileSync(path.resolve(__dirname, '../ethereum/config/config.json'), 'utf8'),
);

// ── Helpers ──────────────────────────────────────────────────────────────────

function minimal(): DeployConfig {
  return {
    defaults: {
      spokeRegistration: {riskPremiumThreshold: 100000, active: true, halted: false},
      reserve: {receiveSharesEnabled: true, frozen: false, paused: false},
    },
    tokens: {
      WETH: {
        address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
        priceFeed: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
      },
      USDC: {
        address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
        priceFeed: '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6',
      },
    },
    hubs: [{key: 'HUB_A'}],
    spokes: [{key: 'SPOKE_A'}],
    assets: [
      {
        tokenKey: 'WETH',
        hubKey: 'HUB_A',
        liquidityFee: 1000,
        irData: {
          optimalUsageRatio: 9000,
          baseDrawnRate: 0,
          rateGrowthBeforeOptimal: 270,
          rateGrowthAfterOptimal: 8000,
        },
      },
      {
        tokenKey: 'USDC',
        hubKey: 'HUB_A',
        liquidityFee: 1000,
        irData: {
          optimalUsageRatio: 9200,
          baseDrawnRate: 0,
          rateGrowthBeforeOptimal: 550,
          rateGrowthAfterOptimal: 3500,
        },
      },
    ],
    spokeRegistrations: [
      {assetKey: 'WETH', hubKey: 'HUB_A', spokeKey: 'SPOKE_A', addCap: 225, drawCap: 200},
      {assetKey: 'USDC', hubKey: 'HUB_A', spokeKey: 'SPOKE_A', addCap: 3000000, drawCap: 2760000},
    ],
    reserves: [
      {
        spokeKey: 'SPOKE_A',
        hubKey: 'HUB_A',
        assetKey: 'WETH',
        collateralRisk: 0,
        borrowable: true,
        collateralFactor: 8500,
        maxLiquidationBonus: 10500,
        liquidationFee: 1000,
      },
      {
        spokeKey: 'SPOKE_A',
        hubKey: 'HUB_A',
        assetKey: 'USDC',
        collateralRisk: 0,
        borrowable: true,
        collateralFactor: 8300,
        maxLiquidationBonus: 10000,
        liquidationFee: 1000,
      },
    ],
    periphery: {
      nativeTokenKey: 'WETH',
      deploySignatureGateway: true,
      deployNativeTokenGateway: true,
    },
  };
}

function clone<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj));
}

function hasError(result: ValidationResult, code: string) {
  return result.errors.some((e) => e.code === code);
}
function hasWarning(result: ValidationResult, code: string) {
  return result.warnings.some((w) => w.code === code);
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('baseline', () => {
  it('minimal clean config produces no errors or warnings', () => {
    const result = validate(minimal());
    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toHaveLength(0);
  });

  it('production ethereum config.json has no errors or warnings', () => {
    const result = validate(PROD_CONFIG);
    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toHaveLength(0);
  });
});

describe('E1: invalid token reference', () => {
  it('detects bad tokenKey in assets', () => {
    const c: any = clone(minimal());
    c.assets[0].tokenKey = 'NONEXISTENT';
    expect(hasError(validate(c), 'E1')).toBe(true);
  });

  it('detects bad assetKey in spokeRegistrations', () => {
    const c: any = clone(minimal());
    c.spokeRegistrations[0].assetKey = 'NONEXISTENT';
    expect(hasError(validate(c), 'E1')).toBe(true);
  });

  it('detects bad assetKey in reserves', () => {
    const c: any = clone(minimal());
    c.reserves[0].assetKey = 'NONEXISTENT';
    expect(hasError(validate(c), 'E1')).toBe(true);
  });
});

describe('E2: invalid hub reference', () => {
  it('detects bad hubKey in assets', () => {
    const c: any = clone(minimal());
    c.assets[0].hubKey = 'BAD_HUB';
    expect(hasError(validate(c), 'E2')).toBe(true);
  });

  it('detects bad hubKey in spokeRegistrations', () => {
    const c: any = clone(minimal());
    c.spokeRegistrations[0].hubKey = 'BAD_HUB';
    expect(hasError(validate(c), 'E2')).toBe(true);
  });

  it('detects bad hubKey in reserves', () => {
    const c: any = clone(minimal());
    c.reserves[0].hubKey = 'BAD_HUB';
    expect(hasError(validate(c), 'E2')).toBe(true);
  });
});

describe('E3: invalid spoke reference', () => {
  it('detects bad spokeKey in spokeRegistrations', () => {
    const c: any = clone(minimal());
    c.spokeRegistrations[0].spokeKey = 'BAD_SPOKE';
    expect(hasError(validate(c), 'E3')).toBe(true);
  });

  it('detects bad spokeKey in reserves', () => {
    const c: any = clone(minimal());
    c.reserves[0].spokeKey = 'BAD_SPOKE';
    expect(hasError(validate(c), 'E3')).toBe(true);
  });
});

describe('E4: duplicate asset', () => {
  it('detects same tokenKey+hubKey twice', () => {
    const c = clone(minimal());
    c.assets.push({...c.assets[0]});
    expect(hasError(validate(c), 'E4')).toBe(true);
  });
});

describe('E5: duplicate spoke registration', () => {
  it('detects same assetKey+hubKey+spokeKey twice', () => {
    const c = clone(minimal());
    c.spokeRegistrations.push({...c.spokeRegistrations[0]});
    expect(hasError(validate(c), 'E5')).toBe(true);
  });
});

describe('E6: duplicate reserve', () => {
  it('detects same spokeKey+hubKey+assetKey twice', () => {
    const c = clone(minimal());
    c.reserves.push({...c.reserves[0]});
    expect(hasError(validate(c), 'E6')).toBe(true);
  });
});

describe('E7: missing asset for spoke registration', () => {
  it('detects spoke reg referencing non-existent asset', () => {
    const c = clone(minimal());
    c.hubs.push({key: 'HUB_B'});
    c.spokeRegistrations.push({
      assetKey: 'WETH',
      hubKey: 'HUB_B',
      spokeKey: 'SPOKE_A',
      addCap: 100,
      drawCap: 50,
    });
    expect(hasError(validate(c), 'E7')).toBe(true);
  });
});

describe('E8: missing asset for reserve', () => {
  it('detects reserve referencing non-existent asset', () => {
    const c = clone(minimal());
    c.hubs.push({key: 'HUB_B'});
    c.spokeRegistrations.push({
      assetKey: 'WETH',
      hubKey: 'HUB_B',
      spokeKey: 'SPOKE_A',
      addCap: 100,
      drawCap: 50,
    });
    c.reserves.push({
      spokeKey: 'SPOKE_A',
      hubKey: 'HUB_B',
      assetKey: 'WETH',
      collateralRisk: 0,
      borrowable: true,
      collateralFactor: 8500,
      maxLiquidationBonus: 10500,
      liquidationFee: 1000,
    });
    expect(hasError(validate(c), 'E8')).toBe(true);
  });
});

describe('E9: missing spoke registration for reserve', () => {
  it('detects reserve without spoke registration', () => {
    const c = clone(minimal());
    c.spokes.push({key: 'SPOKE_B'});
    c.reserves.push({
      spokeKey: 'SPOKE_B',
      hubKey: 'HUB_A',
      assetKey: 'WETH',
      collateralRisk: 0,
      borrowable: true,
      collateralFactor: 8500,
      maxLiquidationBonus: 10500,
      liquidationFee: 1000,
    });
    expect(hasError(validate(c), 'E9')).toBe(true);
  });
});

describe('E10: collateralFactor >= 10000', () => {
  it('detects collateralFactor = 10000', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 10000;
    expect(hasError(validate(c), 'E10')).toBe(true);
  });

  it('detects collateralFactor = 15000', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 15000;
    expect(hasError(validate(c), 'E10')).toBe(true);
  });

  it('accepts collateralFactor = 9999', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 9999;
    expect(hasError(validate(c), 'E10')).toBe(false);
  });
});

describe('E11: maxLiquidationBonus < 10000', () => {
  it('detects maxLiquidationBonus = 9999', () => {
    const c = clone(minimal());
    c.reserves[0].maxLiquidationBonus = 9999;
    expect(hasError(validate(c), 'E11')).toBe(true);
  });

  it('detects maxLiquidationBonus = 0', () => {
    const c = clone(minimal());
    c.reserves[0].maxLiquidationBonus = 0;
    expect(hasError(validate(c), 'E11')).toBe(true);
  });

  it('accepts maxLiquidationBonus = 10000', () => {
    const c = clone(minimal());
    c.reserves[0].maxLiquidationBonus = 10000;
    c.reserves[0].collateralFactor = 0;
    expect(hasError(validate(c), 'E11')).toBe(false);
  });
});

describe('E12: percentMulUp(bonus, factor) >= 10000', () => {
  it('detects bonus * factor too high (12000 * 9000)', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 9000;
    c.reserves[0].maxLiquidationBonus = 12000;
    expect(hasError(validate(c), 'E12')).toBe(true);
  });

  it('detects boundary case (11765 * 8500 -> ceil = 10001)', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 8500;
    c.reserves[0].maxLiquidationBonus = 11765;
    expect(hasError(validate(c), 'E12')).toBe(true);
  });

  it('does not fire when collateralFactor=0', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 0;
    c.reserves[0].maxLiquidationBonus = 10000;
    expect(hasError(validate(c), 'E12')).toBe(false);
  });

  it('accepts valid combo (8500 / 10500 -> 8925 < 10000)', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 8500;
    c.reserves[0].maxLiquidationBonus = 10500;
    expect(hasError(validate(c), 'E12')).toBe(false);
  });
});

describe('E13: liquidationFee > 10000', () => {
  it('detects liquidationFee = 10001', () => {
    const c = clone(minimal());
    c.reserves[0].liquidationFee = 10001;
    expect(hasError(validate(c), 'E13')).toBe(true);
  });

  it('accepts liquidationFee = 10000', () => {
    const c = clone(minimal());
    c.reserves[0].liquidationFee = 10000;
    expect(hasError(validate(c), 'E13')).toBe(false);
  });
});

describe('E14: liquidityFee > 10000', () => {
  it('detects liquidityFee = 20000', () => {
    const c = clone(minimal());
    c.assets[0].liquidityFee = 20000;
    expect(hasError(validate(c), 'E14')).toBe(true);
  });

  it('accepts liquidityFee = 10000', () => {
    const c = clone(minimal());
    c.assets[0].liquidityFee = 10000;
    expect(hasError(validate(c), 'E14')).toBe(false);
  });
});

describe('E15: collateralRisk > 100000', () => {
  it('detects collateralRisk = 100001', () => {
    const c = clone(minimal());
    c.reserves[0].collateralRisk = 100001;
    expect(hasError(validate(c), 'E15')).toBe(true);
  });

  it('accepts collateralRisk = 100000', () => {
    const c = clone(minimal());
    c.reserves[0].collateralRisk = 100000;
    expect(hasError(validate(c), 'E15')).toBe(false);
  });
});

describe('E16: optimalUsageRatio bounds [100, 9900]', () => {
  it('detects optimalUsageRatio = 15000 (too high)', () => {
    const c = clone(minimal());
    c.assets[0].irData!.optimalUsageRatio = 15000;
    expect(hasError(validate(c), 'E16')).toBe(true);
  });

  it('detects optimalUsageRatio = 10000 (above max 9900)', () => {
    const c = clone(minimal());
    c.assets[0].irData!.optimalUsageRatio = 10000;
    expect(hasError(validate(c), 'E16')).toBe(true);
  });

  it('detects optimalUsageRatio = 9901', () => {
    const c = clone(minimal());
    c.assets[0].irData!.optimalUsageRatio = 9901;
    expect(hasError(validate(c), 'E16')).toBe(true);
  });

  it('detects optimalUsageRatio = 99 (below min 100)', () => {
    const c = clone(minimal());
    c.assets[0].irData!.optimalUsageRatio = 99;
    expect(hasError(validate(c), 'E16')).toBe(true);
  });

  it('detects optimalUsageRatio = 0', () => {
    const c = clone(minimal());
    c.assets[0].irData!.optimalUsageRatio = 0;
    expect(hasError(validate(c), 'E16')).toBe(true);
  });

  it('accepts optimalUsageRatio = 100 (min boundary)', () => {
    const c = clone(minimal());
    c.assets[0].irData!.optimalUsageRatio = 100;
    expect(hasError(validate(c), 'E16')).toBe(false);
  });

  it('accepts optimalUsageRatio = 9900 (max boundary)', () => {
    const c = clone(minimal());
    c.assets[0].irData!.optimalUsageRatio = 9900;
    expect(hasError(validate(c), 'E16')).toBe(false);
  });
});

describe('E17: periphery.nativeTokenKey not in tokens', () => {
  it('detects bad nativeTokenKey', () => {
    const c = clone(minimal());
    c.periphery!.nativeTokenKey = 'MISSING_TOKEN';
    expect(hasError(validate(c), 'E17')).toBe(true);
  });
});

describe('E18: borrowable but drawCap=0', () => {
  it('errors when borrowable=true and drawCap=0', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].drawCap = 0;
    expect(hasError(validate(c), 'E18')).toBe(true);
  });

  it('no error when borrowable=false', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].drawCap = 0;
    c.reserves[0].borrowable = false;
    expect(hasError(validate(c), 'E18')).toBe(false);
  });
});

describe('W2: collateralFactor > 0 but addCap=0', () => {
  it('warns when collateralFactor>0 and addCap=0', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].addCap = 0;
    expect(hasWarning(validate(c), 'W2')).toBe(true);
  });

  it('no warning when collateralFactor=0', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].addCap = 0;
    c.reserves[0].collateralFactor = 0;
    c.reserves[0].maxLiquidationBonus = 10000;
    expect(hasWarning(validate(c), 'W2')).toBe(false);
  });
});

describe('W3: drawCap > 0 but reserve not borrowable', () => {
  it('warns when drawCap>0 and borrowable=false', () => {
    const c = clone(minimal());
    c.reserves[0].borrowable = false;
    expect(hasWarning(validate(c), 'W3')).toBe(true);
  });

  it('no warning when borrowable=true', () => {
    const c = clone(minimal());
    expect(hasWarning(validate(c), 'W3')).toBe(false);
  });
});

describe('W4: collateralFactor=0 AND borrowable=false', () => {
  it('warns on useless reserve', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 0;
    c.reserves[0].borrowable = false;
    c.reserves[0].maxLiquidationBonus = 10000;
    expect(hasWarning(validate(c), 'W4')).toBe(true);
  });

  it('no warning when borrowable=true', () => {
    const c = clone(minimal());
    c.reserves[0].collateralFactor = 0;
    c.reserves[0].borrowable = true;
    c.reserves[0].maxLiquidationBonus = 10000;
    expect(hasWarning(validate(c), 'W4')).toBe(false);
  });

  it('no warning when collateralFactor>0', () => {
    const c = clone(minimal());
    c.reserves[0].borrowable = false;
    expect(hasWarning(validate(c), 'W4')).toBe(false);
  });
});

describe('W6: spoke registration with no reserve', () => {
  it('warns on orphan spoke registration', () => {
    const c = clone(minimal());
    c.tokens['AAVE'] = {
      address: '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9',
      priceFeed: '0xbd7F896e60B650C01caf2d7279a1148189A68884',
    };
    c.assets.push({
      tokenKey: 'AAVE',
      hubKey: 'HUB_A',
      liquidityFee: 1000,
      irData: {
        optimalUsageRatio: 4500,
        baseDrawnRate: 0,
        rateGrowthBeforeOptimal: 550,
        rateGrowthAfterOptimal: 30000,
      },
    });
    c.spokeRegistrations.push({
      assetKey: 'AAVE',
      hubKey: 'HUB_A',
      spokeKey: 'SPOKE_A',
      addCap: 100,
      drawCap: 50,
    });
    expect(hasWarning(validate(c), 'W6')).toBe(true);
  });
});

describe('W7: mock price feed', () => {
  it('warns on zero-address price feed used in reserves', () => {
    const c = clone(minimal());
    c.tokens.WETH.priceFeed = '0x0000000000000000000000000000000000000000';
    expect(hasWarning(validate(c), 'W7')).toBe(true);
  });

  it('no warning when mock token not used in any reserve', () => {
    const c = clone(minimal());
    c.tokens['MOCK'] = {
      address: '0x1111111111111111111111111111111111111111',
      priceFeed: '0x0000000000000000000000000000000000000000',
    };
    expect(hasWarning(validate(c), 'W7')).toBe(false);
  });
});

describe('E19: tokenize drawCap must be 0', () => {
  it('errors when per-asset drawCap is non-zero', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {drawCap: 100};
    expect(hasError(validate(c), 'E19')).toBe(true);
  });

  it('errors when defaults.tokenize.drawCap is non-zero', () => {
    const c = clone(minimal());
    c.defaults = {...c.defaults, tokenize: {drawCap: 1000}};
    expect(hasError(validate(c), 'E19')).toBe(true);
  });

  it('no error when drawCap is 0', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {drawCap: 0};
    expect(hasError(validate(c), 'E19')).toBe(false);
  });

  it('no error when drawCap is omitted', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {enabled: true};
    expect(hasError(validate(c), 'E19')).toBe(false);
  });

  it('no error when tokenize is absent', () => {
    const c = clone(minimal());
    expect(hasError(validate(c), 'E19')).toBe(false);
  });
});

describe('E20: unknown keys (via Zod strict)', () => {
  it('errors on unknown key in defaults.tokenize', () => {
    const c: any = clone(minimal());
    c.defaults.tokenize = {enabled: true, foo: 123};
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in per-asset tokenize', () => {
    const c: any = clone(minimal());
    c.assets[0].tokenize = {enabled: true, riskPremium: 500};
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('no error with only allowed tokenize keys', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {enabled: true, addCap: 500};
    expect(hasError(validate(c), 'E20')).toBe(false);
  });

  it('errors on unknown top-level key', () => {
    const c: any = clone(minimal());
    c.extraField = true;
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in defaults', () => {
    const c: any = clone(minimal());
    c.defaults.foo = {};
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in defaults.spoke', () => {
    const c: any = clone(minimal());
    c.defaults.spoke = {oracleDecimals: 8, badKey: 1};
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in defaults.spoke.liquidationConfig', () => {
    const c: any = clone(minimal());
    c.defaults.spoke = {liquidationConfig: {targetHealthFactor: '1050000000000000000', extra: 1}};
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in defaults.reserve', () => {
    const c: any = clone(minimal());
    c.defaults.reserve.collateralFactor = 8000;
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in defaults.asset', () => {
    const c: any = clone(minimal());
    c.defaults.asset = {liquidityFee: 1000, irData: {}};
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in token', () => {
    const c: any = clone(minimal());
    c.tokens.WETH.decimals = 18;
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in hub', () => {
    const c: any = clone(minimal());
    c.hubs[0].name = 'test';
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in spoke', () => {
    const c: any = clone(minimal());
    c.spokes[0].treasury = '0x00';
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in spoke liquidationConfig', () => {
    const c: any = clone(minimal());
    c.spokes[0].liquidationConfig = {targetHealthFactor: '1050000000000000000', bonus: 100};
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in asset', () => {
    const c: any = clone(minimal());
    c.assets[0].oracleDecimals = 8;
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in asset irData', () => {
    const c: any = clone(minimal());
    c.assets[0].irData.maxRate = 50000;
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in spokeRegistration', () => {
    const c: any = clone(minimal());
    c.spokeRegistrations[0].borrowCap = 100;
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in reserve', () => {
    const c: any = clone(minimal());
    c.reserves[0].debtCeiling = 10000;
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('errors on unknown key in periphery', () => {
    const c: any = clone(minimal());
    c.periphery.flashLoan = true;
    expect(hasError(validate(c), 'E20')).toBe(true);
  });

  it('no errors on clean minimal config', () => {
    const c = clone(minimal());
    expect(hasError(validate(c), 'E20')).toBe(false);
  });

  it('no errors on production config', () => {
    expect(hasError(validate(PROD_CONFIG), 'E20')).toBe(false);
  });
});

describe('E21: tokenize name/symbol required when addCap > 0', () => {
  it('errors when addCap > 0 but name missing', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {addCap: 500, symbol: 'tWETH'};
    expect(hasError(validate(c), 'E21')).toBe(true);
  });

  it('errors when addCap > 0 but symbol missing', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {addCap: 500, name: 'Tokenized WETH'};
    expect(hasError(validate(c), 'E21')).toBe(true);
  });

  it('no error when addCap = 0', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {addCap: 0};
    expect(hasError(validate(c), 'E21')).toBe(false);
  });

  it('no error when addCap > 0 and name+symbol present', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {addCap: 500, name: 'Tokenized WETH', symbol: 'tWETH'};
    expect(hasError(validate(c), 'E21')).toBe(false);
  });

  it('errors when defaults.tokenize.addCap > 0 but per-asset name missing', () => {
    const c: any = clone(minimal());
    c.defaults.tokenize = {addCap: 500};
    expect(hasError(validate(c), 'E21')).toBe(true);
  });
});

describe('W8: defaults.reserve.maxLiquidationBonus < 10000', () => {
  it('warns on bad default maxLiquidationBonus', () => {
    const c: any = clone(minimal());
    c.defaults.reserve = {...c.defaults.reserve, maxLiquidationBonus: 9000};
    expect(hasWarning(validate(c), 'W8')).toBe(true);
  });

  it('no warning on valid default maxLiquidationBonus', () => {
    const c: any = clone(minimal());
    c.defaults.reserve = {...c.defaults.reserve, maxLiquidationBonus: 10500};
    expect(hasWarning(validate(c), 'W8')).toBe(false);
  });
});

describe('W9: defaults.reserve.liquidationFee > 10000', () => {
  it('warns on bad default liquidationFee', () => {
    const c: any = clone(minimal());
    c.defaults.reserve = {...c.defaults.reserve, liquidationFee: 15000};
    expect(hasWarning(validate(c), 'W9')).toBe(true);
  });

  it('no warning on valid default liquidationFee', () => {
    const c: any = clone(minimal());
    c.defaults.reserve = {...c.defaults.reserve, liquidationFee: 1000};
    expect(hasWarning(validate(c), 'W9')).toBe(false);
  });
});

describe('E22: IR params non-negative', () => {
  it('errors on negative baseDrawnRate', () => {
    const c = clone(minimal());
    c.assets[0].irData!.baseDrawnRate = -1;
    expect(hasError(validate(c), 'E22')).toBe(true);
  });

  it('errors on negative rateGrowthBeforeOptimal', () => {
    const c = clone(minimal());
    c.assets[0].irData!.rateGrowthBeforeOptimal = -100;
    expect(hasError(validate(c), 'E22')).toBe(true);
  });

  it('errors on negative rateGrowthAfterOptimal', () => {
    const c = clone(minimal());
    c.assets[0].irData!.rateGrowthAfterOptimal = -1;
    expect(hasError(validate(c), 'E22')).toBe(true);
  });

  it('accepts zero values', () => {
    const c = clone(minimal());
    c.assets[0].irData!.baseDrawnRate = 0;
    expect(hasError(validate(c), 'E22')).toBe(false);
  });
});

describe('E23: combined max drawn rate <= 100000', () => {
  it('errors when sum exceeds 100000', () => {
    const c = clone(minimal());
    c.assets[0].irData = {
      optimalUsageRatio: 9000,
      baseDrawnRate: 50000,
      rateGrowthBeforeOptimal: 30000,
      rateGrowthAfterOptimal: 30000,
    };
    expect(hasError(validate(c), 'E23')).toBe(true);
  });

  it('accepts sum = 100000 (boundary)', () => {
    const c = clone(minimal());
    c.assets[0].irData = {
      optimalUsageRatio: 9000,
      baseDrawnRate: 50000,
      rateGrowthBeforeOptimal: 30000,
      rateGrowthAfterOptimal: 20000,
    };
    expect(hasError(validate(c), 'E23')).toBe(false);
  });

  it('accepts sum = 0', () => {
    const c = clone(minimal());
    c.assets[0].irData = {
      optimalUsageRatio: 9000,
      baseDrawnRate: 0,
      rateGrowthBeforeOptimal: 0,
      rateGrowthAfterOptimal: 0,
    };
    expect(hasError(validate(c), 'E23')).toBe(false);
  });
});

describe('E24: liquidation config constraints', () => {
  it('errors when targetHealthFactor < 1e18', () => {
    const c = clone(minimal());
    c.spokes[0].liquidationConfig = {targetHealthFactor: '999999999999999999'};
    expect(hasError(validate(c), 'E24')).toBe(true);
  });

  it('accepts targetHealthFactor = 1e18', () => {
    const c = clone(minimal());
    c.spokes[0].liquidationConfig = {targetHealthFactor: '1000000000000000000'};
    expect(hasError(validate(c), 'E24')).toBe(false);
  });

  it('errors when healthFactorForMaxBonus >= 1e18', () => {
    const c = clone(minimal());
    c.spokes[0].liquidationConfig = {healthFactorForMaxBonus: '1000000000000000000'};
    expect(hasError(validate(c), 'E24')).toBe(true);
  });

  it('accepts healthFactorForMaxBonus < 1e18', () => {
    const c = clone(minimal());
    c.spokes[0].liquidationConfig = {healthFactorForMaxBonus: '999999999999999999'};
    expect(hasError(validate(c), 'E24')).toBe(false);
  });

  it('errors when liquidationBonusFactor > 10000', () => {
    const c = clone(minimal());
    c.spokes[0].liquidationConfig = {liquidationBonusFactor: 10001};
    expect(hasError(validate(c), 'E24')).toBe(true);
  });

  it('accepts liquidationBonusFactor = 10000', () => {
    const c = clone(minimal());
    c.spokes[0].liquidationConfig = {liquidationBonusFactor: 10000};
    expect(hasError(validate(c), 'E24')).toBe(false);
  });

  it('validates defaults.spoke.liquidationConfig', () => {
    const c: any = clone(minimal());
    c.defaults.spoke = {liquidationConfig: {targetHealthFactor: '0'}};
    expect(hasError(validate(c), 'E24')).toBe(true);
  });

  it('resolves per-spoke against defaults', () => {
    const c: any = clone(minimal());
    c.defaults.spoke = {liquidationConfig: {healthFactorForMaxBonus: '500000000000000000'}};
    // spoke does not override healthFactorForMaxBonus, inherits valid default
    c.spokes[0].liquidationConfig = {targetHealthFactor: '1050000000000000000'};
    expect(hasError(validate(c), 'E24')).toBe(false);
  });
});

describe('E25: maxUserReservesLimit > 0', () => {
  it('errors on default = 0', () => {
    const c: any = clone(minimal());
    c.defaults.spoke = {maxUserReservesLimit: 0};
    expect(hasError(validate(c), 'E25')).toBe(true);
  });

  it('errors on per-spoke = 0', () => {
    const c = clone(minimal());
    c.spokes[0].maxUserReservesLimit = 0;
    expect(hasError(validate(c), 'E25')).toBe(true);
  });

  it('accepts default = 1', () => {
    const c: any = clone(minimal());
    c.defaults.spoke = {maxUserReservesLimit: 1};
    expect(hasError(validate(c), 'E25')).toBe(false);
  });
});

describe('E26: maxUserReservesLimit <= 65535', () => {
  it('errors on default > 65535', () => {
    const c: any = clone(minimal());
    c.defaults.spoke = {maxUserReservesLimit: 65536};
    expect(hasError(validate(c), 'E26')).toBe(true);
  });

  it('errors on per-spoke > 65535', () => {
    const c = clone(minimal());
    c.spokes[0].maxUserReservesLimit = 70000;
    expect(hasError(validate(c), 'E26')).toBe(true);
  });

  it('accepts 65535', () => {
    const c: any = clone(minimal());
    c.defaults.spoke = {maxUserReservesLimit: 65535};
    expect(hasError(validate(c), 'E26')).toBe(false);
  });
});

describe('E27: uint overflow checks', () => {
  it('errors on spokeRegistration addCap > uint40 max', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].addCap = 1099511627776;
    expect(hasError(validate(c), 'E27')).toBe(true);
  });

  it('errors on spokeRegistration drawCap > uint40 max', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].drawCap = 1099511627776;
    expect(hasError(validate(c), 'E27')).toBe(true);
  });

  it('accepts addCap = uint40 max', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].addCap = 1099511627775;
    expect(hasError(validate(c), 'E27')).toBe(false);
  });

  it('errors on riskPremiumThreshold > uint24 max', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].riskPremiumThreshold = 16777216;
    expect(hasError(validate(c), 'E27')).toBe(true);
  });

  it('accepts riskPremiumThreshold = uint24 max', () => {
    const c = clone(minimal());
    c.spokeRegistrations[0].riskPremiumThreshold = 16777215;
    expect(hasError(validate(c), 'E27')).toBe(false);
  });

  it('errors on tokenize addCap > uint40 max', () => {
    const c = clone(minimal());
    c.assets[0].tokenize = {addCap: 1099511627776, name: 'Test', symbol: 'T'};
    expect(hasError(validate(c), 'E27')).toBe(true);
  });

  it('errors on defaults.spokeRegistration.riskPremiumThreshold > uint24 max', () => {
    const c: any = clone(minimal());
    c.defaults.spokeRegistration.riskPremiumThreshold = 16777216;
    expect(hasError(validate(c), 'E27')).toBe(true);
  });
});

describe('E11/E12/E13: default-resolved reserve values', () => {
  it('E11: errors when default maxLiquidationBonus < 10000 and reserve omits it', () => {
    const c: any = clone(minimal());
    c.defaults.reserve = {...c.defaults.reserve, maxLiquidationBonus: 9000};
    delete c.reserves[0].maxLiquidationBonus;
    delete c.reserves[1].maxLiquidationBonus;
    expect(hasError(validate(c), 'E11')).toBe(true);
  });

  it('E12: errors when default maxLiquidationBonus causes percentMulUp overflow', () => {
    const c: any = clone(minimal());
    c.defaults.reserve = {...c.defaults.reserve, maxLiquidationBonus: 12000};
    delete c.reserves[0].maxLiquidationBonus;
    c.reserves[0].collateralFactor = 9000;
    expect(hasError(validate(c), 'E12')).toBe(true);
  });

  it('E13: errors when default liquidationFee > 10000 and reserve omits it', () => {
    const c: any = clone(minimal());
    c.defaults.reserve = {...c.defaults.reserve, liquidationFee: 15000};
    delete c.reserves[0].liquidationFee;
    delete c.reserves[1].liquidationFee;
    expect(hasError(validate(c), 'E13')).toBe(true);
  });
});

describe('SCHEMA: type errors', () => {
  it('errors when a number field gets a string', () => {
    const c: any = clone(minimal());
    c.reserves[0].collateralFactor = 'high';
    expect(hasError(validate(c), 'SCHEMA')).toBe(true);
  });

  it('errors when a boolean field gets a number', () => {
    const c: any = clone(minimal());
    c.reserves[0].borrowable = 1;
    expect(hasError(validate(c), 'SCHEMA')).toBe(true);
  });

  it('errors when a required field is missing', () => {
    const c: any = clone(minimal());
    delete c.reserves[0].borrowable;
    expect(hasError(validate(c), 'SCHEMA')).toBe(true);
  });
});
