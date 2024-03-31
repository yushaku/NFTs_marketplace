// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./StakedBalances.sol";
import "./SMTypes.sol";
import "./Roles.sol";

/**
 * @title Admin
 * @dev Admin-only functions.
 */
abstract contract Admin is StakedBalances, Roles {
  using SafeMath for uint256;

  // ============ External Functions ============

  /**
   * @notice Set the parameters defining the function from timestamp to epoch number.
   *
   *  The formula used is `n = floor((t - b) / a)` where:
   *    - `n` is the epoch number
   *    - `t` is the timestamp (in seconds)
   *    - `b` is a non-negative offset, indicating the start of epoch zero (in seconds)
   *    - `a` is the length of an epoch, a.k.a. the interval (in seconds)
   *
   *  Reverts if epoch zero already started, and the new parameters would change the current epoch.
   *  Reverts if epoch zero has not started, but would have had started under the new parameters.
   *
   * @param  interval  The length `a` of an epoch, in seconds.
   * @param  offset    The offset `b`, i.e. the start of epoch zero, in seconds.
   */
  function setEpochParameters(
    uint256 interval,
    uint256 offset
  ) external onlyRole(EPOCH_PARAMETERS_ROLE) nonReentrant {
    if (!hasEpochZeroStarted()) {
      require(block.timestamp < offset, "SMAdmin: Started epoch zero");
      _setEpochParameters(interval, offset);
      return;
    }

    // We must settle the total active balance to ensure the index is recorded at the epoch
    // boundary as needed, before we make any changes to the epoch formula.
    _settleTotalActiveBalance();

    // Update the epoch parameters. Require that the current epoch number is unchanged.
    uint256 originalCurrentEpoch = getCurrentEpoch();
    _setEpochParameters(interval, offset);
    uint256 newCurrentEpoch = getCurrentEpoch();
    require(originalCurrentEpoch == newCurrentEpoch, "SMAdmin: Changed epochs");
  }

  /**
   * @notice Set the blackout window, during which one cannot request withdrawals of staked funds.
   */
  function setBlackoutWindow(
    uint256 blackoutWindow
  ) external onlyRole(EPOCH_PARAMETERS_ROLE) nonReentrant {
    _setBlackoutWindow(blackoutWindow);
  }

  /**
   * @notice Set the emission rate of rewards.
   *
   * @param  emissionPerSecond  The new number of rewards tokens given out per second.
   */
  function setRewardsPerSecond(
    uint256 emissionPerSecond
  ) external onlyRole(REWARDS_RATE_ROLE) nonReentrant {
    uint256 totalStaked = 0;
    if (hasEpochZeroStarted()) {
      // We must settle the total active balance to ensure the index is recorded at the epoch
      // boundary as needed, before we make any changes to the emission rate.
      totalStaked = _settleTotalActiveBalance();
    }
    _setRewardsPerSecond(emissionPerSecond, totalStaked);
  }
}
