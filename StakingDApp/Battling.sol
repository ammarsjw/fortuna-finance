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
import "./BattlingHelper.sol";
import "./BattleStruct.sol";

contract Battling is Ownable, BattleStruct {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    uint256 bribeToEmeperor;

    IPancakeRouter02 public pancakeRouter;
    IPancakePair public pancakePair;

    // LP Token for FRTNA-BUSD pair
    IERC20 public LPToken;

    // Fortunas Multi Token for heroes and cavalry
    FortunasAssets public fortunasAssets;
    
    // FRTNA
    FortunasToken public fortunasToken;
    address public treasuryWallet;

    // BUSD mainnet
    // address public immutable BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    // BUSD testnet (TestnetERC20Token)
    address public BUSD = address(0x7D9385C733a967793EE14D933212ee44025f1B9d);

    uint256 public rewardTime;                              // 30 minutes in seconds
    uint256 public oneDayTime;                              // 1 day in seconds
    uint256 public baseBattleTime;                          // 3 days in seconds

    uint256 multiplier;
    uint256 multiplierForReward;

    uint256 rationsIncreasePercentage;

    uint256[5] rationsBase;                                 // rations %
    uint256[5] rationsIncrease;                             // percentage increase in rations percentages when reward limit is reached
    
    uint256[6] rewardBasePercentages;
    uint256 rewardIncreasePerDay;

    uint256[6] rewardLimit;                                 // rewardBase cannot exceed these amounts
    uint256[6] rewardBase;                                  // reward % per day

    uint256[10] assetPercentages;
    uint256[10] assetPrices;

    uint256 randomAssetPrice;

    BattlingHelper battlingHelper;

    // mappings

    mapping(address => mapping(uint256 => Battle)) private battleForAddress;
    mapping(address => mapping(uint256 => uint256)) private heroBattleForAddress;
    mapping(address => mapping(uint256 => uint256)) private cavalryBattleForAddress;

    // events

    event BattleStarted (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 tokensStaked,
        uint256 battleStartTime,
        uint256 battleDurationInDays,
        uint256 rewards,
        uint256 rations
    );

    event BattleUpdated (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 tokensStaked,
        uint256 battleStartTime,
        uint256 battleDurationInDays,
        uint256 rewards,
        uint256 rations
    );

    event BattleEnded (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 tokensStaked,
        uint256 battleStartTime,
        uint256 battleDurationInDays,
        uint256 rewards,
        uint256 rations
    );

    event HeroPurchased (
        address indexed user,
        uint256 battleType,
        bool heroStatus,
        uint256 hero
    );

    event HeroDeployed (
        address indexed user,
        uint256 battleType,
        bool heroStatus,
        uint256 hero
    );

    event HeroReturned (
        address indexed user,
        uint256 battleType,
        bool heroStatus,
        uint256 hero
    );

    event HeroLost (
        address indexed user,
        uint256 battleType,
        bool heroStatus,
        uint256 hero
    );

    event CavalryPurchased (
        address indexed user,
        uint256 battleType,
        bool cavalryStatus,
        uint256 cavalry
    );

    event CavalryDeployed (
        address indexed user,
        uint256 battleType,
        bool cavalryStatus,
        uint256 cavalry
    );

    event CavalryReturned (
        address indexed user,
        uint256 battleType,
        bool cavalryStatus,
        uint256 cavalry
    );

    event CavalryLost (
        address indexed user,
        uint256 battleType,
        bool cavalryStatus,
        uint256 cavalry
    );

    // constructor

    constructor(address _fortunasToken) {
        bribeToEmeperor = 5000;

        // TODO (for mainnet) rather than using the constructor, use the setter function to initialize some of the below variables to hide sensitive information
        // PancakeRouter02 mainnet
        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(address(0));
        // PancakeRouter02 testnet
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
        address _addressForPancakePair = IPancakeFactory(_pancakeRouter.factory()).getPair(_fortunasToken, BUSD);

        pancakeRouter = _pancakeRouter;
        pancakePair = IPancakePair(_addressForPancakePair);

        LPToken = IERC20(_addressForPancakePair);

        fortunasAssets = new FortunasAssets("", address(this));

        fortunasToken = FortunasToken(payable(_fortunasToken));
        treasuryWallet = address(fortunasToken);

        // rewardTime = 1800;
        // oneDayTime = 86400;
        // baseBattleTime = 259200;
        rewardTime = 1;                                     // only for testing
        oneDayTime = 48;                                    // only for testing
        baseBattleTime = 144;                               // only for testing

        multiplier = 1000000;
        multiplierForReward = 10000000;

        rationsIncreasePercentage = 125000;

        rationsBase = [2500, 5000, 7500, 10000, 12500];
        setRations();

        assetPercentages = [20, 40, 60, 80, 100,            // each hero's effect on current APY
                            10, 20, 30, 40, 50];            // each cavalry's effect on total APY
        assetPrices = [2500, 5000, 7500, 10000, 12500,      // percentage cost of LP for purchasing each hero
                        2500, 5000, 7500, 10000, 12500];    // percentage cost of LP for purchasing each cavalry

        randomAssetPrice = 5000;

        battlingHelper = new BattlingHelper();

        // setting all rewards for both battling and battlingHelper outside of constructor
    }

    // getters

    function getBattleForAddress(address _walletAddress, uint _battleType) external view returns (Battle memory) {
        return battleForAddress[_walletAddress][_battleType];
    }

    // setters

    function setFortunasToken(address _fortunasToken) external onlyOwner {
        fortunasToken = FortunasToken(payable(_fortunasToken));
        treasuryWallet = address(fortunasToken);
    }

    function setFortunasAssets(address _fortunasAssets) external onlyOwner {
        fortunasAssets = FortunasAssets(_fortunasAssets);
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

    function setRewardBasePercentages(uint256[6] memory _rewardBasePercentages) external onlyOwner {
        rewardBasePercentages = _rewardBasePercentages;

        setRewards();
    }

    function setrewardIncreasePerDay(uint256 _rewardIncreasePerDay) external onlyOwner {
        rewardIncreasePerDay = _rewardIncreasePerDay;
    }

    function setRewardLimit(uint256[6] memory _rewardLimit) external onlyOwner {
        rewardLimit = _rewardLimit;

        setRewards();
    }

    function setRewards() internal {
        for (uint256 i = 0 ; i < 6 ; i++) {
            rewardBase[i] = rewardLimit[i].mul(rewardBasePercentages[i]).roundDiv(100);
        }
    }

    function setAllRewards(uint256[6] memory _basePercentages, uint256 _increasePerDay, uint256[6] memory _limit) external onlyOwner {
        rewardBasePercentages = _basePercentages;
        rewardIncreasePerDay = _increasePerDay;

        rewardLimit = _limit;
        setRewards();
        battlingHelper.setAllRewards(_basePercentages, _increasePerDay, _limit);
    }

    // functions

    function battleStart(uint256 _tokens, uint8 _battleType) external {
        require(_tokens >= 13334, "battleStart::Minimum amount of tokens for battle is 0.000000000000013334 FRTNA");
        require(2 <= _battleType && _battleType <= 6, "battleStart::No such battle type exists");
        require(fortunasToken.balanceOf(msg.sender) >= _tokens, "battleStart::Insufficient funds");


        uint256 bribe = _tokens.mul(bribeToEmeperor).div(multiplier);
        _tokens -= bribe;

        if (_battleType == 2) {
            LPToken.transferFrom(msg.sender, treasuryWallet, bribe);

            LPToken.transferFrom(msg.sender, address(this), _tokens);
        }
        else {
            fortunasToken.transferFrom(msg.sender, treasuryWallet, bribe);

            fortunasToken.transferFrom(msg.sender, address(this), _tokens);
        }

        battleForAddress[msg.sender][_battleType] = Battle(_battleType, _tokens, 0, 0, 0, rewardLimit[_battleType - 1], rewardBase[_battleType - 1], block.timestamp, 0, 0, 0, 0, 0);

        emit BattleStarted (
            msg.sender,
            _battleType,
            true,
            _tokens,
            battleForAddress[msg.sender][_battleType].battleStartTime,
            3,
            0,
            0
        );
    }

    function sendRations(uint8 _battleType, uint256 _rationDays) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(tempBattle.initialTokensStaked != 0, "sendRations::No such battle is currently taking place");
        if (block.timestamp >= tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
            require(false, "sendRations::Cannot send rations to battles that have already finished");
        }
        else if (tempBattle.battleDaysExpended >= 3) {
            uint256 rationsExpended = block.timestamp.sub(tempBattle.battleStartTime.add(baseBattleTime)).ceilDiv(oneDayTime);
            uint256 currentRationsDays = tempBattle.rationsDaysTotal.sub(rationsExpended).add(_rationDays);
            require(currentRationsDays <= 5, "sendRations::RCE5-2");
        }
        require(3 <= _battleType && _battleType <= 6, "sendRations::User can only add rations to easy, medium, hard or very hard battles");
        require(1 <= _rationDays && _rationDays <= 5, "sendRations::RCE5-1");


        tempBattle = battlingHelper.calculateRewards(tempBattle);

        uint256 tempTotalTokens = tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards);
        uint256 tempRations;
        uint256 totalPercentage;
        if (tempBattle.rationsDaysTotal + _rationDays >= tempBattle.dayForLimitReached
        && tempBattle.dayForLimitReached != 0) {
            if (tempBattle.rationsDaysTotal < tempBattle.dayForLimitReached) {
                uint256 daysPreIncrease = tempBattle.dayForLimitReached - tempBattle.rationsDaysTotal;
                tempRations = tempTotalTokens.mul(rationsBase[daysPreIncrease - 1]).div(multiplier);

                uint256 daysPostIncrease = (tempBattle.rationsDaysTotal.add(_rationDays)) - tempBattle.dayForLimitReached;
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

        fortunasToken.transferFrom(msg.sender, address(this), tempRations);

        tempBattle.rations += tempRations;
        tempBattle.rationsDaysTotal += _rationDays;
        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked.add(tempBattle.additionalTokens),
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.rewards,
            tempBattle.rations
        );
    }

    function addTroops(uint256 _tokensToAdd, uint8 _battleType) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(tempBattle.initialTokensStaked != 0, "addTroops::No such battle is currently taking place");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addTroops::Cannot add tokens to battles that have already finished");
        require(fortunasToken.balanceOf(msg.sender) >= _tokensToAdd, "addTroops::Insufficient funds");


        tempBattle = battlingHelper.calculateRewards(tempBattle);
        tempBattle.additionalTokens += _tokensToAdd;
        if (tempBattle.additionalTokens + _tokensToAdd > tempBattle.initialTokensStaked) {
            tempBattle.currentRewardPercentage = rewardBase[tempBattle.battleType - 1];
            if (tempBattle.hero > 0) {
                tempBattle.currentRewardPercentage += assetPercentages[tempBattle.hero - 1];
            }
        }

        fortunasToken.transferFrom(msg.sender, address(this), _tokensToAdd);

        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked.add(tempBattle.additionalTokens),
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.rewards,
            tempBattle.rations
        );
    }

    function removeTroops(uint256 _tokensToRemove, uint8 _battleType) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(tempBattle.initialTokensStaked != 0, "removeTroops::No such battle is currently taking place");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeTroops::Cannot remove tokens from battles that have already finished");
        require(fortunasToken.balanceOf(address(this)) >= _tokensToRemove, "removeTroops::Contract has insufficient balance. Please try again later");


        tempBattle = battlingHelper.calculateRewards(tempBattle);
        require(_tokensToRemove < tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards), "removeTroops::Not enough tokens in this battle");
        require(tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards).sub(_tokensToRemove) >= 13334, "removeTroops::Total staked amount cannot be lower than 0.000000000000013334 FRTNA");

        if (_tokensToRemove > tempBattle.rewards) {
            _tokensToRemove -= tempBattle.rewards;
            tempBattle.rewards = 0;
            if (_tokensToRemove > tempBattle.additionalTokens) {
                _tokensToRemove -= tempBattle.additionalTokens;
                tempBattle.additionalTokens = 0;
                tempBattle.initialTokensStaked -= _tokensToRemove;
            }
            else {
                tempBattle.additionalTokens -= _tokensToRemove;
            }
        }
        else {
            tempBattle.rewards -= _tokensToRemove;
        }

        calculateLosses(tempBattle);

        fortunasToken.transfer(msg.sender, _tokensToRemove);

        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked.add(tempBattle.additionalTokens),
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.rewards,
            tempBattle.rations
        );
    }

    function purchaseHero(uint256 _heroToPurchase) external {
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
        require(fortunasAssets.ownershipOf(msg.sender, _heroToPurchase) == false, "purchaseHero::You already own this hero");


        (uint256 reserves, , ) = pancakePair.getReserves();

        uint256 price = reserves.mul(cost).roundDiv(multiplier);
        fortunasToken.transferFrom(msg.sender, address(this), price);

        fortunasAssets.mint(msg.sender, _heroToPurchase, 1, "");

        emit HeroPurchased (
            msg.sender,
            0,
            true,
            _heroToPurchase
        );
    }

    function purchaseCavalry(uint256 _cavalryToPurchase) external {
        require(6 <= _cavalryToPurchase && _cavalryToPurchase <= 10, "purchaseCavalry::Incorrect cavalry specified");
        require(fortunasAssets.ownershipOf(msg.sender, _cavalryToPurchase) == false, "purchaseCavalry::You already own this cavalry");


        (uint256 reserves, , ) = pancakePair.getReserves();

        uint256 price = reserves.mul(assetPrices[_cavalryToPurchase - 1]).roundDiv(multiplier);
        fortunasToken.transferFrom(msg.sender, address(this), price);

        fortunasAssets.mint(msg.sender, _cavalryToPurchase, 1, "");

        emit CavalryPurchased (
            msg.sender,
            0,
            true,
            _cavalryToPurchase
        );
    }

    function addHero(uint256 _heroToAdd, uint8 _battleType) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(1 <= _heroToAdd && _heroToAdd <= 5, "addHero::Incorrect hero specified");
        require(fortunasAssets.ownershipOf(msg.sender, _heroToAdd), "addHero::User does not own this hero");
        require(tempBattle.initialTokensStaked != 0, "addHero::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addHero::User can only add hero to easy, medium, hard or very hard battles");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addHero::Cannot add heroes to battles that have already finished");
        require(heroBattleForAddress[msg.sender][_heroToAdd] == 0, "addHero::This hero is currently in another battle");
        require(tempBattle.hero == 0, "addHero::A hero is already in this battle");


        tempBattle = battlingHelper.calculateRewards(tempBattle);
        tempBattle.currentRewardPercentage += assetPercentages[_heroToAdd - 1];
        if (tempBattle.currentRewardPercentage >= tempBattle.currentRewardLimit) {
            tempBattle.currentRewardPercentage = tempBattle.currentRewardLimit;
            tempBattle.dayForLimitReached = tempBattle.battleDaysExpended;
        }
        tempBattle.hero = _heroToAdd;

        fortunasAssets.safeTransferFromWithoutCheck(msg.sender, address(this), _heroToAdd, 1, "");

        heroBattleForAddress[msg.sender][_heroToAdd] = _battleType;
        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit HeroDeployed (
            msg.sender,
            _battleType,
            true,
            _heroToAdd
        );

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked.add(tempBattle.additionalTokens),
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.rewards,
            tempBattle.rations
        );
    }

    function removeHero(uint256 _heroToRemove, uint8 _battleType) public {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(1 <= _heroToRemove && _heroToRemove <= 5, "removeHero::Incorrect hero specified");
        require(fortunasAssets.ownershipOf(msg.sender, _heroToRemove), "removeHero::User does not own this hero");
        require(tempBattle.initialTokensStaked != 0, "removeHero::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeHero::User can only remove hero from easy, medium, hard or very hard battles");
        require(heroBattleForAddress[msg.sender][_heroToRemove] == _battleType, "removeHero::Incorrect hero or battle number given");


        tempBattle = battlingHelper.calculateRewards(tempBattle);
        tempBattle.currentRewardPercentage -= assetPercentages[_heroToRemove - 1];
        if (tempBattle.dayForLimitReached != 0) {
            tempBattle.dayForLimitReached = 0;
        }
        tempBattle.hero = 0;

        fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, _heroToRemove, 1, "");

        heroBattleForAddress[msg.sender][_heroToRemove] = 0;
        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit HeroReturned (
            msg.sender,
            0,
            true,
            _heroToRemove
        );

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked.add(tempBattle.additionalTokens),
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.rewards,
            tempBattle.rations
        );
    }

    function addCavalry(uint256 _cavalryToAdd, uint8 _battleType) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(6 <= _cavalryToAdd && _cavalryToAdd <= 10, "addCavalry::Incorrect cavalry specified");
        require(fortunasAssets.ownershipOf(msg.sender, _cavalryToAdd), "addCavalry::User does not own this cavalry");
        require(tempBattle.initialTokensStaked != 0, "addCavalry::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addCavalry::User can only add cavalry to easy, medium, hard or very hard battles");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addCavalry::Cannot add cavalries to battles that have already finished");
        require(cavalryBattleForAddress[msg.sender][_cavalryToAdd] == 0, "addCavalry::This cavalry unit is currently in another battle");
        require(tempBattle.cavalry == 0, "addCavalry::A cavalry unit is already in this battle");


        tempBattle = battlingHelper.calculateRewards(tempBattle);
        tempBattle.currentRewardLimit += assetPercentages[_cavalryToAdd - 1];
        if (tempBattle.dayForLimitReached != 0) {
            if (tempBattle.currentRewardPercentage < tempBattle.currentRewardLimit) {
                tempBattle.dayForLimitReached = 0;
            }
        }
        tempBattle.cavalry = _cavalryToAdd;
        
        fortunasAssets.safeTransferFromWithoutCheck(msg.sender, address(this), _cavalryToAdd, 1, "");

        cavalryBattleForAddress[msg.sender][_cavalryToAdd] = _battleType;
        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit CavalryDeployed (
            msg.sender,
            _battleType,
            true,
            _cavalryToAdd
        );

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked.add(tempBattle.additionalTokens),
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.rewards,
            tempBattle.rations
        );
    }

    function removeCavalry(uint256 _cavalryToRemove, uint8 _battleType) public {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(6 <= _cavalryToRemove && _cavalryToRemove <= 10, "removeCavalry::Incorrect cavalry specified");
        require(fortunasAssets.ownershipOf(msg.sender, _cavalryToRemove), "removeCavalry::User does not own this cavalry");
        require(tempBattle.initialTokensStaked != 0, "removeCavalry::No such battle is currently taking place");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeCavalry::User can only remove cavalry from easy, medium, hard or very hard battles");
        require(cavalryBattleForAddress[msg.sender][_cavalryToRemove] == _battleType, "removeCavalry::Incorrect cavalry unit or battle number given");


        tempBattle = battlingHelper.calculateRewards(tempBattle);
        tempBattle.currentRewardLimit -= assetPercentages[_cavalryToRemove - 1];
        if (tempBattle.currentRewardPercentage >= tempBattle.currentRewardLimit) {
            tempBattle.currentRewardPercentage = tempBattle.currentRewardLimit;
            tempBattle.dayForLimitReached = tempBattle.battleDaysExpended;
        }
        tempBattle.cavalry = 0;

        fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, _cavalryToRemove, 1, "");

        cavalryBattleForAddress[msg.sender][_cavalryToRemove] = 0;
        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit CavalryReturned (
            msg.sender,
            0,
            true,
            _cavalryToRemove
        );

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked.add(tempBattle.additionalTokens),
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.rewards,
            tempBattle.rations
        );
    }

    function battleEnd(uint8 _battleType) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(2 <= _battleType && _battleType <= 6, "battleEnd::Incorrect battle type");
        require(tempBattle.initialTokensStaked != 0, "battleEnd::No such battle is currently taking place");


        tempBattle = battlingHelper.calculateRewardsForBattleEnd(tempBattle);
        uint256 tokensToTransfer = tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards);

        if (_battleType == 2) {
            require(LPToken.balanceOf(address(this)) >= tokensToTransfer, "battleEnd::Contract has insufficient LP Tokens");
            LPToken.transfer(msg.sender, tokensToTransfer);
        }
        else {
            require(fortunasToken.balanceOf(address(this)) >= tokensToTransfer, "battleEnd::Contract has insufficient Fortunas Tokens");
            fortunasToken.transfer(msg.sender, tokensToTransfer);

            calculateLosses(tempBattle);
        }

        heroBattleForAddress[msg.sender][tempBattle.hero] = 0;
        cavalryBattleForAddress[msg.sender][tempBattle.cavalry] = 0;
        Battle memory emptyBattle;
        battleForAddress[msg.sender][_battleType] = emptyBattle;

        emit BattleEnded (
            msg.sender,
            _battleType,
            false,
            0,
            0,
            0,
            0,
            0
        );
    }

    function calculateLosses(Battle memory _tempBattle) internal {
        // TODO
        uint256 randHero = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        uint256 randCavalry = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        uint256 randRations = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));

        randHero = randHero.mod(1000);
        randCavalry = randCavalry.mod(1000);
        randRations = randRations.mod(1000);

        uint256 chanceToLoose = 500;
        uint256 chanceDecrease = _tempBattle.battleDaysExpended.div(48).mul(10).div(2);
        chanceToLoose = chanceToLoose.safeSub(chanceDecrease);

        if (_tempBattle.hero != 0) {
            if (0 < randHero && randHero <= chanceToLoose) {
                emit HeroLost (
                    msg.sender,
                    0,
                    false,
                    _tempBattle.hero
                );

                removeHero(_tempBattle.hero, _tempBattle.battleType);
                fortunasAssets.burn(address(this), _tempBattle.hero, 1);
            }
        }

        if (_tempBattle.cavalry != 0) {
            if (0 < randCavalry && randCavalry <= chanceToLoose) {
                emit CavalryLost (
                    msg.sender,
                    0,
                    false,
                    _tempBattle.cavalry
                );

                removeCavalry(_tempBattle.hero, _tempBattle.battleType);
                fortunasAssets.burn(address(this), _tempBattle.cavalry, 1);
            }
        }

        if (_tempBattle.rations > 0) {
            if (0 < randRations && randRations <= chanceToLoose) {
                fortunasToken.burn(address(this), _tempBattle.rations);
                battleForAddress[msg.sender][_tempBattle.battleType].rations = 0;
            }
        }
    }

    /**
     * @dev Should be called if updated battle data needed
     * @dev Ideally to be called only if an update on current reward amount is needed
     * @dev Function "battleEnd" should be called if unstaking
     */
    function viewRewards(address _user) external view returns (uint256[] memory) {
        uint256[] memory tempRewards = new uint256[](5);
        Battle memory tempBattle;
        for (uint256 i = 0 ; i < 5 ; i++) {
            tempBattle = battleForAddress[_user][i + 2];
            if (tempBattle.initialTokensStaked != 0) {
                if (block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
                    tempBattle = battlingHelper.calculateRewards(tempBattle);
                }
                else {
                    tempBattle = battlingHelper.calculateRewardsForBattleEnd(tempBattle);
                }
            }
            tempRewards[i] = tempBattle.rewards;
        }

        return tempRewards;
    }
}