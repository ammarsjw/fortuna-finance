pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./ABDKMath64x64.sol";
import "./BattleStruct.sol";

contract BattlingHelper is Ownable, BattleStruct {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    // variables

    uint256 public rewardTime;                              // 30 minutes in seconds
    uint256 public oneDayTime;                              // 1 day in seconds
    uint256 public baseBattleTime;                          // 3 days in seconds

    uint256 multiplier;
    uint256 multiplierForReward;

    uint256 rationsIncreasePercentage;

    uint256[5] rationsBase;                                 // rations %
    uint256[5] rationsIncrease;                             // percentage increase in rations percentages when reward limit is reached

    uint256[6] rewardBasePercentages;
    uint256 rewardIncreasePerDay;

    uint256[6] rewardLimit;                                 // rewardBase cannot exceed these amounts
    uint256[6] rewardBase;                                  // reward % per day

    // constructor

    constructor() {
        // rewardTime = 1800;
        // oneDayTime = 86400;
        // baseBattleTime = 259200;
        rewardTime = 1;                                     // only for testing
        oneDayTime = 48;                                    // only for testing
        baseBattleTime = 144;                               // only for testing

        multiplier = 1000000;
        multiplierForReward = 10000000;

        rationsIncreasePercentage = 125000;

        rationsBase = [2500, 5000, 7500, 10000, 12500];
        _setRations();

        // setting all rewards in battling contract
    }

    // setters

    function _setRations() internal {
        for (uint256 i = 0 ; i < 5 ; i++) {
            rationsIncrease[i] = rationsBase[i].mul(rationsIncreasePercentage).roundDiv(multiplier);
        }
    }

    function setAllRewards(uint256[6] memory _basePercentages, uint256 _increasePerDay, uint256[6] memory _limit) external onlyOwner {
        rewardBasePercentages = _basePercentages;
        rewardIncreasePerDay = _increasePerDay;

        rewardLimit = _limit;
        _setRewards();
    }

    function _setRewards() internal {
        for (uint256 i = 0 ; i < 6 ; i++) {
            rewardBase[i] = rewardLimit[i].mul(rewardBasePercentages[i]).roundDiv(100);
        }
    }

    // functions

    function calculateRations(Battle memory _tempBattle, uint256 _extraRewards, uint256 _rationDays) external view returns (Battle memory, uint256) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards).add(_extraRewards);
        uint256 tempRations;
        uint256 totalPercentage;
        if (_tempBattle.rationsDaysTotal + _rationDays >= _tempBattle.dayForLimitReached
        && _tempBattle.dayForLimitReached != 0) {
            if (_tempBattle.rationsDaysTotal < _tempBattle.dayForLimitReached) {
                uint256 daysPreIncrease = _tempBattle.dayForLimitReached - _tempBattle.rationsDaysTotal;
                tempRations = tempTotalTokens.mul(rationsBase[daysPreIncrease - 1]).div(multiplier);

                uint256 daysPostIncrease = (_tempBattle.rationsDaysTotal.add(_rationDays)) - _tempBattle.dayForLimitReached;
                totalPercentage = rationsBase[daysPostIncrease - 1].add(rationsIncrease[daysPostIncrease - 1]);
                tempRations += tempTotalTokens.mul(totalPercentage).div(multiplier);
            }
            else {
                totalPercentage = rationsBase[_rationDays - 1].add(rationsIncrease[_rationDays - 1]);
                tempRations = tempTotalTokens.mul(totalPercentage).div(multiplier);               
            }
        }
        else {
            tempRations = tempTotalTokens.mul(rationsBase[_rationDays - 1]).div(multiplier);
        }

        return (_tempBattle, tempRations);
    }

    function calculateRewards(Battle memory _tempBattle) public view returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 daysWagingBattle = block.timestamp.sub(_tempBattle.battleStartTime).div(oneDayTime);
        uint256 daysForReward;

        uint256 ratio = _tempBattle.currentRewardPercentage.mul(10 ** 18).div(multiplierForReward);
        uint256 accruedInterest;
        if (daysWagingBattle.sub(_tempBattle.battleDaysExpended) != 0) {
            if (daysWagingBattle < 3) {
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                accruedInterest = _compoundReward(
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

                    accruedInterest = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward
                    );
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                    tempTotalTokens += _tempBattle.rewards;

                    _tempBattle.battleDaysExpended = 3;
                }

                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                uint256 exponent;
                uint256 singleReward;
                for (uint256 i = 0 ; i < daysForReward ; i++) {
                    if (_tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit
                    && _tempBattle.currentRewardPercentage + rewardIncreasePerDay < _tempBattle.currentRewardLimit) {
                        _tempBattle.currentRewardPercentage += rewardIncreasePerDay;

                        singleReward = tempTotalTokens.mul(_tempBattle.currentRewardPercentage).div(multiplierForReward);
                        _tempBattle.rewards += singleReward;
                        tempTotalTokens += singleReward;
                    }
                    else if (_tempBattle.dayForLimitReached == 0) {
                        _tempBattle.dayForLimitReached = _tempBattle.battleDaysExpended.add(i + 1);
                        _tempBattle.currentRewardPercentage = _tempBattle.currentRewardLimit;
                    }

                    if (_tempBattle.currentRewardPercentage == _tempBattle.currentRewardLimit) {
                        exponent = daysForReward - i;
                        break;
                    }
                }

                if (exponent > 0) {
                    accruedInterest = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent
                    );
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                }
            }

            _tempBattle.battleDaysExpended = daysWagingBattle;
        }

        require(block.timestamp < _tempBattle.battleStartTime.add(baseBattleTime).add(_tempBattle.rationsDaysTotal.mul(oneDayTime)), "calculateRewards::BE");

        return _tempBattle;
    }

    function calculateExtraRewards(Battle memory _tempBattle) public view returns (uint256) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 cyclesRemaining = block.timestamp.sub(_tempBattle.battleDaysExpended.mul(oneDayTime).add(_tempBattle.battleStartTime)).div(rewardTime);
        uint256 ratio = _tempBattle.currentRewardPercentage.div(48).mul(cyclesRemaining);
        ratio = ratio.mul(10 ** 18).div(multiplierForReward);

        uint256 accruedInterest = _compoundReward(
            tempTotalTokens,
            ratio,
            1
        );

        return accruedInterest.sub(tempTotalTokens);
    }

    function calculateRewardsForBattleEnd(Battle memory _tempBattle) external view returns (Battle memory) {
        uint256 battleEndTime = _tempBattle.rationsDaysTotal.add(3).mul(oneDayTime).add(_tempBattle.battleStartTime);

        if (block.timestamp < battleEndTime && _tempBattle.battleType != 2) {
            _tempBattle = calculateRewards(_tempBattle);

            _tempBattle.rewards += calculateExtraRewards(_tempBattle);
        }
        else {
            uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

            uint256 daysWagingBattle = _tempBattle.rationsDaysTotal.add(3);
            uint256 daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

            uint256 ratio = _tempBattle.currentRewardPercentage.mul(10 ** 18).div(multiplierForReward);
            uint256 accruedInterest;
            if (_tempBattle.battleType == 2) {
                require(block.timestamp >= battleEndTime, "calculateRewardsForBattleEnd::BNE");

                accruedInterest = _compoundReward(
                    tempTotalTokens,
                    ratio,
                    daysForReward
                );
                _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
            }
            else {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    accruedInterest = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward
                    );
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                    tempTotalTokens += _tempBattle.rewards;

                    _tempBattle.battleDaysExpended = 3;
                }

                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                uint256 exponent;
                uint256 singleReward;
                for (uint256 i = 0 ; i < daysForReward ; i++) {
                    if (_tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit
                    && _tempBattle.currentRewardPercentage + rewardIncreasePerDay < _tempBattle.currentRewardLimit) {
                        _tempBattle.currentRewardPercentage += rewardIncreasePerDay;

                        singleReward = tempTotalTokens.mul(_tempBattle.currentRewardPercentage).div(multiplierForReward);
                        _tempBattle.rewards += singleReward;
                        tempTotalTokens += singleReward;
                    }
                    else if (_tempBattle.dayForLimitReached == 0) {
                        _tempBattle.dayForLimitReached = _tempBattle.battleDaysExpended.add(i + 1);
                        _tempBattle.currentRewardPercentage = _tempBattle.currentRewardLimit;
                    }

                    if (_tempBattle.currentRewardPercentage == _tempBattle.currentRewardLimit) {
                        exponent = daysForReward - i;
                        break;
                    }
                }

                if (exponent > 0) {
                    accruedInterest = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent
                    );
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                }
            }

            _tempBattle.battleDaysExpended = daysWagingBattle;
        }

        return _tempBattle;
    }

    function _compoundReward(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return _principal;
        }

        return ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
    }
}