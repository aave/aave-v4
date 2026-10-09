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
# `make deploy-contracts script=AaveV4DeployBase`
deploy-contracts :;
	FOUNDRY_PROFILE=${chain} forge clean && forge script scripts/deploy/${script}.s.sol:${script} \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast --verify) \

# Step 3: Configure the market and halt every listed asset on the Hub.
# Verifies as well, because listing a tokenized asset deploys its TokenizationSpoke here.
# `make configure-market chain=base account=<keystore-name> script=AaveV4ConfigureBase`
configure-market :;
	FOUNDRY_PROFILE=${chain} forge script scripts/config/${script}.s.sol:${script} \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast --verify) \

# Step 4: Hand the market over and verify the deployer holds nothing
# `make relinquish-market chain=base account=<keystore-name> script=AaveV4RelinquishBase`
relinquish-market :;
	FOUNDRY_PROFILE=${chain} forge script scripts/config/${script}.s.sol:${script} \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast) \

# Deploys the AaveV4ConfigEngine governance payloads delegatecall into. Independent of the steps
# above: the engine is stateless and sits at a deterministic address.
# `make deploy-config-engine chain=base account=<keystore-name> script=DeployBaseConfigEngine`
deploy-config-engine :;
	FOUNDRY_PROFILE=${chain} forge script scripts/config/${script}.s.sol:${script} \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast --verify) \

# Sentora market on Ethereum, chain id 1. Every target takes the cast wallet keystore account to
# broadcast from, and `dry=true` to simulate instead: `make sentora-deploy account=<keystore-name>`.
# Run them in order; see docs/sentora-deploy.md for what goes between the steps.
sentora-account :; cast wallet address --account ${account}

sentora-deploy :; make deploy-contracts chain=mainnet account=${account} script=AaveV4DeploySentora dry=${dry}
sentora-configure :; make configure-market chain=mainnet account=${account} script=AaveV4ConfigureSentora dry=${dry}
sentora-relinquish :; make relinquish-market chain=mainnet account=${account} script=AaveV4RelinquishSentora dry=${dry}
sentora-config-engine :; make deploy-config-engine chain=mainnet account=${account} script=DeploySentoraConfigEngine dry=${dry}
