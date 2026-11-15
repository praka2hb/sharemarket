// Static named re-export so the bundler can tree-shake the rest of `wagmi/connectors`
// even though this module itself is loaded lazily (see lazyCoinbase.ts).
export { coinbaseWallet } from "wagmi/connectors";
