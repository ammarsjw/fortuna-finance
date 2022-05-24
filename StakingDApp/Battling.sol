pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Math.sol";
import "./FortunasToken.sol";

contract Battling is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using Math for uint256;

    address treasuryWallet;
    address liquidityProvider;

    uint256 contractStartTime;                          // a certain epoch time for testing (11:00 AM, 13th May 2022)
    uint256 timeSinceLastReward;
    uint256 public rewardTime;                          // 30 minutes in epoch time
    uint256 public oneDayTime;                          // 1 day in epoch time

    uint256 public bribeToEmeperor;                     // percentage of staked amount sent to treasury every time battling or training occurs

    uint256 multiplierForReward;
    uint256 multiplierForMisc;

    uint256[] rationsBase;                              // rations %

    uint256[] rationsIncrease;                          // percentage increase in rations percentages when reward limit is reached

    uint256 rationsIncreasePercentage;
    
    uint256[] rewardLimit;                              // rewardBase cannot exceed these amounts for battles

    uint256[] rewardBase;                               // 30 minute reward %

    uint256[] rewardIncrease;                           // percentage of reward to add after every day of rations

    uint256[] rewardBasePercentages;
    uint256 rewardIncreasePercentage;

    uint256[] heroPercentages;

    uint256[] cavalryPercentages;

    FortunasToken fortunasToken;

    address[] fortunasHolders;

    // structs

    struct Battle {
        uint256 originalTokensSent;
        uint256 rationsAmount;
        uint256 rewardAmount;
        uint256 currentRewardPercentage;
        uint256 battleStartTime;
        uint256 battleRewardTime;
        uint256 rewardCyclesDone;
        uint256 rationsDaysTotal;
        uint8 battleType;
        bool isRewardReset;
        uint256 dayForRewardReset;
    }

    // mappings

    mapping(address => mapping(uint256 => Battle)) addressForBattle;
    mapping(address => uint256) numberOfBattles;
    mapping(address => mapping(uint256 => uint8)) addressForHero;
    mapping(address => mapping(uint256 => uint8)) addressForCavalry;

    // constructor

    constructor() {
        treasuryWallet = msg.sender;                    // TODO change this after testing phase to the correct address
        liquidityProvider = msg.sender;                 // TODO change this after testing phase to the correct address

        contractStartTime = 1652421600;                 // TODO change after testing
        timeSinceLastReward = 1652421600;               // TODO change after testing
        rewardTime = 1800;
        oneDayTime = 86400;

        bribeToEmeperor = 5000;

        // TODO (for mainnet) rather than using the constructor, use the setter function to initialize all the below variables to hide the values from the public eye
        multiplierForReward = 1000000000;
        multiplierForMisc = 1000000;
        
        rationsBase = [1000, 2000, 3000, 4000, 5000];

        rationsIncrease = [125, 250, 375, 500, 625];

        rationsIncreasePercentage = 125000;

        rewardLimit = [520833, 1041667, 208333, 173611, 111107, 81667];

        rewardBase = [520833, 1041667, 156250, 86806, 22221, 8167];

        rewardIncrease = [0, 0, 1042, 868, 556, 408];

        rewardBasePercentages = [100, 100, 75, 50, 20, 10];
        rewardIncreasePercentage = 5000;

        heroPercentages = [2, 4, 6, 8, 10];

        cavalryPercentages = [1, 2, 3];
    }

    // getters

    function getTreasuryWallet() external view onlyOwner returns (address) {
        return treasuryWallet;
    }

    function getLiquidityProvider() external view onlyOwner returns (address) {
        return liquidityProvider;
    }

    function getContractStartTime() external view onlyOwner returns (uint256) {
        return contractStartTime;
    }

    function getTimeSinceLastReward() external view onlyOwner returns (uint256) {
        return timeSinceLastReward;
    }

    function getMultiplierForReward() external view onlyOwner returns (uint256) {
        return multiplierForReward;
    }

    function getMultiplierForMisc() external view onlyOwner returns (uint256) {
        return multiplierForMisc;
    }

    function getFortunasTokenContractAddress() external view onlyOwner returns (address) {
        return address(fortunasToken);
    }

    function getAddressForBattle(address _walletAddress, uint _battleNumber) external view onlyOwner returns (Battle memory) {
        return addressForBattle[_walletAddress][_battleNumber];
    }

    function getNumberOfBattles(address _walletAddress) external view onlyOwner returns (uint256) {
        return numberOfBattles[_walletAddress];
    }

    // setters

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        treasuryWallet = _treasuryWallet;
    }

    function setLiquidityProvider(address _liquidityProvider) external onlyOwner {
        liquidityProvider = _liquidityProvider;
    }

    function setContractStartTime(uint256 _contractStartTime) external onlyOwner {
        contractStartTime = _contractStartTime;
    }

    function setTimeSinceLastReward(uint256 _timeSinceLastReward) external onlyOwner {
        require(_timeSinceLastReward <= block.timestamp, "setTimeSinceLastReward::Time since last reward cannot be greater than current time");
        if (_timeSinceLastReward.mod(rewardTime) != 0) {
            _timeSinceLastReward = _timeSinceLastReward.mul(rewardTime).div(rewardTime);
        }
        timeSinceLastReward = _timeSinceLastReward;
    }

    function setRationsBase(uint256[5] memory _rationsBase) external onlyOwner {
        rationsBase = _rationsBase;

        setRations();
    }

    function setRationsIncreasePercentage(uint256 _rationsIncreasePercentage) external onlyOwner {
        rationsIncreasePercentage = _rationsIncreasePercentage;

        setRations();
    }

    function setRations() internal {
        uint256 result;
        for (uint256 i = 0 ; i < 5 ; i++) {
            result = rationsBase[i].mul(10).mul(rationsIncreasePercentage).div(multiplierForMisc);
            if (result.mod(10) >= 5) {
                rationsIncrease[i] = rationsBase[i].mul(rationsIncreasePercentage).ceilDiv(multiplierForMisc);
            }
            else {
                rationsIncrease[i] = rationsBase[i].mul(rationsIncreasePercentage).div(multiplierForMisc);
            }
        }
    }

    function setRewardLimit(uint256[6] memory _rewardLimit) external onlyOwner {
        rewardLimit = _rewardLimit;

        setRewards();
    }

    function setRewardBasePercentages(uint256[6] memory _rewardBasePercentages) external onlyOwner {
        rewardBasePercentages = _rewardBasePercentages;

        setRewards();
    }

    function setRewardIncreasePercentage(uint256 _rewardIncreasePercentage) external onlyOwner {
        rewardIncreasePercentage = _rewardIncreasePercentage;

        setRewards();
    }

    function setRewards() internal {
        uint256 result;
        for (uint256 i = 0 ; i < 6 ; i++) {
            result = rewardLimit[i].mul(10).mul(rewardBasePercentages[i]).div(100);
            if (result.mod(10) >= 5) {
                rewardBase[i] = rewardLimit[i].mul(rewardBasePercentages[i]).ceilDiv(100);
            }
            else {
                rewardBase[i] = rewardLimit[i].mul(rewardBasePercentages[i]).div(100);
            }
            if (i == 0 || i == 1) {
                rewardIncrease[i] = 0;
            }
            else {
                result = rewardLimit[i].mul(10).mul(rewardIncreasePercentage).div(multiplierForMisc);
                if (result.mod(10) >= 5) {
                    rewardIncrease[i] = rewardLimit[i].mul(rewardIncreasePercentage).ceilDiv(multiplierForMisc);
                }
                else {
                    rewardIncrease[i] = rewardLimit[i].mul(rewardIncreasePercentage).div(multiplierForMisc);
                }
            }
        }
    }

    function setFortunasTokenContractAddress(address _contractAddress) external onlyOwner {
        fortunasToken = FortunasToken(_contractAddress);
    }

    // functions

    function battleStart(uint256 _tokens, uint8 _battleType) external {
        uint256 allowance = fortunasToken.allowance(msg.sender, address(this));
        require(2 <= _battleType && _battleType <= 6, "battleStart::No such battle type exists");
        require(fortunasToken.balanceOf(msg.sender) >= _tokens, "battleStart::Insufficient manpower");
        require(allowance >= _tokens, "battleStart::Not enough allowance to send tokens");


        uint256 bribe = _tokens.mul(bribeToEmeperor).div(multiplierForMisc);
        _tokens -= bribe;
        fortunasToken.transferFrom(msg.sender, treasuryWallet, bribe);


        numberOfBattles[msg.sender]++;
        addressForBattle[msg.sender][numberOfBattles[msg.sender] - 1] = Battle(_tokens, 0, 0, rewardBase[_battleType - 1], block.timestamp, block.timestamp, 0, 0, _battleType, false, 0);
        fortunasToken.transferFrom(msg.sender, address(this), _tokens);
    }

    function sendRations(uint8 _battleType, uint256 _battleNumber, uint256 _rationDays) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "sendRations::No such battle is currently taking place");
        if (block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
            require(false, "sendRations::Cannot send rations to battles that have already finished");
        }
        else {
            uint256 rationsExpended = block.timestamp.sub(tempBattle.battleStartTime.add(3 days)).div(oneDayTime);
            uint256 tempRationDaysLeft = tempBattle.rationsDaysTotal.sub(rationsExpended).add(_rationDays);
            require(tempRationDaysLeft <= 5, "sendRations::Rations cannot exceed 5 days at a single given time");
        }
        require(3 <= _battleType && _battleType <= 6, "sendRations::User can only add rations to easy, medium, hard or very hard battles");
        require(1 <= _rationDays && _rationDays <= 5, "sendRations::Rations cannot exceed 5 days at a single given time");


        uint256 allowance = fortunasToken.allowance(msg.sender, address(this));
        uint256 extraRewardAmount;

        (tempBattle, extraRewardAmount) = calculateRewardsAndReturn(tempBattle, tempBattle.battleType);
        
        calculateRationsAndTransfer(allowance, tempBattle, _battleNumber, _rationDays, extraRewardAmount);
    }

    function calculateRationsAndTransfer(uint256 _allowance, Battle memory _tempBattle, uint256 _battleNumber, uint256 _rationDays, uint256 _extraRewardAmount) internal {
        uint256 totalTokens = _tempBattle.originalTokensSent.add(_tempBattle.rewardAmount).add(_extraRewardAmount);
        uint256 tempRations;
        uint256 totalPercentage;
        if (_tempBattle.rationsDaysTotal + _rationDays >= 50) {
            if (_tempBattle.rationsDaysTotal < 50) {
                uint256 daysPreIncrease = 50 - _tempBattle.rationsDaysTotal;
                tempRations = totalTokens.mul(rationsBase[daysPreIncrease - 1]).div(multiplierForMisc);
                if (_tempBattle.isRewardReset == false && _tempBattle.rationsAmount.add(tempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle = findDayForRewardReset(_tempBattle, daysPreIncrease, 1);
                }

                uint256 daysPostIncrease = (_tempBattle.rationsDaysTotal.add(_rationDays)) - 50;
                totalPercentage = rationsBase[daysPostIncrease - 1].add(rationsIncrease[daysPostIncrease - 1]);
                tempRations = totalTokens.mul(totalPercentage).div(multiplierForMisc);
                if (_tempBattle.isRewardReset == false && _tempBattle.rationsAmount.add(tempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle = findDayForRewardReset(_tempBattle, daysPostIncrease, 2);
                }
            }
            else {
                totalPercentage = rationsBase[_rationDays - 1].add(rationsIncrease[_rationDays - 1]);
                tempRations = totalTokens.mul(totalPercentage).div(multiplierForMisc);
                if (_tempBattle.isRewardReset == false && _tempBattle.rationsAmount.add(tempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle = findDayForRewardReset(_tempBattle, _rationDays, 3);
                }                
            }
        }
        else {
            tempRations = totalTokens.mul(rationsBase[_rationDays - 1]).div(multiplierForMisc);
            if (_tempBattle.isRewardReset == false && _tempBattle.rationsAmount.add(tempRations) > _tempBattle.originalTokensSent) {
                _tempBattle = findDayForRewardReset(_tempBattle, _rationDays, 4);
            }
        }
        require(fortunasToken.balanceOf(msg.sender) >= tempRations, "calculateRations::Not enough balance to send rations");
        require(_allowance >= tempRations, "calculateRations::Not enough allowance to send rations");


        fortunasToken.transferFrom(msg.sender, address(this), tempRations);

        _tempBattle.rationsAmount += tempRations;
        _tempBattle.rationsDaysTotal += _rationDays;
        addressForBattle[msg.sender][_battleNumber - 1] = _tempBattle;
    }

    function findDayForRewardReset(Battle memory _tempBattle, uint256 _days, uint8 _scenario) internal view returns (Battle memory) {
        uint256 totalTokens = _tempBattle.originalTokensSent.add(_tempBattle.rewardAmount);
        uint256 tempTempRations;
        uint256 totalPercentage;
        if (_scenario == 1 || _scenario == 4) {
            for (uint256 i = 0 ; i < _days ; i++) {
                tempTempRations = totalTokens.mul(rationsBase[i]).div(multiplierForMisc);
                if (_tempBattle.rationsAmount.add(tempTempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle.dayForRewardReset = _tempBattle.rationsDaysTotal.add(tempTempRations);
                    _tempBattle.isRewardReset = true;
                }
            }
        }
        else {
            for (uint256 i = 0 ; i < _days ; i++) {
                totalPercentage = rationsBase[i].add(rationsIncrease[i]);
                tempTempRations = totalTokens.mul(totalPercentage).div(multiplierForMisc);
                if (_tempBattle.rationsAmount.add(tempTempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle.dayForRewardReset = _tempBattle.rationsDaysTotal.add(tempTempRations);
                    _tempBattle.isRewardReset = true;
                }
            }
        }

        return _tempBattle;
    }

    function removeTokens(uint256 _tokensToRemove, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "removeTokens::No such battle is currently taking place");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, _battleType);
        require(block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeTokens::Cannot remove tokens from battles that have already finished");
        require(_tokensToRemove < tempBattle.originalTokensSent + tempBattle.rewardAmount, "removeTokens::Not enough tokens in this battle");


        if (_tokensToRemove > tempBattle.rewardAmount) {
            _tokensToRemove -= tempBattle.rewardAmount;
            tempBattle.rewardAmount = 0;
            tempBattle.originalTokensSent -= _tokensToRemove;
        }
        else {
            tempBattle.rewardAmount -= _tokensToRemove;
        }

        if (tempBattle.isRewardReset == false && tempBattle.rationsAmount > tempBattle.originalTokensSent) {
            tempBattle.dayForRewardReset = tempBattle.rationsDaysTotal;
            tempBattle.isRewardReset = true;
        }

        require(fortunasToken.balanceOf(address(this)) >= _tokensToRemove, "removeTokens::Contract has insufficient balance. Please try again later");
        fortunasToken.transferFrom(address(this), msg.sender, _tokensToRemove);

        addressForBattle[msg.sender][_battleType - 1] = tempBattle;
    }

    function addHero(uint8 _heroToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "addHero::No such battle is currently taking place");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, _battleType);
        require(block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addHero::Cannot remove tokens from battles that have already finished");
        // require for checking whether this user can add such a hero or not


        uint256 percentageToAdd = rewardBase[_battleType - 1].mul(heroPercentages[_heroToAdd - 1]).div(100);
        tempBattle.currentRewardPercentage += percentageToAdd;

        addressForHero[msg.sender][_battleNumber - 1] = _heroToAdd;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function removeHero(uint8 _heroToRemove, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "removeHero::No such battle is currently taking place");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, _battleType);
        require(block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeHero::Cannot remove tokens from battles that have already finished");
        require(_heroToRemove == addressForHero[msg.sender][_battleNumber - 1], "removeHero::Incorrect hero specified");


        uint256 percentageToRemove = rewardBase[_battleType - 1].mul(heroPercentages[_heroToRemove - 1]).div(100);
        tempBattle.currentRewardPercentage -= percentageToRemove;

        addressForHero[msg.sender][_battleNumber - 1] = 0;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function addCavalry(uint8 _cavalryToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "addCavalry::No such battle is currently taking place");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, _battleType);
        require(block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addCavalry::Cannot remove tokens from battles that have already finished");
        // require for checking whether this user can add such a cavalry or not


        uint256 percentageToAdd = rewardBase[_battleType - 1].mul(cavalryPercentages[_cavalryToAdd - 1]).div(100);
        tempBattle.currentRewardPercentage += percentageToAdd;

        addressForCavalry[msg.sender][_battleNumber - 1] = _cavalryToAdd;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function removeCavalry(uint8 _cavalryToRemove, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "removeCavalry::No such battle is currently taking place");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, _battleType);
        require(block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeCavalry::Cannot remove tokens from battles that have already finished");
        require(_cavalryToRemove == addressForCavalry[msg.sender][_battleNumber - 1], "removeCavalry::Incorrect cavalry specified");


        uint256 percentageToRemove = rewardBase[_battleType - 1].mul(cavalryPercentages[_cavalryToRemove - 1]).div(100);
        tempBattle.currentRewardPercentage -= percentageToRemove;

        addressForCavalry[msg.sender][_battleNumber - 1] = 0;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function battleEnd(uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(2 <= _battleType && _battleType <= 6, "battleEnd::Incorrect battle type");
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "battleEnd::No such battle is currently taking place");


        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, _battleType);

        uint256 totalTokens = tempBattle.originalTokensSent.add(tempBattle.rewardAmount);
        
        require(fortunasToken.balanceOf(address(this)) >= totalTokens, "battleEnd::Contract has insufficient balance. Please try again later");
        fortunasToken.transfer(msg.sender, totalTokens);

        addressForBattle[msg.sender][_battleNumber - 1] = Battle(0, 0, 0, 0, 0, 0, 0, 0, 0, false, 0);
    }

    function calculateRewardsAndReturn(Battle memory _tempBattle, uint8 _battleType) internal view returns (Battle memory, uint256) {
        uint256 startTimeForReward;
        uint256 numberOfRewardCycles;
        uint256 tempTotalTokens = _tempBattle.originalTokensSent.add(_tempBattle.rewardAmount);
        uint256 extraRewardAmount;

        if (_battleType == 2) {
            require(block.timestamp >= _tempBattle.battleStartTime + 3 days, "calculateReward::Training of tokens lasts a fixed 3 days");
            startTimeForReward = _tempBattle.battleStartTime.div(rewardTime).mul(rewardTime);
            numberOfRewardCycles = _tempBattle.battleStartTime.add(3 days).sub(startTimeForReward).div(rewardTime);

            for (uint256 i = 0 ; i < numberOfRewardCycles ; i++) {
                _tempBattle.rewardAmount += tempTotalTokens.mul(rewardBase[_battleType - 1]).div(multiplierForReward);
                tempTotalTokens += _tempBattle.rewardAmount;
            }
        }
        else {
            startTimeForReward = _tempBattle.battleRewardTime.div(rewardTime).mul(rewardTime);
            uint256 rationsEndTime = _tempBattle.battleStartTime.add(3 days).add(_tempBattle.rationsDaysTotal.mul(oneDayTime));
            bool isExtra = false;
            _tempBattle.battleRewardTime = block.timestamp;
            if (block.timestamp >= rationsEndTime &&
                _tempBattle.rationsDaysTotal > 0) {
                numberOfRewardCycles = rationsEndTime.sub(startTimeForReward).div(rewardTime);
            }
            else if (block.timestamp >= _tempBattle.battleStartTime.add(3 days) &&
                block.timestamp < rationsEndTime &&
                _tempBattle.rationsDaysTotal > 0) {
                numberOfRewardCycles = block.timestamp.sub(startTimeForReward).div(rewardTime);
                isExtra = true;
            }
            else if (block.timestamp >= _tempBattle.battleStartTime.add(3 days) &&
                _tempBattle.rationsDaysTotal == 0) {
                numberOfRewardCycles = _tempBattle.battleStartTime.add(3 days).sub(startTimeForReward).div(rewardTime);
            }
            else if (block.timestamp < _tempBattle.battleStartTime.add(3 days)) {
                numberOfRewardCycles = block.timestamp.sub(startTimeForReward).div(rewardTime);
            }

            for ( ; _tempBattle.rewardCyclesDone < numberOfRewardCycles ; _tempBattle.rewardCyclesDone++) {
                // isRewardReset
                if (_tempBattle.rewardCyclesDone == _tempBattle.dayForRewardReset.mul(48) && _tempBattle.isRewardReset == true) {
                    _tempBattle.currentRewardPercentage = rewardBase[_battleType - 1];
                }

                // isLimitReached
                if (_tempBattle.currentRewardPercentage > rewardLimit[_battleType - 1]) {
                    _tempBattle.currentRewardPercentage = rewardLimit[_battleType - 1];
                }
                else if (_tempBattle.rewardCyclesDone >= uint256(48).mul(3) && _tempBattle.rewardCyclesDone.mod(48) == 0) {
                    _tempBattle.currentRewardPercentage += rewardIncrease[_battleType -1];
                }

                _tempBattle.rewardAmount += tempTotalTokens.mul(_tempBattle.currentRewardPercentage).div(multiplierForReward);
                tempTotalTokens += _tempBattle.rewardAmount;
            }

            if (isExtra) {
                uint256 extraStartTimeForReward = _tempBattle.battleRewardTime;
                uint256 extraNumberOfRewardCycles;
                extraNumberOfRewardCycles = rationsEndTime.sub(extraStartTimeForReward).div(rewardTime);
                uint256 extraRewardCyclesDone = _tempBattle.rewardCyclesDone;
                uint256 extraCurrentRewardPercentage = _tempBattle.currentRewardPercentage;
                extraRewardAmount;
                for ( ; extraRewardCyclesDone < extraNumberOfRewardCycles ; extraRewardCyclesDone++) {
                    if (extraRewardCyclesDone == _tempBattle.dayForRewardReset.mul(48) && _tempBattle.isRewardReset == true) {
                        extraCurrentRewardPercentage = rewardBase[_battleType - 1];
                    }

                    if (extraCurrentRewardPercentage > rewardLimit[_battleType - 1]) {
                        extraCurrentRewardPercentage = rewardLimit[_battleType - 1];
                    }
                    else if (extraRewardCyclesDone >= uint256(48).mul(3) && extraRewardCyclesDone.mod(48) == 0) {
                        extraCurrentRewardPercentage += rewardIncrease[_battleType - 1];
                    }

                    extraRewardAmount += tempTotalTokens.mul(extraCurrentRewardPercentage).div(multiplierForReward);
                    tempTotalTokens += extraRewardAmount;
                }
            }
        }

        return (_tempBattle, extraRewardAmount);
    }
    
    /**
     * @dev Should be called if updated data on a battle is needed
     *      Subject to change
     *      Can be adjusted to calculate rewards for all battles for a specific user
     *      External function "battleEnd" must be called if the battle has already finished
     */
    function calculateRewardsAndSave(uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(2 <= _battleType && _battleType <= 6, "calculateRewardsAndSave::Incorrect battle type");
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "calculateRewardsAndSave::No such battle is currently taking place");
        require(block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "calculateRewardsAndSave::Cannot calculate rewards for battles that have already finished");


        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, _battleType);
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    /**
     * @dev Must be called from the frontend every 30 minutes to calculate and send reward to all $FRTNA holders
     */
    function sendRewardToHolders() external returns (bool) {
        if (block.timestamp >= rewardTime.mul(2).add(timeSinceLastReward) || timeSinceLastReward <= block.timestamp) {
            return false;
        }

        uint256 tempRewardAmount;
        for (uint256 i = 0 ; i < fortunasHolders.length ; i++) {
            if (fortunasToken.balanceOf(fortunasHolders[i]) != 0) {
                tempRewardAmount = fortunasToken.balanceOf(fortunasHolders[i]).mul(rewardBase[0]).div(multiplierForReward);
                require(fortunasToken.balanceOf(address(this)) > tempRewardAmount, "sendRewardToHolders::Contract has insufficient balance. Please try again later");
                fortunasToken.transfer(fortunasHolders[i], tempRewardAmount);
            }
        }

        timeSinceLastReward += rewardTime;

        return true;
    }
}