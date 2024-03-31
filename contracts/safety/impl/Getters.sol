// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../utils/Math.sol";
import "./SMTypes.sol";
import "./Storage.sol";

/**
 * @title Getters
 * @dev Some external getter functions.
 */
abstract contract Getters is Storage {
  using SafeMath for uint256;

  // ============ External Functions ============

  /**
   * @notice The parameters specifying the function from timestamp to epoch number.
   * @return The parameters struct with { interval, offset }
   */
  function getEpochParameters()
    external
    view
    returns (SMTypes.EpochParameters memory)
  {
    return _EPOCH_PARAMETERS_;
  }

  /**
   * @notice The period of time at the end of each epoch in which withdrawals cannot be requested.
   * @return The blackout window duration, in seconds.
   */
  function getBlackoutWindow() external view returns (uint256) {
    return _BLACKOUT_WINDOW_;
  }

  /**
   * @notice Get the domain separator used for EIP-712 signatures.
   * @return The EIP-712 domain separator.
   */
  function getDomainSeparator() external view returns (bytes32) {
    return _DOMAIN_SEPARATOR_;
  }

  /**
   * @notice The value of one underlying token, in the units used for staked balances, denominated
   *  as a mutiple of EXCHANGE_RATE_BASE for additional precision.
   *  To convert from an underlying amount to a staked amount, multiply by the exchange rate.
   *
   * @return The exchange rate.
   */
  function getExchangeRate() external view returns (uint256) {
    return _EXCHANGE_RATE_;
  }

  /**
   * @notice Get an exchange rate snapshot.
   * @param  index  The index number of the exchange rate snapshot.
   * @return The snapshot struct with `blockNumber` and `value` fields.
   */
  function getExchangeRateSnapshot(
    uint256 index
  ) external view returns (SMTypes.Snapshot memory) {
    return _EXCHANGE_RATE_SNAPSHOTS_[index];
  }

  /**
   * @notice Get the number of exchange rate snapshots.
   * @return The number of snapshots that have been taken of the exchange rate.
   */
  function getExchangeRateSnapshotCount() external view returns (uint256) {
    return _EXCHANGE_RATE_SNAPSHOT_COUNT_;
  }
}
