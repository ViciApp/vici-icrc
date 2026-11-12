# Domain: the money rules

What must stay true about VICI supply, and how the code keeps it true today. Read this before touching an amount, a cap, a fee, the mint path, a ledger call or an upgrade. The product view is in [`TOKENOMICS.md`](../../TOKENOMICS.md) and [`src/minter/README.md`](../../src/minter/README.md); this page is the engineering contract. Paths are relative to `src/minter/src/` unless they start with `scripts/` or a file at the root.

A change that would break a rule here is not a refactor: stop and ask the owner. A suspected break already in the code is reported to the owner in private (this repository is public), never in a PR, an issue or a comment.

## The invariants

1. **Only the minter mints.** The ledger's minting account is the minter canister, never a person (`scripts/build.ledger.args.sh` refuses the deploying identity), and the ledger starts with `initial_balances = vec {}`. Every VICI in existence came from `ledger::mint_to` (`services/ledger.rs:38`).
2. **The minter mints only to registered reserves.** `mint_to` is called from two places, the rebalance (`services/rebalance.rs:84`) and the manual top-up (`api/admin/api.rs:442`), both with the account of a `ReserveRecord`. There is no endpoint that mints to an arbitrary account, and a reserve's account never changes after `add_reserve`.
3. **Every mint is counted.** A successful mint adds its exact amount to the reserve's `lifetime_minted` and pushes a `MintEvent` (`services/rebalance.rs:103-108`, `api/admin/api.rs:466-471`). The caps and rate limits below are only as good as these two counters: they must equal what the ledger really minted to that reserve.
4. **No reserve receives more than its `lifetime_received_maximum`.** Checked before every mint against `lifetime_minted` (`services/reserve.rs:378-394`, `api/admin/api.rs:345-353`).
5. **The 1,000,000,000 VICI commitment is the sum of those maximums.** The minter does not check the sum: `scripts/init.reserves.sh` does, once, when the reserves are registered. `remove_reserve` discards a reserve's counters, and `update_reserve` can raise or clear a maximum, so both are owner decisions about supply, not housekeeping.
6. **One mint at a time per reserve.** `reserve_mint_inflight` holds the reserve id from before the first `await` until the commit (see [the mint pattern](./patterns.md#mint)).
7. **Only a controller can cause a mint or change a rule.** Every update that writes or mints is `guard = "caller_is_controller"`; the hourly timer is the only other source of mints.

## Units

- **Amounts are base units in a `candid::Nat`**, end to end: arguments, state, ledger calls, results. The minter never sees whole tokens and never reads the decimals; every threshold and cap in a `ReserveConfig` is already in base units.
- **One VICI is `10^8` base units.** The decimals are set once, when the ledger is installed (`DECIMALS=8` in `scripts/build.ledger.args.sh`), and are the default of `scripts/init.reserves.sh`, which turns whole tokens into base units with `MULT = 10^DECIMALS`. The whole supply is `10^17` base units.
- **Shell arithmetic is signed 64-bit.** `10^17` fits; the same script with 10 or more decimals would overflow silently. Any number added to a script is checked against that bound.
- **Time is nanoseconds in a `u64`**, from `ic_cdk::api::time()`, in fields named `_ns`. A month is 30 days and a year 365 days (`services/reserve.rs:13-21`).

## Fees

- **A mint pays no fee.** `mint_to` sends `fee: None` (`services/ledger.rs:49`): a transfer from the minting account creates tokens and the reserve receives exactly `amount`. That equality is what lets `lifetime_minted` count ledger supply; never add a fee to a mint or subtract one from the amount recorded.
- **The ledger's transfer fee is `100_000` base units** (0.001 VICI), `TRANSFER_FEE` in `scripts/build.ledger.args.sh`, sent at install and again in every ledger upgrade argument. It applies to transfers between accounts; the minter never pays or collects it and holds no balance.
- **The minter does no burn accounting.** For the ledger a transfer to the minting account is a burn; `lifetime_minted` is gross and never goes down.

## Rounding

There is none, and it must stay that way.

- The Rust code never divides an amount. Deficits and budgets are sums, differences and comparisons of `Nat`.
- A `Nat` subtraction that would go negative panics, so every subtraction sits behind a `>` check on the same two values (`services/reserve.rs:213-217`, `:328-337`, `:361-362`, `:379-380`).
- Rates are compared by cross-multiplying, `limit_large * hours_small < limit_small * hours_large`, never by dividing a limit by a duration (`services/reserve.rs:74-77`).
- The scripts only multiply integers. Fractions of a token are written as whole tokens before the multiplication (`112500000`, not 112.5 million times something).

A rule that needs a ratio (a percentage, a pro-rata share) is a new kind of rule here: say which way it rounds and who gets the remainder, in the PR, before writing it.

## Order of operations

### Rebalance (`services/rebalance.rs:22`)

1. **Lock and snapshot**, one borrow: the reserve exists, its id goes into `reserve_mint_inflight` (already there: `ReserveOperationInProgress`), and the flow clones the ledger id, the config, `lifetime_minted`, `mint_events` and the global policy (`:23-39`).
2. **Read the balance** from the ledger (`:41`).
3. **Compute** with `reserve::compute_rebalance` (`services/reserve.rs:294`): `MintingDisabled` is an error; a disabled reserve or one with `allow_auto_rebalance = false` is `Skipped`; the raw amount is the larger of the cyclical deficit `target_balance - balance` and the lifetime deficit `lifetime_received_minimum - lifetime_minted`; then the caps, in this order: `max_topup_per_rebalance`, room under `max_balance`, room under `lifetime_received_maximum`, the global `max_mint_per_operation`.
4. **Rate limits, as a soft cap**: read `now`, shrink the amount to `available_mint_budget`, skip if the budget is zero (`:61-80`).
5. **Mint** with memo `rebalance:{id}` (`:82-91`).
6. **Commit**, one borrow: release the lock, add the amount to `lifetime_minted`, push a `MintEvent` stamped with the `now` of step 4, prune events older than a year (`:93-110`).

Any error in steps 2 to 5 releases the lock and records nothing.

### Manual top-up (`api/admin/api.rs:364`)

1. **Idempotency, lock and snapshot**, one borrow: a `Completed` key returns the stored response without minting; a `Pending` key is `IdempotencyOperationInProgress`; then the reserve exists, the lock is taken and the key is stored as `Pending` (`:369-413`).
2. **Validate**, same message, no `await` before it: minting enabled, reserve enabled, `allow_manual_topup`, the global `max_mint_per_operation`, `lifetime_minted + amount <= lifetime_received_maximum`, and the rate limits as a hard check (`validate_manual_topup_inputs`, `:318-360`). The amount is exact: this path rejects, it never shrinks. It does not read the ledger balance.
3. **Mint** with memo `topup:{id}:{key}`, or `topup:{id}` without a key (`:437-455`).
4. **Commit**, one borrow: release the lock, update the counters as the rebalance does, store the key as `Completed` with the block index (`:457-485`).

A failed validation or a failed mint calls `rollback_manual_mint_begin` (`:259`): lock released, `Pending` key dropped.

### What a change here must keep

- The counters move only in the commit, and only by the amount handed to `mint_to`.
- Nothing between the lock and the commit trusts state read before an `await` to still be current, except the snapshot it took on purpose. The config and policy a mint uses are the ones read at the lock.
- Every way out of the flow, including every way the ledger call can end, has a decided answer for the lock, the counters and the idempotency key. Write those answers in the PR.

## Rate limits

- Five optional rolling windows per reserve: hour, day (24 h), week (7 d), month (30 d), year (365 d). Usage in a window is the sum of the `MintEvent`s with `timestamp_ns >= now - window` (`services/reserve.rs:177`).
- A config is valid only if each larger configured window allows a strictly lower rate than the next smaller one (`validate_rate_limits`, `services/reserve.rs:58`).
- The rebalance shrinks to the tightest remaining budget; the manual top-up fails with `RateLimitExceeded`.
- Events older than a year are pruned after each mint, so no window can be longer than a year without changing `prune_old_events`.

## Calls to other canisters

- The minter calls one canister, the ledger in `State.ledger_id`, with two methods: `icrc1_balance_of` and `icrc1_transfer`, both in `services/ledger.rs`, both `Call::bounded_wait`, with no cycles attached. A new call goes in that file, or in a sibling client for another canister, never inline in a flow.
- `ledger_id` is set at install and is never changed by an endpoint.
- A transport error, a reject or a reply that does not decode becomes `MinterError::LedgerError` with the context in the message (`services/ledger.rs:20-27`, `:57-64`). A ledger `TransferError::Duplicate` is returned as success with the original block (`:68`).
- The memo is cut to 32 bytes, the ledger's default memo limit (`services/ledger.rs:44`), and `created_at_time` is the minter's `time()` at the call (`:51`).
- No `STATE` borrow is held across an `await`, and the canister keeps running other messages while it waits: that is why the lock exists.

## Upgrades

- `pre_upgrade` Candid-encodes the whole `State` and writes it to stable memory as a 4-byte little-endian length followed by the payload (`state.rs:58`). If it traps, the upgrade is cancelled and the old code keeps running.
- `post_upgrade(Arg::Upgrade)` restores that state and traps if it cannot (`lib.rs:57-61`), which also cancels the upgrade.
- `post_upgrade(Arg::Init)` does not restore anything: it starts from `State::default()` with the given ledger id (`lib.rs:62-64`). It exists for the first install over a placeholder canister and is never used on a minter that holds reserves: an upgrade of a live minter always carries `Upgrade`, and the generated `out/build.minter.args.did` is read before any deploy.
- Every type reachable from `State` is a stored format; see [stable state](./patterns.md#stable-state) and the [persisted-type recipe](./workflows/change-persisted-type.md).
- The locks (`reserve_mint_inflight`) and the `Pending` idempotency keys are part of `State` and survive an upgrade. A minter upgraded while a mint is waiting on the ledger comes back with that lock set; `release_stuck_mint_state` clears it, after the owner has checked on the ledger what was minted.
- Timers do not survive: `init` and `post_upgrade` both arm the hourly rebalance (`services/timer.rs:18`), so the first automatic rebalance is one interval after an upgrade.
- A reinstall is not an upgrade. `reinstall:minter:prod` resets the counters; `reinstall:ledger:prod` erases every balance and the whole history. Never run them.
- On the ledger, the decimals and the minting account are install-time only; the symbol, the name, the fee, the logo and the feature flags are sent again with every upgrade (`scripts/build.ledger.args.sh`).

## Numbers that are decisions

Reserve caps and daily budgets (`scripts/init.reserves.sh`), the token's decimals and fee (`scripts/build.ledger.args.sh`), `REBALANCE_INTERVAL` (`services/timer.rs:8`), the window lengths (`services/reserve.rs:13-36`) and the defaults of `GlobalPolicy` (`model.rs:177`) move supply or its pace. An agent proposes a change to one of them and the owner picks; see [governance](./governance.md#never-without-an-explicit-ask).
