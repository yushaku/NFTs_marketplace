// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./StakedBalances.sol";
import "../../utils/Math.sol";
import "./SMERC20.sol";
import "./SMTypes.sol";

/**
 * @title Staking
 * @dev External functions for stakers.See StakedBalances for details on staker accounting.
 *
 *  UNDERLYING AND STAKED AMOUNTS:
 *
 *   We distinguish between underlying amounts and stake amounts. An underlying amount is denoted
 *   in the original units of the token being staked. A stake amount is adjusted by the exchange
 *   rate, which can increase due to slashing. Before any slashes have occurred, the exchange rate
 *   is equal to one.
 */
abstract contract Staking is StakedBalances, SM1ERC20 {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  // ============ Events ============

  event Staked(
    address indexed staker,
    address spender,
    uint256 underlyingAmount,
    uint256 stakeAmount
  );

  event WithdrawalRequested(address indexed staker, uint256 stakeAmount);

  event WithdrewStake(
    address indexed staker,
    address recipient,
    uint256 underlyingAmount,
    uint256 stakeAmount
  );

  // ============ Constants ============

  IERC20 public immutable STAKED_TOKEN;

  // ============ Constructor ============

  constructor(
    IERC20 stakedToken,
    IERC20 rewardsToken,
    address rewardsTreasury,
    uint256 distributionStart,
    uint256 distributionEnd
  )
    StakedBalances(
      rewardsToken,
      rewardsTreasury,
      distributionStart,
      distributionEnd
    )
  {
    STAKED_TOKEN = stakedToken;
  }

  // ============ External Functions ============

  /**
   * @notice Deposit and stake funds. These funds are active and start earning rewards immediately.
   *
   * @param  underlyingAmount  The amount of underlying token to stake.
   */
  function stake(uint256 underlyingAmount) external nonReentrant {
    _stake(msg.sender, underlyingAmount);
  }

  /**
   * @notice Deposit and stake on behalf of another address.
   *
   * @param  staker            The staker who will receive the stake.
   * @param  underlyingAmount  The amount of underlying token to stake.
   */
  function stakeFor(
    address staker,
    uint256 underlyingAmount
  ) external nonReentrant {
    _stake(staker, underlyingAmount);
  }

  /**
   * @notice Request to withdraw funds. Starting in the next epoch, the funds will be “inactive”
   *  and available for withdrawal. Inactive funds do not earn rewards.
   *
   *  Reverts if we are currently in the blackout window.
   *
   * @param  stakeAmount  The amount of stake to move from the active to the inactive balance.
   */
  function requestWithdrawal(uint256 stakeAmount) external nonReentrant {
    _requestWithdrawal(msg.sender, stakeAmount);
  }

  /**
   * @notice Withdraw the sender's inactive funds, and send to the specified recipient.
   *
   * @param  recipient    The address that should receive the funds.
   * @param  stakeAmount  The amount of stake to withdraw from the sender's inactive balance.
   */
  function withdrawStake(
    address recipient,
    uint256 stakeAmount
  ) external nonReentrant {
    _withdrawStake(msg.sender, recipient, stakeAmount);
  }

  /**
   * @notice Withdraw the max available inactive funds, and send to the specified recipient.
   *
   *  This is less gas-efficient than querying the max via eth_call and calling withdrawStake().
   *
   * @param  recipient  The address that should receive the funds.
   *
   * @return The withdrawn amount.
   */
  function withdrawMaxStake(
    address recipient
  ) external nonReentrant returns (uint256) {
    uint256 stakeAmount = getStakeAvailableToWithdraw(msg.sender);
    _withdrawStake(msg.sender, recipient, stakeAmount);
    return stakeAmount;
  }

  /**
   * @notice Settle and claim all rewards, and send them to the specified recipient.
   *
   *  Call this function with eth_call to query the claimable rewards balance.
   *
   * @param  recipient  The address that should receive the funds.
   *
   * @return The number of rewards tokens claimed.
   */
  function claimRewards(
    address recipient
  ) external nonReentrant returns (uint256) {
    return _settleAndClaimRewards(msg.sender, recipient); // Emits an event internally.
  }

  // ============ Public Functions ============

  /**
   * @notice Get the amount of stake available for a given staker to withdraw.
   * @param  staker  The address whose balance to check.
   * @return The staker's stake amount that is inactive and available to withdraw.
   */
  function getStakeAvailableToWithdraw(
    address staker
  ) public view returns (uint256) {
    // Note that the next epoch inactive balance is always at least that of the current epoch.
    return getInactiveBalanceCurrentEpoch(staker);
  }

  // ============ Internal Functions ============

  function _stake(address staker, uint256 underlyingAmount) internal {
    // Convert using the exchange rate.
    uint256 stakeAmount = stakeAmountFromUnderlyingAmount(underlyingAmount);

    // Update staked balances and delegate snapshots.
    _increaseCurrentAndNextActiveBalance(staker, stakeAmount);
    _moveDelegatesForTransfer(address(0), staker, stakeAmount);

    // Transfer token from the sender.
    STAKED_TOKEN.safeTransferFrom(msg.sender, address(this), underlyingAmount);

    emit Staked(staker, msg.sender, underlyingAmount, stakeAmount);
    emit Transfer(address(0), msg.sender, stakeAmount);
  }

  function _requestWithdrawal(address staker, uint256 stakeAmount) internal {
    require(
      !inBlackoutWindow(),
      "Staking: Withdraw requests restricted in the blackout window"
    );

    // Get the staker's requestable amount and revert if there is not enough to request withdrawal.
    uint256 requestableBalance = getActiveBalanceNextEpoch(staker);
    require(
      stakeAmount <= requestableBalance,
      "Staking: Withdraw request exceeds next active balance"
    );

    // Move amount from active to inactive in the next epoch.
    _moveNextBalanceActiveToInactive(staker, stakeAmount);

    emit WithdrawalRequested(staker, stakeAmount);
  }

  function _withdrawStake(
    address staker,
    address recipient,
    uint256 stakeAmount
  ) internal {
    // Get staker withdrawable balance and revert if there is not enough to withdraw.
    uint256 withdrawableBalance = getInactiveBalanceCurrentEpoch(staker);
    require(
      stakeAmount <= withdrawableBalance,
      "Staking: Withdraw amount exceeds staker inactive balance"
    );

    // Update staked balances and delegate snapshots.
    _decreaseCurrentAndNextInactiveBalance(staker, stakeAmount);
    _moveDelegatesForTransfer(staker, address(0), stakeAmount);

    // Convert using the exchange rate.
    uint256 underlyingAmount = underlyingAmountFromStakeAmount(stakeAmount);

    // Transfer token to the recipient.
    STAKED_TOKEN.safeTransfer(recipient, underlyingAmount);

    emit Transfer(msg.sender, address(0), stakeAmount);
    emit WithdrewStake(staker, recipient, underlyingAmount, stakeAmount);
  }
}
