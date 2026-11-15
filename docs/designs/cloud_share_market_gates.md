# Cloud Share Market: Gates and Cut List

> **Superseded in part (2026-11-15):** settlement was dropped (`docs/decisions/0001-drop-settlement.md`). Gates and never-cut items about the resolver, close hook, dispute replay and fallback no longer apply.

* **Status:** draft. It replaces "Build order and gates" in `cloud_share_market.md` (lines 601–612) and restores the brief's "never cut" list and cut order.
* **Addresses:** Zoom Out review Majors #1 and #6 (`docs/reviews/cloud_share_market_zoom_out.md`).
* **Sources:** dates, interview thresholds and outcomes come from `cloud_share_market.md` and `docs/inputs/concepts_brief.md`. Anything those don't settle is marked **TBD**.

## What changed and why

* **Demand is tested before the build, as the brief asked.** The brief called for a 48-hour demand gate. The design moved the interview result to G4 (Nov 23–25), after the contracts are built. Now a partial tally of 10 interviews at the end of G0 decides which contracts get built.
* **Only the vault starts before the demand result.** All three interview options need a split/merge vault, so building it early is safe. The resolver, hook and router depend on the answer, so they wait.
* **The freeze has two parts.** Before, the whole design froze on Nov 16, a day before the GOOGLc fork check ended. Now the parts that don't depend on GOOGLc freeze on Nov 16, and the collateral handling freezes once the fork result is in on Nov 17.
* **Each demand outcome has a concrete action,** instead of "the pitch changes".
* **Each gate names what gets cut if it slips.**

## Gate table

| Gate | When | Work | Pass condition | If it fails or slips |
|---|---|---|---|---|
| **G0: facts** | Nov 15–17 | Fork check (file 20): is GOOGLc a normal contract or a precompile; are `isAuthorized` checks a blocklist or an allowlist; do balances change with the multiplier; what does the issuer's pause block. Confirm Uniswap v4 addresses on Base Sepolia and Base, and whether Uniswap's Universal Router is deployed (the fallback for `buyCloud` and `sellCloud` if the custom router slips). Collect 8–12 quarters of Cloud share (file 24). Settle the Q4 question and write it into the rule (file 23). Ask the organisers whether this fits Track 3. Run the first 10 interviews (file 25). | All of the above are answered and written into the design. | Contracts can't hold GOOGLc → the demo runs on mocks only, and the README says why. Not Track 3 → stop and re-plan before G1b. |
| **G1a: partial freeze** | Nov 16 | Freeze what doesn't depend on GOOGLc: the series lifecycle, the ppm formula, the rule document, the resolver flow and the app page list. | Both team members sign off. | Slips into G1b; no cut. |
| **G1b: full freeze** | Nov 17 | Freeze the collateral and token handling from the fork result (decimals, units, `IB20` names). | Fork test results are in the design. | Cut 1. |
| **Demand gate** | End of Nov 17 | Tally the first 10 interviews against the outcomes below. | See "Demand gate outcomes". | See "Demand gate outcomes". |
| **G2: core contracts** | Nov 17–20 | Vault and mock token from Nov 17, whatever the demand result. Resolver from Nov 18, only if the demand gate passes. | Split, merge, redeem and resolver tests pass locally. The rule reproduces four quarters, including a Q4. | The rule can't map Alphabet mechanically → switch the demo stock to Nvidia (the plan's existing fallback). A late slip → cut 1. |
| **G3: local end to end** | Nov 20–22 | Router (on v4-periphery's swap helpers), mocks, router and invariant tests (files 9–10, 18–19). | The full local test passes (file 21): split, swap, merge, close, propose, dispute, decide, redeem. | Cuts 2 and 3. |
| **G4: testnet** | Nov 23–25 | Scripts 11–14, first testnet deploy, start the frontend. Finish the remaining 10 interviews. | Deployed on Base Sepolia. Final tally meets the 20-interview bar (8 of 20). | Cut 4. Interviews not done → cut 5. Final tally below the bar → see "Late reversal" below. |
| **G5: contracts frozen** | Nov 25–27 | Replay settlement on testnet. Invariant and fork tests green. | Disputed replay runs on testnet; contracts frozen. | Cut 6 (frontend polish). |
| **G6: final build** | Nov 27 – Dec 1 | Frontend pages 27–36, docs 37–39, outsider test with 3–5 people. Mainnet go or no-go. | Outsider test passes (`docs/DEMO.md`). Mainnet only if all four mainnet conditions hold. | If cuts 1–6 are used and it's still late → cut 7. |
| **Submit** | Dec 2–4 | Video and risk page (Dec 3). Submit Dec 4. | All "never cut" items done. | Dec 5 is buffer only. |

## Demand gate outcomes

The interview question is the brief's three-option question: which would you trade — a free-floating `$CLOUD`, a settling `$CLOUD`, or a USDC market on Cloud's share? Each interview also records whether the payout is big enough to bother with.

The thresholds scale the design's 20-interview marks (pass at 8 of 20, change below 5 of 20) down to 10. Set them now and don't change them after the first interview.

| Outcome (first 10 interviews) | Action |
|---|---|
| **Settling `$CLOUD` wins:** chosen by at least 4 of 10. | Build as planned. Resolver work starts Nov 18. |
| **They like the settling version, but the bet is too small:** at least 4 of 10 choose settling `$CLOUD`, and most of them say the payout is too small to bother. | Build as planned, and reopen Alternative E (a bigger payout) as a decision for G1b. The design already names it as the answer to this result. |
| **Free-floating wins:** fewer than 3 of 10 choose settling `$CLOUD`, and free-floating is the top choice. | Following the design's below-5-of-20 rule, lead the pitch with the stock-backed split. Keep settlement as the feature that differs from Daybreak, and shrink the resolver to the minimum needed for the replay. |
| **USDC market wins:** fewer than 3 of 10 choose settling `$CLOUD`, and the USDC market is the top choice. | Stop and decide before writing any resolver code. Alternative D was rejected as a weak fit for a stock-token competition, so this result questions the entry itself, not just the pitch. |
| **In between:** 3 of 10 choose settling `$CLOUD`. | Proceed as planned, and mark the G4 tally as the deciding result. |

**Late reversal.** If the 10 early interviews pass but all 20 come in below 5 of 20 at G4, the contracts stay as they are and only the pitch changes: lead with the stock-backed split. There's no time to rebuild after G4.

**If fewer than 10 interviews are done by Nov 17:** run the gate on whatever is done, but no fewer than 6, using the same proportions. With fewer than 6, start resolver work anyway and record in this document that it rests on an untested demand guess.

## Never cut

From `concepts_brief.md`. These ship no matter what slips:

1. Mainnet fork test
2. Invariant tests
3. Dispute replay on testnet
4. Proof page
5. Never-settles fallback

## Cut order

This combines the brief's cut order with the review's additions. The brief also listed the USDC path, automated rollover and selling `$SERVICES` in one transaction, but the design already made those non-goals, so they aren't listed again.

| # | Cut | What stays | Triggered by |
|---|---|---|---|
| 1 | Mainnet path, including the timelock delay, deposit cap and bond-sizing rule | The testnet build. Mainnet becomes "decided at the mainnet gate" (Nit 1). | G1b or G2 slip |
| 2 | 90% coverage gate in CI | Every test and Slither still run in CI; only the coverage threshold goes. | G3 slip |
| 3 | Router extras: anything beyond `buyCloud`, `sellCloud` and `buyServices` | The three router paths and merge. | G3 slip |
| 4 | How-it-works page | Its content moves into the Trade page. | G4 slip |
| 5 | Interviews reduced from 20 to 10 | The 10 from the demand gate count as the final tally. | G4 interviews not done |
| 6 | Frontend polish and the Positions payout table | Positions still show balances and the current share. | G5 slip |
| 7 | Close hook and custom router (only if cuts 1–6 are used up) | The standard Uniswap router for `$CLOUD`. The team withdraws its liquidity at `tradingCloseAt`, and the app refuses trades once the series isn't Trading. | G6 slip |

Each cut is final for the competition. Major #4 was settled by keeping a slim hook, with no admin registration, and one custom router built on v4-periphery. Cut 7 is the fallback if that still slips.

## Open items

1. **Who runs the interviews, and can 10 be done by Nov 17?** The brief asked for 10–15 conversations in G0, so the target is the brief's own, but nobody is assigned yet.
2. **How "too small to bother" is recorded** in `docs/research/trader-interviews.md`, so the second demand outcome can be counted, not just felt.
