// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Coinbase B20 tokenized-stock interface, as confirmed against real GOOGLc on Base mainnet
///         (docs/research/g0_findings.md, section 1.3). GOOGLc is a precompile (code 0xef).
/// @dev There is no `paused()` and no zero-argument `policyId()`; both revert on the real token.
///      The vault treats GOOGLc as a plain ERC-20. The extra functions are used by the fork test,
///      the mocks and the frontend banner only.
interface IB20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Share-equivalence multiplier (WAD). Separate from balances.
    function multiplier() external view returns (uint256);
    /// @notice Paused features. Empty means nothing is paused.
    function pausedFeatures() external view returns (uint8[] memory);

    function TRANSFER_SENDER_POLICY() external view returns (bytes32);
    function TRANSFER_RECEIVER_POLICY() external view returns (bytes32);
    function TRANSFER_EXECUTOR_POLICY() external view returns (bytes32);
    function policyId(bytes32 scope) external view returns (uint64);
}

/// @notice B20 PolicyRegistry precompile at 0x8453000000000000000000000000000000000002.
/// @dev A policy ID's top byte gives its type: 0x00 BLOCKLIST, 0x01 ALLOWLIST. GOOGLc uses policy 5 (blocklist).
interface IPolicyRegistry {
    /// @notice Never reverts.
    function isAuthorized(uint64 policyId, address account) external view returns (bool);
    function policyExists(uint64 policyId) external view returns (bool);
}
