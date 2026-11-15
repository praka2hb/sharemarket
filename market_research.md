# Stock-meme launchpads: market research

* **Date:** 2026-11-13
* **Purpose:** decide what a differentiated stock-linked launchpad on Base should do for Stocks Maxxing (deadline December 5).

## 1. Facts about the stock tokens (Base and Coinbase docs)

* Coinbase stock tokens are B20 tokens on Base, backed 1:1 by real shares held by a regulated custodian (Alpaca).
* Anyone can hold or trade them on the open market. KYC happens only when Authorized Participants mint or redeem.
* They are not offered to US persons (and some other places, such as the UK).
* The issuer can attach a policy: `isAuthorized(policyID, account)` tells you whether an address may transfer. Blocked transfers revert. Functions can be paused.
* One token is not always one share. A `multiplier` changes on dividends and splits. Identify tokens by address, not ticker.
* Chainlink publishes a NAV/reference price for each token (the real stock price times the multiplier). The public Tokenized Stocks API returns addresses, supply, multipliers and reference values with no key.
* About 50 stocks on Base today; Base's goal is about 500.

## 2. Who already does what

| Product | Chain | What it does | Overlap with our ideas |
|---|---|---|---|
| **Bankr indexes** (partner) | Base, Robinhood | Index token = ERC-20 holding a basket of 2–20 stock or crypto tokens, through a Uniswap v4 hook. Buying mints shares against the basket, selling burns them, and any holder can redeem for the basket at any time (cannot be paused). Creator sets a 0.25–1% fee; Bankr keeps 40%; the rest is split between creator and holders, and the holder part is added to backing over 24 hours. Rebalances by public Dutch auction with 48-hour notice and a 1% loss budget. | **Covers "theme index" launches fully.** |
| **Bankr index-paired launches** | Base | A meme token's pool is quoted in an index token instead of WETH (launched through Doppler). Creator fees can arrive in the index and be redeemed for real stock tokens. | Covers "meme trades against a basket of stocks". |
| **BaseStonk** (partner) | Base, Robinhood | Live Uniswap v4 pool from block one, no bonding curve. Pair with stocks, stables or other tokens. 4,500+ launches. Fee share for creators. | Covers plain stock-paired launches. |
| **Stonks Exchange** (partner) | Base | Single-sided Uniswap v3: pool opens 100% meme, 0% stock, and builds stock inventory through trading. Fees buy back $STONKEX. | Same. |
| **Feel.cash** (partner) | Base, Robinhood | Stock-paired launches. Backed by Coinbase Ventures and Lattice. | Same. |
| **o1 Exchange** (partner) | Base, Solana, Robinhood | Trading terminal plus launchpad. Raised $4.2M; 45% cashback, 41% referral share. | Same. |
| **LONG.xyz** | Robinhood | Every launch accumulates its paired stock through trading. Leader $AI (paired with NVDA, about $280M). | Closest to a "stock reserve" launch. |
| **Pons** | Robinhood | Largest stock-meme factory; custom quote assets including ETFs; bonding curve then Uniswap. | — |
| **Baseline Markets** | (migrated) | Tokens with their own AMM and bonding curve that give every token a **floor price**, plus staking for fees, borrowing with no expiry and leverage without liquidation. Floor is in ETH, not stocks. | **Prior art for the "floor" mechanism.** |
| Community projects (IPOD, Delivery Guy, Blue Chip, Timu) | Base | Route fees to a treasury or buybacks, airdrop stock tokens to holders, raffles. Rules are informal. | Covers "fees buy stock for holders" informally. |

## 3. The problem nobody has fixed: the weekend float squeeze

On Sunday August 30, 2026, the meme $BONER was paired against tokenized HIMS on Robinhood Chain. Its pool held most of the HIMS token supply, so every dollar of meme demand had to buy HIMS first. With markets closed, no new HIMS tokens could be minted, and the onchain price reached $61.15 against a real Friday close of $28.84 (more than double). When minting reopened Monday at 00:00 UTC, 18,750 new tokens were sold into the pools and the premium went from 93% to 12% in 12 minutes and to zero within two hours. People who bought the stock token above its real value on Sunday lost the difference.

Lessons from the write-up:

* A stock token's onchain price only equals its real value while minting is open.
* Thin pools against an outside reference price let a meme push the stock token far away from its real price.
* Stock-paired launchpads today do nothing about it.

Base's own brief for idea 1.1 asks builders to "show... what happens when stock-market liquidity shifts." This is that problem.

## 4. What this changes in our earlier ideas

* **Theme-index launchpad:** drop it. Bankr, a partner, ships this already with redemption, rebalancing and fee sharing.
* **Floor launchpad (stock-backed floor):** narrower than first thought. Baseline has floor-price tokens (in ETH). LONG accumulates the paired stock. Bankr index-paired launches let creators redeem fees into stocks. A floor in stock tokens that rises with volume is still not shipped by anyone we found, but the gap is small and Bankr could add it.
* **New opening:** a launchpad whose pools know the real stock price (Chainlink NAV) and market hours, so memes can trade against stocks 24/7 without cornering the stock supply. No one we found does this.

## 5. Sources

* base.org/stocksmaxxing; base.org/AGENTS.md
* docs.base.org/build-on-base/integrate-defi/list-tokenized-stocks
* docs.chain.link/data-feeds/tokenized-equity-feeds/coinbase
* docs.bankr.bot (index tokens, index-paired launches, index contracts); bankr.bot/indexes
* baseline.markets/docs (migration FAQ)
* x.com/Nick_Researcher/status/2097983027528020351 (list of stock-meme launchpads, 2026-09-10)
* defiprime.com/tokenized-stock-float-squeeze (2026-08-31)
* techflowpost.com/en-US/article/34809 (Base Meme Summit recap)
