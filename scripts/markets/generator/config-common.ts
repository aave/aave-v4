// Shared constants and helpers for config generators.

import {z} from 'zod';

export interface IrProfile {
  optimalUsageRatio: number;
  baseDrawnRate: number;
  rateGrowthBeforeOptimal: number;
  rateGrowthAfterOptimal: number;
}

export const ZERO = '0x0000000000000000000000000000000000000000';

export const TOKEN_REGISTRY: Record<string, {address: string; priceFeed: string}> = {
  WETH: {
    address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // name: "Wrapped Ether", symbol: "WETH"
    priceFeed: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419', // "ETH / USD", latestAnswer: 213475000000
  },
  WBTC: {
    address: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599', // name: "Wrapped BTC", symbol: "WBTC"
    priceFeed: '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c', // "BTC / USD", latestAnswer: 7016528830938
  },
  cbBTC: {
    address: '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf', // name: "Coinbase Wrapped BTC", symbol: "cbBTC"
    priceFeed: '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c', // "BTC / USD", latestAnswer: 7047392557506 // using BTC/USD feed
  },
  wstETH: {
    address: '0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0', // name: "Wrapped liquid staked Ether 2.0", symbol: "wstETH"
    priceFeed: '0x869C9Ae2C8fbe82a8b0F768b9F791f89E083222C', // "Capped wstETH / stETH(ETH) / USD", latestAnswer: 264065694721
  },
  weETH: {
    address: '0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee', // name: "Wrapped eETH", symbol: "weETH"
    priceFeed: '0xf112af6f0a332b815fbef3ff932c057e570b62d3', // "Capped weETH / eETH(ETH) / USD", latestAnswer: 233208272231
  },
  rsETH: {
    address: '0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7', // name: "rsETH", symbol: "rsETH"
    priceFeed: '0x47f52b2e43d0386cf161e001835b03ad49889e3b', // "Capped rsETH / ETH / USD", latestAnswer: 228277416664
  },
  USDC: {
    address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // name: "USD Coin", symbol: "USDC"
    priceFeed: '0x581b8Bc9d6104F71ad6da1f483B67500968C5994', // "Capped USDC / USD", latestAnswer: 99994497
  },
  USDT: {
    address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', // name: "Tether USD", symbol: "USDT"
    priceFeed: '0x260326c220E469358846b187eE53328303Efe19C', // "Capped USDT / USD", latestAnswer: 99995746
  },
  GHO: {
    address: '0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f', // name: "Gho Token", symbol: "GHO"
    priceFeed: '0xD110cac5d8682A3b045D5524a9903E031d70FCCd', // "GHO / USD", latestAnswer: 99981837
  },
  AAVE: {
    address: '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9', // name: "Aave Token", symbol: "AAVE"
    priceFeed: '0x547a514d5e3769680Ce22B2361c10Ea13619e8a9', // "AAVE / USD", latestAnswer: 11038631328
  },
  LINK: {
    address: '0x514910771AF9Ca656af840dff83E8264EcF986CA', // name: "ChainLink Token", symbol: "LINK"
    priceFeed: '0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c', // "LINK / USD", latestAnswer: 906213889
  },
  sUSDe: {
    address: '0x9D39A5DE30e57443BfF2A8307A4256c8797A3497', // name: "Staked USDe", symbol: "sUSDe"
    priceFeed: '0x42bc86f2f08419280a99d8fbEa4672e7c30a86ec', // "Capped sUSDe / USDT / USD", latestAnswer: 122442865
  },
  PT_sUSDE_7MAY2026: {
    address: '0x3de0ff76E8b528C092d47b9DaC775931cef80F49', // name: "PT Ethena sUSDE 7MAY2026", symbol: "PT-sUSDE-7MAY2026"
    priceFeed: '0xa0dc0249c32fa79e8B9b17c735908a60b1141B40', // "PT Capped sUSDe USDT/USD linear discount 07MAY2026", latestAnswer: 99473812
  },
  USDe: {
    address: '0x4c9EDD5852cd905f086C759E8383e09bff1E68B3', // name: "USDe", symbol: "USDe"
    priceFeed: '0xC26D4a1c46d884cfF6dE9800B6aE7A8Cf48B4Ff8', // "Capped USDT / USD", latestAnswer: 99956422
  },
  LBTC: {
    address: '0x8236a87084f8B84306f72007F36F2618A5634494', // name: "Lombard Staked Bitcoin", symbol: "LBTC"
    priceFeed: '0x5C1771583dbbAE5AFEd71ACD2BfC0eA4029EBB04', // "Capped LBTC / BTC / USD", latestAnswer: 7016528830938
  },
  EURC: {
    address: '0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c', // name: "Euro Coin", symbol: "EURC"
    priceFeed: '0xa6aB031A4d189B24628EC9Eb155F0a0f1A0E55a3', // "Capped EURC / USD", latestAnswer: 115630690
  },
  XAUt: {
    address: '0x68749665FF8D2d112Fa859AA293F07A622782F38', // name: "Tether Gold", symbol: "XAUt"
    priceFeed: '0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6', // "XAU / USD", latestAnswer: 457825000000
  },
  USDG: {
    address: '0xe343167631d89B6Ffc58B88d6b7fB0228795491D', // name: "Global Dollar", symbol: "USDG"
    priceFeed: '0xF29b1e3b68Fd59DD0a413811fD5d0AbaE653216d', // "FixedPriceAdapter", latestAnswer: 100000000
  },
  RLUSD: {
    address: '0x8292Bb45bf1Ee4d140127049757c2E0fF06317eD', // name: "RLUSD", symbol: "RLUSD"
    priceFeed: '0xf0eaC18E908B34770FDEe46d069c846bDa866759', // "Capped RLUSD / USD", latestAnswer: 100005582
  },
  frxUSD: {
    address: '0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29', // name: "Frax USD", symbol: "frxUSD"
    priceFeed: '0x25ded2f9ae6ae9416693ab63abe3ab25493861fd', // "Capped frxUSD / USD", latestAnswer: 99988313
  },
  PT_USDE_7MAY2026: {
    address: '0xAeBf0Bb9f57E89260d57f31AF34eB58657d96Ce0', // name: "PT Ethena USDe 7MAY2026", symbol: "PT-USDe-7MAY2026"
    priceFeed: '0x0a72df02CE3E4185b6CEDf561f0AE651E9BeE235', // "PT Capped USDe USDT/USD linear discount 07MAY2026", latestAnswer: 99482901
  },
};

/**
 * Convert a decimal string to a WAD (1e18) string using pure string/BigInt arithmetic.
 * Maximum 6 decimal places — throws if more precision is specified.
 *
 * Pass String(excelCell) from the caller; never convert to Number first,
 * as float arithmetic can silently introduce precision errors.
 *
 * "1.05"    → "1050000000000000000"
 * "1.23200" → "1232000000000000000"  (trailing zeros retained correctly)
 * "1.1"     → "1100000000000000000"  (no float precision loss)
 */
export function toWadString(decimal: string): string {
  const s = String(decimal).trim();
  const dotIndex = s.indexOf('.');
  const intPart = dotIndex === -1 ? s : s.slice(0, dotIndex);
  const fracPart = dotIndex === -1 ? '' : s.slice(dotIndex + 1);

  if (fracPart.length > 6) {
    throw new Error(
      `toWadString: "${decimal}" has ${fracPart.length} decimal places; maximum allowed is 6`,
    );
  }
  if (!/^\d*$/.test(intPart) || (fracPart && !/^\d+$/.test(fracPart))) {
    throw new Error(`toWadString: "${decimal}" is not a valid non-negative decimal`);
  }

  // Pad fracPart to 18 digits, concatenate with intPart, convert once to BigInt.
  // Result = intPart × 10^18 + fracPart × 10^(18 − fracPart.length) = value in WAD.
  return BigInt((intPart || '0') + fracPart.padEnd(18, '0')).toString();
}

export function safeMaxLiquidationBonus(desired: number, collateralFactor: number): number {
  if (collateralFactor === 0) return desired;
  // percentMulUp(mlb, cf) < 10000  ⟺  mlb * cf ≤ 99990000
  const maxSafe = Math.floor(99990000 / collateralFactor);
  return Math.min(desired, maxSafe);
}

// ── On-chain constants ───────────────────────────────────────────────────────
export const UINT40_MAX = 1099511627775; // type(uint40).max — spoke caps
export const UINT24_MAX = 16777215; // type(uint24).max — riskPremiumThreshold, collateralRisk
export const UINT16_MAX = 65535; // type(uint16).max — maxUserReservesLimit
export const WAD = BigInt('1000000000000000000'); // 1e18
export const PERCENTAGE_FACTOR = 10000;
export const MIN_OPTIMAL_RATIO = 100; // AssetInterestRateStrategy.MIN_OPTIMAL_RATIO
export const MAX_OPTIMAL_RATIO = 9900; // AssetInterestRateStrategy.MAX_OPTIMAL_RATIO
export const MAX_ALLOWED_DRAWN_RATE = 100000; // AssetInterestRateStrategy.MAX_ALLOWED_DRAWN_RATE

// ── Zod Schemas ──────────────────────────────────────────────────────────────

const LiquidationConfigSchema = z
  .object({
    targetHealthFactor: z.string().optional(),
    healthFactorForMaxBonus: z.string().optional(),
    liquidationBonusFactor: z.number().int().optional(),
  })
  .strict();

const TokenSchema = z
  .object({
    address: z.string(),
    priceFeed: z.string(),
  })
  .strict();

const HubSchema = z
  .object({
    key: z.string(),
  })
  .strict();

const SpokeSchema = z
  .object({
    key: z.string(),
    registerOnPositionManagers: z.boolean().optional(),
    oracleDecimals: z.number().int().optional(),
    maxUserReservesLimit: z.number().int().optional(),
    liquidationConfig: LiquidationConfigSchema.optional(),
  })
  .strict();

const IrDataSchema = z
  .object({
    optimalUsageRatio: z.number().int(),
    baseDrawnRate: z.number().int(),
    rateGrowthBeforeOptimal: z.number().int(),
    rateGrowthAfterOptimal: z.number().int(),
  })
  .strict();

const TokenizeSchema = z
  .object({
    enabled: z.boolean().optional(),
    name: z.string().optional(),
    symbol: z.string().optional(),
    addCap: z.number().int().optional(),
    drawCap: z.number().int().optional(),
  })
  .strict();

const AssetSchema = z
  .object({
    tokenKey: z.string(),
    hubKey: z.string(),
    liquidityFee: z.number().int().optional(),
    irData: IrDataSchema.optional(),
    tokenize: TokenizeSchema.optional(),
  })
  .strict();

const SpokeRegistrationSchema = z
  .object({
    assetKey: z.string(),
    hubKey: z.string(),
    spokeKey: z.string(),
    addCap: z.number().int(),
    drawCap: z.number().int(),
    riskPremiumThreshold: z.number().int().optional(),
    active: z.boolean().optional(),
    halted: z.boolean().optional(),
  })
  .strict();

const ReserveSchema = z
  .object({
    spokeKey: z.string(),
    hubKey: z.string(),
    assetKey: z.string(),
    borrowable: z.boolean(),
    collateralFactor: z.number().int(),
    maxLiquidationBonus: z.number().int().optional(),
    liquidationFee: z.number().int().optional(),
    collateralRisk: z.number().int(),
    receiveSharesEnabled: z.boolean().optional(),
    frozen: z.boolean().optional(),
    paused: z.boolean().optional(),
  })
  .strict();

const PeripherySchema = z
  .object({
    nativeTokenKey: z.string(),
    deploySignatureGateway: z.boolean().optional(),
    deployNativeTokenGateway: z.boolean().optional(),
    deployGiverPositionManager: z.boolean().optional(),
    deployTakerPositionManager: z.boolean().optional(),
    deployConfigPositionManager: z.boolean().optional(),
  })
  .strict();

const DefaultsSchema = z
  .object({
    spoke: z
      .object({
        oracleDecimals: z.number().int().optional(),
        maxUserReservesLimit: z.number().int().optional(),
        liquidationConfig: LiquidationConfigSchema.optional(),
      })
      .strict()
      .optional(),
    spokeRegistration: z
      .object({
        riskPremiumThreshold: z.number().int().optional(),
        active: z.boolean().optional(),
        halted: z.boolean().optional(),
      })
      .strict()
      .optional(),
    reserve: z
      .object({
        receiveSharesEnabled: z.boolean().optional(),
        frozen: z.boolean().optional(),
        paused: z.boolean().optional(),
        liquidationFee: z.number().int().optional(),
        maxLiquidationBonus: z.number().int().optional(),
      })
      .strict()
      .optional(),
    asset: z
      .object({
        liquidityFee: z.number().int().optional(),
      })
      .strict()
      .optional(),
    tokenize: z
      .object({
        enabled: z.boolean().optional(),
        addCap: z.number().int().optional(),
        drawCap: z.number().int().optional(),
      })
      .strict()
      .optional(),
  })
  .strict();

export const ConfigSchema = z
  .object({
    defaults: DefaultsSchema.optional(),
    tokens: z.record(z.string(), TokenSchema),
    hubs: z.array(HubSchema),
    spokes: z.array(SpokeSchema),
    assets: z.array(AssetSchema),
    spokeRegistrations: z.array(SpokeRegistrationSchema),
    reserves: z.array(ReserveSchema),
    periphery: PeripherySchema.optional(),
  })
  .strict();

export type DeployConfig = z.infer<typeof ConfigSchema>;
