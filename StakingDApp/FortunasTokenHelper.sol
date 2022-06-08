pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ABDKMath64x64.sol";

contract FortunasTokenHelper is Ownable {
    using SafeMath for uint256;

    uint256 rewardTime;
    
    uint256 multiplierForReward;

    uint256 rewardPercentage;
    uint256 rewardPercentagePerCycle;

    // mappings

    mapping (address => uint256) private _lastUpdate;
    mapping (address => uint256) private _totalPassiveRewards;

    // constructor

    constructor() {
        // rewardTime = 1800;
        rewardTime = 1;

        multiplierForReward = 10 ** 9;

        rewardPercentage = 2500000;
        rewardPercentagePerCycle = 52083;
    }

    // getters

    function getLastUpdate(address account) external view returns (uint256) {
        return _lastUpdate[account];
    }

    function getTotalPassiveRewards(address account) external view returns (uint256) {
        return _totalPassiveRewards[account];
    }

    // functions

    function updatePassiveRewards(address account, uint256 balance) public onlyOwner returns (uint256) {
        uint256 tempTotalPassiveRewards = _totalPassiveRewards[account];
        uint256 tempLastUpdate = _lastUpdate[account];

        uint256 currentTime = block.timestamp;
        
        if (balance == 0 && tempTotalPassiveRewards == 0) {
            _lastUpdate[account] = currentTime;
            return 0;
        }

        bool isFirstTransaction = tempLastUpdate == 0;

        if (isFirstTransaction) {
            _lastUpdate[account] = currentTime;
            return 0;
        }

        bool isValid = currentTime > tempLastUpdate.add(rewardTime);

        if (isValid) {
            uint256 timeToConsider = currentTime.sub(tempLastUpdate);

            uint256 rewardCycles = timeToConsider.div(rewardTime);
            uint256 ratio = rewardPercentagePerCycle.mul(rewardCycles);

            uint256 accruedInterest = _compoundReward(
                balance.add(tempTotalPassiveRewards),
                ratio,
                1
            );
            tempTotalPassiveRewards += accruedInterest.sub(balance.add(tempTotalPassiveRewards));

            _totalPassiveRewards[account] = tempTotalPassiveRewards;
            _lastUpdate[account] += rewardCycles.mul(rewardTime);
        }

        return _totalPassiveRewards[account];
    }

    function claimPassiveRewards(address account, uint256 balance) external onlyOwner returns (uint256) {
        uint256 updatedPassiveRewards = updatePassiveRewards(account, balance);

        bool isClaimable = updatedPassiveRewards > 0;

        if (isClaimable) {
            _totalPassiveRewards[account] = 0;
        }

        return updatedPassiveRewards;
    }

    function viewPassiveRewards(address account, uint256 balance) external view returns (uint256, uint256) {
        uint256 tempTotalPassiveRewards = _totalPassiveRewards[account];
        uint256 nextPassiveReward;

        uint256 currentTime = block.timestamp;

        if (balance == 0 && tempTotalPassiveRewards == 0) {
            return (0, 0);
        }

        bool isFirstTransaction = _lastUpdate[account] == 0;

        if (isFirstTransaction) {
            return (0, 0);
        }

        bool isValid = currentTime > _lastUpdate[account].add(rewardTime);

        if (isValid) {
            uint256 timeToConsider = currentTime.sub(_lastUpdate[account]);

            uint256 rewardCycles = timeToConsider.div(rewardTime);
            uint256 ratio = rewardPercentagePerCycle.mul(rewardCycles);

            uint256 accruedInterest = _compoundReward(
                balance.add(tempTotalPassiveRewards),
                ratio,
                1
            );
            tempTotalPassiveRewards += accruedInterest.sub(balance.add(tempTotalPassiveRewards));

            accruedInterest = _compoundReward(
                balance.add(tempTotalPassiveRewards),
                rewardPercentagePerCycle,
                1
            );
            nextPassiveReward += accruedInterest.sub(balance.add(tempTotalPassiveRewards));
        }

        return (tempTotalPassiveRewards, nextPassiveReward);
    }

    function _compoundReward(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return _principal;
        }

        return ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
    }
}