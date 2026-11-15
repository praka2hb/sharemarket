// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IMintable {
    function mint(address to, uint256 amount) external;
}

/// @notice Testnet faucet: a fixed amount of each mock stock token per address per 24 hours. No admin.
/// @dev Must be set as a minter on every mock token it hands out.
contract Faucet {
    uint256 public constant COOLDOWN = 24 hours;

    IMintable[] internal _tokens;
    uint256[] internal _amounts;
    mapping(address => uint256) public lastClaim;

    error TooSoon(uint256 nextClaimAt);
    error BadConfig();

    event Claimed(address indexed to);

    constructor(IMintable[] memory tokens_, uint256[] memory amounts_) {
        if (tokens_.length == 0 || tokens_.length != amounts_.length) revert BadConfig();
        _tokens = tokens_;
        _amounts = amounts_;
    }

    function claim() external {
        uint256 last = lastClaim[msg.sender];
        if (last != 0 && block.timestamp < last + COOLDOWN) revert TooSoon(last + COOLDOWN);
        lastClaim[msg.sender] = block.timestamp;
        for (uint256 i; i < _tokens.length; i++) {
            _tokens[i].mint(msg.sender, _amounts[i]);
        }
        emit Claimed(msg.sender);
    }

    function tokens() external view returns (IMintable[] memory) {
        return _tokens;
    }

    function amounts() external view returns (uint256[] memory) {
        return _amounts;
    }
}
