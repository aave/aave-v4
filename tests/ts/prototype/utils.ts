import {User, Spoke, LiquidityHub} from './core.ts';

export const DEBUG = true;

export enum Rounding {
  FLOOR,
  CEIL,
  BANKER,
}

export const RAY = 10n ** 27n;
export const WAD = 10n ** 18n;
export const PERCENTAGE_FACTOR = 100_00n;
export const MAX_UINT = 2n ** 256n - 1n;

export const MIN_RP = 0n;
export const MAX_RP = 1000_00n;
export const MIN_INDEX = parseRay(1.01); // 1% interest
export const MAX_INDEX = parseRay(1.99); // 99% interest

export const PRECISION = 3n; // max abs delta allowed

export function logBaseAndPremiumDebt(who: User | Spoke | LiquidityHub) {
  const hub = who instanceof LiquidityHub ? who : who.hub;
  console.log(
    'debt: base %d + premium %d (ghost %d, offset %d, unrealised %d) = %d',
    f(who.getDebt().baseDebt),
    f(who.getDebt().premiumDebt),
    f(hub.toDrawnAssets(who.ghostDrawnShares)), // getters round down by 4626 convention, repay amount should round up
    f(who.offset),
    f(who.unrealisedPremium),
    f(who.getTotalDebt())
  );
}

export function assertNonZero(a: bigint) {
  if (a === 0n) throw new Error('got zero');
}

export function random(min: bigint, max: bigint) {
  return BigInt(Math.floor(Math.random() * Number(max - min))) + min;
}

export function randomRiskPremium() {
  return random(MIN_RP, MAX_RP);
}

export function randomIndex() {
  return random(MIN_INDEX, MAX_INDEX);
}

export function randomChance(chance: number) {
  if (chance < 0 || chance > 1) throw new Error('chance must be between 0 and 1');
  return Math.random() < chance;
}

export function randomAmount() {
  if (randomChance(0.15)) return random(1n, 10n);
  const whole = random(0n, 10n ** random(0n, 10n));
  const index = random(0n, 18n);
  const paddedFractional = random(1n, 10n ** index)
    .toString()
    .padEnd(Number(index), '0');
  return BigInt(whole) * 10n ** index + BigInt(paddedFractional.slice(0, Number(index)));
}

export function max(a: bigint, b: bigint, c: bigint) {
  return a > b ? (a > c ? a : c) : b > c ? b : c;
}

export function absDiff(a: bigint, b: bigint) {
  return a > b ? a - b : b - a;
}

export function maxAbsDiff(a: bigint, b: bigint, c: bigint) {
  return max(absDiff(a, b), absDiff(b, c), absDiff(a, c));
}

export function inverse(rounding: Rounding) {
  if (rounding === Rounding.FLOOR) return Rounding.CEIL;
  if (rounding === Rounding.CEIL) return Rounding.FLOOR;
  throw new Error('cannot inverse rounding');
}

export function parseEther(ether: string | bigint | number) {
  return parseUnits(ether, 18);
}

export function parseRay(ray: string | bigint | number) {
  return parseUnits(ray, 27);
}

export function formatEther(wei: bigint) {
  return formatUnits(wei, 18);
}

export function formatRay(ray: bigint) {
  return formatUnits(ray, 27);
}

export function formatBps(bps: bigint) {
  return formatUnits(bps, 2);
}

export function f(wei: bigint) {
  return formatEther(wei);
}

export function p(ether: string | bigint | number) {
  return parseEther(ether);
}

export function percentMul(a: bigint, b: bigint, rounding = Rounding.FLOOR) {
  return mulDiv(a, b, PERCENTAGE_FACTOR, rounding);
}

export function rayMul(a: bigint, b: bigint, rounding = Rounding.FLOOR) {
  return mulDiv(a, b, RAY, rounding);
}

export function formatUnits(wei: bigint, index = 18): string {
  const UNITS = 10n ** BigInt(index);
  const whole = wei / UNITS;
  const fractional = (wei % UNITS).toString().padStart(index, '0');
  return `${whole}.${fractional}`.replace(/\.?0+$/, '');
}

export function parseUnits(units: string | bigint | number, index = 18): bigint {
  if (typeof units === 'bigint' || typeof units === 'number') units = units.toString();
  const [whole, fractional = ''] = units.split('.');
  const paddedFractional = fractional.padEnd(index, '0');
  return BigInt(whole) * 10n ** BigInt(index) + BigInt(paddedFractional.slice(0, index));
}

// @dev Calculates (a * b) / c, with specified rounding direction
export function mulDiv(a: bigint, b: bigint, c: bigint, rounding: Rounding) {
  const prod = a * b;
  const quotient = prod / c;
  const remainder = prod % c;

  switch (rounding) {
    case Rounding.CEIL:
      return quotient + (remainder !== 0n ? 1n : 0n);

    case Rounding.BANKER: {
      const doubleRemainder = remainder * 2n;
      if (doubleRemainder < c) {
        return quotient;
      } else if (doubleRemainder > c) {
        return quotient + 1n;
      } else {
        return quotient + (quotient % 2n !== 0n ? 1n : 0n);
      }
    }

    case Rounding.FLOOR:
    default:
      return quotient;
  }
}

export function info(...args: any[]) {
  if (DEBUG) console.info(...args);
}
