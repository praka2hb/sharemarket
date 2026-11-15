# G0 findings (facts check)

* **Date:** 2026-11-14, read at Base mainnet block 57,298,792
* **Covers:** the G0 items in `docs/designs/cloud_share_market_gates.md` that can be checked without people:
  * GOOGLc facts;
  * Uniswap v4 addresses;
  * Alphabet share history;
  * the Q4 question.
* **Not covered here:** trader interviews and the Track 3 question to the organisers.

## Summary

| Question | Answer | Effect on the design |
|---|---|---|
| Can contracts hold GOOGLc? | **Yes.** The transfer policy is a blocklist; any address passes unless the issuer adds it. | The gate passes. The risk that the issuer blocks the vault later remains. |
| Is GOOGLc a precompile? | **Yes.** Its onchain code is the single byte `0xef`. | Fork tests run with Base's Foundry build (`base-forge`). The fork test passes 5 of 5 (section 1.4). |
| Do balances change with the multiplier? | No sign of it: `multiplier()` is a separate value (WAD, 1.000377 today) and `balanceOf` is a plain balance. The full check needs the fork test. | Count in token units, as planned. |
| Decimals | **8** | Piece tokens use 8 decimals. The mock must use 8, not 18. |
| Anything paused? | **No.** `pausedFeatures()` returns an empty list. | — |
| Uniswap v4 on Base Sepolia? | **Yes.** PoolManager, PositionManager, Quoter, StateView and Universal Router all have code. | Pool venue confirmed. Universal Router can cover `buyCloud` and `sellCloud` if needed. |
| Q4 segment revenue on its own? | **Yes.** Q4 earnings releases print "Quarter Ended December 31" segment revenue. | Settling on the 8-K earnings release works for every quarter. Drop the "full year minus nine months" fallback. |
| How much does Cloud's share move? | **Far more than assumed:** +2.5 to +3.4 points per quarter in 2026, up from about +0.5–0.7 in 2025. | The "small bet" objection no longer holds. The 3-point sanity band and the ±3-point pool range are too tight (section 4). |

## 1. GOOGLc

### 1.1 Identity

* **Address:** `0xb2000000000000000000002D0BA3164cc74f58B7`. Source: Coinbase Tokenized Stocks API (`https://api.coinbase.com/v1/tokenized-stocks`), confirmed onchain.
* **Name and symbol:** "Alphabet Inc.", `GOOGLc`. 8 decimals.
* **Total supply:** 35,372.00982128 tokens. At the API's reference price of $294.89 that is about **$10.4M**, so the whole float is small.
* **Multiplier:** 1.000377118676784179 (WAD), from both the API and `multiplier()`.
* **First minted:** 2026-08-12.
* **Metadata:** `contractURI()` returns `https://api.coinbase.com/v1/tokenized-stocks/metadata/GOOGLc`.
* **Legal description in the API:** a certificate issued by Coinbase Onchain SPV Ltd (ADGM), not a direct share. Dividends are reinvested through the multiplier.

### 1.2 It is a precompile

* `cast code` returns `0xef`: one byte, no bytecode.
* Base's docs say tokenized stocks "are B20 native precompiles, not separately deployed contracts".
* **Effect:** a fork test on Foundry before 1.8.4 cannot run GOOGLc calls. Base's docs say Foundry v1.8.4 and later runs B20 precompiles natively in forge, cast, anvil and chisel. Base also maintains `base-anvil`.

### 1.3 Transfer policy and pause

* The three transfer scopes all use **policy ID 5**:
  * `TRANSFER_SENDER_POLICY`;
  * `TRANSFER_RECEIVER_POLICY`;
  * `TRANSFER_EXECUTOR_POLICY`.
* `policyExists(5)` is true on the PolicyRegistry (`0x8453000000000000000000000000000000000002`).
* The top byte of ID 5 is `0x00`, which marks a **BLOCKLIST**.
* `isAuthorized(5, x)` returns true for every address tried:
  * the Uniswap v4 PoolManager;
  * `0x…dEaD`;
  * an arbitrary unused address;
  * the zero address.

  A new vault, the PoolManager and a router can all hold GOOGLc.
* `pausedFeatures()` returns an empty list: nothing is paused.
* **Executor policy applies to every transfer.** Per the B20 reference (BaseHub, third-party, not yet confirmed in Base's own docs), after the "Denim" upgrade the executor policy runs on every `transfer` and `transferFrom`, including the caller. With a blocklist this changes nothing unless the caller is blocked.

**Exact interface names, for `IB20.sol` (file 4):**
* `multiplier()`;
* `pausedFeatures()`, which returns an array;
* `isPaused(feature)`, whose exact argument type is still unconfirmed;
* `TRANSFER_SENDER_POLICY()`, `TRANSFER_RECEIVER_POLICY()` and `TRANSFER_EXECUTOR_POLICY()`, each returning a `bytes32` scope;
* `policyId(bytes32 scope)`, which returns `uint64`.

**Exact interface names, on the PolicyRegistry:**
* `isAuthorized(uint64 policyId, address account)`, which never reverts;
* `policyExists(uint64)`.

The design's `paused()` and `policyId()` with no arguments do not exist; both calls revert.

### 1.4 Fork test: passes (5 of 5)

* **Test:** `contracts/test/fork/GOOGLcFork.t.sol`, pinned to Base mainnet block 57,298,792.
* **Holder used:** it impersonates a real holder, `0x16c70F04C3080a127486Cdf5a4C33c066bBF47C3`, a contract holding about 3,877 GOOGLc. No balances are minted.
* **What passed:**
  * GOOGLc is a precompile (code `0xef`) with 8 decimals.
  * Nothing is paused.
  * All three transfer scopes use policy 5, a BLOCKLIST. A new contract, the v4 PoolManager, the Universal Router and a fresh address are all authorized.
  * **A contract vault round trip moves exact amounts.** The holder approves, and the vault pulls 10 GOOGLc with `transferFrom`, so the vault is the executor. The vault then pays them to a fresh address with `transfer`. Balances are exact at each step, and the multiplier is unchanged.
  * Direct transfers to the PoolManager and the Universal Router succeed.
* **Toolchain:**
  * Run with Base's Foundry build: `base-forge test --match-path test/fork/GOOGLcFork.t.sol -vv` in `contracts/`. `base-forge` reports `1.6.0-v1.1.0`; it enables Base precompiles by itself.
  * Homebrew Foundry 1.9.0 cannot run it: it is built without the `base` feature, so every precompile call reverts.
* **Install note:** `base-foundryup` refuses to install while any process named `anvil` runs, so stop local anvil nodes first.
* **Not covered:** a multiplier change during the test. The token's multiplier can only be changed by the issuer's role, so balance behaviour across a change is assumed from the B20 design (separate multiplier, plain balances) and will be exercised with the mock token's multiplier in the invariant tests.
* Base Sepolia has the PolicyRegistry and ActivationRegistry precompiles, but the B20 factory address (`0xB20f…0000`, per BaseHub) shows no code there. Issuing a real test B20 on Sepolia is unconfirmed, so the plan keeps the mock token.

## 2. Uniswap v4 addresses (from Uniswap's deployment page, each confirmed to have code)

| Contract | Base mainnet | Base Sepolia |
|---|---|---|
| PoolManager | `0x498581ff718922c3f8e6a244956af099b2652b2b` | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| PositionManager | `0x7c5f5a4bbd8fd63184577525326123b519429bdc` | `0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80` |
| Quoter | `0xE1A6C5803e3c44368b171BD680c7D32dfc92CA47` | `0x5e6B8B8AFA7e5CEF6C09dd2A67aBA9FB12C75623` |
| StateView | `0xa3c0c9b65bad0b08107aa264b0f3db444b867a71` | `0x571291b572ed32ce6751a2cb2486ebee8defb9b4` |
| Universal Router | `0x6ff5693b99212da76ad316178a184ab56d299b43` | `0x492e6456d9528771018deb9e87ef7750ef184104` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | same |

## 3. Alphabet Cloud share history

Full table: `docs/data/googl-cloud-share-history.csv`. Shares are computed with the design's formula, floor(Cloud × 1,000,000 ÷ (Cloud + Services)).

| Quarter | Services ($M) | Cloud ($M) | Cloud share | Change |
|---|---|---|---|---|
| 2023 Q4 | 76,311 | 9,192 | 10.75% | |
| 2024 Q4 | 84,094 | 11,955 | 12.45% | +1.70 over 4 quarters |
| 2025 Q1 | 77,264 | 12,260 | 13.69% | +1.25 |
| 2025 Q2 | 82,543 | 13,624 | 14.17% | +0.47 |
| 2025 Q3 | 87,052 | 15,157 | 14.83% | +0.66 |
| 2025 Q4 | 95,862 | 17,664 | 15.56% | +0.73 |
| 2026 Q1 | 89,637 | 20,028 | 18.26% | +2.70 |
| 2026 Q2 | 94,540 | 24,768 | 20.76% | +2.50 |
| 2026 Q3 | 96,302 | 30,709 | 24.18% | +3.42 |

**Gaps:**
* 2024 Q1–Q3 are not collected yet.
* Two accession numbers, for 2025 Q2 and 2026 Q2, still need recording.
* The SHA-256 hashes of each exhibit need computing from the EDGAR files. EDGAR asks automated clients for a contact User-Agent, so this is left for the team to run with their own contact.

**What changed in the business:**
* Cloud grew 103% year on year in Q3 2026.
* Alphabet's segment description now says Google Cloud also earns "product revenues primarily from the sale of TPU systems".
* Hardware sales are lumpier than subscriptions, so expect larger and less predictable swings in the share.

**Surprise size:** in Q2 2026, Cloud revenue was $24.8B against a StreetAccount estimate of $22.24B (CNBC), about 11% above forecast. A surprise that size moves Cloud's share by roughly 2 points, about **10% on `$CLOUD`** at settlement.

## 4. What this means for the design (applied to `docs/designs/cloud_share_market.md` on 2026-11-14)

1. **Pitch.**
   * The bet is no longer small. At today's pace, Cloud's share moves 2.5–3.4 points a quarter, and a typical surprise moves `$CLOUD` around 10%.
   * Drop the "small bet" wording in The Problem. Replace the worked example's 15.0% → 15.5% with real 2026 numbers, for example 20.76% → 24.18%, which is +16% against GOOGL.
2. **Sanity band.**
   * The 3-point band (30,000 ppm) would have sent the honest Q3 2026 settlement (+3.42) straight to Disputed.
   * **Applied: 10 points (100,000 ppm).** The design measures the band against the quarter's fallback share, which can be two quarters old. The largest honest two-quarter move so far is 5.9 points (Q1 to Q3 2026), so 8 points would leave too little margin.
3. **Pool range.**
   * "Last settled share ± 3 points" is centred in the wrong place. The fallback share is two quarters old, and the trend adds about 3 points a quarter.
   * Centre the main range on the last settled share plus the recent trend, about 3 points per quarter for each quarter since that share was settled. Make it ±5 points, and widen the backstop to 10%–45%.
4. **Fallback share.**
   * Fixing it at creation from the share two quarters back puts it about 6 points below reality at today's growth.
   * The fallback is meant to be rare, so this is acceptable, but say so in the rule document.
5. **`IB20.sol` (file 4).** Use the real names in section 1.3. Remove `paused()` and `policyId()`. `isAuthorized` lives on the PolicyRegistry, not the token.
6. **Mock token (file 10).** 8 decimals, a blocklist policy, and the same function names as above.
7. **Toolchain.** Use Base's Foundry build (`base-forge`, installed with `base-foundryup`) in the README and CI. The Homebrew build cannot run B20 precompiles.
8. **Rule document.**
   * State that Q4 uses the Q4 earnings release's "Quarter Ended December 31" columns.
   * Remove the "full year minus nine months" fallback from Open Questions.
   * Add a line on TPU product sales: they count as Cloud, as Alphabet reports them.
