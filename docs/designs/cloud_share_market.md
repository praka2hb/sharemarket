# Cloud Share Market: an earnings-mix market paid in Alphabet stock

> **Superseded in part (2026-11-15):** settlement was dropped. The pieces now trade forever with no quarters, resolver, close hook or payout. See `docs/decisions/0001-drop-settlement.md`, and `0002-three-pieces-and-nvda.md` for the current three-piece GOOGL and NVDA markets. Sections on series, settlement, the resolver, the hook, the fallback share and the replay describe the archived version in `archive/settlement-v1/`.

*   **Author:** Two-person team (Base "Stocks Maxxing" entry)
*   **Status:** Proposed
*   **Date:** 2026-11-14

--------------------------------------------------------------------------------

## Overview

Cloud Share Market lets someone take a view on how Alphabet's revenue will split between Google Cloud and the rest of Google in the coming quarter, without selling their Alphabet stock.

It works on Base, on top of Coinbase's tokenized Alphabet stock (GOOGLc):

1.  **Split:** 1 GOOGLc goes into a vault and comes out as two tokens.
    *   `$CLOUD` is the long side: it gains if Cloud's share of revenue beats what the market expected.
    *   `$SERVICES` is the short side: "Alphabet minus Cloud".
2.  **Trade:** people buy and sell `$CLOUD` in one pool priced in GOOGLc. The pool price is the market's forecast of Cloud's revenue share. If `$CLOUD` costs 0.270 GOOGLc, the market expects Cloud at 27.0%.
3.  **Merge:** 1 `$CLOUD` + 1 `$SERVICES` always gives back 1 GOOGLc.
4.  **Settle:** after Alphabet files its quarterly results with the SEC, the share is posted onchain, can be challenged for a fixed window, and then becomes final.
    *   1 `$CLOUD` then redeems for (Cloud's share) × 1 GOOGLc.
    *   1 `$SERVICES` redeems for the rest.

For this competition the product is a public testnet demo with mock tokens, a replay of a real Alphabet filing, and a test against the real GOOGLc token on a copy of Base mainnet.

## The Problem

**What users cannot do today.** Someone holding tokenized Alphabet on Base who thinks "Cloud will keep taking a bigger share of Google's business" has three options, all poor:

*   **Do nothing.** Their view has no effect on their position.
*   **Sell Alphabet and use a dollar prediction market.** They lose their stock exposure, pay to exit and re-enter, and need an earnings market that exists for this exact question (most cover headline EPS, not segment mix).
*   **Buy a segment token from a split product such as Daybreak.** Daybreak's public page describes pieces that move on trading alone and redeem only as a full set. Nothing ties a piece's price to the segment's reported results, so the price reflects what other buyers think, not what Alphabet reports.

**What is new here.** Each piece settles on its own against the number Alphabet files with the SEC. The price between reports is a forecast of a real, checkable number, and the position stays in Alphabet stock throughout.

**What this is not**, stated so nobody is misled:

*   It is not "owning Google Cloud". `$CLOUD` pays Cloud's **share** of revenue, not Cloud's growth or value. If both segments grow at the same rate, the payout does not change.
*   It is a bet on how fast the mix shifts, and the shift can be large or small.
    *   In 2025, Cloud's share rose only about 0.5–0.7 points a quarter.
    *   In 2026 it rose 2.5–3.4 points a quarter: 18.26%, then 20.76%, then 24.18% (`docs/data/googl-cloud-share-history.csv`).
    *   A 2-point surprise moves `$CLOUD` by roughly 8–10% against GOOGL.
    *   Cloud now includes sales of TPU systems, which are lumpier than subscriptions, so the share can also move less, or backwards.
*   It is an expiring market. Each quarter's tokens settle and a new quarter's tokens start.

**Worked example (real Alphabet numbers).** After Q2 2026 settled at 20.76%, suppose the market priced Q3 at the same share:
*   You pay 0.2076 GOOGLc for 1 `$CLOUD`.
*   Alphabet reports Cloud at 24.18% for Q3. 1 `$CLOUD` redeems for 0.2418 GOOGLc, **about +16.5% against simply holding GOOGL**, before pool fees.
*   Whatever Alphabet's stock did that quarter applies on top, because you are paid in GOOGLc.
*   Had Cloud come in at 18.7% instead, the same token would have redeemed for about 10% less than you paid, measured in GOOGLc.
*   Rough rule: return in GOOGLc ≈ reported share ÷ share you paid for − 1.

**Why it matters for Base.** Base's stock-token program wants uses of tokenized stocks beyond holding and swapping. This uses the stock as collateral for a market that only makes sense onchain: settlement from a public filing, open challenge, and a vault anyone can check.

**Risks the product depends on:**

*   **Demand:** no trader has yet been asked whether they want this.
*   **Issuer control:** Coinbase can pause GOOGLc or block any contract from holding it. If it does, the whole product stops, and the team cannot override that.
*   **Resolver trust:** for the demo, the people posting and judging the share include the team. That makes it a trusted process with a public audit trail, not a trustless one, and the app says so.

## Goals

1.  **Usable demo.** On Base Sepolia, a person with no help can:
    *   get mock GOOGLc and USDC from a faucet;
    *   split, buy or sell `$CLOUD`, get `$SERVICES`, and merge;
    *   redeem each piece on its own after settlement;
    *   do all of this within 5 minutes.
2.  **Clear in 2 minutes.** A judge can say what `$CLOUD` pays, and how it differs from Daybreak and from a prediction market, after a 2-minute walkthrough. Tested with 3–5 people outside the team before December 1.
3.  **A rule anyone can check.** A written settlement rule names the exact filing fields used for Cloud and for the rest. Applied to Alphabet's last four quarters, including a Q4, it gives the same numbers as a hand calculation.
4.  **Settlement end to end.** On testnet:
    *   a correct share is proposed, survives the challenge window and is paid out;
    *   a wrong proposal is challenged and loses its bond;
    *   a quarter with no settlement can still be closed out after a fixed deadline, using a fallback rule written in advance.
5.  **The vault always covers what it owes.**
    *   Automated tests run thousands of random actions, including a change in the stock token's multiplier, and the property holds after every one.
    *   A public Proof page shows the same check live from onchain data.
6.  **Works with the real token.** A test on a copy of Base mainnet uses the real GOOGLc. It covers deposit, split, merge, settle and redeem, and checks that every contract holding GOOGLc is allowed to.
7.  **Honest framing everywhere.** Pitch, app and docs use one sentence: "an earnings-mix market paid in the stock", plus one worked dollar example. Risks are stated on a dedicated page.

## Non-Goals

*   **Mainnet launch or real seed money by default.** Allowed only after December 1, and only if every one of these holds:
    *   the fork test passes;
    *   a lawyer gives written no-objection;
    *   the team is confirmed eligible to hold stock tokens;
    *   the trader interviews meet their bar.
*   **A live settlement before the deadline.** Alphabet's next report is about February 2027. The Nvidia testnet series (report November 17) is dropped: it needs a deployed, tested vault and resolver within two days.
*   **More stocks, or more than two pieces per stock.**
*   **Rolling tokens that never expire, or more than one quarter trading at once** (except the brief overlap when the next quarter opens).
*   **A trustless resolver.** No UMA integration and no escalation game in this version. UMA is a roadmap item.
*   **Payouts larger than the real share** (leverage, growth ranges, operating-income share). These are revisited only if interviews show the bet is too small to interest anyone.
*   **USDC entry, a route through Aerodrome, and liquidity range tuning.**
*   **A pause that reopens the same pool.** Each quarter's pool closes once, for good.
*   **Any promise about prices between reports.**
*   **An own token, points, a trading terminal, an audit, or US users.**

## Open Questions

*   **Is there demand?** Will at least 8 of 20 traders choose a settling `$CLOUD` over a free-floating one or a dollar market? Below 5 of 20, the pitch changes.
*   **Which track?** Does the competition accept this under Track 3 ("Programmable Stock Markets")?
*   **Does a multiplier change leave balances alone?** The B20 design keeps the multiplier separate from balances, and the fork test shows balances and the multiplier move independently. But only the issuer can change the multiplier, so a change mid-test was not possible. The mock token's invariant tests cover it.
*   **Will the trend continue?** The pool range and the sanity band are sized for 2026's pace of about 3 points a quarter. If Cloud's share stalls or reverses (for example a quarter with few TPU sales), the range can be off-centre. The band still allows it.
*   **Resolved in G0** (details in `docs/research/g0_findings.md`):
    *   Contracts can hold GOOGLc: policy 5 is a blocklist, and the vault, PoolManager and router are allowed.
    *   GOOGLc is a precompile with 8 decimals, and its fork test passes under `base-forge`.
    *   Q4 is reported on its own in the Q4 release.
    *   Uniswap v4 is live on Base Sepolia and Base mainnet.
    *   The share history covers 9 quarters (`docs/data/googl-cloud-share-history.csv`). Still missing: 2024 Q1–Q3, two accession numbers, and the exhibit file hashes.

## Critical User Journeys (CUJs)

### CUJ 1: Take a view that Cloud will beat expectations

*   **Given**:
    *   A user on Base Sepolia holds mock GOOGLc from the faucet.
    *   The current quarter's market is open.
    *   The app shows "Market expects Cloud share: 27.0%".
*   **When**: The user enters 2 GOOGLc and presses "Buy $CLOUD".
*   **Then**:
    *   One transaction swaps 2 GOOGLc for about 7.4 `$CLOUD` (the exact amount shown before signing, with a minimum the user accepts).
    *   The headline number rises slightly.
    *   The user's position page shows what the tokens pay at different reported shares.

### CUJ 2: Take the other side without leaving Alphabet

*   **Given**: A user holds 10 GOOGLc and thinks Cloud will disappoint.
*   **When**: The user presses "Buy $SERVICES" with 10 GOOGLc.
*   **Then**:
    *   In one transaction the router:
        1.  splits 10 GOOGLc into 10 `$CLOUD` and 10 `$SERVICES`;
        2.  sells the 10 `$CLOUD` into the pool;
        3.  returns 10 `$SERVICES` plus the GOOGLc the sale raised (about 2.7 at a 27% price, less fees and price impact).
    *   The user now holds "Alphabet minus Cloud".

### CUJ 3: Exit before results

*   **Given**: A user holds 10 `$CLOUD` and 10 `$SERVICES`.
*   **When**: The user presses "Merge".
*   **Then**: They receive 10 GOOGLc. Merge works at every stage of the quarter, including while trading is closed and after settlement.

### CUJ 4: Settlement with a wrong proposal (the demo replay)

*   **Given**:
    *   The replay quarter's trading has closed.
    *   Alphabet's real Q3 2026 earnings release is on SEC EDGAR.
*   **When**:
    1.  A proposer posts wrong revenue figures with a bond.
    2.  A challenger posts the correct figures, with a link to the filing and an equal bond.
    3.  The arbiter picks the challenger.
*   **Then**:
    *   The challenger's figures become final and the challenger takes the proposer's bond.
    *   The Cloud share is fixed at 241,782 parts per million (24.18%): Cloud $30,709M ÷ (Cloud $30,709M + Services $96,302M).
    *   Every step appears on the Settlement page with the filing link, accession number, and file hash.

### CUJ 5: Redeem one piece on its own

*   **Given**: The replay quarter has settled at Cloud share 24.1782%, and a user holds 10 `$CLOUD` and no `$SERVICES`.
*   **When**: The user presses "Redeem".
*   **Then**:
    *   They receive 2.41782000 GOOGLc (floor of 10 × 241,782 ÷ 1,000,000, in GOOGLc's 8-decimal units).
    *   The tokens are burned.
    *   The Proof page still shows the vault holding at least everything it owes.

### CUJ 6: A quarter never settles

*   **Given**: Trading closed, and no proposal became final before the fallback deadline (45 days on mainnet, 1 hour on testnet).
*   **When**: Anyone calls "Finalize with fallback".
*   **Then**:
    *   The quarter settles at its fallback share, which was fixed when the series was created and is published in its rule document.
    *   Every holder can redeem. Nobody's tokens are stuck.

### CUJ 7: Judge checks that the money is there

*   **Given**: A judge opens the Proof page.
*   **When**: The page loads.
*   **Then**: For each quarter, it reads from the chain and shows:
    *   GOOGLc held for that quarter;
    *   supply of each piece;
    *   the amount owed;
    *   a pass or fail line;
    *   contract addresses linked to the block explorer.

    No number on the page is typed in by the team.

## Technical Plan (Architecture)

### 1. Components

```text
                     ┌──────────────────────────────────────┐
  Alphabet 8-K  ───► │ Proposer / Challenger (anyone, bond)  │
  (SEC EDGAR)        └──────────────────┬───────────────────┘
                                        │ figures + accession + hash
                                        ▼
                           ┌──────────────────────┐   arbiter decides
                           │  FilingResolver       │◄── (2-of-3 Safe,
                           │  bonds, windows,      │     1 outside signer)
                           │  sanity band, fallback│
                           └──────────┬───────────┘
                                      │ finalize(series, cloudPpm)
                                      ▼
 user ─ split/merge/redeem ─► ┌──────────────────────┐ ◄─ holds ─ GOOGLc (B20)
                              │  SegmentVault         │
                              │  per-quarter series   │── mints/burns ─► $CLOUD-xxQx
                              └──────────▲───────────┘                  $SVCS-xxQx
                                         │ split / merge                 (ERC-20s)
 user ─ buy/sell ─► ┌──────────────────┐ │
                    │  SegmentRouter    │─┘
                    └────────┬─────────┘
                             │ swaps
                             ▼
                    ┌──────────────────────────┐
                    │ Uniswap v4 pool           │  $CLOUD / GOOGLc
                    │ + CloseHook (no swaps or  │  one pool per quarter
                    │   new liquidity after     │
                    │   tradingCloseAt)         │
                    └──────────────────────────┘

 Frontend (reads chain directly) ── Trade / Positions / Settlement / Proof / Risks
```

### 2. Decisions made in this section

| Decision | Choice | Main reason |
|---|---|---|
| Vault | Custom Solidity 0.8 vault, about 200 lines | No old-compiler toolchain, no ERC-1155 wrapping, plain ERC-20 pieces, simpler tests. UMA's Long Short Pair is a fallback only if confirmed on both Base networks. |
| Market venue | Uniswap v4, one `$CLOUD`/GOOGLc pool per quarter, with a hook | v4 has hooks and is on Base Sepolia (to verify). Aerodrome Slipstream has no hooks. |
| `$SERVICES` trading | No pool of its own; router splits or merges around the `$CLOUD` pool | One pool, one price, half the liquidity cost. |
| Settlement source | Earnings release filed as an 8-K (Exhibit 99.1) on SEC EDGAR | Available the day of results, covers Q4, and is still an SEC filing. The 10-Q is used only as a reference in disputes. |
| Settlement value | One number: Cloud share in parts per million (ppm) | Two weights that must sum to 100% cannot drift apart. |
| Resolver | Custom bonded resolver with a named arbiter | UMA adds integration time and may be missing on testnet. The trust model is stated openly. |
| Trading close | A fixed `tradingCloseAt` per quarter. A guardian can close early, never reopen. | Stops trading against liquidity providers once results are known, with no keeper and no reopen gap. |
| Bonds | USDC | Keeps the issuer's stock-token transfer rules out of the dispute process. |
| Data for the app | Read contract state and events over RPC. No indexer. | Few contracts, low volume, less to build. |

### 3. SegmentVault

**Per quarter ("series") it stores:**

*   `cloudToken`, `servicesToken`: two ERC-20s deployed at series creation. Their decimals equal GOOGLc's (8). Names follow `CLOUD-GOOGL-26Q4` and `SVCS-GOOGL-26Q4`.
*   `collateral`: GOOGLc units held for this series. GOOGLc is counted in token units only, never converted to shares.
*   `tradingCloseAt`, `state`, `cloudPpm` (set at finalization), `ruleHash` (hash of the written settlement-rule document, fixed at creation).

**Lifecycle.** The vault tracks only the three states its own actions depend on:

```text
Trading ─(tradingCloseAt passes, or guardian close)─► Closed ─(FilingResolver calls finalize)─► Final
```

*   A series is created directly in Trading.
*   Proposals and disputes are the resolver's business and live only in FilingResolver (section 4). While they run, the vault just sees Closed.

**Actions:**

| Action | Allowed in | Effect |
|---|---|---|
| `split(series, amount)` | Trading, Closed | Take `amount` GOOGLc, mint `amount` of each piece |
| `merge(series, amount, to)` | Every state | Burn `amount` of each piece, send `amount` GOOGLc to `to` |
| `redeem(series, cloudAmt, svcsAmt, to)` | Final | Burn the pieces, send floor(cloudAmt × ppm ÷ 1,000,000) + floor(svcsAmt × (1,000,000 − ppm) ÷ 1,000,000) GOOGLc to `to` |
| `finalize(series, ppm)` | Closed; callable only by FilingResolver | Sets `cloudPpm` and state Final. This is the resolver's only call into the vault. |

**Design notes:**

*   `to` lets a holder whose own address is blocked by the issuer exit to an allowed address.
*   There is no function that moves GOOGLc out of the vault other than merge and redeem. There is no admin withdrawal and no pause in the team's code.
*   Split is disabled after Final, because new pieces would have a known value.

**Properties the tests must hold after every action:**

*   Before Final: `collateral == cloud supply == services supply`.
*   After Final: `collateral ≥ (cloud supply × ppm + services supply × (1,000,000 − ppm)) ÷ 1,000,000`. Rounding dust stays in the vault.
*   The vault's GOOGLc balance is at least the sum of all series' `collateral`.

### 4. Settlement rule and FilingResolver

**The written rule.** One document per stock, hashed into each series. It contains:

*   **Source:** Alphabet's quarterly earnings release, filed on SEC EDGAR as Exhibit 99.1 to a Form 8-K.
*   **Figures:**
    *   **Cloud** = the "Google Cloud" segment revenue row for the three months of the quarter.
    *   **Services** = the "Google Services" segment revenue row for the same three months.
    *   Other Bets, hedging gains or losses, and Alphabet-level items are excluded. Figures are as printed, in USD millions.
    *   **Q4** uses the fourth-quarter release's "Quarter Ended December 31" columns. These show Q4 alone, as checked on the Q4 2024 and Q4 2025 releases.
    *   **Cloud includes everything Alphabet reports under Google Cloud,** including product revenue from TPU system sales.
*   **Share:** `cloudPpm = floor(Cloud × 1,000,000 ÷ (Cloud + Services))`.
*   **Restatements:** the first filing for the quarter wins. Later amendments and recast figures are ignored.
*   **Fallback share:** each quarter has its own fallback share, fixed when the series is created and never changed.
    *   It equals the most recent final share known at creation time. Because the next quarter opens when the previous one closes, that is usually the share from two quarters back, since the previous quarter has not settled yet.
    *   It is written into the rule document for that quarter, so it is covered by `ruleHash` and anyone can see it before trading.
    *   The first series takes it from the share history (`docs/data/googl-cloud-share-history.csv`).
    *   While the share is trending, the fallback lags reality. At 2026's pace it could sit about 6 points below the true share. The fallback is meant to be rare, and the rule document says this plainly.
*   **Segment changes:** if Alphabet stops reporting either row in this form, the quarter settles at its fallback share.
*   **Fallback deadline:** 45 days after `tradingCloseAt` (1 hour on testnet). After that, anyone can finalize at the quarter's fallback share.

**Proposing and challenging:**

| Step | Who | Input | Rule |
|---|---|---|---|
| Propose | Anyone, once the vault reports Closed | Cloud and Services revenue, EDGAR accession number, SHA-256 hash of the exhibit file, bond | The contract computes `cloudPpm`. If it differs from the quarter's fallback share by more than 100,000 ppm (10 points), the proposal goes straight to Disputed. The fallback can be two quarters old, and the largest honest two-quarter move so far is 5.9 points (Q1 to Q3 2026). |
| Challenge | Anyone, within the dispute window | Different figures, plus an equal bond | One challenge per proposal |
| Decide | Arbiter only | Pick proposer, challenger, or reject | Proposer or challenger: those figures become final and the winner takes the other's bond. Reject: every bond posted on this proposal is burned and the resolver goes back to Open for a new proposal. |
| No challenge | Anyone, after the window | — | Proposal becomes Final; the bond is returned |

**Resolver states.** FilingResolver keeps its own state for each series. The vault never sees these.

```text
Open ─(propose)─► Proposed ─(window ends, no challenge)─► Done
Proposed ─(challenge, or outside sanity band)─► Disputed ─(arbiter picks a side)─► Done
Disputed ─(arbiter rejects)─► Open
Open / Proposed / Disputed ─(fallback deadline passes)─► Done (fallback share)
```

*   Proposing requires the vault to report the series as Closed.
*   Every path to Done makes exactly one call, `vault.finalize(series, ppm)`.

**Per-series settings live on the resolver.** The admin sets them once with `configureSeries(series, fallbackPpm, bond)`, in the same Safe transaction as `vault.createSeries`, and they cannot change afterwards. Proposing reverts for a series that has no settings. Even then, merge still works, so no tokens are stuck as long as both pieces are held.

**Parameters:**

*   **Dispute window:** 15 minutes on testnet, 72 hours on mainnet.
*   **Bond:** 1,000 mock USDC on testnet. On mainnet it must be at least the most a wrong number could move: cap total deposits to match.
*   **Arbiter:** a 2-of-3 Safe with at least one signer outside the team. The app labels it "trusted arbiter".

**Events:** `Proposed`, `Challenged`, `Decided`, `Rejected`, `Finalized`, `FallbackFinalized`. Each carries the series, figures, ppm, accession number and hash, so the app and anyone else can rebuild the history.

### 5. Market: pool, hook and router

**Pool:**

*   One Uniswap v4 pool per series: `$CLOUD` against GOOGLc, 0.30% fee.
*   The team seeds it with concentrated liquidity centred on the expected share and spanning ±5 points around it, plus a small backstop position from 10% to 45%. If the price leaves the main range, the backstop still provides some liquidity.
    *   **Expected share** = the last settled share plus the recent trend for each quarter in between. The trend is 3 points a quarter at 2026's pace.
    *   **Example:** the `26Q4` series opens after Q3 settled at 24.18%, so its main range is about 22.2%–32.2%, centred on 27.2%.

**CloseHook:**

*   Blocks swaps and adding liquidity once the series is no longer Trading, with the error "closed for settlement".
*   Never blocks removing liquidity.
*   Finds its series from the pool's tokens: it asks the vault which series the pool's `$CLOUD` token belongs to (`vault.seriesOfToken`). No admin registration is needed.
*   Refuses to initialize any pool that doesn't pair a known `$CLOUD` token with GOOGLc.
*   The hook's permissions are fixed in its address, which is mined with HookMiner at deploy time.

**Why keep the hook on testnet,** where the team is the only liquidity provider:

*   It is the judge-facing proof that trading in this market closes for settlement by itself, with nobody having to act at the right moment. That is the programmable-market feature Track 3 is about.
*   On mainnet it protects outside liquidity providers the same way.
*   Its limit is stated openly: it covers only pools that use it. Pools opened elsewhere without it are not closed (see "Known gap" below and the Risks page).

**SegmentRouter** (every function takes a minimum-out amount and a deadline):

| Function | What happens |
|---|---|
| `buyCloud(series, googlIn, minCloudOut)` | Swap GOOGLc for `$CLOUD` |
| `sellCloud(series, cloudIn, minGooglOut)` | Swap `$CLOUD` for GOOGLc |
| `buyServices(series, googlIn, minGooglBack)` | Split `googlIn`, sell all the `$CLOUD`, return `googlIn` of `$SERVICES` plus the GOOGLc raised |

To exit a `$SERVICES` position, the app sends two transactions: `buyCloud` for the same amount, then `merge`.

The router holds tokens only within a single transaction.

**Why one custom router for all three paths.** `buyServices` must split and sell in one transaction, so a custom v4 swapping contract is needed anyway. Adding `buyCloud` and `sellCloud` to it costs little. Using Uniswap's Universal Router for those two instead would move the work to the frontend (Permit2 approvals, command encoding, a second quoting path). The router is built on v4-periphery's swap helpers rather than a hand-written callback. If the router slips, the Universal Router on Base Sepolia (checked in G0) is the fallback for `buyCloud` and `sellCloud`.

**Known gap:** anyone can create another pool for these ERC-20s without the close hook. The router only uses the team's pool, and the Risks page says so.

### 6. Who must be allowed to hold GOOGLc

| Contract | Holds GOOGLc? | If blocked by the issuer |
|---|---|---|
| SegmentVault | Yes, all collateral | Product cannot work on that token. Demo runs on mocks only. |
| Uniswap v4 PoolManager | Yes, pool balances. Shared by all v4 pools. | No trading; split, merge and redeem still work |
| SegmentRouter | Only within a transaction | Router paths fail; direct pool and vault calls still work |
| FilingResolver | No (bonds are USDC) | Not affected |
| User addresses | Yes | User exits with `to` set to an allowed address |

The fork test checks `isAuthorized` for each of these against the real GOOGLc policy.

### 7. Failure modes

| Event | What happens | What the user sees |
|---|---|---|
| Issuer pauses GOOGLc | Every transfer of GOOGLc fails, so split, merge, redeem and trading all stop | Banner: "GOOGL token paused by its issuer" |
| Issuer blocks the vault | As above, permanently for that token | Same banner, plus Risks page entry |
| Multiplier changes (dividend or split) | Balances are counted in units, so all claims stay proportional. The USD value per unit changes for everyone equally. | Note on the Positions page. |
| No filing, or the arbiter does nothing | Fallback finalize after 45 days | Countdown on the Settlement page |
| Restatement after Final | Ignored, by the rule | Rule text linked from the Settlement page |
| Segment reorganisation | Settles at the quarter's fallback share | Same |
| Wrong proposal | Challenge, arbiter decides, wrong party loses its bond | Full history on the Settlement page |
| Price leaves the main liquidity range | Backstop position trades at worse prices | Price impact shown before signing |
| Trading elsewhere after close | Not prevented | Risks page entry |
| Bug in vault | Limited by a deposit cap on mainnet. No admin can move funds. | Risks page: unaudited |

### 8. Admin surface (complete list)

Every function that only some address can call, across every contract. "Admin" means the 2-of-3 Safe acting through a TimelockController (24-hour delay on mainnet, none on testnet).

**Roles and who holds them:**

| Role | Holder | Can it change? |
|---|---|---|
| Admin | TimelockController, with the Safe as its only proposer and executor | No. The vault and resolver store it as a fixed value at deploy. The timelock is deployed with no separate admin, so its roles change only through its own delayed process. |
| Guardian | A team address | No. It's fixed at deploy. Losing it only removes the ability to close early. |
| Arbiter | A 2-of-3 Safe with at least one signer outside the team | Yes, through `setArbiter`, but never for a proposal already made (see below). |
| Deployer | The deploy key | Only for `setResolver`, which locks after one call. |

**Privileged functions:**

| Contract | Function | Who | What it can do | When it locks |
|---|---|---|---|---|
| SegmentVault | `setResolver(address)` | Deployer | Sets the only address that can call `finalize`. | After its single call, made in the deploy script before any series exists. |
| SegmentVault | `createSeries(label, tradingCloseAt, ruleHash)` | Admin | Opens a new quarter. It can't touch existing series. | Never; it's needed every quarter. |
| SegmentVault | `setDepositCap(series, amount)` | Admin | Limits new splits in a series. It can't block merge or redeem. Mainnet only (cut 1). | Never. |
| SegmentVault | `closeEarly(series)` | Guardian | Moves a series from Trading to Closed. It can't reopen. | Per series, once it is Closed. |
| SegmentVault | `finalize(series, ppm)` | FilingResolver contract | Sets the final share, only from Closed. | Per series, once it is Final. |
| FilingResolver | `configureSeries(series, fallbackPpm, bond)` | Admin | Sets a series' fallback share and bond. | Per series, after its single call. |
| FilingResolver | `setArbiter(address)` | Admin | Changes who decides future disputes. | Never. Each proposal keeps the arbiter in place when it was made, so a change can't reach a live dispute. |
| FilingResolver | `decide(series, choice)` | Arbiter | Picks the proposer, the challenger, or rejects. It can't choose a share neither side posted. | Per series, once it is Done. |
| PieceToken | `mint`, `burn` | SegmentVault contract | Only as part of split, merge and redeem. | Never. |

**No privileged functions:** CloseHook and SegmentRouter. Their settings are fixed at deploy.

**Fixed at deploy, with no setter:** the dispute window, the fallback delay, the sanity band, the bond token, the collateral token, the admin and the guardian.

**Testnet mocks only** (never deployed on mainnet): MockB20's owner can change the multiplier, pause and unpause, and edit the blocklist. The Faucet has no admin.

No other privileged functions exist. The fork test and unit tests check access control on every function in this table.

### 9. Testnet setup

*   **MockB20 GOOGLc:**
    *   **Multiplier:** changeable by the team, which only changes the displayed share equivalence.
    *   **Pause:** pause and unpause.
    *   **Blocklist policy:** answers `isAuthorized`.
*   **MockUSDC.**
*   **Faucet:** 20 mock GOOGLc and 2,000 mock USDC per address per day.
*   **No dollar values:** the app shows every amount in GOOGLc, so no price feed is needed on testnet.
*   **Two series:**
    *   `26Q3` (replay): created, traded briefly, closed, settled on Alphabet's real Q3 2026 release, including the challenged wrong proposal.
    *   `26Q4` (live): open for trading through judging. It will settle on Alphabet's Q4 2026 release (about February 2027).

### 10. Frontend

**Pages:**

*   **Trade:** headline share, buy and sell `$CLOUD`, buy `$SERVICES`, split and merge.
*   **Positions:** holdings, plus a payout table at several possible shares.
*   **Settlement:** state, countdowns, proposals, challenges, filing links and hashes.
*   **Proof:** the live checks in CUJ 7.
*   **Risks.**
*   **How it works:** the worked dollar example.

**Implementation:**

*   **Frontend stack:** Next.js with viem and wagmi, reading contracts directly.
*   **Checking proposals:** for the demo, the team checks each proposal's figures and file hash by hand against the filing. An automated watcher is a future improvement.

## Alternatives Considered

### Product direction

#### Alternative A: Stock-paired meme launchpad with price protection

Memes trade against a stock token. A Uniswap v4 hook raises fees and caps stock holdings when the stock token's price drifts from its real price, and a vault gives each meme a stock-backed floor.

*   **Pros**:
    *   Uses the team's launchpad experience.
    *   Addresses a real event: the HIMS weekend squeeze on Robinhood Chain, August 2026.
*   **Cons**:
    *   The protection sits in the wrong pool: the squeeze happens in the stock token's own markets.
    *   The floor vault locks up more stock exactly when none can be minted.
    *   Needs a manipulable second price.
    *   Launchers want squeezes, not caps.
*   **Reason for Rejection**: An earlier six-reviewer review found two parts designed the wrong way round, and the whole thing too large for two people (`concepts_brief_launchpad.md`).

#### Alternative B: Memes quoted in USDC with a stock treasury and holder redemption

*   **Pros**:
    *   Cannot cause a weekend squeeze.
    *   Matches Base's idea 1.2.
    *   Uses launchpad experience.
*   **Cons**:
    *   Every piece already exists:
        *   stock-paired launches (BaseStonk, Feel.cash, o1, Stonks Exchange);
        *   building up stock through trading (LONG.xyz);
        *   fee-to-stock redemption (Bankr index-paired launches);
        *   floors (Baseline).
    *   Partners with more money and users could add the rest within weeks.
*   **Reason for Rejection**: It isn't new, and a two-person team can't win on distribution against the partner launchpads.

#### Alternative C: Free-floating segment pieces (Daybreak's model)

The same split and merge, with no settlement. Prices move on trading alone.

*   **Pros**:
    *   Simplest build: the vault and two tokens.
    *   Unlimited, story-driven upside, which may suit meme traders better.
*   **Cons**:
    *   Nothing ties a piece's price to the segment's results.
    *   One whale can push a piece to near zero and keep it there.
    *   Indistinguishable from Daybreak.
*   **Reason for Rejection**: It removes the only difference from Daybreak. It's kept only as a comparison option in the trader interviews.

#### Alternative D: Dollar (USDC) market on Cloud's revenue share

The same bet, with collateral in USDC instead of GOOGLc.

*   **Pros**:
    *   No issuer pause or transfer-policy risk.
    *   Familiar to prediction-market users.
*   **Cons**:
    *   The user leaves Alphabet exposure.
    *   It's a weak fit for a tokenized-stock competition.
    *   Competes directly with Polymarket and Kalshi.
*   **Reason for Rejection**: Being paid in the stock is the product's reason to exist on Base. It's kept as the third option in the trader interviews.

#### Alternative E: A bigger payout (leveraged share, growth range, or operating-income share)

*   **Pros**: Settlement moves would be large enough to interest traders. A ±0.3-point surprise at 10× leverage becomes about ±20%.
*   **Cons**:
    *   Clearly a leveraged derivative, with more legal exposure.
    *   Operating income can be negative and is affected by Alphabet-level cost allocations.
    *   More rules to dispute.
*   **Reason for Rejection**: Deferred, not rejected. It's revisited only if interviews show the plain share is too small to matter.

#### Alternative F: A filing-linked segment-data oracle for other protocols

Sell the resolver itself, as infrastructure, to Daybreak and others.

*   **Pros**: New, and possibly the most reusable part.
*   **Cons**:
    *   No users of its own.
    *   An earlier review flagged infrastructure pitches as weak for this competition.
*   **Reason for Rejection**: It's a later business option, not a competition entry. The resolver is built as a separate contract so this path stays open.

### Technical choices

#### Alternative G: Gnosis Conditional Tokens as the vault

*   **Pros**:
    *   Audited and used in production by Polymarket.
    *   A strong trust story.
*   **Cons**:
    *   Old Solidity (0.5).
    *   ERC-1155 positions need wrapping to ERC-20 for pools and wallets.
    *   Redeem burns a holder's whole balance.
    *   Only the oracle address fixed at creation can report, and only once.
    *   No canonical deployment on Base confirmed.
*   **Reason for Rejection**: The integration work (wrapper, receiver hooks, a separate toolchain) costs more than writing and testing a 200-line vault. Once wrapped, "Polymarket's contracts" is only partly true anyway.

#### Alternative H: UMA Long Short Pair as the vault, with UMA's Optimistic Oracle as the resolver

*   **Pros**:
    *   Audited.
    *   Plain ERC-20 long and short tokens.
    *   A real external dispute process.
*   **Cons**:
    *   Deployment on Base Sepolia is unconfirmed.
    *   Disputes on testnet would be mocked or slow.
    *   Its question format needs adapting to a numeric share.
*   **Reason for Rejection**: It's the fallback if both networks are confirmed during the first gate. Otherwise UMA is a roadmap item for a trustless resolver.

#### Alternative I: One single-asset prediction-market pool (Fixed Product Market Maker)

*   **Pros**: LPs supply only GOOGLc.
*   **Cons**:
    *   It spreads liquidity from 0% to 100%.
    *   At an 85/15 split, a trade of 10% of the seed doubled the `$CLOUD` price.
*   **Reason for Rejection**: Calculated price impact. A concentrated pool moved about 10% on a trade of 20% of the seed.

#### Alternative J: Two USDC pools, one per piece

*   **Pros**: Users pay in dollars directly.
*   **Cons**:
    *   Doubles the liquidity needed, and half of it must be USDC.
    *   Two prices that arbitrage has to keep in line.
*   **Reason for Rejection**: Cost and complexity. One `$CLOUD`/GOOGLc pool plus a router covers both pieces.

#### Alternative K: Settle on the 10-Q (and the 10-K for Q4)

*   **Pros**: Formal, reviewed filings with tagged segment data.
*   **Cons**:
    *   There's no Q4 10-Q. The 10-K may not show Q4 alone.
    *   Filing comes days after results, so holders stay locked longer.
*   **Reason for Rejection**: The 8-K earnings release is same-day, covers every quarter, and is still an SEC filing. The 10-Q remains the reference for disputes.

#### Alternative L: Rolling tokens that never expire

*   **Pros**:
    *   Matches the word "own".
    *   No rollover, and one pool for good.
*   **Cons**:
    *   A one-time-settle vault can't express it; it needs redemption windows and a reopening market.
    *   Reopening a pool after results lets the first trader take the gap from LPs.
*   **Reason for Rejection**: Quarterly series are simpler and honest about being an expiring market. Rolling is a future improvement.

#### Alternative M: Pause the pool at results and reopen it after settlement

*   **Pros**: One pool across quarters.
*   **Cons**:
    *   The first trader after reopening takes the price gap from LPs.
    *   Needs a keeper to trigger it.
*   **Reason for Rejection**: Replaced by a fixed close time per quarter, with a new pool for the next quarter.

#### Alternative N: A live Nvidia testnet series settled on the November 17 report

*   **Pros**: A real, live settlement before judging, which is stronger than a replay.
*   **Cons**:
    *   Needs a deployed, tested vault and resolver within two days of this draft.
    *   Nvidia's mix is even more lopsided: Data Center is about 90% of revenue.
*   **Reason for Rejection**: Not enough time to ship it without skipping tests.

--------------------------------------------------------------------------------

## Non-Functional Requirements

*   **Security**
    *   No function can move GOOGLc out of the vault except merge and redeem.
    *   State-changing functions follow checks, then state updates, then transfers, and are guarded against re-entry.
    *   Token transfers use safe-transfer helpers.
    *   Admin calls go through a 2-of-3 Safe and a timelock.
    *   The guardian can only close a series early.
    *   Private keys and RPC keys never enter the repository. CI uses secrets.
*   **Rollout**
    *   Testnet first.
    *   Mainnet only behind the December 1 gate (see Non-Goals), with a per-series deposit cap of $25,000 and the 24-hour timelock.
    *   Contracts are not upgradeable. A fix means deploying new contracts and opening a new series, while old series can still merge and redeem.
*   **Performance**
    *   Not a concern on Base: each action costs one transaction at normal gas.
    *   The frontend reads at most a few hundred events per series.

### Additional Resources

*   `concepts_brief.md`: the Goldfish review findings and the framing decision.
*   `segment_split_hypothesis.md`: the reviewed hypothesis.
*   `market_research.md`: stock-token facts and competitors.
*   `concepts_brief_launchpad.md`: the rejected launchpad concept.
*   Base documentation, "List Tokenized Stocks": stock-token behaviour and the token list.
*   Daybreak's launch page on Alliance: the competitor description.
*   `docs/research/g0_findings.md`: G0 facts on GOOGLc, Uniswap v4 addresses, Q4 reporting and the share history, with the fork-test result.
*   `docs/data/googl-cloud-share-history.csv`: Alphabet's Cloud and Services revenue by quarter, from the earnings releases.

### Future Improvements

*   **Trustless resolver**: replace the arbiter with UMA's Optimistic Oracle once it is confirmed on Base.
*   **Rolling markets**: one token across quarters, with redemption windows.
*   **More stocks**: Tesla (Auto vs Energy) and Amazon (Stores vs AWS) use the same contracts with a new rule document.
*   **Bigger payout variants** (Alternative E), if demand data supports them.
*   **USDC entry** through a route via Aerodrome.
*   **Watcher**: a script that checks each proposal against the filing on EDGAR and alerts on issuer pause, policy and multiplier changes. Needed before any mainnet launch.
*   **One-step `$SERVICES` exit** in the router, and USD values in the app.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

**Repository layout:**

*   One repository with `contracts/` (Foundry), `app/` (Next.js) and `docs/`.
*   Package manager: pnpm.

**Libraries:**

*   OpenZeppelin Contracts 5.x: ERC20, SafeERC20, ReentrancyGuard, TimelockController.
*   Uniswap `v4-core` and `v4-periphery`.
*   OpenZeppelin `uniswap-hooks` (BaseHook).
*   `forge-std`.

**Units:**

*   Shares are in ppm, 1,000,000 = 100%.
*   Piece tokens use the same decimals as GOOGLc: 8, confirmed in G0. The mock token also uses 8.

### Build order and gates

| Days | Work | Gate |
|---|---|---|
| Nov 15–17 | Fork check (file 20), share history (file 24), rule document (file 23), trader interviews (file 25), confirm v4 addresses | G0: stop or change direction if contracts cannot hold GOOGLc or demand fails |
| Nov 16 | Freeze this document | G1 |
| Nov 17–20 | Files 1–8 and unit tests 15–17 | G2: split, merge, redeem and resolver tests pass locally; rule reproduces four quarters |
| Nov 20–22 | Files 9–10, 18–19 | G3: full local end-to-end test passes |
| Nov 23–25 | Scripts 11–14, testnet deploy, frontend start | G4: first testnet deploy; interview results in |
| Nov 25–27 | Replay settlement on testnet, invariant and fork tests green | G5: contracts frozen |
| Nov 27 – Dec 1 | Frontend 27–36, docs 37–39 | G6: outsider test, mainnet go or no-go |
| Dec 2–4 | Video, submission | Dec 5 is buffer only |

### Target Files to Create/Modify

#### 1. `contracts/foundry.toml` (Create)

*   **Type / Scope**: Build configuration.
*   **Proposed Changes**:
    *   Solidity 0.8.26 with optimizer on and `evm_version = "cancun"` (needed for v4 transient storage).
    *   An `rpc_endpoints.base` entry that reads `BASE_RPC_URL`. The fork test pins its own block.
    *   **Toolchain:** run with Base's Foundry build, `base-forge` (installed with `base-foundryup`), which enables the B20 precompiles by default. The Homebrew `forge` is built without Base support, and every call to GOOGLc reverts under it. Stock Foundry 1.8.4 or later can work with `hardfork = "base:Cobalt"`, but only if it is built with the `base` feature.
    *   Already created during G0, with `forge-std`.
    *   An invariant setting of 256 runs and depth 100.

#### 2. `contracts/remappings.txt` (Create)

*   **Type / Scope**: Build configuration.
*   **Proposed Changes**: Import paths for OpenZeppelin, v4-core, v4-periphery, uniswap-hooks and forge-std, so every file imports by the same names.

#### 3. `contracts/src/libraries/SeriesTypes.sol` (Create)

*   **Type / Scope**: Shared types.
*   **Proposed Changes**:
    *   `enum State { Trading, Closed, Final }` (vault).
    *   `enum ResolverState { Open, Proposed, Disputed, Done }` (resolver).
    *   `struct Series { address cloud; address services; uint256 collateral; uint64 tradingCloseAt; uint32 cloudPpm; State state; bytes32 ruleHash; uint256 depositCap; }`.
    *   Constant `PPM = 1_000_000`.
    *   Shared custom errors: `WrongState`, `ZeroAmount`, `CapExceeded`, `NotVault`, `NotResolver`, `NotGuardian`.

#### 4. `contracts/src/interfaces/IB20.sol` (Create)

*   **Type / Scope**: Interface.
*   **Proposed Changes**:
    *   **On the token** (confirmed against real GOOGLc in G0):
        *   `balanceOf`, `transfer`, `transferFrom`, `approve`, `decimals` (8);
        *   `multiplier()` returning a WAD `uint256`;
        *   `pausedFeatures()` returning `uint8[]`, where an empty list means nothing is paused;
        *   `TRANSFER_SENDER_POLICY()`, `TRANSFER_RECEIVER_POLICY()` and `TRANSFER_EXECUTOR_POLICY()`, each returning a `bytes32` scope;
        *   `policyId(bytes32 scope)` returning `uint64`.
    *   **There is no `paused()` and no zero-argument `policyId()`.** Calls to either revert.
    *   **A separate `IPolicyRegistry`** at `0x8453000000000000000000000000000000000002`:
        *   `isAuthorized(uint64 policyId, address account)`, which never reverts;
        *   `policyExists(uint64)`.
        *   A policy ID's top byte gives its type: `0x00` is BLOCKLIST, `0x01` is ALLOWLIST.
    *   GOOGLc uses policy 5, a blocklist, for all three transfer scopes.
    *   Only the fork test and the frontend banner use the non-ERC-20 parts. The vault treats GOOGLc as a plain ERC-20.

#### 5. `contracts/src/PieceToken.sol` (Create)

*   **Type / Scope**: ERC-20.
*   **Proposed Changes**:
    *   OpenZeppelin ERC20 with an immutable `vault`, and `mint(to, amount)` / `burn(from, amount)` callable only by the vault.
    *   Decimals are set at construction to match GOOGLc.
    *   Plain transfers, with no extra transfer restrictions.

#### 6. `contracts/src/SegmentVault.sol` (Create)

*   **Type / Scope**: Core contract.
*   **Proposed Changes**:
    *   **Behaviour**: the actions, lifecycle and safety properties in Technical Plan section 3; admin and guardian functions in section 8.
    *   **Storage**: `IERC20 immutable collateralToken`, `mapping(uint256 => Series) series`, `uint256 seriesCount`, `address immutable admin` (the timelock), `address immutable guardian`, `address deployer`, and `address resolver`, which is set once by the deployer through `setResolver` before any series exists (see section 8).
    *   **Additions not in the Technical Plan**:
        *   `createSeries(label, tradingCloseAt, ruleHash)` deploys the two PieceTokens with the names from section 3 and sets state Trading. It takes no resolver settings.
        *   `poke(id)` moves Trading → Closed once `tradingCloseAt` has passed. Every other function runs the same check first.
        *   Resolver-only: `finalize(id, ppm)` requires Closed, then sets `cloudPpm` and state Final. There is no other resolver hook into the vault.
        *   Views: `stateOf(id)` (reports Closed once time passes, even before a write), `owed(id)`, `getSeries(id)`, and `seriesOfToken(cloud)`, which returns the series id for a `$CLOUD` token and reverts for any other address. CloseHook relies on it.
    *   **Events**: `SeriesCreated`, `Split`, `Merged`, `Redeemed`, `Closed`, `Finalized`.
    *   **Errors**: from `SeriesTypes.sol`.

#### 7. `contracts/src/FilingResolver.sol` (Create)

*   **Type / Scope**: Settlement contract.
*   **Proposed Changes**:
    *   **Storage**: `vault`, `IERC20 immutable bondToken` (USDC), `address immutable admin`, `arbiter`, and immutable `disputeWindow`, `fallbackDelay` (45 days mainnet, 1 hour testnet) and `sanityBandPpm = 100_000`, and per series `fallbackPpm`, `bond`, a `ResolverState`, a `configured` flag, and a `Proposal` struct (proposer, challenger, both figure pairs, accession string, docHash, proposedAt, and the arbiter at the time of proposing; `decide` accepts only that arbiter).
    *   **Behaviour**: the rule, steps, resolver states and parameters in Technical Plan section 4. The fallback deadline is the vault's `tradingCloseAt` plus `fallbackDelay`. The sanity band is measured against the series' `fallbackPpm`.
    *   **Functions**: `configureSeries(id, fallbackPpm, bond)` (admin, once per series; reverts if already set or if the vault has no such series), `propose(id, cloudRev, servicesRev, accession, docHash)`, `challenge(id, cloudRev, servicesRev, accession, docHash)`, `settle(id)` (unchallenged proposal after the window), `decide(id, choice)` with `choice` one of Proposer, Challenger or Reject, and `fallbackFinalize(id)` (returns any posted bonds).
    *   **Additions not in the Technical Plan**:
        *   ppm is computed onchain from the two revenue figures, never accepted as an input.
        *   Burned bonds go to the address `0x000000000000000000000000000000000000dEaD`.
        *   A new proposal after a Reject starts a fresh dispute window.
    *   **Events**: `Proposed`, `Challenged`, `Decided`, `Rejected`, `Finalized`, `FallbackFinalized`, each with figures, ppm, accession and docHash.

#### 8. `contracts/src/CloseHook.sol` (Create)

*   **Type / Scope**: Uniswap v4 hook.
*   **Proposed Changes**:
    *   BaseHook with permissions `beforeInitialize`, `beforeSwap` and `beforeAddLiquidity`.
    *   Immutable `vault` and `collateralToken` (GOOGLc). No admin functions.
    *   `beforeInitialize` accepts the pool only if one currency is GOOGLc and the other is a `$CLOUD` token the vault knows (`vault.seriesOfToken`). It handles either token order.
    *   `beforeSwap` and `beforeAddLiquidity` look up the series the same way and revert with `ClosedForSettlement()` unless the vault reports it as Trading.
    *   Removing liquidity has no check.
    *   Fee is fixed at 0.30% and tick spacing at 60, in the PoolKey.

#### 9. `contracts/src/SegmentRouter.sol` (Create)

*   **Type / Scope**: Periphery contract.
*   **Proposed Changes**:
    *   **Behaviour**: `buyCloud`, `sellCloud` and `buyServices` as in Technical Plan section 5, each with a `deadline` and a minimum amount out.
    *   **Additions not in the Technical Plan**:
        *   Built on v4-periphery's `V4Router` base and `Actions` encoding, not a hand-written `unlock` callback. This leaves token ordering and settling with the PoolManager to tested library code.
        *   It keeps no balance between transactions. A test checks this after every call.
        *   The hook's `ClosedForSettlement()` error passes through unchanged.

#### 10. `contracts/src/mocks/MockB20.sol`, `MockUSDC.sol`, `Faucet.sol` (Create)

*   **Type / Scope**: Testnet and test mocks.
*   **Proposed Changes**:
    *   **MockB20**: an ERC-20 with **8 decimals** and the same function names as `IB20.sol`. It has:
        *   an owner-set `multiplier()`;
        *   `pausedFeatures()`, and owner `pause`/`unpause`, with transfers reverting while paused;
        *   the three transfer-scope getters and `policyId(bytes32)`.
    *   **MockPolicyRegistry**: a blocklist answering `isAuthorized(uint64, address)`. The mock token checks it on every transfer for sender, receiver and executor, like the real token.
    *   **MockUSDC**: 6 decimals.
    *   **Faucet**: 20 GOOGLc and 2,000 USDC per address per 24 hours.

#### 11. `contracts/script/DeployTestnet.s.sol` (Create)

*   **Type / Scope**: Deployment script.
*   **Proposed Changes**:
    *   Deploys the mocks, the Faucet, a TimelockController (zero delay on testnet, Safe as its only proposer and executor, no separate admin), the vault, the resolver (window 15 minutes, fallback delay 1 hour; the 1,000 USDC bond is set per series by `CreateSeries`), the hook (mined address via HookMiner) and the router.
    *   Calls `vault.setResolver` once, before any series exists, which locks it.
    *   Writes all addresses to `deployments/base-sepolia.json`.

#### 12. `contracts/script/CreateSeries.s.sol` (Create)

*   **Type / Scope**: Script.
*   **Proposed Changes**:
    *   Takes label, close time, rule hash, fallback ppm, bond and cap. The fallback ppm must match the one written in that quarter's rule document.
    *   Calls `vault.createSeries` and `resolver.configureSeries` in one Safe transaction, then initializes the pool (no registration step; the hook recognises the new `$CLOUD` token through the vault) at the price matching the last settled share (handling which token sorts first), and appends the series to the deployments file.

#### 13. `contracts/script/SeedPool.s.sol` (Create)

*   **Type / Scope**: Script.
*   **Proposed Changes**:
    *   Splits seed GOOGLc and adds two positions through the v4 PositionManager: the main range at the expected share ± 5 points (Technical Plan section 5), and the backstop at 10%–45%.
    *   The leftover `$SERVICES` stays in the team wallet and is recorded as the cost of providing liquidity.

#### 14. `contracts/script/ReplaySettlement.s.sol` (Create)

*   **Type / Scope**: Demo script.
*   **Proposed Changes**: For series `26Q3`, scripted on testnet:
    1.  A few trades.
    2.  `closeEarly`.
    3.  A wrong proposal from wallet A.
    4.  A challenge with Alphabet's real Q3 2026 figures, accession number and file hash from wallet B.
    5.  The arbiter's decision through the Safe.
    6.  Redemptions.

#### 15. `contracts/test/SegmentVault.t.sol` (Create)

*   **Type / Scope**: Unit tests.
*   **Proposed Changes**:
    *   Split, merge and redeem amounts, including rounding at ppm 0, 1, 999,999 and 1,000,000.
    *   Every state blocks the right actions.
    *   Deposit cap.
    *   Exit with `to` while the sender is blocklisted on the mock.
    *   Behaviour while the mock is paused: actions revert, nothing is lost.
    *   Access control on every function in section 8.
    *   `setResolver` works once, only from the deployer, and only before the first series.

#### 16. `contracts/test/FilingResolver.t.sol` (Create)

*   **Type / Scope**: Unit tests.
*   **Proposed Changes**:
    *   Propose, then settle.
    *   Challenge, then each decision (proposer, challenger, reject) with exact bond payouts, and a new proposal after a reject.
    *   Sanity band triggers Disputed.
    *   Window edges.
    *   One challenge only.
    *   Fallback settles at the series' configured `fallbackPpm`. Two series are open at once: finalizing the older one does not change the newer one's fallback or sanity band.
    *   `configureSeries` works once only, and proposing on an unconfigured series reverts.
    *   Proposing reverts while the vault reports Trading.
    *   `setArbiter` during a live dispute: the old arbiter still decides it, and the new one can't.
    *   No action allowed after Done.

#### 17. `contracts/test/CloseHook.t.sol` (Create)

*   **Type / Scope**: Unit tests on a local v4 deployment.
*   **Proposed Changes**:
    *   Swaps and adding liquidity work while Trading and fail after `tradingCloseAt` or `closeEarly`.
    *   Removing liquidity always works.
    *   A pool cannot initialize with an unknown token, with a `$CLOUD` token paired against anything other than GOOGLc, or without the hook's address.
    *   Works with either token order.

#### 18. `contracts/test/SegmentRouter.t.sol` (Create)

*   **Type / Scope**: Unit tests.
*   **Proposed Changes**:
    *   Each of the three paths gives the expected amounts against a seeded pool.
    *   Slippage limits and deadlines revert.
    *   The router ends every call holding nothing.
    *   Closed-series errors pass through.

#### 19. `contracts/test/invariant/VaultInvariant.t.sol` and `contracts/test/invariant/VaultHandler.sol` (Create)

*   **Type / Scope**: Invariant (fuzz) tests.
*   **Proposed Changes**:
    *   The handler randomly calls split, merge, swaps, multiplier changes, pause and unpause, time jumps, propose, challenge, decide, fallback and redeem, across several series and actors.
    *   Invariants:
        *   the three vault properties in Technical Plan section 3;
        *   a series in Final never changes ppm;
        *   the total GOOGLc paid out never exceeds the total deposited.

#### 20. `contracts/test/fork/GOOGLcFork.t.sol` (Create)

*   **Type / Scope**: Mainnet-fork test.
*   **Proposed Changes**:
    *   Pinned block 57,298,792, real GOOGLc (`0xb2000000000000000000002D0BA3164cc74f58B7`), real v4 contracts.
    *   **Day-1 part: done in G0, and passes 5 of 5 under `base-forge`** (`docs/research/g0_findings.md`, section 1.4). It confirmed:
        *   GOOGLc is a precompile with 8 decimals;
        *   nothing is paused;
        *   policy 5 is a blocklist that allows the vault, PoolManager and Universal Router;
        *   a contract vault's `transferFrom` and `transfer` round trip moves exact amounts.
    *   **Full test, to add once SegmentVault exists:** it impersonates the same real holder, `0x16c70F04C3080a127486Cdf5a4C33c066bBF47C3`, with no `deal`. Steps: deposit, split, merge, settle and redeem through the real vault, plus a swap through the real v4 PoolManager.

#### 21. `contracts/test/E2E.t.sol` (Create)

*   **Type / Scope**: Local end-to-end test.
*   **Proposed Changes**: CUJs 1–7 in one scenario on a local chain. This is the G3 gate test.

#### 22. `deployments/base-sepolia.json` (Create, generated)

*   **Type / Scope**: Deployment record.
*   **Proposed Changes**: Contract addresses, series ids, pool ids and token addresses. The app reads it, and it is committed so judges can check it.

#### 23. `docs/rules/GOOGL-segment-rule-v1.md` (Create)

*   **Type / Scope**: Settlement rule.
*   **Proposed Changes**:
    *   The rule text from Technical Plan section 4, naming the exact table and row labels in Alphabet's earnings release.
    *   A worked calculation on the last four quarters, including Q4.
    *   Its SHA-256 hash goes into every series as `ruleHash`.

#### 24. `docs/data/googl-cloud-share-history.csv` (Create)

*   **Type / Scope**: Data.
*   **Proposed Changes**:
    *   Columns: quarter, accession number, exhibit SHA-256 (computed with `shasum -a 256`), Cloud revenue, Services revenue, ppm.
    *   The last 8–12 quarters, taken by hand from EDGAR.
    *   Used to size the bet honestly in the pitch, to set each series' fallback ppm, and to centre the pool range.

#### 25. `docs/research/trader-interviews.md` (Create)

*   **Type / Scope**: Research record.
*   **Proposed Changes**:
    *   The three-option question: free-floating `$CLOUD`, settling `$CLOUD`, or a USDC Cloud-share market.
    *   One row per interview.
    *   Tally against the 8-of-20 pass mark and the 5-of-20 change mark.

#### 26. `.github/workflows/ci.yml` (Create)

*   **Type / Scope**: CI.
*   **Proposed Changes**:
    *   **Contracts:** install Base's Foundry build with `base-foundryup`. Then run:
        *   `base-forge build`;
        *   `base-forge test` (unit, invariant, end-to-end);
        *   `base-forge coverage`, with a check of at least 90% line coverage on `contracts/src` excluding mocks;
        *   the fork test, with `BASE_RPC_URL` from secrets.
    *   **App:** lint and build.

#### 27. `app/package.json`, `app/next.config.mjs`, `app/tsconfig.json` (Create)

*   **Type / Scope**: Frontend configuration.
*   **Proposed Changes**: Next.js (App Router), TypeScript, viem, wagmi, and TanStack Query. No other UI framework beyond plain CSS modules.

#### 28. `app/lib/contracts.ts` (Create)

*   **Type / Scope**: Frontend module.
*   **Proposed Changes**: Loads addresses from `deployments/base-sepolia.json` and the ABIs exported from Foundry's build output. One typed object per contract.

#### 29. `app/lib/math.ts` (Create)

*   **Type / Scope**: Frontend module.
*   **Proposed Changes**:
    *   Implied share from the pool price.
    *   Payout per piece at a given ppm.
    *   The worked example: return compared with holding GOOGL.
    *   Rounding identical to the contract (floor).

#### 30. `app/lib/wagmi.ts` (Create)

*   **Type / Scope**: Frontend module.
*   **Proposed Changes**: Base Sepolia chain configuration, an injected-wallet connector and the RPC URL from an environment variable.

#### 31. `app/app/page.tsx` (Create)

*   **Type / Scope**: Trade page.
*   **Proposed Changes**:
    *   Headline "Market expects Cloud share: X%".
    *   Buy and sell `$CLOUD`, and buy `$SERVICES`, through the router, with a quote, price impact and a minimum-out setting.
    *   Exiting `$SERVICES` is offered as two steps: buy `$CLOUD`, then merge.
    *   Split and merge.
    *   Faucet button.
    *   Issuer-pause banner.

#### 32. `app/app/positions/page.tsx` (Create)

*   **Type / Scope**: Page.
*   **Proposed Changes**: Holdings per series, and a payout table at the implied share ± 1 and ± 2 points.

#### 33. `app/app/settlement/page.tsx` (Create)

*   **Type / Scope**: Page.
*   **Proposed Changes**:
    *   Series state and countdowns (close, window, fallback).
    *   Proposals and challenges with EDGAR links, accession numbers and hashes, rebuilt from resolver events.
    *   Redeem button.

#### 34. `app/app/proof/page.tsx` (Create)

*   **Type / Scope**: Page.
*   **Proposed Changes**:
    *   For each series: collateral, both supplies, amount owed, and the vault's total GOOGLc balance.
    *   A pass or fail line per check.
    *   Explorer links.
    *   Read live, with nothing hard-coded except contract addresses.

#### 35. `app/app/risks/page.tsx` (Create)

*   **Type / Scope**: Page.
*   **Proposed Changes**:
    *   Issuer pause and blocklist.
    *   Trusted arbiter.
    *   Unaudited, testnet only.
    *   It's a derivative, not for US persons.
    *   Pools outside the team's pool are not closed at settlement.
    *   What `$CLOUD` does and does not pay.

#### 36. `app/app/how-it-works/page.tsx` (Create)

*   **Type / Scope**: Page.
*   **Proposed Changes**:
    *   The one-sentence pitch.
    *   The worked example from The Problem: Q3 2026, 20.76% → 24.18%.
    *   The difference from Daybreak and from prediction markets, in the agreed wording.

#### 37. `README.md` (Create)

*   **Type / Scope**: Documentation.
*   **Proposed Changes**:
    *   What the product is, in the agreed framing.
    *   How to run the tests (including the fork test).
    *   Deployed addresses.
    *   The admin list, and what admins can and cannot do.
    *   A link to the rule document and to the Risks page.

#### 38. `docs/DEMO.md` (Create)

*   **Type / Scope**: Documentation.
*   **Proposed Changes**:
    *   The 2-minute judge path: faucet, buy `$CLOUD`, view the replay settlement, redeem, check Proof.
    *   The 5-minute outsider test script used before December 1.

#### 39. `.env.example` (Create)

*   **Type / Scope**: Configuration template.
*   **Proposed Changes**: `BASE_RPC_URL`, `BASE_SEPOLIA_RPC_URL`, `FORK_BLOCK`, `DEPLOYER_ADDRESS`, `SAFE_ADDRESS`. Keys are never stored. Deploys use a hardware or keystore signer.

### Verification Plan

*   **Toolchain**: every Foundry command below uses `base-forge` (Base's build), because the Homebrew `forge` cannot run B20 precompiles.
*   **Compilation/Build**: `base-forge build` in `contracts/`; `pnpm --filter app build`.
*   **Unit Tests**: `base-forge test --match-path "test/*.t.sol"`.
*   **Invariant Tests**: `base-forge test --match-path "test/invariant/*"`, 256 runs, depth 100. Must pass with the multiplier and pause actions enabled.
*   **Fork Test**: `BASE_RPC_URL=<rpc> base-forge test --match-path "test/fork/*" -vv`. The block is pinned in the test.
*   **End-to-end**: `base-forge test --match-path test/E2E.t.sol` (gate G3), then `ReplaySettlement.s.sol` on Base Sepolia (gate G5).
*   **Static Analysis & Linting**: `base-forge fmt --check`; Slither on `contracts/src` with no high or medium findings left unexplained; `pnpm lint`.
*   **Test Coverage Requirement**: At least 90% line coverage on `contracts/src` excluding mocks.
*   **Settlement rule check**: `docs/data/googl-cloud-share-history.csv` ppm values match the rule applied by hand for four quarters including Q4, and match `FilingResolver`'s calculation in a unit test.
*   **Usability**: 3–5 outsiders complete the `docs/DEMO.md` path. Success means each can say what `$CLOUD` pays within 2 minutes and completes split, trade and redeem within 5 minutes with at most one question.

--------------------------------------------------------------------------------

<!-- Provenance: Indicates initial structural drafting via EGM. -->

*Drafted with EGM*
