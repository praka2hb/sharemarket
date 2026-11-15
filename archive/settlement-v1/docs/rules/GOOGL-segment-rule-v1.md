# GOOGL segment settlement rule, version 1

This document is the settlement rule for every Cloud Share Market series on Alphabet (GOOGL). Its keccak256 hash is stored in each series as `ruleHash` when the series is created. Any change to this text is a new version with a new hash. Existing series keep the version they were created with.

## 1. Source

Alphabet's quarterly earnings release, filed on SEC EDGAR as Exhibit 99.1 to a Form 8-K.

## 2. Figures

* **Cloud:** the "Google Cloud" segment revenue row for the three months of the quarter.
* **Services:** the "Google Services" segment revenue row for the same three months.
* Excluded: Other Bets, hedging gains or losses, and all Alphabet-level items.
* Figures are taken as printed, in USD millions.
* **Q4** uses the fourth-quarter release's "Quarter Ended December 31" columns, which show Q4 alone.
* **Cloud includes everything Alphabet reports under Google Cloud,** including product revenue from TPU system sales.

## 3. Share

`cloudPpm = floor(Cloud × 1,000,000 ÷ (Cloud + Services))`

The resolver contract computes this from the two figures. Nobody submits a share directly.

Example (Q3 2026): Cloud 30,709 and Services 96,302 give 241,782 ppm (24.18%).

## 4. Restatements

The first filing for the quarter wins. Later amendments and recast figures are ignored.

## 5. Segment changes

If Alphabet stops reporting either row in this form, the quarter settles at its fallback share.

## 6. Fallback share

* Each series has its own fallback share. It is fixed when the series is created and never changes.
* It equals the most recent final share known at creation time.
* While Cloud's share is trending upward, the fallback lags the true share. At 2026's pace it can sit several points below. The fallback is meant to be rare.
* After the fallback deadline, anyone can finalize the series at its fallback share.

| Series | Fallback share (ppm) | Source quarter |
|---|---|---|
| 26Q4 | 241,782 | Q3 2026 |

## 7. Deadlines and settlement process

* **Proposing** opens when trading closes. Anyone may propose the two figures, with the EDGAR accession number, the SHA-256 hash of the exhibit file, and a bond.
* **Sanity band:** a proposal whose share is more than 100,000 ppm (10 points) from the fallback share goes straight to the arbiter.
* **Challenge:** anyone may challenge once, within the dispute window, with different figures and an equal bond.
* **Arbiter:** picks the proposer, picks the challenger, or rejects. The winner takes the loser's bond. On reject, all bonds on that proposal are burned and proposing reopens.
* **No challenge:** after the window, the proposal becomes final and its bond is returned.
* **Fallback deadline:** 45 days after trading closes on mainnet (1 hour on testnet).
* **Dispute window:** 72 hours on mainnet (15 minutes on testnet).

## 8. Payout

After settlement, each `$CLOUD` redeems for `cloudPpm ÷ 1,000,000` GOOGLc and each `$SERVICES` for the rest. Amounts are rounded down, and rounding dust stays in the vault.
