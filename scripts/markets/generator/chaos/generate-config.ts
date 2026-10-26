import * as XLSX from 'xlsx';
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {validate} from '../validate-config.ts';
import {
  TOKEN_REGISTRY,
  safeMaxLiquidationBonus,
  toWadString,
  type IrProfile,
} from '../config-common.ts';

// ══════════════════════════════════════════════════════════════════════════════
// Key Normalization Maps
// ══════════════════════════════════════════════════════════════════════════════

const TOKEN_KEY_MAP: Record<string, string> = {
  Aave: 'AAVE',
  ETH: 'WETH',
  EUR: 'EURC',
  ['PT-USDE-7MAY2026']: 'PT_USDE_7MAY2026',
  ['PT-sUSDE-7MAY2026']: 'PT_sUSDE_7MAY2026',
};

function normalizeTokenKey(raw: string): string {
  const trimmed = raw.trim();
  return TOKEN_KEY_MAP[trimmed] ?? trimmed;
}

function toTitleCase(raw: string): string {
  return String(raw).charAt(0).toUpperCase() + String(raw).slice(1).toLowerCase();
}

const HUB_KEY_MAP: Record<string, string> = {
  'Core Hub': 'CORE_HUB',
  'Prime Hub': 'PRIME_HUB',
  'Plus Hub': 'PLUS_HUB',
};

function normalizeHubKey(raw: string): string {
  const trimmed = raw.trim();
  const mapped = HUB_KEY_MAP[trimmed];
  if (!mapped) throw new Error(`Unknown hub: "${trimmed}"`);
  return mapped;
}

const SPOKE_KEY_MAP: Record<string, string> = {
  'Main Spoke': 'MAIN_SPOKE',
  'Lido Spoke': 'LIDO_ESPOKE',
  'EtherFi Spoke': 'ETHERFI_ESPOKE',
  'Kelp Spoke': 'KELP_ESPOKE',
  'Lombard BTC Spoke': 'LOMBARD_BTC_SPOKE',
  'Gold Spoke': 'GOLD_SPOKE',
  'Forex Spoke': 'FOREX_SPOKE',
  'Bluechip Spoke': 'BLUECHIP_SPOKE',
  'Ethena Ecosystem Spoke': 'ETHENA_ECOSYSTEM_SPOKE',
  'Ethena Correlated Spoke': 'ETHENA_CORRELATED_SPOKE',
};

const TOKENIZE_HUB_PREFIX_MAP: Record<string, string> = {
  Core: 'CORE_HUB',
  Prime: 'PRIME_HUB',
  Plus: 'PLUS_HUB',
};

const TOKENIZE_SPOKE_RE = /^(\w+)\s+Tokenized\s+(.+?)\s+Spoke$/;

function normalizeSpokeKey(raw: string): string {
  const trimmed = raw.trim();
  const mapped = SPOKE_KEY_MAP[trimmed];
  if (!mapped) throw new Error(`Unknown spoke: "${trimmed}"`);
  return mapped;
}

// ══════════════════════════════════════════════════════════════════════════════
// Unit Conversion Helpers
// ══════════════════════════════════════════════════════════════════════════════

function toBps(decimal: number, warnings?: string[], context?: string): number {
  const exact = decimal * 10000;
  const rounded = Math.round(exact);
  if (warnings && context && Math.abs(exact - rounded) > 1e-6) {
    warnings.push(`${context}: toBps rounded ${decimal} from ${exact} to ${rounded}`);
  }
  return rounded;
}

/**
 * Parse IR Base field into BPS.
 *
 * Accepted input formats (all producing the same BPS result):
 *   "0" or ""     → 0
 *   "2%"          → 200 BPS   (string × 100)
 *   "0.25%"       → 25 BPS    (string × 100)
 *   0.02          → 200 BPS   (decimal × 10000 via toBps)
 *
 * WARNING: do NOT pass a raw BPS integer like "200" — it would be treated
 * as a decimal and produce 2,000,000 BPS.
 */
function parseIrBase(raw: string): number {
  const s = String(raw).trim();
  if (s === '0' || s === '') return 0;
  if (s.endsWith('%')) {
    return Math.round(parseFloat(s) * 100); // "2%" → 200, "0.25%" → 25
  }
  // Numeric decimal (shouldn't happen for base, but handle it)
  const n = parseFloat(s);
  if (!isNaN(n)) return toBps(n);
  return 0;
}

function isNA(val: unknown): boolean {
  return val === 'N/A' || val === 'n/a' || val === undefined || val === null;
}

// ══════════════════════════════════════════════════════════════════════════════
// Defaults
// ══════════════════════════════════════════════════════════════════════════════

const ZERO_IR: IrProfile = {
  optimalUsageRatio: 99_00,
  baseDrawnRate: 0,
  rateGrowthBeforeOptimal: 0,
  rateGrowthAfterOptimal: 0,
};

// ══════════════════════════════════════════════════════════════════════════════
// Sheet Parsing: Spoke Level Params
// ══════════════════════════════════════════════════════════════════════════════

interface SpokeParams {
  hubKey: string;
  spokeKey: string;
  liquidationBonusFactor: number; // BPS
  targetHealthFactor: string; // WAD string
  healthFactorForMaxBonus: string; // WAD string
}

function parseSpokeParams(sheet: XLSX.WorkSheet): {results: SpokeParams[]; warnings: string[]} {
  const rows = XLSX.utils.sheet_to_json<Record<string, string>>(sheet, {header: 1}) as unknown[][];
  // Header: Chain | Hub | Spoke | Liquidation Bonus Factor | Target Health Factor | Health Factor For Max Bonus
  const results: SpokeParams[] = [];
  const warnings: string[] = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (!row || !row[0]) continue;
    const hubKey = normalizeHubKey(String(row[1]));
    const spokeKey = normalizeSpokeKey(String(row[2]));
    const ctx = `spoke ${spokeKey} at ${hubKey}`;
    const lbf = toBps(Number(row[3]), warnings, `${ctx} liquidationBonusFactor`); // 1 → 10000
    const thf = toWadString(Number(row[4]).toFixed(6)); // 1.24 → "1240000000000000000"
    const hfmb = toWadString(Number(row[5]).toFixed(6)); // 0.99 → "990000000000000000"
    results.push({
      hubKey,
      spokeKey,
      liquidationBonusFactor: lbf,
      targetHealthFactor: thf,
      healthFactorForMaxBonus: hfmb,
    });
  }
  return {results, warnings};
}

// ══════════════════════════════════════════════════════════════════════════════
// Sheet Parsing: Asset Level IR Params
// ══════════════════════════════════════════════════════════════════════════════

interface AssetParams {
  hubKey: string;
  tokenKey: string;
  irData: IrProfile;
  liquidityFee: number | null; // BPS, null if N/A
}

function parseAssetParams(sheet: XLSX.WorkSheet): {results: AssetParams[]; warnings: string[]} {
  const rows = XLSX.utils.sheet_to_json<Record<string, string>>(sheet, {header: 1}) as unknown[][];
  // Header: Chain | Hub | Asset | Base | Slope 1 | Slope 2 | Uoptimal | Liquidity Fee | Reinvestment Controller | Fee Receiver
  const results: AssetParams[] = [];
  const warnings: string[] = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (!row || !row[0]) continue;
    const hubKey = normalizeHubKey(String(row[1]));
    const tokenKey = normalizeTokenKey(String(row[2]));
    const ctx = `asset ${tokenKey} at ${hubKey}`;

    const rawBase = row[3];
    const rawSlope1 = row[4];
    const rawSlope2 = row[5];
    const rawUopt = row[6];
    const rawLiqFee = row[7];

    let irData: IrProfile;
    let liquidityFee: number | null;

    if (isNA(rawBase) || isNA(rawSlope1)) {
      // Supply-only asset — no IR params
      irData = ZERO_IR;
      liquidityFee = null;
    } else {
      irData = {
        baseDrawnRate: parseIrBase(String(rawBase)),
        rateGrowthBeforeOptimal: toBps(Number(rawSlope1), warnings, `${ctx} slope1`),
        rateGrowthAfterOptimal: toBps(Number(rawSlope2), warnings, `${ctx} slope2`),
        optimalUsageRatio: toBps(Number(rawUopt), warnings, `${ctx} uOptimal`),
      };
      liquidityFee = isNA(rawLiqFee)
        ? null
        : toBps(Number(rawLiqFee), warnings, `${ctx} liquidityFee`);
    }

    results.push({hubKey, tokenKey, irData, liquidityFee});
  }
  return {results, warnings};
}

// ══════════════════════════════════════════════════════════════════════════════
// Sheet Parsing: Reserve Level Params
// ══════════════════════════════════════════════════════════════════════════════

interface TokenizeSpokeParams {
  hubKey: string;
  tokenKey: string;
  addCap: number;
}

interface ReserveParams {
  hubKey: string;
  spokeKey: string;
  tokenKey: string;
  addCap: number;
  drawCap: number;
  collateralFactor: number; // BPS
  maxLiquidationBonus: number; // BPS (absolute, e.g. 10500)
  borrowable: boolean;
  collateralRisk: number; // BPS
  liquidationFee: number; // BPS
}

function parseReserveSheet(sheet: XLSX.WorkSheet): {
  reserves: ReserveParams[];
  tokenizeSpokes: TokenizeSpokeParams[];
  warnings: string[];
} {
  const rows = XLSX.utils.sheet_to_json<Record<string, string>>(sheet, {header: 1}) as unknown[][];
  // Header: Chain | Hub | Spoke | Reserve | Add Cap | Draw Cap | Collateral Factor | Max Liquidation Bonus | Borrowable | Collateral Risk | Liquidation Fee
  const reserves: ReserveParams[] = [];
  const tokenizeSpokes: TokenizeSpokeParams[] = [];
  const warnings: string[] = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (!row || !row[0]) continue;

    const rawSpoke = String(row[2]).trim();
    const tokenizeMatch = rawSpoke.match(TOKENIZE_SPOKE_RE);

    if (tokenizeMatch) {
      // Tokenization spoke row — extract hub prefix and token from spoke name
      const hubPrefix = tokenizeMatch[1];
      const hubKey = TOKENIZE_HUB_PREFIX_MAP[hubPrefix];
      if (!hubKey)
        throw new Error(`Unknown tokenization spoke hub prefix: "${hubPrefix}" in "${rawSpoke}"`);
      const tokenKey = normalizeTokenKey(tokenizeMatch[2]);
      const addCap = Number(row[4]) || 0;
      tokenizeSpokes.push({hubKey, tokenKey, addCap});
      continue;
    }

    const hubKey = normalizeHubKey(String(row[1]));
    const spokeKey = normalizeSpokeKey(rawSpoke);
    const tokenKey = normalizeTokenKey(String(row[3]));
    const ctx = `reserve ${tokenKey} of ${spokeKey} at ${hubKey}`;

    const rawAddCap = row[4];
    const addCap = Math.round(Number(rawAddCap));
    if (!Number.isFinite(addCap)) {
      throw new Error(`${ctx}: addCap "${rawAddCap}" is not a valid number`);
    }

    let drawCap = Number(row[5]) || 0;
    if (!Number.isInteger(drawCap)) {
      const rounded = Math.round(drawCap);
      warnings.push(`${ctx}: rounding drawCap from ${drawCap} to ${rounded}`);
      drawCap = rounded;
    }

    const rawCF = row[6];
    const collateralFactor = toBps(Number(rawCF), warnings, `${ctx} collateralFactor`);
    if (!Number.isFinite(collateralFactor)) {
      throw new Error(`${ctx}: collateralFactor "${rawCF}" is not a valid number`);
    }

    // Max Liquidation Bonus: number (bonus portion, e.g. 0.05 → 10500) or "N/A" or "Risk oracle"
    const rawMLB = row[7];
    let maxLiquidationBonus: number;
    if (isNA(rawMLB)) {
      maxLiquidationBonus = 10000; // no bonus for non-collateral
    } else if (String(rawMLB).toLowerCase().includes('risk oracle')) {
      maxLiquidationBonus = safeMaxLiquidationBonus(10600, collateralFactor);
    } else {
      maxLiquidationBonus = Math.round((1 + Number(rawMLB)) * 10000);
    }

    const borrowable = row[8] === true || String(row[8]).toLowerCase() === 'true';

    // Collateral Risk
    const rawCR = row[9];
    const collateralRisk = isNA(rawCR)
      ? 0
      : toBps(Number(rawCR), warnings, `${ctx} collateralRisk`);

    // Liquidation Fee
    const rawLF = row[10];
    const liquidationFee = isNA(rawLF)
      ? 0
      : toBps(Number(rawLF), warnings, `${ctx} liquidationFee`);

    reserves.push({
      hubKey,
      spokeKey,
      tokenKey,
      addCap,
      drawCap,
      collateralFactor,
      maxLiquidationBonus,
      borrowable,
      collateralRisk,
      liquidationFee,
    });
  }
  return {reserves, tokenizeSpokes, warnings};
}

// ══════════════════════════════════════════════════════════════════════════════
// Config Assembly
// ══════════════════════════════════════════════════════════════════════════════

function buildConfig(
  spokeParams: SpokeParams[],
  assetParams: AssetParams[],
  reserveParams: ReserveParams[],
  tokenizeSpokeParams: TokenizeSpokeParams[],
): Record<string, unknown> {
  // ── Defaults ──
  const defaults = {
    spokeRegistration: {
      riskPremiumThreshold: 0,
      active: true,
      halted: false,
    },
    reserve: {
      receiveSharesEnabled: true,
      frozen: false,
      paused: false,
      liquidationFee: 0,
      maxLiquidationBonus: 10000,
    },
    asset: {
      liquidityFee: 0,
    },
    tokenize: {
      enabled: true,
    },
  };

  // ── Tokens ──
  const allTokenKeys = new Set<string>();
  for (const a of assetParams) allTokenKeys.add(a.tokenKey);
  for (const r of reserveParams) allTokenKeys.add(r.tokenKey);

  const tokens: Record<string, {address: string; priceFeed: string}> = {};
  for (const key of [...allTokenKeys].sort()) {
    const entry = TOKEN_REGISTRY[key];
    if (!entry) {
      throw new Error(
        `Token "${key}" not found in TOKEN_REGISTRY — check Excel spelling or add to TOKEN_KEY_MAP`,
      );
    }
    tokens[key] = entry;
  }

  // ── Hubs ──
  const hubKeySet = new Set<string>();
  for (const a of assetParams) hubKeySet.add(a.hubKey);
  for (const r of reserveParams) hubKeySet.add(r.hubKey);
  const PREFERRED_HUB_ORDER = ['PRIME_HUB', 'CORE_HUB', 'PLUS_HUB'];
  const hubKeyOrder = [
    ...PREFERRED_HUB_ORDER.filter((k) => hubKeySet.has(k)),
    ...[...hubKeySet].filter((k) => !PREFERRED_HUB_ORDER.includes(k)).sort(),
  ];
  const hubs = hubKeyOrder.map((key) => ({key}));

  // ── Spokes ──
  const spokeConfigMap = new Map<string, SpokeParams>();
  const spokes: Array<Record<string, unknown>> = [];
  for (const sp of spokeParams) {
    const existing = spokeConfigMap.get(sp.spokeKey);
    if (existing) {
      if (
        existing.liquidationBonusFactor !== sp.liquidationBonusFactor ||
        existing.targetHealthFactor !== sp.targetHealthFactor ||
        existing.healthFactorForMaxBonus !== sp.healthFactorForMaxBonus
      ) {
        throw new Error(`Spoke "${sp.spokeKey}" has conflicting liquidation configs across hubs`);
      }
      continue;
    }
    spokeConfigMap.set(sp.spokeKey, sp);
    const spoke: Record<string, unknown> = {key: sp.spokeKey};
    spoke.liquidationConfig = {
      targetHealthFactor: sp.targetHealthFactor,
      healthFactorForMaxBonus: sp.healthFactorForMaxBonus,
      liquidationBonusFactor: sp.liquidationBonusFactor,
    };
    spokes.push(spoke);
  }

  // ── Assets ──
  // Build from asset IR params sheet. Each (tokenKey, hubKey) is one asset.
  const assetHubSet = new Set<string>();
  const assets: Array<Record<string, unknown>> = [];
  for (const a of assetParams) {
    const key = `${a.tokenKey}|${a.hubKey}`;
    if (assetHubSet.has(key)) continue;
    assetHubSet.add(key);
    const asset: Record<string, unknown> = {
      tokenKey: a.tokenKey,
      hubKey: a.hubKey,
      irData: a.irData,
    };
    if (a.liquidityFee !== null && a.liquidityFee !== defaults.asset.liquidityFee) {
      asset.liquidityFee = a.liquidityFee;
    }
    assets.push(asset);
  }

  // Ensure cross-hub assets exist (reserves may reference hub+asset combos not in the IR sheet)
  for (const r of reserveParams) {
    const key = `${r.tokenKey}|${r.hubKey}`;
    if (!assetHubSet.has(key)) {
      assets.push({tokenKey: r.tokenKey, hubKey: r.hubKey, irData: ZERO_IR});
      assetHubSet.add(key);
    }
  }

  // ── Tokenization Spoke AddCap ──
  // Build lookup from explicit tokenization spoke rows
  const tokenizeCapMap = new Map<string, number>();
  for (const ts of tokenizeSpokeParams) {
    tokenizeCapMap.set(`${ts.tokenKey}|${ts.hubKey}`, ts.addCap);
  }

  // For each asset, set tokenize.addCap from Excel or infer 0 for supply-only assets
  for (const asset of assets) {
    const hubPrefix = toTitleCase(String(asset.hubKey).replace(/_HUB$/, ''));
    const key = `${asset.tokenKey}|${asset.hubKey}`;
    const explicitCap = tokenizeCapMap.get(key);
    if (explicitCap !== undefined) {
      asset.tokenize = {
        name: `Wrapped Aave ${hubPrefix} ${asset.tokenKey}`,
        symbol: `wa${hubPrefix}${asset.tokenKey}`,
        addCap: explicitCap,
      };
    } else {
      // No tokenization row — check if any spoke registration has non-zero drawCap
      const maxDrawCap = reserveParams
        .filter((r) => r.tokenKey === asset.tokenKey && r.hubKey === asset.hubKey)
        .reduce((max, r) => Math.max(max, r.drawCap), 0);
      if (maxDrawCap > 0) {
        const spokeWithDraw = reserveParams.find(
          (r) => r.tokenKey === asset.tokenKey && r.hubKey === asset.hubKey && r.drawCap > 0,
        )!;
        throw new Error(
          `Asset ${asset.tokenKey} on ${asset.hubKey} has no tokenization spoke addCap but has drawCap=${spokeWithDraw.drawCap} on spoke ${spokeWithDraw.spokeKey} — tokenization cap is required for yield-generating assets`,
        );
      } else {
        // All drawCaps are 0 — deploy with addCap 0 for consistency
        asset.tokenize = {
          name: `Tokenized Aave ${hubPrefix} ${asset.tokenKey}`,
          symbol: `a${hubPrefix}-${asset.tokenKey}`,
          addCap: 0,
        };
      }
    }
  }

  // ── Spoke Registrations ──
  const srSeen = new Map<string, {addCap: number; drawCap: number}>();
  const spokeRegistrations: Array<Record<string, unknown>> = [];
  for (const r of reserveParams) {
    const key = `${r.tokenKey}|${r.hubKey}|${r.spokeKey}`;
    const existing = srSeen.get(key);
    if (existing) {
      if (existing.addCap !== r.addCap || existing.drawCap !== r.drawCap) {
        throw new Error(
          `Duplicate spoke registration ${key} with conflicting values: ` +
            `first={addCap:${existing.addCap},drawCap:${existing.drawCap}} ` +
            `vs new={addCap:${r.addCap},drawCap:${r.drawCap}}`,
        );
      }
      continue;
    }
    srSeen.set(key, {addCap: r.addCap, drawCap: r.drawCap});
    spokeRegistrations.push({
      assetKey: r.tokenKey,
      hubKey: r.hubKey,
      spokeKey: r.spokeKey,
      addCap: r.addCap,
      drawCap: r.drawCap,
    });
  }

  // Warn on spokes declared in the spokes array that have no registrations.
  const registeredSpokeKeys = new Set(spokeRegistrations.map((sr) => sr.spokeKey as string));
  for (const spoke of spokes) {
    if (!registeredSpokeKeys.has(spoke.key as string)) {
      console.error(
        `  WARN: spoke "${spoke.key}" has no spoke registrations — it serves no purpose`,
      );
    }
  }

  // ── Reserves ──
  type StoredReserve = Pick<
    ReserveParams,
    'collateralFactor' | 'maxLiquidationBonus' | 'borrowable' | 'collateralRisk' | 'liquidationFee'
  >;
  const resSeen = new Map<string, StoredReserve>();
  const reserves: Array<Record<string, unknown>> = [];
  for (const r of reserveParams) {
    const key = `${r.spokeKey}|${r.hubKey}|${r.tokenKey}`;
    const existing = resSeen.get(key);
    if (existing) {
      if (
        existing.collateralFactor !== r.collateralFactor ||
        existing.maxLiquidationBonus !== r.maxLiquidationBonus ||
        existing.borrowable !== r.borrowable ||
        existing.collateralRisk !== r.collateralRisk ||
        existing.liquidationFee !== r.liquidationFee
      ) {
        throw new Error(
          `Duplicate reserve ${key} with conflicting values: ` +
            `first={cf:${existing.collateralFactor},mlb:${existing.maxLiquidationBonus},borrowable:${existing.borrowable},cr:${existing.collateralRisk},lf:${existing.liquidationFee}} ` +
            `vs new={cf:${r.collateralFactor},mlb:${r.maxLiquidationBonus},borrowable:${r.borrowable},cr:${r.collateralRisk},lf:${r.liquidationFee}}`,
        );
      }
      continue;
    }
    resSeen.set(key, {
      collateralFactor: r.collateralFactor,
      maxLiquidationBonus: r.maxLiquidationBonus,
      borrowable: r.borrowable,
      collateralRisk: r.collateralRisk,
      liquidationFee: r.liquidationFee,
    });

    const reserve: Record<string, unknown> = {
      spokeKey: r.spokeKey,
      hubKey: r.hubKey,
      assetKey: r.tokenKey,
      borrowable: r.borrowable,
      collateralFactor: r.collateralFactor,
      collateralRisk: r.collateralRisk,
    };

    // Only include if different from defaults
    if (r.maxLiquidationBonus !== defaults.reserve.maxLiquidationBonus) {
      reserve.maxLiquidationBonus = r.maxLiquidationBonus;
    }
    if (r.liquidationFee !== defaults.reserve.liquidationFee) {
      reserve.liquidationFee = r.liquidationFee;
    }

    reserves.push(reserve);
  }

  // ── Periphery ──
  const periphery = {
    nativeTokenKey: 'WETH',
    deploySignatureGateway: true,
    deployNativeTokenGateway: true,
    deployGiverPositionManager: true,
    deployTakerPositionManager: true,
    deployConfigPositionManager: true,
  };

  return {
    defaults,
    tokens,
    hubs,
    spokes,
    assets,
    spokeRegistrations,
    reserves,
    periphery,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// Main
// ══════════════════════════════════════════════════════════════════════════════

function main() {
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const xlsxPath =
    process.argv[2] || path.resolve(__dirname, '../../ethereum/config/chaos-labs-parameters.xlsx');
  const outputPath =
    process.argv[3] || path.resolve(__dirname, '../../ethereum/config/config.json');

  console.error(`Reading: ${xlsxPath}`);
  const workbook = XLSX.read(fs.readFileSync(xlsxPath));

  // Parse sheets
  const spokeSheet = workbook.Sheets['Spoke Level Params'];
  if (!spokeSheet) throw new Error('Sheet "Spoke Level Params" not found');
  const {results: spokeParams, warnings: spokeWarnings} = parseSpokeParams(spokeSheet);
  console.error(`  Spoke Level Params: ${spokeParams.length} entries`);

  const assetSheet = workbook.Sheets['Asset Level IR Params'];
  if (!assetSheet) throw new Error('Sheet "Asset Level IR Params" not found');
  const {results: assetParams, warnings: assetWarnings} = parseAssetParams(assetSheet);
  console.error(`  Asset Level IR Params: ${assetParams.length} entries`);

  const reserveSheet = workbook.Sheets['Reserve Level Params'];
  if (!reserveSheet) throw new Error('Sheet "Reserve Level Params" not found');
  const {
    reserves: reserveParams,
    tokenizeSpokes,
    warnings: parseWarnings,
  } = parseReserveSheet(reserveSheet);
  console.error(`  Reserve Level Params: ${reserveParams.length} entries`);
  console.error(`  Tokenization Spoke Params: ${tokenizeSpokes.length} entries`);
  const allParseWarnings = [...spokeWarnings, ...assetWarnings, ...parseWarnings];
  if (allParseWarnings.length > 0) {
    console.error('\nRounding WARNINGS:');
    allParseWarnings.forEach((w) => console.error(`  ${w}`));
  }

  // Build config
  const config = buildConfig(spokeParams, assetParams, reserveParams, tokenizeSpokes);

  // Validate
  const result = validate(config);
  if (result.errors.length > 0) {
    console.error('\nValidation ERRORS:');
    result.errors.forEach((e) => console.error(`  [${e.code}] ${e.msg}`));
  }
  if (result.warnings.length > 0) {
    console.error('\nValidation WARNINGS:');
    result.warnings.forEach((w) => console.error(`  [${w.code}] ${w.msg}`));
  }
  console.error(`\n=== ${result.errors.length} error(s), ${result.warnings.length} warning(s) ===`);

  // Write output
  const json = JSON.stringify(config, null, 2);
  fs.writeFileSync(outputPath, json + '\n');
  console.error(`\nWritten to: ${outputPath}`);

  if (result.errors.length > 0) process.exit(1);
}

main();
