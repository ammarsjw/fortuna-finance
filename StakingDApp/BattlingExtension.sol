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

    // variables

    uint256[5] public rationsPercentages;                   // rations %
    uint256 public rationsIncreasePercentage;               // percentage increase in rations percentages when to collect limit is reached

    // constructor

    constructor() {
        // PancakeRouter02 mainnet
        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        // TODO remove
        IPancakeRouter02 _pancakeRouter;
        if (block.chainid == 97) {
            _pancakeRouter = IPancakeRouter02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        }
        else if (block.chainid == 4) {
            _pancakeRouter = IPancakeRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        }
        IPancakeFactory _pancakeFactory = IPancakeFactory(_pancakeRouter.factory());

        rng_pancakeRouter = _pancakeRouter;
        rng_pancakeFactory = _pancakeFactory;

        rationsPercentages = [2500, 5000, 7500, 10000, 12500];
        rationsIncreasePercentage = 125000;
    }

    // RNG functions

    function createRandomness(uint256 _chance, uint256 _multiplier) public view onlyOwner returns (bool) {
        if (_chance == 0) {
            return false;
        }

        uint256 pairSelector =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, tx.origin)))
                .mod(rng_pancakeFactory.allPairsLength().safeSub(2));

        address addressForPancakePair1 = rng_pancakeFactory.allPairs(pairSelector);
        address addressForPancakePair2 = rng_pancakeFactory.allPairs(pairSelector++);
        address addressForPancakePair3 = rng_pancakeFactory.allPairs(pairSelector++);

        uint256 a = IPancakePair(addressForPancakePair1).price0CumulativeLast();
        uint256 b = IPancakePair(addressForPancakePair1).price1CumulativeLast();

        uint256 c = IPancakePair(addressForPancakePair2).price0CumulativeLast();
        uint256 d = IPancakePair(addressForPancakePair2).price1CumulativeLast();

        uint256 e = IPancakePair(addressForPancakePair3).price0CumulativeLast();
        uint256 f = IPancakePair(addressForPancakePair3).price1CumulativeLast();

        uint256 randomChance =
            uint256(keccak256(abi.encodePacked(a, b, c, d, e, f, block.timestamp))).mod(_multiplier).add(1);

        return randomChance <= _chance;
    }

    function createMassRandomness(uint256 _chance, uint256 _multiplier, uint256 counter) public view onlyOwner returns (bool) {
        if (_chance == 0) {
            return false;
        }

        uint256 pairSelector =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, tx.origin, counter)))
                .mod(rng_pancakeFactory.allPairsLength().safeSub(1));

        address addressForPancakePair1 = rng_pancakeFactory.allPairs(pairSelector);
        address addressForPancakePair2 = rng_pancakeFactory.allPairs(pairSelector++);

        uint256 a = IPancakePair(addressForPancakePair1).price0CumulativeLast();
        uint256 b = IPancakePair(addressForPancakePair1).price1CumulativeLast();

        uint256 c = IPancakePair(addressForPancakePair2).price0CumulativeLast();

        uint256 randomChance =
            uint256(keccak256(abi.encodePacked(a, b, c, counter))).mod(_multiplier).add(1);

        return randomChance <= _chance;
    }

    function createRandomnessForAsset() external view onlyOwner returns (uint256) {
        uint256 pairSelector =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, tx.origin)))
                .mod(rng_pancakeFactory.allPairsLength());

        address addressForPancakePair1 = rng_pancakeFactory.allPairs(pairSelector++);
        address addressForPancakePair2 = rng_pancakeFactory.allPairs(pairSelector++);
        address addressForPancakePair3 = rng_pancakeFactory.allPairs(pairSelector++);

        uint256 a = IPancakePair(addressForPancakePair1).price0CumulativeLast();
        uint256 b = IPancakePair(addressForPancakePair1).price1CumulativeLast();
        (uint256 c, , ) = IPancakePair(addressForPancakePair1).getReserves();

        uint256 d = IPancakePair(addressForPancakePair2).price0CumulativeLast();
        uint256 e = IPancakePair(addressForPancakePair2).price1CumulativeLast();
        (uint256 f, , ) = IPancakePair(addressForPancakePair2).getReserves();

        uint256 g = IPancakePair(addressForPancakePair3).price0CumulativeLast();
        uint256 h = IPancakePair(addressForPancakePair3).price1CumulativeLast();
        (uint256 i, , ) = IPancakePair(addressForPancakePair3).getReserves();

        uint256 randomChance =
            uint256(keccak256(abi.encodePacked(a, b, c, d, e, f, g, h, i, block.timestamp))).mod(100).add(1);

        uint256 result;

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

    // functions

    function determineRewardCycles(
        uint256 _currentToCollectPercentage,
        uint256 _numberOfCycles,
        bool isStatic
    ) internal view returns (uint256, uint256) {
        uint256 numberOfWins;

        if (isStatic) {
            for (uint256 i = 0 ; i < _numberOfCycles ; i++) {
                bool result = createMassRandomness(_currentToCollectPercentage, 1000, i);

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

                bool result = createMassRandomness(_currentToCollectPercentage, 1000, i);

                if (result) {
                    numberOfWins++;
                }
            }
        }

        return (_currentToCollectPercentage, numberOfWins);
    }

    function calculateRations(
        Battle memory _tempBattle,
        uint256 _rationDays
    ) external view onlyOwner returns (uint256) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);
        uint256 tempRations;

        tempRations = tempTotalTokens.mul(rationsPercentages[_rationDays - 1]).div(multiplier);

        if (_tempBattle.currentToCollectPercentage == 1000) {
            uint256 ratio = rationsIncreasePercentage.mul(10 ** 18).div(multiplier);

            uint256 rationsIncreaseAmount = _compound(
                tempRations,
                ratio,
                _rationDays
            );

            tempRations += rationsIncreaseAmount;
        }

        return tempRations;
    }

    function calculateRewards(Battle memory _tempBattle) public view onlyOwner returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 daysWagingBattle = block.timestamp.sub(_tempBattle.battleStartTime).div(oneDayTime);

        uint256 ratio = _tempBattle.currentRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForReward);

        uint256 daysForReward;
        uint256 cyclesForReward;
        uint256 compoundReward;

        uint256 cyclesToComplete = block.timestamp.sub(_tempBattle.battleDaysExpended.mul(oneDayTime).add(_tempBattle.battleStartTime)).div(rewardTime);

        if (
            cyclesToComplete > _tempBattle.cyclesCompleted &&
            _tempBattle.cyclesRemaining != 0
        ) {
            _tempBattle = completeRemainingCycles(_tempBattle);
        }

        if (daysWagingBattle.sub(_tempBattle.battleDaysExpended) != 0) {
            if (daysWagingBattle < 3) {
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                cyclesForReward = daysForReward.mul(48);

                if (_tempBattle.currentToCollectPercentage != 1000) {
                    (, cyclesForReward) = determineRewardCycles(
                        _tempBattle.currentToCollectPercentage,
                        daysForReward.mul(48),
                        true
                    );
                }

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

                    cyclesForReward = daysForReward.mul(48);

                    if (_tempBattle.currentToCollectPercentage != 1000) {
                        (, cyclesForReward) = determineRewardCycles(
                            _tempBattle.currentToCollectPercentage,
                            daysForReward.mul(48),
                            true
                        );
                    }

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

                cyclesForReward = daysForReward.mul(48);

                if (_tempBattle.currentToCollectPercentage != 1000) {
                    (_tempBattle.currentToCollectPercentage, cyclesForReward) = determineRewardCycles(
                        _tempBattle.currentToCollectPercentage,
                        daysForReward.mul(48),
                        false
                    );
                }

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

        if (
            cyclesToComplete > 0 &&
            _tempBattle.cyclesCompleted == 0
        ) {
            _tempBattle = completeCycles(_tempBattle);
        }

        require(
            block.timestamp <
            _tempBattle.battleStartTime.add(baseBattleTime).add(_tempBattle.rationsDaysTotal.mul(oneDayTime)),
            "calculateRewards::BE"
        );

        return _tempBattle;
    }

    function completeRemainingCycles(Battle memory _tempBattle) internal view returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 ratio = _tempBattle.currentRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForReward);

        uint256 cyclesToComplete = block.timestamp.sub(_tempBattle.battleDaysExpended.mul(oneDayTime).add(_tempBattle.battleStartTime)).div(rewardTime);
        if (cyclesToComplete.add(_tempBattle.cyclesCompleted) >= 48) {
            cyclesToComplete = _tempBattle.cyclesRemaining;
            _tempBattle.cyclesCompleted = 0;
            _tempBattle.cyclesRemaining = 0;
            _tempBattle.battleDaysExpended++;
        }
        else {
            cyclesToComplete = cyclesToComplete.sub(_tempBattle.cyclesCompleted);
            _tempBattle.cyclesCompleted += cyclesToComplete;
            _tempBattle.cyclesRemaining -= cyclesToComplete;
        }
        uint256 cyclesForReward = cyclesToComplete;

        if (_tempBattle.currentToCollectPercentage != 1000) {
            (, cyclesForReward) = determineRewardCycles(
                _tempBattle.currentToCollectPercentage,
                cyclesToComplete,
                true
            );
        }

        _tempBattle.rewards += _compound(
            tempTotalTokens,
            ratio,
            cyclesForReward
        );

        return _tempBattle;
    }

    function completeCycles(Battle memory _tempBattle) internal view returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 ratio = _tempBattle.currentRewardPercentagePerCycle.mul(10 ** 18).div(multiplierForReward);

        uint256 cyclesToComplete = block.timestamp.sub(_tempBattle.battleDaysExpended.mul(oneDayTime).add(_tempBattle.battleStartTime)).div(rewardTime);
        uint256 cyclesForReward = cyclesToComplete;

        if (_tempBattle.currentToCollectPercentage != 1000) {
            (, cyclesForReward) = determineRewardCycles(
                _tempBattle.currentToCollectPercentage,
                cyclesToComplete,
                true
            );
        }

        _tempBattle.rewards += _compound(
            tempTotalTokens,
            ratio,
            cyclesForReward
        );

        _tempBattle.cyclesCompleted = cyclesToComplete;
        _tempBattle.cyclesRemaining = uint256(48).sub(cyclesToComplete);

        return _tempBattle;
    }

    function calculateRewardsForEndBattle(Battle memory _tempBattle) external view onlyOwner returns (Battle memory) {
        uint256 battleEndTime = _tempBattle.rationsDaysTotal.add(3).mul(oneDayTime).add(_tempBattle.battleStartTime);

        if (block.timestamp < battleEndTime && _tempBattle.battleType != 2) {
            _tempBattle = calculateRewards(_tempBattle);
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

                compoundReward = _compound(
                    tempTotalTokens,
                    ratio,
                    daysForReward.mul(48)
                );
                _tempBattle.rewards += compoundReward;
            }
            else {
                cyclesForReward = block.timestamp.sub(_tempBattle.battleDaysExpended.mul(oneDayTime).add(_tempBattle.battleStartTime)).div(rewardTime);

                if (
                    cyclesForReward > _tempBattle.cyclesCompleted &&
                    _tempBattle.cyclesRemaining != 0
                ) {
                    _tempBattle = completeRemainingCycles(_tempBattle);
                }

                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    cyclesForReward = daysForReward.mul(48);

                    if (_tempBattle.currentToCollectPercentage != 1000) {
                        (, cyclesForReward) = determineRewardCycles(
                            _tempBattle.currentToCollectPercentage,
                            daysForReward.mul(48),
                            true
                        );
                    }

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
                    cyclesForReward = daysForReward.mul(48);

                    if (_tempBattle.currentToCollectPercentage != 1000) {
                        (_tempBattle.currentToCollectPercentage, cyclesForReward) = determineRewardCycles(
                            _tempBattle.currentToCollectPercentage,
                            daysForReward.mul(48),
                            false
                        );
                    }

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

            // TODO change "60" to "rewardTime"
            cyclesForReward = block.timestamp.sub(battleEndTime).div(60);

            ratio = rewardPercentagesPerCycle[0].mul(10 ** 18).div(multiplierForReward);

            _tempBattle.passiveRewards = _compound(
                tempTotalTokens,
                ratio,
                cyclesForReward
            );
        }

        return _tempBattle;
    }

    function _compound(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return 0;
        }

        bool isInteger = _ratio.mod(10000000) == 0;

        uint256 accruedReward = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);

        if (isInteger) {
            accruedReward++;
        }

        return accruedReward.sub(_principal);
    }

    // testing only
    function testRewardTime(uint256 _seconds) public {
        rewardTime = _seconds;
        oneDayTime = _seconds.mul(48);
        baseBattleTime = _seconds.mul(144);
    }

    function testToCollectPercentage(uint256 _chanceToCollect) public {
        toCollectPercentages = [1000, 1000, _chanceToCollect, _chanceToCollect, _chanceToCollect, _chanceToCollect];
    }
}