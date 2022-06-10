pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./BattlingBase.sol";
import "./BattlingExtension.sol";
import "./IFortunasToken.sol";
import "./FortunasAssets.sol";
import "./ERC1155Holder.sol";
import "./IPancakePair.sol";
import "./IPancakeRouter02.sol";
import "./IPancakeFactory.sol";

contract Battling is BattlingBase, ERC1155Holder {
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
    IFortunasToken public fortunasToken;
    
    // Treasury Wallet
    address public treasuryWallet;

    // BUSD mainnet
    // address public BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    // BUSD testnet (TestnetERC20Token)
    address public BUSD = address(0x7D9385C733a967793EE14D933212ee44025f1B9d);

    uint256[10] assetPercentages;
    uint256[10] assetPrices;

    uint256 randomAssetPrice;

    BattlingExtension public battlingExtension;

    // mappings

    mapping (address => mapping(uint256 => Battle)) private battleForAddress;
    mapping (address => mapping(uint256 => uint8)) private heroBattleForAddress;
    mapping (address => mapping(uint256 => uint8)) private cavalryBattleForAddress;

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

    event HeroPurchased (address indexed user, uint256 battleType, bool heroStatus, uint256 hero);

    event HeroDeployed (address indexed user, uint256 battleType, bool heroStatus, uint256 hero);

    event HeroReturned (address indexed user, uint256 battleType, bool heroStatus, uint256 hero);

    event HeroLost (address indexed user, uint256 battleType, bool heroStatus, uint256 hero);

    event CavalryPurchased (address indexed user, uint256 battleType, bool cavalryStatus, uint256 cavalry);

    event CavalryDeployed (address indexed user, uint256 battleType, bool cavalryStatus, uint256 cavalry);

    event CavalryReturned (address indexed user, uint256 battleType, bool cavalryStatus, uint256 cavalry);

    event CavalryLost (address indexed user, uint256 battleType, bool cavalryStatus, uint256 cavalry);

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

        fortunasToken = IFortunasToken(payable(_fortunasToken));

        // TODO
        treasuryWallet = address(0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80);

        // each hero's/cavalry's effect on current/total battle APY
        assetPercentages = [200000, 400000, 600000, 800000, 1000000,
                            100000, 200000, 300000, 400000, 500000];
        // percentage cost of LP for purchasing each hero/cavalry
        assetPrices = [2500, 5000, 7500, 10000, 12500,
                        2500, 5000, 7500, 10000, 12500];

        randomAssetPrice = 5000;

        battlingExtension = new BattlingExtension();

        // setting all rewards for both battling and battlingExtension outside of constructor
    }

    // getters

    function getBattleForAddress(address _walletAddress, uint _battleType) external view returns (Battle memory) {
        return battleForAddress[_walletAddress][_battleType];
    }

    // setters

    function setFortunasToken(address _fortunasToken) external onlyOwner {
        fortunasToken = IFortunasToken(payable(_fortunasToken));
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        treasuryWallet = _treasuryWallet;
    }

    function setAllRewards(uint256[6] memory _basePercentages, uint256 _increasePerDay, uint256[6] memory _limit) external onlyOwner {
        _setAllRewards(_basePercentages, _increasePerDay, _limit);
    }

    // functions

    function battleStart(uint256 _amount, uint8 _battleType) external {
        require(_amount >= minRewardAmount[_battleType - 1], "battleStart::MIN");
        require(2 <= _battleType && _battleType <= 6, "battleStart::WBT1");
        require(battleForAddress[msg.sender][_battleType].initialTokensStaked == 0, "battleStart::BAS");


        uint256 bribe = _amount.mul(bribeToEmeperor).div(multiplier);
        _amount -= bribe;

        if (_battleType == 2) {
            LPToken.transferFrom(msg.sender, treasuryWallet, bribe);

            LPToken.transferFrom(msg.sender, address(this), _amount);
        }
        else {
            fortunasToken.transferFrom(msg.sender, treasuryWallet, bribe);

            fortunasToken.transferFrom(msg.sender, address(this), _amount);
        }

        battleForAddress[msg.sender][_battleType] = Battle(_battleType, _amount, 0, 0, 0, rewardLimit[_battleType - 1], rewardBase[_battleType - 1], block.timestamp, 0, 0, 0, 0, 0);

        emit BattleStarted (
            msg.sender,
            _battleType,
            true,
            _amount,
            battleForAddress[msg.sender][_battleType].battleStartTime,
            3,
            0,
            0
        );
    }

    function sendRations(uint8 _battleType, uint256 _rationDays) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(tempBattle.initialTokensStaked != 0, "sendRations::WB");
        if (block.timestamp >= tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
            require(false, "sendRations::BE");
        }
        else if (tempBattle.battleDaysExpended >= 3) {
            uint256 rationsExpended = block.timestamp.sub(tempBattle.battleStartTime.add(baseBattleTime)).ceilDiv(oneDayTime);
            uint256 currentRationsDays = tempBattle.rationsDaysTotal.sub(rationsExpended).add(_rationDays);
            require(currentRationsDays <= 5, "sendRations::WR2");
        }
        require(3 <= _battleType && _battleType <= 6, "sendRations::WB2");
        require(1 <= _rationDays && _rationDays <= 5, "sendRations::WR1");


        tempBattle = battlingExtension.calculateRewards(tempBattle);

        (uint256 extraRewards, ) = battlingExtension.calculateExtraRewards(tempBattle);

        uint256 tempRations;
        (tempBattle, tempRations) = battlingExtension.calculateRations(tempBattle, extraRewards, _rationDays);

        fortunasToken.burn(msg.sender, tempRations);

        battleForAddress[msg.sender][_battleType].rations += tempRations;
        battleForAddress[msg.sender][_battleType].rationsDaysTotal += _rationDays;
        battleForAddress[msg.sender][_battleType].dayForLimitReached = tempBattle.dayForLimitReached;

        tempBattle = battleForAddress[msg.sender][_battleType];

        // tempBattle.rations += tempRations;
        // tempBattle.rationsDaysTotal += _rationDays;
        // battleForAddress[msg.sender][_battleType] = tempBattle;

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

    function addTroops(uint256 _amountToAdd, uint8 _battleType) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(tempBattle.initialTokensStaked != 0, "addTroops::WB");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addTroops::BE");


        tempBattle = battlingExtension.calculateRewards(tempBattle);
        tempBattle.additionalTokens += _amountToAdd;
        if (tempBattle.additionalTokens + _amountToAdd > tempBattle.initialTokensStaked) {
            tempBattle.currentRewardPercentage = rewardBase[tempBattle.battleType - 1];
            if (tempBattle.hero > 0) {
                tempBattle.currentRewardPercentage += assetPercentages[tempBattle.hero - 1];
            }
        }

        fortunasToken.transferFrom(msg.sender, address(this), _amountToAdd);

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

    function removeTroops(uint256 _amountToRemove, uint8 _battleType) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(tempBattle.initialTokensStaked != 0, "removeTroops::WB");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "removeTroops::BE");


        tempBattle = battlingExtension.calculateRewards(tempBattle);
        require(_amountToRemove < tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards), "removeTroops::WT");
        require(tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards).sub(_amountToRemove) >= minRewardAmount[_battleType - 1], "removeTroops::MIN");

        if (_amountToRemove > tempBattle.rewards) {
            _amountToRemove -= tempBattle.rewards;
            tempBattle.rewards = 0;
            if (_amountToRemove > tempBattle.additionalTokens) {
                _amountToRemove -= tempBattle.additionalTokens;
                tempBattle.additionalTokens = 0;
                tempBattle.initialTokensStaked -= _amountToRemove;
            }
            else {
                tempBattle.additionalTokens -= _amountToRemove;
            }
        }
        else {
            tempBattle.rewards -= _amountToRemove;
        }

        tempBattle = _calculateLosses(tempBattle);

        uint256 totalContractBalance = fortunasToken.balanceOf(address(this));
        if (_amountToRemove > totalContractBalance) {
            uint256 toMint = _amountToRemove.sub(totalContractBalance);
            fortunasToken.mint(address(this), toMint);
        }
        fortunasToken.transfer(msg.sender, _amountToRemove);

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
        require(1 <= _heroToPurchase && _heroToPurchase <= 6, "purchaseHero::WH");

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
        require(_heroToPurchase != 6, "purchaseHero::RNG");
        require(fortunasAssets.ownershipOf(msg.sender, _heroToPurchase) == false, "purchaseHero::HAO");


        uint256 reserves;
        if (pancakePair.token0() == address(fortunasToken)) {
            (reserves, , ) = pancakePair.getReserves();
        }
        else {
            (, reserves, ) = pancakePair.getReserves();
        }

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
        require(6 <= _cavalryToPurchase && _cavalryToPurchase <= 10, "purchaseCavalry::WC");
        require(fortunasAssets.ownershipOf(msg.sender, _cavalryToPurchase) == false, "purchaseCavalry::OC");


        uint256 reserves;
        if (pancakePair.token0() == address(fortunasToken)) {
            (reserves, , ) = pancakePair.getReserves();
        }
        else {
            (, reserves, ) = pancakePair.getReserves();
        }

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
        require(1 <= _heroToAdd && _heroToAdd <= 5, "addHero::WH");
        require(fortunasAssets.ownershipOf(msg.sender, _heroToAdd), "addHero::HNO");
        require(tempBattle.initialTokensStaked != 0, "addHero::WB");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addHero::WBT2");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addHero::BE");
        require(heroBattleForAddress[msg.sender][_heroToAdd] == 0, "addHero::HAB1");
        require(tempBattle.hero == 0, "addHero::HAB2");


        tempBattle = battlingExtension.calculateRewards(tempBattle);
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
        require(1 <= _heroToRemove && _heroToRemove <= 5, "removeHero::WH");
        require(fortunasAssets.ownershipOf(msg.sender, _heroToRemove), "removeHero::HNO");
        require(tempBattle.initialTokensStaked != 0, "removeHero::WB");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeHero::WBT2");
        require(heroBattleForAddress[msg.sender][_heroToRemove] == _battleType, "removeHero::HAB3");


        tempBattle = battlingExtension.calculateRewards(tempBattle);
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
        require(6 <= _cavalryToAdd && _cavalryToAdd <= 10, "addCavalry::WC");
        require(fortunasAssets.ownershipOf(msg.sender, _cavalryToAdd), "addCavalry::CNO");
        require(tempBattle.initialTokensStaked != 0, "addCavalry::WB");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "addCavalry::WBT2");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "addCavalry::BE");
        require(cavalryBattleForAddress[msg.sender][_cavalryToAdd] == 0, "addCavalry::CAB1");
        require(tempBattle.cavalry == 0, "addCavalry::CAB2");


        tempBattle = battlingExtension.calculateRewards(tempBattle);
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
        require(6 <= _cavalryToRemove && _cavalryToRemove <= 10, "removeCavalry::WC");
        require(fortunasAssets.ownershipOf(msg.sender, _cavalryToRemove), "removeCavalry::CNO");
        require(tempBattle.initialTokensStaked != 0, "removeCavalry::WB");
        require(3 <= tempBattle.battleType && tempBattle.battleType <= 6, "removeCavalry::WBT2");
        require(cavalryBattleForAddress[msg.sender][_cavalryToRemove] == _battleType, "removeCavalry::CAB3");


        tempBattle = battlingExtension.calculateRewards(tempBattle);
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
        require(2 <= _battleType && _battleType <= 6, "battleEnd::WBT1");
        require(tempBattle.initialTokensStaked != 0, "battleEnd::WB");


        tempBattle = battlingExtension.calculateRewardsForBattleEnd(tempBattle);
        uint256 tokensToTransfer = tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards);

        if (_battleType == 2) {
            require(LPToken.balanceOf(address(this)) >= tokensToTransfer, "battleEnd::WT3");
            LPToken.transfer(msg.sender, tokensToTransfer);
        }
        else {
            uint256 totalContractBalance = fortunasToken.balanceOf(address(this));
            if (tokensToTransfer > totalContractBalance) {
                uint256 toMint = tokensToTransfer.sub(totalContractBalance);
                fortunasToken.mint(address(this), toMint);
            }
            fortunasToken.transfer(msg.sender, tokensToTransfer);

            tempBattle = _calculateLosses(tempBattle);

            if (tempBattle.hero != 0) {
                fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, tempBattle.hero, 1, "");
            }
            if (tempBattle.cavalry != 0) {
                fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, tempBattle.cavalry, 1, "");
            }
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

    function _calculateLosses(Battle memory _tempBattle) internal returns (Battle memory) {
        uint256 chanceToLoose = 50;
        if (_tempBattle.battleDaysExpended > 3) {
            uint256 chanceDecrease = _tempBattle.battleDaysExpended.sub(3).mul(5);
            chanceToLoose = chanceToLoose.safeSub(chanceDecrease);
        }

        if (_tempBattle.hero != 0 && chanceToLoose != 0) {
            // TODO
            uint256 randHero = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
            randHero = randHero.mod(100);

            if (0 < randHero && randHero <= chanceToLoose) {
                emit HeroLost (
                    msg.sender,
                    0,
                    false,
                    _tempBattle.hero
                );

                fortunasAssets.burnWithoutCheck(msg.sender, _tempBattle.hero, 1);

                heroBattleForAddress[msg.sender][_tempBattle.hero] = 0;

                _tempBattle.currentRewardPercentage -= assetPercentages[_tempBattle.hero - 1];
                if (_tempBattle.dayForLimitReached != 0) {
                    _tempBattle.dayForLimitReached = 0;
                }
                _tempBattle.hero = 0;
            }
        }

        if (_tempBattle.cavalry != 0 && chanceToLoose != 0) {
            uint256 randCavalry = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
            randCavalry = randCavalry.mod(100);

            if (0 < randCavalry && randCavalry <= chanceToLoose) {
                emit CavalryLost (
                    msg.sender,
                    0,
                    false,
                    _tempBattle.cavalry
                );

                fortunasAssets.burnWithoutCheck(msg.sender, _tempBattle.cavalry, 1);

                cavalryBattleForAddress[msg.sender][_tempBattle.cavalry] = 0;

                _tempBattle.currentRewardLimit -= assetPercentages[_tempBattle.cavalry - 1];
                if (_tempBattle.currentRewardPercentage >= _tempBattle.currentRewardLimit) {
                    _tempBattle.currentRewardPercentage = _tempBattle.currentRewardLimit;
                    _tempBattle.dayForLimitReached = _tempBattle.battleDaysExpended;
                }
                _tempBattle.cavalry = 0;
            }
        }

        return _tempBattle;
    }

    function removeLPTokens(uint256 _amount) external onlyOwner {
        if (_amount == 0) {
            LPToken.transfer(owner(), LPToken.balanceOf(address(this)));
            return;
        }

        require(LPToken.balanceOf(address(this)) >= _amount);

        LPToken.transfer(owner(), _amount);
    }

    /**
     * @dev Should be called if updated battle data needed
     * @dev Ideally to be called only if an update on current reward amount is needed
     * @dev Function "battleEnd" should be called if unstaking
     */
    function viewAllRewards(address _user) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory tempRewards = new uint256[](5);
        uint256[] memory nextRewards = new uint256[](5);
        uint256 extraRewards;
        Battle memory tempBattle;
        for (uint256 i = 0 ; i < 5 ; i++) {
            tempBattle = battleForAddress[_user][i + 2];
            if (tempBattle.initialTokensStaked != 0) {
                if (block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
                    tempBattle = battlingExtension.calculateRewards(tempBattle);

                    (extraRewards, nextRewards[i]) = battlingExtension.calculateExtraRewards(tempBattle);
                    tempBattle.rewards += extraRewards;
                }
                else {
                    tempBattle = battlingExtension.calculateRewardsForBattleEnd(tempBattle);
                }
            }
            tempRewards[i] = tempBattle.rewards;
        }

        return (tempRewards, nextRewards);
    }
}