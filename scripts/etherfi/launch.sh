#!/usr/bin/env bash
# ether.fi Cash Aave V4 launch pipeline (OP Mainnet, whitelabel — Safe-administered).
#
# Usage:
#   scripts/etherfi/launch.sh rehearse                       # validate + fork dress rehearsal
#   account=<keystore> scripts/etherfi/launch.sh broadcast   # the real thing (asks for confirmation)
#
# Stages:
#   1. validate   read-only preflight of every address in AaveV4EtherfiCash.sol
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
  || die "preflight NOT READY - fill the TBD addresses in src/etherfi/AaveV4EtherfiCash.sol"

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

log "deploying both payloads (phase 1 config + phase 2 activation)"
forge script scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol:DeployEtherfiCashLaunchPayloadScript \
  --rpc-url "$RPC" --account "$account" --broadcast --verify 2>&1 \
  | tee /tmp/etherfi-deploy.log | sed -n '/== Logs ==/,/^##/p'
PAYLOAD=$(grep 'EtherfiCashLaunchPayload (phase 1' /tmp/etherfi-deploy.log | grep -o '0x[0-9a-fA-F]\{40\}' | head -1)
ACTIVATION=$(grep 'EtherfiCashActivationPayload (phase 2' /tmp/etherfi-deploy.log | grep -o '0x[0-9a-fA-F]\{40\}' | head -1)
[[ -n "$PAYLOAD" && -n "$ACTIVATION" ]] || die "could not parse deployed payload addresses"

log "generating Owner-Safe transactions (safe-launch-tx.json + safe-activation-tx.json)"
PAYLOAD="$PAYLOAD" ACTIVATION="$ACTIVATION" \
  forge script scripts/etherfi/GenerateEtherfiCashSafeTx.s.sol:GenerateEtherfiCashSafeTxScript \
  --sig 'generate()' --rpc-url "$RPC" 2>&1 | sed -n '/== Logs ==/,$p'

log "generating launch spec (output/etherfi/launch-spec.md)"
PAYLOAD="$PAYLOAD" ACTIVATION="$ACTIVATION" \
  forge script scripts/etherfi/GenerateEtherfiCashLaunchSpec.s.sol:GenerateEtherfiCashLaunchSpecScript \
  --sig 'generate()' --rpc-url "$RPC" 2>&1 | sed -n '/== Logs ==/,$p'

log "DONE"
echo "phase 1 payload:    $PAYLOAD (verified source on Etherscan)"
echo "phase 2 activation: $ACTIVATION"
echo "next steps (two-phase launch):"
echo "  1. share the payload addresses + output/etherfi/launch-spec.md for review"
echo "  2. Owner Safe executes output/etherfi/safe-launch-tx.json"
echo "     (operation = 1 / DELEGATECALL - Safe web Transaction Builder cannot do this; use safe-cli/SDK)"
echo "  3. EXPECT_ACTIVE=false make etherfi-verify   # confirm the DORMANT configured state"
echo "  4. Owner Safe executes output/etherfi/safe-activation-tx.json"
echo "  5. make etherfi-verify                        # confirm the market is live"
