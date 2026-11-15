# Segment tokens that settle on SEC filings: concepts brief

* **Author:** Two-person team (Stocks Maxxing entry)
* **Date:** 2026-11-14
* **Inputs:** `segment_split_hypothesis.md`, `market_research.md`, Goldfish review (design, codebase details, zoom-out, comprehension, implementation readiness, structural)
* **Note:** reviewers could not open web pages. Facts about what is deployed where (Conditional Tokens, token wrappers, UMA, Uniswap v4 and Aerodrome on Base and Base Sepolia, the internals of Coinbase stock tokens, Alphabet's segment reporting) came from memory and are marked **VERIFY**.

## Overview

The idea:

* Split a Coinbase stock token (demo: Alphabet, GOOGLc) into one token per business segment, `$SEARCH` and `$CLOUD`.
* Let people trade the pieces.
* After each quarterly report, let each piece redeem on its own for its segment's share of revenue, taken from Alphabet's SEC filing.

The only claimed difference from Daybreak is this filing-based payout. Daybreak's public page describes no results-based settlement.

**Reviewer verdict:** the vault, resolver and pool can be built as a testnet demo by two people, but only after cutting about a quarter of the planned scope. Every reviewer's main doubt is the product, not the code.

## Decision: framing (resolved 2026-11-14)

The team chose **alternative A: reframe without changing the mechanism.** The product is presented as what it is: a market on a company's revenue mix, paid in the stock itself.

* **One-line pitch:** "Take a view on Alphabet's quarter without selling your Alphabet. `$CLOUD` pays out Cloud's real share of revenue, in GOOGL, straight from the SEC filing."
* **One market, two sides:**
  * `$CLOUD` is the long side: you think Cloud's share will beat what the market expects.
  * The other piece is the short side, named `$SERVICES`, the accurate segment name. It is described as "Alphabet minus Cloud".
  * The app leads with `$CLOUD`.
* **Headline number:** "Market expects Cloud share: X%", which is the `$CLOUD` price in GOOGLc.
* **Answer to "isn't this a prediction market?":** "Yes, an earnings-mix market. The difference is that it is paid in the stock. Your position still moves with Alphabet, nothing is converted to dollars, and merging both pieces always gives back one real GOOGL token."
* **Answer to "how is this different from Daybreak?":** "Daybreak's public page describes segment pieces that move on trading alone. Ours pay out on the filed numbers, so the price is the market's forecast of the company's revenue mix."
* **Worked example** (illustrative numbers):
  * The market expects Cloud at 15.0%. You buy 1 `$CLOUD` for 0.150 GOOGLc.
  * Alphabet reports Cloud at 15.5%, so 1 `$CLOUD` redeems for 0.155 GOOGLc: **+3.3% against holding GOOGL**.
  * If Alphabet's stock also rose 5% that quarter, your total is about **+8.5%**, against +5% for plain GOOGL.
  * If Cloud comes in at 14.5% instead, you get about **−3.3% against GOOGL**.
  * Rough rule: return ≈ (1 + Alphabet's return) × (actual share ÷ share you paid for) − 1.
* **What we stop saying:**
  * "Own the part of the company you believe in";
  * "invest in segments";
  * "built like Polymarket";
  * anything that suggests big moves at settlement.
* **Still open:**
  * Make the payout bigger (alternative B), only if trader interviews show the bet is too small to interest anyone.
  * The other decisions listed under "Decisions to freeze".

## Analysis

### Objections, strongest first

1. **The payout barely moves.**
   * `$CLOUD` pays w × GOOGLc, where w = Cloud ÷ (Services + Cloud).
   * w changes by about half a point to a point a quarter (VERIFY), and analysts forecast most of that. A typical surprise is about ±0.3 points, so `$CLOUD` moves about ±2% at settlement and `$SEARCH` about ±0.35%. Alphabet's own price moves 10–20% a quarter.
   * The pitch "own the part you believe in" promises more than the payout delivers.
   * A Cloud bull can lose money if AI hurts Search: w rises, but GOOGLc falls.
   * Before building, collect the last 8–12 quarters of w.

2. **It is a prediction market on revenue mix, paid in stock, and judges will say so.**
   * Two outcome tokens, a single number decided by an oracle, then redemption: that is the textbook design.
   * Holding GOOGLc plus a USDC market on Cloud's share gives the same position.
   * Recommended response: stop defending it and say it plainly. "An earnings-mix market paid in stock: take a view on the quarter without selling your stock."
   * Confirm with the organisers which track it fits.

3. **It is a different product from Daybreak, not a better one.**
   * Settlement ties the price to a revenue ratio and removes the open-ended, story-driven upside that probably draws Daybreak users.
   * No target user is named:
     * meme traders get no big upside;
     * stock holders get almost no hedge;
     * earnings gamblers already have USD markets.
   * In a 2-minute demo, split, trade and merge look like Daybreak. The difference only shows in the settlement replay.

4. **Demand is tested last.** This repeats the mistake of the rejected concept.
   * Make it a 48-hour gate with three options for traders:
     * a free-floating `$CLOUD`;
     * a settling `$CLOUD`;
     * a USDC market on Cloud's share.

5. **The resolver is the real custody risk.**
   * "Nobody can withdraw GOOGLc" means little if the team can propose Cloud = 100% while holding `$CLOUD`.
   * At small size, nobody outside the team will watch for wrong proposals, and a dispute decided by the team is not a real check.
   * In practice this is a trusted oracle. Say so, and add an outside signer.

6. **The issuer can freeze everything.**
   * If the issuer pauses GOOGLc, or blocks any contract that holds it, every action stops: split, merge, redeem and the pool.
   * Because the pieces move freely, a blocked address could hold Alphabet exposure through them. The issuer's natural response is to block the vault.
   * Correct wording: "the team cannot pause it; the issuer can freeze everything."

7. **Quarterly expiry contradicts the word "own".**
   * Every piece expires each quarter, and holders and liquidity providers must roll over.
   * This is an expiring derivative, which supports the reframing in objection 2.

8. **`$SEARCH` is close to redundant.**
   * At about 85% of Alphabet it is nearly plain GOOGLc. It is also really "Google Services" (Search, YouTube, subscriptions, devices).
   * Present the product as one Cloud-share market with a long side and a short side.

9. **The pause and settlement timing conflict.**
   * Waiting for the 10-Q, and for Q4 the annual 10-K, then 48–72 hours of disputes, locks holders for days or weeks.
   * The hypothesis also contradicts itself on whether redemption is open during the pause.

The tracking-stock discount risk does not apply, because merge always gives back 1 GOOGLc. Present that as a strength.

### Technical points the build must get right

**Settlement source and rule**

* **There is no Q4 10-Q.** The 10-K may not show Q4 segment revenue separately (VERIFY). Two options:
  * settle every quarter on the earnings release, which is filed with the SEC as an 8-K (exhibit 99.1) on EDGAR;
  * define Q4 as the full year minus nine months.
* **Formula:** w = Cloud ÷ (Services + Cloud), using named XBRL data fields. Exclude Other Bets, hedging and Alphabet-level items. State how intersegment revenue is handled.
* **Store one number.** Post the raw revenue figures and compute Cloud's share in parts per million, rounded down. Search's share is the remainder.
* **Rounding:** round every payout down. Leftover dust stays in the vault.
* **Evidence:** the EDGAR accession number plus a hash of the exact file. It is an audit trail, not a proof.
* **Written rules for edge cases:**
  * **Restatements:** the first filing wins.
  * **Segment reorganisation:** settle at the last settled w.
  * **No filing or no arbiter:** after 30–45 days, anyone can finalise at a fallback w written in advance. Never cut this rule; without it, holders can be stuck forever.

**Resolver**

* **If Conditional Tokens is used:** only the address written into each market can report the result, it can report only once, and the result can't be undone. So the resolver contract itself must be that address.
* **Dispute flow:**
  1. The proposer posts weights with a bond in USDC.
  2. A challenger posts different weights with an equal bond.
  3. A named 2-of-3 Safe, with one signer from outside the team, picks the answer. The winner takes the loser's bond.
* **Sanity check:** reject or escalate automatically if Cloud's share moves more than about 3 points.
* **Testnet dispute window:** 10–15 minutes, stated in the demo.
* **UMA:** a roadmap item, not this build.
* **Events and monitoring:** emit an event at each step, run a watcher that checks proposals against EDGAR, and alert on issuer pause, policy change and multiplier change.

**Collateral (GOOGLc)**

* **Check on a mainnet fork on day 1:**
  * Do balances change when the multiplier changes?
  * Are there transfer fees?
  * Is `isAuthorized` a blocklist or an allowlist?
  * What does the issuer's pause block?
  * How are dividends and spin-offs delivered?
  * Is the token a normal contract or a precompile (VERIFY)? If it's a precompile, the fork test needs another approach.
* **Accounting:** count token units, not shares.
* **Blocked holders:** add `redeemTo(address)` so a blocked holder can exit to another address.
* **Mock token:** it must change its multiplier in the middle of a test.

**Vault**

* Conditional Tokens is old Solidity (0.5), needs a wrapper to make ERC-20 tokens, and redeems a holder's whole balance at once.
* **Options:**
  * **(i) UMA Long Short Pair:** GOOGLc as collateral, `$CLOUD` long, `$SEARCH` short. Use it only if it's deployed on Base and Base Sepolia (VERIFY).
  * **(ii) Custom vault:** a small, modern one of 150–250 lines with two ERC-20s per quarter. Easier to test.
  * **(iii) Conditional Tokens:** only if "Polymarket's contracts" matters more than build time.
* **Reviewers lean towards (ii).**

**Pool, pause and router**

* **Venue:** use Uniswap v4. Aerodrome Slipstream has no hooks and probably no testnet deployment (VERIFY).
* **Pausing:**
  * Don't pause and then reopen the same pool, because the first trade after reopening takes the gap from liquidity providers.
  * Instead, set a fixed `tradingCloseAt` time for each quarter, ahead of the earnings date. A guardian can close early but never reopen. Liquidity removal is always allowed.
  * Open the next quarter's market at the same time, so one market is always live.
* **Liquidity math (checked):**
  * At a $5k seed, a $1k trade moves `$CLOUD` about 10%.
  * Centre the range on last quarter's w ± 2–3 points, with a wide backstop.
  * Seeding leaves the team holding unused `$SEARCH`. Fee income will be near zero.
* **Router:** it needs to sell `$SEARCH` and sell `$CLOUD`, not only buy them. Every path needs a minimum amount out and a deadline.
* **Leak:** anyone can open an unpaused pool elsewhere. State this on the risk page.

**Display and tests**

* **"Fair value" is mislabelled.** The token pays next quarter's weight. Rename it "last settled value", and make the headline "market expects Cloud share X%", which is simply the pool price.
* **The Proof page's sum check proves nothing.** Show instead:
  * before settlement: vault GOOGLc ≥ the larger of the two supplies;
  * after settlement: vault GOOGLc ≥ the total owed.
* **Fork test:** pin it to a block, and keep the RPC key out of the repository.

### Alternatives raised

* **A. Reframe without changing code.** "Earnings-mix market paid in stock." Lead with `$CLOUD`, and describe `$SEARCH` as "Alphabet minus Cloud". This is the most honest option and the least work.
* **B. Make the bet bigger.**
  * Leverage the payout around a set point (for example 10× the change in share).
  * Settle on a growth range, or on operating-income share.
  * Trade-off: it looks even more like a derivative.
* **C. A USDC market on Cloud's share.** The same bet, with no issuer risk, but a weaker fit for a stocks competition.
* **D. A filing-linked segment-data oracle that others (including Daybreak) could use.** New, but it's infrastructure with no users of its own.
* **E. Free-floating pieces like Daybreak.** Not recommended; nothing would distinguish it.
* **Live settlement option:**
  * Nvidia reports November 17 (VERIFY). A testnet series on mock NVDAc, settled on the real filing about a week later, would beat a replay.
  * It needs a minimal vault and resolver deployed by about November 16, and Nvidia's mix is even more static.

## Goals vs. Non-Goals

* **In-scope goals:**
  1. **On Base Sepolia,** a user can:
     * split mock GOOGLc;
     * trade `$CLOUD`, or get `$SEARCH` through the router;
     * merge;
     * redeem each piece on its own after settlement.
  2. **A written settlement rule** maps named XBRL fields to w and reproduces the last four Alphabet quarters, including a Q4, exactly.
  3. **End-to-end settlement** with the bonded resolver, including one wrong proposal that loses a dispute, and the never-settles fallback.
  4. **Invariant tests,** including a multiplier change, show that the vault always covers what it owes. The Proof page shows the same thing live.
  5. **A mainnet fork test with real GOOGLc:** deposit, split, merge and redeem, plus an `isAuthorized` check for every contract that holds it.
  6. **The headline number** is the market-implied Cloud share.
  7. **A one-sentence answer** to "how is this not a prediction market?", plus a worked dollar example.
  8. **Usability:**
     * a judge can say what `$CLOUD` pays within 2 minutes;
     * they can complete split, trade and redeem within 5 minutes;
     * tested with 3–5 outsiders before December 1.
* **Out-of-scope non-goals:**
  * A mainnet beta or real seed money, unless every mainnet gate passes.
  * USDC entry, the Aerodrome route, range tuning.
  * An event-triggered pause or a pool that reopens.
  * Rolling tokens or more than one live series.
  * A decentralised resolver, UMA integration.
  * More stocks or segments (except the optional live NVDA testnet series).
  * Any promise about prices between reports.
  * An own token, points, a trading terminal, an audit, US users.
  * Conditional Tokens with token wrapping, unless the other vault options fail.
* **Never cut:** the fork test, invariant tests, the dispute replay, the Proof page, the never-settles fallback.
* **Cut order if late:**
  1. Mainnet.
  2. USDC path.
  3. Router extras.
  4. Selling `$SEARCH` in one transaction.
  5. Automated roll-over.
  6. Frontend polish.
  7. Interviews cut to 10.

## Key Decisions & Staging for Next Steps

**Gates**

* **G0, Nov 15–17: facts and the fork test.**
  * Fork test on GOOGLc: rebase, blocklist or allowlist, which contracts can hold it, pause behaviour, precompile.
  * Confirm contract addresses on Base and Base Sepolia.
  * Ask the organisers about track fit.
  * Collect 8–12 quarters of w.
  * Start 10–15 trader conversations with the three-option question.
  * Stop or pivot if contracts can't hold GOOGLc or settling `$CLOUD` doesn't clearly win.
* **G1, Nov 16:** freeze the decisions below, the state of each quarter's series, the resolver spec and the rule document.
* **G2, Nov 19–20:** vault, mock token and resolver running locally. The rule reproduces four quarters. If Alphabet can't be mapped mechanically, switch to Nvidia.
* **G3, Nov 22:** a full local run passes: split, swap, merge, close, propose, dispute, decide, redeem.
* **G4, Nov 24–25:** first testnet deployment. Interviews done.
  * **Pass:** at least 8 of 20 traders prefer the settling `$CLOUD`.
  * **Below 5 of 20:** lead with the stock-backed split instead.
* **G5, Nov 27:** contracts frozen. Tests and fork test green. Disputed replay run on testnet.
* **G6, Dec 1:** final deployment, frontend, Proof page and outsider test done. Mainnet only if all of these hold:
  * the fork test passes;
  * a lawyer gives written no-objection;
  * the team is eligible to hold stock tokens;
  * the G4 demand bar is met.
* **Dec 3:** video and risk page. **Dec 4:** submit. **Dec 5:** buffer.

**Decisions to freeze by about November 16**

1. **Product framing:** resolved, reframe only (A). See "Decision: framing".
2. **Vault:** UMA Long Short Pair, a custom vault, or Conditional Tokens.
3. **Settlement source:** the 8-K earnings release, or the 10-Q/10-K with a Q4 rule.
4. **Weight formula:** the denominator, exclusions, precision and rounding.
5. **Resolver:**
   * who proposes;
   * the arbiter and its outside signer;
   * bond asset and size;
   * window lengths;
   * the sanity band;
   * the never-settles deadline and its fallback;
   * restatement and reorganisation rules.
6. **Pause:** a scheduled, permanent close for each quarter, with a guardian who can only close early.
7. **Quarterly lifecycle:** Created → Trading → Closed → Proposed → (Disputed) → Final → Redeem-only. Also decide when the next quarter opens and how tokens are named (for example `CLOUD-GOOGL-26Q4`).
8. **Collateral policy:** count token units, add `redeemTo`, decide what happens to airdrops and spin-offs, and decide whether piece transfers follow the issuer's rules.
9. **Router scope.**
10. **Demo stock:** an Alphabet replay only, or add a live Nvidia testnet series (needs deployment by about November 16).
11. **Admin functions:** list every one. Nothing else exists. All go through a Safe with a timelock.

**The next document (`/egm:egm-draft`) needs:**

* a plain problem statement and goals;
* the quarterly lifecycle;
* the resolver and settlement-rule spec;
* an issuer-permission table;
* a failure-mode table: issuer pause, blocked address, multiplier change, no filing, restatement, reorganisation, wrong proposal, price out of range, an unpaused outside pool;
* the alternatives rejected;
* costs;
* a timeline with gates;
* success criteria;
* a glossary.
