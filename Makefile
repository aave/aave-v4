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

# Echidna
echidna:
	FOUNDRY_PROFILE=invariant echidna . --contract invariants/protocol-suite/Tester.t.sol:Tester --config ./invariants/protocol-suite/_config/echidna_config.yaml
echidna-assert:
	FOUNDRY_PROFILE=invariant echidna . --contract invariants/protocol-suite/Tester.t.sol:Tester --test-mode assertion --config ./invariants/protocol-suite/_config/echidna_config.yaml
echidna-explore:
	FOUNDRY_PROFILE=invariant echidna . --contract invariants/protocol-suite/Tester.t.sol:Tester --test-mode exploration --config ./invariants/protocol-suite/_config/echidna_config.yaml

echidna-hub:
	FOUNDRY_PROFILE=invariant echidna . --contract invariants/hub-suite/Tester.t.sol:Tester --config ./invariants/hub-suite/_config/echidna_config.yaml
echidna-hub-assert:
	FOUNDRY_PROFILE=invariant echidna . --contract invariants/hub-suite/Tester.t.sol:Tester --test-mode assertion --config ./invariants/hub-suite/_config/echidna_config.yaml
echidna-hub-explore:
	FOUNDRY_PROFILE=invariant echidna . --contract invariants/hub-suite/Tester.t.sol:Tester --test-mode exploration --config ./invariants/hub-suite/_config/echidna_config.yaml

# Medusa
medusa:
	FOUNDRY_PROFILE=invariant medusa fuzz --config ./medusa.protocol.json
medusa-hub:
	FOUNDRY_PROFILE=invariant medusa fuzz --config ./medusa.hub.json

foundry-invariants:
	FOUNDRY_PROFILE=invariant forge test --mc TesterFoundry -vvv 

# Results
runes-echidna:
	runes convert ./invariants/protocol-suite/_corpus/echidna/default/_data/corpus/reproducers --output ./invariants/protocol-suite/replays
runes-medusa:
	runes convert ./invariants/protocol-suite/_corpus/medusa/ --output ./invariants/protocol-suite/replays

runes-echidna-hub:
	runes convert ./invariants/hub-suite/_corpus/echidna/default/_data/corpus/reproducers --output ./invariants/hub-suite/replays
runes-medusa-hub:
	runes convert ./invariants/hub-suite/_corpus/medusa/ --output ./invariants/hub-suite/replays
