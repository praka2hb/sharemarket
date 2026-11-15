// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {SegmentVault} from "./SegmentVault.sol";
import {State} from "./libraries/SeriesTypes.sol";

/// @notice Uniswap v4 hook for the $CLOUD / GOOGLc pools. Once a series is no longer Trading,
///         it blocks swaps and new liquidity ("closed for settlement"). Removing liquidity is never
///         blocked. It only accepts pools that pair a $CLOUD token the vault knows with GOOGLc,
///         at 0.30% fee and tick spacing 60. No admin functions.
/// @dev Permissions (beforeInitialize, beforeAddLiquidity, beforeSwap) are encoded in the
///      contract's address, which is mined at deploy time.
contract CloseHook is IHooks {
    uint24 public constant FEE = 3000;
    int24 public constant TICK_SPACING = 60;

    IPoolManager public immutable poolManager;
    SegmentVault public immutable vault;
    address public immutable collateralToken;

    error NotPoolManager();
    error ClosedForSettlement();
    error BadPool();
    error HookNotImplemented();

    constructor(IPoolManager poolManager_, SegmentVault vault_) {
        poolManager = poolManager_;
        vault = vault_;
        collateralToken = address(vault_.collateralToken());
        Hooks.validateHookPermissions(IHooks(address(this)), getHookPermissions());
    }

    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    /// @notice Series id for a pool, or revert if the pool isn't $CLOUD / GOOGLc.
    function seriesOf(PoolKey calldata key) public view returns (uint256) {
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        address cloud;
        if (c0 == collateralToken) cloud = c1;
        else if (c1 == collateralToken) cloud = c0;
        else revert BadPool();
        try vault.seriesOfToken(cloud) returns (uint256 id) {
            return id;
        } catch {
            revert BadPool();
        }
    }

    function _requireTrading(PoolKey calldata key) internal view {
        if (vault.stateOf(seriesOf(key)) != State.Trading) revert ClosedForSettlement();
    }

    // ---------------- enabled hooks ----------------

    function beforeInitialize(address, PoolKey calldata key, uint160) external view onlyPoolManager returns (bytes4) {
        if (address(key.hooks) != address(this) || key.fee != FEE || key.tickSpacing != TICK_SPACING) revert BadPool();
        seriesOf(key);
        return IHooks.beforeInitialize.selector;
    }

    function beforeAddLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        onlyPoolManager
        returns (bytes4)
    {
        _requireTrading(key);
        return IHooks.beforeAddLiquidity.selector;
    }

    function beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata)
        external
        view
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        _requireTrading(key);
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    // ---------------- not enabled (never called by the PoolManager) ----------------

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        revert HookNotImplemented();
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        returns (bytes4, int128)
    {
        revert HookNotImplemented();
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        revert HookNotImplemented();
    }
}
