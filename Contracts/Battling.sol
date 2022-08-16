pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";

import "./BattlingBase.sol";
import "./BattlingExtension.sol";
import "./ERC1155Holder.sol";

import "./IFortunaToken.sol";
import "./IFortunaAssets.sol";
import "./IPancakeFactory.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";

contract Battling is BattlingBase, ERC1155Holder {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    // BUSD mainnet
    address public BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    // PancakeSwap
    IPancakeRouter02 public pancakeRouter;
    IPancakePair public pancakePair;

    // LP Token for FRTNA-BUSD pair
    IERC20 public LPToken;

    // FRTNA
    IFortunaToken public fortunaToken;

    // Fortuna Multi Token for heroes and cavalry
    IFortunaAssets public fortunaAssets;

    // Contract that handles calculations for Battling
    BattlingExtension public battlingExtension;

    // Treasury wallet
    address public treasuryWallet;

    // Reward wallet
    address public rewardWallet;

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
    uint256 public baseChanceToLoseAssets;

    // mappings

    mapping (address => mapping(uint8 => Battle)) battleForAddress;

    // events

    event UpdatedTreasuryWallet(address indexed newTreasuryWallet, address indexed oldTreasuryWallet);

    event UpdatedRewardWallet(address indexed newRewardWallet, address indexed oldRewardWallet);

    event UpdatedBattleResetPercentage(uint256 newBattleResetPercentage, uint256 oldBattleResetPercentage);

    event EndedBattle(
        address indexed user,
        uint256 battleType,
        uint256 initialTokensStaked,
        uint256 additionalTokens,
        uint256 rewards,
        uint256 passiveRewards,
        uint256 battleStartTime,
        uint256 battleDurationInDays
    );

    event PurchasedAsset(address indexed user, uint256 asset, uint256 amount);

    event LostAsset(address indexed user, uint256 asset, uint256 amount);

    // constructor

    constructor(address _fortunaToken, address _fortunaAssets) {
        // PancakeRouter02 mainnet
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address _addressForPancakePair = IPancakeFactory(_pancakeRouter.factory()).getPair(_fortunaToken, BUSD);

        pancakeRouter = _pancakeRouter;
        pancakePair = IPancakePair(_addressForPancakePair);

        LPToken = IERC20(_addressForPancakePair);

        fortunaToken = IFortunaToken(_fortunaToken);

        fortunaAssets = IFortunaAssets(_fortunaAssets);

        battlingExtension = new BattlingExtension();

        treasuryWallet = 0x8E98A208b3128066b8e1BA46BD8e34Dc09F8bf4f;

        rewardWallet = 0x6429B65da9EEE43ECE3771c5A840145fddcd95bd;

        suppliesCost = 20000;

        battleResetPercentage = 200;

        assetPercentages = [20, 40, 60, 80, 100,
                            101, 102, 103, 104, 105];

        assetPrices = [2500, 5000, 7500, 10000, 12500,
                        2500, 5000, 7500, 10000, 12500];

        randomAssetPrice = 5000;

        baseChanceToLoseAssets = 50;
    }

    // getters and setters

    function getBattleForAddress(address _user, uint8 _battleType) external view returns (Battle memory) {
        return battleForAddress[_user][_battleType];
    }

    function updateTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(treasuryWallet != _treasuryWallet, "updateTreasuryWallet::TW");
        emit UpdatedTreasuryWallet(_treasuryWallet, treasuryWallet);
        treasuryWallet = _treasuryWallet;
    }

    function updateRewardWallet(address _rewardWallet) external onlyOwner {
        require(rewardWallet != _rewardWallet, "updateRewardWallet::RW");
        emit UpdatedRewardWallet(_rewardWallet, rewardWallet);
        rewardWallet = _rewardWallet;
    }

    function updateBattleResetPercentage(uint256 _battleResetPercentage) external onlyOwner {
        require(battleResetPercentage != _battleResetPercentage, "updateBattleResetPercentage::BRP");
        emit UpdatedBattleResetPercentage(_battleResetPercentage, battleResetPercentage);
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

            fortunaToken.transferFrom(msg.sender, treasuryWallet, supplies);

            fortunaToken.transferFrom(msg.sender, address(this), _amount);
        }

        battleForAddress[msg.sender][_battleType] = Battle(_battleType, _amount, 0, 0, 0, 0, rewardPercentagesPerCycle[_battleType - 1], toCollectPercentages[_battleType - 1], 0, 0, block.timestamp, 0, 0, 0, 0, 0);
    }

    function sendRations(
        uint256 _rationDays,
        uint8 _battleType
    ) external validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        require(1 <= _rationDays && _rationDays <= 5, "sendRations::WR1");

        if (tempBattle.rationsDaysTotal != 0) {
            uint256 battleDaysTotal = tempBattle.rationsDaysTotal.add(3);

            uint256 daysWagingBattle;
            if (block.timestamp.sub(tempBattle.battleStartTime).div(oneDayTime) <= 3) {
                daysWagingBattle = 3;
            }
            else {
                daysWagingBattle = block.timestamp.sub(tempBattle.battleStartTime).ceilDiv(oneDayTime);
            }

            uint256 unusedRations = battleDaysTotal.sub(daysWagingBattle);
            uint256 rationsAcceptable = uint256(5).sub(unusedRations);

            require(_rationDays <= rationsAcceptable, "sendRations::WR2");
        }

        tempBattle = battlingExtension.calculateRewards(tempBattle);

        uint256 tempRations = battlingExtension.calculateRations(tempBattle, _rationDays);

        fortunaToken.burn(msg.sender, tempRations);

        tempBattle.rations += tempRations;
        tempBattle.rationsDaysTotal += _rationDays;

        battleForAddress[msg.sender][_battleType] = tempBattle;
    }

    function addTroops(
        uint256 _amountToAdd,
        uint8 _battleType
    ) external validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        tempBattle = battlingExtension.calculateRewards(tempBattle);

        uint256 supplies = _amountToAdd.mul(suppliesCost).div(multiplier);
        _amountToAdd -= supplies;

        fortunaToken.transferFrom(msg.sender, treasuryWallet, supplies);

        fortunaToken.transferFrom(msg.sender, address(this), _amountToAdd);

        tempBattle.additionalTokens += _amountToAdd;
        if (
            tempBattle.additionalTokens >
            tempBattle.initialTokensStaked.mul(battleResetPercentage).div(100)
        ) {
            tempBattle.currentToCollectPercentage = toCollectPercentages[tempBattle.battleType - 1];

            if (tempBattle.currentToCollectPercentage < 1000) {
                tempBattle.daysAtMaxToCollect = 0;
            }

            if (tempBattle.hero != 0) {
                tempBattle.currentToCollectPercentage += assetPercentages[tempBattle.hero - 1];
            }
        }

        battleForAddress[msg.sender][_battleType] = tempBattle;
    }

    function purchaseAsset(
        uint256 _assetToPurchase
    ) external {
        require(0 <= _assetToPurchase && _assetToPurchase <= 10, "purchaseHero::WA");

        uint256 pricePercentage;
        if (_assetToPurchase == 0) {
            pricePercentage = randomAssetPrice;
            _assetToPurchase = battlingExtension.createAssetRandomness();
        }
        else {
            pricePercentage = assetPrices[_assetToPurchase - 1];
        }

        uint256 reserves;
        if (address(fortunaToken) == pancakePair.token0()) {
            (reserves, , ) = pancakePair.getReserves();
        }
        else {
            (, reserves, ) = pancakePair.getReserves();
        }
        require(reserves > 0, "purchaseAsset::NLP");

        uint256 price = reserves.mul(pricePercentage).roundDiv(multiplier);
        fortunaToken.transferFrom(msg.sender, treasuryWallet, price);

        fortunaAssets.mintWithCheck(msg.sender, _assetToPurchase, 1, "");

        emit PurchasedAsset(
            msg.sender,
            _assetToPurchase,
            fortunaAssets.balanceOf(msg.sender, _assetToPurchase)
        );
    }

    function deployAsset(
        uint256 _assetToDeploy,
        uint8 _battleType
    ) external validBattleType(_battleType) validBattle(_battleType) {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        require(1 <= _assetToDeploy && _assetToDeploy <= 10, "deployAsset::WA");
        require(fortunaAssets.balanceOf(msg.sender, _assetToDeploy) > 0, "deployAsset::ANO");

        if (_assetToDeploy <= 5) {
            require(tempBattle.hero == 0, "deployAsset::HIB");

            tempBattle = battlingExtension.calculateRewards(tempBattle);

            if (tempBattle.currentToCollectPercentage.add(assetPercentages[_assetToDeploy - 1]) > 1000) {
                tempBattle.currentToCollectPercentage = 1000;
            }
            else {
                tempBattle.currentToCollectPercentage += assetPercentages[_assetToDeploy - 1];
            }

            tempBattle.hero = _assetToDeploy;
        }
        else {
            require(tempBattle.cavalry == 0, "deployAsset::CIB");

            tempBattle = battlingExtension.calculateRewards(tempBattle);

            tempBattle.currentRewardPercentagePerCycle = rewardPercentages[tempBattle.battleType - 1].mul(assetPercentages[_assetToDeploy - 1]).div(100).roundDiv(48);

            tempBattle.cavalry = _assetToDeploy;
        }

        fortunaAssets.safeTransferFromWithCheck(msg.sender, address(this), _assetToDeploy, 1, "");

        battleForAddress[msg.sender][_battleType] = tempBattle;
    }

    function endBattle(
        uint8 _battleType
    ) external {
        Battle memory tempBattle = battleForAddress[msg.sender][_battleType];

        require(2 <= _battleType && _battleType <= 6, "endBattle::WBT1");
        require(tempBattle.initialTokensStaked != 0, "endBattle:WB");

        if (_battleType == 2) {
            uint256 battleEndTime = uint256(30).mul(oneDayTime).add(tempBattle.battleStartTime);
            require(block.timestamp >= battleEndTime, "calculateRewardsForEndBattle::BNE");
        }

        tempBattle = battlingExtension.calculateRewardsForEndBattle(tempBattle);

        if (_battleType == 2) {
            LPToken.transfer(msg.sender, tempBattle.initialTokensStaked);

            uint256 rewardsToReturn = tempBattle.rewards.add(tempBattle.passiveRewards);

            uint256 rewardWalletBalance = fortunaToken.balanceOf(rewardWallet);

            bool isMint = rewardsToReturn > rewardWalletBalance;

            if (isMint) {
                if (rewardWalletBalance != 0) {
                    fortunaToken.transferFrom(rewardWallet, msg.sender, rewardWalletBalance);
                }

                fortunaToken.mint(msg.sender, rewardsToReturn.sub(rewardWalletBalance));
            }
            else {
                fortunaToken.transferFrom(rewardWallet, msg.sender, rewardsToReturn);
            }
        }
        else {
            uint256 tokensToReturn = tempBattle.initialTokensStaked.add(tempBattle.additionalTokens);

            uint256 rewardsToReturn = tempBattle.rewards.add(tempBattle.passiveRewards);

            uint256 rewardWalletBalance = fortunaToken.balanceOf(rewardWallet);

            bool isMint = rewardsToReturn > rewardWalletBalance;

            if (isMint) {
                if (rewardWalletBalance != 0) {
                    fortunaToken.transferFrom(rewardWallet, msg.sender, rewardWalletBalance);
                }

                fortunaToken.mint(msg.sender, rewardsToReturn.sub(rewardWalletBalance));
            }
            else {
                fortunaToken.transferFrom(rewardWallet, msg.sender, rewardsToReturn);
            }

            fortunaToken.transfer(msg.sender, tokensToReturn);

            if (tempBattle.hero != 0 || tempBattle.cavalry != 0) {
                uint256 chanceToLoseAssets = baseChanceToLoseAssets;

                if (tempBattle.battleDaysExpended >= 3) {
                    uint256 daysForDecrease = tempBattle.battleDaysExpended.sub(3);
                    if (daysForDecrease < tempBattle.rationsDaysTotal) {
                        daysForDecrease++;
                    }
                    uint256 chanceDecrease = daysForDecrease.mul(5);
                    chanceToLoseAssets = chanceToLoseAssets.safeSub(chanceDecrease);
                }

                if (chanceToLoseAssets != 0) {
                    tempBattle = _handleLoss(tempBattle, chanceToLoseAssets);
                }

                if (tempBattle.hero != 0) {
                    fortunaAssets.safeTransferFromWithCheck(address(this), msg.sender, tempBattle.hero, 1, "");
                }

                if (tempBattle.cavalry != 0) {
                    fortunaAssets.safeTransferFromWithCheck(address(this), msg.sender, tempBattle.cavalry, 1, "");
                }
            }
        }

        Battle memory emptyBattle;
        battleForAddress[msg.sender][_battleType] = emptyBattle;

        emit EndedBattle(
            msg.sender,
            _battleType,
            tempBattle.initialTokensStaked,
            tempBattle.additionalTokens,
            tempBattle.rewards,
            tempBattle.passiveRewards,
            tempBattle.battleStartTime,
            tempBattle.rationsDaysTotal.add(3)
        );
    }

    function _handleLoss(
        Battle memory _tempBattle,
        uint256 _chanceToLoseAssets
    ) internal returns (Battle memory) {
        bool isHeroLost;
        bool isCavalryLost;

        if (_tempBattle.hero != 0 && _tempBattle.cavalry != 0) {
            isHeroLost = battlingExtension.createRandomness(_chanceToLoseAssets, 100, _tempBattle.hero);
            isCavalryLost = battlingExtension.createRandomness(_chanceToLoseAssets, 100, _tempBattle.cavalry);
        }
        else if (_tempBattle.hero != 0) {
            isHeroLost = battlingExtension.createRandomness(_chanceToLoseAssets, 100, _tempBattle.hero);
        }
        else if (_tempBattle.cavalry != 0) {
            isCavalryLost = battlingExtension.createRandomness(_chanceToLoseAssets, 100, _tempBattle.cavalry);
        }

        if (isHeroLost) {
            fortunaAssets.burnWithCheck(address(this), _tempBattle.hero, 1);

            emit LostAsset(
                msg.sender,
                _tempBattle.hero,
                fortunaAssets.balanceOf(msg.sender, _tempBattle.hero)
            );

            _tempBattle.hero = 0;
        }

        if (isCavalryLost) {
            fortunaAssets.burnWithCheck(address(this), _tempBattle.cavalry, 1);

            emit LostAsset(
                msg.sender,
                _tempBattle.cavalry,
                fortunaAssets.balanceOf(msg.sender, _tempBattle.cavalry)
            );

            _tempBattle.cavalry = 0;
        }

        return _tempBattle;
    }

    function viewAllRewards(
        address _user
    ) external view returns (uint256[] memory, uint256[] memory, uint256[] memory) {
        uint256[] memory committedRewards = new uint256[](5);
        uint256[] memory potentialRewards = new uint256[](5);
        uint256[] memory passiveRewards = new uint256[](5);

        Battle memory tempBattle;

        for (uint8 i = 0 ; i < 5 ; i++) {
            tempBattle = battleForAddress[_user][i + 2];
            if (tempBattle.initialTokensStaked != 0) {
                if (
                    i == 0 &&
                    block.timestamp < tempBattle.battleStartTime.add(baseLockTime)
                ) {
                    potentialRewards[i] = battlingExtension.viewLockedRewards(
                        tempBattle.initialTokensStaked,
                        tempBattle.currentRewardPercentagePerCycle,
                        tempBattle.battleStartTime
                    );
                }
                else if (
                    i != 0 &&
                    block.timestamp < tempBattle.battleStartTime.add(baseBattleTime).add(tempBattle.rationsDaysTotal.mul(oneDayTime))
                ) {
                    committedRewards[i] = tempBattle.rewards;

                    tempBattle.currentToCollectPercentage = 1000;
                    tempBattle = battlingExtension.calculateRewards(tempBattle);

                    potentialRewards[i] = tempBattle.rewards.sub(committedRewards[i]);
                }
                else {
                    committedRewards[i] = tempBattle.rewards;

                    tempBattle.currentToCollectPercentage = 1000;
                    tempBattle = battlingExtension.calculateRewardsForEndBattle(tempBattle);

                    potentialRewards[i] = tempBattle.rewards.sub(committedRewards[i]);

                    passiveRewards[i] = tempBattle.passiveRewards;
                }
            }
        }

        return (committedRewards, potentialRewards, passiveRewards);
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
}