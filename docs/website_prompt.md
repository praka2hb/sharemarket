# Prompt: build the website

Copy everything below the line into a new chat. It is self-contained.

---

You are building the frontend for a two-person team's entry to Base's "Stocks Maxxing" competition (tokenized stocks on Base). The smart contracts are finished, tested and deployed on **Base Sepolia**. Your job is the website. It must feel like a real trading product that a judge opens, understands in 10 seconds, and can use in under a minute with no help.

Work in `/Users/prakash/baseday/app` (create it). The contracts live in `/Users/prakash/baseday/contracts` and the deployed addresses in `/Users/prakash/baseday/deployments/base-sepolia.json`. Read both before you write code. Don't change anything in `contracts/`.

## 1. What the product is

**One line:** split a big tech stock into its businesses, and trade each one.

* A user deposits **1 stock token** and gets **1 of each piece**:
  * **Alphabet (GOOGLc):** `$SEARCH`, `$YOUTUBE` (YouTube ads), `$CLOUD`.
  * **Nvidia (NVDAc):** `$HYPERSCALE` (big-tech clouds buying Nvidia), `$AICLOUD` (AI clouds, sovereign AI, enterprise), `$EDGE` (gaming, workstations, cars, robots).
* Handing back 1 of each piece always returns exactly 1 stock token.
* **Each piece trades on its own Uniswap v4 pool** against its stock token. If people believe in Google Cloud, they buy `$CLOUD` and its price rises.
* **A piece's price in stock tokens reads as the market's view of that business's share of the company.** `$CLOUD` at 0.29 means "the market thinks Cloud is worth 29% of what the three pieces cover".
* **The pieces' prices sum to about 1 stock token.** If they sum to more, anyone can split and sell every piece for a profit; if less, buy one of each and merge. Show the live sum. It's a clean proof that the prices are anchored.
* **There is no settlement, no expiry, no payout and no admin.** The pieces trade forever. The vaults can't be paused or drained by anyone. Never describe it as a prediction market or say it pays out on earnings.
* **Who it's for:** someone with a view on *which part* of a company will win. "Cloud beats Search." "AI clouds will grab share from hyperscalers." It lets them act on that view without leaving the stock. Holding one of each piece is the same as holding the stock.

**Testnet honesty (show it clearly, not hidden):**
* On Base Sepolia, GOOGLc and NVDAc are **mock** tokens the team deployed. They copy the real Coinbase B20 tokens' rules (8 decimals, an issuer blocklist, pause), but they aren't real stock. Real GOOGLc and NVDAc exist on Base mainnet.
* Contracts are unaudited.
* Prices come only from trading. They aren't tied to the companies' reported numbers and can drift.
* `$YOUTUBE` tracks YouTube **ads** only: Premium and Music subscriptions aren't reported on their own.
* The pieces don't cover every line. Alphabet's Network ads, subscriptions/devices and Other Bets stay inside the stock token, and traders price them into the pieces.

## 2. Chain, addresses and contracts

* **Chain:** Base Sepolia, chain id **84532**, RPC `https://sepolia.base.org`, explorer `https://sepolia.basescan.org`.
* **Addresses:** load them from `deployments/base-sepolia.json` (generate `app/lib/addresses.ts` from it; don't hardcode addresses in components). Its shape:

```json
{
  "chainId": 84532,
  "poolManager": "0x05E7…3408",
  "policyRegistry": "0x…",
  "faucet": "0x…",
  "GOOGL": { "stock": "0x…", "vault": "0x…", "router": "0x…",
             "pieces": ["0x…", "0x…", "0x…"],
             "symbols": ["SEARCH-GOOGL", "YOUTUBE-GOOGL", "CLOUD-GOOGL"] },
  "NVDA":  { "stock": "0x…", "vault": "0x…", "router": "0x…",
             "pieces": ["0x…", "0x…", "0x…"],
             "symbols": ["HYPERSCALE-NVDA", "AICLOUD-NVDA", "EDGE-NVDA"] }
}
```

* **Uniswap v4 on Base Sepolia:**
  * PoolManager `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`
  * StateView `0x571291b572ed32ce6751a2cb2486ebee8defb9b4`
  * Quoter `0x5e6B8B8AFA7e5CEF6C09dd2A67aBA9FB12C75623`
* **Every token has 8 decimals.**
* **ABIs:** take them from `contracts/out/<Name>.sol/<Name>.json` (`.abi`) for `SegmentVault`, `SegmentRouter`, `PieceToken`, `MockB20` and `Faucet`. If `out/` is missing, run `cd contracts && base-forge build`. Use standard Uniswap v4 ABIs for StateView and Quoter.

### Functions you'll call

**Faucet**
* `claim()`: gives the caller **20 GOOGLc and 20 NVDAc** (mock). Once per 24 hours per address.
* `lastClaim(address)`, `COOLDOWN()`.
* Reverts `TooSoon(uint256 nextClaimAt)`. Show a countdown.

**Vault** (`SegmentVault`, one per stock)
* `split(uint256 amount, address to)`: pulls `amount` stock (needs approval to the vault) and mints `amount` of every piece to `to`.
* `merge(uint256 amount, address to)`: burns `amount` of every piece from the caller and sends `amount` stock to `to`. No approval needed.
* `pieceCount()`, `piece(i)`, `pieces()`, `collateralToken()`, `setsOutstanding()`.
* Events `Split(user, to, amount)`, `Merged(user, to, amount)`. Errors `ZeroAmount()`, `TransferMismatch()`.

**Router** (`SegmentRouter`, one per stock). Every call takes a minimum-out and a deadline (unix seconds).
* `buy(uint256 piece, uint256 stockIn, uint256 minPieceOut, uint256 deadline) → pieceOut`: needs stock approved to the router.
* `sell(uint256 piece, uint256 pieceIn, uint256 minStockOut, uint256 deadline) → stockOut`: needs that piece approved to the router.
* `poolKey(uint256 piece) → PoolKey`: piece/stock, fee 3000, tick spacing 60, hooks = zero address.
* `FEE()`, `TICK_SPACING()`.
* Events `Bought(user, piece, stockIn, pieceOut)`, `Sold(user, piece, pieceIn, stockOut)`.
* Errors: `DeadlinePassed()`, `ZeroAmount()`, `BadPiece()`. Slippage failures are Uniswap's `V4TooLittleReceived(min, received)`.

**Mock stock tokens** (`MockB20`): ERC-20 plus `pausedFeatures() → uint8[]` (non-empty means paused) and `multiplier()`. Errors: `FeaturePaused(uint8)`, and `PolicyForbids(address)` when the issuer has blocked that address.

### Reading prices

* **Pool id** = `keccak256(abi.encode(poolKey))`. Compute it with viem's `encodeAbiParameters` + `keccak256` from `router.poolKey(i)`.
* **Spot:** `StateView.getSlot0(poolId) → (sqrtPriceX96, tick, protocolFee, lpFee)`. Pool price `p = (sqrtPriceX96 / 2^96)^2` is **currency1 per currency0**:
  * if the piece is currency0, piece price in stock = `p`;
  * otherwise it's `1 / p`.

  Check which by comparing addresses: the lower address is currency0. Use bigint math for anything you send on-chain.
* **Quotes:** `Quoter.quoteExactInputSingle({poolKey, zeroForOne, exactAmount, hookData: "0x"}) → (amountOut, gasEstimate)`. It isn't a view function, so call it with `simulateContract` or `eth_call`.
* **Slippage:** default 0.5%, adjustable. `minOut = quote × (1 − slippage)`. Deadline = now + 10 minutes.
* **History:** read the PoolManager `Swap` events for each pool id (topic1) to draw price charts. Never fake data; a sparse chart is fine.

### Reported mix (information only, shown next to market prices)

Each line's share of the pieces' combined reported revenue. Label it clearly as information that doesn't affect any payout.

| Market | Piece | Year earlier | Latest |
|---|---|---|---|
| GOOGL | `$SEARCH` | 69.0% (Q3 2025) | **60.2%** (Q3 2026) |
| GOOGL | `$YOUTUBE` (ads) | 12.5% | **10.6%** |
| GOOGL | `$CLOUD` | 18.5% | **29.2%** |
| NVDA | `$HYPERSCALE` | 51.7% (Q2 FY26) | **50.6%** (Q2 FY27) |
| NVDA | `$AICLOUD` | 36.2% | **41.9%** |
| NVDA | `$EDGE` | 12.1% | **7.5%** |

Sources: `docs/research/alphabet_earnings_disclosure.md` and `docs/research/nvidia_earnings_disclosure.md`. The trend ("Cloud went from 18% to 29% in a year") is a strong hook. Use it.

## 3. Pages and flows

### `/`: Markets (the landing page; most judges see only this)

* **Hero:** "Trade the parts of big tech." Two market cards, **Alphabet** and **Nvidia**. Each card has:
  * a big **split bar**, one bar divided into three coloured segments sized by live market prices;
  * a thin marker row underneath showing the reported mix for comparison;
  * the live sum of prices ("Σ 1.002 GOOGLc").
* Clicking a card or a segment goes to that market.

### `/[stock]`: Trade (GOOGL or NVDA)

* **Header:** the split bar (big and animated), three piece tiles (price, 24h change from swap history, reported share), and the live price sum.
* **Trade panel:** pick a piece (tabs coloured by piece), then **Buy / Sell**.
  * Amount input with MAX, live quote, price impact, minimum received, the 0.30% fee and slippage.
  * One primary button that walks through the needed steps: Connect → Switch to Base Sepolia → Get test tokens (if the balance is 0) → Approve (exact amount, and say so) → Trade.
* **Split / Merge panel:** split stock into all three, or merge all three back. Show "N full sets = N stock, mergeable now".
* **Faucet:** a clear "Get 20 GOOGLc + 20 NVDAc" button with a cooldown timer, impossible to miss when the balance is zero.
* **"What is this piece?"** One plain sentence per piece, its reported share now and a year ago, and a link to the research doc.

### `/portfolio`

* Balances of both stocks and all six pieces, valued in their stock token at current prices.
* Full sets mergeable per stock.
* Recent activity from router and vault events, with explorer links.

### `/how-it-works`

* A three-step visual: deposit 1 stock → get 1 of each business → trade the ones you believe in; merge any time.
* **Worked example:** "You think Cloud keeps winning. You buy `$CLOUD` at 0.29 GOOGLc. Others agree, and it reaches 0.35. Your `$CLOUD` is worth 21% more GOOGLc, while someone who sold `$SEARCH` early avoided its drop."
* **Why prices stay honest:** the split-and-sell / buy-and-merge arbitrage, in plain words.
* **Why no settlement:** prices come from traders, and nothing forces them toward reported numbers.

### `/proof`

Live from chain, refreshing on its own, per market:
* the stock token held by the vault against the supply of each piece. All must be equal, so show a green check when they are.
* the contract addresses with explorer links;
* a note that there's no admin, no pause and no withdraw: stock only leaves through merge.

### `/risks`

* the mock tokens on testnet;
* unaudited contracts;
* prices not tied to reported numbers;
* thin liquidity and price impact, especially on `$YOUTUBE` and `$EDGE`;
* the issuer can pause or blocklist the real stock tokens, which would freeze transfers;
* `$YOUTUBE` is ads only;
* uncovered lines stay inside the stock;
* other pools for these tokens may exist elsewhere.

### Global

* A header with the logo, nav, network badge ("Base Sepolia · testnet") and connect button.
* **A paused banner** if a stock's `pausedFeatures()` is non-empty.
* **On `PolicyForbids`:** explain the issuer block and offer merge to another address.
* **Turn every revert into a human sentence:**
  * `TooSoon`: show the countdown;
  * `V4TooLittleReceived`: "price moved, raise slippage or retry";
  * `DeadlinePassed`, `BadPiece`;
  * insufficient balance or allowance;
  * wrong network.
* **After each transaction:** a pending state, then success with the amounts actually received (decoded from events) and an explorer link.

## 4. Design direction ("banger", not generic)

* **Feel:** a sharp trading terminal crossed with an editorial finance site, confident and calm. Avoid the default AI look (purple-blue gradients, glassmorphism everywhere, emoji icons).
* **The split bar is the signature.** Make it big, tactile and animated; reuse it as the logo idea of one bar in coloured segments. Segment widths animate when prices move.
* **Colour:** one distinct colour per piece, consistent everywhere (bar, tabs, charts, balances):
  * GOOGL: Search, YouTube and Cloud;
  * NVDA: Hyperscale, AI Cloud and Edge;
  * near-black or warm off-white backgrounds, with both light and dark mode;
  * green and red only for up and down.
* **Type:** a strong grotesk for UI (Inter Tight, Geist or similar) and a monospace with tabular figures for every number.
* **Motion:** 150–250ms ease-outs for price ticks, bar resizing and tab changes. Respect `prefers-reduced-motion`.
* **Numbers:** always with units (GOOGLc, NVDAc, %). 4 decimals for prices, up to 4 for balances, trimming trailing zeros. Never show raw 8-decimal integers.
* **Mobile first:** the trade panel works one-handed at 375px.
* **Accessibility:** contrast AA, focus states, labelled inputs, keyboard navigation.
* **Logos:** design simple SVG marks for each piece and each mock stock token in the piece colours. **Don't use Google, YouTube, Alphabet or Nvidia logos or brand marks.**

## 5. Tech

* **Next.js (App Router) + TypeScript + Tailwind, wagmi v2 + viem.** Pin exact versions.
* **Wallets:** Coinbase Smart Wallet (OnchainKit) first, since the competition is on Base, plus injected wallets (MetaMask, Rabby).
* **Reads:** batch with multicall. Refresh prices every ~10s or on new blocks. No backend, no indexer.
* **Make the markets data-driven:** a `markets` config built from the deployments JSON plus a small metadata file (piece colours, one-line descriptions, reported mix). Adding a third stock later should be config only.
* **File layout:**
  * `app/lib/addresses.ts`, `app/lib/markets.ts`, `app/lib/abis/*`;
  * `app/lib/math.ts` (sqrtPrice → price for either token order, minOut, formatting);
  * `app/lib/quotes.ts`;
  * `app/hooks/*` (useMarket, useBalances, usePrices, useTrade with an approve-then-trade state machine);
  * `app/components/*`.
* **Unit tests** for `math.ts`: price from sqrtPriceX96 in both token orders, minOut, and 8-decimal formatting.
* **Deployable to Vercel** with no secrets. An optional `NEXT_PUBLIC_RPC_URL` can override the public RPC.

## 6. Definition of done

1. A fresh wallet on Base Sepolia can do all of this in the deployed app without reading docs:
   * claim test tokens;
   * buy and sell every piece in both markets;
   * split and merge.

   Received amounts must match quotes within slippage.
2. The landing page shows both markets' live split bars and price sums from the real pools. The Proof page shows each vault fully backed, all read from chain.
3. Every error state above shows a clear human message.
4. Lighthouse 90+ on performance and accessibility on mobile.
5. A short `app/README.md` covering how to run locally, how to deploy, and where addresses and ABIs come from.

Before writing code, read `contracts/src/SegmentVault.sol`, `contracts/src/SegmentRouter.sol`, `deployments/base-sepolia.json`, `docs/decisions/0001-drop-settlement.md` and `docs/decisions/0002-three-pieces-and-nvda.md`, then show me a short plan of pages and components. Then build page by page, starting with `/`, and run it locally to check each flow against Base Sepolia.
