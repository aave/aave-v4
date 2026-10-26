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
# Step 1: Pre-deploy the LiquidationLogic and BabylonLiquidationLogic libraries (required before deploying spokes)
# `make deploy-precompile`
deploy-precompile :;
	FOUNDRY_PROFILE=${chain} forge clean && forge script scripts/LibraryPreCompile.s.sol \
	--rpc-url ${chain} --account ${account} --ffi \
	$(if ${dry},, --broadcast --verify) \
	$(if ${gas_multiplier},--gas-estimate-multiplier ${gas_multiplier}) \

# Step 2: Deploy contracts + grant roles to deployer
# `make deploy-contracts`
deploy-contracts :;
	FOUNDRY_PROFILE=${chain} forge clean && forge script scripts/deploy/AaveV4DeployBatch.s.sol:AaveV4DeployBatchScript \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast --verify) \

# Babylon market. Run in order; see scripts/markets/babylon/README.md for what goes between the steps.
# `make babylon-deploy chain=sepolia config=sepolia account=<keystore-name>`, `config` names `scripts/markets/babylon/config/<config>.json`.
# Add `dry=true` to simulate and `gas_multiplier=<percent>` to scale gas estimates
babylon-precompile :;
	FOUNDRY_PROFILE=${chain} forge clean && BABYLON_CONFIG=${config} forge script scripts/markets/babylon/AaveV4BabylonLibraries.s.sol:AaveV4BabylonLibraries \
	--rpc-url ${chain} --account ${account} --ffi \
	$(if ${dry},, --broadcast --verify) \
	$(if ${gas_multiplier},--gas-estimate-multiplier ${gas_multiplier}) \

babylon-deploy :;
	forge clean && BABYLON_CONFIG=${config} forge script scripts/markets/babylon/AaveV4DeployBabylon.s.sol:AaveV4DeployBabylon \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast --verify) \
	$(if ${gas_multiplier},--gas-estimate-multiplier ${gas_multiplier}) \

babylon-configure :;
	BABYLON_CONFIG=${config} forge script scripts/markets/babylon/AaveV4BabylonConfigure.s.sol:AaveV4BabylonConfigure \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast) \
	$(if ${gas_multiplier},--gas-estimate-multiplier ${gas_multiplier}) \

babylon-handover :;
	BABYLON_CONFIG=${config} forge script scripts/markets/babylon/AaveV4BabylonHandover.s.sol:AaveV4BabylonHandover \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast) \
	$(if ${gas_multiplier},--gas-estimate-multiplier ${gas_multiplier}) \

babylon-verify :; BABYLON_CONFIG=${config} forge script scripts/markets/babylon/AaveV4BabylonVerify.s.sol:AaveV4BabylonVerify --rpc-url ${chain}
