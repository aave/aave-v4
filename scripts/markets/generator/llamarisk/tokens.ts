// ════════════════════════════════════════════════════════════════════════════
// Avalanche token registry for the LlamaRisk config generator.
//
// Addresses + price sources are sourced 1:1 from the Aave V3 Avalanche pool
// (we deliberately reuse V3's oracles), via aave-address-book:
//   https://github.com/aave-dao/aave-address-book/blob/main/src/AaveV3Avalanche.sol
//   `address`   = AaveV3AvalancheAssets.<SYMBOL>_UNDERLYING
//   `priceFeed` = AaveV3AvalancheAssets.<SYMBOL>_ORACLE
//
// The // → comments are live return values read on the avax_dev Tenderly fork
// (chainId 456789123, state-synced with Avalanche mainnet 43114):
//   token  : name() / symbol()
//   feed   : description() / latestAnswer()   (latestAnswer is a sample reading)
// These are asserted by tokens.spec.ts.
//
// Addresses are checksummed; the generator re-runs them through viem getAddress()
// so any transcription error fails loudly at generation time.
// ════════════════════════════════════════════════════════════════════════════

export interface TokenEntry {
  address: string;
  priceFeed: string;
}

export const ZERO = '0x0000000000000000000000000000000000000000';

export const AVALANCHE_TOKEN_REGISTRY: Record<string, TokenEntry> = {
  // token: name()="Wrapped AVAX"  symbol()="WAVAX"
  // feed:  description()="AVAX / USD"  latestAnswer()=695947000 (~$6.96)
  WAVAX: {
    address: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    priceFeed: '0x0A77230d17318075983913bC2145DB16C7366156',
  },
  // token: name()="Bitcoin"  symbol()="BTC.b"
  // feed:  description()="BTC / USD"  latestAnswer()=6645702707929 (~$66,457)
  BTCb: {
    address: '0x152b9d0FdC40C096757F570A51E494bd4b943E50',
    priceFeed: '0x2779D32d5166BAaa2B2b658333bA7e6Ec0C65743',
  },
  // token: name()="USD Coin"  symbol()="USDC"
  // feed:  description()="Capped USDC/USD"  latestAnswer()=99975072 (~$1.00)
  USDC: {
    address: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
    priceFeed: '0xb0D7A8bbDcdb1203850b742bB4d7f57a1F1C8483',
  },
  // token: name()="TetherToken"  symbol()="USDt"
  // feed:  description()="Capped USDt/USD"  latestAnswer()=99949883 (~$1.00)
  USDT: {
    address: '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7',
    priceFeed: '0x5b7810a910B4a878AaA4800a824E5E5796838009',
  },
  // token: name()="Wrapped Ether"  symbol()="WETH.e"
  // feed:  description()="ETH / USD"  latestAnswer()=181722000000 (~$1,817)
  WETHe: {
    address: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
    priceFeed: '0x976B3D034E162d8bD72D6b9C989d545b839003b0',
  },
  // token: name()="Euro Coin"  symbol()="EURC"
  // feed:  description()="EURC / USD"  latestAnswer()=115914824 (~$1.16)
  EURC: {
    address: '0xC891EB4cbdEFf6e073e859e987815Ed1505c2ACD',
    priceFeed: '0x3368310bC4AeE5D96486A73bae8E6b49FcDE62D3',
  },
  // token: name()="Staked AVAX"  symbol()="sAVAX"   (collateral-only on AVAX Correlated Spoke)
  // feed:  description()="Capped sAVAX / AVAX / USD"  latestAnswer()=882096789 (~$8.82)
  sAVAX: {
    address: '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE',
    priceFeed: '0xB2B332f27e4B7305649a228C31Ed9858c5a6bAD9',
  },
};
