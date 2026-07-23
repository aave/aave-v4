#!/usr/bin/env bash
# ether.fi Cash Aave V4 launch pipeline (OP Mainnet, whitelabel — Safe-administered).
#
# Usage:
#   scripts/etherfi/launch.sh rehearse                       # validate + fork dress rehearsal
#   account=<keystore> scripts/etherfi/launch.sh broadcast   # the real thing (asks for confirmation)
#
# Stages:
#   1. validate   read-only preflight of every address in EtherfiCashOpMainnet.sol
#   2. rehearse   fork test: deploy payload, execute it in the Owner Safe's context
#                 (delegatecall, real instance, real roles), verify state field by field
#   3. broadcast  (broadcast mode only) deploy + verify the payload for real, then generate
#                 the Owner-Safe transaction JSON and the launch spec document
#
# The launch itself is completed by the Owner Safe signing/executing the transaction in
# output/etherfi/safe-launch-tx.json (operation = 1 / DELEGATECALL).
#
# Requirements: foundry; RPC_OPTIMISM (falls back to https://mainnet.optimism.io);
# broadcast mode additionally needs `account` (foundry keystore) with OP ETH and
# ETHERSCAN_API_KEY_OPTIMISM for source verification.
set -euo pipefail
cd "$(dirname "$0")/../.."

MODE="${1:-rehearse}"
RPC="${RPC_OPTIMISM:-https://mainnet.optimism.io}"

log() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- stage 1: validate
log "stage 1/3: preflight validation against $RPC"
forge script scripts/etherfi/ValidateEtherfiCashLaunch.s.sol:ValidateEtherfiCashLaunchScript \
  --rpc-url "$RPC" 2>&1 | sed -n '/== Logs ==/,$p' | tee /tmp/etherfi-validate.log

grep -q 'READY: all instance addresses resolve' /tmp/etherfi-validate.log \
  || die "preflight NOT READY - fill the TBD addresses in src/etherfi/EtherfiCashOpMainnet.sol"

# ---------------------------------------------------------------- stage 2: rehearse
log "stage 2/3: dress rehearsal on an OP Mainnet fork (deploy + Safe-context execute + verify)"
forge test --match-path tests/etherfi/EtherfiCashLaunchFork.t.sol --fork-url "$RPC" -vv 2>&1 \
  | tee /tmp/etherfi-rehearse.log | grep -E "\[PASS\]|\[FAIL\]|VERIFIED|MISMATCH|Suite result"
grep -q "Suite result: ok" /tmp/etherfi-rehearse.log || die "fork rehearsal failed - see /tmp/etherfi-rehearse.log"
log "rehearsal PASSED"

if [[ "$MODE" != "broadcast" ]]; then
  log "rehearse mode - stopping before any real transaction. Run with 'broadcast' to go live."
  exit 0
fi

# ---------------------------------------------------------------- stage 3: broadcast
[[ -n "${account:-}" ]] || die "broadcast mode needs account=<foundry keystore name>"

log "stage 3/3: BROADCAST payload deployment to OP Mainnet with keystore '$account'"
read -r -p "deploy the payload for real? type 'yes' to continue: " ACK
[[ "$ACK" == "yes" ]] || die "aborted by user"

log "deploying payload"
forge script scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol:DeployEtherfiCashLaunchPayloadScript \
  --rpc-url "$RPC" --account "$account" --broadcast --verify 2>&1 \
  | tee /tmp/etherfi-deploy.log | sed -n '/== Logs ==/,/^##/p'
PAYLOAD=$(grep -o 'deployed at: 0x[0-9a-fA-F]\{40\}' /tmp/etherfi-deploy.log | awk '{print $3}' | head -1)
[[ -n "$PAYLOAD" ]] || die "could not parse deployed payload address"

log "generating Owner-Safe transaction (output/etherfi/safe-launch-tx.json)"
PAYLOAD="$PAYLOAD" forge script scripts/etherfi/GenerateEtherfiCashSafeTx.s.sol:GenerateEtherfiCashSafeTxScript \
  --sig 'generate()' --rpc-url "$RPC" 2>&1 | sed -n '/== Logs ==/,$p'

log "generating launch spec (output/etherfi/launch-spec.md)"
PAYLOAD="$PAYLOAD" forge script scripts/etherfi/GenerateEtherfiCashLaunchSpec.s.sol:GenerateEtherfiCashLaunchSpecScript \
  --sig 'generate()' --rpc-url "$RPC" 2>&1 | sed -n '/== Logs ==/,$p'

log "DONE"
echo "payload:     $PAYLOAD (verified source on Etherscan)"
echo "next steps:"
echo "  1. share the payload address + output/etherfi/launch-spec.md for review"
echo "  2. propose output/etherfi/safe-launch-tx.json from the Owner Safe"
echo "     (operation = 1 / DELEGATECALL - Safe web Transaction Builder cannot do this; use safe-cli/SDK)"
echo "  3. after Safe execution: make etherfi-verify"
