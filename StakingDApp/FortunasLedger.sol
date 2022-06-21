pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ABDKMath64x64.sol";

contract FortunasLedger is Ownable {
    using SafeMath for uint256;

    uint256 public passiveRewardTime;
    
    uint256 public multiplierForPassiveReward;

    uint256 public passiveRewardPercentage;
    uint256 public passiveRewardPercentagePerCycle;

    // mappings

    mapping (address => uint256) private _lastUpdate;
    mapping (address => uint256) private _totalPassiveRewards;

    // constructor

    constructor() {
        // passiveRewardTime = 1800;
        passiveRewardTime = 144;

        multiplierForPassiveReward = 10 ** 9;

        passiveRewardPercentage = 2500000;
        passiveRewardPercentagePerCycle = 52083;
    }

    // getters

    function getLastUpdate(address account) external view returns (uint256) {
        return _lastUpdate[account];
    }

    function getTotalPassiveRewards(address account) external view returns (uint256) {
        return _totalPassiveRewards[account];
    }

    // functions

    function updatePassiveRewards(address account, uint256 balance) public onlyOwner returns (uint256, bool) {
        uint256 tempTotalPassiveRewards = _totalPassiveRewards[account];
        uint256 tempLastUpdate = _lastUpdate[account];

        uint256 currentTime = block.timestamp;

        bool isFirstTransaction = tempLastUpdate == 0;

        if (isFirstTransaction) {
            _lastUpdate[account] = currentTime;
            return (0, true);
        }

        if (
            balance == 0 &&
            tempTotalPassiveRewards == 0 &&
            !isFirstTransaction
        ) {
            return (0, false);
        }

        bool isValid = currentTime > tempLastUpdate.add(passiveRewardTime);

        if (isValid) {
            uint256 timeToConsider = currentTime.sub(tempLastUpdate);

            uint256 rewardCycles = timeToConsider.div(passiveRewardTime);

            uint256 ratio = passiveRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForPassiveReward);

            uint256 compoundReward = _compoundReward(
                balance.add(tempTotalPassiveRewards),
                ratio,
                rewardCycles
            );
            tempTotalPassiveRewards += compoundReward;

            _totalPassiveRewards[account] = tempTotalPassiveRewards;
            _lastUpdate[account] += rewardCycles.mul(passiveRewardTime);
        }

        return (_totalPassiveRewards[account], false);
    }

    function calculateNextPassiveReward(address account, uint256 balance) public view returns (uint256) {
        uint256 tempTotalPassiveRewards = _totalPassiveRewards[account];

        if (
            balance == 0 &&
            tempTotalPassiveRewards == 0
        ) {
            return 0;
        }

        uint256 ratio = passiveRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForPassiveReward);

        uint256 compoundReward = _compoundReward(
            balance.add(tempTotalPassiveRewards),
            ratio,
            1
        );
        uint256 nextPassiveReward = compoundReward;

        return nextPassiveReward;
    }

    function claimPassiveRewards(address account, uint256 balance) external onlyOwner returns (uint256, uint256) {
        (uint256 updatedPassiveRewards, ) = updatePassiveRewards(account, balance);
        uint256 nextPassiveReward;

        bool isClaimable = updatedPassiveRewards > 0;

        if (isClaimable) {
            _totalPassiveRewards[account] = 0;
        }

        bool hasBalance = balance > 0;

        if (hasBalance) {
            nextPassiveReward = calculateNextPassiveReward(account, balance);
        }

        return (updatedPassiveRewards, nextPassiveReward);
    }

    function getCurrentLedgerStatus(address account, uint256 balance) external view returns (uint256, uint256) {
        uint256 tempTotalPassiveRewards = _totalPassiveRewards[account];
        uint256 tempLastUpdate = _lastUpdate[account];
        uint256 nextPassiveReward;

        uint256 currentTime = block.timestamp;

        if (
            balance == 0 &&
            tempTotalPassiveRewards == 0
        ) {
            return (0, 0);
        }

        bool isValid = currentTime > tempLastUpdate.add(passiveRewardTime);

        uint256 ratio = passiveRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForPassiveReward);
        uint256 compoundReward;

        if (isValid) {
            uint256 timeToConsider = currentTime.sub(tempLastUpdate);

            uint256 rewardCycles = timeToConsider.div(passiveRewardTime);

            compoundReward = _compoundReward(
                balance.add(tempTotalPassiveRewards),
                ratio,
                rewardCycles
            );
            tempTotalPassiveRewards += compoundReward;
        }

        compoundReward = _compoundReward(
            balance.add(tempTotalPassiveRewards),
            ratio,
            1
        );
        nextPassiveReward = compoundReward;

        return (tempTotalPassiveRewards, nextPassiveReward);
    }

    function _compoundReward(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return _principal;
        }

        uint256 accruedReward = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
        return accruedReward.sub(_principal);
    }
}