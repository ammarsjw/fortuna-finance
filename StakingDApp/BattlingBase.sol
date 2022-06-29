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

    uint256[6] toCollectPercentages;                        // chance to win for every iteration
    uint256 toCollectIncreasePerDay;                        // increase in chance to win for every ration day

    uint256[6] rewardPercentages;                           // reward percentage per day
    uint256[6] rewardPercentagesPerCycle;                   // reward percentage per reward iteration
    uint256[6] public minStakeAmount;                       // minimum stake amount to be able to receive rewards

    // structs

    struct Battle {
        uint8 battleType;
        uint256 initialTokensStaked;
        uint256 additionalTokens;
        uint256 rewards;
        uint256 rations;
        uint256 passiveRewards;
        uint256 currentRewardPercentagePerCycle;
        uint256 currentToCollectPercentage;
        uint256 battleStartTime;
        uint256 battleDaysExpended;
        uint256 rationsDaysTotal;
        uint256 hero;
        uint256 cavalry;
    }

    // constructor

    constructor() {
        // TODO
        // rewardTime = 1800;
        // oneDayTime = 86400;
        // baseBattleTime = 259200;
        rewardTime = 1;
        oneDayTime = 48;
        baseBattleTime = 144;

        multiplier = 10 ** 6;
        multiplierForReward = 10 ** 9;

        toCollectPercentages = [1000, 1000, 750, 500, 200, 100];
        toCollectIncreasePerDay = 5;

        rewardPercentages = [2500000, 5000000, 10000000, 12500000, 20000000, 25000000];
        _setRewards();
    }

    // setters

    function _setRewards() internal {
        for (uint256 i = 0 ; i < 6 ; i++) {
            rewardPercentagesPerCycle[i] = rewardPercentages[i].roundDiv(48);
            minStakeAmount[i] = multiplierForReward.ceilDiv(rewardPercentagesPerCycle[i]);
        }
    }
}