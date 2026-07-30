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

# ether.fi Cash Aave V4 launch (OP Mainnet, whitelabel - Safe-administered)
#
# The spoke links against the CANONICAL Aave LiquidationLogic (same address as Ethereum
# mainnet and Avalanche), pre-deployed on OP 2026-07-30 via
# `make etherfi-predeploy-liquidationlogic` (below; idempotent — no-ops now that code
# exists) and source-verified on OP Etherscan. The pin lives HERE, in committed tooling,
# instead of the machine-local .env the precompile script manages — every machine builds
# byte-identical spoke bytecode, which is what makes the predicted addresses reproducible.
# deploy-precompile is NOT part of the etherfi flow; etherfi-validate gates on the
# canonical library having code on OP.
ETHERFI_FOUNDRY_LIBRARIES = src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0x88dF535473C5adf1f57789734A05E555F7Deb8DB
ETHERFI_LIQUIDATION_LOGIC = 0x88dF535473C5adf1f57789734A05E555F7Deb8DB

# Step 0: pre-deploy the canonical LiquidationLogic on OP at the SAME address as Ethereum
# mainnet (Safe Singleton Factory + canonical salt; init code reproduced from this repo's
# source, so the address assertion proves byte-identical code). Broadcast from ANY funded
# account EXCEPT the launch deployer — the script enforces this so the deployer stays at
# nonce 3 for the instance deployment.
# `make etherfi-predeploy-liquidationlogic account=<keystore>` (set dry=1 to simulate)
etherfi-predeploy-liquidationlogic :;
	forge script scripts/etherfi/PredeployLiquidationLogic.s.sol:PredeployLiquidationLogicScript \
	--rpc-url optimism --account ${account} --slow \
	$(if ${dry},, --broadcast) \

# Verify the pre-deployed canonical LiquidationLogic source on OP Etherscan
# (requires ETHERSCAN_API_KEY_OPTIMISM)
# `make etherfi-verify-liquidationlogic`
etherfi-verify-liquidationlogic :;
	forge verify-contract ${ETHERFI_LIQUIDATION_LOGIC} \
	src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic --chain optimism --watch

# Deploy the instance itself (hub/spoke/etc., admins = Owner Safe).
# `make etherfi-deploy-instance account=<keystore>` (set dry=1 to simulate)
etherfi-deploy-instance :;
	FOUNDRY_LIBRARIES=${ETHERFI_FOUNDRY_LIBRARIES} \
	forge script scripts/etherfi/DeployEtherfiCashInstance.s.sol:DeployEtherfiCashInstanceScript \
	--rpc-url optimism --account ${account} --slow \
	$(if ${dry},, --broadcast --verify) \

# One-command pipeline: validate -> fork dress rehearsal (deploy + Safe-context execute + verify) -> stop
# `make etherfi-rehearse`
etherfi-rehearse :;
	./scripts/etherfi/launch.sh rehearse

# Same pipeline, then real payload deploy + Safe tx + launch spec after a confirmation prompt
# `make etherfi-launch account=<keystore>`
etherfi-launch :;
	account=${account} ./scripts/etherfi/launch.sh broadcast

# Read-only preflight of every pinned address
# `make etherfi-validate`
etherfi-validate :;
	forge script scripts/etherfi/ValidateEtherfiCashLaunch.s.sol:ValidateEtherfiCashLaunchScript --rpc-url optimism

# Read-only field-by-field check of live hub/spoke state + operator roles vs the payload spec
# `make etherfi-verify`
etherfi-verify :;
	forge script scripts/etherfi/VerifyEtherfiCashLive.s.sol:VerifyEtherfiCashLiveScript --sig 'verify()' --rpc-url optimism

# Regenerate the Owner-Safe launch transaction JSON for an already-deployed payload
# `make etherfi-safe-tx PAYLOAD=0x...`
etherfi-safe-tx :;
	forge script scripts/etherfi/GenerateEtherfiCashSafeTx.s.sol:GenerateEtherfiCashSafeTxScript --sig 'generate()' --rpc-url optimism

# Regenerate the launch spec document from the payload specs
# `make etherfi-launch-spec PAYLOAD=0x...`
etherfi-launch-spec :;
	forge script scripts/etherfi/GenerateEtherfiCashLaunchSpec.s.sol:GenerateEtherfiCashLaunchSpecScript --sig 'generate()' --rpc-url optimism

# Deploy the stateless config engine (broadcast = 4 engine libraries + engine, all deterministic)
# `make etherfi-deploy-engine account=<keystore>` (set dry=1 to simulate)
etherfi-deploy-engine :;
	forge script scripts/etherfi/DeployEtherfiCashConfigEngine.s.sol:DeployEtherfiCashConfigEngineScript \
	--rpc-url optimism --account ${account} --slow \
	$(if ${dry},, --broadcast --verify) \
