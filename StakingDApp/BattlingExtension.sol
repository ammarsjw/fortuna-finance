pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./ABDKMath64x64.sol";
import "./BattlingBase.sol";
import "./IPancakePair.sol";
import "./IPancakeRouter02.sol";
import "./IPancakeFactory.sol";

contract BattlingExtension is BattlingBase {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    // RNG variables

    IPancakeRouter02 public rng_pancakeRouter;
    IPancakeFactory public rng_pancakeFactory;

    IPancakePair public rng_pancakePair1;
    IPancakePair public rng_pancakePair2;
    IPancakePair public rng_pancakePair3;
    IPancakePair public rng_pancakePair4;

    uint256[] private defeatChance;

    // constructor

    constructor() {
        // PancakeRouter02 mainnet
        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        // TODO remove
        IPancakeRouter02 _pancakeRouter;
        if (block.chainid == 97) {
            _pancakeRouter = IPancakeRouter02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        }
        else if (block.chainid == 4) {
            _pancakeRouter = IPancakeRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        }
        IPancakeFactory _pancakeFactory = IPancakeFactory(_pancakeRouter.factory());

        address _addressForPancakePair1 = _pancakeFactory.allPairs(0);
        address _addressForPancakePair2 = _pancakeFactory.allPairs(1);
        address _addressForPancakePair3 = _pancakeFactory.allPairs(2);
        address _addressForPancakePair4 = _pancakeFactory.allPairs(3);

        rng_pancakeRouter = _pancakeRouter;
        rng_pancakeFactory = _pancakeFactory;

        rng_pancakePair1 = IPancakePair(_addressForPancakePair1);
        rng_pancakePair2 = IPancakePair(_addressForPancakePair2);
        rng_pancakePair3 = IPancakePair(_addressForPancakePair3);
        rng_pancakePair4 = IPancakePair(_addressForPancakePair4);

        defeatChance = [250, 500, 800, 900];
    }

    // RNG functions

    function createRandomnessForLoss(uint256 _chanceToLose, uint256 _multiplier) public view returns (bool) {
        uint256 a = rng_pancakePair1.price0CumulativeLast();
        uint256 b = rng_pancakePair1.price1CumulativeLast();

        uint256 c = rng_pancakePair2.price0CumulativeLast();
        uint256 d = rng_pancakePair2.price1CumulativeLast();

        uint256 e = rng_pancakePair3.price0CumulativeLast();
        uint256 f = rng_pancakePair3.price1CumulativeLast();

        uint256 g = rng_pancakePair4.price0CumulativeLast();
        uint256 h = rng_pancakePair4.price1CumulativeLast();

        uint256 randomChance =
            uint256(keccak256(abi.encodePacked(a, b, c, d, e, f, g, h, block.timestamp))).mod(_multiplier).add(1);

        return randomChance <= _chanceToLose;
    }

    function createRandomnessForAsset() external view returns (uint256) {
        uint256 result;

        uint256 a = rng_pancakePair1.price0CumulativeLast();
        uint256 b = rng_pancakePair1.price1CumulativeLast();
        (uint256 c, , ) = rng_pancakePair1.getReserves();

        uint256 d = rng_pancakePair2.price0CumulativeLast();
        uint256 e = rng_pancakePair2.price1CumulativeLast();
        (uint256 f, , ) = rng_pancakePair2.getReserves();

        uint256 g = rng_pancakePair3.price0CumulativeLast();
        uint256 h = rng_pancakePair3.price1CumulativeLast();
        (uint256 i, , ) = rng_pancakePair3.getReserves();

        uint256 randomChance = uint256(keccak256(abi.encodePacked(a, b, c, d, e, f, g, h, i, block.timestamp))).mod(100).add(1);

        if (randomChance <= 50) {
            result = 1;
        }
        else if (50 < randomChance && randomChance <= 75) {
            result = 2;
        }
        else if (75 < randomChance && randomChance <= 90) {
            result = 3;
        }
        else if (90 < randomChance && randomChance <= 99) {
            result = 4;
        }
        else if (randomChance == 100) {
            result = 5;
        }

        return result;
    }

    function determineBattleOutcome(uint256 _battleDaysExpended, uint8 _battleType) external view returns (bool) {
        uint256 chanceDecrease = _battleDaysExpended.mul(5);
        uint256 chanceForDefeat = defeatChance[_battleType - 3].safeSub(chanceDecrease);

        if (chanceForDefeat != 0) {
            return createRandomnessForLoss(chanceForDefeat, 1000);
        }

        return false;
    }

    // functions

    function calculateRations(Battle memory _tempBattle, uint256 _extraRewards, uint256 _rationDays) external view onlyOwner returns (Battle memory, uint256) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards).add(_extraRewards);
        uint256 tempRations;
        uint256 totalPercentage;
        if (
            _tempBattle.rationsDaysTotal + _rationDays >= _tempBattle.dayForLimitReached &&
            _tempBattle.dayForLimitReached != 0
        ) {
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

    function calculateRewards(Battle memory _tempBattle) public view onlyOwner returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 daysWagingBattle = block.timestamp.sub(_tempBattle.battleStartTime).div(oneDayTime);
        uint256 daysForReward;

        uint256 trueRewardPercentage = _tempBattle.currentRewardPercentage.roundDiv(48);
        uint256 ratio = trueRewardPercentage.mul(10 ** 18).div(multiplierForReward);
        uint256 compoundReward;
        if (daysWagingBattle.sub(_tempBattle.battleDaysExpended) != 0) {
            if (daysWagingBattle < 3) {
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                compoundReward = _compoundReward(
                    tempTotalTokens,
                    ratio,
                    daysForReward.mul(48)
                );
                _tempBattle.rewards += compoundReward;
            }
            else if (
                daysWagingBattle >= 3 &&
                daysWagingBattle < _tempBattle.rationsDaysTotal.add(3) &&
                _tempBattle.rationsDaysTotal > 0
            ) {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    compoundReward = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward.mul(48)
                    );
                    _tempBattle.rewards += compoundReward;
                    tempTotalTokens += compoundReward;

                    _tempBattle.battleDaysExpended = 3;
                }

                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                uint256 exponent;
                for (uint256 i = 0 ; i < daysForReward ; i++) {
                    if (
                        _tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit &&
                        _tempBattle.currentRewardPercentage + rewardIncreasePerDay < _tempBattle.currentRewardLimit
                    ) {
                        _tempBattle.currentRewardPercentage += rewardIncreasePerDay;
                        trueRewardPercentage = _tempBattle.currentRewardPercentage.roundDiv(48);
                        ratio = trueRewardPercentage.mul(10 ** 18).div(multiplierForReward);

                        compoundReward = _compoundReward(
                            tempTotalTokens,
                            ratio,
                            48
                        );
                        _tempBattle.rewards += compoundReward;
                        tempTotalTokens += compoundReward;
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
                    trueRewardPercentage = _tempBattle.currentRewardPercentage.roundDiv(48);
                    ratio = trueRewardPercentage.mul(10 ** 18).div(multiplierForReward);

                    compoundReward = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent.mul(48)
                    );
                    _tempBattle.rewards += compoundReward;
                }
            }

            _tempBattle.battleDaysExpended = daysWagingBattle;
        }

        require(block.timestamp < _tempBattle.battleStartTime.add(baseBattleTime).add(_tempBattle.rationsDaysTotal.mul(oneDayTime)), "calculateRewards::BE");

        return _tempBattle;
    }

    function calculateExtraRewards(Battle memory _tempBattle) public view onlyOwner returns (uint256, uint256) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 cyclesRemaining = block.timestamp.sub(_tempBattle.battleDaysExpended.mul(oneDayTime).add(_tempBattle.battleStartTime)).div(rewardTime);

        uint256 trueRewardPercentage = _tempBattle.currentRewardPercentage.roundDiv(48);
        uint256 ratio = trueRewardPercentage.mul(10 ** 18).div(multiplierForReward);

        uint256 extraRewards = _compoundReward(
            tempTotalTokens,
            ratio,
            cyclesRemaining
        );
        tempTotalTokens += extraRewards;

        uint256 nextReward = _compoundReward(
            tempTotalTokens,
            ratio,
            1
        );

        return (extraRewards, nextReward);
    }

    function calculateRewardsForEndBattle(Battle memory _tempBattle) external view onlyOwner returns (Battle memory) {
        uint256 battleEndTime = _tempBattle.rationsDaysTotal.add(3).mul(oneDayTime).add(_tempBattle.battleStartTime);

        if (block.timestamp < battleEndTime && _tempBattle.battleType != 2) {
            _tempBattle = calculateRewards(_tempBattle);

            (uint256 extraRewards, ) = calculateExtraRewards(_tempBattle);
            _tempBattle.rewards += extraRewards;
        }
        else {
            uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

            uint256 daysWagingBattle = _tempBattle.rationsDaysTotal.add(3);
            uint256 daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

            uint256 trueRewardPercentage = _tempBattle.currentRewardPercentage.roundDiv(48);
            uint256 ratio = trueRewardPercentage.mul(10 ** 18).div(multiplierForReward);
            uint256 compoundReward;
            if (_tempBattle.battleType == 2) {
                require(block.timestamp >= battleEndTime, "calculateRewardsForEndBattle::BNE");

                compoundReward = _compoundReward(
                    tempTotalTokens,
                    ratio,
                    daysForReward.mul(48)
                );
                _tempBattle.rewards += compoundReward;
            }
            else {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    compoundReward = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward.mul(48)
                    );
                    _tempBattle.rewards += compoundReward;
                    tempTotalTokens += compoundReward;

                    _tempBattle.battleDaysExpended = 3;
                }

                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                uint256 exponent;
                for (uint256 i = 0 ; i < daysForReward ; i++) {
                    if (
                        _tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit &&
                        _tempBattle.currentRewardPercentage + rewardIncreasePerDay < _tempBattle.currentRewardLimit
                    ) {
                        _tempBattle.currentRewardPercentage += rewardIncreasePerDay;
                        trueRewardPercentage = _tempBattle.currentRewardPercentage.roundDiv(48);
                        ratio = trueRewardPercentage.mul(10 ** 18).div(multiplierForReward);

                        compoundReward = _compoundReward(
                            tempTotalTokens,
                            ratio,
                            48
                        );
                        _tempBattle.rewards += compoundReward;
                        tempTotalTokens += compoundReward;
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
                    trueRewardPercentage = _tempBattle.currentRewardPercentage.roundDiv(48);
                    ratio = trueRewardPercentage.mul(10 ** 18).div(multiplierForReward);

                    compoundReward = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent.mul(48)
                    );
                    _tempBattle.rewards += compoundReward;
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

        bool isInteger = _ratio.mod(10000000) == 0;

        uint256 accruedReward = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
        
        if (isInteger) {
            accruedReward++;
        }

        return accruedReward.sub(_principal);
    }
}