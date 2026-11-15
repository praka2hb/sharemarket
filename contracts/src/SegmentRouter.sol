// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {V4Router} from "@uniswap/v4-periphery/src/V4Router.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";
import {Locker} from "@uniswap/v4-periphery/src/libraries/Locker.sol";
import {SegmentVault} from "./SegmentVault.sol";

/// @notice One-click trading for one vault's pieces. Each piece has its own Uniswap v4 pool against
///         the stock token (0.30% fee, tick spacing 60, no hook). `buy` swaps stock for a piece,
///         `sell` swaps a piece back to stock.
/// @dev Built on v4-periphery's V4Router (swap and delta settling are library code). Users approve
///      this contract directly; it pulls exactly the input, pays the PoolManager from its own
///      balance, and holds nothing between transactions. No admin functions.
///      The pieces' prices stay summing to about 1 stock token through arbitrage: if they sum to more,
///      anyone can split and sell; if less, buy one of each and merge.
contract SegmentRouter is V4Router {
    using SafeERC20 for IERC20;

    uint24 public constant FEE = 3000; // 0.30%
    int24 public constant TICK_SPACING = 60;

    SegmentVault public immutable vault;
    IERC20 public immutable stock;

    error DeadlinePassed();
    error ZeroAmount();
    error BadPiece();
    error PayerNotRouter();
    error Reentered();

    event Bought(address indexed user, uint256 indexed piece, uint256 stockIn, uint256 pieceOut);
    event Sold(address indexed user, uint256 indexed piece, uint256 pieceIn, uint256 stockOut);

    constructor(IPoolManager poolManager_, SegmentVault vault_) V4Router(poolManager_) {
        vault = vault_;
        stock = vault_.collateralToken();
    }

    modifier guarded(uint256 index, uint256 amount, uint256 deadline) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        if (amount == 0) revert ZeroAmount();
        if (index >= vault.pieceCount()) revert BadPiece();
        if (Locker.get() != address(0)) revert Reentered();
        Locker.set(msg.sender);
        _;
        Locker.set(address(0));
    }

    /// @notice Swap `stockIn` stock tokens for at least `minPieceOut` of piece `index`.
    function buy(uint256 index, uint256 stockIn, uint256 minPieceOut, uint256 deadline)
        external
        guarded(index, stockIn, deadline)
        returns (uint256 pieceOut)
    {
        IERC20 p = IERC20(address(vault.piece(index)));
        stock.safeTransferFrom(msg.sender, address(this), stockIn);
        uint256 before = p.balanceOf(msg.sender);
        _swapExactIn(poolKey(index), Currency.wrap(address(stock)), Currency.wrap(address(p)), stockIn, minPieceOut);
        pieceOut = p.balanceOf(msg.sender) - before;
        emit Bought(msg.sender, index, stockIn, pieceOut);
    }

    /// @notice Swap `pieceIn` of piece `index` for at least `minStockOut` stock tokens.
    function sell(uint256 index, uint256 pieceIn, uint256 minStockOut, uint256 deadline)
        external
        guarded(index, pieceIn, deadline)
        returns (uint256 stockOut)
    {
        IERC20 p = IERC20(address(vault.piece(index)));
        p.safeTransferFrom(msg.sender, address(this), pieceIn);
        uint256 before = stock.balanceOf(msg.sender);
        _swapExactIn(poolKey(index), Currency.wrap(address(p)), Currency.wrap(address(stock)), pieceIn, minStockOut);
        stockOut = stock.balanceOf(msg.sender) - before;
        emit Sold(msg.sender, index, pieceIn, stockOut);
    }

    /// @notice The pool for piece `index`: piece / stock, 0.30% fee, tick spacing 60, no hook.
    function poolKey(uint256 index) public view returns (PoolKey memory key) {
        address p = address(vault.piece(index));
        address s = address(stock);
        (address a, address b) = p < s ? (p, s) : (s, p);
        key = PoolKey({
            currency0: Currency.wrap(a),
            currency1: Currency.wrap(b),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    /// @notice The user of the current router call (set for the duration of the call).
    function msgSender() public view override returns (address) {
        return Locker.get();
    }

    function _swapExactIn(PoolKey memory key, Currency tokenIn, Currency tokenOut, uint256 amountIn, uint256 minOut)
        internal
    {
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE), uint8(Actions.TAKE));
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: tokenIn == key.currency0,
                amountIn: _toUint128(amountIn),
                amountOutMinimum: _toUint128(minOut),
                minHopPriceX36: 0,
                hookData: ""
            })
        );
        // Pay the full input from this contract's balance (payerIsUser = false).
        params[1] = abi.encode(tokenIn, ActionConstants.OPEN_DELTA, false);
        // Send the full output straight to the user.
        params[2] = abi.encode(tokenOut, msgSender(), ActionConstants.OPEN_DELTA);
        poolManager.unlock(abi.encode(actions, params));
    }

    /// @dev V4Router pays the PoolManager through this. Inputs are always pulled into the router first.
    function _pay(Currency token, address payer, uint256 amount) internal override {
        if (payer != address(this)) revert PayerNotRouter();
        IERC20(Currency.unwrap(token)).safeTransfer(address(poolManager), amount);
    }

    function _toUint128(uint256 x) internal pure returns (uint128) {
        require(x <= type(uint128).max, "amount too large");
        // casting to 'uint128' is safe because of the check above
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint128(x);
    }
}
