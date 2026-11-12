# Patterns

The patterns the minter really uses, each with an example to copy, and the anti-patterns already in the code, named so nobody copies them. The money rules behind them are in [`domain.md`](./domain.md). Paths are relative to `src/minter/src/` unless they start with `scripts/` or a file at the root.

## Endpoints

- **`*_impl` plus a thin endpoint.** The logic is a private function returning `Result<T, MinterError>`, so it can use `?`; the `#[update]` / `#[query]` function only converts it with `.into()`: `api/admin/api.rs:26` and `api/admin/api.rs:75-78`.
- **One named result enum per fallible endpoint**, `Ok(T)` / `Err(MinterError)`, with a `From<Result<T, MinterError>>` impl next to it: `api/admin/results.rs:47-62`. Endpoints that cannot fail return the payload directly (`list_reserves`, `get_global_policy`, `get_ledger_id`, `api/query/api.rs:14`, `:51`, `:58`). Large payloads go in a `Box` (`api/query/results.rs:21`). `scripts/lint.did.sh` fails the build if `Result` or `Result_N` shows up in the `.did`.
- **A guard on every endpoint**, in the attribute: `#[update(guard = "caller_is_controller")]` for anything that writes or mints, `caller_is_not_anonymous` for reads and previews (`guards.rs:5`, `guards.rs:15`). Authorization failures are guard rejections, not `MinterError` values (`model.rs:221-225`).
- **Previews are `#[update]`**, not queries, because they call the ledger: `api/admin/api.rs:514-575`.
- **Partial updates use `Option<Option<T>>`**: omit keeps, `null` clears, a value sets. The struct carries `#[expect(clippy::option_option)]` with the reason: `api/admin/params.rs:13`.

## Errors

- Every failure a caller can act on is a `MinterError` variant with the data needed to act (`model.rs:227`). Add a variant rather than a free-text `InvalidConfig` when callers need to branch on it.
- Ledger call failures are mapped once, in the client, to `MinterError::LedgerError` with the context in the message: `services/ledger.rs:17-27`.
- `TransferError::Duplicate` is a success that returns the original block: `services/ledger.rs:66-72`.
- After a successful mint, a missing reserve is `InternalInvariantViolated`, never a panic: `services/rebalance.rs:95-102`.

## State

- One `State`, in one `thread_local!` `RefCell`, reached only with `STATE.with_borrow` / `with_borrow_mut`: `state.rs:45-48`.
- **No `await` inside a borrow.** Read a snapshot (clone what the flow needs), drop the borrow, await, then commit in a new borrow. The section header `api/admin/api.rs:256` says it; `services/rebalance.rs:23-39` and `:93-110` show it.
- A check and the write it protects sit in the same borrow, so no other message can run between them: the duplicate-account scan and the insert in `add_reserve_impl` (`api/admin/api.rs:29-65`), the lock test and the removal in `remove_reserve_impl` (`:171-190`).

### Stable state

- `pre_upgrade` writes the Candid-encoded `State` with a 4-byte length prefix; `post_upgrade` restores it and traps if it cannot: `state.rs:58`, `state.rs:82`, `lib.rs:54-68`.
- So every type reachable from `State` (`ReserveRecord`, `ReserveConfig`, `RateLimits`, `MintEvent`, `GlobalPolicy`, `IdempotencyRecord`, `IdempotencyEntry`) is a stored format. A new field is `Option<T>` (Candid decodes a missing `opt` field as `null`); a removed or renamed field or variant needs a migration. Recipe: [change-persisted-type](./workflows/change-persisted-type.md).
- Timers do not survive an upgrade: `init` and `post_upgrade` both call `start_rebalance_timer` (`services/timer.rs:18`).
- What `Arg::Init` and `Arg::Upgrade` do to the state, and why it matters for supply: [upgrades](./domain.md#upgrades).

## Mint

Every mint, automatic or manual, follows the same five steps. The exact checks of each flow are in [order of operations](./domain.md#order-of-operations).

1. **Lock and snapshot** in one `with_borrow_mut`: insert the id into `reserve_mint_inflight`, fail with `ReserveOperationInProgress` if it was there, clone config, counters, events and policy (`services/rebalance.rs:23-39`).
2. **Check** with the pure functions of `services/reserve.rs` (`compute_rebalance`, `available_mint_budget`, `check_rate_limits`).
3. **Mint** through `ledger::mint_to` with a memo naming the operation (`rebalance:{id}`, `topup:{id}:{key}`).
4. **Commit** in a new borrow: release the lock, add to `lifetime_minted`, push a `MintEvent`, `prune_old_events` (`services/rebalance.rs:93-110`).
5. **Release the lock on every early exit**: `release_mint_lock` (`services/rebalance.rs:10`) or `rollback_manual_mint_begin` (`api/admin/api.rs:259`). A lock left behind blocks the reserve until a controller calls `release_stuck_mint_state`.

Manual top-ups add **idempotency**: a key is reserved as `Pending` in the same borrow as the lock, replayed from `Completed`, and rejected while pending (`api/admin/api.rs:369-413`).

A reserve cannot be removed while it is locked or has a `Pending` key (`api/admin/api.rs:172-185`).

## Pure rules

- Validation and amount computation take plain values and return `Result<_, MinterError>` or a value: `services/reserve.rs:58` (`validate_rate_limits`), `:192` (`available_mint_budget`), `:294` (`compute_rebalance`). `now_ns` is a parameter, never `time()` inside.
- Amounts are `candid::Nat` end to end, subtracted only after a `>` check, so they never underflow (`services/reserve.rs:213-217`).
- Larger rate-limit windows must be strictly more restrictive; compared by cross-multiplying, never dividing a `Nat` (`services/reserve.rs:45-77`).
- Time windows use `saturating_sub` for the cutoff, so a clock near zero (tests) does not underflow (`services/reserve.rs:178`, `:271`).

## Lints

- A lint that must stay off at one site gets `#[expect(clippy::lint)]` plus a comment saying why (`model.rs:37`, `api/admin/api.rs:306`, `state.rs:64`). `#[allow]` is denied by `allow_attributes`.
- Imports go through `use`, never absolute paths (`absolute_paths`), and from `core` before `std` (`std_instead_of_core`).
- `ic_cdk::println!`, never `std::println!` (`clippy.toml` `disallowed-macros`).

## Scripts

- One script per job, named `<verb>.<object>.sh`, started with `set -euo pipefail` (`scripts/lint.sh`), linted by shellcheck and formatted by shfmt (two-space indent).
- A script that writes canister arguments takes a mode (`auto`, `init`, `upgrade`), reads the network from `DFX_NETWORK`, and reads canister ids from `canister_ids.json`, never from a literal: `scripts/build.minter.args.sh`.
- A script that calls a canister has a dry run that prints the calls: `DRY_RUN=1` in `scripts/init.reserves.sh`. It checks its own arithmetic before calling anything (the cap sums at `scripts/init.reserves.sh:90-108`).
- Real principals never enter git: they live in the gitignored `scripts/init.reserves.config.sh`, copied from the example file.

## Anti-patterns in the code today

Do not copy these. Each is a follow-up of its own; fix one only in a PR whose purpose it is (rule 2, scoped).

- **A flow in the API layer.** The manual top-up flow, with its own validation, lock, ledger call and commit, lives in `api/admin/api.rs:306-494` while the rebalance flow lives in `services/rebalance.rs`. New flows go in `services/`.
- **Copy-paste around the mint.** The lock-and-snapshot tuple (`services/rebalance.rs:23-39`, `api/admin/api.rs:369-413`; the preview at `api/admin/api.rs:521-533` takes the same snapshot without the lock), the release-on-error `match` (`services/rebalance.rs:41-55`, `:83-91`, `api/admin/api.rs:425-455`) and the post-mint commit (`services/rebalance.rs:93-110`, `api/admin/api.rs:457-485`) are written twice or more. Extend them into one helper before adding a third caller.
- **Rate-limit windows written three times.** `validate_rate_limits`, `available_mint_budget` and `check_rate_limits` each list the five windows (`services/reserve.rs:59-65`, `:200-206`, `:240-246`), over two sets of constants for the same lengths (`NANOS_PER_*` at `:13-21`, `HOURS_PER_*` at `:28-36`). A sixth window would need five edits.
- **Repeated result literals.** `compute_rebalance` builds the same zero `Skipped` result five times (`services/reserve.rs:306-411`).
- **Twin structs and twin validators.** `AddReserveArg` and `ReserveConfig` hold the same fields (`model.rs:72`, `:132`), copied one by one in `api/admin/api.rs:44-58`, and `validate_add_reserve_arg` and `validate_reserve_config` are the same body on each (`services/reserve.rs:140`, `:157`).
- **`ReserveInfo` built twice**, field by field, in `api/query/api.rs:18-22` and `:31-35`.
- **Empty modules.** `api/admin/errors.rs`, `api/query/errors.rs` and `api/query/params.rs` hold nothing.
- **`expect` outside tests and a magic page size.** `state.rs:63` and `:71` call `expect`, and the 64 KiB page size is the literal `65536` twice (`state.rs:68`, `:98`).
- **Variants nothing returns.** `NotAuthorized`, `AutoRebalanceNotAllowed` and `IdempotencyKeyAlreadyUsed` (`model.rs:229`, `:241`, `:262`) are kept only for the Candid interface. Do not add more reserved variants.
- **A field no rule reads.** `min_balance` is validated (`services/reserve.rs:114`) and stored, but the cyclical deficit starts at `target_balance` (`services/reserve.rs:328`); its doc comment says otherwise. Do not build on it before the owner settles what it means.
- **Free text where callers need to branch.** `release_stuck_mint_state_impl` reports a key pending for another reserve as `InvalidConfig` (`api/admin/api.rs:228-230`), and every `Skipped` reason is a sentence.
- **A map that only grows.** `State.idempotency` (`state.rs:25`) keeps every key for ever and is encoded on each upgrade.
- **Scripts.** `build.sh`, `did.sh`, `download.ledger.sh`, `format.cargo.sh` and `format.sh.sh` run without `set -euo pipefail`; the logo paths in `build.ledger.args.sh` point at an `assets/` folder that does not exist; the ledger-suite release tag is written in five places (`dfx.json`, `download.ledger.sh`) and `DECIMALS=8` in two (`build.ledger.args.sh`, `init.reserves.sh`); the ledger `Upgrade` argument sends `decimals`, a field the pinned ledger's `UpgradeArgs` does not have; `download.ledger.sh` says the ledger is "used for vUSD", a comment from another repository.
- **Tooling written twice or not at all.** The cargo-sort version is in `dev-tools.json` and again in `.github/actions/prepare/action.yml`; `dev-tools.json` pins tools nothing installs (`didc`, `solana`, `ic-wasm`, `cargo-audit`, `cargo-edit`); the `add-and-commit` action has no caller.
- **Dashes.** The product docs and a few comments use em and en dashes (rule 14 of the standard), and no lint stops new ones.
