# Working hypothesis: segment tokens that settle on SEC filings (Base)

* **Date:** 2026-11-14
* **Team:** two people with prior launchpad experience. Build window about 3 weeks (deadline December 5, 2026).
* **Competition:** Base "Stocks Maxxing" (tokenized stocks on Base). Likely Track 3, "Programmable Stock Markets".
* **Background reading in the same folder:** `market_research.md` (stock-token facts, competitors, the HIMS weekend squeeze). An earlier, rejected concept and its review are in `hypothesis.md` and `concepts_brief_launchpad.md`; they are context only.

## 1. The idea in one sentence

Split one Coinbase stock token into one token per business segment, let people trade the pieces, and after each quarterly report let each piece redeem on its own for that segment's share of revenue, taken from the company's SEC filing (10-Q).

Pitch: "Own the part of the company you believe in. Each quarter, the SEC filing decides what each part was worth."

## 2. Facts the design relies on

* Coinbase stock tokens on Base are "B20" tokens: Base-native, backed 1:1 by real shares at a regulated custodian. Anyone can hold and trade them; KYC happens only at mint/redeem by Authorized Participants. Not offered to US persons.
* The issuer can block transfers per address (`isAuthorized(policyID, account)`) and can pause the token. One token is not always one share: a `multiplier` changes on dividends and splits.
* Base docs list stock tokens including AAPL, AMZN, GOOGL, META, MSFT, MSTR, NVDA, SNDK, SPCX, TSLA. Chainlink publishes a reference price for each.
* No B20 stock tokens or Chainlink stock feeds were found on Base Sepolia (testnet), so a testnet demo needs mock tokens.
* Supply on Base is small. Example: NVDAc is about $7M in total, 76% held by five wallets. GOOGLc depth is unknown.
* Alphabet's last reports were in late October 2026; its next report is around early February 2027, after the deadline. Nvidia reports November 17, 2026. No live settlement on the demo stock happens before December 5.

## 3. Direct competitor: Daybreak

From Daybreak's launch page (Alliance accelerator): Daybreak "splits tokenized equities into segments reported by the company". Users trade individual businesses. Anyone holding an equal amount of every piece can redeem them together for shares at any time. Examples given: YouTube, Search and Waymo inside Google; Optimus inside Tesla. The page names no chain (founder previously at the Solana Foundation) and **mentions no settlement based on company results**. We could not read their docs.

Our only claimed difference: **each piece pays out on its own, based on the filed segment numbers**. Daybreak pieces (as far as we found) get value from trading only. Chain and backing are not differences.

## 4. Mechanism

### 4.1 Demo stock

Alphabet (GOOGLc), split two ways:

* `$SEARCH` = Google Services (Search, YouTube, Network, subscriptions, devices). Roughly 85% of revenue.
* `$CLOUD` = Google Cloud. Roughly 15% of revenue and rising.

(Approximate; exact numbers come from the 10-Q.) "AI kills Search vs Cloud wins" is the conviction trade. Backup demo stock: Tesla (Auto vs Energy).

### 4.2 Vault: split, merge, redeem

Built on the Gnosis Conditional Tokens Framework (the contracts Polymarket uses), deployed on Base if not already there.

* **Split:** deposit 1 GOOGLc, receive 1 `$SEARCH` + 1 `$CLOUD`.
* **Merge:** return 1 of each, receive 1 GOOGLc. Always available.
* **Redeem after settlement:** each piece redeems alone for (its weight × 1 GOOGLc).
* Conditions resolve once, so tokens are **quarterly series** (for example `$CLOUD-Q4-2026`). After settlement a new series starts.
* Positions are ERC-1155; they are wrapped as ERC-20 for pools and wallets.

Because split and merge are always open, the price of `$SEARCH` + `$CLOUD` stays close to the price of GOOGLc; arbitrage closes any gap.

### 4.3 Settlement (the resolver)

1. Before launch, publish a written rule: which 10-Q revenue line items count as Search and which as Cloud, and what happens if Alphabet reorganises its segments.
2. After the 10-Q is filed (not the earlier press release), a proposer posts the weights onchain (for example Search 85.2%, Cloud 14.8%) with a link to the filing on SEC EDGAR and a hash of the document.
3. A 48–72 hour dispute window opens. Anyone can challenge by posting a bond. Version 1: team multisig proposes, disputes escalate to a fallback (to be decided). Option: UMA Optimistic Oracle if it is on Base.
4. After the window, weights are final and redemption opens.

Weights are revenue shares, not growth. If both segments grow 20%, the payout does not change. The bet is on mix.

### 4.4 Trading pause at each report

From the moment the company releases results until settlement is final, the pool stops trading. Split, merge and redeem stay open. Purpose: stop traders who already know the numbers from trading against liquidity providers.

### 4.5 Market: one concentrated pool plus a router

* One pool: `$CLOUD` against GOOGLc on Uniswap v4 or Aerodrome Slipstream, with liquidity concentrated where Cloud's share can realistically be (about 0.12–0.20 GOOGLc per `$CLOUD`), plus a small wide backstop position (about 0.05–0.40).
* `$SEARCH` has no pool. Its price is GOOGLc minus `$CLOUD`. A router handles: buy `$CLOUD` (from the pool); buy `$SEARCH` (split GOOGLc, sell the `$CLOUD`); pay in USDC (router first buys GOOGLc on Aerodrome).
* An earlier design used a single-asset prediction-market pool (Fixed Product Market Maker). It was rejected: with an 85/15 split, one trade of 10% of the seed doubled the `$CLOUD` price. With concentrated liquidity, a trade of 20% of the seed moved it about 10% (no fees, illustrative).
* The price still moves with buying; liquidity only decides how much money is needed per percent of movement.

### 4.6 Fair value shown in the app

Fair value between reports = last quarter's weight × current GOOGLc price. The app shows fair value, market price, and the implied "market expects Cloud share: X%".

## 5. Demo plan (testnet + mainnet fork)

* Public app on Base Sepolia with a faucet for mock GOOGLc and USDC: split, trade, merge, redeem.
* The mock GOOGLc copies the real token's behaviour: `multiplier`, pause, `isAuthorized`.
* A replayed settlement using Alphabet's latest real 10-Q, including one disputed proposal that loses to the correct one.
* A "Proof" page reading live onchain data: vault GOOGLc against tokens outstanding, pool reserves, sum check, every number linked to the block explorer.
* Open-source, verified contracts. Foundry invariant tests ("vault always covers every outstanding token"). A mainnet fork test using the real GOOGLc token: deposit, split, merge, withdraw.
* Admin rules in code: nobody can withdraw GOOGLc from the vault; merge and redeem cannot be paused; admin actions through a multisig with a timelock.
* An honest risk page and a 2-minute video.
* Not built: own token, points, more stocks, custom chart terminal, audit.

## 6. Mainnet (optional, after December 1)

A capped beta (for example $25k total deposits), seeded with about $5k of GOOGLc, only if the fork test passes, a lawyer call does not stop it, and trader interviews show interest. Region blocking for US and other restricted persons; terms of service.

## 7. Success criteria

* Judges can use the testnet app unaided in two minutes and understand the difference from Daybreak in one sentence.
* The replayed settlement and the dispute work end to end on testnet.
* The fork test passes with the real GOOGLc token.
* At least some of 20 traders asked say they would hold a settling `$CLOUD` rather than a free-floating one.

## 8. Known open questions and risks

1. **Demand is unproven.** Historical tracking stocks traded at discounts. Traders may prefer a free-floating meme version or a plain prediction market.
2. **Is it a prediction market?** Answer we give: the bet sits on top of the stock (holding `$CLOUD` still moves with Alphabet) and pays in stock, not USDC. Is that enough?
3. **Resolver trust and correctness.** Mapping 10-Q line items, segment reorganisations, restatements, who proposes, what the dispute fallback is, how large bonds are.
4. **Quarterly series vs rolling tokens.** Series split liquidity and need relaunching each quarter.
5. **Issuer permissions.** Can the Conditional Tokens contract, the pool and the router hold GOOGLc (`isAuthorized`)? What happens when the issuer pauses GOOGLc or the multiplier changes?
6. **Liquidity.** GOOGLc depth on Aerodrome may be thin, so USDC entry is costly. Who becomes a liquidity provider besides the team? What happens when the price leaves the concentrated range?
7. **Price meaning between reports.** Nothing forces prices toward fair value between reports except traders' expectations.
8. **Legal.** These are derivatives on a security. Not for US persons. The team's own eligibility to hold stock tokens is unconfirmed.
9. **No live settlement before the deadline**; the demo depends on a replay.
10. **Daybreak can add settlement.** Our lead is execution of the resolver, not code.
11. **Scope for two people in three weeks.**
