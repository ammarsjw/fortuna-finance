pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

interface IBattling {
    
    function handleLoss(
        address _user,
        uint8 _battleType,
        uint256 _chanceToLose,
        bool _isEndBattle,
        uint256 _chanceForHeroLoss,
        uint256 _chanceForCavalryLoss
    ) external;

    function purchaseAsset(
        address _user,
        uint256 _assetToPurchase
    ) external;

}