// On-chain verification of the Avalanche token registry against Avalanche mainnet.
//
// Asserts, for every entry in AVALANCHE_TOKEN_REGISTRY:
//   - registry address / priceFeed match the Aave V3 Avalanche address book
//   - token   name() / symbol()      equal the expected values
//   - feed    description()          equals the expected value
//   - feed    latestAnswer()         is positive (live price, not asserted exactly)
//
// Requires an Avalanche RPC in RPC_AVALANCHE.
// Run: bun test scripts/markets/generator/llamarisk/tokens.spec.ts

import {describe, it, expect} from 'bun:test';
import {createPublicClient, http, getAddress, type Address} from 'viem';
import {AVALANCHE_TOKEN_REGISTRY} from './tokens.ts';

const client = createPublicClient({transport: http(process.env.RPC_AVALANCHE)});
const TIMEOUT = 30_000;

const erc20Abi = [
  {
    type: 'function',
    name: 'name',
    stateMutability: 'view',
    inputs: [],
    outputs: [{type: 'string'}],
  },
  {
    type: 'function',
    name: 'symbol',
    stateMutability: 'view',
    inputs: [],
    outputs: [{type: 'string'}],
  },
] as const;

const feedAbi = [
  {
    type: 'function',
    name: 'description',
    stateMutability: 'view',
    inputs: [],
    outputs: [{type: 'string'}],
  },
  {
    type: 'function',
    name: 'latestAnswer',
    stateMutability: 'view',
    inputs: [],
    outputs: [{type: 'int256'}],
  },
] as const;

// Expected values: addresses/oracles from aave-address-book AaveV3Avalanche.sol,
// name/symbol/description verified live on the fork.
interface Expected {
  address: string;
  name: string;
  symbol: string;
  oracle: string;
  description: string;
}

const EXPECTED: Record<string, Expected> = {
  WAVAX: {
    address: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    name: 'Wrapped AVAX',
    symbol: 'WAVAX',
    oracle: '0x0A77230d17318075983913bC2145DB16C7366156',
    description: 'AVAX / USD',
  },
  BTCb: {
    address: '0x152b9d0FdC40C096757F570A51E494bd4b943E50',
    name: 'Bitcoin',
    symbol: 'BTC.b',
    oracle: '0x2779D32d5166BAaa2B2b658333bA7e6Ec0C65743',
    description: 'BTC / USD',
  },
  USDC: {
    address: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
    name: 'USD Coin',
    symbol: 'USDC',
    oracle: '0xb0D7A8bbDcdb1203850b742bB4d7f57a1F1C8483',
    description: 'Capped USDC/USD',
  },
  USDT: {
    address: '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7',
    name: 'TetherToken',
    symbol: 'USDt',
    oracle: '0x5b7810a910B4a878AaA4800a824E5E5796838009',
    description: 'Capped USDt/USD',
  },
  WETHe: {
    address: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
    name: 'Wrapped Ether',
    symbol: 'WETH.e',
    oracle: '0x976B3D034E162d8bD72D6b9C989d545b839003b0',
    description: 'ETH / USD',
  },
  EURC: {
    address: '0xC891EB4cbdEFf6e073e859e987815Ed1505c2ACD',
    name: 'Euro Coin',
    symbol: 'EURC',
    oracle: '0x3368310bC4AeE5D96486A73bae8E6b49FcDE62D3',
    description: 'EURC / USD',
  },
  sAVAX: {
    address: '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE',
    name: 'Staked AVAX',
    symbol: 'sAVAX',
    oracle: '0xB2B332f27e4B7305649a228C31Ed9858c5a6bAD9',
    description: 'Capped sAVAX / AVAX / USD',
  },
};

describe('Avalanche token registry', () => {
  it('registry keys match the expected set', () => {
    expect(Object.keys(AVALANCHE_TOKEN_REGISTRY).sort()).toEqual(Object.keys(EXPECTED).sort());
  });

  for (const [key, exp] of Object.entries(EXPECTED)) {
    it(
      `${key}: token address + on-chain name()/symbol()`,
      async () => {
        const entry = AVALANCHE_TOKEN_REGISTRY[key];
        expect(getAddress(entry.address)).toBe(getAddress(exp.address));
        const address = getAddress(entry.address) as Address;
        const name = await client.readContract({address, abi: erc20Abi, functionName: 'name'});
        const symbol = await client.readContract({address, abi: erc20Abi, functionName: 'symbol'});
        expect(name).toBe(exp.name);
        expect(symbol).toBe(exp.symbol);
      },
      TIMEOUT,
    );

    it(
      `${key}: oracle address + on-chain description()/latestAnswer()`,
      async () => {
        const entry = AVALANCHE_TOKEN_REGISTRY[key];
        expect(getAddress(entry.priceFeed)).toBe(getAddress(exp.oracle));
        const address = getAddress(entry.priceFeed) as Address;
        const description = await client.readContract({
          address,
          abi: feedAbi,
          functionName: 'description',
        });
        const latestAnswer = (await client.readContract({
          address,
          abi: feedAbi,
          functionName: 'latestAnswer',
        })) as bigint;
        expect(description).toBe(exp.description);
        expect(latestAnswer).toBeGreaterThan(0n);
      },
      TIMEOUT,
    );
  }
});
