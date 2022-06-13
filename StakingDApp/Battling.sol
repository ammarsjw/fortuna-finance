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

    // FRTNA
    IFortunasToken public fortunasToken;

    // Fortunas Multi Token for heroes and cavalry
    FortunasAssets public fortunasAssets;

    // Contract that handles calculations for Battling
    BattlingExtension public battlingExtension;

    // Treasury Wallet
    address public treasuryWallet;

    // BUSD mainnet
    // address public BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    // BUSD testnet (TestnetERC20Token)
    address public BUSD = address(0x7D9385C733a967793EE14D933212ee44025f1B9d);

    uint256[10] assetPercentages;
    uint256[10] assetPrices;

    uint256 randomAssetPrice;

    // mappings

    mapping (address => mapping(uint8 => Battle)) private battleForAddress;
    mapping (address => mapping(uint256 => uint8)) private battleTypeForAsset;

    // events

    event BattleStarted (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 initialTokensStaked,
        uint256 additionalTokens,
        uint256 rewards,
        uint256 rations,
        uint256 battleStartTime,
        uint256 battleDurationInDays
    );

    event BattleUpdated (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 initialTokensStaked,
        uint256 additionalTokens,
        uint256 rewards,
        uint256 rations,
        uint256 battleStartTime,
        uint256 battleDurationInDays
    );

    event BattleEnded (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 initialTokensStaked,
        uint256 additionalTokens,
        uint256 rewards,
        uint256 rations,
        uint256 battleStartTime,
        uint256 battleDurationInDays
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

    constructor(address _fortunasToken, uint64 _subscriptionId) {
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

        fortunasToken = IFortunasToken(payable(_fortunasToken));

        fortunasAssets = new FortunasAssets("", address(this));

        battlingExtension = new BattlingExtension(_subscriptionId, address(this));

        // TODO
        treasuryWallet = address(0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80);

        // each hero's/cavalry's effect on current/total battle APY
        assetPercentages = [200000, 400000, 600000, 800000, 1000000,
                            100000, 200000, 300000, 400000, 500000];
        // percentage cost of LP for purchasing each hero/cavalry
        assetPrices = [2500, 5000, 7500, 10000, 12500,
                        2500, 5000, 7500, 10000, 12500];

        // percentage cost of LP for purchasing a random hero
        randomAssetPrice = 5000;

        // setting all reward related variables for battling outside of constructor
    }

    // getters

    function getBattleForAddress(address _user, uint8 _battleType) external view returns (Battle memory) {
        return battleForAddress[_user][_battleType];
    }

    // setters

    function setFortunasToken(address _fortunasToken) external onlyOwner {
        fortunasToken = IFortunasToken(payable(_fortunasToken));
    }

    function setFortunasAssetsURI(string memory _uri) external onlyOwner {
        fortunasAssets.setURI(_uri);
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        treasuryWallet = _treasuryWallet;
    }

    function setAllRewards(uint256[6] memory _basePercentages, uint256 _increasePerDay, uint256[6] memory _limit) external onlyOwner {
        _setAllRewards(_basePercentages, _increasePerDay, _limit);
    }

    // functions

    function startBattle(uint256 _amount, uint8 _battleType) external {
        require(_amount >= minRewardAmount[_battleType - 1], "startBattle::MIN");
        require(2 <= _battleType && _battleType <= 6, "startBattle::WBT1");
        require(battleForAddress[msg.sender][_battleType].initialTokensStaked == 0, "startBattle::BAS");


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
            0,
            0,
            0,
            battleForAddress[msg.sender][_battleType].battleStartTime,
            3
        );
    }

    function sendRations(uint256 _rationDays, uint8 _battleType) external validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(1 <= _rationDays && _rationDays <= 5, "sendRations::WR1");
        if (tempBattle.battleDaysExpended != 0) {
            uint256 rationsExpended = block.timestamp.sub(tempBattle.battleStartTime.add(baseBattleTime)).ceilDiv(oneDayTime);
            uint256 currentRationsDays = tempBattle.rationsDaysTotal.sub(rationsExpended).add(_rationDays);
            require(currentRationsDays <= 5, "sendRations::WR2");
        }


        tempBattle = battlingExtension.calculateRewards(tempBattle);

        (uint256 extraRewards, ) = battlingExtension.calculateExtraRewards(tempBattle);

        uint256 tempRations;
        (tempBattle, tempRations) = battlingExtension.calculateRations(tempBattle, extraRewards, _rationDays);

        fortunasToken.burn(msg.sender, tempRations);

        battleForAddress[msg.sender][_battleType].rations += tempRations;
        battleForAddress[msg.sender][_battleType].rationsDaysTotal += _rationDays;
        battleForAddress[msg.sender][_battleType].dayForLimitReached = tempBattle.dayForLimitReached;

        tempBattle = battleForAddress[msg.sender][_battleType];

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3)
        );
    }

    function addTroops(uint256 _amountToAdd, uint8 _battleType) external validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

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
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3)
        );
    }

    function removeTroops(uint256 _amountToRemove, uint8 _battleType) external validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        tempBattle = battlingExtension.calculateRewards(tempBattle);
        require(_amountToRemove < tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards), "removeTroops::WA");
        require(tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards).sub(_amountToRemove) >= minRewardAmount[_battleType - 1], "removeTroops::MIN");

        if (_amountToRemove > tempBattle.additionalTokens) {
            _amountToRemove -= tempBattle.additionalTokens;
            tempBattle.additionalTokens = 0;
            if (_amountToRemove > tempBattle.rewards) {
                _amountToRemove -= tempBattle.rewards;
                tempBattle.rewards = 0;
                tempBattle.initialTokensStaked -= _amountToRemove;
            }
            else {
                tempBattle.rewards -= _amountToRemove;
            }
        }
        else {
            tempBattle.additionalTokens -= _amountToRemove;
        }

        uint256 totalContractBalance = fortunasToken.balanceOf(address(this));

        if (_amountToRemove > totalContractBalance) {
            uint256 toMint = _amountToRemove.sub(totalContractBalance);
            fortunasToken.mint(address(this), toMint);
        }
        fortunasToken.transfer(msg.sender, _amountToRemove);

        battleForAddress[msg.sender][_battleType] = tempBattle;

        uint256 chanceToLose = 50;
        if (tempBattle.battleDaysExpended > 3) {
            uint256 chanceDecrease = tempBattle.battleDaysExpended.sub(3).mul(5);
            chanceToLose = chanceToLose.safeSub(chanceDecrease);
        }

        if (chanceToLose != 0) {
            if (tempBattle.hero != 0 && tempBattle.cavalry != 0) {
                battlingExtension.requestRandomnessForLoss(2, msg.sender, _battleType, chanceToLose, false, 1);
            }
            else if (tempBattle.hero != 0) {
                battlingExtension.requestRandomnessForLoss(1, msg.sender, _battleType, chanceToLose, false, 2);
            }
            else if (tempBattle.cavalry != 0) {
                battlingExtension.requestRandomnessForLoss(1, msg.sender, _battleType, chanceToLose, false, 3);
            }
        }

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3)
        );
    }

    function purchaseAsset(uint256 _assetToPurchase) external {
        require(0 <= _assetToPurchase && _assetToPurchase <= 10, "purchaseHero::WA");

        uint256 pricePercentage;
        if (_assetToPurchase == 0) {
            battlingExtension.requestRandomnessForRandomAsset();
        }
        else if (msg.sender == address(battlingExtension)) {
            pricePercentage = randomAssetPrice;
        }
        else {
            pricePercentage = assetPrices[_assetToPurchase - 1];
        }
        require(fortunasAssets.ownershipOf(msg.sender, _assetToPurchase) == false, "purchaseHero::HAO");


        uint256 reserves;
        if (pancakePair.token0() == address(fortunasToken)) {
            (reserves, , ) = pancakePair.getReserves();
        }
        else {
            (, reserves, ) = pancakePair.getReserves();
        }

        uint256 price = reserves.mul(pricePercentage).roundDiv(multiplier);
        fortunasToken.transferFrom(msg.sender, address(this), price);

        fortunasAssets.mint(msg.sender, _assetToPurchase, 1, "");

        if (_assetToPurchase <= 5) {
            emit HeroPurchased (
                msg.sender,
                0,
                true,
                _assetToPurchase
            );
        }
        else {
            emit CavalryPurchased (
                msg.sender,
                0,
                true,
                _assetToPurchase
            );
        }
    }

    function deployAsset(uint256 _assetToDeploy, uint8 _battleType) external validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(1 <= _assetToDeploy && _assetToDeploy <= 10, "deployAsset::WA");
        require(fortunasAssets.ownershipOf(msg.sender, _assetToDeploy), "deployAsset::ANO");
        require(battleTypeForAsset[msg.sender][_assetToDeploy] == 0, "deployAsset::AAB1");


        tempBattle = battlingExtension.calculateRewards(tempBattle);

        if (_assetToDeploy <= 5) {
            require(tempBattle.hero == 0, "deployAsset::BAHH");

            tempBattle.currentRewardPercentage += assetPercentages[_assetToDeploy - 1];
            if (tempBattle.currentRewardPercentage >= tempBattle.currentRewardLimit) {
                tempBattle.currentRewardPercentage = tempBattle.currentRewardLimit;
                tempBattle.dayForLimitReached = tempBattle.battleDaysExpended;
            }
            tempBattle.hero = _assetToDeploy;

            emit HeroDeployed (
                msg.sender,
                _battleType,
                true,
                _assetToDeploy
            );
        }
        else {
            require(tempBattle.cavalry == 0, "deployAsset::BAHC");

            tempBattle.currentRewardLimit += assetPercentages[_assetToDeploy - 1];
            if (tempBattle.dayForLimitReached != 0) {
                if (tempBattle.currentRewardPercentage < tempBattle.currentRewardLimit) {
                    tempBattle.dayForLimitReached = 0;
                }
            }
            tempBattle.cavalry = _assetToDeploy;

            emit CavalryDeployed (
                msg.sender,
                _battleType,
                true,
                _assetToDeploy
            );
        }

        fortunasAssets.safeTransferFromWithoutCheck(msg.sender, address(this), _assetToDeploy, 1, "");

        battleTypeForAsset[msg.sender][_assetToDeploy] = _battleType;
        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3)
        );
    }

    function returnAsset(uint256 _assetToReturn, uint8 _battleType) public validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(1 <= _assetToReturn && _assetToReturn <= 10, "removeHero::WA");
        require(fortunasAssets.ownershipOf(msg.sender, _assetToReturn), "removeHero::ANO");
        require(battleTypeForAsset[msg.sender][_assetToReturn] == _battleType, "removeHero::AAB2");


        tempBattle = battlingExtension.calculateRewards(tempBattle);

        if (_assetToReturn <= 5) {
            tempBattle.currentRewardPercentage -= assetPercentages[_assetToReturn - 1];
            if (tempBattle.dayForLimitReached != 0) {
                tempBattle.dayForLimitReached = 0;
            }
            tempBattle.hero = 0;

            emit HeroReturned (
                msg.sender,
                0,
                true,
                _assetToReturn
            );
        }
        else {
            tempBattle.currentRewardLimit -= assetPercentages[_assetToReturn - 1];
            if (tempBattle.currentRewardPercentage >= tempBattle.currentRewardLimit) {
                tempBattle.currentRewardPercentage = tempBattle.currentRewardLimit;
                tempBattle.dayForLimitReached = tempBattle.battleDaysExpended;
            }
            tempBattle.cavalry = 0;

            emit CavalryReturned (
                msg.sender,
                0,
                true,
                _assetToReturn
            );
        }

        fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, _assetToReturn, 1, "");

        battleTypeForAsset[msg.sender][_assetToReturn] = 0;
        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3)
        );
    }

    function endBattle(uint8 _battleType) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(2 <= _battleType && _battleType <= 6, "endBattle::WBT1");
        require(tempBattle.initialTokensStaked != 0, "endBattle:WB");


        tempBattle = battlingExtension.calculateRewardsForEndBattle(tempBattle);

        if (_battleType == 2) {
            uint256 tokensToRefund = tempBattle.initialTokensStaked;
            LPToken.transfer(msg.sender, tokensToRefund);

            uint256 tokensToTransfer = tempBattle.rewards;
            uint256 totalContractBalance = fortunasToken.balanceOf(address(this));

            if (tokensToTransfer > totalContractBalance) {
                uint256 toMint = tokensToTransfer.sub(totalContractBalance);
                fortunasToken.mint(address(this), toMint);
            }
            fortunasToken.transfer(msg.sender, tokensToTransfer);
        }
        else {
            uint256 tokensToTransfer = tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards);
            uint256 totalContractBalance = fortunasToken.balanceOf(address(this));

            if (tokensToTransfer > totalContractBalance) {
                uint256 toMint = tokensToTransfer.sub(totalContractBalance);
                fortunasToken.mint(address(this), toMint);
            }
            fortunasToken.transfer(msg.sender, tokensToTransfer);

            uint256 chanceToLose = 50;
            if (tempBattle.battleDaysExpended > 3) {
                uint256 chanceDecrease = tempBattle.battleDaysExpended.sub(3).mul(5);
                chanceToLose = chanceToLose.safeSub(chanceDecrease);
            }

            if (chanceToLose != 0) {
                if (tempBattle.hero != 0 && tempBattle.cavalry != 0) {
                    battlingExtension.requestRandomnessForLoss(2, msg.sender, _battleType, chanceToLose, true, 1);
                }
                else if (tempBattle.hero != 0) {
                    battlingExtension.requestRandomnessForLoss(1, msg.sender, _battleType, chanceToLose, true, 2);
                }
                else if (tempBattle.cavalry != 0) {
                    battlingExtension.requestRandomnessForLoss(1, msg.sender, _battleType, chanceToLose, true, 3);
                }
            }
        }

        emit BattleEnded (
            msg.sender,
            _battleType,
            false,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            0,
            0,
            0
        );
    }

    function handleLoss(address _user, uint8 _battleType, uint256 _chanceToLose, bool _isEndBattle, uint256 _chanceForHeroLoss, uint256 _chanceForCavalryLoss) external {
        require(msg.sender == address(battlingExtension), "handleLoss::WS");
        Battle memory tempBattle = battleForAddress[_user][_battleType];

        if (_chanceForHeroLoss != 0) {
            if (_chanceForHeroLoss <= _chanceToLose) {
                emit HeroLost (
                    msg.sender,
                    0,
                    false,
                    tempBattle.hero
                );

                fortunasAssets.burnWithoutCheck(msg.sender, tempBattle.hero, 1);

                battleTypeForAsset[msg.sender][tempBattle.hero] = 0;

                if (!_isEndBattle) {
                    tempBattle.currentRewardPercentage -= assetPercentages[tempBattle.hero - 1];
                    if (tempBattle.dayForLimitReached != 0) {
                        tempBattle.dayForLimitReached = 0;
                    }
                }

                tempBattle.hero = 0;
            }
        }

        if (_chanceForCavalryLoss != 0) {
            if (_chanceForCavalryLoss <= _chanceToLose) {
                emit CavalryLost (
                    msg.sender,
                    0,
                    false,
                    tempBattle.cavalry
                );

                fortunasAssets.burnWithoutCheck(msg.sender, tempBattle.cavalry, 1);

                battleTypeForAsset[msg.sender][tempBattle.cavalry] = 0;

                if (!_isEndBattle) {
                    tempBattle.currentRewardLimit -= assetPercentages[tempBattle.cavalry - 1];
                    if (tempBattle.currentRewardPercentage >= tempBattle.currentRewardLimit) {
                        tempBattle.currentRewardPercentage = tempBattle.currentRewardLimit;
                        tempBattle.dayForLimitReached = tempBattle.battleDaysExpended;
                    }
                }

                tempBattle.cavalry = 0;
            }
        }

        if (_isEndBattle) {
            if (tempBattle.hero != 0) {
                fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, tempBattle.hero, 1, "");
                battleTypeForAsset[msg.sender][tempBattle.hero] = 0;

                emit HeroReturned (
                    msg.sender,
                    0,
                    true,
                    tempBattle.hero
                );
            }
            if (tempBattle.cavalry != 0) {
                fortunasAssets.safeTransferFromWithoutCheck(address(this), msg.sender, tempBattle.cavalry, 1, "");
                battleTypeForAsset[msg.sender][tempBattle.cavalry] = 0;

                emit CavalryReturned (
                    msg.sender,
                    0,
                    true,
                    tempBattle.cavalry
                );
            }

            Battle memory emptyBattle;
            battleForAddress[msg.sender][_battleType] = emptyBattle;

            return;
        }

        battleForAddress[_user][_battleType] = tempBattle;
    }

    /**
     * @dev Should be called if updated battle data needed
     * @dev Ideally to be called only if an update on current reward amount is needed
     * @dev Function "endBattle" should be called if unstaking
     */
    function viewAllRewards(address _user) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory tempRewards = new uint256[](5);
        uint256[] memory nextRewards = new uint256[](5);
        uint256 extraRewards;
        Battle memory tempBattle;
        for (uint8 i = 0 ; i < 5 ; i++) {
            tempBattle = battleForAddress[_user][i + 2];
            if (tempBattle.initialTokensStaked != 0) {
                if (block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
                    tempBattle = battlingExtension.calculateRewards(tempBattle);

                    (extraRewards, nextRewards[i]) = battlingExtension.calculateExtraRewards(tempBattle);
                    tempBattle.rewards += extraRewards;
                }
                else {
                    tempBattle = battlingExtension.calculateRewardsForEndBattle(tempBattle);
                }
            }
            tempRewards[i] = tempBattle.rewards;
        }

        return (tempRewards, nextRewards);
    }

    // modifiers

    modifier validBattle(uint8 _battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(tempBattle.initialTokensStaked != 0, "Battling:WB");
        require(block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "battling::BE");
        _;
    }

    modifier validBattleType(uint8 _battleType) {
        require(3 <= _battleType && _battleType <= 6, "Battling::WBT2");
        _;
    }
}