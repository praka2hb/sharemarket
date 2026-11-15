# ShareMarket — app

The website for ShareMarket: split a stock token into one piece per reported business line and trade each piece on Base Sepolia.
Live markets: GOOGLc → `$SEARCH` + `$YOUTUBE` + `$CLOUD`, and NVDAc → `$HYPERSCALE` + `$AICLOUD` + `$EDGE`.
No backend, no indexer: every number is read straight from the chain.

## Run locally

```bash
cd app
npm install
npm run dev        # http://localhost:3000
npm test           # unit tests for lib/math.ts
npm run build      # production build (also re-syncs addresses/ABIs if ../contracts is present)
```

You need a wallet on **Base Sepolia (84532)** with a little test ETH for gas
([Coinbase faucet](https://portal.cdp.coinbase.com/products/faucet)). The app's own faucet gives 20 mock GOOGLc and 20 mock NVDAc per day.

## Deploy (Vercel)

1. Import the repo in Vercel and set **Root Directory** to `app`.
2. Framework preset: Next.js. No secrets are required.
3. Optional environment variables (see `.env.example`):
   - `NEXT_PUBLIC_RPC_URL`: RPC for reads and writes (default `https://sepolia.base.org`).
   - `NEXT_PUBLIC_LOGS_RPC_URL`: RPC for event history. Base's public RPC caps `eth_getLogs` at 200 blocks, so the
     default is the Tenderly public gateway with publicnode as a fallback.
   - `NEXT_PUBLIC_SITE_URL`: canonical URL for social previews.

## Where addresses and ABIs come from

`scripts/sync-contracts.mjs` runs before every build and copies:

- addresses from `../deployments/base-sepolia.json` → `lib/addresses.ts` (one entry per market, plus the deploy block from the latest broadcast)
- ABIs from the Foundry build output `../contracts/out/<Name>.sol/<Name>.json` → `lib/abis/<Name>.ts`
  (`SegmentVault`, `SegmentRouter`, `PieceToken`, `MockB20`, `Faucet`)

The generated files are committed, so the build still works where `../contracts/out` is missing (e.g. Vercel).
If you redeploy the contracts, run `cd ../contracts && base-forge build`, then `npm run sync`.
Uniswap v4 StateView/Quoter ABIs are hand-written minimal ABIs in `lib/abis/uniswap.ts`.
Names, colours and reported mixes for each piece live in `lib/markets.ts`; pool keys and pool ids are computed there from the addresses.
To add a market: deploy it, add it to the deployments file, run `npm run sync`, and add its pieces to `lib/markets.ts`.

## Layout

| Path | What |
|---|---|
| `lib/markets.ts` | Every live market and its pieces: names, colours, reported mix, pool key and pool id. |
| `lib/math.ts` | sqrtPrice → piece price in stock tokens (bigint, either token order), slippage, price impact, 8-decimal formatting. Tested in `math.test.ts`. |
| `lib/quotes.ts` | Uniswap v4 Quoter calls for buying and selling a piece, via `eth_call`. |
| `lib/errors.ts` | Turns every revert (`TooSoon`, `V4TooLittleReceived`, `DeadlinePassed`, `PolicyForbids`, …) into a sentence. |
| `lib/lazyCoinbase.ts` | Coinbase Smart Wallet connector that loads its SDK only when used (keeps first load light). |
| `hooks/useMarket.ts` | Every pool price, vault backing, piece supplies, pause state for one market: one multicall every 10s. |
| `hooks/useAccountData.ts` | Balances, allowances and full sets for one market; gas and faucet cooldown. |
| `hooks/useTrade.ts` | Quote + step machine: connect → network → gas → faucet → approve (exact) → `router.buy` / `router.sell`. |
| `hooks/useTx.ts` | simulate → sign → wait → decode events → toast. |
| `hooks/useHistory.ts` | Per-piece price history (pool `Initialize` + `Swap` events) and the user's activity across all markets. Never synthesised. |
| `components/SplitBar.tsx` | The signature element: one segment per piece, sized by price, with the reported mix underneath. Tap a segment to trade it. |

## Pages

- `/`: markets list with live piece prices.
- `/markets/googl`, `/markets/nvda`: piece cards and split bar, trade panel (buy/sell any piece), faucet, chart of the selected piece, position, split & merge.
- `/positions`: holdings per market valued in its stock token, full sets you can merge, on-chain activity with BaseScan links.
- `/how-it-works`: four steps and a worked example.
- `/proof`: per market, vault stock balance = every piece's supply, live, plus contract addresses.
- `/risks`: testnet mock, unaudited, price not tied to reports, thin liquidity, issuer pause/blocklist, other pools.

## Verified

- Typecheck, unit tests (`npm test`) and production build pass.
- Against the live Base Sepolia deployment: the six pool ids computed in `lib/markets.ts` match live pools; all six prices load
  (sums 100.00% per market); quotes come back in both token orders (2 GOOGLc → 3.3066 `$SEARCH`; 10 `$EDGE` → 0.7412 NVDAc);
  price history loads from pool events; the proof page shows both vaults fully backed.
- Not yet checked with a connected wallet: approve, buy, sell, split, merge and faucet transactions signed from the UI.
