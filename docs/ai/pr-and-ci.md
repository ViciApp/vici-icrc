# PRs and CI

## Scope

One purpose per PR, each opened from `main` and mergeable in any order; stack only when one PR needs the other's code. These are rules [2 (scoped)](https://github.com/AntonioVentilii/officina/blob/main/standards/code.md#2-scoped) and [3 (parallel, not stacked)](https://github.com/AntonioVentilii/officina/blob/main/standards/code.md#3-parallel-not-stacked) of the Officina code standard.

## Title

Conventional commits: `type(scope): description`, lowercase, imperative, no trailing period. The scope is required: the `pr-checks` title check rejects a title without one. The PR is squashed, so its title becomes the commit on `main`.

- Types the check accepts: `feat`, `fix`, `perf`, `deps`, `revert`, `docs`, `style`, `chore`, `refactor`, `test`, `build`, `ci`.
- Scopes seen: `scripts`, `deps`, `pr-checks`, and Dependabot's `cargo-deps`, `cargo-deps-dev`, `npm-deps-dev`, `rust`, `github-actions`. Use `minter` for canister code, `scripts` for scripts, `ai` for agent docs.
- Examples from the history: `fix(scripts): never use the deploying identity as the ledger minting account`, `ci(pr-checks): run the org-wide pull request checks`.

## Body

Fill the sections of [`.github/pull_request_template.md`](../../.github/pull_request_template.md): Summary, Risk Classification, Linked Artifacts, Checklist, Evidence of Verification.

- Risk follows [the scale in governance.md](./governance.md#risk-levels): any change under `src/minter/src/` is at least Medium; a change to minting, locks, idempotency, caps, guards or persisted types is High.
- A High change says, rule by rule, what it does to the invariants of [`domain.md`](./domain.md).
- Linked Artifacts holds real links (an issue, the PR this one follows) or the word "None". The template's `file:///` placeholders never stay in.
- Evidence lists the commands run and their result (`cargo test`: 42 passed), and for an API change the `minter.did` diff.
- Call out any protected path touched (see [governance.md](./governance.md)).
- No AI attribution lines. Do not start a body line with `Test:` or `Fix:`.
- Nothing about a suspected security or money bug: that goes to the owner in private.

## Local gates

Run before opening a PR:

```bash
npm ci
npm run format                  # then commit what it changed
npm run lint                    # prettier check, workspace deps, did, zizmor, clippy, shellcheck
cargo test --locked -p minter   # not in CI
npm run did                     # when an endpoint or a Candid type changed; commit minter.did
npm run build                   # when Cargo.toml, Cargo.lock or the build scripts changed
```

`npm run format` needs the nightly in `dev-tools.json` (rustfmt runs with unstable options), cargo-sort and shfmt; `npm run lint` needs yq, zizmor and shellcheck; `npm run did` needs candid-extractor. `scripts/setup <tool>` installs each at its pinned version.

## CI

- `.github/workflows/checks.yml` on every PR, push to `main`, `v*` tag and merge group:
  - `format`: runs `npm run format` and fails if it changed any file.
  - `lint`: runs `npm run lint`.
  - `checks-pass`: fails unless both jobs succeeded. The repository's `checks` ruleset requires it.
- `.github/workflows/pr-checks.yml` on every PR and merge group: calls the org-wide pull request rules in `ViciApp/.github` (`.github/workflows/pull-request.yml`, the one copy every ViciApp repository runs): a Conventional Commit title with a scope, and no empty change, checked again for each merge queue entry. The org `baseline` ruleset requires its `pr-checks / pass`, a pull request for every change to `main`, and a Copilot review.
- `main` merges by squash through the merge queue (this repo's `merge-queue` ruleset). Queuing a PR is merging it: only the owner does it, and an agent never enables auto-merge.
- Not in CI: `cargo test`, `npm run build`, and a check that `minter.did` matches the code. Those are on you.
- `.github/workflows/release.yml` on a `v*` tag or a published release: builds the minter wasm, downloads ledger and index, and attaches the wasm and `.did` files to the GitHub release that vici-app pins.
- Nothing deploys from CI. An agent opens the PR and stops there.

## After CI fails

- `format` failed: run `npm run format` locally, commit the result.
- `lint` failed: fix the code. Never add `#[allow]`, never relax `[workspace.lints]` or a script to get green (rule 11, respect CI).
- `pr-checks` failed: fix the title, or the PR has become empty against `main`.

## Updating a PR

Add commits; never force-push, amend or rebase a pushed branch. Bring `main` in with a merge. Answer every review comment, Copilot's included: fix it, or say why not, then resolve the thread.
