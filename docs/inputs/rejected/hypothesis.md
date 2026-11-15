# Working hypothesis: NAV-aware stock-paired launchpad on Base

## Context

* Competition: Base "Stocks Maxxing", Nov 5 – Dec 5, 2026, $100K+ prizes. Track 1 "Meme and Community Economies" has 7 partners, most of them launchpads (o1 Exchange, BaseStonk, Stonks Exchange, Feel.cash, Hydropump, Bankr). Base idea 1.1 asks for a token that trades against a stock token and to "show both prices, the pool's two-sided exposure, and what happens when stock-market liquidity shifts", with "launch → trading → any pool migration, with clear fees and the underlying asset's restrictions intact".
* Team: two people with prior experience building a launchpad. About 3 weeks of build time left. They want something that can grow a real user base, not a generic launchpad.
* Market research (competitors, stock-token rules, the HIMS weekend squeeze) is in `market_research.md` in the same folder. Read it.

## The concept

A stock-paired meme launchpad on Base, built as a Uniswap v4 hook. Each launched meme token trades against one Coinbase stock token (B20, e.g. NVDAc). The pool reads Chainlink's NAV/reference price for that stock token and knows whether the US market is open.

1. **Drift-based fee.** When the stock token's onchain price moves away from its NAV by more than a threshold (e.g. 5%), the pool fee rises with the gap. The extra fee goes to the meme's floor vault instead of to whoever bought at the inflated price.
2. **Float cap.** One meme pool may not hold more than a set share (e.g. 10%) of the stock token's total supply. Buys that would push past it are limited or rerouted.
3. **Market-hours display.** The UI shows "market closed – onchain price may not match the real price", with the live gap.
4. **Stock-backed floor vault.** A share of each buy (e.g. 10–20%) and of fees goes into a vault of the stock token. Any holder can burn meme tokens for a pro-rata share of the vault, so each meme has a floor that rises with volume. The vault is valued at NAV.
5. **Launch flow.** Bonding curve then graduation to a Uniswap v4 / Aerodrome pool (exact venue open).

## Success criteria

A mainnet demo by Dec 5: launch → trading → a simulated replay of a HIMS-style weekend squeeze being contained → a holder redeeming at the floor. Also: one or more partner launchpads interested in using the hook as a module.

## Known open questions

* Is redemption-for-stock legally a fund or security? Stock tokens are not for US persons; how is that respected?
* What happens when the Chainlink feed pauses for corporate actions (splits)?
* Do higher fees during drift also block the arbitrage that would close the gap?
* Can stock tokens (with issuer transfer policies and pauses) be held by the vault and the v4 PoolManager?
* Does a safety feature make memes boom, or does it need the floor to attract users?
* Overlap with Bankr index-paired launches, Baseline floor tokens, and LONG.xyz.
