pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";

contract BattlingBase is Ownable {
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
    uint256[6] minRewardAmount;

    // structs

    struct Battle {
        uint8 battleType;
        uint256 initialTokensStaked;
        uint256 additionalTokens;
        uint256 rewards;
        uint256 rations;
        uint256 currentRewardLimit;
        uint256 currentRewardPercentage;
        uint256 battleStartTime;
        uint256 battleDaysExpended;
        uint256 rationsDaysTotal;
        uint256 dayForLimitReached;
        uint256 hero;
        uint256 cavalry;
    }

    // constructor

    constructor() {
        // rewardTime = 1800;
        // oneDayTime = 86400;
        // baseBattleTime = 259200;
        rewardTime = 60;                                    // only for testing
        oneDayTime = 2880;                                  // only for testing
        baseBattleTime = 8640;                              // only for testing

        multiplier = 10 ** 6;
        multiplierForReward = 10 ** 9;

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

    function _setAllRewards(uint256[6] memory _basePercentages, uint256 _increasePerDay, uint256[6] memory _limit) internal {
        rewardBasePercentages = _basePercentages;
        rewardIncreasePerDay = _increasePerDay;

        rewardLimit = _limit;
        for (uint256 i = 0 ; i < 6 ; i++) {
            rewardBase[i] = rewardLimit[i].mul(rewardBasePercentages[i]).roundDiv(100);
            minRewardAmount[i] = multiplierForReward.roundDiv(rewardBase[i].roundDiv(48));
        }
    }
}