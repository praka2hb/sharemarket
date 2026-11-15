// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IMintable {
    function mint(address to, uint256 amount) external;
}

/// @notice Testnet faucet: 20 mock GOOGLc and 2,000 mock USDC per address per 24 hours. No admin.
/// @dev Must be set as a minter on both mocks.
contract Faucet {
    uint256 public constant GOOGL_AMOUNT = 20e8;
    uint256 public constant USDC_AMOUNT = 2_000e6;
    uint256 public constant COOLDOWN = 24 hours;

    IMintable public immutable googl;
    IMintable public immutable usdc;
    mapping(address => uint256) public lastClaim;

    error TooSoon(uint256 nextClaimAt);

    event Claimed(address indexed to);

    constructor(IMintable googl_, IMintable usdc_) {
        googl = googl_;
        usdc = usdc_;
    }

    function claim() external {
        uint256 last = lastClaim[msg.sender];
        if (last != 0 && block.timestamp < last + COOLDOWN) revert TooSoon(last + COOLDOWN);
        lastClaim[msg.sender] = block.timestamp;
        googl.mint(msg.sender, GOOGL_AMOUNT);
        usdc.mint(msg.sender, USDC_AMOUNT);
        emit Claimed(msg.sender);
    }
}
