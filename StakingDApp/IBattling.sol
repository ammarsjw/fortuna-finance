pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

interface IBattling {
    
    function handleLosses(
        address _user,
        uint256 _battleType,
        uint256 _chanceToLose,
        bool isBattleEnd,
        uint256 _chanceForHeroLoss,
        uint256 _chanceForCavalryLoss
    ) external;

}