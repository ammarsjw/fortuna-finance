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
import "./ABDKMath64x64.sol";

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
    uint256 public baseBattleTime;                          // 3 daays in epoch time

    uint256 multiplier;
    uint256 multiplierForReward;

    uint256 rationsIncreasePercentage;

    uint256[5] rationsBase;                                 // rations %
    uint256[5] rationsIncrease;                             // percentage increase in rations percentages when reward limit is reached
    
    uint256[6] rewardBasePercentages;
    uint256 rewardIncreasePerDay;

    uint256[6] rewardLimit;                                 // rewardBase cannot exceed these amounts for battles
    uint256[6] rewardBase;                                  // 30 minute reward %

    uint256[10] assetPercentages;
    uint256[10] assetPrices;

    uint256 randomAssetPrice;

    // structs

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
        uint8 hero;
        uint8 cavalry;
        uint256 losses;
    }

    // mappings

    mapping(address => mapping(uint256 => Battle)) private addressForBattle;
    mapping(address => uint256) private numberOfBattles;
    mapping(address => mapping(uint8 => uint256)) private addressForHeroBattle;
    mapping(address => mapping(uint8 => uint256)) private addressForCavalryBattle;

    // constructor

    constructor() {
        bribeToEmeperor = 5000;

        // TODO (for mainnet) rather than using the constructor, use the setter function to initialize all the below variables to hide the values from the public eye
        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(address(0));
        // address _addressForPancakePair = IPancakeFactory(pancakeRouter.factory()).getPair(address(fortunasToken), BUSD);

        // pancakeRouter = _pancakeRouter;
        // pancakePair = IPancakePair(_addressForPancakePair);

        // LPToken = IERC20(_addressForPancakePair);

        // fortunasAssets = new FortunasAssets("", address(this));

        contractStartTime = 1652421600;
        // rewardTime = 1800;
        // oneDayTime = 86400;
        // baseBattleTime = 259200;
        rewardTime = 1;                                     // 1 second, only for testing
        oneDayTime = 48;                                    // 48 seconds, only for testing
        baseBattleTime = 144;                               // 2 minutes and 24 seconds, only for testing

        multiplier = 1000000;
        multiplierForReward = 10000000;
        
        rationsIncreasePercentage = 125000;

        rationsBase = [2500, 5000, 7500, 10000, 12500];
        setRations();                                       // setting ration related variables

        rewardBasePercentages = [100, 100, 75, 50, 20, 10];
        rewardIncreasePerDay = 5;

        rewardLimit = [25000, 50000, 1000, 1250, 2000, 2940];
        setRewards();                                       // setting reward related variables

        assetPercentages = [20, 40, 60, 80, 100,            // each hero's effect on current APY
                            10, 20, 30, 40, 50];            // each cavalry's effect on total APY
        assetPrices = [2500, 5000, 7500, 10000, 12500,      // percentage cost of LP for purchasing each hero
                        2500, 5000, 7500, 10000, 12500];    // percentage cost of LP for purchasing each cavalry

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
            rationsIncrease[i] = rationsBase[i].mul(rationsIncreasePercentage).roundDiv(multiplier);
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

    function setrewardIncreasePerDay(uint256 _rewardIncreasePerDay) external onlyOwner {
        rewardIncreasePerDay = _rewardIncreasePerDay;

        setRewards();
    }

    function setRewards() internal {
        for (uint256 i = 0 ; i < 6 ; i++) {
            rewardBase[i] = rewardLimit[i].mul(rewardBasePercentages[i]).roundDiv(100);
        }
    }

    // functions

    function battleStart(uint256 _tokens, uint8 _battleType) external {
        require(_tokens >= 13334, "battleStart::Minimum amount of tokens for battle is 0.000000000000013334 FRTNA");
        require(2 <= _battleType && _battleType <= 6, "battleStart::No such battle type exists");
        uint256 allowance = fortunasToken.allowance(msg.sender, address(this));
        require(fortunasToken.balanceOf(msg.sender) >= _tokens, "battleStart::Insufficient funds");
        require(allowance >= _tokens, "battleStart::Not enough allowance to send tokens");


        uint256 bribe = _tokens.mul(bribeToEmeperor).div(multiplier);
        _tokens -= bribe;

        if (_battleType == 2) {
            LPToken.transferFrom(msg.sender, treasuryWallet, bribe);

            LPToken.transferFrom(msg.sender, address(this), _tokens);

            numberOfBattles[msg.sender]++;
            addressForBattle[msg.sender][numberOfBattles[msg.sender] - 1] = Battle(_tokens, 0, 0, 0, rewardLimit[_battleType - 1], rewardBase[_battleType - 1], block.timestamp, 0, 0, 0, _battleType, 0, 0, 0);
        }
        else {
            fortunasToken.transferFrom(msg.sender, treasuryWallet, bribe);

            fortunasToken.transferFrom(msg.sender, address(this), _tokens);

            numberOfBattles[msg.sender]++;
            addressForBattle[msg.sender][numberOfBattles[msg.sender] - 1] = Battle(_tokens, 0, 0, 0, rewardLimit[_battleType - 1], rewardBase[_battleType - 1], block.timestamp, 0, 0, 0, _battleType, 0, 0, 0);
        }
    }

    function sendRations(uint8 _battleType, uint256 _battleNumber, uint256 _rationDays) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.initialTokensStaked != 0 && tempBattle.battleType == _battleType, "sendRations::No such battle is currently taking place");
        if (block.timestamp >= tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
            require(false, "sendRations::Cannot send rations to battles that have already finished");
        }
        else {
            uint256 rationsExpended = block.timestamp.sub(tempBattle.battleStartTime.add(baseBattleTime)).ceilDiv(oneDayTime);
            uint256 currentRationsDays = tempBattle.rationsDaysTotal.sub(rationsExpended).add(_rationDays);
            require(currentRationsDays <= 5, "sendRations::Rations cannot exceed 5 days at a single given time");
        }
        require(3 <= _battleType && _battleType <= 6, "sendRations::User can only add rations to easy, medium, hard or very hard battles");
        require(1 <= _rationDays && _rationDays <= 5, "sendRations::Rations cannot exceed 5 days at a single given time");


        uint256 allowance = fortunasToken.allowance(msg.sender, address(this));
        uint256 extraRewards;

        tempBattle = calculateRewards(tempBattle);
        
        calculateRationsAndTransfer(allowance, tempBattle, _battleNumber, _rationDays, extraRewards);
    }

    function calculateRationsAndTransfer(uint256 _allowance, Battle memory _tempBattle, uint256 _battleNumber, uint256 _rationDays, uint256 _extraRewards) internal {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards).add(_extraRewards);
        uint256 tempRations;
        uint256 totalPercentage;
        if (_tempBattle.rationsDaysTotal + _rationDays >= _tempBattle.dayForLimitReached) {
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
        require(fortunasToken.balanceOf(msg.sender) >= tempRations, "calculateRations::Not enough balance to send rations");
        require(_allowance >= tempRations, "calculateRations::Not enough allowance to send rations");


        fortunasToken.transferFrom(msg.sender, address(this), tempRations);

        _tempBattle.rations += tempRations;
        _tempBattle.rationsDaysTotal += _rationDays;
        addressForBattle[msg.sender][_battleNumber - 1] = _tempBattle;
    }

    function addTroops(uint256 _tokensToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.initialTokensStaked != 0 && tempBattle.battleType == _battleType, "addTroops::No such battle is currently taking place");
        require(block.timestamp >= tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addTroops::Cannot remove tokens from battles that have already finished");


        tempBattle = calculateRewards(tempBattle);
        if (tempBattle.additionalTokens + _tokensToAdd > tempBattle.initialTokensStaked) {
            tempBattle.currentRewardPercentage = rewardBase[tempBattle.battleType - 1];
            if (tempBattle.hero > 0) {
                tempBattle.currentRewardPercentage += assetPercentages[tempBattle.hero - 1];
            }
        }

        fortunasToken.transferFrom(msg.sender, address(this), _tokensToAdd);

        addressForBattle[msg.sender][_battleType - 1] = tempBattle;
    }

    function removeTroops(uint256 _tokensToRemove, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(tempBattle.initialTokensStaked != 0 && tempBattle.battleType == _battleType, "removeTroops::No such battle is currently taking place");
        require(block.timestamp >= tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeTroops::Cannot remove tokens from battles that have already finished");
        require(_tokensToRemove < tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards), "removeTroops::Not enough tokens in this battle");


        tempBattle = calculateRewards(tempBattle);
        if (_tokensToRemove > tempBattle.additionalTokens) {
            _tokensToRemove -= tempBattle.additionalTokens;
            tempBattle.additionalTokens = 0;
            if (_tokensToRemove > tempBattle.rewards) {
                _tokensToRemove -= tempBattle.rewards;
                tempBattle.rewards = 0;
                tempBattle.initialTokensStaked -= _tokensToRemove;
            }
            else {
                tempBattle.rewards -= _tokensToRemove;
            }
        }
        else {
            tempBattle.additionalTokens -= _tokensToRemove;
        }

        if (tempBattle.hero != 0) {
            tempBattle.losses += 200;
        }
        if (tempBattle.cavalry != 0) {
            tempBattle.losses += 20;
        }
        tempBattle.losses += 2;
        calculateLosses(tempBattle, tempBattle.losses, _battleNumber);

        require(fortunasToken.balanceOf(address(this)) >= _tokensToRemove, "removeTroops::Contract has insufficient balance. Please try again later");
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
        // require(fortunasAssets.ownershipOf(msg.sender, _heroToPurchase) == false, "purchaseHero::You already own this hero");


        (uint256 reserves, , ) = pancakePair.getReserves();

        uint256 price = reserves.mul(cost).roundDiv(multiplier);
        fortunasToken.transferFrom(msg.sender, address(this), price);

        fortunasAssets.mint(msg.sender, _heroToPurchase, 1, "");
    }

    function purchaseCavalry(uint8 _cavalryToPurchase) external {
        require(6 <= _cavalryToPurchase && _cavalryToPurchase <= 10, "purchaseCavalry::Incorrect cavalry specified");
        // require(fortunasAssets.ownershipOf(msg.sender, _cavalryToPurchase) == false, "purchaseCavalry::You already own this cavalry");


        (uint256 reserves, , ) = pancakePair.getReserves();

        uint256 price = reserves.mul(assetPrices[_cavalryToPurchase - 1]).roundDiv(multiplier);
        fortunasToken.transferFrom(msg.sender, address(this), price);

        fortunasAssets.mint(msg.sender, _cavalryToPurchase, 1, "");
    }

    function addHero(uint8 _heroToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(1 <= _heroToAdd && _heroToAdd <= 5, "addHero::Incorrect hero specified");
        // require(fortunasAssets.ownershipOf(msg.sender, _heroToAdd), "addHero::User does not own this hero");
        require(tempBattle.initialTokensStaked != 0 && tempBattle.battleType == _battleType, "addHero::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addHero::User can only add hero to easy, medium, hard or very hard battles");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addHero::Cannot add heroes to battles that have already finished");
        require(addressForHeroBattle[msg.sender][_heroToAdd] == 0, "addHero::This hero is currently in another battle");
        require(tempBattle.hero == 0, "addHero::A hero is already in this battle");


        tempBattle = calculateRewards(tempBattle);
        tempBattle.currentRewardPercentage += assetPercentages[_heroToAdd - 1];
        if (tempBattle.currentRewardPercentage >= tempBattle.currentRewardLimit) {
            tempBattle.currentRewardPercentage = tempBattle.currentRewardLimit;
            tempBattle.dayForLimitReached = tempBattle.battleDaysExpended;
        }
        tempBattle.hero = _heroToAdd;

        // fortunasAssets.safeTransferFromWithoutCheck(msg.sender, address(this), _heroToAdd, 1, "");

        addressForHeroBattle[msg.sender][_heroToAdd] = _battleNumber;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function removeHero(uint8 _heroToRemove, uint8 _battleType, uint256 _battleNumber) public {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(1 <= _heroToRemove && _heroToRemove <= 5, "removeHero::Incorrect hero specified");
        // require(fortunasAssets.ownershipOf(msg.sender, _heroToRemove), "removeHero::User does not own this hero");
        require(tempBattle.initialTokensStaked != 0 && tempBattle.battleType == _battleType, "removeHero::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeHero::User can only remove hero from easy, medium, hard or very hard battles");
        require(addressForHeroBattle[msg.sender][_heroToRemove] == _battleNumber, "removeHero::Incorrect hero or battle number given");


        tempBattle = calculateRewards(tempBattle);
        tempBattle.currentRewardPercentage -= assetPercentages[_heroToRemove - 1];
        if (tempBattle.dayForLimitReached != 0) {
            tempBattle.dayForLimitReached = 0;
        }
        tempBattle.hero = 0;

        // fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, _heroToRemove, 1, "");

        addressForHeroBattle[msg.sender][_heroToRemove] = 0;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function addCavalry(uint8 _cavalryToAdd, uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(6 <= _cavalryToAdd && _cavalryToAdd <= 10, "addCavalry::Incorrect cavalry specified");
        // require(fortunasAssets.ownershipOf(msg.sender, _cavalryToAdd), "addCavalry::User does not own this cavalry");
        require(tempBattle.initialTokensStaked != 0 && tempBattle.battleType == _battleType, "addCavalry::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addCavalry::User can only add cavalry to easy, medium, hard or very hard battles");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addCavalry::Cannot add cavalries to battles that have already finished");
        require(addressForCavalryBattle[msg.sender][_cavalryToAdd] == 0, "addCavalry::This cavalry unit is currently in another battle");
        require(tempBattle.cavalry == 0, "addCavalry::A cavalry unit is already in this battle");


        tempBattle = calculateRewards(tempBattle);
        tempBattle.currentRewardLimit += assetPercentages[_cavalryToAdd - 1];
        if (tempBattle.dayForLimitReached != 0) {
            if (tempBattle.currentRewardPercentage < tempBattle.currentRewardLimit) {
                tempBattle.dayForLimitReached = 0;
            }
        }
        tempBattle.cavalry = _cavalryToAdd;
        
        // fortunasAssets.safeTransferFromWithoutCheck(msg.sender, address(this), _cavalryToAdd, 1, "");

        addressForCavalryBattle[msg.sender][_cavalryToAdd] = _battleNumber;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function removeCavalry(uint8 _cavalryToRemove, uint8 _battleType, uint256 _battleNumber) public {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(6 <= _cavalryToRemove && _cavalryToRemove <= 10, "removeCavalry::Incorrect cavalry specified");
        // require(fortunasAssets.ownershipOf(msg.sender, _cavalryToRemove), "removeCavalry::User does not own this cavalry");
        require(tempBattle.initialTokensStaked != 0 && tempBattle.battleType == _battleType, "removeCavalry::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeCavalry::User can only remove cavalry from easy, medium, hard or very hard battles");
        require(addressForCavalryBattle[msg.sender][_cavalryToRemove] == _battleNumber, "removeCavalry::Incorrect cavalry unit or battle number given");


        tempBattle = calculateRewards(tempBattle);
        tempBattle.currentRewardLimit -= assetPercentages[_cavalryToRemove - 1];
        if (tempBattle.currentRewardPercentage >= tempBattle.currentRewardLimit) {
            tempBattle.currentRewardPercentage = tempBattle.currentRewardLimit;
            tempBattle.dayForLimitReached = tempBattle.battleDaysExpended;
        }
        tempBattle.cavalry = 0;

        // fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, _cavalryToRemove, 1, "");

        addressForCavalryBattle[msg.sender][_cavalryToRemove] = 0;
        addressForBattle[msg.sender][_battleNumber - 1] = tempBattle;
    }

    function battleEnd(uint8 _battleType, uint256 _battleNumber) external {
        Battle memory tempBattle = addressForBattle[msg.sender][_battleNumber - 1];
        require(2 <= _battleType && _battleType <= 6, "battleEnd::Incorrect battle type");
        require(tempBattle.initialTokensStaked != 0 && tempBattle.battleType == _battleType, "battleEnd::No such battle is currently taking place");


        tempBattle = calculateRewards(tempBattle);
        uint256 tokensToTransfer = tempBattle.initialTokensStaked.add(tempBattle.rewards);

        if (_battleType == 2) {
            require(LPToken.balanceOf(address(this)) >= tokensToTransfer, "battleEnd::Contract has insufficient LP Tokens");
            LPToken.transfer(msg.sender, tokensToTransfer);
        }
        else {
            require(fortunasToken.balanceOf(address(this)) >= tokensToTransfer, "battleEnd::Contract has insufficient Fortunas Tokens");
            fortunasToken.transfer(msg.sender, tokensToTransfer);

            calculateLosses(tempBattle, tempBattle.losses, _battleNumber);
        }

        addressForHeroBattle[msg.sender][tempBattle.hero] = 0;
        addressForCavalryBattle[msg.sender][tempBattle.cavalry] = 0;
        Battle memory emptyBattle;
        addressForBattle[msg.sender][_battleNumber - 1] = emptyBattle;
    }

    function calculateRewards(Battle memory _tempBattle) internal view returns (Battle memory) {
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.additionalTokens).add(_tempBattle.rewards);

        uint256 daysWagingBattle = block.timestamp.sub(_tempBattle.battleStartTime).div(oneDayTime);
        uint256 daysForReward;

        uint256 ratio = rewardBase[_tempBattle.battleType - 1].mul(10 ** 18).div(multiplierForReward);
        uint256 accruedInterest;
        if (daysWagingBattle.sub(_tempBattle.battleDaysExpended) != 0) {
            if (daysWagingBattle < 3) {
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                accruedInterest = compoundReward(
                    tempTotalTokens,
                    ratio,
                    daysForReward);
                _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
            }
            else if (daysWagingBattle >= 3
            && daysWagingBattle < _tempBattle.rationsDaysTotal.add(3)
            && _tempBattle.rationsDaysTotal > 0) {
                if (_tempBattle.battleDaysExpended < 3) {
                    daysForReward = uint256(3).sub(_tempBattle.battleDaysExpended);

                    accruedInterest = compoundReward(
                        tempTotalTokens,
                        ratio,
                        daysForReward);
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                    tempTotalTokens += accruedInterest.sub(tempTotalTokens);

                    _tempBattle.battleDaysExpended = 3;
                }
                daysForReward = daysWagingBattle.sub(_tempBattle.battleDaysExpended);

                uint256 exponent = 0;
                uint256 singleReward;
                for (uint256 i = 0 ; i < daysForReward ; i++) {
                    if (_tempBattle.currentRewardPercentage == _tempBattle.currentRewardLimit) {
                        exponent++;
                    }

                    if (_tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit) {
                        _tempBattle.currentRewardPercentage += rewardIncreasePerDay;

                        singleReward = tempTotalTokens.mul(_tempBattle.currentRewardPercentage).div(multiplierForReward);
                        _tempBattle.rewards += singleReward;
                        tempTotalTokens += singleReward;
                    }
                    else if (_tempBattle.dayForLimitReached == 0) {
                        _tempBattle.dayForLimitReached = _tempBattle.battleDaysExpended.add(i + 1);
                        _tempBattle.currentRewardPercentage = _tempBattle.currentRewardLimit;
                    }
                }

                if (exponent > 0) {
                    ratio = _tempBattle.currentRewardLimit;
                    compoundReward(
                        tempTotalTokens,
                        ratio,
                        exponent);
                    _tempBattle.rewards += accruedInterest.sub(tempTotalTokens);
                    tempTotalTokens += accruedInterest.sub(tempTotalTokens);
                }
            }
            _tempBattle.battleDaysExpended = daysWagingBattle;
        }

        return _tempBattle;
    }

    function calculateRewardsForBattleEnd(Battle memory _tempBattle) internal view returns (Battle memory) {
        uint256 startTimeForReward;
        uint256 numberOfRewardCycles;
        uint256 increaseBy;
        uint256 tempTotalTokens = _tempBattle.initialTokensStaked.add(_tempBattle.rewards);
        uint256 extraRewards;
        // TODO
        bool _isLosable = true;
        bool _isExtra = true;

        if (_tempBattle.battleType == 2) {
            require(block.timestamp >= _tempBattle.battleStartTime + baseBattleTime, "calculateRewards::Training of troops lasts a fixed 3 days");
            // startTimeForReward = _tempBattle.battleStartTime.div(rewardTime).mul(rewardTime);
            // numberOfRewardCycles = _tempBattle.battleStartTime.add(baseBattleTime).sub(startTimeForReward).div(rewardTime);

            // for (uint256 i = 0 ; i < numberOfRewardCycles ; i++) {
            //     _tempBattle.rewards += tempTotalTokens.mul(rewardBase[_tempBattle.battleType - 1]).div(multiplierForReward);
            //     tempTotalTokens += _tempBattle.rewards;
            // }
            increaseBy = rewardBase[_tempBattle.battleType - 1].mul(3);
            _tempBattle.rewards += tempTotalTokens.mul(increaseBy).div(multiplierForReward);
        }
        else {
            uint256 daysInBattle = block.timestamp.sub(_tempBattle.battleStartTime).div(oneDayTime);
            if (
            daysInBattle < 3) {
                increaseBy = rewardBase[_tempBattle.battleType - 1].mul(daysInBattle);
                _tempBattle.rewards += tempTotalTokens.mul(increaseBy).div(multiplierForReward);

                uint256 lastDayCycles = block.timestamp.sub(_tempBattle.battleStartTime.add(daysInBattle.mul(oneDayTime))).div(rewardTime);
                uint256 percentageRewardPerCycle = rewardBase[_tempBattle.battleType - 1].mul(10000).div(48);
                increaseBy = lastDayCycles.mul(percentageRewardPerCycle);

                _tempBattle.rewards += tempTotalTokens.mul(increaseBy).div(1000000000);
            }
            else if (
            daysInBattle >= 3
            && _tempBattle.rationsDaysTotal == 0) {
                increaseBy = rewardBase[_tempBattle.battleType - 1].mul(3);
                _tempBattle.rewards += tempTotalTokens.mul(increaseBy).div(multiplierForReward);
            }
            else if (
            daysInBattle >= 3
            && daysInBattle < _tempBattle.rationsDaysTotal.add(3)
            && _tempBattle.rationsDaysTotal > 0) {
                increaseBy = rewardBase[_tempBattle.battleType - 1].mul(daysInBattle);
                _tempBattle.rewards += tempTotalTokens.mul(increaseBy).div(multiplierForReward);

                uint256 lastDayCycles = block.timestamp.sub(_tempBattle.battleStartTime.add(daysInBattle.mul(oneDayTime))).div(rewardTime);
                uint256 percentageRewardPerCycle = rewardBase[_tempBattle.battleType - 1].mul(10000).div(48);
                increaseBy = lastDayCycles.mul(percentageRewardPerCycle);

                _tempBattle.rewards += tempTotalTokens.mul(increaseBy).div(1000000000);
            }
            else if (
            daysInBattle >= _tempBattle.rationsDaysTotal.add(3)
            && _tempBattle.rationsDaysTotal > 0) {
            }

            startTimeForReward = _tempBattle.battleStartTime.div(rewardTime).mul(rewardTime);
            uint256 rationsEndTime = _tempBattle.battleStartTime.add(baseBattleTime).add(_tempBattle.rationsDaysTotal.mul(oneDayTime));
            _tempBattle.battleStartTime = block.timestamp;
            if (block.timestamp >= rationsEndTime &&
                _tempBattle.rationsDaysTotal > 0) {
                numberOfRewardCycles = rationsEndTime.sub(startTimeForReward).div(rewardTime);
                if (_isLosable) {
                    if (_tempBattle.hero != 0) {
                        _tempBattle.losses += 200;
                    }
                    if (_tempBattle.cavalry != 0) {
                        _tempBattle.losses += 20;
                    }
                    _tempBattle.losses += 2;
                }
            }
            else if (block.timestamp >= _tempBattle.battleStartTime.add(baseBattleTime) &&
                block.timestamp < rationsEndTime &&
                _tempBattle.rationsDaysTotal > 0) {
                numberOfRewardCycles = block.timestamp.sub(startTimeForReward).div(rewardTime);
                if (_isLosable) {
                    if (_tempBattle.hero != 0) {
                        _tempBattle.losses += 200;
                    }
                    if (_tempBattle.cavalry != 0) {
                        _tempBattle.losses += 20;
                    }
                    _tempBattle.losses += 2;
                }
            }
            else if (block.timestamp >= _tempBattle.battleStartTime.add(baseBattleTime) &&
                _tempBattle.rationsDaysTotal == 0) {
                numberOfRewardCycles = _tempBattle.battleStartTime.add(baseBattleTime).sub(startTimeForReward).div(rewardTime);
                if (_isLosable) {
                    if (_tempBattle.hero != 0) {
                        _tempBattle.losses += 200;
                    }
                    if (_tempBattle.cavalry != 0) {
                        _tempBattle.losses += 20;
                    }
                    _tempBattle.losses += 0;
                }
            }
            else if (block.timestamp < _tempBattle.battleStartTime.add(baseBattleTime)) {
                numberOfRewardCycles = block.timestamp.sub(startTimeForReward).div(rewardTime);
                if (_isLosable) {
                    if (_tempBattle.hero != 0) {
                        _tempBattle.losses += 200;
                    }
                    if (_tempBattle.cavalry != 0) {
                        _tempBattle.losses += 20;
                    }
                    _tempBattle.losses += 0;
                }
            }

            for ( ; _tempBattle.battleDaysExpended < numberOfRewardCycles ; _tempBattle.battleDaysExpended++) {
                // isRewardReset
                // if (_tempBattle.battleDaysExpended == _tempBattle.dayForRewardReset.mul(48) && _tempBattle.dayForRewardReset != 0) {
                //     _tempBattle.currentRewardPercentage = rewardBase[_tempBattle.battleType - 1];
                // }

                // isLimitReached
                if (_tempBattle.currentRewardPercentage >= _tempBattle.currentRewardLimit && _tempBattle.dayForLimitReached != 0) {
                    _tempBattle.currentRewardPercentage = _tempBattle.currentRewardLimit;
                    _tempBattle.dayForLimitReached = _tempBattle.battleDaysExpended.div(48);

                }
                else if (_tempBattle.battleDaysExpended >= uint256(48).mul(3) && _tempBattle.battleDaysExpended.mod(48) == 0 && _tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit) {
                    // _tempBattle.currentRewardPercentage += rewardIncreasePerDay[_tempBattle.battleType -1];
                }

                _tempBattle.rewards += tempTotalTokens.mul(_tempBattle.currentRewardPercentage).div(multiplierForReward);
                tempTotalTokens += _tempBattle.rewards;
            }

            if (_isExtra) {
                uint256 extraStartTimeForReward = _tempBattle.battleStartTime;
                uint256 extraNumberOfRewardCycles;
                extraNumberOfRewardCycles = rationsEndTime.sub(extraStartTimeForReward).div(rewardTime);
                uint256 extraBattleDaysExpended = _tempBattle.battleDaysExpended;
                uint256 extraCurrentRewardPercentage = _tempBattle.currentRewardPercentage;
                for ( ; extraBattleDaysExpended < extraNumberOfRewardCycles ; extraBattleDaysExpended++) {
                    // if (extraBattleDaysExpended == _tempBattle.dayForRewardReset.mul(48) && _tempBattle.dayForRewardReset != 0) {
                    //     extraCurrentRewardPercentage = rewardBase[_tempBattle.battleType - 1];
                    // }

                    if (extraCurrentRewardPercentage >= _tempBattle.currentRewardLimit && _tempBattle.dayForLimitReached != 0) {
                        extraCurrentRewardPercentage = _tempBattle.currentRewardLimit;
                        _tempBattle.dayForLimitReached = extraBattleDaysExpended.div(48);
                    }
                    else if (extraBattleDaysExpended >= uint256(48).mul(3) && extraBattleDaysExpended.mod(48) == 0 && _tempBattle.currentRewardPercentage < _tempBattle.currentRewardLimit) {
                        // extraCurrentRewardPercentage += rewardIncreasePerDay[_tempBattle.battleType - 1];
                    }

                    extraRewards += tempTotalTokens.mul(extraCurrentRewardPercentage).div(multiplierForReward);
                    tempTotalTokens += extraRewards;
                }
            }
        }

        return _tempBattle;
    }

    function compoundReward(uint256 _principal, uint256 _ratio, uint256 _exponent) internal pure returns (uint256) {
        return ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
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
        uint256 chanceDecrease = _tempBattle.battleDaysExpended.div(48).mul(10).div(2);
        chanceToLoose = chanceToLoose.safeSub(chanceDecrease);

        if (posLosses[2] == 2) {
            if (0 < randHero && randHero <= chanceToLoose) {
                removeHero(_tempBattle.hero, _tempBattle.battleType, _battleNumber);
                // fortunasAssets.burn(msg.sender, _tempBattle.hero, 1);
            }
        }

        if (posLosses[1] == 2) {
            if (0 < randCavalry && randCavalry <= chanceToLoose) {
                removeCavalry(_tempBattle.hero, _tempBattle.battleType, _battleNumber);
                // fortunasAssets.burn(msg.sender, _tempBattle.cavalry, 1);
            }
        }

        if (posLosses[0] == 2) {
            if (0 < randRations && randRations <= chanceToLoose) {
                fortunasToken.burn(address(this), _tempBattle.rations);
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
            if (tempBattle.initialTokensStaked != 0) {
                tempBattle = calculateRewards(tempBattle);
                tempRewards[counter] = tempBattle.rewards;
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
// TODO/Done divide normal reward function into 2 (normal + extra)
// TODO/Done islimitreached and reconfigure reward reset for additional troops not rations
// TODO/Done nft transfer and mapping in assets for ownership
// TODO/Done adjust calculation for price of heroes/cavalry
// TODO Reward -> Compound interest
// TODO calculateRewardsForBattleEnd...
// TODO set all unset values for testing and mainnet in Battling, FortunasToken, FortunasAssets and FortunasLottery
// TODO Chainlink randomizer or api/oracle randomizer
// TODO FortunasToken -> clean unnecassery code from FortunasToken
// TODO modifiers
// TODO code optimization and code cleaning

/*
Buying Taxes (10%)
2.5% Liquidity Pool
7.5% Treasury
Selling Taxes (10%)
7.5% Liquidity Pool
2.5% Treasury
*/