pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Math.sol";
import "./FortunasToken.sol";
import "./IPancakePair.sol";
import "./IPancakeRouter02.sol";
import "./IPancakeFactory.sol";
import "./IWBUSD.sol";

contract Battling is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using Math for uint256;

    uint256 public bribeToEmeperor;                     // percentage of staked amount sent to treasury every time battling or training occurs
    
    address treasuryWallet;
    
    IWBUSD wbusd;
    IPancakeFactory pancakeFactory;
    IPancakePair pancakePair;
    IPancakeRouter02 pancakeRouter;

    FortunasToken fortunasToken;

    uint256 contractStartTime;                          // a certain epoch time for testing (11:00 AM, 13th May 2022)
    uint256 timeSinceLastReward;
    uint256 public rewardTime;                          // 30 minutes in epoch time
    uint256 public oneDayTime;                          // 1 day in epoch time

    uint256 multiplierForReward;
    uint256 multiplierForMisc;

    uint256[5] rationsBase;                              // rations %
    uint256[5] rationsIncrease;                          // percentage increase in rations percentages when reward limit is reached

    uint256 rationsIncreasePercentage;
    
    uint256[6] rewardLimit;                              // rewardBase cannot exceed these amounts for battles
    uint256[6] rewardBase;                               // 30 minute reward %
    uint256[6] rewardIncrease;                           // percentage of reward to add after every day of rations

    uint256[6] rewardBasePercentages;
    uint256 rewardIncreasePercentage;

    uint256[5] heroPercentages;
    uint256[6] heroPrices;

    uint256[5] cavalryPercentages;
    uint256[5] cavalryPrices;

    // structs

    struct Battle {
        uint256 originalTokensSent;
        uint256 rationsAmount;
        uint256 rewardAmount;
        uint256 liquidityAmount;
        uint256 currentRewardPercentage;
        uint256 battleStartTime;
        uint256 battleRewardTime;
        uint256 rewardCyclesDone;
        uint256 rationsDaysTotal;
        uint8 battleType;
        uint256 dayForRewardReset;
        uint256 dayForLimitReached;
        uint8 hero;
        uint8 cavalry;
        uint256 losses;
    }

    // mappings

    mapping(address => mapping(uint256 => Battle)) addressForBattle;
    mapping(address => uint256) numberOfBattles;
    mapping(address => mapping(uint8 => uint256)) addressForHeroBattle;
    mapping(address => mapping(uint8 => uint256)) addressForCavalryBattle;
    mapping(address => mapping(uint8 => bool)) addressForOwnedHeroes;
    mapping(address => mapping(uint8 => bool)) addressForOwnedCavalries;

    // constructor

    constructor() {
        bribeToEmeperor = 5000;

        // TODO (for mainnet) rather than using the constructor, use the setter function to initialize all the below variables to hide the values from the public eye
        treasuryWallet = address(0);
        
        wbusd = IWBUSD(address(0));
        // mainnet
        // pancakeFactory = IPancakeFactory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
        // testnet
        pancakeFactory = IPancakeFactory(address(0));
        pancakePair = IPancakePair(pancakeFactory.getPair(address(fortunasToken), address(wbusd)));
        pancakeRouter = IPancakeRouter02(address(0));

        contractStartTime = 1652421600;
        timeSinceLastReward = 1652421600;
        // rewardTime = 1800;
        // oneDayTime = 86400;
        // 30 seconds, only for testing
        rewardTime = 30;
        // 24 minutes, only for testing
        oneDayTime = 1440;

        multiplierForReward = 1000000000;
        multiplierForMisc = 1000000;
        
        rationsBase = [2500, 5000, 7500, 10000, 12500];

        rationsIncrease = [125, 250, 375, 500, 625];

        rationsIncreasePercentage = 125000;

        rewardLimit = [520833, 1041667, 208333, 260416, 416650, 612500];

        rewardBase = [520833, 1041667, 156250, 130208, 83330, 61250];

        rewardIncrease = [0, 0, 1042, 1302, 2083, 3063];

        rewardBasePercentages = [100, 100, 75, 50, 20, 10];
        rewardIncreasePercentage = 5000;

        heroPercentages = [2, 4, 6, 8, 10];

        heroPrices = [2500, 5000, 7500, 10000, 12500, 5000];

        cavalryPercentages = [1, 2, 3, 4, 5];

        cavalryPrices = [2500, 5000, 7500, 10000, 12500];
    }

    // getters

    function getTreasuryWallet() external view onlyOwner returns (address) {
        return treasuryWallet;
    }

    function getFortunasToken() external view onlyOwner returns (address) {
        return address(fortunasToken);
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

    function setFortunasToken(address _contractAddress) external onlyOwner {
        fortunasToken = FortunasToken(_contractAddress);
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

    // functions

    function battleStart(uint256 _tokens, uint8 _battleType) external {
        require(2 <= _battleType && _battleType <= 6, "battleStart::No such battle type exists");
        uint256 allowance = fortunasToken.allowance(msg.sender, address(this));
        require(fortunasToken.balanceOf(msg.sender) >= _tokens, "battleStart::Insufficient funds");
        require(allowance >= _tokens, "battleStart::Not enough allowance to send tokens");


        uint256 bribe = _tokens.mul(bribeToEmeperor).div(multiplierForMisc);
        _tokens -= bribe;
        fortunasToken.transferFrom(msg.sender, treasuryWallet, bribe);

        if (_battleType == 2) {
            (, , uint256 tempLiquidityAmount) = pancakeRouter.addLiquidity(
                address(fortunasToken),
                address(wbusd),
                _tokens,
                _tokens, // TODO how much wbusd to be sent along with $FRTNA Tokens
                _tokens,
                _tokens,
                msg.sender,
                block.timestamp.add(60)
            );

            numberOfBattles[msg.sender]++;
            addressForBattle[msg.sender][numberOfBattles[msg.sender] - 1] = Battle(_tokens, 0, 0, tempLiquidityAmount, rewardBase[_battleType - 1], block.timestamp, block.timestamp, 0, 0, _battleType, 0, 0, 0, 0, 0);
        }
        else {
            fortunasToken.transferFrom(msg.sender, address(this), _tokens);

            numberOfBattles[msg.sender]++;
            addressForBattle[msg.sender][numberOfBattles[msg.sender] - 1] = Battle(_tokens, 0, 0, 0, rewardBase[_battleType - 1], block.timestamp, block.timestamp, 0, 0, _battleType, 0, 0, 0, 0, 0);
        }
    }

    function sendRations(uint8 _battleType, uint256 _battleNumber, uint256 _rationDays) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "sendRations::No such battle is currently taking place");
        if (block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
            require(false, "sendRations::Cannot send rations to battles that have already finished");
        }
        else {
            uint256 rationsExpended = block.timestamp.sub(tempBattle.battleStartTime.add(3 days)).ceilDiv(oneDayTime);
            uint256 currentRationsDays = tempBattle.rationsDaysTotal.sub(rationsExpended).add(_rationDays);
            require(currentRationsDays <= 5, "sendRations::Rations cannot exceed 5 days at a single given time");
        }
        require(3 <= _battleType && _battleType <= 6, "sendRations::User can only add rations to easy, medium, hard or very hard battles");
        require(1 <= _rationDays && _rationDays <= 5, "sendRations::Rations cannot exceed 5 days at a single given time");


        uint256 allowance = fortunasToken.allowance(msg.sender, address(this));
        uint256 extraRewardAmount;

        (tempBattle, extraRewardAmount) = calculateRewardsAndReturn(tempBattle, true, false);
        
        calculateRationsAndTransfer(allowance, tempBattle, _battleNumber, _rationDays, extraRewardAmount);
    }

    function calculateRationsAndTransfer(uint256 _allowance, Battle memory _tempBattle, uint256 _battleNumber, uint256 _rationDays, uint256 _extraRewardAmount) internal {
        uint256 totalTokens = _tempBattle.originalTokensSent.add(_tempBattle.rewardAmount).add(_extraRewardAmount);
        uint256 tempRations;
        uint256 totalPercentage;
        if (_tempBattle.rationsDaysTotal + _rationDays >= _tempBattle.dayForLimitReached) {
            if (_tempBattle.rationsDaysTotal < _tempBattle.dayForLimitReached) {
                uint256 daysPreIncrease = _tempBattle.dayForLimitReached - _tempBattle.rationsDaysTotal;
                tempRations = totalTokens.mul(rationsBase[daysPreIncrease - 1]).div(multiplierForMisc);
                if (_tempBattle.dayForRewardReset == 0 && _tempBattle.rationsAmount.add(tempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle = findDayForRewardReset(_tempBattle, daysPreIncrease, 1);
                }

                uint256 daysPostIncrease = (_tempBattle.rationsDaysTotal.add(_rationDays)) - _tempBattle.dayForLimitReached;
                totalPercentage = rationsBase[daysPostIncrease - 1].add(rationsIncrease[daysPostIncrease - 1]);
                tempRations = totalTokens.mul(totalPercentage).div(multiplierForMisc);
                if (_tempBattle.dayForRewardReset == 0 && _tempBattle.rationsAmount.add(tempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle = findDayForRewardReset(_tempBattle, daysPostIncrease, 2);
                }
            }
            else {
                totalPercentage = rationsBase[_rationDays - 1].add(rationsIncrease[_rationDays - 1]);
                tempRations = totalTokens.mul(totalPercentage).div(multiplierForMisc);
                if (_tempBattle.dayForRewardReset == 0 && _tempBattle.rationsAmount.add(tempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle = findDayForRewardReset(_tempBattle, _rationDays, 3);
                }                
            }
        }
        else {
            tempRations = totalTokens.mul(rationsBase[_rationDays - 1]).div(multiplierForMisc);
            if (_tempBattle.dayForRewardReset == 0 && _tempBattle.rationsAmount.add(tempRations) > _tempBattle.originalTokensSent) {
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
                }
            }
        }
        else {
            for (uint256 i = 0 ; i < _days ; i++) {
                totalPercentage = rationsBase[i].add(rationsIncrease[i]);
                tempTempRations = totalTokens.mul(totalPercentage).div(multiplierForMisc);
                if (_tempBattle.rationsAmount.add(tempTempRations) > _tempBattle.originalTokensSent) {
                    _tempBattle.dayForRewardReset = _tempBattle.rationsDaysTotal.add(tempTempRations);
                }
            }
        }

        return _tempBattle;
    }

    function removeTokens(uint256 _tokensToRemove, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "removeTokens::No such battle is currently taking place");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
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

        if (tempBattle.dayForRewardReset == 0 && tempBattle.rationsAmount > tempBattle.originalTokensSent) {
            tempBattle.dayForRewardReset = tempBattle.rationsDaysTotal;
        }

        require(fortunasToken.balanceOf(address(this)) >= _tokensToRemove, "removeTokens::Contract has insufficient balance. Please try again later");
        fortunasToken.transferFrom(address(this), msg.sender, _tokensToRemove);

        addressForBattle[msg.sender][_battleType - 1] = tempBattle;
    }

    function purchaseHero(uint8 _heroToPurchase, uint256 randomizer) external {
        require(1 <= _heroToPurchase && _heroToPurchase <= 6, "purchaseHero::Incorrect hero specified");
        require(addressForOwnedHeroes[msg.sender][_heroToPurchase] == false, "purchaseHero::You already own this hero");

        (uint256 reserves, , ) = pancakePair.getReserves();

        uint8 heroForCost = _heroToPurchase;
        if (_heroToPurchase == 6 && randomizer != 0) {
            // TODO off chain randomizer
            uint256 randNum = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
            randNum = randNum.mul(randomizer).mod(100);
            if (0 < randNum && randNum <= 50) {
                _heroToPurchase = 1;
            }
            else if (50 < randNum && randNum <= 75) {
                _heroToPurchase = 2;
            }
            else if (75 < randNum && randNum <= 90) {
                _heroToPurchase = 3;
            }
            else if (90 < randNum && randNum <= 99) {
                _heroToPurchase = 4;
            }
            else if (randNum == 0) {
                _heroToPurchase = 5;
            }
        }
        require(_heroToPurchase != 6, "purchaseHero::Error in randomizer");
        uint256 price = reserves.mul(10).mul(heroPrices[heroForCost - 1]).div(multiplierForMisc);
        if (price.mod(10) >= 5) {
            price = reserves.mul(heroPrices[heroForCost - 1]).ceilDiv(multiplierForMisc);
        }
        else {
            price = reserves.mul(heroPrices[heroForCost - 1]).div(multiplierForMisc);
        }
        fortunasToken.transferFrom(msg.sender, address(this), price);

        addressForOwnedHeroes[msg.sender][_heroToPurchase] = true;
    }

    function purchaseCavalry(uint8 _cavalryToPurchase) external {
        require(1 <= _cavalryToPurchase && _cavalryToPurchase <= 5, "purchaseCavalry::Incorrect cavalry specified");
        require(addressForOwnedCavalries[msg.sender][_cavalryToPurchase] == false, "purchaseCavalry::You already own this cavalry");

        (uint256 reserves, , ) = pancakePair.getReserves();

        uint256 price = reserves.mul(10).mul(cavalryPrices[_cavalryToPurchase - 1]).div(multiplierForMisc);
        if (price.mod(10) >= 5) {
            price = reserves.mul(cavalryPrices[_cavalryToPurchase - 1]).ceilDiv(multiplierForMisc);
        }
        else {
            price = reserves.mul(cavalryPrices[_cavalryToPurchase - 1]).div(multiplierForMisc);
        }
        fortunasToken.transferFrom(msg.sender, address(this), price);

        addressForOwnedCavalries[msg.sender][_cavalryToPurchase] = true;
    }

    function addHero(uint8 _heroToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "addHero::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addHero::User can only add hero to easy, medium, hard or very hard battles");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        require(block.timestamp < tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addHero::Cannot add heroes to battles that have already finished");
        require(addressForOwnedHeroes[msg.sender][_heroToAdd], "addHero::User does not own this hero");
        require(addressForHeroBattle[msg.sender][_heroToAdd] == 0, "addHero::This hero is currently in another battle");
        require(tempBattle.hero == 0, "addHero::A hero is already in this battle");


        uint256 percentageToAdd;
        uint256 result = rewardLimit[_battleType - 1].mul(10).mul(heroPercentages[_heroToAdd - 1]).div(100);
        if (result.mod(10) >= 5) {
            percentageToAdd = rewardLimit[_battleType - 1].mul(heroPercentages[_heroToAdd - 1]).ceilDiv(100);
        }
        else {
            percentageToAdd = rewardLimit[_battleType - 1].mul(heroPercentages[_heroToAdd - 1]).div(100);
        }
        tempBattle.currentRewardPercentage += percentageToAdd;
        tempBattle.hero = _heroToAdd;

        addressForHeroBattle[msg.sender][_heroToAdd] = _battleNumber;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function removeHero(uint8 _heroToRemove, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "removeHero::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeHero::User can only remove hero from easy, medium, hard or very hard battles");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        require(block.timestamp < tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeHero::Cannot remove heroes from battles that have already finished");
        require(addressForHeroBattle[msg.sender][_heroToRemove] == _battleNumber, "removeHero::Incorrect hero or battle number given");


        uint256 percentageToRemove;
        uint256 result = rewardLimit[_battleType - 1].mul(10).mul(heroPercentages[_heroToRemove - 1]).div(100);
        if (result.mod(10) >= 5) {
            percentageToRemove = rewardLimit[_battleType - 1].mul(heroPercentages[_heroToRemove - 1]).ceilDiv(100);
        }
        else {
            percentageToRemove = rewardLimit[_battleType - 1].mul(heroPercentages[_heroToRemove - 1]).div(100);
        }
        tempBattle.currentRewardPercentage -= percentageToRemove;
        tempBattle.dayForLimitReached = 0;
        tempBattle.hero = 0;

        addressForHeroBattle[msg.sender][_heroToRemove] = 0;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function addCavalry(uint8 _cavalryToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "addCavalry::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addCavalry::User can only add cavalry to easy, medium, hard or very hard battles");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        require(block.timestamp < tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addCavalry::Cannot add cavalries to battles that have already finished");
        require(addressForOwnedCavalries[msg.sender][_cavalryToAdd], "addCavalry::User does not own this cavalry");
        require(addressForCavalryBattle[msg.sender][_cavalryToAdd] == 0, "addCavalry::This cavalry unit is currently in another battle");
        require(tempBattle.cavalry == 0, "addHero::A cavalry unit is already in this battle");


        uint256 percentageToAdd;
        uint256 result = rewardLimit[_battleType - 1].mul(10).mul(cavalryPercentages[_cavalryToAdd - 1]).div(100);
        if (result.mod(10) >= 5) {
            percentageToAdd = rewardLimit[_battleType - 1].mul(cavalryPercentages[_cavalryToAdd - 1]).ceilDiv(100);
        }
        else {
            percentageToAdd = rewardLimit[_battleType - 1].mul(cavalryPercentages[_cavalryToAdd - 1]).div(100);
        }
        tempBattle.currentRewardPercentage += percentageToAdd;
        tempBattle.cavalry = _cavalryToAdd;

        addressForCavalryBattle[msg.sender][_cavalryToAdd] = _battleNumber;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function removeCavalry(uint8 _cavalryToRemove, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "removeCavalry::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeCavalry::User can only remove cavalry from easy, medium, hard or very hard battles");
        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        require(block.timestamp < tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeCavalry::Cannot remove cavalries from battles that have already finished");
        require(addressForCavalryBattle[msg.sender][_cavalryToRemove] == _battleNumber, "removeCavalry::Incorrect cavalry unit or battle number given");


        uint256 percentageToRemove;
        uint256 result = rewardLimit[_battleType - 1].mul(10).mul(cavalryPercentages[_cavalryToRemove - 1]).div(100);
        if (result.mod(10) >= 5) {
            percentageToRemove = rewardLimit[_battleType - 1].mul(cavalryPercentages[_cavalryToRemove - 1]).ceilDiv(100);
        }
        else {
            percentageToRemove = rewardLimit[_battleType - 1].mul(cavalryPercentages[_cavalryToRemove - 1]).div(100);
        }
        tempBattle.currentRewardPercentage -= percentageToRemove;
        tempBattle.dayForLimitReached = 0;
        tempBattle.cavalry = 0;

        addressForCavalryBattle[msg.sender][_cavalryToRemove] = 0;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function battleEnd(uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(2 <= _battleType && _battleType <= 6, "battleEnd::Incorrect battle type");
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "battleEnd::No such battle is currently taking place");


        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, true);
        uint256 tokensToTransfer;

        if (_battleType == 2) {
            tokensToTransfer = tempBattle.rewardAmount;

            pancakeRouter.removeLiquidity(
                address(fortunasToken),
                address(wbusd),
                tempBattle.liquidityAmount,
                tempBattle.originalTokensSent,
                tempBattle.originalTokensSent,
                msg.sender,
                block.timestamp.add(60)
            );
        }
        else {
            tokensToTransfer = tempBattle.originalTokensSent.add(tempBattle.rewardAmount);
 
            calculateLosses(tempBattle, tempBattle.losses);
        }

        require(fortunasToken.balanceOf(address(this)) >= tokensToTransfer, "battleEnd::Contract has insufficient balance. Please try again later");
        fortunasToken.transfer(msg.sender, tokensToTransfer);

        addressForHeroBattle[msg.sender][tempBattle.hero] = 0;
        addressForCavalryBattle[msg.sender][tempBattle.cavalry] = 0;
        Battle memory emptyBattle;
        addressForBattle[msg.sender][_battleNumber - 1] = emptyBattle;
    }

    function calculateRewardsAndReturn(Battle memory _tempBattle, bool _isPotentialNeeded, bool isBattleEnd) internal view returns (Battle memory, uint256) {
        uint256 startTimeForReward;
        uint256 numberOfRewardCycles;
        uint256 tempTotalTokens = _tempBattle.originalTokensSent.add(_tempBattle.rewardAmount);
        uint256 extraRewardAmount;

        if (_tempBattle.battleType == 2) {
            require(block.timestamp >= _tempBattle.battleStartTime + 3 days, "calculateRewardsAndReturn::Training of troops lasts a fixed 3 days");
            startTimeForReward = _tempBattle.battleStartTime.div(rewardTime).mul(rewardTime);
            numberOfRewardCycles = _tempBattle.battleStartTime.add(3 days).sub(startTimeForReward).div(rewardTime);

            for (uint256 i = 0 ; i < numberOfRewardCycles ; i++) {
                _tempBattle.rewardAmount += tempTotalTokens.mul(rewardBase[_tempBattle.battleType - 1]).div(multiplierForReward);
                tempTotalTokens += _tempBattle.rewardAmount;
            }
        }
        else {
            startTimeForReward = _tempBattle.battleRewardTime.div(rewardTime).mul(rewardTime);
            uint256 rationsEndTime = _tempBattle.battleStartTime.add(3 days).add(_tempBattle.rationsDaysTotal.mul(oneDayTime));
            _tempBattle.battleRewardTime = block.timestamp;
            if (block.timestamp >= rationsEndTime &&
                _tempBattle.rationsDaysTotal > 0) {
                numberOfRewardCycles = rationsEndTime.sub(startTimeForReward).div(rewardTime);
                // if (isBattleEnd) {
                //     if (_tempBattle.hero != 0) {
                //         _tempBattle.losses += 100;
                //     }
                //     if (_tempBattle.cavalry != 0) {
                //         _tempBattle.losses += 10;
                //     }
                //     _tempBattle.losses += 1;
                // }
            }
            else if (block.timestamp >= _tempBattle.battleStartTime.add(3 days) &&
                block.timestamp < rationsEndTime &&
                _tempBattle.rationsDaysTotal > 0) {
                numberOfRewardCycles = block.timestamp.sub(startTimeForReward).div(rewardTime);
                if (isBattleEnd) {
                    if (_tempBattle.hero != 0) {
                        _tempBattle.losses += 200;
                    }
                    if (_tempBattle.cavalry != 0) {
                        _tempBattle.losses += 20;
                    }
                    _tempBattle.losses += 2;
                }
            }
            else if (block.timestamp >= _tempBattle.battleStartTime.add(3 days) &&
                _tempBattle.rationsDaysTotal == 0) {
                numberOfRewardCycles = _tempBattle.battleStartTime.add(3 days).sub(startTimeForReward).div(rewardTime);
                // if (isBattleEnd) {
                //     if (_tempBattle.hero != 0) {
                //         _tempBattle.losses += 100;
                //     }
                //     if (_tempBattle.cavalry != 0) {
                //         _tempBattle.losses += 10;
                //     }
                //     _tempBattle.losses += 0;
                // }
            }
            else if (block.timestamp < _tempBattle.battleStartTime.add(3 days)) {
                numberOfRewardCycles = block.timestamp.sub(startTimeForReward).div(rewardTime);
                if (isBattleEnd) {
                    if (_tempBattle.hero != 0) {
                        _tempBattle.losses += 200;
                    }
                    if (_tempBattle.cavalry != 0) {
                        _tempBattle.losses += 20;
                    }
                    _tempBattle.losses += 0;
                }
            }

            for ( ; _tempBattle.rewardCyclesDone < numberOfRewardCycles ; _tempBattle.rewardCyclesDone++) {
                // isRewardReset
                if (_tempBattle.rewardCyclesDone == _tempBattle.dayForRewardReset.mul(48) && _tempBattle.dayForRewardReset != 0) {
                    _tempBattle.currentRewardPercentage = rewardBase[_tempBattle.battleType - 1];
                }

                // isLimitReached
                if (_tempBattle.currentRewardPercentage >= rewardLimit[_tempBattle.battleType - 1] && _tempBattle.dayForLimitReached != 0) {
                    _tempBattle.currentRewardPercentage = rewardLimit[_tempBattle.battleType - 1];
                    _tempBattle.dayForLimitReached = _tempBattle.rewardCyclesDone.div(48);

                }
                else if (_tempBattle.rewardCyclesDone >= uint256(48).mul(3) && _tempBattle.rewardCyclesDone.mod(48) == 0 && _tempBattle.currentRewardPercentage < rewardLimit[_tempBattle.battleType - 1]) {
                    _tempBattle.currentRewardPercentage += rewardIncrease[_tempBattle.battleType -1];
                }

                _tempBattle.rewardAmount += tempTotalTokens.mul(_tempBattle.currentRewardPercentage).div(multiplierForReward);
                tempTotalTokens += _tempBattle.rewardAmount;
            }

            if (_isPotentialNeeded) {
                uint256 extraStartTimeForReward = _tempBattle.battleRewardTime;
                uint256 extraNumberOfRewardCycles;
                extraNumberOfRewardCycles = rationsEndTime.sub(extraStartTimeForReward).div(rewardTime);
                uint256 extraRewardCyclesDone = _tempBattle.rewardCyclesDone;
                uint256 extraCurrentRewardPercentage = _tempBattle.currentRewardPercentage;
                for ( ; extraRewardCyclesDone < extraNumberOfRewardCycles ; extraRewardCyclesDone++) {
                    if (extraRewardCyclesDone == _tempBattle.dayForRewardReset.mul(48) && _tempBattle.dayForRewardReset != 0) {
                        extraCurrentRewardPercentage = rewardBase[_tempBattle.battleType - 1];
                    }

                    if (extraCurrentRewardPercentage >= rewardLimit[_tempBattle.battleType - 1] && _tempBattle.dayForLimitReached != 0) {
                        extraCurrentRewardPercentage = rewardLimit[_tempBattle.battleType - 1];
                        _tempBattle.dayForLimitReached = extraRewardCyclesDone.div(48);
                    }
                    else if (extraRewardCyclesDone >= uint256(48).mul(3) && extraRewardCyclesDone.mod(48) == 0 && _tempBattle.currentRewardPercentage < rewardLimit[_tempBattle.battleType - 1]) {
                        extraCurrentRewardPercentage += rewardIncrease[_tempBattle.battleType - 1];
                    }

                    extraRewardAmount += tempTotalTokens.mul(extraCurrentRewardPercentage).div(multiplierForReward);
                    tempTotalTokens += extraRewardAmount;
                }
            }
        }

        return (_tempBattle, extraRewardAmount);
    }

    function calculateLosses(Battle memory _tempBattle, uint256 _losses) internal {
        uint256 randHero = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        uint256 randCavalry = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        uint256 randRations = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));

        randHero = randHero.mod(1000);
        randCavalry = randCavalry.mod(1000);
        randRations = randRations.mod(1000);

        uint256[] memory posLosses;
        for (uint256 i = 0 ; i < 3 ; i++) {
            posLosses[i] = _losses.mod(10);
            _losses = _losses.div(10);
        }

        uint256 chanceToLoose = 500;
        uint256 chanceDecrease = _tempBattle.rewardCyclesDone.div(48).mul(10).div(2);
        if (chanceDecrease >= chanceToLoose) {
            chanceToLoose = 0;
        }
        else {
            chanceToLoose -= chanceDecrease;
        }

        if (posLosses[2] == 2) {
            if (0 < randHero && randHero <= chanceToLoose) {
                addressForOwnedHeroes[msg.sender][_tempBattle.hero] = false;
            }
        }
        // else if (posLosses[2] == 1) {
        //     if (0 < randHero && randHero <= 33) {
        //         addressForOwnedHeroes[msg.sender][_tempBattle.hero] = false;
        //     }
        // }

        if (posLosses[1] == 2) {
            if (0 < randCavalry && randCavalry <= chanceToLoose) {
                addressForOwnedCavalries[msg.sender][_tempBattle.cavalry] = false;
            }
        }
        // else if (posLosses[1] == 1) {
        //     if (0 < randCavalry && randCavalry <= 33) {
        //         addressForOwnedCavalries[msg.sender][_tempBattle.cavalry] = false;
        //     }
        // }

        if (posLosses[0] == 2) {
            if (0 < randRations && randRations <= chanceToLoose) {
                fortunasToken.burn(address(this), _tempBattle.rationsAmount);
            }
        }
        // else if (posLosses[0] == 1) {
        //     if (0 < randRations && randRations <= 33) {
        //         fortunasToken.burn(address(this), _tempBattle.rationsAmount);
        //     }
        // }
    }

    /**
     * @dev Should be called if updated battle data needed
     *      Ideally to be called only if an update on current reward amount is needed
     *      Function "battleEnd" should be called if unstaking
     */
    function viewRewards() external view returns (uint256[] memory) {
        uint256[] memory tempRewards;
        Battle memory tempBattle;
        uint256 counter = 0;
        for (uint256 i = 0 ; i < numberOfBattles[msg.sender] ; i++) {
            tempBattle = addressForBattle[msg.sender][i];
            if (tempBattle.originalTokensSent != 0) {
                (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
                tempRewards[counter] = tempBattle.rewardAmount;
                counter++;
            }
        }

        return tempRewards;
    }
    // function viewRewards(uint8 _battleType, uint256 _battleNumber) external view returns (Battle memory) {
    //     Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
    //     require(2 <= _battleType && _battleType <= 6, "calculateRewardsAndSave::Incorrect battle type");
    //     require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "calculateRewardsAndSave::No such battle is currently taking place");
    //     require(block.timestamp >= tempBattle.battleStartTime.add(3 days).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "calculateRewardsAndSave::Cannot calculate rewards for battles that have already finished");


    //     (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        
    //     return tempBattle;
    // }

    /**
     * @dev Must be called from the frontend every 30 minutes to calculate and send reward to all $FRTNA holders
     */
    // function sendRewardToHolders() external returns (bool) {
    //     if (block.timestamp >= rewardTime.mul(2).add(timeSinceLastReward) || timeSinceLastReward <= block.timestamp) {
    //         return false;
    //     }

    //     uint256 tempRewardAmount;
    //     for (uint256 i = 0 ; i < fortunasHolders.length ; i++) {
    //         if (fortunasToken.balanceOf(fortunasHolders[i]) != 0) {
    //             tempRewardAmount = fortunasToken.balanceOf(fortunasHolders[i]).mul(rewardBase[0]).div(multiplierForReward);
    //             require(fortunasToken.balanceOf(address(this)) > tempRewardAmount, "sendRewardToHolders::Contract has insufficient balance. Please try again later");
    //             fortunasToken.transfer(fortunasHolders[i], tempRewardAmount);
    //         }
    //     }

    //     timeSinceLastReward += rewardTime;

    //     return true;
    // }
}

// IMPORTANT TODO - can I have more than 1 hero in a battle or similarly can I have more than 1 cavalry in a battle

// TODO/Done LP staking
// TODO/Done conditions for addHero/addCavalry (owned or not) -> mapping?
// TODO/Done pancake pair reserve for purchasing/selling heroes/cavalry (maybe selling not needed)
// TODO/Done Fortunas Chance. Random Hero (L1 to L5)
// TODO/NotNeeded 33% chance of losing heroes, cavalry, rations when unstaking after battle finished
// TODO/Done 50% chance of losing heroes, cavalry, rations when unstaking before battle finished
// TODO/Done decrease in .5% chance of losing heroes, cavalry, rations after every ration day when unstaking before battle finished
// TODO adjust getters and setters
// TODO modifiers
// TODO math upgradeable -> add a function for round off -> ".roundDiv" to make the code less clogged
// TODO dividend tracking token
// TODO Ludos? Lottery? Similar to Titano PLAY (https://app.sphere.finance/games)
// TODO burn rations to help with inflation? Currently burning rations when unstaking
// TODO Chainlink randomizer