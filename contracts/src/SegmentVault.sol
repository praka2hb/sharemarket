// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PieceToken} from "./PieceToken.sol";

/// @notice Splits a stock token into N pieces that trade forever, one per business line.
///         Example: 1 GOOGLc -> 1 $SEARCH + 1 $YOUTUBE + 1 $CLOUD. One of each back -> 1 GOOGLc.
/// @dev No settlement, no expiry, no admin, no pause. Prices come only from trading; split and
///      merge keep the pieces' prices summing to about 1 stock token. The only way collateral
///      leaves is `merge`, so the vault always holds one stock token per full set of pieces.
contract SegmentVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_PIECES = 2;
    uint256 public constant MAX_PIECES = 8;

    IERC20 public immutable collateralToken;
    PieceToken[] internal _pieces;

    error ZeroAmount();
    error TransferMismatch();
    error BadPieceCount();

    event Split(address indexed user, address indexed to, uint256 amount);
    event Merged(address indexed user, address indexed to, uint256 amount);

    /// @param symbols one symbol per piece, e.g. ["SEARCH-GOOGL", "YOUTUBE-GOOGL", "CLOUD-GOOGL"]
    /// @param names   one name per piece (same length as symbols)
    constructor(IERC20 collateralToken_, string[] memory symbols, string[] memory names) {
        if (symbols.length < MIN_PIECES || symbols.length > MAX_PIECES || names.length != symbols.length) {
            revert BadPieceCount();
        }
        collateralToken = collateralToken_;
        uint8 dec = IERC20Metadata(address(collateralToken_)).decimals();
        for (uint256 i; i < symbols.length; i++) {
            _pieces.push(new PieceToken(names[i], symbols[i], dec));
        }
    }

    /// @notice Deposit `amount` stock tokens; `to` receives `amount` of every piece.
    function split(uint256 amount, address to) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 before = collateralToken.balanceOf(address(this));
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        if (collateralToken.balanceOf(address(this)) - before != amount) revert TransferMismatch();
        uint256 n = _pieces.length;
        for (uint256 i; i < n; i++) {
            _pieces[i].mint(to, amount);
        }
        emit Split(msg.sender, to, amount);
    }

    /// @notice Burn `amount` of every piece from the caller; `to` receives `amount` stock tokens.
    /// @dev `to` lets a holder whose own address is blocked by the issuer exit to an allowed address.
    function merge(uint256 amount, address to) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 n = _pieces.length;
        for (uint256 i; i < n; i++) {
            _pieces[i].burn(msg.sender, amount);
        }
        collateralToken.safeTransfer(to, amount);
        emit Merged(msg.sender, to, amount);
    }

    function pieceCount() external view returns (uint256) {
        return _pieces.length;
    }

    function piece(uint256 index) external view returns (PieceToken) {
        return _pieces[index];
    }

    function pieces() external view returns (PieceToken[] memory) {
        return _pieces;
    }

    /// @notice Full sets outstanding. The vault must hold at least this much collateral.
    function setsOutstanding() external view returns (uint256) {
        return _pieces[0].totalSupply();
    }
}
