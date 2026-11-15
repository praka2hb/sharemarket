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
import {CloseHook} from "./CloseHook.sol";
import {Series, State} from "./libraries/SeriesTypes.sol";

/// @notice One-click trading for a series' $CLOUD / GOOGLc pool:
///         buyCloud, sellCloud, and buyServices (split, then sell the $CLOUD half).
/// @dev Built on v4-periphery's V4Router (swap and delta settling are library code). Users approve
///      this contract directly; it pulls exactly the input, pays the PoolManager from its own
///      balance, and holds nothing between transactions. No admin functions.
contract SegmentRouter is V4Router {
    using SafeERC20 for IERC20;

    SegmentVault public immutable vault;
    CloseHook public immutable hook;
    IERC20 public immutable googl;

    error DeadlinePassed();
    error ClosedForSettlement();
    error ZeroAmount();
    error PayerNotRouter();
    error Reentered();

    event BoughtCloud(uint256 indexed id, address indexed user, uint256 googlIn, uint256 cloudOut);
    event SoldCloud(uint256 indexed id, address indexed user, uint256 cloudIn, uint256 googlOut);
    event BoughtServices(uint256 indexed id, address indexed user, uint256 googlIn, uint256 servicesOut, uint256 googlBack);

    constructor(IPoolManager poolManager_, SegmentVault vault_, CloseHook hook_) V4Router(poolManager_) {
        vault = vault_;
        hook = hook_;
        googl = vault_.collateralToken();
    }

    modifier guarded(uint256 id, uint256 amount, uint256 deadline) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        if (amount == 0) revert ZeroAmount();
        if (vault.stateOf(id) != State.Trading) revert ClosedForSettlement();
        if (Locker.get() != address(0)) revert Reentered();
        Locker.set(msg.sender);
        _;
        Locker.set(address(0));
    }

    // ------------------------------------------------------------------
    // Public paths
    // ------------------------------------------------------------------

    /// @notice Swap `googlIn` GOOGLc for at least `minCloudOut` $CLOUD.
    function buyCloud(uint256 id, uint256 googlIn, uint256 minCloudOut, uint256 deadline)
        external
        guarded(id, googlIn, deadline)
        returns (uint256 cloudOut)
    {
        (PoolKey memory key, IERC20 cloud) = poolKeyOf(id);
        googl.safeTransferFrom(msg.sender, address(this), googlIn);
        uint256 before = cloud.balanceOf(msg.sender);
        _swapExactIn(key, Currency.wrap(address(googl)), Currency.wrap(address(cloud)), googlIn, minCloudOut, msg.sender);
        cloudOut = cloud.balanceOf(msg.sender) - before;
        emit BoughtCloud(id, msg.sender, googlIn, cloudOut);
    }

    /// @notice Swap `cloudIn` $CLOUD for at least `minGooglOut` GOOGLc.
    function sellCloud(uint256 id, uint256 cloudIn, uint256 minGooglOut, uint256 deadline)
        external
        guarded(id, cloudIn, deadline)
        returns (uint256 googlOut)
    {
        (PoolKey memory key, IERC20 cloud) = poolKeyOf(id);
        cloud.safeTransferFrom(msg.sender, address(this), cloudIn);
        uint256 before = googl.balanceOf(msg.sender);
        _swapExactIn(key, Currency.wrap(address(cloud)), Currency.wrap(address(googl)), cloudIn, minGooglOut, msg.sender);
        googlOut = googl.balanceOf(msg.sender) - before;
        emit SoldCloud(id, msg.sender, cloudIn, googlOut);
    }

    /// @notice Split `googlIn` GOOGLc, keep all the $SERVICES, sell all the $CLOUD.
    ///         The caller receives `googlIn` $SERVICES plus at least `minGooglBack` GOOGLc.
    function buyServices(uint256 id, uint256 googlIn, uint256 minGooglBack, uint256 deadline)
        external
        guarded(id, googlIn, deadline)
        returns (uint256 googlBack)
    {
        (PoolKey memory key, IERC20 cloud) = poolKeyOf(id);
        Series memory s = vault.getSeries(id);

        googl.safeTransferFrom(msg.sender, address(this), googlIn);
        googl.forceApprove(address(vault), googlIn);
        vault.split(id, googlIn);
        IERC20(s.services).safeTransfer(msg.sender, googlIn);

        uint256 before = googl.balanceOf(msg.sender);
        _swapExactIn(key, Currency.wrap(address(cloud)), Currency.wrap(address(googl)), googlIn, minGooglBack, msg.sender);
        googlBack = googl.balanceOf(msg.sender) - before;
        emit BoughtServices(id, msg.sender, googlIn, googlIn, googlBack);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice The team's pool for a series: $CLOUD / GOOGLc, 0.30%, tick spacing 60, CloseHook.
    function poolKeyOf(uint256 id) public view returns (PoolKey memory key, IERC20 cloud) {
        cloud = IERC20(vault.getSeries(id).cloud);
        (address a, address b) =
            address(cloud) < address(googl) ? (address(cloud), address(googl)) : (address(googl), address(cloud));
        key = PoolKey({
            currency0: Currency.wrap(a),
            currency1: Currency.wrap(b),
            fee: hook.FEE(),
            tickSpacing: hook.TICK_SPACING(),
            hooks: IHooks(address(hook))
        });
    }

    /// @notice The user of the current router call (set for the duration of the call).
    function msgSender() public view override returns (address) {
        return Locker.get();
    }

    // ------------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------------

    function _swapExactIn(
        PoolKey memory key,
        Currency tokenIn,
        Currency tokenOut,
        uint256 amountIn,
        uint256 minOut,
        address recipient
    ) internal {
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
        params[2] = abi.encode(tokenOut, recipient, ActionConstants.OPEN_DELTA);
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
