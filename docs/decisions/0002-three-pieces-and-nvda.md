# 0002: Three pieces per stock, and a second market for NVDA

* **Date:** 2026-11-15
* **Status:** Decided by the team
* **Builds on:** `0001-drop-settlement.md` (pieces trade forever; no settlement).

## Decision

* **The vault splits one stock token into N pieces** (2 to 8), one per business line the company reports. Deposit 1 stock token for 1 of each piece; return 1 of each for 1 stock token.
* **No "other" piece.** With no settlement, nothing pays out by revenue, so the pieces don't need to cover every reported line. Lines without a piece (for Alphabet: Network ads, subscriptions and devices, Other Bets) stay inside the stock token held by the vault, and traders price them into the pieces.
* **Two markets on testnet:**

| Market | Pieces | Opening prices (each line's share of the pieces' combined revenue) |
|---|---|---|
| GOOGL | `$SEARCH`, `$YOUTUBE` (ads), `$CLOUD` | 60.18% / 10.65% / 29.17% (Q3 2026) |
| NVDA | `$HYPERSCALE`, `$AICLOUD`, `$EDGE` | 50.62% / 41.90% / 7.48% (Q2 FY2027) |

  NVDA's pieces follow the only lines Nvidia now reports. Since fiscal 2027 there is no gaming, networking or automotive figure. See `docs/research/nvidia_earnings_disclosure.md`.
* **Each piece has its own Uniswap v4 pool** against its stock token (0.30%, tick spacing 60, no hook). The router does `buy(piece, stockIn, minOut)` and `sell(piece, pieceIn, minOut)`.
* **The pieces' prices stay summing to about 1 stock token through arbitrage.** If the sum is above 1, anyone can split and sell every piece for a profit; if below, buy one of each and merge. A test shows this.

## What we accept

* **Liquidity is spread across six pools** instead of one.
* **Small pieces move a lot on small trades:** `$YOUTUBE` around 0.11, `$EDGE` around 0.07.
* **`$YOUTUBE` tracks YouTube ads only.** YouTube Premium and Music sit in a line that also includes Google One, Play and Pixel.
* **Exiting through merge needs every piece of that stock.**

## Verified

* 29 local tests pass, including random-action tests covering split, merge and buys and sells of every piece.
* Fork tests pass on Base mainnet with real GOOGLc and the real Uniswap v4 PoolManager: split, merge, and buy and sell of each of the three pieces.
* **NVDAc** was checked on Base mainnet: a B20 precompile, 8 decimals, the same blocklist policy 5. **Still to do:** a fork test with real NVDAc, which needs a real holder address to impersonate.
* The deploy and seed scripts were rehearsed on a Base Sepolia fork: both markets deployed, six pools seeded at the prices above, and a test wallet bought and sold every piece.
