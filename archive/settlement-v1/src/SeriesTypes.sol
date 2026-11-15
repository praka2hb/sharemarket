// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Vault-side lifecycle of one quarter ("series").
enum State {
    Trading,
    Closed,
    Final
}

/// @notice Resolver-side settlement state of one series. The vault never sees this.
enum ResolverState {
    Open,
    Proposed,
    Disputed,
    Done
}

/// @notice Everything the vault stores for one series.
struct Series {
    address cloud; // $CLOUD piece token
    address services; // $SERVICES piece token
    uint256 collateral; // GOOGLc units held for this series
    uint64 tradingCloseAt; // trading ends at this timestamp
    uint32 cloudPpm; // Cloud share in parts per million, set at Final
    State state; // stored state (Trading may already be Closed by time; see SegmentVault.stateOf)
    bytes32 ruleHash; // hash of the written settlement rule for this series
    uint256 depositCap; // max collateral for this series; 0 = no cap
}

uint256 constant PPM = 1_000_000;

error WrongState();
error ZeroAmount();
error CapExceeded();
error NotVault();
error NotResolver();
error NotGuardian();
error NotAdmin();
error NotDeployer();
error UnknownSeries();
error TransferMismatch();
error BadPpm();
error BadTime();
