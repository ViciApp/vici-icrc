# Testing

## Where tests live

- **Unit tests** sit in a `#[cfg(test)] mod tests` at the bottom of the file they test. Today that is `src/minter/src/services/reserve.rs:425`: the tests over validation, rate limits, pruning and `compute_rebalance`.
- **No integration tests yet.** `pocket-ic` is a dev-dependency of the minter, but no test uses it. The flows that lock, call the ledger and commit (`services/rebalance.rs`, the manual top-up in `api/admin/api.rs`), the guards, the idempotency keys and the upgrade path (`state.rs`, `lib.rs`) have no automated test today. A change there is proven by hand on a local replica and says so in the PR.

## How they are written

Copy the style of `services/reserve.rs`:

- One behaviour per `#[test]`, named for the behaviour in snake case with no `test_` prefix (`redundant_test_prefix` is denied): `caps_at_max_topup_per_rebalance`, `rejects_empty_label`.
- Fixtures are small builder functions in the test module (`sample_config`, `sample_policy`, `services/reserve.rs:439-465`); a test mutates the field it is about.
- Time is a parameter: pass `now_ns` built from the window constants (`NANOS_PER_HOUR * 2`), never call `time()`.
- Amounts are `Nat::from(1000_u64)` style literals in base units, with the suffix separated (`unseparated_literal_suffix` is denied).
- Assert the outcome a caller sees: the `RebalanceAction`, the `mint_amount`, or `matches!(r, Err(MinterError::RateLimitExceeded { .. }))`.
- `unwrap()` is fine in tests; keep it out of production code (rule 6).

## What a money change must test

A change to a rule in [`domain.md`](./domain.md) comes with tests for:

- the boundary on both sides (an amount equal to the cap passes, one base unit more does not);
- zero, and a value far above any real supply (the whole supply is `10^17` base units; `Nat` does not overflow, the test proves the rule does not assume it would);
- each cap being the one that binds, and the order when two bind at once;
- the same input run twice giving the same answer (the rules are pure; a test that needs state belongs in an integration test).

## Where a new test goes

| What you changed                                  | Test it                                                                                                                                |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| A rule in `services/reserve.rs`                   | a unit test in its `mod tests`                                                                                                         |
| New logic in a flow                               | extract the decision into a pure function in `reserve.rs` and unit-test that                                                           |
| Locking, idempotency, upgrade or ledger behaviour | a PocketIC integration test under `src/minter/tests/` (ask first: it is the first one, and needs the ledger wasm from `npm run build`) |

## Commands

```bash
cargo test --locked -p minter     # all unit tests, native target
npm run lint                      # clippy also checks the test code (--tests)
```

CI does not run `cargo test` (see [pr-and-ci.md](./pr-and-ci.md)): run it before every PR that touches `src/minter/`.
