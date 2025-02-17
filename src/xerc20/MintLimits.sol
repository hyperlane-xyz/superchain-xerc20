// SPDX-License-Identifier: BSD-3.0
pragma solidity >=0.8.19 <0.9.0;

import {
    RateLimitMidPoint,
    RateLimitMidpointCommonLibrary
} from "../libraries/rateLimits/RateLimitMidpointCommonLibrary.sol";
import {RateLimitedMidpointLibrary} from "../libraries/rateLimits/RateLimitedMidpointLibrary.sol";

/// @dev Modified lightly from Zelt at commit 30b2ba0, with the following changes:
/// - Updated the Solidity compiler version used;
/// - Refactored the `_rateLimits` mapping to be internal;
/// - Removed internal `_addLimits(...)` & `_removeLimits(...)` helpers.
/// Can refer to: (https://github.com/solidity-labs-io/zelt/blob/30b2ba0352422471c03b233d55feddfbdba198a3/src/impl/MintLimits.sol)
abstract contract MintLimits {
    using RateLimitMidpointCommonLibrary for RateLimitMidPoint;
    using RateLimitedMidpointLibrary for RateLimitMidPoint;

    /// @notice struct for initializing rate limit
    struct RateLimitMidPointInfo {
        /// @notice the buffer cap for this bridge
        uint112 bufferCap;
        /// @notice the rate limit per second for this bridge
        uint128 rateLimitPerSecond;
        /// @notice the bridge address
        address bridge;
    }

    /// @notice rate limit for each bridge contract
    mapping(address bridge => RateLimitMidPoint bridgeRateLimit) internal _rateLimits;

    /// @notice emitted when a rate limit is added or removed
    /// @param bridge the bridge address
    /// @param bufferCap the new buffer cap for this bridge
    /// @param rateLimitPerSecond the new rate limit per second for this bridge
    event ConfigurationChanged(address indexed bridge, uint112 bufferCap, uint128 rateLimitPerSecond);

    //// ------------------------------------------------------------
    //// ------------------------------------------------------------
    //// -------------------- View Functions ------------------------
    //// ------------------------------------------------------------
    //// ------------------------------------------------------------

    /// @notice the amount of action used before hitting limit
    /// @dev replenishes at rateLimitPerSecond per second up to bufferCap
    function buffer(address from) public view returns (uint256) {
        return _rateLimits[from].buffer();
    }

    /// @notice the cap of the buffer for this address
    /// @param from address to get buffer cap for
    function bufferCap(address from) public view returns (uint256) {
        return _rateLimits[from].bufferCap;
    }

    /// @notice the amount the buffer replenishes towards the midpoint per second
    /// @param from address to get rate limit for
    function rateLimitPerSecond(address from) public view returns (uint256) {
        return _rateLimits[from].rateLimitPerSecond;
    }

    //// ------------------------------------------------------------
    //// ------------------------------------------------------------
    //// -------------- Internal Helper Functions -------------------
    //// ------------------------------------------------------------
    //// ------------------------------------------------------------

    //// ----------- Depleting and Replenishing Buffer --------------

    /// @notice the method that enforces the rate limit.
    /// Decreases buffer by "amount".
    /// If buffer is <= amount, revert
    /// @param amount to decrease buffer by
    function _depleteBuffer(address from, uint256 amount) internal {
        require(amount != 0, "MintLimits: deplete amount cannot be 0");
        _rateLimits[from].depleteBuffer(amount);
    }

    /// @notice function to replenish buffer
    /// @param from address to set rate limit for
    /// @param amount to increase buffer by if under buffer cap
    function _replenishBuffer(address from, uint256 amount) internal {
        require(amount != 0, "MintLimits: replenish amount cannot be 0");
        _rateLimits[from].replenishBuffer(amount);
    }

    //// -------------- Modifying Existing Limits -------------------

    /// @notice function to set rate limit per second
    /// @dev updates the current buffer and last buffer used time first,
    /// then sets the new rate limit per second
    /// @param from address to set rate limit for
    /// @param newRateLimitPerSecond new rate limit per second
    function _setRateLimitPerSecond(address from, uint128 newRateLimitPerSecond) internal {
        require(newRateLimitPerSecond <= maxRateLimitPerSecond(), "MintLimits: rateLimitPerSecond too high");
        require(_rateLimits[from].bufferCap != 0, "MintLimits: non-existent rate limit");

        _rateLimits[from].setRateLimitPerSecond(newRateLimitPerSecond);

        emit ConfigurationChanged(from, _rateLimits[from].bufferCap, newRateLimitPerSecond);
    }

    /// @notice function to set buffer cap
    /// @dev updates the current buffer and last buffer used time first,
    /// then sets the new buffer cap
    /// @param from address to set the buffer cap for
    /// @param newBufferCap new buffer cap
    function _setBufferCap(address from, uint112 newBufferCap) internal {
        require(newBufferCap != 0, "MintLimits: bufferCap cannot be 0");
        require(_rateLimits[from].bufferCap != 0, "MintLimits: non-existent rate limit");
        require(newBufferCap > minBufferCap(), "MintLimits: buffer cap below min");

        _rateLimits[from].setBufferCap(newBufferCap);

        emit ConfigurationChanged(from, newBufferCap, _rateLimits[from].rateLimitPerSecond);
    }

    //// -------------- Adding Limits -------------------

    /// @notice add an individual rate limit
    /// @param rateLimit cap on buffer size for this rate limited instance
    function _addLimit(RateLimitMidPointInfo memory rateLimit) internal {
        require(rateLimit.rateLimitPerSecond <= maxRateLimitPerSecond(), "MintLimits: rateLimitPerSecond too high");
        require(rateLimit.bridge != address(0), "MintLimits: invalid bridge address");
        require(_rateLimits[rateLimit.bridge].bufferCap == 0, "MintLimits: rate limit already exists");
        require(rateLimit.bufferCap > minBufferCap(), "MintLimits: buffer cap below min");

        _rateLimits[rateLimit.bridge] = RateLimitMidPoint({
            bufferCap: rateLimit.bufferCap,
            lastBufferUsedTime: uint32(block.timestamp),
            bufferStored: uint112(rateLimit.bufferCap / 2),
            midPoint: uint112(rateLimit.bufferCap / 2),
            rateLimitPerSecond: rateLimit.rateLimitPerSecond
        });

        emit ConfigurationChanged(rateLimit.bridge, rateLimit.bufferCap, rateLimit.rateLimitPerSecond);
    }

    //// -------------- Removing Limits -------------------

    /// @notice remove a bridge from the rate limit mapping, deleting all data
    /// @param bridge the bridge address to remove
    function _removeLimit(address bridge) internal {
        require(_rateLimits[bridge].bufferCap != 0, "MintLimits: cannot remove non-existent rate limit");

        delete _rateLimits[bridge];

        emit ConfigurationChanged(bridge, 0, 0);
    }

    //// ------------------------------------------------------------
    //// ------------------------------------------------------------
    //// ---------------------- Virtual Function --------------------
    //// ------------------------------------------------------------
    //// ------------------------------------------------------------

    /// @notice the maximum rate limit per second allowed in any bridge
    /// must be overridden by child contract
    function maxRateLimitPerSecond() public pure virtual returns (uint128);

    /// @notice the minimum buffer cap, non inclusive
    /// must be overridden by child contract
    function minBufferCap() public pure virtual returns (uint112);
}
