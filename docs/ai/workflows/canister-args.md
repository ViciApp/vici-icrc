# Workflow: change canister init or upgrade arguments

For the ledger (token name, symbol, decimals, fee, minting account, archive), the index, or the minter `Arg`. History: `script: Init args for minter`, `fix: Build script`, `fix(scripts): never use the deploying identity as the ledger minting account`. These scripts decide what mainnet runs: ask first.

1. **Find the owner.** `dfx.json` names, per canister, the `pre_install` script and the `init_arg_file` it writes (`out/build.<canister>.args.did`):
   - ledger: `scripts/build.ledger.args.sh`
   - index: `scripts/build.index.args.sh`
   - minter: `scripts/build.minter.args.sh` (the Candid type is `Arg` in `src/minter/src/model.rs`)
2. **Both variants.** Each script writes `Init` or `Upgrade`, chosen by `scripts/check.canister.installed.sh` in `auto` mode or forced with `init` / `upgrade`. A value that must change on a live ledger goes in the `Upgrade` variant too; a value that only `Init` accepts (the decimals, the minting account, the initial balances) cannot change without a reinstall, which erases every balance. Say which one applies in the PR.
3. **The variant is a money decision for the minter.** `Arg::Init` on an installed minter starts from an empty state (see [upgrades](../domain.md#upgrades)). A change to how the variant is chosen is High risk, and the PR shows the generated argument for an installed and a not-installed canister.
4. **The minting account is the minter canister.** Never a personal principal, never the deploying identity, never a fallback; an unresolvable minter is a hard error (`scripts/build.ledger.args.sh`).
5. **Per network.** Values that differ between `ic`, `staging` and `local` live in the script's `DFX_NETWORK` `case`; canister ids come from `canister_ids.json`, never a literal.
6. **One value, one place.** Decimals are also the default `DECIMALS` in `scripts/init.reserves.sh`, and the ledger-suite release is in `dfx.json` and `scripts/download.ledger.sh`: change every copy in the same PR, or better, make them read one source (rule 5). A change to the decimals also changes every base-unit number in `scripts/init.reserves.sh` and must stay inside 64-bit shell arithmetic (see [units](../domain.md#units)).
7. **Check the output.** Run the script with `DFX_NETWORK=local` and each mode, and read the generated `.did` argument; then `npm run deploy` on a local replica. Paste the generated argument in the PR.
8. **Gates.** `npm run format` (shfmt), `npm run lint` (shellcheck). Never run a script against `ic`; the owner deploys.
