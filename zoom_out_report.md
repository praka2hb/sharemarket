# Stage 5: Initial Zoom Out Review

* **Target:** `docs/designs/cloud_share_market.md` (full file, lines 1–954)
* **Standard:** EGM Zoom Out Standard
* **Date:** 2026-11-14
* **Verdict:** needs revision. No Blockers, 6 Majors, 7 Nits.
* **Context check:** passes. The goal and the reason for it are clear. There is no README or code yet, so project fit was checked against `concepts_brief.md`, and reuse against outside libraries only.

## Majors

### 1. Demand is still tested after the build, and the design is frozen before the facts arrive

**Where:** gate table, lines 601–612; Open Questions, lines 88–90.

**Problem:**
* G0 (Nov 15–17) says to stop if demand fails, but interview results only arrive at G4 (Nov 23–25), after the contracts are built.
* G1 freezes the design on Nov 16, before G0 ends on Nov 17. So it freezes before anyone knows whether contracts can hold GOOGLc or whether GOOGLc is a precompile, and both can change the architecture.
* The low-demand outcome is vague ("the pitch changes"). The brief named a concrete pivot.

**Suggested change:**
* Freeze only after the fork check, or freeze only the parts that don't depend on it.
* Make a partial interview tally (about 10 interviews) a hard gate before contract work starts at G2.
* Write the concrete pivot for each outcome into the gate table.

### 2. The vault owns states it doesn't use, which splits one state machine across two contracts

**Where:** lines 232–247, 350, 633, 660–662.

**Problem:**
* The vault only needs to know three things: is the series Trading, is it Closed, is it Final.
* It also stores Created (never used), Proposed and Disputed, and the resolver gets a privileged `setState` call to move it between them.
* `createSeries` on the vault takes resolver settings (`firstFallbackPpm`, `bond`).

**Suggested change:**
* The vault keeps three states: Trading, Closed, Final.
* Proposed and Disputed live only in FilingResolver, and the resolver's only call into the vault is `finalize(id, ppm)`.
* Remove `setState` and Created.
* Configure resolver settings on the resolver.

### 3. "Previous quarter's final share" has no defined source, and the fallback depends on it

**Where:** lines 155, 273, 279, 350, 671.

**Problem:**
* The fallback and the 3-point sanity band both use the previous quarter's share.
* But `lastFinalPpm` is stored per series and seeded from a value passed at creation. Nothing says how quarter N reads quarter N−1's result, or what happens when the next quarter is created before the previous one settles.
* The fallback is on the "never cut" list.

**Suggested change:** pick one rule and write it into both the rule document and section 4. Preferred: fix each quarter's fallback share when the series is created, publish it in the rule document, and include it in `ruleHash`. Alternative: one stock-wide `lastFinalPpm`, updated on every finalize.

### 4. The close hook and a custom v4 router protect liquidity that is almost all the team's own

**Where:** lines 213, 218, 297–315, 684–698.

**Problem:**
* The hook exists to protect liquidity providers once results are known. On testnet the only liquidity provider is the team.
* Its cost:
  * mining the hook address;
  * a `registerPool` admin function and an initialize check;
  * a router built on the PoolManager callback;
  * token-order handling;
  * a test file.
* `buyCloud` and `sellCloud` are plain swaps that existing Uniswap routers already do.

**Suggested change:**
* Either keep the hook as a judge-facing feature ("trading provably closes") and say so, or replace it: the team withdraws its liquidity at `tradingCloseAt`, and the router and app refuse once the vault is not Trading.
* Either way, use the existing Uniswap router for `buyCloud` and `sellCloud`, and write custom code only for `buyServices`.
* Check in G0 whether those routers are deployed on Base Sepolia.

### 5. The "complete" admin list is not complete

**Where:** lines 346–356, 658, 685.

**Problem:**
* Section 8 says no other privileged functions exist.
* But `CloseHook.registerPool` is admin-only, the vault's resolver address is set once by someone, and the resolver's `setState` call is privileged.
* The README presents this list to judges as a trust claim.

**Suggested change:** list privileged functions from every contract, including one-time setup calls and when each locks. Majors 2 and 4 shrink the list.

### 6. The brief's "never cut" list and cut order were dropped

**Where:** lines 601–612; compare `concepts_brief.md`.

**Problem:**
* The plan covers:
  * 4 contracts plus mocks;
  * 4 scripts;
  * 7 test files;
  * CI with a 90% coverage gate and Slither;
  * a 6-page app;
  * 20 interviews;
  * a usability test;
  * an optional mainnet path.
* That is for two people in three weeks, with no agreed fallback when a gate slips.

**Suggested change:**
* Restore the "never cut" line: fork test, invariant tests, dispute replay, Proof page, fallback.
* Restore an ordered cut list:
  1. mainnet;
  2. the 90% coverage gate;
  3. How-it-works merged into Trade;
  4. the Positions payout table;
  5. interviews cut to 10.
* Tie each gate to what gets cut if it is missed.

## Nits

1. **Mainnet machinery in a testnet build** (lines 71–75, 287, 344–352, 555).
   * The 24-hour timelock, `setDepositCap`, the $25k cap and the bond-sizing rule are built for a mainnet that probably won't happen.
   * The bond-sizing rule also doesn't work: a wrong number can move the whole vault, and the bond is in USDC while deposits are in GOOGLc.
   * Fix: state that mainnet is out of scope for the competition, and replace the bond rule with "decided at the mainnet gate".
2. **`createSeries(stock, …)` takes a stock argument** (lines 350, 658), but each vault has one fixed collateral token, and more stocks are a non-goal. Fix: remove it.
3. **The two-step `$SERVICES` exit needs GOOGLc the user may not have** (lines 313, 870, CUJ 2). The CUJ 2 user got about 1.5 GOOGLc back and needs about that much plus fees and slippage to buy `$CLOUD` back. Fix: state the limit in CUJ 3 and on the Risks page, or bring back a one-step `sellServices`.
4. **The 0.30% fee is large next to a ±2–3% expected move** (lines 39, 296). Fix: justify it or use 0.05%, and include fees in the worked example.
5. **The Q4 fallback ("full year minus nine months") is only in Open Questions** (lines 93, 263–273). The rule's segment-change clause would settle differently. Fix: settle the question in G0 and write the answer into the rule.
6. **Goal 3 says "filing fields", but the rule reads printed table rows** (lines 58, 267–269). Fix: say "named table and row labels".
7. **There is no costs section and no glossary**, both of which the brief asked for. Fix: add short versions (seed amount, cost of leftover `$SERVICES`, gas, signers; ppm, series, piece, B20, multiplier).

## What works and should stay

* The custom vault, with clear reasons for rejecting the alternatives.
* One pool, with the router covering `$SERVICES`.
* A single ppm value.
* No indexer, and no upgradeable contracts.
* A fixed close time for each quarter.
* The failure-mode table and the issuer-permission table.
* Function-level detail placed in the Implementation Plan.
