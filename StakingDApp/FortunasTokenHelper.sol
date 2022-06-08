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

    function getLastUpdate(address _user) external view returns (uint256) {
        return _lastUpdate[_user];
    }

    function getTotalPassiveRewards(address _user) external view returns (uint256) {
        return _totalPassiveRewards[_user];
    }

    // functions

    function updatePassiveRewards(address _user, uint256 _balance) public onlyOwner returns (uint256) {
        require(_user != address(0), "updatePassiveRewards::User cannot be zero address");

        uint256 tempTotalPassiveRewards = _totalPassiveRewards[_user];
        uint256 tempLastUpdate = _lastUpdate[_user];

        uint256 currentTime = block.timestamp;

        bool firstTransaction = tempLastUpdate == 0;

        if (firstTransaction) {
            _lastUpdate[_user] = currentTime;
            return 0;
        }

        bool isValid = currentTime > tempLastUpdate.add(rewardTime);

        if (isValid) {
            uint256 timeToConsider = currentTime.sub(tempLastUpdate);

            uint256 rewardCycles = timeToConsider.div(rewardTime);
            uint256 ratio = rewardPercentagePerCycle.mul(rewardCycles);

            uint256 accruedInterest = _compoundReward(
                _balance.add(tempTotalPassiveRewards),
                ratio,
                1
            );
            _totalPassiveRewards[_user] += accruedInterest.sub(_balance.add(tempTotalPassiveRewards));

            _lastUpdate[_user] += rewardCycles.mul(rewardTime);
        }

        return _totalPassiveRewards[_user];
    }

    function claimPassiveRewards(address _user, uint256 _balance) external onlyOwner returns (uint256) {
        uint256 updatedPassiveRewards = updatePassiveRewards(_user, _balance);

        bool isClaimable = updatedPassiveRewards > 0;

        if (isClaimable) {
            _totalPassiveRewards[_user] = 0;
        }

        return updatedPassiveRewards;
    }

    function viewPassiveRewards(address _user, uint256 _balance) external view returns (uint256, uint256) {
        require(_user != address(0), "updatePassiveRewards::User cannot be zero address");

        uint256 tempTotalPassiveRewards = _totalPassiveRewards[_user];
        uint256 nextPassiveReward;

        uint256 currentTime = block.timestamp;

        bool firstTransaction = _lastUpdate[_user] == 0;

        if (firstTransaction) {
            return (0, 0);
        }

        bool isValid = currentTime > _lastUpdate[_user].add(rewardTime);

        if (isValid) {
            uint256 timeToConsider = currentTime.sub(_lastUpdate[_user]);

            uint256 rewardCycles = timeToConsider.div(rewardTime);
            uint256 ratio = rewardPercentagePerCycle.mul(rewardCycles);

            uint256 accruedInterest = _compoundReward(
                _balance.add(tempTotalPassiveRewards),
                ratio,
                1
            );
            tempTotalPassiveRewards += accruedInterest.sub(_balance.add(tempTotalPassiveRewards));

            accruedInterest = _compoundReward(
                _balance.add(tempTotalPassiveRewards),
                rewardPercentagePerCycle,
                1
            );
            nextPassiveReward += accruedInterest.sub(_balance.add(tempTotalPassiveRewards));
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