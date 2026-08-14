# VICI tokenomics

> [!TIP]
> **Looking for the short version?** See the [TL;DR](TLDR.md) — reserves, emission rates, and the full flow in one page.

This document describes the intended economic design for the **VICI token** (symbol: **VICI**), the reward and coordination layer of the Vici prediction platform. On-chain, VICI is an **ICRC** token on the Internet Computer. **Economic policy** does not rely on a hard-coded fixed supply in the ledger; it relies on **how the minter is configured** — in particular [reserve accounts](src/minter/README.md) with **lifetime mint caps** and other limits.

## Dual-token context

Vici operates a dual-token model:

| Token                                                                          | Symbol | Role                        | Who earns                        | Friction   |
| ------------------------------------------------------------------------------ | ------ | --------------------------- | -------------------------------- | ---------- |
| **Vici XP** ([vici-points](https://github.com/ViciApp/vici-points))            | VXP    | Gameplay / onboarding layer | Everyone — every user, instantly | Zero       |
| **VICI Token** (this repo)                                                     | VICI   | Reward / coordination layer | Top / most active users — scarce | Higher bar |

A third layer — **settlement** (stablecoin for real-money prediction markets) — is a separate, future concern and is not part of either token.

### Why two tokens?

| Concern              | How the split helps                                                                                                                                                           |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Regulation**       | XP is play money — no MiCA / e-money classification risk. VICI is a coordination/utility asset, not settlement currency. Clean separation avoids "1 token = 1 USD" ambiguity. |
| **Growth**           | XP removes all friction (no wallet, no money feel). VICI adds scarce upside without being the betting currency.                                                               |
| **Incentive design** | XP drives engagement (progression, streaks, leaderboard). VICI rewards excellence and contribution. Different tokens for different goals.                                     |

### Strategy (vs. Polymarket / Kalshi)

- **Polymarket** is money-first (USDC betting): strong incentives, but niche and regulatory pressure.
- **Kalshi** is regulation-first: safe but slow and less engaging.
- **Vici** is product-first: build a massive, engaging prediction gameplay layer (XP) first, then layer in money later (settlement). VICI sits in the middle as the reward/coordination asset that connects gameplay to real value.

---

## ICRC reality vs. target economics

| Aspect                     | ICRC / ledger                           | Target policy                                                                                                  |
| -------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| New tokens                 | Minted from the minting account         | Same mechanism                                                                                                 |
| Maximum circulating design | Not "1B hard cap" in the token standard | **1,000,000,000 VICI** as the **maximum amount we commit to mint in total**, enforced by reserve configuration |
| Where minted tokens go     | Transfers from minter                   | Only to **pre-approved reserve accounts**; the minter does not mint to arbitrary users                         |

**Operational model:** treat each major allocation (community rewards, treasury, team, etc.) as one or more **minter reserves**. Set each reserve's `lifetime_received_maximum` so that the **sum of lifetime maximums across all reserves does not exceed 1B VICI** (in base units, respecting decimals). Additional safety layers (`max_balance`, `max_topup_per_rebalance`, `rate_limits`, global `minting_enabled`, `max_mint_per_operation`) align short-term flows with long-term emission intent.

The [minter README](src/minter/README.md) documents the exact fields (`lifetime_received_minimum`, `lifetime_received_maximum`, rebalance rules, and so on).

---

## Total supply and initial allocation (policy)

**Target maximum minted supply:** **1,000,000,000 VICI** (fixed for economic planning).

| Category          | Share   | Tokens | Reserve role                                                   |
| ----------------- | ------- | ------ | -------------------------------------------------------------- |
| Community rewards | **45%** | 450M   | Scarce rewards for top/most active users                       |
| Treasury          | **20%** | 200M   | Ecosystem, liquidity, R&D, discretionary grants                |
| Team              | **15%** | 150M   | Team allocation (with vesting off-chain or via separate locks) |
| Investors         | **15%** | 150M   | Investor allocation (with vesting)                             |
| Advisors          | **5%**  | 50M    | Advisor allocation (with vesting)                              |

**Interpretation:** VICI is earned through excellence and contribution, not participation alone. Unlike XP (which everyone earns), VICI is distributed selectively to the best and most active users, and through protocol-level activities (liquidity provision, oracle work, staking).

---

## Community reserves (450M)

The 450M community allocation is split into six on-chain minter reserves, each with its own lifetime cap and rate limits enforced by the minter:

| Reserve       | Cap (VICI) | % of 45% | Purpose                                                          | Auto-rebalance |
| ------------- | ---------- | -------- | ---------------------------------------------------------------- | -------------- |
| **rewards**   | 180M       | 40%      | Top-performer accuracy rewards, reputation-weighted payouts      | yes            |
| **liquidity** | 112.5M     | 25%      | Liquidity provider incentives (DEX, market making)               | yes            |
| **oracle**    | 67.5M      | 15%      | Market creation and oracle resolution rewards                    | yes            |
| **staking**   | 45M        | 10%      | Staking incentives (market creation, conviction, oracle staking) | yes            |
| **campaign**  | 22.5M      | 5%       | Ecosystem campaigns, partnerships, events                        | yes            |
| **buffer**    | 22.5M      | 5%       | Strategic reserve for future needs                               | no (manual)    |

Sub-reserve caps sum exactly to 450M. Each is registered as a separate minter reserve with its own principal, so per-category caps are enforced on-chain — not just in application logic.

### What changed from the single-token model

In the original single-token design, the community 45% included an **onboarding** reserve (15% = 67.5M) for signup and activation bonuses. With the dual-token split, onboarding is now handled entirely by **XP** — the gameplay token where every user earns from day one. The freed allocation is redistributed:

- `forecast` → renamed to **rewards** (40%, up from 30%) — reflects scarcity; not everyone earns VICI for predicting, only the best.
- `onboarding` → **removed** (moved to XP).
- New: **staking** (10%) — staking incentives for market creation, conviction, and oracle operations.

---

## Emissions (community pool)

From the **450M** community allocation, the **intended release shape** over time:

| Phase     | Share of community allocation | Approx. from 450M |
| --------- | ----------------------------- | ----------------- |
| Years 1–3 | **50%**                       | ~225M             |
| Years 4–7 | **35%**                       | ~157.5M           |
| Year 8+   | **15%**                       | ~67.5M            |

This is **policy and scheduling**, implemented by:

- reserve **rate limits** and rebalance parameters,
- programme-level distribution from community/treasury reserves,
- and (where applicable) burning or locking outside the minter.

**Intent:** moderate early incentives to reward early contributors, then a long tail to reduce speculative inflation pressure. VICI emission is significantly more conservative than XP emission — scarcity is intentional.

### Daily emission budget

Year 1–3 target: **~75M/year = ~100k VICI/day** across all community buckets (approximately half the rate of the original single-token model, reflecting VICI's scarce positioning).

| Reserve       | Daily budget | Target balance (7 d) | Min balance (2 d) | Daily rate limit | Yearly rate limit |
| ------------- | ------------ | -------------------- | ----------------- | ---------------- | ----------------- |
| **rewards**   | 40k          | 280k                 | 80k               | 80k              | 14.6M             |
| **liquidity** | 30k          | 210k                 | 60k               | 60k              | 10.95M            |
| **oracle**    | 15k          | 105k                 | 30k               | 30k              | 5.475M            |
| **staking**   | 10k          | 70k                  | 20k               | 20k              | 3.65M             |
| **campaign**  | 5k           | 35k                  | 10k               | 10k              | 1.825M            |

The minter's auto-rebalance timer checks every hour. When a reserve's balance drops below its target, the minter refills it — subject to all configured caps, rate limits, and the lifetime maximum. Daily rate limits are set at 2x the daily budget to allow catch-up after downtime.

All parameters are adjustable at runtime via `update_reserve` — no canister redeployment required.

---

## Incentives: who earns VICI

Core principle: VICI is earned through **excellence and contribution**, not mere participation (that's what XP is for).

| Activity                                      | Reward (design intent)                     |
| --------------------------------------------- | ------------------------------------------ |
| Top prediction accuracy                       | VICI (accuracy-weighted, reputation-gated) |
| Liquidity provision                           | VICI                                       |
| Market creation                               | VICI                                       |
| Oracle / dispute resolution                   | VICI                                       |
| Staking (market creation, conviction, oracle) | VICI                                       |

**Design principle:** VICI rewards are tied to **accuracy, contribution, and protocol-level work**. Not everyone earns VICI — it requires demonstrating skill or providing value to the ecosystem. This supports both a compliance-conscious framing and the scarcity that gives VICI real utility.

---

## VICI utility (early value without positioning as money)

VICI has real utility from day one, without needing to be positioned as "money":

- **Feature access** — Advanced prediction modes, premium analytics, private competitions.
- **Status** — VICI holdings/earnings as a visible indicator of skill and contribution.
- **Governance** — Voting on market parameters, dispute resolution, platform decisions (where enabled).
- **Staking** — Stake VICI to create markets, back predictions with conviction, or serve as an oracle.

---

## Staking and alignment (product layer)

Staking mechanics are specified at the **application / protocol** layer (not in the ICRC ledger). Intended roles:

1. **Market creation staking** — Stake (e.g. 500 VICI) to create a market; good behaviour → stake returned plus rewards; abuse or spam → **slash / burn** (policy-defined).
2. **Reputation / confidence staking** — Stake behind predictions (e.g. 1,000 VICI); correct → higher rewards and reputation; wrong → loss of stake or opportunity cost.
3. **Oracle staking** — Oracles stake to resolve markets; incorrect resolution → **slashed** stake.
4. **Governance / utility staking (where applicable)** — Fee discounts, voting weight, feature access.

Exact percentages, lock durations, and formulas are **not** fixed in this repository; they belong in protocol specs and on-chain logic above the ledger.

---

## Liquidity incentives

- **Who:** liquidity providers, market makers, early traders (as defined by each programme).
- **Rewards:** trading fees plus **VICI emissions** from the liquidity reserve.
- **Dynamic:** incentive intensity **decreases over time** — bootstrap liquidity early, then rely more on organic fees and market depth.

---

## Revenue model and distribution (example)

**Example trading fee:** **1.5%** per trade (illustrative; actual fees are set by product).

**Illustrative split of protocol revenue:**

| Destination          | Share   |
| -------------------- | ------- |
| Treasury             | **50%** |
| Staking incentives   | **30%** |
| Liquidity programmes | **20%** |

**Important:** VICI is **not** designed as a profit-sharing security. Revenue **feeds treasury, incentives, and liquidity programmes** rather than guaranteeing pro-rata cash flow to token holders. Settlement of trades can remain in stablecoins (e.g. USDC); VICI acts as **coordination, staking, and governance** (where enabled).

---

## Treasury

The **treasury** allocation (200M) plus ongoing revenue supports:

- ecosystem grants,
- liquidity programmes,
- R&D,
- further community incentives,

subject to **token-holder governance** where implemented.

---

## Vesting (supply pressure)

| Group     | Vesting (intent)         |
| --------- | ------------------------ |
| Team      | 4 years + 12 month cliff |
| Investors | 3 years                  |
| Advisors  | 24 months                |

Vesting is enforced by **legal agreements**, vesting schedules in distribution contracts, and/or locked accounts — not by the ICRC ledger alone.

---

## Structural choices (summary)

| VICI is not (by design)          | VICI is                                |
| -------------------------------- | -------------------------------------- |
| Primary settlement currency      | A coordination and staking asset       |
| The betting currency             | Earned reward for top contributors     |
| Stablecoin                       | Governance and utility (where enabled) |
| Direct profit-sharing instrument | Subject to incentive and policy design |
| Play money (that's XP)           | Scarce, with real utility from day one |

---

## Mental model (dual-token flow)

```text
User opens app
  → earns XP instantly (predict, streak, leaderboard)
  → XP drives engagement loop (progression, status, competition)
  → zero friction, no wallet feel

Top users (accuracy, consistency, contribution)
  → earn VICI rewards (scarce, not everyone)
  → VICI unlocks: advanced modes, private competitions, feature access
  → VICI has staking utility: market creation, oracle, governance

Settlement layer (future, separate)
  → stablecoin for real-money betting (when/if compliant)
  → VICI is NOT the betting currency
```

---

## Operational architecture

The minter and the app backend have distinct responsibilities:

| Layer           | Responsibility                                                              |
| --------------- | --------------------------------------------------------------------------- |
| **Minter**      | Protocol-level emission control: lifetime caps, rate limits, auto-rebalance |
| **App backend** | User-level distribution: who earns rewards, per-user caps, anti-Sybil       |

The app backend holds a funded reward wallet (one per community sub-reserve). The minter refills these wallets automatically. The backend distributes tokens to users based on application logic — the minter does not need to know about individual users, activity stats, or reward formulas.

### Refill flow

```text
Minter timer fires (every 1 hour)
  → for each auto-rebalance reserve:
      → query ledger balance
      → balance < target_balance?
      → compute refill amount (capped by all limits)
      → mint to reserve account
  → backend wallet stays funded
  → backend distributes to users based on app logic
```

## Engineering and design items still to specify

The minter enforces **per-reserve** and **global** limits; it does not encode prediction markets or vesting. Open items for protocol specs:

- **Reward formulas** per action type (backend responsibility).
- **Per-user caps** and anti-Sybil enforcement (backend responsibility).
- **Slash** percentages and beneficiaries (burn vs. treasury).
- **Staking** lock durations and unstaking delays.
- **Reputation** ↔ token weighting.
- **XP-to-VICI** qualification criteria (what XP milestones unlock VICI earning potential).

---

## Future improvement: governance-controlled minting

Today, minting policy is enforced by **minter configuration** (admin-controlled reserves, caps, and rate limits). A natural upgrade is to place the **minter under on-chain governance** — for example via the [NNS](https://internetcomputer.org/docs/building-apps/governing-apps/overview) or a dedicated governance canister — so that **changes to minting limits, new reserves, and emission parameters** require a vote by **owners and/or stakers**, aligned with the long-term token design.

---

## See also

- [Minter canister — reserves and minting](src/minter/README.md)
- [Project README](README.md)
- [Vici XP (vici-points)](https://github.com/ViciApp/vici-points) — the gameplay/onboarding token
