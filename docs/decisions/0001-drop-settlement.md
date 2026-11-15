# 0001: Drop settlement; the pieces trade forever

* **Date:** 2026-11-15
* **Status:** Decided by the team
* **Replaces:** the settlement parts of `docs/designs/cloud_share_market.md` (quarterly series, FilingResolver, CloseHook, fallback share, dispute replay) and the settlement gates in `cloud_share_market_gates.md`.

## Decision

`$CLOUD` and `$SERVICES` no longer settle on Alphabet's earnings. There is one perpetual pair:

* Deposit 1 GOOGLc and get 1 `$CLOUD` + 1 `$SERVICES`. Return 1 of each and get 1 GOOGLc back.
* No quarters, no expiry, no closing, no payout, no arbiter, no admin.
* Prices come only from trading on one Uniswap v4 pool, `$CLOUD` / GOOGLc, with no hook.
* `$CLOUD`'s price in GOOGLc reads as the market's view of Cloud's share of Alphabet.

## Why

* The team wants a market that trades on conviction, like a stock, not one that is scored and closed. With settlement it was, at its core, a prediction market.
* Settlement forced trading to close before each result, which confused the pitch.
* It is simpler to build, explain and trust: no arbiter, no bonds, no fallback share.

## What we accept

* **The price is not tied to Alphabet's reported numbers.** `$CLOUD` can sit far from Cloud's real share, and nothing pulls it back. The pieces are worth what other traders pay.
* **It is close to Daybreak's free-floating model.** The pitch needs a clear answer to "how is this different?"
* **Thin markets drift.** With few traders, small trades move the price a lot.
* Split and merge still keep `$CLOUD + $SERVICES ≈ 1 GOOGLc`, so the pair together always tracks Alphabet.

## What changed in the code

* `SegmentVault`: one pair created in the constructor; only `split(amount, to)` and `merge(amount, to)`.
* `SegmentRouter`: `buyCloud`, `sellCloud`, `buyServices` on the single hookless pool.
* Removed (kept in `archive/settlement-v1/`): `FilingResolver`, `CloseHook`, series types, mock USDC, the settlement rule, the replay and create-series scripts, and the first Base Sepolia deployment record.
* The faucet now hands out mock GOOGLc only.
* The pool opens at 24.18% (Alphabet's last reported Cloud share), with a main range of ±10 points and a 5%–60% backstop.

## Open option

Post Alphabet's reported Cloud share on-chain each quarter, as information only, so the app can show "market says X%, Alphabet reported Y%". It would not move any money. Not built.
