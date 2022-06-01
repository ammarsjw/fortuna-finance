pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./FortunasToken.sol";
import "./ABDKMath64x64.sol";
import "./BattleStruct.sol";

contract BattlingHelper is Ownable, BattleStruct {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    // variables

    uint256 public oneDayTime;                              // 1 day in epoch time
    uint256 public baseBattleTime;

    uint256 multiplierForReward;

    uint256[6] rewardBasePercentages;
    uint256 rewardIncreasePerDay;

    uint256[6] rewardLimit;                                 // rewardBase cannot exceed these amounts
    uint256[6] rewardBase;                                  // reward % per day

    // constructor

    constructor() {
        // oneDayTime = 86400;
        // baseBattleTime = 259200;
        oneDayTime = 60;                                    // 1 minute, only for testing
        baseBattleTime = 180;                               // 3 minutes, only for testing

        multiplierForReward = 10000000;

        rewardBasePercentages = [100, 100, 75, 50, 20, 10];
        rewardIncreasePerDay = 5;

        rewardLimit = [25000, 50000, 1000, 1250, 2000, 2940];
        setRewards();                                       // setting reward related variables
    }

    function setRewards() internal {
        for (uint256 i = 0 ; i < 6 ; i++) {
            rewardBase[i] = rewardLimit[i].mul(rewardBasePercentages[i]).roundDiv(100);
        }
    }

    // functions

    function calculateRewards(Battle memory _tempBattle) public view returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 daysWagingBattle = block.timestamp.sub(_tempBattle.battleStartTime).div(oneDayTime);
        uint256 daysForReward;

        uint256 ratio = rewardBase[_tempBattle.battleType - 1].mul(10 ** 18).div(multiplierForReward);
        uint256 accruedInterest;
        if (daysWagingBattle.sub(_tempBattle.battleDaysExpended) != 0) {
            if (daysWagingBattle < 3) {
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                accruedInterest = compoundReward(
                    tempTotalTokens,
                    ratio,
                    daysForReward
                );
                _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
            }
            else if (daysWagingBattle >= 3
            && daysWagingBattle < _tempBattle.rationsDaysTotal.add(3)
            && _tempBattle.rationsDaysTotal > 0) {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    accruedInterest = compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward
                    );
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                    tempTotalTokens += accruedInterest.sub(tempTotalTokens);

                    _tempBattle.battleDaysExpended = 3;
                }
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                uint256 exponent = 0;
                uint256 singleReward;
                for (uint256 i = 0 ; i < daysForReward ; i++) {
                    if (_tempBattle.currentRewardPercentage == _tempBattle.currentRewardLimit) {
                        exponent++;
                    }

                    if (_tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit) {
                        _tempBattle.currentRewardPercentage += rewardIncreasePerDay;

                        singleReward = tempTotalTokens.mul(_tempBattle.currentRewardPercentage).div(multiplierForReward);
                        _tempBattle.rewards += singleReward;
                        tempTotalTokens += singleReward;
                    }
                    else if (_tempBattle.dayForLimitReached == 0) {
                        _tempBattle.dayForLimitReached = _tempBattle.battleDaysExpended.add(i + 1);
                        _tempBattle.currentRewardPercentage = _tempBattle.currentRewardLimit;
                    }
                }

                if (exponent > 0) {
                    ratio = _tempBattle.currentRewardLimit;
                    compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent
                    );
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                    tempTotalTokens += accruedInterest.sub(tempTotalTokens);
                }
            }

            _tempBattle.battleDaysExpended = daysWagingBattle;
        }

        require(block.timestamp < _tempBattle.battleStartTime.add(baseBattleTime).add(_tempBattle.rationsDaysTotal.mul(oneDayTime)), "calculateRewards::Battle already finished");

        return _tempBattle;
    }

    function calculateRewardsForBattleEnd(Battle memory _tempBattle) external view returns (Battle memory) {
        uint256 battleEndTime = _tempBattle.rationsDaysTotal.add(3).mul(oneDayTime).add(_tempBattle.battleStartTime);

        if (block.timestamp < battleEndTime && _tempBattle.battleType != 2) {
            _tempBattle = calculateRewards(_tempBattle);
        }
        else {
            uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

            uint256 daysWagingBattle = _tempBattle.rationsDaysTotal.add(3);
            uint256 daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

            uint256 ratio = rewardBase[_tempBattle.battleType - 1].mul(10 ** 18).div(multiplierForReward);
            uint256 accruedInterest;
            if (_tempBattle.battleType == 2) {
                require(block.timestamp >= battleEndTime, "calculateRewardsForBattleEnd::Training of troops lasts a fixed 3 days");

                accruedInterest = compoundReward(
                    tempTotalTokens,
                    ratio,
                    daysForReward
                );
                _tempBattle.rewards += accruedInterest;
            }
            else {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    accruedInterest = compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward
                    );
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                    tempTotalTokens += accruedInterest.sub(tempTotalTokens);

                    _tempBattle.battleDaysExpended = 3;
                }
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                uint256 exponent = 0;
                uint256 singleReward;
                for (uint256 i = 0 ; i < daysForReward ; i++) {
                    if (_tempBattle.currentRewardPercentage == _tempBattle.currentRewardLimit) {
                        exponent++;
                    }

                    if (_tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit) {
                        _tempBattle.currentRewardPercentage += rewardIncreasePerDay;

                        singleReward = tempTotalTokens.mul(_tempBattle.currentRewardPercentage).div(multiplierForReward);
                        _tempBattle.rewards += singleReward;
                        tempTotalTokens += singleReward;
                    }
                    else if (_tempBattle.dayForLimitReached == 0) {
                        _tempBattle.dayForLimitReached = _tempBattle.battleDaysExpended.add(i + 1);
                        _tempBattle.currentRewardPercentage = _tempBattle.currentRewardLimit;
                    }
                }

                if (exponent > 0) {
                    ratio = _tempBattle.currentRewardLimit;
                    compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent
                    );
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                    tempTotalTokens += accruedInterest.sub(tempTotalTokens);
                }
            }

            _tempBattle.battleDaysExpended = daysWagingBattle;
        }

        require(block.timestamp < _tempBattle.battleStartTime.add(baseBattleTime).add(_tempBattle.rationsDaysTotal.mul(oneDayTime)), "calculateRewardsForBattleEnd::Battle already finished");

        return _tempBattle;
    }

    function compoundReward(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        return ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
    }
}