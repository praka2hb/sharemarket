# Stock-linked meme launchpad on Base: concepts brief

* **Author:** Two-person launchpad team (Stocks Maxxing entry)
* **Date:** 2026-11-13
* **Inputs:** `hypothesis.md`, `market_research.md`, Goldfish review (design, codebase details, zoom-out, comprehension, implementation readiness, structural)

## Overview

The team has built a launchpad before and wants a stock-linked launchpad on Base that is not a copy of what the partner launchpads (BaseStonk, o1, Stonks Exchange, Feel.cash, Bankr) already do.

The idea that went into review: a Uniswap v4 hook for meme tokens paired against a Coinbase stock token (for example NVDAc). The hook would read Chainlink's real stock price (NAV), raise fees and cap how much of the stock token one pool can hold when the onchain price drifts from NAV, and send the extra fees into a vault of stock tokens that meme holders can redeem against (a "floor").

The problem behind it is real. On August 30, 2026 on Robinhood Chain, the meme $BONER, paired against tokenized HIMS, held most of the HIMS token supply while minting was closed. The token traded at $61 against a real close of $28.84, then collapsed back when minting reopened. Base's own brief for idea 1.1 asks what happens "when stock-market liquidity shifts".

All six reviewers reached the same verdict on their own: **the full concept cannot ship safely with two people by December 5, and two parts of it are designed the wrong way round.** A cut-down version can ship, and one alternative design avoids most of the problems.

## Analysis

### What is wrong with the concept as written

1. **The protection sits in the wrong pool.** In the HIMS case the overpricing happened in the stock token's own markets (stock/USDC), where meme buyers bought the stock first. A hook on the meme/stock pool can only tax or block meme demand; it cannot see or fix the stock's price. The claim "extra fees go to the vault instead of to whoever bought at the inflated price" is false: the people who overpaid get nothing back. The honest claim is narrower: "our pools do not take stock off the market while minting is closed."

2. **The floor vault makes the squeeze worse.** The squeeze happened because one pool locked up most of the stock supply. A vault that turns 10–20% of each buy into stock locks up even more, during exactly the hours when no new stock can be minted. If the vault does not count toward the cap, it goes around the cap; if it does, it uses the cap up.

3. **"Drift from NAV" needs a second price that can be manipulated.** A meme/stock pool has no dollar price for the stock. You would need a stock/USDC pool as a reference, those pools are thin, and v4 has no built-in time-averaged price. An attacker can push the reference for one block to switch the fee off (to buy through the guard) or on (to hurt a rival).

4. **The demo cannot be done honestly on mainnet.** Recreating a squeeze on mainnet means pushing a real tokenized security above its real price with real money (costly, and it looks like market manipulation) or faking the oracle (which undermines the claim). HIMS may not exist on Base. "Contained" has no number.

5. **Nobody has checked that the issuer allows the pool and vault to hold the stock.** The issuer's transfer check (`isAuthorized`) can block the v4 PoolManager, the hook, the vault or people redeeming. A pause freezes every pool on that stock. One test answers this; if it fails, the concept is dead.

6. **Launchers and traders want squeezes.** For them a squeeze is the upside. A cap limits how big a meme can get, and extra fees plus a 10–20% buy tax are 10–40 times what competitors charge (0.25–1%). Volume would move to BaseStonk. The people who want containment are Base, Coinbase, the issuer, partners worried about reputation, and the judges. That makes this an infrastructure pitch, which conflicts with the goal of growing a user base.

7. **The problem has not been shown on Base.** Nobody has confirmed that Coinbase's minters stop on weekends, or measured how much of each stock token's supply meme pools on Base hold today.

### Technical points the build would have to get right

* **Fees in v4 go to liquidity providers, not to the hook.** Sending fees to a vault needs either a hook that takes its own cut of each swap (the most bug-prone kind of hook) or a hook that owns all the liquidity and collects the fees. That choice fixes the hook's address forever.
* **Fees should only apply to buys** (which pull stock into the pool), never to sells (which release stock).
* **Caps must be per stock token across all pools,** not per pool, or a squeezer launches ten memes on the same stock. A swap that would break the cap should fail with a readable error, not be partly filled.
* **Market hours are the wrong clock.** What matters is when minters are active (HIMS minting reopened Monday 00:00 UTC, not at the NYSE open). Standard Chainlink price feeds probably do not report this onchain. The paid Data Streams product does, but it does not fit a check on every swap.
* **Oracle failure must be defined:** stale feeds, sequencer downtime, split and dividend multiplier changes that look like a 2x or 0.5x jump, and weekend news that looks like drift. The safe default is to block buys while leaving sells and redemption open, never to make every swap fail.
* **Graduating to Aerodrome removes every protection,** because a v4 pool is bound to its hook. Launch straight into a hooked v4 pool instead.
* **Hooks cannot be upgraded.** Plan for limits set in code, a one-way shutdown mode, and redemption no admin can pause.
* **Gas is not a problem** (about 10–60k extra per swap on Base). The real costs are buying real stock tokens for liquidity and a short external review of the hook.
* **Parts to reuse:** OpenZeppelin uniswap-hooks (BaseHook, dynamic fee bases), v4-periphery (PositionManager, V4Quoter, HookMiner), the Clanker v4 factory as a starting point (about a week saved), and Ponder, Envio or Goldsky for indexing.
* **Monitoring is missing and is the cheapest valuable piece.** Each swap should log the real price, the price age, the premium, minting status, how much of the stock supply the pools hold, and the fee charged. A dashboard showing these per stock, across every launchpad's pools, matches Base's brief almost word for word.

### Alternatives the reviewers raised (strongest first)

1. **Memes quoted in USDC or WETH, with a stock treasury.** Memes never need stock tokens on weekends, so they cannot cause a squeeze. A share of fees buys the stock token, but only while minting is open and the price is within about 1% of NAV. Holders can redeem against the treasury. Pitch: "every meme is backed by real NVDA and never buys it above its real price." Several reviewers called this the strongest design. It does not match idea 1.1's wording ("trades against a stock token"), but it matches **idea 1.2 ("community fees into a visible stock treasury")** directly, which is in the same track.
2. **Float Guard module.** Only the hook and a registry: buy-only fee, a cap per stock token, defined failure behaviour, a replay test kit and documentation, pitched to BaseStonk and Bankr. Good for the judges and partners; gives up having your own users.
3. **Squeeze Radar.** A public dashboard, API and alert bot for every stock-paired pool on Base: how much stock each holds, premium over the real price, minting status. About one week to build, no contract risk, useful to partners and the issuer. Best combined with option 1 or 2.
4. **Pair memes with a Bankr index instead of one stock.** Spreads demand across many stocks so a squeeze is smaller. Mostly exists already.
5. **Weekend premium products** (pay whoever supplies stock over the weekend, or an inventory vault that sells into the premium and rebuys on Monday). Something traders would want, but derivative and legal risk and too big for three weeks.

## Goals vs. Non-Goals

* **In-scope goals (for whichever direction is chosen):**
  * One or two real stock tokens on Base mainnet (for example NVDAc).
  * Launch straight into a pool with no bonding curve, reusing an existing factory (Clanker fork or similar).
  * A rule that the product never buys stock tokens while minting is closed or above NAV by more than a set band.
  * A public dashboard: both prices, premium, minting status, stock held, every treasury purchase, and a reconciliation of fees in against purchases.
  * A replay on a mainnet fork of a HIMS-sized weekend squeeze, with and without the protection, and numbers that define a pass.
  * Readable onchain errors and events so bots and aggregators do not mistake protections for a scam.
* **Out-of-scope non-goals:**
  * Bonding curve and graduation.
  * Aerodrome pools.
  * A separate 10–20% buy tax.
  * Creating a real squeeze on mainnet.
  * An onchain market-hours calendar.
  * A custom trading terminal.
  * Multi-stock baskets (Bankr already does this).
  * More than 2–3 stock tokens.

## Key Decisions & Staging for Next Steps

**Gates for the first 48 hours. If any fails, change direction.**

1. Fork or mainnet test: can the stock token be sent to the v4 PoolManager, a hook and a new vault contract, and back out to a normal wallet? Read `isAuthorized` for each. Check whether balances change on a multiplier update.
2. Chainlink feeds on Base for the demo tokens: addresses, update frequency, weekend behaviour, whether a market-status field exists.
3. Coinbase minting hours in UTC, including holidays. (Thanksgiving, Nov 26–27, falls inside the build.)
4. Data pull: how much of each stock token's supply sits in meme pools on Base today, and the weekend premium history.
5. Whether the team can legally buy and hold stock tokens where it is based.
6. Ask the organisers whether a USDC-quoted meme with a stock treasury qualifies for Track 1 (it should, under idea 1.2).
7. Ask 5 launchers whether they would accept a cap on growth in exchange for a floor.

**Decisions still open:**

* Which direction: USDC-quoted memes with a stock treasury (alternative 1), Float Guard module (alternative 2), or either one plus Squeeze Radar.
* Whether the treasury allows redemption (legal exposure, flash-loan protection, what counts as outstanding supply) or only shows the holdings.
* Fee routing design and hook permissions, which cannot change later.
* Who holds admin keys and what can never be paused.

**Proposed timeline:**

* Nov 13–15: run the gates above.
* Nov 16–22: contracts and the replay test. Checkpoint: replay passes.
* Nov 23–29: launch factory, testnet, mainnet rehearsal, external hook review (Thanksgiving week, about 70% capacity). Watch real weekend price behaviour on Nov 28–29.
* Nov 30 – Dec 5: fix review findings, mainnet deploy by Dec 1 with allowlisted launchers and value caps, submit Dec 3–4.
