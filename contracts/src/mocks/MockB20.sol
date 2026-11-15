// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPolicyRegistry} from "../interfaces/IB20.sol";

/// @notice Testnet stand-in for a Coinbase B20 stock token (GOOGLc, NVDAc, ...). 8 decimals, the same function names as the real B20 token,
///         an owner-set multiplier, pause, and a blocklist checked for sender, receiver and executor
///         on every transfer (like the real token after the "Denim" upgrade).
/// @dev Never deployed on mainnet.
contract MockB20 is ERC20, Ownable {
    bytes32 public constant TRANSFER_SENDER_POLICY = keccak256("TRANSFER_SENDER_POLICY");
    bytes32 public constant TRANSFER_RECEIVER_POLICY = keccak256("TRANSFER_RECEIVER_POLICY");
    bytes32 public constant TRANSFER_EXECUTOR_POLICY = keccak256("TRANSFER_EXECUTOR_POLICY");
    uint8 public constant TRANSFER_FEATURE = 0;

    IPolicyRegistry public immutable registry;
    uint64 public immutable transferPolicy;
    uint256 public multiplier = 1e18;
    bool public paused;
    mapping(address => bool) public isMinter;

    error FeaturePaused(uint8 feature);
    error PolicyForbids(address account);
    error NotMinter();
    error UnknownScope();

    event MultiplierSet(uint256 multiplier);
    event PausedSet(bool paused);
    event MinterSet(address indexed minter, bool allowed);

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        IPolicyRegistry registry_,
        uint64 transferPolicy_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        registry = registry_;
        transferPolicy = transferPolicy_;
        isMinter[owner_] = true;
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function pausedFeatures() external view returns (uint8[] memory list) {
        if (!paused) return new uint8[](0);
        list = new uint8[](1);
        list[0] = TRANSFER_FEATURE;
    }

    function policyId(bytes32 scope) external view returns (uint64) {
        if (scope != TRANSFER_SENDER_POLICY && scope != TRANSFER_RECEIVER_POLICY && scope != TRANSFER_EXECUTOR_POLICY)
        {
            revert UnknownScope();
        }
        return transferPolicy;
    }

    // ---- owner controls (testnet only) ----

    function setMultiplier(uint256 newMultiplier) external onlyOwner {
        multiplier = newMultiplier;
        emit MultiplierSet(newMultiplier);
    }

    function pause() external onlyOwner {
        paused = true;
        emit PausedSet(true);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit PausedSet(false);
    }

    function setMinter(address minter, bool allowed) external onlyOwner {
        isMinter[minter] = allowed;
        emit MinterSet(minter, allowed);
    }

    function mint(address to, uint256 amount) external {
        if (!isMinter[msg.sender]) revert NotMinter();
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (paused) revert FeaturePaused(TRANSFER_FEATURE);
        if (from != address(0) && to != address(0)) {
            if (!registry.isAuthorized(transferPolicy, from)) revert PolicyForbids(from);
            if (!registry.isAuthorized(transferPolicy, to)) revert PolicyForbids(to);
            if (!registry.isAuthorized(transferPolicy, msg.sender)) revert PolicyForbids(msg.sender);
        }
        super._update(from, to, value);
    }
}
