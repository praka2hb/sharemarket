// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPolicyRegistry} from "../interfaces/IB20.sol";

/// @notice Testnet stand-in for the B20 PolicyRegistry. Policy 5 is a blocklist, like real GOOGLc.
contract MockPolicyRegistry is IPolicyRegistry, Ownable {
    uint64 public constant BLOCKLIST_POLICY = 5;

    mapping(uint64 => mapping(address => bool)) public blocked;

    event BlockedSet(uint64 indexed policyId, address indexed account, bool blocked);

    constructor(address owner_) Ownable(owner_) {}

    function setBlocked(address account, bool isBlocked) external onlyOwner {
        blocked[BLOCKLIST_POLICY][account] = isBlocked;
        emit BlockedSet(BLOCKLIST_POLICY, account, isBlocked);
    }

    function isAuthorized(uint64 policyId, address account) external view returns (bool) {
        if (policyId != BLOCKLIST_POLICY) return false;
        return !blocked[policyId][account];
    }

    function policyExists(uint64 policyId) external pure returns (bool) {
        return policyId == BLOCKLIST_POLICY;
    }
}
