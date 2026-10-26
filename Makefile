# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes
test   :; forge test -vvv

# Utilities
download :; cast etherscan-source --chain ${chain} -d src/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@npx prettier ${before} ${after} --write
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

gas-report :; forge test --mp 'tests/gas/**'

# Coverage
coverage-base :; FOUNDRY_PROFILE=coverage forge coverage --report lcov --no-match-coverage "(scripts|tests|deployments|mocks)"
coverage-clean :; lcov --rc derive_function_end_line=0 --remove ./lcov.info -o ./lcov.info.p --ignore-errors inconsistent 'src/dependencies/*'
coverage-report :; genhtml ./lcov.info.p -o report --branch-coverage --rc derive_function_end_line=0 
coverage-badge :; coverage=$$(awk -F '[<>]' '/headerCovTableEntryHi/{print $3}' ./report/index.html | sed 's/[^0-9.]//g' | head -n 1); \
	wget -O ./report/coverage.svg "https://img.shields.io/badge/coverage-$${coverage}%25-brightgreen"
coverage :
	make coverage-base
	make coverage-clean
	make coverage-report
	make coverage-badge

# Deployment
# Step 1:Pre-deploy LiquidationLogic library (required before deploying spokes)
# `make deploy-precompile`
deploy-precompile :;
	FOUNDRY_PROFILE=${chain} forge clean && forge script scripts/LibraryPreCompile.s.sol \
	--rpc-url ${chain} --account ${account} --ffi \
	$(if ${dry},, --broadcast --verify) \

# Step 2: Deploy contracts + grant roles to deployer
# `make deploy-contracts`
deploy-contracts :;
	FOUNDRY_PROFILE=${chain} forge clean && forge script scripts/deploy/AaveV4DeployBatch.s.sol:AaveV4DeployBatchScript \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast --verify) \

# Initial markets (see scripts/markets/README.md)
# `make <target> market=ethereum|avalanche|arc chain=<rpc alias> account=<keystore>`
MARKET_DIR = scripts/markets/${market}
MARKET_NAME = $(if $(filter ethereum,${market}),Ethereum,$(if $(filter arc,${market}),Arc,Avalanche))
# Arc's explorer cannot be reached by `forge --verify`, and its LiquidationLogic is at salt 0
MARKET_VERIFY = $(if $(filter arc,${market}),,--verify)
MARKET_LIBRARY_SALT = $(if $(filter arc,${market}),0,11231)
MARKET_SCRIPT = forge script ${MARKET_DIR}/AaveV4${MARKET_NAME}MarketPayloads.s.sol \
	--rpc-url ${chain} --account ${account} --slow $(if ${dry},, --broadcast)

market-config :; bun run scripts/markets/generator/$(if $(filter ethereum,${market}),chaos,llamarisk)/generate-config.ts
market-address-lib :; bun run scripts/markets/generator/generateContracts.ts ${market}
market-payloads :; bun run scripts/markets/generator/generatePayload.ts ${market}
market-tokenization :; bun run scripts/markets/generator/generateTokenizationSpoke.ts ${market}
market-tokenization-payload :; bun run scripts/markets/generator/generateTokenizationSpoke.ts ${market} --payload
market-diff :; bun run scripts/markets/generator/generateDiffPayload.ts ${market}

market-deploy-precompile :;
	forge script scripts/LibraryPreCompile.s.sol --sig 'run(bytes32)' $$(cast to-uint256 ${MARKET_LIBRARY_SALT}) \
	--rpc-url ${chain} --account ${account} --ffi $(if ${dry},, --broadcast ${MARKET_VERIFY})

market-deploy-contracts :;
	forge script ${MARKET_DIR}/AaveV4Deploy${MARKET_NAME}Market.s.sol \
	--rpc-url ${chain} --account ${account} --slow $(if ${dry},, --broadcast ${MARKET_VERIFY})

market-setup :; ${MARKET_SCRIPT} --sig 'setup()'

market-deploy-tokenization :;
	forge script ${MARKET_DIR}/TokenizationSpokeDeploy.s.sol --tc TokenizationSpokeDeploy \
	--rpc-url ${chain} --account ${account} --slow $(if ${dry},, --broadcast)

market-listings :; ${MARKET_SCRIPT} $(if ${engine},--sig 'listings(address)' ${engine},--sig 'listings()')
market-handover :; ${MARKET_SCRIPT} --sig 'handover()'

# Arc, run after market-deploy-precompile and market-deploy-contracts with market=arc
ARC_SCRIPT = forge script scripts/markets/arc/$(1).s.sol \
	--rpc-url ${chain} --account ${account} --slow $(if ${dry},, --broadcast)

arc-deploy-config-engine :; $(call ARC_SCRIPT,AaveV4DeployArcConfigEngine)
arc-configure :; $(call ARC_SCRIPT,AaveV4ConfigureArc)
arc-relinquish :; $(call ARC_SCRIPT,AaveV4RelinquishArc)
arc-verify :; forge script scripts/markets/arc/AaveV4VerifyArc.s.sol --rpc-url ${chain}

market-test :; FOUNDRY_PROFILE=markets forge test
