pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./FortunasToken.sol";
import "./IPancakePair.sol";
import "./IPancakeRouter02.sol";
import "./IPancakeFactory.sol";
import "./FortunasAssets.sol";

contract Battling is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using MathUpgradeable for uint256;

    uint256 public bribeToEmeperor;                         // percentage of staked amount sent to treasury every time battling or training occurs

    IPancakeRouter02 pancakeRouter;
    IPancakePair pancakePair;

    // LP Token for FRTNA-BUSD pair
    IERC20 LPToken;

    // Fortunas Multi Token for heroes and cavalry
    FortunasAssets public fortunasAssets;
    
    // FRTNA
    FortunasToken public fortunasToken = FortunasToken(payable(0));
    address treasuryWallet = address(fortunasToken);

    // BUSD
    address public BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    uint256 contractStartTime;                              // a certain epoch time for testing (11:00 AM, 13th May 2022)
    uint256 public rewardTime;                              // 30 minutes in epoch time
    uint256 public oneDayTime;                              // 1 day in epoch time
    uint256 public threeDayTime;                            // 3 daays in epoch time

    uint256 multiplierForReward;
    uint256 multiplierForMisc;

    uint256 rationsIncreasePercentage;

    uint256[5] rationsBase;                                 // rations %
    uint256[5] rationsIncrease;                             // percentage increase in rations percentages when reward limit is reached
    
    uint256[6] rewardBasePercentages;
    uint256 rewardIncreasePercentage;

    uint256[6] rewardLimit;                                 // rewardBase cannot exceed these amounts for battles
    uint256[6] rewardBase;                                  // 30 minute reward %
    uint256[6] rewardIncrease;                              // percentage of reward to add after every day of rations

    uint256[10] assetPercentages;
    uint256[10] assetPrices;

    uint256 randomAssetPrice;

    // structs

    struct Battle {
        uint256 originalTokensSent;
        uint256 rationsAmount;
        uint256 rewardAmount;
        uint256 currentRewardLimit;
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

    // constructor

    constructor() {
        bribeToEmeperor = 5000;

        // TODO (for mainnet) rather than using the constructor, use the setter function to initialize all the below variables to hide the values from the public eye
        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(address(0));
        // address _addressForPancakePair = IPancakeFactory(pancakeRouter.factory()).getPair(address(fortunasToken), BUSD);

        // pancakeRouter = _pancakeRouter;
        // pancakePair = IPancakePair(_addressForPancakePair);

        // LPToken = IERC20(_addressForPancakePair);

        fortunasAssets = new FortunasAssets("", address(this));

        contractStartTime = 1652421600;
        // rewardTime = 1800;
        // oneDayTime = 86400;
        // threeDayTime = 259200;
        rewardTime = 1;                                     // 1 second, only for testing
        oneDayTime = 48;                                    // 48 seconds, only for testing
        threeDayTime = 144;                                 // 2 minutes and 24 seconds, only for testing

        multiplierForReward = 1000000000;
        multiplierForMisc = 1000000;
        
        rationsIncreasePercentage = 125000;

        rationsBase = [2500, 5000, 7500, 10000, 12500];
        setRations();                                       // setting ration related variables

        rewardBasePercentages = [100, 100, 75, 50, 20, 10];
        rewardIncreasePercentage = 5000;

        rewardLimit = [520833, 1041667, 208333, 260416, 416650, 612500];
        setRewards();                                       // setting ration related variables

        assetPercentages = [2, 4, 6, 8, 10,                 // each hero's effect on the APY
                            1, 2, 3, 4, 5];                 // each cavalry's effect on the APY
        assetPrices = [2500, 5000, 7500, 10000, 12500,      // cost of purchasing each hero
                        2500, 5000, 7500, 10000, 12500];    // cost of purchasing each cavalry

        randomAssetPrice = 5000;
    }

    // getters

    function getAddressForBattle(address _walletAddress, uint _battleNumber) external view onlyOwner returns (Battle memory) {
        return addressForBattle[_walletAddress][_battleNumber];
    }

    function getNumberOfBattles(address _walletAddress) external view onlyOwner returns (uint256) {
        return numberOfBattles[_walletAddress];
    }

    // setters

    function setFortunasToken(address _contractAddress) external onlyOwner {
        fortunasToken = FortunasToken(payable(_contractAddress));
        treasuryWallet = address(fortunasToken);
    }

    function setFortunasAssets(address _contractAddress) external onlyOwner {
        fortunasAssets = FortunasAssets(_contractAddress);
    }

    function setLPToken(address _LPToken) external onlyOwner {
        LPToken = IERC20(_LPToken);
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
        for (uint256 i = 0 ; i < 5 ; i++) {
            rationsIncrease[i] = rationsBase[i].mul(rationsIncreasePercentage).roundDiv(multiplierForMisc);
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
        for (uint256 i = 0 ; i < 6 ; i++) {
            rewardBase[i] = rewardLimit[i].mul(rewardBasePercentages[i]).roundDiv(100);

            if (i == 0 || i == 1) {
                rewardIncrease[i] = 0;
            }
            else {
                rewardIncrease[i] = rewardLimit[i].mul(rewardIncreasePercentage).roundDiv(multiplierForMisc);
            }
        }
    }

    // functions

    function battleStart(uint256 _tokens, uint8 _battleType) external {
        require(_tokens >= 6400, "battleStart::Minimum amount of tokens for battle is 0.0000000000000064 FRTNA");
        require(2 <= _battleType && _battleType <= 6, "battleStart::No such battle type exists");
        uint256 allowance = fortunasToken.allowance(msg.sender, address(this));
        require(fortunasToken.balanceOf(msg.sender) >= _tokens, "battleStart::Insufficient funds");
        require(allowance >= _tokens, "battleStart::Not enough allowance to send tokens");


        uint256 bribe = _tokens.mul(bribeToEmeperor).div(multiplierForMisc);
        _tokens -= bribe;

        if (_battleType == 2) {
            LPToken.transferFrom(msg.sender, treasuryWallet, bribe);

            LPToken.transferFrom(msg.sender, address(this), _tokens);

            numberOfBattles[msg.sender]++;
            addressForBattle[msg.sender][numberOfBattles[msg.sender] - 1] = Battle(_tokens, 0, 0, rewardLimit[_battleType - 1], rewardBase[_battleType - 1], block.timestamp, block.timestamp, 0, 0, _battleType, 0, 0, 0, 0, 0);
        }
        else {
            fortunasToken.transferFrom(msg.sender, treasuryWallet, bribe);

            fortunasToken.transferFrom(msg.sender, address(this), _tokens);

            numberOfBattles[msg.sender]++;
            addressForBattle[msg.sender][numberOfBattles[msg.sender] - 1] = Battle(_tokens, 0, 0, rewardLimit[_battleType - 1], rewardBase[_battleType - 1], block.timestamp, block.timestamp, 0, 0, _battleType, 0, 0, 0, 0, 0);
        }
    }

    function sendRations(uint8 _battleType, uint256 _battleNumber, uint256 _rationDays) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "sendRations::No such battle is currently taking place");
        if (block.timestamp >= tempBattle.battleStartTime.add(threeDayTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
            require(false, "sendRations::Cannot send rations to battles that have already finished");
        }
        else {
            uint256 rationsExpended = block.timestamp.sub(tempBattle.battleStartTime.add(threeDayTime)).ceilDiv(oneDayTime);
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
        require(block.timestamp >= tempBattle.battleStartTime.add(threeDayTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeTokens::Cannot remove tokens from battles that have already finished");
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

        if (tempBattle.hero != 0) {
            tempBattle.losses += 200;
        }
        if (tempBattle.cavalry != 0) {
            tempBattle.losses += 20;
        }
        if (tempBattle.rationsAmount > 0) {
            tempBattle.losses += 2;
        }
        calculateLosses(tempBattle, tempBattle.losses, _battleNumber);

        require(fortunasToken.balanceOf(address(this)) >= _tokensToRemove, "removeTokens::Contract has insufficient balance. Please try again later");
        fortunasToken.transferFrom(address(this), msg.sender, _tokensToRemove);

        addressForBattle[msg.sender][_battleType - 1] = tempBattle;
    }

    function purchaseHero(uint8 _heroToPurchase) external {
        require(1 <= _heroToPurchase && _heroToPurchase <= 6, "purchaseHero::Incorrect hero specified");


        uint256 cost;
        if (_heroToPurchase == 6) {
            cost = randomAssetPrice;

            // TODO
            uint256 randNum = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
            randNum = randNum.mod(100);
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
        else {
            cost = assetPrices[_heroToPurchase - 1];
        }
        require(_heroToPurchase != 6, "purchaseHero::Error in randomizer");
        require(fortunasAssets.balanceOf(msg.sender, _heroToPurchase) == 0, "purchaseHero::You already own this hero");


        (uint256 reserves, , ) = pancakePair.getReserves();

        uint256 price = reserves.mul(cost).roundDiv(multiplierForMisc);
        fortunasToken.transferFrom(msg.sender, address(this), price);

        fortunasAssets.mint(msg.sender, _heroToPurchase, 1, "");
    }

    function purchaseCavalry(uint8 _cavalryToPurchase) external {
        require(6 <= _cavalryToPurchase && _cavalryToPurchase <= 10, "purchaseCavalry::Incorrect cavalry specified");
        require(fortunasAssets.balanceOf(msg.sender, _cavalryToPurchase) == 0, "purchaseCavalry::You already own this cavalry");


        (uint256 reserves, , ) = pancakePair.getReserves();

        uint256 price = reserves.mul(assetPrices[_cavalryToPurchase - 1]).roundDiv(multiplierForMisc);
        fortunasToken.transferFrom(msg.sender, address(this), price);

        fortunasAssets.mint(msg.sender, _cavalryToPurchase, 1, "");
    }

    function addHero(uint8 _heroToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(1 <= _heroToAdd && _heroToAdd <= 5, "addHero::Incorrect hero specified");
        require(fortunasAssets.balanceOf(msg.sender, _heroToAdd) == 1, "addHero::User does not own this hero");
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "addHero::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addHero::User can only add hero to easy, medium, hard or very hard battles");
        require(block.timestamp < tempBattle.battleStartTime.add(threeDayTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addHero::Cannot add heroes to battles that have already finished");
        require(addressForHeroBattle[msg.sender][_heroToAdd] == 0, "addHero::This hero is currently in another battle");
        require(tempBattle.hero == 0, "addHero::A hero is already in this battle");


        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        uint256 percentageToAdd = rewardLimit[_battleType - 1].mul(assetPercentages[_heroToAdd - 1]).roundDiv(100);
        tempBattle.currentRewardPercentage += percentageToAdd;
        tempBattle.hero = _heroToAdd;

        addressForHeroBattle[msg.sender][_heroToAdd] = _battleNumber;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function removeHero(uint8 _heroToRemove, uint8 _battleType, uint256 _battleNumber) public {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(1 <= _heroToRemove && _heroToRemove <= 5, "removeHero::Incorrect hero specified");
        require(fortunasAssets.balanceOf(msg.sender, _heroToRemove) == 1, "removeHero::User does not own this hero");
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "removeHero::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeHero::User can only remove hero from easy, medium, hard or very hard battles");
        require(addressForHeroBattle[msg.sender][_heroToRemove] == _battleNumber, "removeHero::Incorrect hero or battle number given");


        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        uint256 percentageToRemove = rewardLimit[_battleType - 1].mul(assetPercentages[_heroToRemove - 1]).roundDiv(100);
        tempBattle.currentRewardPercentage -= percentageToRemove;
        if (tempBattle.dayForLimitReached != 0) {
            tempBattle.dayForLimitReached = 0;
        }
        tempBattle.hero = 0;

        addressForHeroBattle[msg.sender][_heroToRemove] = 0;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function addCavalry(uint8 _cavalryToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(6 <= _cavalryToAdd && _cavalryToAdd <= 10, "addCavalry::Incorrect cavalry specified");
        require(fortunasAssets.balanceOf(msg.sender, _cavalryToAdd) == 1, "addCavalry::User does not own this cavalry");
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "addCavalry::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addCavalry::User can only add cavalry to easy, medium, hard or very hard battles");
        require(block.timestamp < tempBattle.battleStartTime.add(threeDayTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addCavalry::Cannot add cavalries to battles that have already finished");
        require(addressForCavalryBattle[msg.sender][_cavalryToAdd] == 0, "addCavalry::This cavalry unit is currently in another battle");
        require(tempBattle.cavalry == 0, "addHero::A cavalry unit is already in this battle");


        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        uint256 percentageToAdd = rewardLimit[_battleType - 1].mul(assetPercentages[_cavalryToAdd - 1]).roundDiv(100);
        tempBattle.currentRewardLimit += percentageToAdd;
        if (tempBattle.dayForLimitReached != 0) {
            if (tempBattle.currentRewardPercentage < tempBattle.currentRewardLimit) {
                tempBattle.dayForLimitReached = 0;
            }
        }
        tempBattle.cavalry = _cavalryToAdd;

        addressForCavalryBattle[msg.sender][_cavalryToAdd] = _battleNumber;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function removeCavalry(uint8 _cavalryToRemove, uint8 _battleType, uint256 _battleNumber) public {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(6 <= _cavalryToRemove && _cavalryToRemove <= 10, "removeCavalry::Incorrect cavalry specified");
        require(fortunasAssets.balanceOf(msg.sender, _cavalryToRemove) == 1, "removeCavalry::User does not own this cavalry");
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "removeCavalry::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeCavalry::User can only remove cavalry from easy, medium, hard or very hard battles");
        require(addressForCavalryBattle[msg.sender][_cavalryToRemove] == _battleNumber, "removeCavalry::Incorrect cavalry unit or battle number given");


        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
        uint256 percentageToRemove = rewardLimit[_battleType - 1].mul(assetPercentages[_cavalryToRemove - 1]).roundDiv(100);
        tempBattle.currentRewardLimit -= percentageToRemove;
        if (tempBattle.currentRewardPercentage >= tempBattle.currentRewardLimit) {
            tempBattle.dayForLimitReached = tempBattle.rewardCyclesDone.ceilDiv(48);
        }
        tempBattle.cavalry = 0;

        addressForCavalryBattle[msg.sender][_cavalryToRemove] = 0;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function battleEnd(uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(2 <= _battleType && _battleType <= 6, "battleEnd::Incorrect battle type");
        require(tempBattle.originalTokensSent != 0 && tempBattle.battleType == _battleType, "battleEnd::No such battle is currently taking place");


        (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, true);
        uint256 tokensToTransfer = tempBattle.originalTokensSent.add(tempBattle.rewardAmount);

        if (_battleType == 2) {
            require(LPToken.balanceOf(address(this)) >= tokensToTransfer, "battleEnd::Contract has insufficient LP Token balance. Please try again later");
            LPToken.transfer(msg.sender, tokensToTransfer);
        }
        else {
            require(fortunasToken.balanceOf(address(this)) >= tokensToTransfer, "battleEnd::Contract has insufficient Fortunas Token balance. Please try again later");
            fortunasToken.transfer(msg.sender, tokensToTransfer);

            calculateLosses(tempBattle, tempBattle.losses, _battleNumber);
        }

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
            require(block.timestamp >= _tempBattle.battleStartTime + threeDayTime, "calculateRewardsAndReturn::Training of troops lasts a fixed threeDayTime");
            startTimeForReward = _tempBattle.battleStartTime.div(rewardTime).mul(rewardTime);
            numberOfRewardCycles = _tempBattle.battleStartTime.add(threeDayTime).sub(startTimeForReward).div(rewardTime);

            for (uint256 i = 0 ; i < numberOfRewardCycles ; i++) {
                _tempBattle.rewardAmount += tempTotalTokens.mul(rewardBase[_tempBattle.battleType - 1]).div(multiplierForReward);
                tempTotalTokens += _tempBattle.rewardAmount;
            }
        }
        else {
            startTimeForReward = _tempBattle.battleRewardTime.div(rewardTime).mul(rewardTime);
            uint256 rationsEndTime = _tempBattle.battleStartTime.add(threeDayTime).add(_tempBattle.rationsDaysTotal.mul(oneDayTime));
            _tempBattle.battleRewardTime = block.timestamp;
            if (block.timestamp >= rationsEndTime &&
                _tempBattle.rationsDaysTotal > 0) {
                numberOfRewardCycles = rationsEndTime.sub(startTimeForReward).div(rewardTime);
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
            else if (block.timestamp >= _tempBattle.battleStartTime.add(threeDayTime) &&
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
            else if (block.timestamp >= _tempBattle.battleStartTime.add(threeDayTime) &&
                _tempBattle.rationsDaysTotal == 0) {
                numberOfRewardCycles = _tempBattle.battleStartTime.add(threeDayTime).sub(startTimeForReward).div(rewardTime);
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
            else if (block.timestamp < _tempBattle.battleStartTime.add(threeDayTime)) {
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
                if (_tempBattle.currentRewardPercentage >= _tempBattle.currentRewardLimit && _tempBattle.dayForLimitReached != 0) {
                    _tempBattle.currentRewardPercentage = _tempBattle.currentRewardLimit;
                    _tempBattle.dayForLimitReached = _tempBattle.rewardCyclesDone.div(48);

                }
                else if (_tempBattle.rewardCyclesDone >= uint256(48).mul(3) && _tempBattle.rewardCyclesDone.mod(48) == 0 && _tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit) {
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

                    if (extraCurrentRewardPercentage >= _tempBattle.currentRewardLimit && _tempBattle.dayForLimitReached != 0) {
                        extraCurrentRewardPercentage = _tempBattle.currentRewardLimit;
                        _tempBattle.dayForLimitReached = extraRewardCyclesDone.div(48);
                    }
                    else if (extraRewardCyclesDone >= uint256(48).mul(3) && extraRewardCyclesDone.mod(48) == 0 && _tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit) {
                        extraCurrentRewardPercentage += rewardIncrease[_tempBattle.battleType - 1];
                    }

                    extraRewardAmount += tempTotalTokens.mul(extraCurrentRewardPercentage).div(multiplierForReward);
                    tempTotalTokens += extraRewardAmount;
                }
            }
        }

        return (_tempBattle, extraRewardAmount);
    }

    function calculateLosses(Battle memory _tempBattle, uint256 _losses, uint256 _battleNumber) internal {
        // TODO
        uint256 randHero = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        uint256 randCavalry = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        uint256 randRations = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));

        randHero = randHero.mod(1000);
        randCavalry = randCavalry.mod(1000);
        randRations = randRations.mod(1000);

        uint256[3] memory posLosses;
        for (uint256 i = 0 ; i < 3 ; i++) {
            posLosses[i] = _losses.mod(10);
            _losses = _losses.div(10);
        }

        uint256 chanceToLoose = 500;
        uint256 chanceDecrease = _tempBattle.rewardCyclesDone.div(48).mul(10).div(2);
        chanceToLoose = chanceToLoose.safeSub(chanceDecrease);

        if (posLosses[2] == 2) {
            if (0 < randHero && randHero <= chanceToLoose) {
                removeHero(_tempBattle.hero, _tempBattle.battleType, _battleNumber);
                fortunasAssets.burn(msg.sender, _tempBattle.hero, 1);
            }
        }

        if (posLosses[1] == 2) {
            if (0 < randCavalry && randCavalry <= chanceToLoose) {
                removeCavalry(_tempBattle.hero, _tempBattle.battleType, _battleNumber);
                fortunasAssets.burn(msg.sender, _tempBattle.cavalry, 1);
            }
        }

        if (posLosses[0] == 2) {
            if (0 < randRations && randRations <= chanceToLoose) {
                fortunasToken.burn(address(this), _tempBattle.rationsAmount);
            }
        }

        _tempBattle.losses = 0;
    }

    /**
     * @dev Should be called if updated battle data needed
     * @dev Ideally to be called only if an update on current reward amount is needed
     * @dev Function "battleEnd" should be called if unstaking
     */
    function viewRewards(address _user) external view returns (uint256[] memory) {
        uint256 tempNumberOfBattles = numberOfBattles[_user];
        uint256[] memory tempRewards = new uint256[](tempNumberOfBattles);
        Battle memory tempBattle;
        uint256 counter = 0;
        for (uint256 i = 0 ; i < numberOfBattles[_user] ; i++) {
            tempBattle = addressForBattle[_user][i];
            if (tempBattle.originalTokensSent != 0) {
                (tempBattle, ) = calculateRewardsAndReturn(tempBattle, false, false);
                tempRewards[counter] = tempBattle.rewardAmount;
                counter++;
            }
        }

        if (tempNumberOfBattles > counter) {
            uint256[] memory rewardsToReturn = new uint256[](counter);
            for (uint256 i = 0 ; i < counter ; i++) {
                rewardsToReturn[i] = tempRewards[i];
            }

            return rewardsToReturn;
        }

        return tempRewards;
    }
}

// IMPORTANT TODO - can I have more than 1 hero in a battle or similarly can I have more than 1 cavalry in a battle

// TODO/Done LP staking
// TODO/Done conditions for addHero/addCavalry (owned or not) -> mapping?
// TODO/Done pancake pair reserve for purchasing/selling heroes/cavalry (maybe selling not needed)
// TODO/Done Fortunas Chance. Random Hero (L1 to L5)
// TODO/NotNeeded 33% chance of losing heroes, cavalry, rations when unstaking after battle finished
// TODO/Done 50% chance of losing heroes, cavalry, rations when unstaking before battle finished
// TODO/Done decrease in .5% chance of losing heroes, cavalry, rations after every ration day when unstaking before battle finished
// TODO/Done dividend tracking token
// TODO/Done cavalry increase in max limit
// TODO/Done check if isLimitReached is done properly
// TODO/Done math upgradeable -> add a function for round off and safe Sub -> ".roundDiv", ".safeSub" to make the code less clogged
// TODO/Done adjust getters (how do mappings and getters work) (do i even need so many getters)
// TODO/Done adjust setters (do i even need so many setters)
// TODO/Done Losses on remove troops and 50% of losses when unstaking after battle finished
// TODO/Done check with wasif for some TODOs about liquidity, LP Staking and pancake swap
// TODO/Done buy/sell fees
// TODO/Done Ludos? Lottery? Similar to Titano PLAY (https://app.sphere.finance/games)
// TODO/Done Heroes and cavalry -> NFTs (ERC1155)
// TODO/Done Heroes and cavalry -> make sure to add checks so that more than 1 of any type of NFT cant be owned (1 x L1 hero, 1 x L1 cavalry etc)
// TODO/Done FortunasToken -> make sure tax is only on selling/buying and not on every transfer -> add this contract's address to excludedFromFees mapping
// TODO Chainlink randomizer or api/oracle randomizer
// TODO FortunasToken -> clean unnecassery code from FortunasToken
// TODO set all unset values for testing and mainnet in Battling, FortunasToken, FortunasAssets and FortunasLottery
// TODO modifiers
// TODO divide reward function into 2?
// TODO code optimization and code cleaning

/*
Buying Taxes (10%)
2.5% Liquidity Pool
7.5% Treasury
Selling Taxes (10%)
7.5% Liquidity Pool
2.5% Treasury
*/