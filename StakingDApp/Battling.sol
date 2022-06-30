pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./BattlingBase.sol";
import "./BattlingExtension.sol";
import "./FortunasToken.sol";
import "./IFortunasAssets.sol";
import "./ERC1155Holder.sol";
import "./IPancakePair.sol";
import "./IPancakeRouter02.sol";
import "./IPancakeFactory.sol";

contract Battling is BattlingBase, ERC1155Holder {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    // BUSD mainnet
    // address public BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    // TODO remove
    address public BUSD;

    // PancakeSwap
    IPancakeRouter02 public pancakeRouter;
    IPancakePair public pancakePair;

    // LP Token for FRTNA-BUSD pair
    IERC20 public LPToken;

    // FRTNA
    FortunasToken public fortunasToken;

    // Fortunas Multi Token for heroes and cavalry
    IFortunasAssets public fortunasAssets;

    // Contract that handles calculations for Battling
    BattlingExtension public battlingExtension;

    // Treasury Wallet
    address public treasuryWallet;

    // Initial cost of supplies to send troops to battle
    uint256 public suppliesCost;

    // Initial staked tokens percentage at which battle resets
    uint256 public battleResetPercentage;

    // Each hero's/cavalry's effect on current/total battle APY
    uint256[10] public assetPercentages;

    // Percentage cost of LP for purchasing each hero/cavalry
    uint256[10] public assetPrices;

    // Percentage cost of LP for purchasing a random hero
    uint256 public randomAssetPrice;

    // Percentage chance of losing hero/cavalry in a battle that is being ended or having tokens removed
    uint256 public loseAssetChance;

    // mappings

    mapping (address => mapping(uint8 => Battle)) private battleForAddress;

    // events

    event BattleStarted (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 initialTokensStaked,
        uint256 additionalTokens,
        uint256 rewards,
        uint256 rations,
        uint256 passiveRewards,
        uint256 battleStartTime,
        uint256 battleDurationInDays,
        uint256 hero,
        uint256 cavalry
    );

    event BattleUpdated (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 initialTokensStaked,
        uint256 additionalTokens,
        uint256 rewards,
        uint256 rations,
        uint256 passiveRewards,
        uint256 battleStartTime,
        uint256 battleDurationInDays,
        uint256 hero,
        uint256 cavalry
    );

    event BattleEnded (
        address indexed user,
        uint256 battleType,
        bool battleStatus,
        uint256 initialTokensStaked,
        uint256 additionalTokens,
        uint256 rewards,
        uint256 rations,
        uint256 passiveRewards,
        uint256 battleStartTime,
        uint256 battleDurationInDays,
        uint256 hero,
        uint256 cavalry
    );

    event AssetPurchased (address indexed user, uint256 asset, uint256 amount);

    event AssetDeployed (address indexed user, uint256 asset, uint256 amount);

    event AssetReturned (address indexed user, uint256 asset, uint256 amount);

    event AssetLost (address indexed user, uint256 asset, uint256 amount);

    // constructor

    /*
     * @dev all rations related variables for battling are defined and initialized in base class
     * @dev all reward related variables for battling are defined base class
     * @dev all reward related variables for battling are initialized outside of constructor in parent class
     */
    constructor(address _fortunasToken, address _fortunasAssets) {
        // TODO remove
        if (block.chainid == 97) {
            BUSD = 0x8354e8b945D6C35bD35615DD0277C4032cd0a67D;
        }
        else if (block.chainid == 4) {
            BUSD = 0x7D9385C733a967793EE14D933212ee44025f1B9d;
        }

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
        address _addressForPancakePair = IPancakeFactory(_pancakeRouter.factory()).getPair(_fortunasToken, BUSD);

        pancakeRouter = _pancakeRouter;
        pancakePair = IPancakePair(_addressForPancakePair);

        LPToken = IERC20(_addressForPancakePair);

        fortunasToken = FortunasToken(payable(_fortunasToken));

        fortunasAssets = IFortunasAssets(_fortunasAssets);

        battlingExtension = new BattlingExtension();

        // TODO change
        treasuryWallet = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;

        suppliesCost = 5000;

        battleResetPercentage = 200;

        assetPercentages = [20, 40, 60, 80, 100,
                            2083, 4167, 6250, 8333, 10417];

        assetPrices = [2500, 5000, 7500, 10000, 12500,
                        2500, 5000, 7500, 10000, 12500];

        randomAssetPrice = 5000;

        loseAssetChance = 50;
    }

    // getters

    function getBattleForAddress(address _user, uint8 _battleType) external view returns (Battle memory) {
        return battleForAddress[_user][_battleType];
    }

    // setters

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        treasuryWallet = _treasuryWallet;
    }

    function setBattleResetPercentage(uint256 _battleResetPercentage) external onlyOwner {
        battleResetPercentage = _battleResetPercentage;
    }

    // functions

    function startBattle(
        uint256 _amount,
        uint8 _battleType
    ) external {
        require(_amount >= minStakeAmount[_battleType - 1], "startBattle::MIN");
        require(2 <= _battleType && _battleType <= 6, "startBattle::WBT1");
        require(battleForAddress[msg.sender][_battleType].initialTokensStaked == 0, "startBattle::BAS");

        if (_battleType == 2) {
            LPToken.transferFrom(msg.sender, address(this), _amount);
        }
        else {
            uint256 supplies = _amount.mul(suppliesCost).div(multiplier);
            _amount -= supplies;

            fortunasToken.transferFrom(msg.sender, treasuryWallet, supplies);

            fortunasToken.transferFrom(msg.sender, address(this), _amount);
        }

        battleForAddress[msg.sender][_battleType] = Battle(_battleType, _amount, 0, 0, 0, 0, rewardPercentagesPerCycle[_battleType - 1], toCollectPercentages[_battleType - 1], block.timestamp, 0, 0, 0, 0);

        emit BattleStarted (
            msg.sender,
            _battleType,
            true,
            _amount,
            0, 0, 0, 0,
            battleForAddress[msg.sender][_battleType].battleStartTime,
            3, 0, 0
        );
    }

    function sendRations(
        uint256 _rationDays,
        uint8 _battleType
    ) external validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        require(1 <= _rationDays && _rationDays <= 5, "sendRations::WR1");

        if (tempBattle.rationsDaysTotal != 0) {
            uint256 rationsExpended = 
                block.timestamp.sub(tempBattle.battleStartTime.add(baseBattleTime)).ceilDiv(oneDayTime);
            uint256 currentRationsDays =
                tempBattle.rationsDaysTotal.sub(rationsExpended).add(_rationDays);
            require(currentRationsDays <= 5, "sendRations::WR2");
        }

        tempBattle = battlingExtension.calculateRewards(tempBattle);

        (uint256 extraRewards, ) = battlingExtension.calculateExtraRewards(tempBattle);

        uint256 tempRations;
        (tempBattle, tempRations) = battlingExtension.calculateRations(tempBattle, extraRewards, _rationDays);

        fortunasToken.burn(msg.sender, tempRations);

        battleForAddress[msg.sender][_battleType].rations += tempRations;
        battleForAddress[msg.sender][_battleType].rationsDaysTotal += _rationDays;

        tempBattle = battleForAddress[msg.sender][_battleType];

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.passiveRewards,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.hero,
            tempBattle.cavalry
        );
    }

    function addTroops(
        uint256 _amountToAdd,
        uint8 _battleType
    ) external validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        tempBattle = battlingExtension.calculateRewards(tempBattle);

        tempBattle.additionalTokens += _amountToAdd;
        if (tempBattle.additionalTokens >
            tempBattle.initialTokensStaked.mul(battleResetPercentage).div(100)) {
            tempBattle.currentToCollectPercentage = toCollectPercentages[tempBattle.battleType - 1];
            if (tempBattle.hero != 0) {
                tempBattle.currentToCollectPercentage += assetPercentages[tempBattle.hero - 1];
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
            tempBattle.passiveRewards,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.hero,
            tempBattle.cavalry
        );
    }

    function removeTroops(
        uint256 _amountToRemove,
        uint8 _battleType
    ) external validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        tempBattle = battlingExtension.calculateRewards(tempBattle);

        uint256 tempTotalTokens = tempBattle.initialTokensStaked.add(tempBattle.additionalTokens).add(tempBattle.rewards);
        require(_amountToRemove < tempTotalTokens, "removeTroops::WA");
        require(minStakeAmount[_battleType - 1] <= tempTotalTokens.sub(_amountToRemove), "removeTroops::MIN");

        uint256 tempAmountToRemove = _amountToRemove;
        if (tempAmountToRemove > tempBattle.additionalTokens) {
            uint256 rewardsToMint;

            tempAmountToRemove -= tempBattle.additionalTokens;
            tempBattle.additionalTokens = 0;
            if (tempAmountToRemove > tempBattle.rewards) {
                rewardsToMint = tempBattle.rewards;
                tempAmountToRemove -= tempBattle.rewards;
                tempBattle.rewards = 0;
                tempBattle.initialTokensStaked -= tempAmountToRemove;
            }
            else {
                rewardsToMint = tempAmountToRemove;
                tempBattle.rewards -= tempAmountToRemove;
            }

            bool isMint = rewardsToMint != 0;

            if (isMint) {
                fortunasToken.mint(msg.sender, rewardsToMint);
                _amountToRemove -= rewardsToMint;
            }
        }
        else {
            tempBattle.additionalTokens -= tempAmountToRemove;
        }

        fortunasToken.transfer(msg.sender, _amountToRemove);

        if (tempBattle.hero != 0 || tempBattle.cavalry != 0) {
            uint256 chanceToLoseAssets = loseAssetChance;

            if (tempBattle.battleDaysExpended > 3) {
                uint256 chanceDecrease = tempBattle.battleDaysExpended.sub(3).mul(5);
                chanceToLoseAssets = chanceToLoseAssets.safeSub(chanceDecrease);
            }

            if (chanceToLoseAssets != 0) {
                tempBattle = handleLoss(tempBattle, chanceToLoseAssets, false);
            }
        }

        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.passiveRewards,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.hero,
            tempBattle.cavalry
        );
    }

    function purchaseAsset(
        uint256 _assetToPurchase
    ) external {
        require(0 <= _assetToPurchase && _assetToPurchase <= 10, "purchaseHero::WA");

        uint256 pricePercentage;
        if (_assetToPurchase == 0) {
            pricePercentage = randomAssetPrice;
            _assetToPurchase = battlingExtension.createRandomnessForAsset();
        }
        else {
            pricePercentage = assetPrices[_assetToPurchase - 1];
        }

        uint256 reserves;
        if (address(fortunasToken) == pancakePair.token0()) {
            (reserves, , ) = pancakePair.getReserves();
        }
        else {
            (, reserves, ) = pancakePair.getReserves();
        }

        uint256 price = reserves.mul(pricePercentage).roundDiv(multiplier);
        fortunasToken.transferFrom(msg.sender, address(this), price);

        fortunasAssets.mint(msg.sender, _assetToPurchase, 1, "");

        emit AssetPurchased (
            msg.sender,
            _assetToPurchase,
            fortunasAssets.balanceOf(msg.sender, _assetToPurchase)
        );
    }

    function deployAsset(
        uint256 _assetToDeploy,
        uint8 _battleType
    ) external validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        require(1 <= _assetToDeploy && _assetToDeploy <= 10, "deployAsset::WA");
        require(fortunasAssets.balanceOf(msg.sender, _assetToDeploy) > 0, "deployAsset::ANO");

        if (_assetToDeploy <= 5) {
            require(tempBattle.hero == 0, "deployAsset::HIB");

            tempBattle = battlingExtension.calculateRewards(tempBattle);

            tempBattle.currentToCollectPercentage += assetPercentages[_assetToDeploy - 1];

            tempBattle.hero = _assetToDeploy;
        }
        else {
            require(tempBattle.cavalry == 0, "deployAsset::CIB");

            tempBattle = battlingExtension.calculateRewards(tempBattle);

            tempBattle.currentRewardPercentagePerCycle += assetPercentages[_assetToDeploy - 1];

            tempBattle.cavalry = _assetToDeploy;
        }

        fortunasAssets.safeTransferFromWithCheck(msg.sender, address(this), _assetToDeploy, 1, "");

        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit AssetDeployed (
            msg.sender,
            _assetToDeploy,
            fortunasAssets.balanceOf(msg.sender, _assetToDeploy)
        );

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.passiveRewards,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.hero,
            tempBattle.cavalry
        );
    }

    function returnAsset(
        uint256 _assetToReturn,
        uint8 _battleType
    ) public validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        require(1 <= _assetToReturn && _assetToReturn <= 10, "returnAsset::WA");

        if (_assetToReturn <= 5) {
            require(tempBattle.hero == _assetToReturn, "returnAsset::HNIB");

            tempBattle = battlingExtension.calculateRewards(tempBattle);

            tempBattle.currentToCollectPercentage -= assetPercentages[_assetToReturn - 1];

            tempBattle.hero = 0;
        }
        else {
            require(tempBattle.cavalry == _assetToReturn, "returnAsset::CNIB");

            tempBattle = battlingExtension.calculateRewards(tempBattle);

            tempBattle.currentRewardPercentagePerCycle -= assetPercentages[_assetToReturn - 1];

            tempBattle.cavalry = 0;
        }

        fortunasAssets.safeTransferFromWithCheck(address(this), msg.sender, _assetToReturn, 1, "");

        battleForAddress[msg.sender][_battleType] = tempBattle;

        emit AssetReturned (
            msg.sender,
            _assetToReturn,
            fortunasAssets.balanceOf(msg.sender, _assetToReturn)
        );

        emit BattleUpdated (
            msg.sender,
            _battleType,
            true,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.rations,
            tempBattle.passiveRewards,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3),
            tempBattle.hero,
            tempBattle.cavalry
        );
    }

    function endBattle(
        uint8 _battleType
    ) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(2 <= _battleType && _battleType <= 6, "endBattle::WBT1");
        require(tempBattle.initialTokensStaked != 0, "endBattle:WB");

        tempBattle = battlingExtension.calculateRewardsForEndBattle(tempBattle);

        if (_battleType == 2) {
            LPToken.transfer(msg.sender, tempBattle.initialTokensStaked);

            uint256 rewardsToMint = tempBattle.rewards.add(tempBattle.passiveRewards);

            bool isMint = rewardsToMint != 0;

            if (isMint) {
                fortunasToken.mint(msg.sender, rewardsToMint);
            }
        }
        else {
            uint256 tokensToReturn = tempBattle.initialTokensStaked.add(tempBattle.additionalTokens);

            uint256 rewardsToMint = tempBattle.rewards.add(tempBattle.passiveRewards);

            bool isMint = rewardsToMint != 0;

            if (isMint) {
                fortunasToken.mint(msg.sender, rewardsToMint);
            }

            fortunasToken.transfer(msg.sender, tokensToReturn);

            if (tempBattle.hero != 0 || tempBattle.cavalry != 0) {
                uint256 chanceToLoseAssets = loseAssetChance;

                if (tempBattle.battleDaysExpended > 3) {
                    uint256 chanceDecrease = tempBattle.battleDaysExpended.sub(3).mul(5);
                    chanceToLoseAssets = chanceToLoseAssets.safeSub(chanceDecrease);
                }

                if (chanceToLoseAssets != 0) {
                    tempBattle = handleLoss(tempBattle, chanceToLoseAssets, true);
                }
            }
        }

        Battle memory emptyBattle;
        battleForAddress[msg.sender][_battleType] = emptyBattle;

        emit BattleEnded (
            msg.sender,
            _battleType,
            false,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.passiveRewards,
            0, 0, 0, 0, 0
        );
    }

    function handleLoss(
        Battle memory _tempBattle,
        uint256 _chanceToLoseAssets,
        bool _isEndBattle
    ) internal returns (Battle memory) {
        bool isHeroLost;
        bool isCavalryLost;

        if (_tempBattle.hero != 0 && _tempBattle.cavalry != 0) {
            isHeroLost = battlingExtension.createRandomness(_chanceToLoseAssets, 100);
            isCavalryLost = battlingExtension.createRandomness(_chanceToLoseAssets, 100);
        }
        else if (_tempBattle.hero != 0) {
            isHeroLost = battlingExtension.createRandomness(_chanceToLoseAssets, 100);
        }
        else if (_tempBattle.cavalry != 0) {
            isCavalryLost = battlingExtension.createRandomness(_chanceToLoseAssets, 100);
        }

        if (isHeroLost) {
            fortunasAssets.burnWithCheck(address(this), _tempBattle.hero, 1);

            if (!_isEndBattle) {
                _tempBattle.currentToCollectPercentage -= assetPercentages[_tempBattle.hero - 1];
            }

            emit AssetLost (
                msg.sender,
                _tempBattle.hero,
                fortunasAssets.balanceOf(msg.sender, _tempBattle.hero)
            );

            _tempBattle.hero = 0;
        }

        if (isCavalryLost) {
            fortunasAssets.burnWithCheck(address(this), _tempBattle.cavalry, 1);

            if (!_isEndBattle) {
                _tempBattle.currentRewardPercentagePerCycle -= assetPercentages[_tempBattle.cavalry - 1];
            }

            emit AssetLost (
                msg.sender,
                _tempBattle.cavalry,
                fortunasAssets.balanceOf(msg.sender, _tempBattle.cavalry)
            );

            _tempBattle.cavalry = 0;
        }

        if (_isEndBattle) {
            if (_tempBattle.hero != 0) {
                fortunasAssets.safeTransferFromWithCheck(address(this), msg.sender, _tempBattle.hero, 1, "");

                emit AssetReturned (
                    msg.sender,
                    _tempBattle.hero,
                    fortunasAssets.balanceOf(msg.sender, _tempBattle.hero)
                );
            }

            if (_tempBattle.cavalry != 0) {
                fortunasAssets.safeTransferFromWithCheck(address(this), msg.sender, _tempBattle.cavalry, 1, "");

                emit AssetReturned (
                    msg.sender,
                    _tempBattle.cavalry,
                    fortunasAssets.balanceOf(msg.sender, _tempBattle.cavalry)
                );
            }
        }

        return _tempBattle;
    }

    /*
     * @dev Should be called if updated battle data needed
     * @dev Ideally to be called only if an update on current reward amount is needed
     * @dev Function "endBattle" should be called if unstaking
     */
    function viewAllRewards(
        address _user
    ) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory tempRewards = new uint256[](5);
        uint256[] memory nextRewards = new uint256[](5);
        uint256 extraRewards;
        Battle memory tempBattle;
        for (uint8 i = 0 ; i < 5 ; i++) {
            tempBattle = battleForAddress[_user][i + 2];
            if (tempBattle.initialTokensStaked != 0) {
                if (block.timestamp <
                    tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))) {
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
        _validBattle(_battleType);
        _;
    }

    function _validBattle(uint8 _battleType) internal view {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];
        require(tempBattle.initialTokensStaked != 0, "Battling:WB");
        require(block.timestamp <
            tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime)), "battling::BE");
    }

    modifier validBattleType(uint8 _battleType) {
        _validBattleType(_battleType);
        _;
    }

    function _validBattleType(uint8 _battleType) internal pure {
        require(3 <= _battleType && _battleType <= 6, "Battling::WBT2");
    }

    // testing only
    function testRewardTime(uint256 _seconds) public {
        rewardTime = _seconds;
        oneDayTime = _seconds.mul(48);
        baseBattleTime = _seconds.mul(144);

        battlingExtension.testRewardTime(_seconds);
    }

    function testToCollectPercentage(uint256 _chanceToCollect) public {
        toCollectPercentages = [1000, 1000, _chanceToCollect, _chanceToCollect, _chanceToCollect, _chanceToCollect];

        battlingExtension.testToCollectPercentage(_chanceToCollect);
    }
}