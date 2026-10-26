import fs from 'fs';
import path from 'path';
import {createPublicClient, http, getAddress, type Address, type PublicClient} from 'viem';
import {mainnet} from 'viem/chains';
import prettier from 'prettier';
import {marketPaths} from './markets.ts';

// ── CLI ──────────────────────────────────────────────────────────────────────

const market = process.argv[2];
const paths = marketPaths(market);

const configFlagIdx = process.argv.indexOf('--config');
const configPath =
  configFlagIdx !== -1 && process.argv[configFlagIdx + 1]
    ? path.resolve(process.argv[configFlagIdx + 1])
    : path.join(paths.config, 'config.json');

const deploy = JSON.parse(fs.readFileSync(path.join(paths.config, 'deployment.json'), 'utf8'));
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// ── RPC resolution from foundry.toml ─────────────────────────────────────────

function resolveRpcUrl(alias: string): string {
  const tomlPath = path.resolve(__dirname, '..', '..', '..', 'foundry.toml');
  const toml = fs.readFileSync(tomlPath, 'utf8');
  const lines = toml.split('\n');

  let inRpcSection = false;
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === '[rpc_endpoints]') {
      inRpcSection = true;
      continue;
    }
    if (trimmed.startsWith('[') && inRpcSection) break;
    if (!inRpcSection) continue;

    const match = trimmed.match(/^(\w+)\s*=\s*"(.+)"$/);
    if (match && match[1] === alias) {
      const value = match[2];
      const envMatch = value.match(/^\$\{(\w+)\}$/);
      if (envMatch) {
        const envVal = process.env[envMatch[1]];
        if (!envVal) {
          console.error(`Env var ${envMatch[1]} not set (needed for RPC alias "${alias}")`);
          process.exit(1);
        }
        return envVal;
      }
      return value;
    }
  }
  console.error(`RPC alias "${alias}" not found in foundry.toml [rpc_endpoints]`);
  process.exit(1);
}

const rpcUrl = resolveRpcUrl(paths.rpcAlias);
console.log(`RPC: ${rpcUrl.slice(0, 60)}...`);

const client: PublicClient = createPublicClient({
  chain: mainnet,
  transport: http(rpcUrl),
});

// ── Inline ABIs ──────────────────────────────────────────────────────────────

const hubAbi = [
  {
    name: 'getAssetId',
    type: 'function',
    stateMutability: 'view',
    inputs: [{name: 'underlying', type: 'address'}],
    outputs: [{name: '', type: 'uint256'}],
  },
  {
    name: 'isUnderlyingListed',
    type: 'function',
    stateMutability: 'view',
    inputs: [{name: 'underlying', type: 'address'}],
    outputs: [{name: '', type: 'bool'}],
  },
  {
    name: 'getAssetConfig',
    type: 'function',
    stateMutability: 'view',
    inputs: [{name: 'assetId', type: 'uint256'}],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          {name: 'feeReceiver', type: 'address'},
          {name: 'liquidityFee', type: 'uint16'},
          {name: 'irStrategy', type: 'address'},
          {name: 'reinvestmentController', type: 'address'},
        ],
      },
    ],
  },
  {
    name: 'isSpokeListed',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      {name: 'assetId', type: 'uint256'},
      {name: 'spoke', type: 'address'},
    ],
    outputs: [{name: '', type: 'bool'}],
  },
  {
    name: 'getSpokeConfig',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      {name: 'assetId', type: 'uint256'},
      {name: 'spoke', type: 'address'},
    ],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          {name: 'addCap', type: 'uint40'},
          {name: 'drawCap', type: 'uint40'},
          {name: 'riskPremiumThreshold', type: 'uint24'},
          {name: 'active', type: 'bool'},
          {name: 'halted', type: 'bool'},
        ],
      },
    ],
  },
] as const;

const irStrategyAbi = [
  {
    name: 'getInterestRateData',
    type: 'function',
    stateMutability: 'view',
    inputs: [{name: 'assetId', type: 'uint256'}],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          {name: 'optimalUsageRatio', type: 'uint16'},
          {name: 'baseDrawnRate', type: 'uint32'},
          {name: 'rateGrowthBeforeOptimal', type: 'uint32'},
          {name: 'rateGrowthAfterOptimal', type: 'uint32'},
        ],
      },
    ],
  },
] as const;

const spokeAbi = [
  {
    name: 'getReserveId',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      {name: 'hub', type: 'address'},
      {name: 'assetId', type: 'uint256'},
    ],
    outputs: [{name: '', type: 'uint256'}],
  },
  {
    name: 'getReserveConfig',
    type: 'function',
    stateMutability: 'view',
    inputs: [{name: 'reserveId', type: 'uint256'}],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          {name: 'collateralRisk', type: 'uint24'},
          {name: 'paused', type: 'bool'},
          {name: 'frozen', type: 'bool'},
          {name: 'borrowable', type: 'bool'},
          {name: 'receiveSharesEnabled', type: 'bool'},
        ],
      },
    ],
  },
  {
    name: 'getReserve',
    type: 'function',
    stateMutability: 'view',
    inputs: [{name: 'reserveId', type: 'uint256'}],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          {name: 'underlying', type: 'address'},
          {name: 'hub', type: 'address'},
          {name: 'assetId', type: 'uint16'},
          {name: 'decimals', type: 'uint8'},
          {name: 'collateralRisk', type: 'uint24'},
          {name: 'flags', type: 'uint8'},
          {name: 'dynamicConfigKey', type: 'uint32'},
        ],
      },
    ],
  },
  {
    name: 'getDynamicReserveConfig',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      {name: 'reserveId', type: 'uint256'},
      {name: 'dynamicConfigKey', type: 'uint32'},
    ],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          {name: 'collateralFactor', type: 'uint16'},
          {name: 'maxLiquidationBonus', type: 'uint32'},
          {name: 'liquidationFee', type: 'uint16'},
        ],
      },
    ],
  },
  {
    name: 'getLiquidationConfig',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          {name: 'targetHealthFactor', type: 'uint128'},
          {name: 'healthFactorForMaxBonus', type: 'uint64'},
          {name: 'liquidationBonusFactor', type: 'uint16'},
        ],
      },
    ],
  },
] as const;

const oracleAbi = [
  {
    name: 'getReserveSource',
    type: 'function',
    stateMutability: 'view',
    inputs: [{name: 'reserveId', type: 'uint256'}],
    outputs: [{name: '', type: 'address'}],
  },
] as const;

// ── Types ────────────────────────────────────────────────────────────────────

interface Diff {
  category: string;
  label: string;
  field: string;
  onChain: string;
  desired: string;
}

interface NewItem {
  category: string;
  label: string;
}

// Caches
const assetIdCache: Record<string, Record<string, bigint>> = {}; // hubAddr -> tokenAddr -> assetId

// ── Helpers ──────────────────────────────────────────────────────────────────

function sanitizeKey(key: string) {
  if (/^\d/.test(key)) return '_' + key;
  return key;
}

function tokenRef(tokenKey: string) {
  return `Tokens.${sanitizeKey(tokenKey)}`;
}
function hubRef(hubKey: string) {
  return `Hubs.${hubKey}`;
}
function spokeRef(spokeKey: string) {
  return `Spokes.${spokeKey}`;
}
function irRef(hubKey: string) {
  return `IrStrategies.${hubKey}`;
}

function addr(a: string): Address {
  return getAddress(a) as Address;
}

// ── Phase A: Read hub asset configs ──────────────────────────────────────────

type OnChainAsset =
  | {listed: false}
  | {
      listed: true;
      assetId: bigint;
      liquidityFee: number;
      irData: {
        optimalUsageRatio: number;
        baseDrawnRate: number;
        rateGrowthBeforeOptimal: number;
        rateGrowthAfterOptimal: number;
      };
    };

async function readHubAssets(): Promise<Map<string, OnChainAsset>> {
  const results = new Map<string, OnChainAsset>();

  // Group assets by hub, tracking original config entries
  const byHub: Record<string, {tokenKey: string; hubKey: string}[]> = {};
  for (const a of config.assets) {
    (byHub[a.hubKey] ||= []).push(a);
  }

  for (const [hubKey, assets] of Object.entries(byHub)) {
    const hubAddr = addr(deploy.hub[hubKey]);
    if (!hubAddr) throw new Error(`No hub address for ${hubKey} in deployment JSON`);
    const irStratAddr = addr(deploy.irStrategy[hubKey]);
    if (!irStratAddr) throw new Error(`No IR strategy address for ${hubKey} in deployment JSON`);

    // Step 1: Check which are listed
    const listedCalls = assets.map((a: any) => ({
      address: hubAddr,
      abi: hubAbi,
      functionName: 'isUnderlyingListed' as const,
      args: [addr(config.tokens[a.tokenKey].address)],
    }));
    const listedResults = await client.multicall({contracts: listedCalls});

    // Step 2: Get asset IDs for listed ones
    const listedEntries: {idx: number; tokenKey: string}[] = [];
    for (let i = 0; i < assets.length; i++) {
      const r = listedResults[i];
      if (r.status !== 'success')
        throw new Error(
          `isUnderlyingListed failed for ${hubKey}/${assets[i].tokenKey}: ${r.error}`,
        );
      if (r.result) listedEntries.push({idx: i, tokenKey: assets[i].tokenKey});
      else results.set(`${hubKey}/${assets[i].tokenKey}`, {listed: false});
    }

    if (listedEntries.length === 0) continue;

    const idCalls = listedEntries.map((e) => ({
      address: hubAddr,
      abi: hubAbi,
      functionName: 'getAssetId' as const,
      args: [addr(config.tokens[e.tokenKey].address)],
    }));
    const idResults = await client.multicall({contracts: idCalls});

    // Step 3: Get config + IR data
    const configCalls: any[] = [];
    const irCalls: any[] = [];
    const batchEntries: {tokenKey: string; assetId: bigint}[] = [];

    for (let j = 0; j < listedEntries.length; j++) {
      const r = idResults[j];
      if (r.status !== 'success')
        throw new Error(`getAssetId failed for ${hubKey}/${listedEntries[j].tokenKey}: ${r.error}`);
      const assetId = r.result as bigint;

      // Cache for later phases
      if (!assetIdCache[hubAddr]) assetIdCache[hubAddr] = {};
      assetIdCache[hubAddr][addr(config.tokens[listedEntries[j].tokenKey].address)] = assetId;

      configCalls.push({
        address: hubAddr,
        abi: hubAbi,
        functionName: 'getAssetConfig' as const,
        args: [assetId],
      });
      irCalls.push({
        address: irStratAddr,
        abi: irStrategyAbi,
        functionName: 'getInterestRateData' as const,
        args: [assetId],
      });
      batchEntries.push({tokenKey: listedEntries[j].tokenKey, assetId});
    }

    const [configResults, irResults] = await Promise.all([
      client.multicall({contracts: configCalls}),
      client.multicall({contracts: irCalls}),
    ]);

    for (let j = 0; j < batchEntries.length; j++) {
      const {tokenKey, assetId} = batchEntries[j];
      const key = `${hubKey}/${tokenKey}`;

      const cr = configResults[j];
      if (cr.status !== 'success') throw new Error(`getAssetConfig failed for ${key}: ${cr.error}`);
      const assetConfig = cr.result as any;

      const ir = irResults[j];
      if (ir.status !== 'success')
        throw new Error(`getInterestRateData failed for ${key}: ${ir.error}`);
      const irData = ir.result as any;

      results.set(key, {
        listed: true,
        assetId,
        liquidityFee: Number(assetConfig.liquidityFee),
        irData: {
          optimalUsageRatio: Number(irData.optimalUsageRatio),
          baseDrawnRate: Number(irData.baseDrawnRate),
          rateGrowthBeforeOptimal: Number(irData.rateGrowthBeforeOptimal),
          rateGrowthAfterOptimal: Number(irData.rateGrowthAfterOptimal),
        },
      });
    }
  }

  return results;
}

// ── Phase B: Read hub spoke registrations ────────────────────────────────────

type OnChainSpokeReg =
  | {listed: false}
  | {
      listed: true;
      addCap: number;
      drawCap: number;
      riskPremiumThreshold: number;
      active: boolean;
      halted: boolean;
    };

async function readSpokeRegistrations(): Promise<Map<string, OnChainSpokeReg>> {
  const results = new Map<string, OnChainSpokeReg>();

  // Group by hub for batching
  const byHub: Record<string, {assetKey: string; hubKey: string; spokeKey: string}[]> = {};
  for (const reg of config.spokeRegistrations) {
    (byHub[reg.hubKey] ||= []).push(reg);
  }

  for (const [hubKey, regs] of Object.entries(byHub)) {
    const hubAddr = addr(deploy.hub[hubKey]);
    if (!hubAddr) throw new Error(`No hub address for ${hubKey} in deployment JSON`);

    // Resolve assetIds — error if not cached (means asset wasn't listed in Phase A)
    const resolved: {reg: any; assetId: bigint; spokeAddr: Address; key: string}[] = [];
    for (const r of regs) {
      const key = `${r.hubKey}/${r.assetKey}/${r.spokeKey}`;
      const tokenAddr = addr(config.tokens[r.assetKey].address);
      const cachedId = assetIdCache[hubAddr]?.[tokenAddr];
      if (cachedId === undefined) {
        // Asset not listed on this hub — spoke reg can't exist
        results.set(key, {listed: false});
        continue;
      }
      const spokeAddr = addr(deploy.spoke[r.spokeKey]);
      if (!spokeAddr) throw new Error(`No spoke address for ${r.spokeKey} in deployment JSON`);
      resolved.push({reg: r, assetId: cachedId, spokeAddr, key});
    }

    if (resolved.length === 0) continue;

    // Check which are listed
    const listedCalls = resolved.map((e) => ({
      address: hubAddr,
      abi: hubAbi,
      functionName: 'isSpokeListed' as const,
      args: [e.assetId, e.spokeAddr],
    }));
    const listedResults = await client.multicall({contracts: listedCalls});

    // Collect listed entries for config read
    const listedEntries: {entry: (typeof resolved)[0]; idx: number}[] = [];
    for (let j = 0; j < resolved.length; j++) {
      const r = listedResults[j];
      if (r.status !== 'success')
        throw new Error(`isSpokeListed failed for ${resolved[j].key}: ${r.error}`);
      if (r.result) listedEntries.push({entry: resolved[j], idx: j});
      else results.set(resolved[j].key, {listed: false});
    }

    if (listedEntries.length === 0) continue;

    // Get configs for listed spokes
    const configCalls = listedEntries.map((e) => ({
      address: hubAddr,
      abi: hubAbi,
      functionName: 'getSpokeConfig' as const,
      args: [e.entry.assetId, e.entry.spokeAddr],
    }));
    const configResults = await client.multicall({contracts: configCalls});

    for (let j = 0; j < listedEntries.length; j++) {
      const {entry} = listedEntries[j];
      const cr = configResults[j];
      if (cr.status !== 'success')
        throw new Error(`getSpokeConfig failed for ${entry.key}: ${cr.error}`);
      const sc = cr.result as any;

      results.set(entry.key, {
        listed: true,
        addCap: Number(sc.addCap),
        drawCap: Number(sc.drawCap),
        riskPremiumThreshold: Number(sc.riskPremiumThreshold),
        active: sc.active,
        halted: sc.halted,
      });
    }
  }

  return results;
}

// ── Phase C: Read spoke liquidation configs ──────────────────────────────────

interface OnChainLiqConfig {
  spokeKey: string;
  targetHealthFactor: bigint;
  healthFactorForMaxBonus: bigint;
  liquidationBonusFactor: number;
}

async function readLiquidationConfigs(): Promise<OnChainLiqConfig[]> {
  const calls = config.spokes.map((s: any) => ({
    address: addr(deploy.spoke[s.key]),
    abi: spokeAbi,
    functionName: 'getLiquidationConfig' as const,
  }));

  const results = await client.multicall({contracts: calls});

  return config.spokes.map((s: any, i: number) => {
    const r = results[i];
    if (r.status !== 'success')
      throw new Error(`getLiquidationConfig failed for ${s.key}: ${r.error}`);
    const data = r.result as any;
    return {
      spokeKey: s.key,
      targetHealthFactor: BigInt(data.targetHealthFactor),
      healthFactorForMaxBonus: BigInt(data.healthFactorForMaxBonus),
      liquidationBonusFactor: Number(data.liquidationBonusFactor),
    };
  });
}

// ── Phase D: Read spoke reserves ─────────────────────────────────────────────

type OnChainReserve =
  | {listed: false}
  | {
      listed: true;
      reserveId: bigint;
      dynamicConfigKey: number;
      collateralRisk: number;
      paused: boolean;
      frozen: boolean;
      borrowable: boolean;
      receiveSharesEnabled: boolean;
      collateralFactor: number;
      maxLiquidationBonus: number;
      liquidationFee: number;
      priceSource: string;
    };

async function readReserves(): Promise<Map<string, OnChainReserve>> {
  const results = new Map<string, OnChainReserve>();

  // Group by spoke for batching
  const bySpoke: Record<string, {spokeKey: string; hubKey: string; assetKey: string}[]> = {};
  for (const r of config.reserves) {
    (bySpoke[r.spokeKey] ||= []).push(r);
  }

  for (const [spokeKey, reserves] of Object.entries(bySpoke)) {
    const spokeAddr = addr(deploy.spoke[spokeKey]);
    if (!spokeAddr) throw new Error(`No spoke address for ${spokeKey} in deployment JSON`);
    if (!deploy.oracle?.[spokeKey])
      throw new Error(`No oracle address for ${spokeKey} in deployment JSON`);
    const oracleAddr = addr(deploy.oracle[spokeKey]);

    // Resolve assetIds — skip reserves where asset not cached
    const resolved: {r: any; hubAddr: Address; assetId: bigint; key: string}[] = [];
    for (const r of reserves) {
      const key = `${r.spokeKey}/${r.hubKey}/${r.assetKey}`;
      const hubAddr = addr(deploy.hub[r.hubKey]);
      const tokenAddr = addr(config.tokens[r.assetKey].address);
      const cachedId = assetIdCache[hubAddr]?.[tokenAddr];
      if (cachedId === undefined) {
        results.set(key, {listed: false});
        continue;
      }
      resolved.push({r, hubAddr, assetId: cachedId, key});
    }

    if (resolved.length === 0) continue;

    // Step 1: Get reserve IDs (may revert for unlisted reserves)
    const idCalls = resolved.map((e) => ({
      address: spokeAddr,
      abi: spokeAbi,
      functionName: 'getReserveId' as const,
      args: [e.hubAddr, e.assetId],
    }));
    const idResults = await client.multicall({contracts: idCalls});

    // Collect found reserves
    const found: {entry: (typeof resolved)[0]; reserveId: bigint}[] = [];
    for (let j = 0; j < resolved.length; j++) {
      const r = idResults[j];
      if (r.status !== 'success') {
        // getReserveId reverts for unlisted reserves
        results.set(resolved[j].key, {listed: false});
        continue;
      }
      found.push({entry: resolved[j], reserveId: r.result as bigint});
    }

    if (found.length === 0) continue;

    // Step 2: Batch read config + reserve struct + oracle
    const configCalls = found.map((e) => ({
      address: spokeAddr,
      abi: spokeAbi,
      functionName: 'getReserveConfig' as const,
      args: [e.reserveId],
    }));
    const reserveCalls = found.map((e) => ({
      address: spokeAddr,
      abi: spokeAbi,
      functionName: 'getReserve' as const,
      args: [e.reserveId],
    }));
    const oracleCalls = found.map((e) => ({
      address: oracleAddr,
      abi: oracleAbi,
      functionName: 'getReserveSource' as const,
      args: [e.reserveId],
    }));

    const [configResults, reserveResults, oracleResults] = await Promise.all([
      client.multicall({contracts: configCalls}),
      client.multicall({contracts: reserveCalls}),
      client.multicall({contracts: oracleCalls}),
    ]);

    // Step 3: Read dynamic configs (need dynamicConfigKey from reserve struct)
    const dynEntries: {foundIdx: number; reserveId: bigint; dynamicConfigKey: number}[] = [];
    for (let j = 0; j < found.length; j++) {
      const rr = reserveResults[j];
      if (rr.status !== 'success')
        throw new Error(`getReserve failed for ${found[j].entry.key}: ${rr.error}`);
      const reserve = rr.result as any;
      dynEntries.push({
        foundIdx: j,
        reserveId: found[j].reserveId,
        dynamicConfigKey: Number(reserve.dynamicConfigKey),
      });
    }

    const dynCalls = dynEntries.map((e) => ({
      address: spokeAddr,
      abi: spokeAbi,
      functionName: 'getDynamicReserveConfig' as const,
      args: [e.reserveId, e.dynamicConfigKey],
    }));
    const dynResults = dynCalls.length > 0 ? await client.multicall({contracts: dynCalls}) : [];

    // Build results
    for (let j = 0; j < found.length; j++) {
      const {entry, reserveId} = found[j];
      const {dynamicConfigKey} = dynEntries[j];

      const cr = configResults[j];
      if (cr.status !== 'success')
        throw new Error(`getReserveConfig failed for ${entry.key}: ${cr.error}`);
      const rc = cr.result as any;

      const dr = dynResults[j];
      if (dr.status !== 'success')
        throw new Error(`getDynamicReserveConfig failed for ${entry.key}: ${dr.error}`);
      const dc = dr.result as any;

      const oracleResult = oracleResults[j];
      if (oracleResult.status !== 'success')
        throw new Error(`getReserveSource failed for ${entry.key}: ${oracleResult.error}`);
      const priceSource = getAddress(oracleResult.result as string);

      results.set(entry.key, {
        listed: true,
        reserveId,
        dynamicConfigKey,
        collateralRisk: Number(rc.collateralRisk),
        paused: rc.paused,
        frozen: rc.frozen,
        borrowable: rc.borrowable,
        receiveSharesEnabled: rc.receiveSharesEnabled,
        collateralFactor: Number(dc.collateralFactor),
        maxLiquidationBonus: Number(dc.maxLiquidationBonus),
        liquidationFee: Number(dc.liquidationFee),
        priceSource,
      });
    }
  }

  return results;
}

// ── Diff logic ───────────────────────────────────────────────────────────────

function requireDefault<T>(section: string, field: string, value: T | undefined): T {
  if (value === undefined) throw new Error(`Missing config default: defaults.${section}.${field}`);
  return value;
}

function diffAssets(onChainMap: Map<string, OnChainAsset>): {diffs: Diff[]; newItems: NewItem[]} {
  const diffs: Diff[] = [];
  const newItems: NewItem[] = [];
  const defaults = config.defaults?.asset || {};

  for (const a of config.assets) {
    const key = `${a.hubKey}/${a.tokenKey}`;
    const label = `${a.hubKey} / ${a.tokenKey}`;
    const oc = onChainMap.get(key);

    if (!oc || !oc.listed) {
      newItems.push({category: 'asset', label});
      continue;
    }

    const desiredLiqFee =
      a.liquidityFee !== undefined
        ? a.liquidityFee
        : requireDefault('asset', 'liquidityFee', defaults.liquidityFee);
    if (oc.liquidityFee !== desiredLiqFee) {
      diffs.push({
        category: 'asset',
        label,
        field: 'liquidityFee',
        onChain: String(oc.liquidityFee),
        desired: String(desiredLiqFee),
      });
    }

    if (a.irData && oc.irData) {
      for (const field of [
        'optimalUsageRatio',
        'baseDrawnRate',
        'rateGrowthBeforeOptimal',
        'rateGrowthAfterOptimal',
      ] as const) {
        if (oc.irData[field] !== a.irData[field]) {
          diffs.push({
            category: 'asset',
            label,
            field,
            onChain: String(oc.irData[field]),
            desired: String(a.irData[field]),
          });
        }
      }
    }
  }

  return {diffs, newItems};
}

function diffSpokeRegistrations(onChainMap: Map<string, OnChainSpokeReg>): {
  diffs: Diff[];
  newItems: NewItem[];
} {
  const diffs: Diff[] = [];
  const newItems: NewItem[] = [];
  const defaults = config.defaults?.spokeRegistration || {};

  for (const r of config.spokeRegistrations) {
    const key = `${r.hubKey}/${r.assetKey}/${r.spokeKey}`;
    const label = `${r.hubKey} / ${r.assetKey} / ${r.spokeKey}`;
    const oc = onChainMap.get(key);

    if (!oc || !oc.listed) {
      newItems.push({category: 'spokeRegistration', label});
      continue;
    }

    const fields: {name: string; desired: any; onChain: any}[] = [
      {name: 'addCap', desired: r.addCap, onChain: oc.addCap},
      {name: 'drawCap', desired: r.drawCap, onChain: oc.drawCap},
      {
        name: 'riskPremiumThreshold',
        desired:
          r.riskPremiumThreshold !== undefined
            ? r.riskPremiumThreshold
            : requireDefault(
                'spokeRegistration',
                'riskPremiumThreshold',
                defaults.riskPremiumThreshold,
              ),
        onChain: oc.riskPremiumThreshold,
      },
      {
        name: 'active',
        desired:
          r.active !== undefined
            ? r.active
            : requireDefault('spokeRegistration', 'active', defaults.active),
        onChain: oc.active,
      },
      {
        name: 'halted',
        desired:
          r.halted !== undefined
            ? r.halted
            : requireDefault('spokeRegistration', 'halted', defaults.halted),
        onChain: oc.halted,
      },
    ];

    for (const f of fields) {
      if (String(f.onChain) !== String(f.desired)) {
        diffs.push({
          category: 'spokeRegistration',
          label,
          field: f.name,
          onChain: String(f.onChain),
          desired: String(f.desired),
        });
      }
    }
  }

  return {diffs, newItems};
}

function diffLiquidationConfigs(onChain: OnChainLiqConfig[]): Diff[] {
  const diffs: Diff[] = [];
  const defaultLiq = config.defaults?.spoke?.liquidationConfig || {};

  for (let i = 0; i < config.spokes.length; i++) {
    const s = config.spokes[i];
    const oc = onChain[i];
    const label = s.key;
    const liq = s.liquidationConfig || {};

    const desiredThf = BigInt(
      liq.targetHealthFactor ||
        requireDefault(
          'spoke.liquidationConfig',
          'targetHealthFactor',
          defaultLiq.targetHealthFactor,
        ),
    );
    const desiredHfmb = BigInt(
      liq.healthFactorForMaxBonus ||
        requireDefault(
          'spoke.liquidationConfig',
          'healthFactorForMaxBonus',
          defaultLiq.healthFactorForMaxBonus,
        ),
    );
    const desiredLbf =
      liq.liquidationBonusFactor !== undefined
        ? liq.liquidationBonusFactor
        : requireDefault(
            'spoke.liquidationConfig',
            'liquidationBonusFactor',
            defaultLiq.liquidationBonusFactor,
          );

    if (oc.targetHealthFactor !== desiredThf) {
      diffs.push({
        category: 'liquidationConfig',
        label,
        field: 'targetHealthFactor',
        onChain: oc.targetHealthFactor.toString(),
        desired: desiredThf.toString(),
      });
    }
    if (oc.healthFactorForMaxBonus !== desiredHfmb) {
      diffs.push({
        category: 'liquidationConfig',
        label,
        field: 'healthFactorForMaxBonus',
        onChain: oc.healthFactorForMaxBonus.toString(),
        desired: desiredHfmb.toString(),
      });
    }
    if (oc.liquidationBonusFactor !== desiredLbf) {
      diffs.push({
        category: 'liquidationConfig',
        label,
        field: 'liquidationBonusFactor',
        onChain: String(oc.liquidationBonusFactor),
        desired: String(desiredLbf),
      });
    }
  }

  return diffs;
}

interface ReserveDiffs {
  reserveConfigDiffs: Diff[];
  dynamicConfigDiffs: Diff[];
  newItems: NewItem[];
  // Store extra context for payload generation
  reserveContext: Map<string, {dynamicConfigKey: number; reserveId: bigint}>;
}

function diffReserves(onChainMap: Map<string, OnChainReserve>): ReserveDiffs {
  const reserveConfigDiffs: Diff[] = [];
  const dynamicConfigDiffs: Diff[] = [];
  const newItems: NewItem[] = [];
  const reserveContext = new Map<string, {dynamicConfigKey: number; reserveId: bigint}>();
  const defaultReserve = config.defaults?.reserve || {};

  for (const r of config.reserves) {
    const key = `${r.spokeKey}/${r.hubKey}/${r.assetKey}`;
    const label = `${r.spokeKey} / ${r.hubKey} / ${r.assetKey}`;
    const oc = onChainMap.get(key);

    if (!oc || !oc.listed) {
      newItems.push({category: 'reserve', label});
      continue;
    }

    reserveContext.set(label, {dynamicConfigKey: oc.dynamicConfigKey, reserveId: oc.reserveId});

    // Reserve config diffs
    const desiredPriceSource = getAddress(config.tokens[r.assetKey].priceFeed);
    if (oc.priceSource !== desiredPriceSource) {
      reserveConfigDiffs.push({
        category: 'reserve',
        label,
        field: 'priceSource',
        onChain: oc.priceSource,
        desired: desiredPriceSource,
      });
    }

    if (oc.collateralRisk !== r.collateralRisk) {
      reserveConfigDiffs.push({
        category: 'reserve',
        label,
        field: 'collateralRisk',
        onChain: String(oc.collateralRisk),
        desired: String(r.collateralRisk),
      });
    }

    const boolFields: {name: string; desired: any; onChain: any}[] = [
      {name: 'borrowable', desired: r.borrowable, onChain: oc.borrowable},
      {
        name: 'paused',
        desired:
          r.paused !== undefined
            ? r.paused
            : requireDefault('reserve', 'paused', defaultReserve.paused),
        onChain: oc.paused,
      },
      {
        name: 'frozen',
        desired:
          r.frozen !== undefined
            ? r.frozen
            : requireDefault('reserve', 'frozen', defaultReserve.frozen),
        onChain: oc.frozen,
      },
      {
        name: 'receiveSharesEnabled',
        desired:
          r.receiveSharesEnabled !== undefined
            ? r.receiveSharesEnabled
            : requireDefault(
                'reserve',
                'receiveSharesEnabled',
                defaultReserve.receiveSharesEnabled,
              ),
        onChain: oc.receiveSharesEnabled,
      },
    ];

    for (const f of boolFields) {
      if (f.onChain !== f.desired) {
        reserveConfigDiffs.push({
          category: 'reserve',
          label,
          field: f.name,
          onChain: String(f.onChain),
          desired: String(f.desired),
        });
      }
    }

    // Dynamic reserve config diffs
    const desiredCF = r.collateralFactor;
    const desiredMLB =
      r.maxLiquidationBonus !== undefined
        ? r.maxLiquidationBonus
        : requireDefault('reserve', 'maxLiquidationBonus', defaultReserve.maxLiquidationBonus);
    const desiredLF =
      r.liquidationFee !== undefined
        ? r.liquidationFee
        : requireDefault('reserve', 'liquidationFee', defaultReserve.liquidationFee);

    if (oc.collateralFactor !== desiredCF) {
      dynamicConfigDiffs.push({
        category: 'dynamicReserve',
        label,
        field: 'collateralFactor',
        onChain: String(oc.collateralFactor),
        desired: String(desiredCF),
      });
    }
    if (oc.maxLiquidationBonus !== desiredMLB) {
      dynamicConfigDiffs.push({
        category: 'dynamicReserve',
        label,
        field: 'maxLiquidationBonus',
        onChain: String(oc.maxLiquidationBonus),
        desired: String(desiredMLB),
      });
    }
    if (oc.liquidationFee !== desiredLF) {
      dynamicConfigDiffs.push({
        category: 'dynamicReserve',
        label,
        field: 'liquidationFee',
        onChain: String(oc.liquidationFee),
        desired: String(desiredLF),
      });
    }
  }

  return {reserveConfigDiffs, dynamicConfigDiffs, newItems, reserveContext};
}

// ── Console output ───────────────────────────────────────────────────────────

function printDiffSection(title: string, diffs: Diff[]) {
  // Group by label
  const grouped: Record<string, Diff[]> = {};
  for (const d of diffs) {
    (grouped[d.label] ||= []).push(d);
  }
  const labels = Object.keys(grouped);

  console.log(`\n--- ${title} (${labels.length}) ---`);
  if (labels.length === 0) {
    console.log('  (none)');
    return;
  }
  for (const label of labels) {
    console.log(`  ${label}`);
    for (const d of grouped[label]) {
      console.log(`    ${d.field}: ${d.onChain} → ${d.desired}`);
    }
  }
}

function printNewItems(items: NewItem[]) {
  console.log(`\n--- Not Yet On-chain (${items.length}) ---`);
  if (items.length === 0) {
    console.log('  (none)');
    return;
  }
  for (const item of items) {
    console.log(`  [NEW ${item.category.toUpperCase()}] ${item.label}`);
  }
}

// ── Solidity generation ──────────────────────────────────────────────────────

function genHubAssetConfigUpdates(diffs: Diff[]): string | null {
  // Group diffs by label (hubKey / tokenKey)
  const grouped: Record<string, Diff[]> = {};
  for (const d of diffs) (grouped[d.label] ||= []).push(d);
  const labels = Object.keys(grouped);
  if (labels.length === 0) return null;

  const lines: string[] = [];
  lines.push(
    `  function hubAssetConfigUpdates() public pure override returns (IAaveV4ConfigEngine.AssetConfigUpdate[] memory updates) {`,
  );
  lines.push(`    updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](${labels.length});`);

  for (let i = 0; i < labels.length; i++) {
    const label = labels[i];
    const labelDiffs = grouped[label];
    const [hubKey, tokenKey] = label.split(' / ');

    const changedFields = new Set(labelDiffs.map((d) => d.field));
    const desiredByField: Record<string, string> = {};
    for (const d of labelDiffs) desiredByField[d.field] = d.desired;

    const liquidityFee = changedFields.has('liquidityFee')
      ? desiredByField['liquidityFee']
      : 'EngineFlags.KEEP_CURRENT';
    const optUsage = changedFields.has('optimalUsageRatio')
      ? desiredByField['optimalUsageRatio']
      : 'EngineFlags.KEEP_CURRENT_UINT16';
    const baseRate = changedFields.has('baseDrawnRate')
      ? desiredByField['baseDrawnRate']
      : 'EngineFlags.KEEP_CURRENT_UINT32';
    const rGrowthBefore = changedFields.has('rateGrowthBeforeOptimal')
      ? desiredByField['rateGrowthBeforeOptimal']
      : 'EngineFlags.KEEP_CURRENT_UINT32';
    const rGrowthAfter = changedFields.has('rateGrowthAfterOptimal')
      ? desiredByField['rateGrowthAfterOptimal']
      : 'EngineFlags.KEEP_CURRENT_UINT32';

    // Determine if any IR field changed
    const anyIrChange = [
      'optimalUsageRatio',
      'baseDrawnRate',
      'rateGrowthBeforeOptimal',
      'rateGrowthAfterOptimal',
    ].some((f) => changedFields.has(f));

    lines.push(`    updates[${i}] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: IHubConfigurator(Infra.HUB_CONFIGURATOR),
      hub: ${hubRef(hubKey)},
      underlying: ${tokenRef(tokenKey)},
      liquidityFee: ${liquidityFee},
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: ${anyIrChange ? irRef(hubKey) : 'EngineFlags.KEEP_CURRENT_ADDRESS'},
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: ${optUsage},
        baseDrawnRate: ${baseRate},
        rateGrowthBeforeOptimal: ${rGrowthBefore},
        rateGrowthAfterOptimal: ${rGrowthAfter}
      }),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });`);
  }

  lines.push(`    return updates;`);
  lines.push(`  }`);
  return lines.join('\n');
}

function genHubSpokeConfigUpdates(diffs: Diff[]): string | null {
  const grouped: Record<string, Diff[]> = {};
  for (const d of diffs) (grouped[d.label] ||= []).push(d);
  const labels = Object.keys(grouped);
  if (labels.length === 0) return null;

  const lines: string[] = [];
  lines.push(
    `  function hubSpokeConfigUpdates() public pure override returns (IAaveV4ConfigEngine.SpokeConfigUpdate[] memory updates) {`,
  );
  lines.push(`    updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](${labels.length});`);

  for (let i = 0; i < labels.length; i++) {
    const label = labels[i];
    const labelDiffs = grouped[label];
    const [hubKey, assetKey, spokeKey] = label.split(' / ');

    const changedFields = new Set(labelDiffs.map((d) => d.field));
    const desiredByField: Record<string, string> = {};
    for (const d of labelDiffs) desiredByField[d.field] = d.desired;

    const addCap = changedFields.has('addCap')
      ? desiredByField['addCap']
      : 'EngineFlags.KEEP_CURRENT';
    const drawCap = changedFields.has('drawCap')
      ? desiredByField['drawCap']
      : 'EngineFlags.KEEP_CURRENT';
    const rpt = changedFields.has('riskPremiumThreshold')
      ? desiredByField['riskPremiumThreshold']
      : 'EngineFlags.KEEP_CURRENT';
    const active = changedFields.has('active')
      ? desiredByField['active'] === 'true'
        ? 'EngineFlags.ENABLED'
        : 'EngineFlags.DISABLED'
      : 'EngineFlags.KEEP_CURRENT';
    const halted = changedFields.has('halted')
      ? desiredByField['halted'] === 'true'
        ? 'EngineFlags.ENABLED'
        : 'EngineFlags.DISABLED'
      : 'EngineFlags.KEEP_CURRENT';

    lines.push(`    updates[${i}] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: IHubConfigurator(Infra.HUB_CONFIGURATOR),
      hub: ${hubRef(hubKey)},
      underlying: ${tokenRef(assetKey)},
      spoke: ${spokeRef(spokeKey)},
      addCap: ${addCap},
      drawCap: ${drawCap},
      riskPremiumThreshold: ${rpt},
      active: ${active},
      halted: ${halted}
    });`);
  }

  lines.push(`    return updates;`);
  lines.push(`  }`);
  return lines.join('\n');
}

function genSpokeLiquidationConfigUpdates(diffs: Diff[]): string | null {
  const grouped: Record<string, Diff[]> = {};
  for (const d of diffs) (grouped[d.label] ||= []).push(d);
  const labels = Object.keys(grouped);
  if (labels.length === 0) return null;

  const lines: string[] = [];
  lines.push(
    `  function spokeLiquidationConfigUpdates() public pure override returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory updates) {`,
  );
  lines.push(`    updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](${labels.length});`);

  for (let i = 0; i < labels.length; i++) {
    const spokeKey = labels[i];
    const labelDiffs = grouped[spokeKey];
    const changedFields = new Set(labelDiffs.map((d) => d.field));
    const desiredByField: Record<string, string> = {};
    for (const d of labelDiffs) desiredByField[d.field] = d.desired;

    const thf = changedFields.has('targetHealthFactor')
      ? desiredByField['targetHealthFactor']
      : 'EngineFlags.KEEP_CURRENT';
    const hfmb = changedFields.has('healthFactorForMaxBonus')
      ? desiredByField['healthFactorForMaxBonus']
      : 'EngineFlags.KEEP_CURRENT';
    const lbf = changedFields.has('liquidationBonusFactor')
      ? desiredByField['liquidationBonusFactor']
      : 'EngineFlags.KEEP_CURRENT';

    lines.push(`    updates[${i}] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(Infra.SPOKE_CONFIGURATOR),
      spoke: ${spokeRef(spokeKey)},
      targetHealthFactor: ${thf},
      healthFactorForMaxBonus: ${hfmb},
      liquidationBonusFactor: ${lbf}
    });`);
  }

  lines.push(`    return updates;`);
  lines.push(`  }`);
  return lines.join('\n');
}

function genSpokeReserveConfigUpdates(diffs: Diff[]): string | null {
  const grouped: Record<string, Diff[]> = {};
  for (const d of diffs) (grouped[d.label] ||= []).push(d);
  const labels = Object.keys(grouped);
  if (labels.length === 0) return null;

  const lines: string[] = [];
  lines.push(
    `  function spokeReserveConfigUpdates() public pure override returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory updates) {`,
  );
  lines.push(`    updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](${labels.length});`);

  for (let i = 0; i < labels.length; i++) {
    const label = labels[i];
    const labelDiffs = grouped[label];
    const [spokeKey, hubKey, assetKey] = label.split(' / ');

    const changedFields = new Set(labelDiffs.map((d) => d.field));
    const desiredByField: Record<string, string> = {};
    for (const d of labelDiffs) desiredByField[d.field] = d.desired;

    const priceSource = changedFields.has('priceSource')
      ? desiredByField['priceSource']
      : 'EngineFlags.KEEP_CURRENT_ADDRESS';
    const collateralRisk = changedFields.has('collateralRisk')
      ? desiredByField['collateralRisk']
      : 'EngineFlags.KEEP_CURRENT';
    const paused = changedFields.has('paused')
      ? desiredByField['paused'] === 'true'
        ? 'EngineFlags.ENABLED'
        : 'EngineFlags.DISABLED'
      : 'EngineFlags.KEEP_CURRENT';
    const frozen = changedFields.has('frozen')
      ? desiredByField['frozen'] === 'true'
        ? 'EngineFlags.ENABLED'
        : 'EngineFlags.DISABLED'
      : 'EngineFlags.KEEP_CURRENT';
    const borrowable = changedFields.has('borrowable')
      ? desiredByField['borrowable'] === 'true'
        ? 'EngineFlags.ENABLED'
        : 'EngineFlags.DISABLED'
      : 'EngineFlags.KEEP_CURRENT';
    const receiveSharesEnabled = changedFields.has('receiveSharesEnabled')
      ? desiredByField['receiveSharesEnabled'] === 'true'
        ? 'EngineFlags.ENABLED'
        : 'EngineFlags.DISABLED'
      : 'EngineFlags.KEEP_CURRENT';

    lines.push(`    updates[${i}] = IAaveV4ConfigEngine.ReserveConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(Infra.SPOKE_CONFIGURATOR),
      spoke: ${spokeRef(spokeKey)},
      hub: ${hubRef(hubKey)},
      underlying: ${tokenRef(assetKey)},
      priceSource: ${priceSource},
      collateralRisk: ${collateralRisk},
      paused: ${paused},
      frozen: ${frozen},
      borrowable: ${borrowable},
      receiveSharesEnabled: ${receiveSharesEnabled}
    });`);
  }

  lines.push(`    return updates;`);
  lines.push(`  }`);
  return lines.join('\n');
}

function genSpokeDynamicReserveConfigUpdates(
  diffs: Diff[],
  reserveContext: Map<string, {dynamicConfigKey: number; reserveId: bigint}>,
): string | null {
  const grouped: Record<string, Diff[]> = {};
  for (const d of diffs) (grouped[d.label] ||= []).push(d);
  const labels = Object.keys(grouped);
  if (labels.length === 0) return null;

  const lines: string[] = [];
  lines.push(
    `  function spokeDynamicReserveConfigUpdates() public pure override returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory updates) {`,
  );
  lines.push(
    `    updates = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](${labels.length});`,
  );

  for (let i = 0; i < labels.length; i++) {
    const label = labels[i];
    const labelDiffs = grouped[label];
    const [spokeKey, hubKey, assetKey] = label.split(' / ');
    const ctx = reserveContext.get(label);
    if (!ctx) throw new Error(`Missing reserve context for ${label} — should not happen`);
    const dynKey = ctx.dynamicConfigKey;

    const changedFields = new Set(labelDiffs.map((d) => d.field));
    const desiredByField: Record<string, string> = {};
    for (const d of labelDiffs) desiredByField[d.field] = d.desired;

    const collateralFactor = changedFields.has('collateralFactor')
      ? desiredByField['collateralFactor']
      : 'EngineFlags.KEEP_CURRENT';
    const maxLiquidationBonus = changedFields.has('maxLiquidationBonus')
      ? desiredByField['maxLiquidationBonus']
      : 'EngineFlags.KEEP_CURRENT';
    const liquidationFee = changedFields.has('liquidationFee')
      ? desiredByField['liquidationFee']
      : 'EngineFlags.KEEP_CURRENT';

    lines.push(`    updates[${i}] = IAaveV4ConfigEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(Infra.SPOKE_CONFIGURATOR),
      spoke: ${spokeRef(spokeKey)},
      hub: ${hubRef(hubKey)},
      underlying: ${tokenRef(assetKey)},
      dynamicConfigKey: ${dynKey},
      collateralFactor: ${collateralFactor},
      maxLiquidationBonus: ${maxLiquidationBonus},
      liquidationFee: ${liquidationFee}
    });`);
  }

  lines.push(`    return updates;`);
  lines.push(`  }`);
  return lines.join('\n');
}

// ── Assemble Solidity ────────────────────────────────────────────────────────

const SOLIDITY_IMPORTS = `// SPDX-License-Identifier: UNLICENSED
// AUTOGENERATED by generateDiffPayload.ts — DO NOT EDIT
pragma solidity ^0.8.0;

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

import {Hubs, Spokes, Tokens, IrStrategies, Infra} from '${paths.contractsImport}';`;

function wrapContract(functionBodies: string[]) {
  const body = functionBodies.join('\n\n');
  return `${SOLIDITY_IMPORTS}

contract DiffPayload is AaveV4Payload {
  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}

${body}
}
`;
}

async function writeFormatted(outPath: string, source: string) {
  const options = await prettier.resolveConfig(outPath);
  const formatted = await prettier.format(source, {
    ...options,
    filepath: outPath,
  });
  fs.writeFileSync(outPath, formatted);
  console.log(`\nGenerated ${path.relative(process.cwd(), outPath)}`);
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\n=== Config Diff: ${market} ===`);

  // Phase A
  console.log('\nReading hub asset configs...');
  const onChainAssets = await readHubAssets();
  const assetDiffResult = diffAssets(onChainAssets);

  // Phase B
  console.log('Reading spoke registrations...');
  const onChainSpokeRegs = await readSpokeRegistrations();
  const spokeRegDiffResult = diffSpokeRegistrations(onChainSpokeRegs);

  // Phase C
  console.log('Reading spoke liquidation configs...');
  const onChainLiqConfigs = await readLiquidationConfigs();
  const liqDiffs = diffLiquidationConfigs(onChainLiqConfigs);

  // Phase D
  console.log('Reading spoke reserves...');
  const onChainReserves = await readReserves();
  const reserveDiffResult = diffReserves(onChainReserves);

  // Print diffs
  printDiffSection('Asset Config Changes', assetDiffResult.diffs);
  printDiffSection('Spoke Registration Changes', spokeRegDiffResult.diffs);
  printDiffSection('Spoke Liquidation Config Changes', liqDiffs);
  printDiffSection('Reserve Config Changes', reserveDiffResult.reserveConfigDiffs);
  printDiffSection('Dynamic Reserve Config Changes', reserveDiffResult.dynamicConfigDiffs);

  const allNewItems = [
    ...assetDiffResult.newItems,
    ...spokeRegDiffResult.newItems,
    ...reserveDiffResult.newItems,
  ];
  printNewItems(allNewItems);

  const totalDiffs =
    assetDiffResult.diffs.length +
    spokeRegDiffResult.diffs.length +
    liqDiffs.length +
    reserveDiffResult.reserveConfigDiffs.length +
    reserveDiffResult.dynamicConfigDiffs.length;

  console.log(`\n=== Summary: ${totalDiffs} field changes, ${allNewItems.length} new items ===`);

  if (totalDiffs === 0) {
    console.log('No differences found. Skipping payload generation.');
    process.exit(0);
  }

  // Generate Solidity
  const functions: string[] = [];

  const hubAssetFn = genHubAssetConfigUpdates(assetDiffResult.diffs);
  if (hubAssetFn) functions.push(hubAssetFn);

  const hubSpokeFn = genHubSpokeConfigUpdates(spokeRegDiffResult.diffs);
  if (hubSpokeFn) functions.push(hubSpokeFn);

  const liqFn = genSpokeLiquidationConfigUpdates(liqDiffs);
  if (liqFn) functions.push(liqFn);

  const reserveFn = genSpokeReserveConfigUpdates(reserveDiffResult.reserveConfigDiffs);
  if (reserveFn) functions.push(reserveFn);

  const dynFn = genSpokeDynamicReserveConfigUpdates(
    reserveDiffResult.dynamicConfigDiffs,
    reserveDiffResult.reserveContext,
  );
  if (dynFn) functions.push(dynFn);

  const solidity = wrapContract(functions);
  await writeFormatted(path.join(paths.payloads, 'DiffPayload.sol'), solidity);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
