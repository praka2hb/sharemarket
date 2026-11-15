import type { Client } from "viem";
import { simulateContract } from "viem/actions";
import { quoterAbi } from "./abis";
import { ADDRESSES } from "./addresses";
import type { Piece } from "./markets";

/** Amount out for an exact input. The Quoter isn't a view, so this is an eth_call simulation. */
async function quoteExactIn(client: Client, piece: Piece, zeroForOne: boolean, amountIn: bigint): Promise<bigint> {
  const { result } = await simulateContract(client, {
    address: ADDRESSES.quoter,
    abi: quoterAbi,
    functionName: "quoteExactInputSingle",
    args: [{ poolKey: piece.poolKey, zeroForOne, exactAmount: amountIn, hookData: "0x" }],
  });
  return result[0];
}

/** Pieces out for `stockIn` stock tokens. Stock → piece is zeroForOne when the stock is currency0. */
export const quoteBuy = (c: Client, piece: Piece, stockIn: bigint) => quoteExactIn(c, piece, !piece.pieceIs0, stockIn);

/** Stock tokens out for `pieceIn` pieces. */
export const quoteSell = (c: Client, piece: Piece, pieceIn: bigint) => quoteExactIn(c, piece, piece.pieceIs0, pieceIn);
