#!/usr/bin/env bash
#
# Local reserve principals — copy to init.reserves.config.sh and edit.
#
#   cp scripts/init.reserves.config.example.sh scripts/init.reserves.config.sh
#
# scripts/init.reserves.config.sh is gitignored so real principals stay off git.
# This example is committed with empty values: you must fill all five before running.
#
# Why a wrapper instead of editing init.reserves.sh?
#   - init.reserves.sh stays generic (reviewable, safe to commit).
#   - Your principals live in one obvious place (this file).
#   - Same pattern as .env + tooling: separate config from logic.
#
# Common practice elsewhere: never commit production keys; use env vars in CI,
# a gitignored file locally, or a secret store (Vault, cloud SM). For IC,
# principals are not secret like API keys, but they are deployment-specific,
# so keeping them out of the repo is still good hygiene.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export VICI_RESERVE_PRINCIPAL_COMMUNITY=""
export VICI_RESERVE_PRINCIPAL_TREASURY=""
export VICI_RESERVE_PRINCIPAL_TEAM=""
export VICI_RESERVE_PRINCIPAL_INVESTORS=""
export VICI_RESERVE_PRINCIPAL_ADVISORS=""

exec "${SCRIPT_DIR}/init.reserves.sh" "$@"
