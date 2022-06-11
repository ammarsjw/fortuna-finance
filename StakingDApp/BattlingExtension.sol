pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./ABDKMath64x64.sol";
import "./BattlingBase.sol";
import "./ChainlinkDependencies.sol";
import "./IBattling.sol";

contract BattlingExtension is BattlingBase, VRFConsumerBaseV2 {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    // Chainlink VRF Variables

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    uint64 vrf_subscriptionId;

    uint256[] vrf_randomNumbers;
    uint256 vrf_requestId;

    // for loss
    address vrf_user;
    uint256 vrf_battleType;
    uint256 vrf_chanceToLose;
    bool vrf_isBattleEnd;
    uint8 vrf_scenario;

    // TODO
    address vrfCoordinator = address(0x6168499c0cFfCaCD319c818142124B7A15E857ab);

    address link_token_contract = address(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);

    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    uint32 callbackGasLimit = 100000;
    
    uint16 requestConfirmations = 3;

    // variables

    IBattling battling;

    // constructor

    constructor(uint64 _subscriptionId, address _battling) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link_token_contract);

        vrf_subscriptionId = _subscriptionId;

        battling = IBattling(_battling);
    }

    // Chainlink VRF functions

    function requestRandommessForLoss(
        uint32 _numbersNeeded,
        address _user,
        uint256 _battleType,
        uint256 _chanceToLose,
        bool _isBattleEnd,
        uint8 _scenario
    ) external onlyOwner {
        vrf_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            vrf_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            _numbersNeeded
        );

        // setting global variables for callback function
        vrf_user = _user;
        vrf_battleType = _battleType;
        vrf_chanceToLose = _chanceToLose;
        vrf_isBattleEnd = _isBattleEnd;
        vrf_scenario = _scenario;
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        vrf_randomNumbers = randomWords;

        if (vrf_scenario == 1) {
            battling.handleLosses(
                vrf_user,
                vrf_battleType,
                vrf_chanceToLose,
                vrf_isBattleEnd,
                vrf_randomNumbers[0],
                vrf_randomNumbers[1]
            );
        }
        else if (vrf_scenario == 2) {
            battling.handleLosses(
                vrf_user,
                vrf_battleType,
                vrf_chanceToLose,
                vrf_isBattleEnd,
                vrf_randomNumbers[0],
                0
            );
        }
        else if (vrf_scenario == 3) {
            battling.handleLosses(
                vrf_user,
                vrf_battleType,
                vrf_chanceToLose,
                vrf_isBattleEnd,
                0,
                vrf_randomNumbers[0]
            );
        }
    }

    function withdraw(address _to, uint256 _amount) external onlyOwner {
        // Transfer this contract's funds to an address.
        // 1000000000000000000 = 1 LINK
        LINKTOKEN.transfer(_to, _amount);
    }

    // functions

    function calculateRations(Battle memory _tempBattle, uint256 _extraRewards, uint256 _rationDays) external view onlyOwner returns (Battle memory, uint256) {
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

    function calculateRewards(Battle memory _tempBattle) public view onlyOwner returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 daysWagingBattle = block.timestamp.sub(_tempBattle.battleStartTime).div(oneDayTime);
        uint256 daysForReward;

        uint256 ratio = _tempBattle.currentRewardPercentage.mul(10 ** 18).div(multiplierForReward);
        uint256 compoundReward;
        if (daysWagingBattle.sub(_tempBattle.battleDaysExpended) != 0) {
            if (daysWagingBattle < 3) {
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                compoundReward = _compoundReward(
                    tempTotalTokens,
                    ratio,
                    daysForReward
                );
                _tempBattle.rewards += compoundReward;
            }
            else if (daysWagingBattle >= 3
            && daysWagingBattle < _tempBattle.rationsDaysTotal.add(3)
            && _tempBattle.rationsDaysTotal > 0) {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    compoundReward = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward
                    );
                    _tempBattle.rewards += compoundReward;
                    tempTotalTokens += compoundReward;

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
                    compoundReward = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent
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
        uint256 rewardPercentagePerCycle = _tempBattle.currentRewardPercentage.roundDiv(48);
        uint256 ratio = rewardPercentagePerCycle.mul(cyclesRemaining);
        ratio = ratio.mul(10 ** 18).div(multiplierForReward);

        uint256 extraRewards = _compoundReward(
            tempTotalTokens,
            ratio,
            1
        );
        tempTotalTokens += extraRewards;

        ratio = rewardPercentagePerCycle.mul(10 ** 18).div(multiplierForReward);

        uint256 nextReward = _compoundReward(
            tempTotalTokens,
            ratio,
            1
        );

        return (extraRewards, nextReward);
    }

    function calculateRewardsForBattleEnd(Battle memory _tempBattle) external view onlyOwner returns (Battle memory) {
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

            uint256 ratio = _tempBattle.currentRewardPercentage.mul(10 ** 18).div(multiplierForReward);
            uint256 compoundReward;
            if (_tempBattle.battleType == 2) {
                require(block.timestamp >= battleEndTime, "calculateRewardsForBattleEnd::BNE");

                compoundReward = _compoundReward(
                    tempTotalTokens,
                    ratio,
                    daysForReward
                );
                _tempBattle.rewards += compoundReward;
            }
            else {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    compoundReward = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward
                    );
                    _tempBattle.rewards += compoundReward;
                    tempTotalTokens += compoundReward;

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
                    compoundReward = _compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent
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

        uint256 accruedReward = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
        return accruedReward.sub(_principal);
    }
}