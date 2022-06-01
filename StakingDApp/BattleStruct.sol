pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

contract BattleStruct {

    struct Battle {
        uint256 initialTokensStaked;
        uint256 additionalTokens;
        uint256 rations;
        uint256 rewards;
        uint256 currentRewardLimit;
        uint256 currentRewardPercentage;
        uint256 battleStartTime;
        uint256 battleDaysExpended;
        uint256 rationsDaysTotal;
        uint256 dayForLimitReached;
        uint8 battleType;
        uint256 hero;
        uint256 cavalry;
    }

}