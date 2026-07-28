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
# Deploy the instance itself (hub/spoke/etc., admins = Owner Safe). Requires deploy-precompile first.
# `make etherfi-deploy-instance account=<keystore>` (set dry=1 to simulate)
etherfi-deploy-instance :;
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
