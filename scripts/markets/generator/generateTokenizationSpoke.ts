import fs from 'fs';
import path from 'path';
import {getAddress} from 'viem';
import prettier from 'prettier';
import {marketPaths} from './markets.ts';

const paths = marketPaths(process.argv[2]);
const config = JSON.parse(fs.readFileSync(path.join(paths.config, 'config.json'), 'utf8'));

// --- Helpers ---

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

// --- Filter tokenizable assets ---

const tokenizableAssets = config.assets.filter(
  (a: any) => a.tokenize && a.tokenize.name && a.tokenize.symbol,
);

// Group by hubKey preserving order
function groupByHub(assets: any[]) {
  const groups: {hubKey: string; assets: any[]}[] = [];
  const groupMap: Record<string, any[]> = {};
  for (const a of assets) {
    if (!groupMap[a.hubKey]) {
      groupMap[a.hubKey] = [];
      groups.push({hubKey: a.hubKey, assets: groupMap[a.hubKey]});
    }
    groupMap[a.hubKey].push(a);
  }
  return groups;
}

// --- Generate TokenizationSpokeDeploy.s.sol ---

function genTokenizationDeploy() {
  const hubGroups = groupByHub(tokenizableAssets);

  const lines: string[] = [];
  lines.push(`  function run() public {`);
  lines.push(`    vm.startBroadcast();`);
  lines.push(`    Factory factory = new Factory();`);
  lines.push(`    (, address caller, ) = vm.readCallers();`);
  lines.push(`    address proxy;`);

  const hubJsonVars: {hubKey: string; varName: string}[] = [];

  for (const group of hubGroups) {
    const {hubKey, assets} = group;
    lines.push(``);
    lines.push(`    // --- ${hubKey} ---`);

    for (let i = 0; i < assets.length; i++) {
      const a = assets[i];
      const isLast = i === assets.length - 1;

      lines.push(`    proxy = factory.create(`);
      lines.push(`      ${hubRef(a.hubKey)},`);
      lines.push(`      ${tokenRef(a.tokenKey)},`);
      lines.push(`      "${a.tokenize.name}",`);
      lines.push(`      "${a.tokenize.symbol}",`);
      lines.push(`      caller`);
      lines.push(`    );`);

      if (isLast) {
        const varName = `${hubKey.toLowerCase()}Json`;
        hubJsonVars.push({hubKey, varName});
        lines.push(
          `    string memory ${varName} = vm.serializeAddress("${hubKey}", "${sanitizeKey(a.tokenKey)}", proxy);`,
        );
      } else {
        lines.push(`    vm.serializeAddress("${hubKey}", "${sanitizeKey(a.tokenKey)}", proxy);`);
      }
    }
  }

  lines.push(``);
  lines.push(`    vm.stopBroadcast();`);
  lines.push(``);

  // Nest hub objects into root
  for (let i = 0; i < hubJsonVars.length; i++) {
    const {hubKey, varName} = hubJsonVars[i];
    const isLast = i === hubJsonVars.length - 1;
    if (isLast) {
      lines.push(
        `    string memory finalJson = vm.serializeString("root", "${hubKey}", ${varName});`,
      );
    } else {
      lines.push(`    vm.serializeString("root", "${hubKey}", ${varName});`);
    }
  }

  lines.push(`    vm.writeJson(finalJson, "${paths.configRel}/tokenization-deploy.json");`);
  lines.push(`  }`);
  return lines.join('\n');
}

// --- Generate TokenizationSpokePayload.sol ---

function genTokenizationPayload() {
  const deployPath = path.join(paths.config, 'tokenization-deploy.json');
  if (!fs.existsSync(deployPath)) {
    console.error(
      `Error: ${paths.configRel}/tokenization-deploy.json not found. Run the deploy script first.`,
    );
    process.exit(1);
  }
  const deployAddresses = JSON.parse(fs.readFileSync(deployPath, 'utf8'));

  const n = tokenizableAssets.length;
  const lines: string[] = [];
  lines.push(
    `  function hubSpokeToAssetsAdditions() public pure override returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory additions) {`,
  );
  lines.push(`    additions = new IAaveV4ConfigEngine.SpokeToAssetsAddition[](${n});`);

  for (let i = 0; i < n; i++) {
    const a = tokenizableAssets[i];
    const hubAddresses = deployAddresses[a.hubKey];
    if (!hubAddresses || !hubAddresses[a.tokenKey]) {
      console.error(
        `Error: Missing deployed address for ${a.hubKey}.${a.tokenKey} in tokenization-deploy.json`,
      );
      process.exit(1);
    }
    const deployedAddr = getAddress(hubAddresses[a.tokenKey]);
    const addCap = a.tokenize.addCap || 0;

    lines.push(`    {`);
    lines.push(
      `      IAaveV4ConfigEngine.SpokeAssetConfig[] memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](1);`,
    );
    lines.push(`      assets[0] = IAaveV4ConfigEngine.SpokeAssetConfig({
        underlying: ${tokenRef(a.tokenKey)},
        config: IHub.SpokeConfig({
          addCap: ${addCap},
          drawCap: 0,
          riskPremiumThreshold: 0,
          active: true,
          halted: false
        })
      });`);
    lines.push(`      additions[${i}] = IAaveV4ConfigEngine.SpokeToAssetsAddition({
        hubConfigurator: IHubConfigurator(Infra.HUB_CONFIGURATOR),
        hub: ${hubRef(a.hubKey)},
        spoke: ${deployedAddr},
        assets: assets
      });`);
    lines.push(`    }`);
  }

  lines.push(`    return additions;`);
  lines.push(`  }`);
  return lines.join('\n');
}

// --- Wrappers ---

const DEPLOY_IMPORTS = `// SPDX-License-Identifier: UNLICENSED
// AUTOGENERATED - DO NOT EDIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {Hubs, Tokens} from '${paths.contractsImport}';

contract Factory {
  function create(
    address hub,
    address token,
    string memory name,
    string memory symbol,
    address proxyAdminOwner
  ) external returns (address) {
    address impl = address(new TokenizationSpokeInstance(hub, token));
    return address(new TransparentUpgradeableProxy(impl, proxyAdminOwner, abi.encodeCall(TokenizationSpokeInstance.initialize, (name, symbol))));
  }
}

`;

function wrapDeployScript(contractName: string, body: string) {
  return `${DEPLOY_IMPORTS}

contract ${contractName} is Script {
${body}
}
`;
}

const PAYLOAD_IMPORTS = `// SPDX-License-Identifier: UNLICENSED
// AUTOGENERATED - DO NOT EDIT
pragma solidity ^0.8.0;

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

import {Hubs, Tokens, Infra} from '${paths.contractsImport}';`;

function wrapPayloadContract(contractName: string, body: string) {
  return `${PAYLOAD_IMPORTS}

contract ${contractName} is AaveV4Payload {
  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}

${body}
}
`;
}

async function writeFormatted(outDir: string, filename: string, source: string) {
  const outPath = path.join(outDir, filename);
  const options = await prettier.resolveConfig(outPath);
  const formatted = await prettier.format(source, {
    ...options,
    filepath: outPath,
  });
  fs.writeFileSync(outPath, formatted);
  console.log(`Generated ${filename}`);
}

// --- Main ---

const generatePayload = process.argv.includes('--payload');

// Always generate the deploy script
await writeFormatted(
  paths.root,
  'TokenizationSpokeDeploy.s.sol',
  wrapDeployScript('TokenizationSpokeDeploy', genTokenizationDeploy()),
);

// Optionally generate the payload
if (generatePayload) {
  await writeFormatted(
    paths.payloads,
    'TokenizationSpokePayload.sol',
    wrapPayloadContract('TokenizationSpokePayload', genTokenizationPayload()),
  );
}

process.exit(0);
