import path from 'path';

const MARKETS_DIR = path.resolve(__dirname, '..');

// Resolves the paths of a market folder under scripts/markets (e.g. `ethereum`, `avalanche`).
export function marketPaths(market: string | undefined) {
  if (!market) {
    console.error('Missing <market> argument (e.g. ethereum, avalanche)');
    process.exit(1);
  }
  const root = path.join(MARKETS_DIR, market);
  return {
    root,
    config: path.join(root, 'config'),
    payloads: path.join(root, 'payloads'),
    configRel: `scripts/markets/${market}/config`,
    contractsImport: `scripts/markets/${market}/AaveV4Contracts.sol`,
    rpcAlias: market === 'ethereum' ? 'mainnet' : market,
  };
}
