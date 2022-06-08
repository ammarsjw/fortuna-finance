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

    function getTotalRewards(address _user) external view returns (uint256) {
        return _totalPassiveRewards[_user];
    }

    // functions

    function updatePassiveRewards(address _user, uint256 _balance) external {
        require(_user != address(0), "updatePassiveRewards::User cannot be zero address");
        require(_balance != 0, "updatePassiveRewards::Balance cannot be zero");

        uint256 currentTime = block.timestamp;

        bool firstTransaction = _lastUpdate[_user] == 0;

        if (firstTransaction) {
            _lastUpdate[_user] = currentTime;
            return;
        }
        else {
            bool isValid = currentTime > _lastUpdate[_user].add(rewardTime);

            if (isValid) {
                uint256 timeToConsider = currentTime.sub(_lastUpdate[_user]);

                uint256 rewardCycles = timeToConsider.div(rewardTime);
                uint256 ratio = rewardPercentagePerCycle.mul(rewardCycles);

                uint256 accruedInterest = _compoundReward(
                    _balance,
                    ratio,
                    1
                );
                _totalPassiveRewards[_user] += accruedInterest.sub(_balance);

                _lastUpdate[_user] = currentTime;
            }
        }
    }

    function claimPassiveRewards(address _user) external onlyOwner {
    }

    function _compoundReward(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return _principal;
        }

        return ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
    }
}