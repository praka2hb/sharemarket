import {
  BaseError,
  ContractFunctionRevertedError,
  UserRejectedRequestError,
  decodeErrorResult,
  type Abi,
  type Hex,
} from "viem";
import { faucetAbi, stockAbi, pieceAbi, poolManagerAbi, routerAbi, vaultAbi } from "./abis";
import { formatAmount } from "./math";

const errorsOnly = (abi: Abi) => abi.filter((x) => x.type === "error");
export const allErrorsAbi = [
  ...errorsOnly(routerAbi as Abi),
  ...errorsOnly(vaultAbi as Abi),
  ...errorsOnly(pieceAbi as Abi),
  ...errorsOnly(stockAbi as Abi),
  ...errorsOnly(faucetAbi as Abi),
  ...errorsOnly(poolManagerAbi as Abi),
] as Abi;

export type HumanError = {
  kind:
    | "rejected"
    | "tooSoon"
    | "slippage"
    | "deadline"
    | "balance"
    | "allowance"
    | "paused"
    | "blocked"
    | "network"
    | "gas"
    | "zero"
    | "unknown";
  message: string;
  /** Unix seconds, for TooSoon countdowns. */
  nextClaimAt?: number;
  /** Address the issuer has blocked. */
  blocked?: string;
};

function decode(data: Hex | undefined): { errorName: string; args: readonly unknown[] } | null {
  if (!data || data === "0x") return null;
  try {
    const r = decodeErrorResult({ abi: allErrorsAbi, data });
    // PoolManager wraps token reverts; unwrap one level to find e.g. PolicyForbids.
    if (r.errorName === "WrappedError") {
      const inner = decode((r.args as readonly unknown[])[2] as Hex);
      if (inner) return inner;
    }
    return { errorName: r.errorName, args: (r.args ?? []) as readonly unknown[] };
  } catch {
    return null;
  }
}

function fromName(name: string, args: readonly unknown[]): HumanError {
  switch (name) {
    case "TooSoon": {
      const t = Number(args[0] as bigint);
      return { kind: "tooSoon", message: "You've already claimed today. The faucet refills for you soon.", nextClaimAt: t };
    }
    case "V4TooLittleReceived":
    case "V4TooLittleReceivedPerHopSingle":
      return {
        kind: "slippage",
        message: `The price moved before your trade landed (min ${formatAmount(args[0] as bigint)}, would get ${formatAmount(args[1] as bigint)}). Raise slippage or retry.`,
      };
    case "DeadlinePassed":
      return { kind: "deadline", message: "The trade took longer than 10 minutes to confirm and expired. Please retry." };
    case "ZeroAmount":
      return { kind: "zero", message: "Enter an amount greater than zero." };
    case "ERC20InsufficientBalance":
      return { kind: "balance", message: "You don't have enough of this token for that amount." };
    case "ERC20InsufficientAllowance":
      return { kind: "allowance", message: "The approval is lower than this amount. Approve again, then retry." };
    case "FeaturePaused":
      return { kind: "paused", message: "The stock token is paused by its issuer. Trading and merging are stopped until it's unpaused." };
    case "PolicyForbids":
      return {
        kind: "blocked",
        blocked: args[0] as string,
        message: `The token issuer has blocked ${short(args[0] as string)} from holding this stock token, so this trade can't go through.`,
      };
    case "BadPiece":
      return { kind: "unknown", message: "That piece doesn't exist in this market." };
    case "TransferMismatch":
      return { kind: "unknown", message: "The stock token arrived in a different amount than sent, so the vault refused it." };
    default:
      return { kind: "unknown", message: `The transaction was rejected by the contract (${name}).` };
  }
}

export const short = (a?: string) => (a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "");

/** Turn anything thrown by viem/wagmi into one human sentence. */
export function humanizeError(err: unknown): HumanError {
  if (err instanceof BaseError) {
    if (err.walk((e) => e instanceof UserRejectedRequestError)) {
      return { kind: "rejected", message: "You cancelled the request in your wallet." };
    }
    const revert = err.walk((e) => e instanceof ContractFunctionRevertedError) as ContractFunctionRevertedError | null;
    if (revert) {
      if (revert.data?.errorName) return fromName(revert.data.errorName, revert.data.args ?? []);
      const decoded = decode(revert.raw);
      if (decoded) return fromName(decoded.errorName, decoded.args);
    }
    // Some providers return raw revert data deeper in the chain.
    const withData = err.walk((e) => typeof (e as { data?: unknown }).data === "string") as { data?: Hex } | null;
    const decoded = decode(withData?.data);
    if (decoded) return fromName(decoded.errorName, decoded.args);

    const text = `${err.shortMessage} ${err.details ?? ""}`.toLowerCase();
    if (text.includes("insufficient funds")) {
      return { kind: "gas", message: "You need a little Base Sepolia ETH to pay for gas. Grab some free from a faucet, then retry." };
    }
    if (text.includes("chain") && (text.includes("mismatch") || text.includes("does not match"))) {
      return { kind: "network", message: "Your wallet is on the wrong network. Switch to Base Sepolia." };
    }
    return { kind: "unknown", message: err.shortMessage || "Something went wrong. Please retry." };
  }
  if (err instanceof Error) return { kind: "unknown", message: err.message };
  return { kind: "unknown", message: "Something went wrong. Please retry." };
}
