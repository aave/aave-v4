// ════════════════════════════════════════════════════════════════════════════
// LlamaRisk → config.json generator (Aave V4 Avalanche).
//
// Source of truth: scripts/markets/avalanche/config/llamarisk-parameters.md (cloned from Outline).
// Output: scripts/markets/avalanche/config/config.json (the active config consumed by the
//         payload / address-lib / tokenization generators).
//
// This is the Avalanche analog of scripts/markets/generator/chaos/generate-config.ts.
// Instead of an xlsx it parses the markdown tables in the LlamaRisk doc:
//   1. Dynamic Liquidation Bonus Configuration  → spokes[].liquidationConfig
//   2. V4 Spoke Parameters                       → reserves[]
//   3. Add and Draw Caps                         → spokeRegistrations[]
//   4. Interest Rate Curves                      → assets[].irData / liquidityFee
//
// Run: bun run scripts/markets/generator/llamarisk/generate-config.ts [src.md] [out.json]
// ════════════════════════════════════════════════════════════════════════════

import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {getAddress} from 'viem';
import {validate} from '../validate-config.ts';
import {toWadString, type IrProfile} from '../config-common.ts';
import {AVALANCHE_TOKEN_REGISTRY, ZERO} from './tokens.ts';

// ── Key normalization ─────────────────────────────────────────────────────────

const HUB_KEY_MAP: Record<string, string> = {
  'Core Hub': 'CORE_HUB',
};

const SPOKE_KEY_MAP: Record<string, string> = {
  'Main Spoke': 'MAIN_SPOKE',
  'AVAX Correlated Spoke': 'AVAX_CORRELATED_SPOKE',
  'Forex Spoke': 'FOREX_SPOKE',
};

// Reserve/asset names in the doc → Solidity-safe token keys (the Tokens library
// uses these as identifiers, so dots are not allowed).
const TOKEN_KEY_MAP: Record<string, string> = {
  WAVAX: 'WAVAX',
  'BTC.b': 'BTCb',
  USDC: 'USDC',
  USDT: 'USDT',
  'WETH.e': 'WETHe',
  EURC: 'EURC',
  sAVAX: 'sAVAX',
};

function normalizeHub(raw: string): string {
  const t = raw.trim();
  const m = HUB_KEY_MAP[t];
  if (!m) throw new Error(`Unknown hub: "${t}"`);
  return m;
}
function normalizeSpoke(raw: string): string {
  const t = raw.trim();
  const m = SPOKE_KEY_MAP[t];
  if (!m) throw new Error(`Unknown spoke: "${t}"`);
  return m;
}
function normalizeToken(raw: string): string {
  const t = raw.trim();
  const m = TOKEN_KEY_MAP[t];
  if (!m) throw new Error(`Unknown token/reserve: "${t}" (add to TOKEN_KEY_MAP)`);
  return m;
}

// ── Value parsing ─────────────────────────────────────────────────────────────

function isDash(s: unknown): boolean {
  const t = String(s ?? '').trim();
  return t === '' || t === '-' || t === '–' || t.toUpperCase() === 'N/A';
}

/** "73.00%" → 7300 BPS, "144.28%" → 14428 BPS. Bare numbers are treated as %. */
function pctToBps(s: string, ctx: string): number {
  const n = parseFloat(String(s).replace(/%/g, '').replace(/,/g, '').trim());
  if (!Number.isFinite(n)) throw new Error(`${ctx}: "${s}" is not a valid percentage`);
  const exact = n * 100;
  const rounded = Math.round(exact);
  if (Math.abs(exact - rounded) > 1e-6) warnings.push(`${ctx}: rounded ${exact} → ${rounded} BPS`);
  return rounded;
}

/** Base variable borrow rate: "1.00%" → 100, "0.00%" → 0. */
function parseIrBase(s: string, ctx: string): number {
  if (isDash(s) || String(s).trim() === '0') return 0;
  return pctToBps(s, ctx);
}

/**
 * Max Liquidation Bonus in the doc is the *bonus portion* (e.g. "10.00%" means a
 * 10% bonus → absolute 11000). "-" / N/A means no bonus → 10000.
 */
function parseMaxLiquidationBonus(s: string, ctx: string): number {
  if (isDash(s)) return 10000;
  const frac = parseFloat(String(s).replace('%', '').trim()) / 100;
  if (!Number.isFinite(frac)) throw new Error(`${ctx}: maxLiquidationBonus "${s}" invalid`);
  return Math.round((1 + frac) * 10000);
}

/** "5,000,000" → 5000000, "100" → 100, "0" → 0. */
function parseCap(s: string, ctx: string): number {
  if (isDash(s)) return 0;
  const n = Number(String(s).replace(/,/g, '').trim());
  if (!Number.isFinite(n)) throw new Error(`${ctx}: cap "${s}" is not a valid number`);
  return Math.round(n);
}

function parseBool(s: string): boolean {
  return String(s).trim().toUpperCase() === 'TRUE';
}

// ── Markdown table parsing ──────────────────────────────────────────────────────

interface MdTable {
  headers: string[]; // normalized: lowercased, ** and surrounding whitespace stripped
  rawHeaders: string[];
  rows: string[][];
}

function normHeader(cell: string): string {
  return cell.replace(/\*/g, '').trim().toLowerCase();
}

function splitRow(line: string): string[] {
  // Drop the leading/trailing pipe, then split. Keeps interior empties.
  const trimmed = line.trim().replace(/^\|/, '').replace(/\|$/, '');
  return trimmed.split('|').map((c) => c.trim());
}

function isSeparatorRow(cells: string[]): boolean {
  return cells.every((c) => /^:?-{2,}:?$/.test(c.replace(/\s/g, '')));
}

/** Extract every pipe-delimited markdown table in the document. */
function parseTables(md: string): MdTable[] {
  const lines = md.split('\n');
  const tables: MdTable[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const isTableLine = line.trim().startsWith('|') && line.includes('|', 1);
    if (!isTableLine) {
      i++;
      continue;
    }
    // Collect the contiguous block of table lines.
    const block: string[] = [];
    while (i < lines.length && lines[i].trim().startsWith('|')) {
      block.push(lines[i]);
      i++;
    }
    if (block.length < 2) continue;
    const rawHeaders = splitRow(block[0]);
    // Second row must be the separator; otherwise it is not a real table.
    if (!isSeparatorRow(splitRow(block[1]))) continue;
    const rows = block
      .slice(2)
      .map(splitRow)
      .filter((cells) => cells.some((c) => c.length > 0));
    tables.push({headers: rawHeaders.map(normHeader), rawHeaders, rows});
  }
  return tables;
}

/** Find the first table whose normalized headers include all of `required`. */
function findTable(tables: MdTable[], required: string[], label: string): MdTable {
  const t = tables.find((tbl) => required.every((r) => tbl.headers.includes(r)));
  if (!t) throw new Error(`Could not find ${label} table (need columns: ${required.join(', ')})`);
  return t;
}

/** Accessor that resolves a column by header name, tolerant of order. */
function col(table: MdTable, row: string[], header: string, label: string): string {
  const idx = table.headers.indexOf(header);
  if (idx === -1) throw new Error(`${label}: column "${header}" not found`);
  return row[idx] ?? '';
}

// ── Parsed-row shapes ───────────────────────────────────────────────────────────

const warnings: string[] = [];

const ZERO_IR: IrProfile = {
  optimalUsageRatio: 99_00,
  baseDrawnRate: 0,
  rateGrowthBeforeOptimal: 0,
  rateGrowthAfterOptimal: 0,
};

interface SpokeRow {
  hubKey: string;
  spokeKey: string;
  liquidationBonusFactor: number;
  targetHealthFactor: string;
  healthFactorForMaxBonus: string;
}
interface ReserveRow {
  hubKey: string;
  spokeKey: string;
  tokenKey: string;
  collateralFactor: number;
  maxLiquidationBonus: number;
  borrowable: boolean;
  collateralRisk: number;
  liquidationFee: number;
}
interface CapRow {
  hubKey: string;
  spokeKey: string;
  tokenKey: string;
  addCap: number;
  drawCap: number;
}
interface IrRow {
  hubKey: string;
  tokenKey: string;
  irData: IrProfile;
  liquidityFee: number | null;
}

function parseSpokeTable(tables: MdTable[]): SpokeRow[] {
  const t = findTable(
    tables,
    ['liquidation bonus factor', 'target health factor', 'health factor for max bonus'],
    'spoke liquidation',
  );
  return t.rows.map((row) => {
    const hubKey = normalizeHub(col(t, row, 'hub', 'spoke'));
    const spokeKey = normalizeSpoke(col(t, row, 'spoke', 'spoke'));
    const ctx = `spoke ${spokeKey}`;
    return {
      hubKey,
      spokeKey,
      liquidationBonusFactor: pctToBps(col(t, row, 'liquidation bonus factor', ctx), ctx),
      targetHealthFactor: toWadString(col(t, row, 'target health factor', ctx).trim()),
      healthFactorForMaxBonus: toWadString(col(t, row, 'health factor for max bonus', ctx).trim()),
    };
  });
}

function parseReserveTable(tables: MdTable[]): ReserveRow[] {
  const t = findTable(
    tables,
    ['collateral factor', 'max liquidation bonus', 'borrowable', 'liquidation fee'],
    'reserve parameters',
  );
  return t.rows.map((row) => {
    const hubKey = normalizeHub(col(t, row, 'hub', 'reserve'));
    const spokeKey = normalizeSpoke(col(t, row, 'spoke', 'reserve'));
    const tokenKey = normalizeToken(col(t, row, 'reserve', 'reserve'));
    const ctx = `reserve ${tokenKey} on ${spokeKey}`;
    const rawCR = col(t, row, 'collateral risk', ctx);
    const rawLF = col(t, row, 'liquidation fee', ctx);
    return {
      hubKey,
      spokeKey,
      tokenKey,
      collateralFactor: pctToBps(col(t, row, 'collateral factor', ctx), ctx),
      maxLiquidationBonus: parseMaxLiquidationBonus(col(t, row, 'max liquidation bonus', ctx), ctx),
      borrowable: parseBool(col(t, row, 'borrowable', ctx)),
      collateralRisk: isDash(rawCR) ? 0 : pctToBps(rawCR, `${ctx} collateralRisk`),
      liquidationFee: isDash(rawLF) ? 0 : pctToBps(rawLF, `${ctx} liquidationFee`),
    };
  });
}

function parseCapTable(tables: MdTable[]): CapRow[] {
  const t = findTable(tables, ['add cap', 'draw cap'], 'add/draw caps');
  return t.rows.map((row) => {
    const hubKey = normalizeHub(col(t, row, 'hub', 'caps'));
    const spokeKey = normalizeSpoke(col(t, row, 'spoke', 'caps'));
    const tokenKey = normalizeToken(col(t, row, 'reserve', 'caps'));
    const ctx = `caps ${tokenKey} on ${spokeKey}`;
    return {
      hubKey,
      spokeKey,
      tokenKey,
      addCap: parseCap(col(t, row, 'add cap', ctx), `${ctx} addCap`),
      drawCap: parseCap(col(t, row, 'draw cap', ctx), `${ctx} drawCap`),
    };
  });
}

function parseIrTable(tables: MdTable[]): IrRow[] {
  const t = findTable(tables, ['base', 'slope 1', 'slope 2', 'uoptimal'], 'interest rate curves');
  return t.rows.map((row) => {
    const hubKey = normalizeHub(col(t, row, 'hub', 'ir'));
    const tokenKey = normalizeToken(col(t, row, 'reserve', 'ir'));
    const ctx = `ir ${tokenKey} on ${hubKey}`;
    const rawLF = col(t, row, 'liquidity fee', ctx);
    return {
      hubKey,
      tokenKey,
      irData: {
        baseDrawnRate: parseIrBase(col(t, row, 'base', ctx), `${ctx} base`),
        rateGrowthBeforeOptimal: pctToBps(col(t, row, 'slope 1', ctx), `${ctx} slope1`),
        rateGrowthAfterOptimal: pctToBps(col(t, row, 'slope 2', ctx), `${ctx} slope2`),
        optimalUsageRatio: pctToBps(col(t, row, 'uoptimal', ctx), `${ctx} uOptimal`),
      },
      liquidityFee: isDash(rawLF) ? null : pctToBps(rawLF, `${ctx} liquidityFee`),
    };
  });
}

// ── Config assembly ─────────────────────────────────────────────────────────────

function toTitleCase(raw: string): string {
  return raw.charAt(0).toUpperCase() + raw.slice(1).toLowerCase();
}

function buildConfig(
  spokeRows: SpokeRow[],
  reserveRows: ReserveRow[],
  capRows: CapRow[],
  irRows: IrRow[],
): Record<string, unknown> {
  const defaults = {
    spokeRegistration: {riskPremiumThreshold: 0, active: true, halted: false},
    reserve: {
      receiveSharesEnabled: true,
      frozen: false,
      paused: false,
      liquidationFee: 0,
      maxLiquidationBonus: 10000,
    },
    asset: {liquidityFee: 0},
    tokenize: {enabled: true},
  };

  // ── Tokens (checksummed via viem; ZERO feed kept as-is) ──
  const usedTokens = new Set<string>();
  for (const r of reserveRows) usedTokens.add(r.tokenKey);
  for (const r of irRows) usedTokens.add(r.tokenKey);
  for (const c of capRows) usedTokens.add(c.tokenKey);

  const tokens: Record<string, {address: string; priceFeed: string}> = {};
  for (const key of [...usedTokens].sort()) {
    const entry = AVALANCHE_TOKEN_REGISTRY[key];
    if (!entry) throw new Error(`Token "${key}" missing from AVALANCHE_TOKEN_REGISTRY`);
    tokens[key] = {
      address: getAddress(entry.address),
      priceFeed: entry.priceFeed === ZERO ? ZERO : getAddress(entry.priceFeed),
    };
    if (entry.priceFeed === ZERO) {
      warnings.push(`token ${key}: priceFeed is ZERO (placeholder) — set before listing`);
    }
  }

  // ── Hubs ──
  const hubKeys = new Set<string>();
  for (const r of irRows) hubKeys.add(r.hubKey);
  for (const r of reserveRows) hubKeys.add(r.hubKey);
  const hubs = [...hubKeys].map((key) => ({key}));

  // ── Spokes (preserve doc order) ──
  const spokes = spokeRows.map((s) => ({
    key: s.spokeKey,
    liquidationConfig: {
      targetHealthFactor: s.targetHealthFactor,
      healthFactorForMaxBonus: s.healthFactorForMaxBonus,
      liquidationBonusFactor: s.liquidationBonusFactor,
    },
  }));

  // ── Spoke registrations (from caps table) ──
  const spokeRegistrations = capRows.map((c) => ({
    assetKey: c.tokenKey,
    hubKey: c.hubKey,
    spokeKey: c.spokeKey,
    addCap: c.addCap,
    drawCap: c.drawCap,
  }));

  // Aggregate add cap per (asset, hub) → tokenization addCap ("set caps now").
  const aggAddCap = new Map<string, number>();
  for (const c of capRows) {
    const k = `${c.tokenKey}|${c.hubKey}`;
    aggAddCap.set(k, (aggAddCap.get(k) ?? 0) + c.addCap);
  }

  // ── Assets (IR-table order first, then reserve-only assets e.g. sAVAX) ──
  const irByKey = new Map<string, IrRow>();
  for (const r of irRows) irByKey.set(`${r.tokenKey}|${r.hubKey}`, r);

  const assetOrder: string[] = [];
  const seenAsset = new Set<string>();
  const pushAsset = (tokenKey: string, hubKey: string) => {
    const k = `${tokenKey}|${hubKey}`;
    if (!seenAsset.has(k)) {
      seenAsset.add(k);
      assetOrder.push(k);
    }
  };
  for (const r of irRows) pushAsset(r.tokenKey, r.hubKey);
  for (const r of reserveRows) pushAsset(r.tokenKey, r.hubKey);

  const assets = assetOrder.map((k) => {
    const [tokenKey, hubKey] = k.split('|');
    const ir = irByKey.get(k);
    const hubPrefix = toTitleCase(hubKey.replace(/_HUB$/, '')); // CORE_HUB → Core
    const addCap = aggAddCap.get(k) ?? 0;
    const asset: Record<string, unknown> = {
      tokenKey,
      hubKey,
      irData: ir ? ir.irData : ZERO_IR,
    };
    if (ir && ir.liquidityFee !== null && ir.liquidityFee !== defaults.asset.liquidityFee) {
      asset.liquidityFee = ir.liquidityFee;
    }
    // "Set caps now": tokenization enabled with derived addCap + generated name/symbol.
    asset.tokenize = {
      name: `Wrapped Aave ${hubPrefix} ${tokenKey}`,
      symbol: `wa${hubPrefix}${tokenKey}`,
      addCap,
    };
    return asset;
  });

  // ── Reserves ──
  const reserves = reserveRows.map((r) => {
    const reserve: Record<string, unknown> = {
      spokeKey: r.spokeKey,
      hubKey: r.hubKey,
      assetKey: r.tokenKey,
      borrowable: r.borrowable,
      collateralFactor: r.collateralFactor,
      collateralRisk: r.collateralRisk,
    };
    if (r.maxLiquidationBonus !== defaults.reserve.maxLiquidationBonus) {
      reserve.maxLiquidationBonus = r.maxLiquidationBonus;
    }
    if (r.liquidationFee !== defaults.reserve.liquidationFee) {
      reserve.liquidationFee = r.liquidationFee;
    }
    return reserve;
  });

  // ── Periphery (WAVAX is the native wrapper on Avalanche) ──
  const periphery = {
    nativeTokenKey: 'WAVAX',
    deploySignatureGateway: true,
    deployNativeTokenGateway: true,
    deployGiverPositionManager: true,
    deployTakerPositionManager: true,
    deployConfigPositionManager: true,
  };

  return {defaults, tokens, hubs, spokes, assets, spokeRegistrations, reserves, periphery};
}

// ── Main ────────────────────────────────────────────────────────────────────────

function main() {
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const srcPath =
    process.argv[2] || path.resolve(__dirname, '../../avalanche/config/llamarisk-parameters.md');
  const outPath = process.argv[3] || path.resolve(__dirname, '../../avalanche/config/config.json');

  console.error(`Reading: ${srcPath}`);
  const md = fs.readFileSync(srcPath, 'utf8');
  const tables = parseTables(md);
  console.error(`  parsed ${tables.length} markdown tables`);

  const spokeRows = parseSpokeTable(tables);
  const reserveRows = parseReserveTable(tables);
  const capRows = parseCapTable(tables);
  const irRows = parseIrTable(tables);
  console.error(
    `  spokes: ${spokeRows.length}, reserves: ${reserveRows.length}, caps: ${capRows.length}, ir: ${irRows.length}`,
  );

  const config = buildConfig(spokeRows, reserveRows, capRows, irRows);

  const result = validate(config);
  if (warnings.length > 0) {
    console.error('\nGenerator WARNINGS:');
    warnings.forEach((w) => console.error(`  ${w}`));
  }
  if (result.errors.length > 0) {
    console.error('\nValidation ERRORS:');
    result.errors.forEach((e) => console.error(`  [${e.code}] ${e.msg}`));
  }
  if (result.warnings.length > 0) {
    console.error('\nValidation WARNINGS:');
    result.warnings.forEach((w) => console.error(`  [${w.code}] ${w.msg}`));
  }
  console.error(`\n=== ${result.errors.length} error(s), ${result.warnings.length} warning(s) ===`);

  fs.writeFileSync(outPath, JSON.stringify(config, null, 2) + '\n');
  console.error(`\nWritten to: ${outPath}`);

  if (result.errors.length > 0) process.exit(1);
}

main();
