import {describe, it, expect} from 'bun:test';
import {toWadString} from './config-common.ts';

describe('toWadString', () => {
  // ── Correct conversions ──────────────────────────────────────────────────

  it('converts integer strings', () => {
    expect(toWadString('0')).toBe('0');
    expect(toWadString('1')).toBe('1000000000000000000');
    expect(toWadString('2')).toBe('2000000000000000000');
    expect(toWadString('100')).toBe('100000000000000000000');
    expect(toWadString('1.3075')).toBe('1307500000000000000');
  });

  it('converts health-factor-style decimals', () => {
    expect(toWadString('1.05')).toBe('1050000000000000000');
    expect(toWadString('0.99')).toBe('990000000000000000');
    expect(toWadString('1.24')).toBe('1240000000000000000');
    expect(toWadString('0.70')).toBe('700000000000000000');
  });

  it('retains precision with trailing zeros — 1.23200 must equal 1.232 exactly', () => {
    // Both must produce the same WAD value; neither must lose a digit.
    expect(toWadString('1.23200')).toBe('1232000000000000000');
    expect(toWadString('1.232')).toBe('1232000000000000000');
    expect(toWadString('1.100000')).toBe('1100000000000000000');
  });

  it('handles max precision (6 decimal places)', () => {
    expect(toWadString('1.123456')).toBe('1123456000000000000');
    expect(toWadString('0.000001')).toBe('1000000000000');
  });

  it('handles a single fractional digit', () => {
    expect(toWadString('1.5')).toBe('1500000000000000000');
    expect(toWadString('0.1')).toBe('100000000000000000');
  });

  // ── Float precision regression ───────────────────────────────────────────

  it('gives exact result for 1.1 — float multiply would give 1100000000000001000', () => {
    // 1.1 * 1e15 = 1100000000000001 in IEEE 754 — the string path must be exact.
    expect(toWadString('1.1')).toBe('1100000000000000000');
  });

  it('gives exact result for 0.3 — float representation is 0.2999...', () => {
    expect(toWadString('0.3')).toBe('300000000000000000');
  });

  it('gives exact result for 0.7 — float representation is 0.6999...', () => {
    expect(toWadString('0.7')).toBe('700000000000000000');
  });

  // ── Errors ───────────────────────────────────────────────────────────────

  it('throws when more than 6 decimal places are provided', () => {
    expect(() => toWadString('1.1111111')).toThrow('6');
    expect(() => toWadString('0.0000001')).toThrow('6');
    expect(() => toWadString('1.1234567')).toThrow('6');
  });

  it('throws on non-numeric input', () => {
    expect(() => toWadString('N/A')).toThrow();
    expect(() => toWadString('abc')).toThrow();
    expect(() => toWadString('1.2.3')).toThrow();
  });
});
