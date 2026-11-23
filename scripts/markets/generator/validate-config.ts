import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {
  ConfigSchema,
  ZERO,
  UINT40_MAX,
  UINT24_MAX,
  UINT16_MAX,
  WAD,
  PERCENTAGE_FACTOR,
  MIN_OPTIMAL_RATIO,
  MAX_OPTIMAL_RATIO,
  MAX_ALLOWED_DRAWN_RATE,
  type DeployConfig,
} from './config-common.ts';

export type {DeployConfig} from './config-common.ts';

// ── Validation ──────────────────────────────────────────────────────────────

interface Issue {
  code: string;
  msg: string;
}
export interface ValidationResult {
  errors: Issue[];
  warnings: Issue[];
}

export function validate(raw: unknown): ValidationResult {
  const errors: Issue[] = [];
  const warnings: Issue[] = [];

  function error(code: string, msg: string) {
    errors.push({code, msg});
  }
  function warn(code: string, msg: string) {
    warnings.push({code, msg});
  }

  // ── Phase 1: Schema validation ──────────────────────────────────────────

  const parsed = ConfigSchema.safeParse(raw);
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      const p = issue.path.join('.');
      if (issue.code === 'unrecognized_keys') {
        for (const key of issue.keys) {
          error('E20', `${p}: unknown key "${key}"`);
        }
      } else {
        error('SCHEMA', `${p}: ${issue.message}`);
      }
    }
    return {errors, warnings};
  }

  const config = parsed.data;

  // ── Phase 2: Business logic ─────────────────────────────────────────────

  const tokenKeys = new Set(Object.keys(config.tokens));
  const hubKeys = new Set(config.hubs.map((h) => h.key));
  const spokeKeys = new Set(config.spokes.map((s) => s.key));

  // ── E30: Ethereum address format ──
  const ETH_ADDR_RE = /^0x[0-9a-fA-F]{40}$/;
  for (const [key, token] of Object.entries(config.tokens)) {
    if (!ETH_ADDR_RE.test(token.address)) {
      error(
        'E30',
        `tokens["${key}"].address "${token.address}" is not a valid Ethereum address (expected 0x + 40 hex chars)`,
      );
    }
    if (!ETH_ADDR_RE.test(token.priceFeed)) {
      error(
        'E30',
        `tokens["${key}"].priceFeed "${token.priceFeed}" is not a valid Ethereum address (expected 0x + 40 hex chars)`,
      );
    }
  }

  const assetSet = new Set<string>();
  const assetIrMap = new Map<string, DeployConfig['assets'][number]['irData']>();
  const spokeRegSet = new Set<string>();
  const spokeRegMap = new Map<string, DeployConfig['spokeRegistrations'][number]>();
  const reserveSet = new Set<string>();
  const reserveMap = new Map<string, DeployConfig['reserves'][number]>();

  // ── Assets ──

  config.assets.forEach((a, i) => {
    const label = `assets[${i}] (${a.tokenKey}/${a.hubKey})`;
    if (!tokenKeys.has(a.tokenKey))
      error('E1', `${label}: tokenKey "${a.tokenKey}" not found in tokens`);
    if (!hubKeys.has(a.hubKey)) error('E2', `${label}: hubKey "${a.hubKey}" not found in hubs`);

    const key = `${a.tokenKey}|${a.hubKey}`;
    if (assetSet.has(key))
      error('E4', `${label}: duplicate asset (same tokenKey+hubKey already exists)`);
    assetSet.add(key);
    assetIrMap.set(key, a.irData);

    if (a.liquidityFee !== undefined && a.liquidityFee > 10000) {
      error('E14', `${label}: liquidityFee ${a.liquidityFee} > 10000 BPS`);
    }

    if (a.irData) {
      const opt = a.irData.optimalUsageRatio;
      if (opt < MIN_OPTIMAL_RATIO || opt > MAX_OPTIMAL_RATIO) {
        error(
          'E16',
          `${label}: optimalUsageRatio ${opt} outside valid range [${MIN_OPTIMAL_RATIO}, ${MAX_OPTIMAL_RATIO}] BPS`,
        );
      }

      for (const field of [
        'optimalUsageRatio',
        'baseDrawnRate',
        'rateGrowthBeforeOptimal',
        'rateGrowthAfterOptimal',
      ] as const) {
        if (a.irData[field] < 0) {
          error('E22', `${label}: irData.${field} = ${a.irData[field]} must be >= 0`);
        }
      }

      const totalRate =
        a.irData.baseDrawnRate + a.irData.rateGrowthBeforeOptimal + a.irData.rateGrowthAfterOptimal;
      if (totalRate > MAX_ALLOWED_DRAWN_RATE) {
        error(
          'E23',
          `${label}: combined max drawn rate ${totalRate} > ${MAX_ALLOWED_DRAWN_RATE} BPS (MAX_ALLOWED_DRAWN_RATE)`,
        );
      }
    }
  });

  // ── Default Reserve Constraints (W8, W9) ──

  if (config.defaults?.reserve) {
    const dr = config.defaults.reserve;
    if (dr.maxLiquidationBonus !== undefined && dr.maxLiquidationBonus < 10000) {
      warn('W8', `defaults.reserve.maxLiquidationBonus=${dr.maxLiquidationBonus} < 10000`);
    }
    if (dr.liquidationFee !== undefined && dr.liquidationFee > 10000) {
      warn('W9', `defaults.reserve.liquidationFee=${dr.liquidationFee} > 10000 BPS`);
    }
  }

  // ── Tokenization Spokes (E19) ──

  if (config.defaults?.tokenize) {
    const dt = config.defaults.tokenize;
    if (dt.drawCap !== undefined && dt.drawCap !== 0) {
      error(
        'E19',
        `defaults.tokenize: drawCap=${dt.drawCap} must be 0 (cannot borrow from tokenization spokes)`,
      );
    }
  }

  config.assets.forEach((a, i) => {
    if (a.tokenize?.drawCap !== undefined && a.tokenize.drawCap !== 0) {
      error(
        'E19',
        `assets[${i}] (${a.tokenKey}/${a.hubKey}): tokenize.drawCap=${a.tokenize.drawCap} must be 0 (cannot borrow from tokenization spokes)`,
      );
    }
  });

  // ── Tokenization Spoke Name/Symbol (E21) ──

  config.assets.forEach((a, i) => {
    const addCap = a.tokenize?.addCap ?? config.defaults?.tokenize?.addCap;
    if (addCap !== undefined && addCap > 0) {
      if (!a.tokenize?.name || a.tokenize.name.length === 0) {
        error(
          'E21',
          `assets[${i}] (${a.tokenKey}/${a.hubKey}): tokenize.name required when addCap > 0`,
        );
      }
      if (!a.tokenize?.symbol || a.tokenize.symbol.length === 0) {
        error(
          'E21',
          `assets[${i}] (${a.tokenKey}/${a.hubKey}): tokenize.symbol required when addCap > 0`,
        );
      }
    }
  });

  // ── Liquidation Config (E24) ──

  function validateLiquidationConfig(
    lc: {
      targetHealthFactor?: string;
      healthFactorForMaxBonus?: string;
      liquidationBonusFactor?: number;
    },
    defaults:
      | {
          targetHealthFactor?: string;
          healthFactorForMaxBonus?: string;
          liquidationBonusFactor?: number;
        }
      | undefined,
    label: string,
  ) {
    const thf = lc.targetHealthFactor ?? defaults?.targetHealthFactor;
    const hfmb = lc.healthFactorForMaxBonus ?? defaults?.healthFactorForMaxBonus;
    const lbf = lc.liquidationBonusFactor ?? defaults?.liquidationBonusFactor;

    if (thf !== undefined) {
      try {
        if (BigInt(thf) < WAD) {
          error(
            'E24',
            `${label}: targetHealthFactor ${thf} < 1e18 (HEALTH_FACTOR_LIQUIDATION_THRESHOLD)`,
          );
        }
      } catch {
        error('E24', `${label}: targetHealthFactor "${thf}" is not a valid integer`);
      }
    }
    if (hfmb !== undefined) {
      try {
        if (BigInt(hfmb) >= WAD) {
          error(
            'E24',
            `${label}: healthFactorForMaxBonus ${hfmb} >= 1e18 (must be < HEALTH_FACTOR_LIQUIDATION_THRESHOLD)`,
          );
        }
      } catch {
        error('E24', `${label}: healthFactorForMaxBonus "${hfmb}" is not a valid integer`);
      }
    }
    if (lbf !== undefined && lbf > PERCENTAGE_FACTOR) {
      error(
        'E24',
        `${label}: liquidationBonusFactor ${lbf} > ${PERCENTAGE_FACTOR} (PERCENTAGE_FACTOR)`,
      );
    }
  }

  if (config.defaults?.spoke?.liquidationConfig) {
    validateLiquidationConfig(
      config.defaults.spoke.liquidationConfig,
      undefined,
      'defaults.spoke.liquidationConfig',
    );
  }

  config.spokes.forEach((s, i) => {
    if (s.liquidationConfig || config.defaults?.spoke?.liquidationConfig) {
      validateLiquidationConfig(
        s.liquidationConfig ?? {},
        config.defaults?.spoke?.liquidationConfig,
        `spokes[${i}] (${s.key}).liquidationConfig`,
      );
    }
  });

  // ── Liquidation Config Completeness (E28) ──
  // Spoke.updateLiquidationConfig requires all three fields. Validate that
  // each spoke has all three resolved (per-spoke or via defaults).

  config.spokes.forEach((s, i) => {
    const defaults = config.defaults?.spoke?.liquidationConfig;
    const thf = s.liquidationConfig?.targetHealthFactor ?? defaults?.targetHealthFactor;
    const hfmb = s.liquidationConfig?.healthFactorForMaxBonus ?? defaults?.healthFactorForMaxBonus;
    const lbf = s.liquidationConfig?.liquidationBonusFactor ?? defaults?.liquidationBonusFactor;
    const label = `spokes[${i}] (${s.key}).liquidationConfig`;
    if (thf === undefined)
      error(
        'E28',
        `${label}: targetHealthFactor is not set (must be defined on spoke or in defaults.spoke.liquidationConfig)`,
      );
    if (hfmb === undefined)
      error(
        'E28',
        `${label}: healthFactorForMaxBonus is not set (must be defined on spoke or in defaults.spoke.liquidationConfig)`,
      );
    if (lbf === undefined)
      error(
        'E28',
        `${label}: liquidationBonusFactor is not set (must be defined on spoke or in defaults.spoke.liquidationConfig)`,
      );
  });

  // ── maxUserReservesLimit (E25, E26) ──

  if (config.defaults?.spoke?.maxUserReservesLimit !== undefined) {
    if (config.defaults.spoke.maxUserReservesLimit <= 0) {
      error(
        'E25',
        `defaults.spoke.maxUserReservesLimit=${config.defaults.spoke.maxUserReservesLimit} must be > 0`,
      );
    }
    if (config.defaults.spoke.maxUserReservesLimit > UINT16_MAX) {
      error(
        'E26',
        `defaults.spoke.maxUserReservesLimit=${config.defaults.spoke.maxUserReservesLimit} exceeds uint16 max (${UINT16_MAX})`,
      );
    }
  }

  config.spokes.forEach((s, i) => {
    const resolved = s.maxUserReservesLimit ?? config.defaults?.spoke?.maxUserReservesLimit;
    if (resolved !== undefined && resolved <= 0) {
      error('E25', `spokes[${i}] (${s.key}): maxUserReservesLimit=${resolved} must be > 0`);
    }
    if (s.maxUserReservesLimit !== undefined && s.maxUserReservesLimit > UINT16_MAX) {
      error(
        'E26',
        `spokes[${i}] (${s.key}): maxUserReservesLimit=${s.maxUserReservesLimit} exceeds uint16 max (${UINT16_MAX})`,
      );
    }
  });

  // ── Overflow Checks (E27) ──

  if (
    config.defaults?.spokeRegistration?.riskPremiumThreshold !== undefined &&
    config.defaults.spokeRegistration.riskPremiumThreshold > UINT24_MAX
  ) {
    error(
      'E27',
      `defaults.spokeRegistration.riskPremiumThreshold=${config.defaults.spokeRegistration.riskPremiumThreshold} exceeds uint24 max (${UINT24_MAX})`,
    );
  }

  if (
    config.defaults?.tokenize?.addCap !== undefined &&
    config.defaults.tokenize.addCap > UINT40_MAX
  ) {
    error(
      'E27',
      `defaults.tokenize.addCap=${config.defaults.tokenize.addCap} exceeds uint40 max (${UINT40_MAX})`,
    );
  }

  config.assets.forEach((a, i) => {
    if (a.tokenize?.addCap !== undefined && a.tokenize.addCap > UINT40_MAX) {
      error(
        'E27',
        `assets[${i}] (${a.tokenKey}/${a.hubKey}): tokenize.addCap=${a.tokenize.addCap} exceeds uint40 max (${UINT40_MAX})`,
      );
    }
  });

  // ── Spoke Registrations ──

  config.spokeRegistrations.forEach((sr, i) => {
    const label = `spokeRegistrations[${i}] (${sr.assetKey}/${sr.hubKey}/${sr.spokeKey})`;
    if (!tokenKeys.has(sr.assetKey))
      error('E1', `${label}: assetKey "${sr.assetKey}" not found in tokens`);
    if (!hubKeys.has(sr.hubKey)) error('E2', `${label}: hubKey "${sr.hubKey}" not found in hubs`);
    if (!spokeKeys.has(sr.spokeKey))
      error('E3', `${label}: spokeKey "${sr.spokeKey}" not found in spokes`);

    const key = `${sr.assetKey}|${sr.hubKey}|${sr.spokeKey}`;
    if (spokeRegSet.has(key)) error('E5', `${label}: duplicate spoke registration`);
    spokeRegSet.add(key);
    spokeRegMap.set(key, sr);

    const assetKey = `${sr.assetKey}|${sr.hubKey}`;
    if (!assetSet.has(assetKey)) {
      error('E7', `${label}: no asset found for (${sr.assetKey}, ${sr.hubKey}) in assets section`);
    }

    if (sr.addCap > UINT40_MAX) {
      error('E27', `${label}: addCap=${sr.addCap} exceeds uint40 max (${UINT40_MAX})`);
    }
    if (sr.drawCap > UINT40_MAX) {
      error('E27', `${label}: drawCap=${sr.drawCap} exceeds uint40 max (${UINT40_MAX})`);
    }
    const resolvedRPT =
      sr.riskPremiumThreshold ?? config.defaults?.spokeRegistration?.riskPremiumThreshold;
    if (resolvedRPT !== undefined && resolvedRPT > UINT24_MAX) {
      error(
        'E27',
        `${label}: riskPremiumThreshold=${resolvedRPT} exceeds uint24 max (${UINT24_MAX})`,
      );
    }
  });

  // ── Reserves ──

  config.reserves.forEach((r, i) => {
    const label = `reserves[${i}] (${r.spokeKey}/${r.hubKey}/${r.assetKey})`;
    if (!tokenKeys.has(r.assetKey))
      error('E1', `${label}: assetKey "${r.assetKey}" not found in tokens`);
    if (!hubKeys.has(r.hubKey)) error('E2', `${label}: hubKey "${r.hubKey}" not found in hubs`);
    if (!spokeKeys.has(r.spokeKey))
      error('E3', `${label}: spokeKey "${r.spokeKey}" not found in spokes`);

    const key = `${r.spokeKey}|${r.hubKey}|${r.assetKey}`;
    if (reserveSet.has(key)) error('E6', `${label}: duplicate reserve`);
    reserveSet.add(key);
    reserveMap.set(key, r);

    const assetKey = `${r.assetKey}|${r.hubKey}`;
    if (!assetSet.has(assetKey)) {
      error('E8', `${label}: no asset found for (${r.assetKey}, ${r.hubKey}) in assets section`);
    }

    const srKey = `${r.assetKey}|${r.hubKey}|${r.spokeKey}`;
    if (!spokeRegSet.has(srKey)) {
      error(
        'E9',
        `${label}: no spoke registration found for (${r.assetKey}, ${r.hubKey}, ${r.spokeKey})`,
      );
    }

    if (r.collateralFactor >= 10000) {
      error('E10', `${label}: collateralFactor ${r.collateralFactor} >= 10000 (must be < 100%)`);
    }

    const resolvedMLB = r.maxLiquidationBonus ?? config.defaults?.reserve?.maxLiquidationBonus;
    const resolvedLF = r.liquidationFee ?? config.defaults?.reserve?.liquidationFee;

    if (resolvedMLB !== undefined && resolvedMLB < 10000) {
      error(
        'E11',
        `${label}: maxLiquidationBonus ${resolvedMLB} < 10000 (must be >= 100%)${r.maxLiquidationBonus === undefined ? ' (from defaults)' : ''}`,
      );
    }

    if (r.collateralFactor > 0 && resolvedMLB !== undefined && resolvedMLB > 0) {
      const product = resolvedMLB * r.collateralFactor;
      const percentMulUp = Math.ceil(product / 10000);
      if (percentMulUp >= 10000) {
        error(
          'E12',
          `${label}: percentMulUp(maxLiquidationBonus=${resolvedMLB}, collateralFactor=${r.collateralFactor}) = ${percentMulUp} >= 10000${r.maxLiquidationBonus === undefined ? ' (maxLiquidationBonus from defaults)' : ''}`,
        );
      }
    }

    if (resolvedLF !== undefined && resolvedLF > 10000) {
      error(
        'E13',
        `${label}: liquidationFee ${resolvedLF} > 10000 BPS${r.liquidationFee === undefined ? ' (from defaults)' : ''}`,
      );
    }

    if (r.collateralRisk > 100000) {
      error('E15', `${label}: collateralRisk ${r.collateralRisk} > 100000 (max 1000.00%)`);
    }

    if (r.borrowable) {
      const sr = spokeRegMap.get(srKey);
      if (sr && sr.drawCap === 0) {
        error('E18', `${label}: borrowable=true but spoke registration has drawCap=0`);
      }
    }
  });

  // ── Periphery ──

  if (config.periphery) {
    if (!tokenKeys.has(config.periphery.nativeTokenKey)) {
      error(
        'E17',
        `periphery.nativeTokenKey "${config.periphery.nativeTokenKey}" not found in tokens`,
      );
    }
  }

  // ── Warnings ──

  // W2: collateralFactor > 0 but addCap=0
  config.reserves.forEach((r, i) => {
    if (r.collateralFactor === 0) return;
    const srKey = `${r.assetKey}|${r.hubKey}|${r.spokeKey}`;
    const sr = spokeRegMap.get(srKey);
    if (sr && sr.addCap === 0) {
      warn(
        'W2',
        `reserves[${i}] (${r.spokeKey}/${r.hubKey}/${r.assetKey}): collateralFactor=${r.collateralFactor} but spoke registration has addCap=0`,
      );
    }
  });

  // E29: drawCap > 0 but reserve is not borrowable (promoted from W3)
  config.spokeRegistrations.forEach((sr, i) => {
    if (sr.drawCap === 0) return;
    const rKey = `${sr.spokeKey}|${sr.hubKey}|${sr.assetKey}`;
    const reserve = reserveMap.get(rKey);
    if (reserve && !reserve.borrowable) {
      error(
        'E29',
        `spokeRegistrations[${i}] (${sr.assetKey}/${sr.hubKey}/${sr.spokeKey}): drawCap=${sr.drawCap} but reserve is not borrowable — drawCap can never be used`,
      );
    }
  });

  // W4: collateralFactor=0 AND borrowable=false
  config.reserves.forEach((r, i) => {
    if (r.collateralFactor === 0 && !r.borrowable) {
      warn(
        'W4',
        `reserves[${i}] (${r.spokeKey}/${r.hubKey}/${r.assetKey}): collateralFactor=0 and borrowable=false — reserve serves no purpose`,
      );
    }
  });

  // W6: spoke registration with no corresponding reserve
  config.spokeRegistrations.forEach((sr, i) => {
    const rKey = `${sr.spokeKey}|${sr.hubKey}|${sr.assetKey}`;
    if (!reserveSet.has(rKey)) {
      warn(
        'W6',
        `spokeRegistrations[${i}] (${sr.assetKey}/${sr.hubKey}/${sr.spokeKey}): registered on hub but no reserve exists on spoke`,
      );
    }
  });

  // W7: mock price feeds used in reserves
  const tokensUsedInReserves = new Set(config.reserves.map((r) => r.assetKey));
  for (const tokenKey of tokensUsedInReserves) {
    const token = config.tokens[tokenKey];
    if (token && token.priceFeed === ZERO) {
      warn('W7', `Token "${tokenKey}" has mock price feed (${ZERO}) but is used in reserves`);
    }
  }

  // W8, W9 are defined above (defaults.reserve checks).

  // W10: borrowable reserve has all-zero IR data
  config.reserves.forEach((r, i) => {
    if (!r.borrowable) return;
    const irData = assetIrMap.get(`${r.assetKey}|${r.hubKey}`);
    if (
      irData &&
      irData.baseDrawnRate === 0 &&
      irData.rateGrowthBeforeOptimal === 0 &&
      irData.rateGrowthAfterOptimal === 0
    ) {
      warn(
        'W10',
        `reserves[${i}] (${r.spokeKey}/${r.hubKey}/${r.assetKey}): borrowable=true but asset has all-zero IR rates — 0% interest at any utilisation`,
      );
    }
  });

  // W11: spoke declared but has no spoke registrations
  const registeredSpokeKeys = new Set(config.spokeRegistrations.map((sr) => sr.spokeKey));
  config.spokes.forEach((s, i) => {
    if (!registeredSpokeKeys.has(s.key)) {
      warn(
        'W11',
        `spokes[${i}] (${s.key}): no spoke registrations reference this spoke — it serves no purpose`,
      );
    }
  });

  // ── Liquidation Config Ordering (E31) ──
  // healthFactorForMaxBonus must be < targetHealthFactor: if hfmb >= thf the
  // bonus curve is inverted (max bonus at healthy positions).
  config.spokes.forEach((s, i) => {
    const defaults = config.defaults?.spoke?.liquidationConfig;
    const thf = s.liquidationConfig?.targetHealthFactor ?? defaults?.targetHealthFactor;
    const hfmb = s.liquidationConfig?.healthFactorForMaxBonus ?? defaults?.healthFactorForMaxBonus;
    if (thf === undefined || hfmb === undefined) return; // already caught by E28
    try {
      if (BigInt(hfmb) >= BigInt(thf)) {
        error(
          'E31',
          `spokes[${i}] (${s.key}).liquidationConfig: healthFactorForMaxBonus ${hfmb} >= targetHealthFactor ${thf} — bonus curve is inverted`,
        );
      }
    } catch {
      // invalid BigInt strings already caught by E24
    }
  });

  // NOTE: W1, W5 codes are intentionally unassigned (reserved for future use).

  return {errors, warnings};
}

// ── CLI entry point ─────────────────────────────────────────────────────────

const isMain =
  process.argv[1] && fileURLToPath(import.meta.url).endsWith(process.argv[1].replace(/.*\//, ''));
if (isMain) {
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const configPath = process.argv[2] || path.resolve(__dirname, '../ethereum/config/config.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const {errors, warnings} = validate(config);

  console.log('');
  if (errors.length > 0) {
    console.log('ERRORS:');
    errors.forEach((e) => console.log(`  ERROR: [${e.code}] ${e.msg}`));
    console.log('');
  }
  if (warnings.length > 0) {
    console.log('WARNINGS:');
    warnings.forEach((w) => console.log(`  WARN:  [${w.code}] ${w.msg}`));
    console.log('');
  }

  const summary = `=== Summary: ${errors.length} error(s), ${warnings.length} warning(s) ===`;
  if (errors.length > 0) {
    console.log(summary);
    process.exit(1);
  } else if (warnings.length > 0) {
    console.log(summary);
    process.exit(0);
  } else {
    console.log('All checks passed. No errors or warnings.');
    process.exit(0);
  }
}
