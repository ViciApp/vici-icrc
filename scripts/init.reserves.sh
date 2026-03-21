#!/usr/bin/env bash
#
# Initialize minter reserves according to TOKENOMICS.md (allocation caps only).
#
# Registers five reserves — one per bucket — with:
#   - lifetime_received_maximum = bucket cap (matches max in-use supply from minter for that account)
#   - max_balance = same cap (account balance cannot exceed allocation)
#   - min_balance / target_balance = 0 (no automatic mint until you raise targets or use manual top-up)
#   - allow_auto_rebalance = false
#   - allow_manual_topup = true
#
# Prerequisites:
#   - bash, dfx (no Python required)
#   - Minter deployed; caller must be minter controller for add_reserve
#
# Reserve accounts: five ICRC-1 owner principals (subaccount = null). Supply them via:
#
#   1) Environment (what a wrapper script usually exports):
#        VICI_RESERVE_PRINCIPAL_COMMUNITY, _TREASURY, _TEAM, _INVESTORS, _ADVISORS
#   2) Five command-line arguments (same order as above).
#
# See scripts/init.reserves.config.example.sh — copy to init.reserves.config.sh (gitignored),
# fill principals, run it (transparent local config; keeps secrets out of git).
#
# Optional:
#   DFX_NETWORK (default: local)
#   DFX_IDENTITY — passed to dfx as --identity if set
#   DECIMALS — must match ledger token decimals (default: 8)
#   DRY_RUN=1 — print would-be dfx calls, do not execute
#   MINTER_CANISTER — canister name for dfx (default: minter)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

DFX_NETWORK="${DFX_NETWORK:-local}"
DECIMALS="${DECIMALS:-8}"
MINTER_CANISTER="${MINTER_CANISTER:-minter}"
DRY_RUN="${DRY_RUN:-0}"

case "${DECIMALS}" in
'' | *[!0-9]*)
  echo "ERROR: DECIMALS must be a non-negative integer (got '${DECIMALS}')" >&2
  exit 1
  ;;
esac

# 10^DECIMALS in base units (integer math only — avoids awk/Python float precision issues).
pow10() {
  local d="$1"
  local r=1
  local i
  for ((i = 0; i < d; i++)); do
    r=$((r * 10))
  done
  echo "${r}"
}

MULT="$(pow10 "${DECIMALS}")"

# Whole-token amounts per TOKENOMICS.md (must sum to 1_000_000_000).
CAP_COMMUNITY=$((450000000 * MULT)) # 45% lifetime cap (vesting + incentives)
CAP_TREASURY=$((200000000 * MULT))  # 20% lifetime cap (vesting + incentives)
CAP_TEAM=$((150000000 * MULT))      # 15% lifetime cap (vesting)
CAP_INVESTORS=$((150000000 * MULT)) # 15% lifetime cap (vesting)
CAP_ADVISORS=$((50000000 * MULT))   # 5% lifetime cap (vesting)

TOTAL_CAP=$((CAP_COMMUNITY + CAP_TREASURY + CAP_TEAM + CAP_INVESTORS + CAP_ADVISORS))
EXPECTED_TOTAL=$((1000000000 * MULT))
if [[ "${TOTAL_CAP}" -ne "${EXPECTED_TOTAL}" ]]; then
  echo "ERROR: internal cap sum mismatch (${TOTAL_CAP} vs ${EXPECTED_TOTAL})." >&2
  exit 1
fi

usage() {
  cat >&2 <<'EOF'
Usage:
  init.reserves.sh <community> <treasury> <team> <investors> <advisors>

Or export all five:
  VICI_RESERVE_PRINCIPAL_COMMUNITY  VICI_RESERVE_PRINCIPAL_TREASURY  VICI_RESERVE_PRINCIPAL_TEAM
  VICI_RESERVE_PRINCIPAL_INVESTORS  VICI_RESERVE_PRINCIPAL_ADVISORS

Or use scripts/init.reserves.config.example.sh (copy to init.reserves.config.sh).
EOF
}

if [[ "$#" -eq 5 ]]; then
  VICI_RESERVE_PRINCIPAL_COMMUNITY="$1"
  VICI_RESERVE_PRINCIPAL_TREASURY="$2"
  VICI_RESERVE_PRINCIPAL_TEAM="$3"
  VICI_RESERVE_PRINCIPAL_INVESTORS="$4"
  VICI_RESERVE_PRINCIPAL_ADVISORS="$5"
elif [[ "$#" -eq 0 ]]; then
  missing=()
  [[ -z "${VICI_RESERVE_PRINCIPAL_COMMUNITY:-}" ]] && missing+=(VICI_RESERVE_PRINCIPAL_COMMUNITY)
  [[ -z "${VICI_RESERVE_PRINCIPAL_TREASURY:-}" ]] && missing+=(VICI_RESERVE_PRINCIPAL_TREASURY)
  [[ -z "${VICI_RESERVE_PRINCIPAL_TEAM:-}" ]] && missing+=(VICI_RESERVE_PRINCIPAL_TEAM)
  [[ -z "${VICI_RESERVE_PRINCIPAL_INVESTORS:-}" ]] && missing+=(VICI_RESERVE_PRINCIPAL_INVESTORS)
  [[ -z "${VICI_RESERVE_PRINCIPAL_ADVISORS:-}" ]] && missing+=(VICI_RESERVE_PRINCIPAL_ADVISORS)
  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "ERROR: unset environment variables: ${missing[*]}" >&2
    usage
    exit 1
  fi
else
  echo "ERROR: pass exactly five principal arguments, or none (use env)." >&2
  usage
  exit 1
fi

dfx_base=(dfx canister --network "${DFX_NETWORK}")
if [[ -n "${DFX_IDENTITY:-}" ]]; then
  dfx_base+=(--identity "${DFX_IDENTITY}")
fi

call_add_reserve() {
  local label="$1"
  local purpose="$2"
  local principal="$3"
  local cap_nat="$4"

  # Candid text: avoid double quotes inside purpose (or escape them).
  local candid
  candid=$(
    cat <<EOF
(record {
  account = record { owner = principal "${principal}"; subaccount = null };
  min_balance = 0 : nat;
  target_balance = 0 : nat;
  max_balance = opt (${cap_nat} : nat);
  max_topup_per_rebalance = null;
  lifetime_received_minimum = null;
  lifetime_received_maximum = opt (${cap_nat} : nat);
  rate_limits = null;
  enabled = true;
  allow_manual_topup = true;
  allow_auto_rebalance = false;
  purpose = "${purpose}";
  label = "${label}";
})
EOF
  )

  echo "--- add_reserve ${label} (${cap_nat} base units) ---"
  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "${dfx_base[*]} call ${MINTER_CANISTER} add_reserve" "'${candid}'"
    return 0
  fi
  "${dfx_base[@]}" call "${MINTER_CANISTER}" add_reserve "${candid}"
}

echo "Network: ${DFX_NETWORK}, minter: ${MINTER_CANISTER}, decimals: ${DECIMALS}"
echo "Caps (base units): community=${CAP_COMMUNITY} treasury=${CAP_TREASURY} team=${CAP_TEAM} investors=${CAP_INVESTORS} advisors=${CAP_ADVISORS}"

call_add_reserve "community" "Tokenomics: community incentives pool (45% lifetime cap)" "${VICI_RESERVE_PRINCIPAL_COMMUNITY}" "${CAP_COMMUNITY}"
call_add_reserve "treasury" "Tokenomics: treasury (20% lifetime cap)" "${VICI_RESERVE_PRINCIPAL_TREASURY}" "${CAP_TREASURY}"
call_add_reserve "team" "Tokenomics: team allocation (15% lifetime cap)" "${VICI_RESERVE_PRINCIPAL_TEAM}" "${CAP_TEAM}"
call_add_reserve "investors" "Tokenomics: investors (15% lifetime cap)" "${VICI_RESERVE_PRINCIPAL_INVESTORS}" "${CAP_INVESTORS}"
call_add_reserve "advisors" "Tokenomics: advisors (5% lifetime cap)" "${VICI_RESERVE_PRINCIPAL_ADVISORS}" "${CAP_ADVISORS}"

echo "Done. Verify with: ${dfx_base[*]} call ${MINTER_CANISTER} list_reserves"
