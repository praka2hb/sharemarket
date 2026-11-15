// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Testnet USDC for resolver bonds. 6 decimals. Never deployed on mainnet.
contract MockUSDC is ERC20, Ownable {
    mapping(address => bool) public isMinter;

    error NotMinter();

    event MinterSet(address indexed minter, bool allowed);

    constructor(address owner_) ERC20("USD Coin (mock)", "USDC") Ownable(owner_) {
        isMinter[owner_] = true;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function setMinter(address minter, bool allowed) external onlyOwner {
        isMinter[minter] = allowed;
        emit MinterSet(minter, allowed);
    }

    function mint(address to, uint256 amount) external {
        if (!isMinter[msg.sender]) revert NotMinter();
        _mint(to, amount);
    }
}
