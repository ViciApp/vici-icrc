# VICI Token — TL;DR

**What:** Reward and coordination token (symbol: **VICI**). Scarce, earned by top users, real utility from day one.

**Total supply:** 1,000,000,000 VICI

**Who earns:** Top and most active users — not everyone.

---

## Reserves

### Community (450M, 45%)

| Reserve       | Cap    | % of 45% | Who gets it                                        | Auto-refill        |
| ------------- | ------ | -------- | -------------------------------------------------- | ------------------ |
| **rewards**   | 180M   | 40%      | Top-performing predictors (accuracy-weighted)      | yes, ~40k VICI/day |
| **liquidity** | 112.5M | 25%      | Liquidity providers, market makers                 | yes, ~30k VICI/day |
| **oracle**    | 67.5M  | 15%      | Market creators, oracle resolvers                  | yes, ~15k VICI/day |
| **staking**   | 45M    | 10%      | Users who stake VICI (markets, conviction, oracle) | yes, ~10k VICI/day |
| **campaign**  | 22.5M  | 5%       | Ecosystem partners, event participants             | yes, ~5k VICI/day  |
| **buffer**    | 22.5M  | 5%       | Reserved for future needs                          | manual only        |

### Non-community (550M, 55%) — all manual

| Reserve       | Cap  | %   | When                                            |
| ------------- | ---- | --- | ----------------------------------------------- |
| **treasury**  | 200M | 20% | As needed (grants, R&D, governance-directed)    |
| **team**      | 150M | 15% | Per vesting schedule (4 years + 12-month cliff) |
| **investors** | 150M | 15% | Per vesting schedule (3 years)                  |
| **advisors**  | 50M  | 5%  | Per vesting schedule (24 months)                |

---

## Emission schedule (community only)

| Phase     | Amount  | Daily rate     |
| --------- | ------- | -------------- |
| Years 1–3 | ~225M   | ~100k VICI/day |
| Years 4–7 | ~157.5M | decreasing     |
| Year 8+   | ~67.5M  | long tail      |

---

## How it flows

```
Minter (auto, every hour)
  → checks each community reserve's balance
  → below target? mint to refill (capped by lifetime max + rate limits)
  → reserve wallets stay funded

App backend (holds reserve wallets)
  → top predictor by accuracy → VICI from rewards reserve
  → LP provides liquidity → VICI from liquidity reserve
  → user creates/resolves market → VICI from oracle reserve
  → user stakes for conviction → VICI from staking reserve
  → partner campaign → VICI from campaign reserve

Non-community reserves (treasury, team, investors, advisors)
  → manual top-up only, no auto-rebalance
  → vesting enforced off-chain via legal agreements

Users never interact with the minter. They just see VICI arrive.
```

---

## VICI utility (not money, not the betting currency)

- **Feature access** — advanced prediction modes, premium analytics, private competitions
- **Status** — VICI earnings as visible indicator of skill and contribution
- **Staking** — stake to create markets, back predictions, serve as oracle
- **Governance** — voting on platform parameters (where enabled)

---

## Key design choices

- **Scarce.** Not everyone earns VICI — it requires accuracy, contribution, or protocol-level work.
- **Not settlement.** VICI is not the betting currency. Settlement (stablecoin) is a separate, future layer.
- **Not XP.** XP is for gameplay (everyone earns). VICI is the upside (top users earn).
- **Minter is dumb.** It only refills wallets. The app decides who gets what.

---

## See also

- [Tokenomics](TOKENOMICS.md) — full economic design
- [Minter README](src/minter/README.md) — how the reserve system works
- [Vici XP](https://github.com/AntoninoVentworthy/vici-points) — the gameplay/onboarding token
