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
    }

    // RNG functions

    function createRandomness(uint256 _chance, uint256 _multiplier) public view onlyOwner returns (bool) {
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

        return randomChance <= _chance;
    }

    function createRandomnessForAsset() external view onlyOwner returns (uint256) {
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

    function determineRewardCycles(uint256 _currentToCollectPercentage, uint256 _numberOfCycles, bool isStatic) public view onlyOwner returns (uint256, uint256) {
        uint256 numberOfWins;

        if (isStatic) {
            for (uint256 i = 0 ; i < _numberOfCycles ; i++) {
                bool result = createRandomness(_currentToCollectPercentage, 1000);

                if (result) {
                    numberOfWins++;
                }
            }
        }
        else {
            for (uint256 i = 0 ; i < _numberOfCycles ; i++) {
                if (i.mod(48) == 0) {
                    _currentToCollectPercentage += toCollectIncreasePerDay;
                }

                if (_currentToCollectPercentage == 1000) {
                    numberOfWins += _numberOfCycles.sub(i);
                    break;
                }

                bool result = createRandomness(_currentToCollectPercentage, 1000);

                if (result) {
                    numberOfWins++;
                }
            }
        }

        return (_currentToCollectPercentage, numberOfWins);
    }

    // functions

    function calculateRations(Battle memory _tempBattle, uint256 _extraRewards, uint256 _rationDays) external view onlyOwner returns (Battle memory, uint256) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards).add(_extraRewards);
        uint256 tempRations;

        if (_tempBattle.currentToCollectPercentage == 1000) {
            tempRations = tempTotalTokens.mul(rationsPercentages[_rationDays - 1]).div(multiplier);

            uint256 rationsIncreaseAmount = _compound(
                tempRations,
                rationsIncreasePercentage,
                _rationDays
            );

            tempRations += rationsIncreaseAmount;
        }

        return (_tempBattle, tempRations);
    }

    function calculateRewards(Battle memory _tempBattle) public view onlyOwner returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 daysWagingBattle = block.timestamp.sub(_tempBattle.battleStartTime).div(oneDayTime);

        uint256 ratio = _tempBattle.currentRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForReward);

        uint256 daysForReward;
        uint256 cyclesForReward;
        uint256 compoundReward;

        if (daysWagingBattle.sub(_tempBattle.battleDaysExpended) != 0) {
            if (daysWagingBattle < 3) {
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                (, cyclesForReward) = determineRewardCycles(_tempBattle.currentToCollectPercentage, daysForReward.mul(48), true);

                compoundReward = _compound(
                    tempTotalTokens,
                    ratio,
                    cyclesForReward
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

                    (, cyclesForReward) = determineRewardCycles(_tempBattle.currentToCollectPercentage, daysForReward.mul(48), true);

                    compoundReward = _compound(
                        tempTotalTokens,
                        ratio,
                        cyclesForReward
                    );
                    _tempBattle.rewards += compoundReward;
                    tempTotalTokens += compoundReward;

                    _tempBattle.battleDaysExpended = 3;
                }

                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                (_tempBattle.currentToCollectPercentage, cyclesForReward) = determineRewardCycles(
                    _tempBattle.currentToCollectPercentage,
                    daysForReward.mul(48),
                    false
                );

                compoundReward = _compound(
                    tempTotalTokens,
                    ratio,
                    cyclesForReward
                );
                _tempBattle.rewards += compoundReward;
                tempTotalTokens += compoundReward;
            }

            _tempBattle.battleDaysExpended = daysWagingBattle;
        }

        require(block.timestamp <
            _tempBattle.battleStartTime.add(baseBattleTime).add(_tempBattle.rationsDaysTotal.mul(oneDayTime)), "calculateRewards::BE");

        return _tempBattle;
    }

    function calculateExtraRewards(Battle memory _tempBattle) public view onlyOwner returns (uint256, uint256) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 cyclesRemaining =
            block.timestamp.sub(_tempBattle.battleDaysExpended.mul(oneDayTime).add(_tempBattle.battleStartTime)).div(rewardTime);

        uint256 ratio = _tempBattle.currentRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForReward);

        (, uint256 cyclesForReward) = determineRewardCycles(_tempBattle.currentToCollectPercentage, cyclesRemaining, true);

        uint256 extraRewards = _compound(
            tempTotalTokens,
            ratio,
            cyclesForReward
        );
        tempTotalTokens += extraRewards;

        uint256 nextReward = _compound(
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

            uint256 ratio = _tempBattle.currentRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForReward);

            uint256 cyclesForReward;
            uint256 compoundReward;

            if (_tempBattle.battleType == 2) {
                require(block.timestamp >= battleEndTime, "calculateRewardsForEndBattle::BNE");

                (, cyclesForReward) = determineRewardCycles(_tempBattle.currentToCollectPercentage, daysForReward.mul(48), true);

                compoundReward = _compound(
                    tempTotalTokens,
                    ratio,
                    cyclesForReward
                );
                _tempBattle.rewards += compoundReward;
            }
            else {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    (, cyclesForReward) = determineRewardCycles(_tempBattle.currentToCollectPercentage, daysForReward.mul(48), true);

                    compoundReward = _compound(
                        tempTotalTokens,
                        ratio,
                        cyclesForReward
                    );
                    _tempBattle.rewards += compoundReward;
                    tempTotalTokens += compoundReward;

                    _tempBattle.battleDaysExpended = 3;
                }

                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                bool continueBattle = daysForReward != 0;

                if (continueBattle) {
                    daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                    (_tempBattle.currentToCollectPercentage, cyclesForReward) = determineRewardCycles(
                        _tempBattle.currentToCollectPercentage,
                        daysForReward.mul(48),
                        false
                    );

                    compoundReward = _compound(
                        tempTotalTokens,
                        ratio,
                        cyclesForReward
                    );
                    _tempBattle.rewards += compoundReward;
                    tempTotalTokens += compoundReward;
                }
            }

            _tempBattle.battleDaysExpended = daysWagingBattle;
        }

        return _tempBattle;
    }

    function _compound(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
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