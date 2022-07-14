pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";

import "./ERC20.sol";
import "./FortunasLedger.sol";

import "./IPancakeFactory.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";

contract FortunasToken is ERC20, Ownable {
    using SafeMath for uint256;

    // BUSD mainnet
    // address public BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    // TODO remove
    address public BUSD;

    // PancakeSwap
    IPancakeRouter02 public pancakeRouter;
    address public immutable pancakePair;

    bool private transferring;

    // Ledger for all FRTNA holders
    FortunasLedger public fortunasLedger;

    // Battling contract address
    address public battling;

    // Liquidity wallet
    address public liquidityWallet;

    // Treasury wallet
    address public treasuryWallet;

    // Reward wallet
    address public rewardWallet;

    // Buy fees
    uint256 public liquidityBuyingFee;
    uint256 public treasuryBuyingFee;
    uint256 public burnBuyingFee;

    // Sell fees
    uint256 public liquiditySellingFee;
    uint256 public treasurySellingFee;
    uint256 public burnSellingFee;

    uint256 public maxBuyingFee;
    uint256 public maxSellingFee;
    uint256 public immutable multiplierForTotalFee;

    uint256 public totalSellingFeesAccumulated;

    // TODO confirm
    uint256 public transferTokensAtAmount = 1000 * (10**18);

    // TODO change
    // Timestamp for when the token can be traded freely on PanackeSwap
    uint256 public immutable tradingEnabledTimestamp = 1654041600; // June 1, 00:00 GMT, 2022

    // mappings

    // Addresses that are excluded from buying and selling fees
    mapping (address => bool) private isExcludedFromFees;

    // Addresses that are excluded from FRTNA holder's rewards
    mapping (address => bool) private isExcludedFromPassiveRewards;

    // Addresses that can make transfers before trading is enabled
    mapping (address => bool) private canTransferBeforeTradingIsEnabled;

    // Store addresses that are automatic market maker pairs
    mapping (address => bool) public automatedMarketMakerPairs;

    // events

    event UpdatePancakeRouter(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);

    event TreasuryWalletUpdated(address indexed newTreasuryWallet, address indexed oldTreasuryWallet);

    event RewardWalletUpdated(address indexed newRewardWallet, address indexed oldRewardWallet);

    event LedgerCreated(address indexed account, uint256 totalPassiveRewards, uint256 nextReward);

    event LedgerUpdated(address indexed account, uint256 totalPassiveRewards, uint256 nextReward);
    
    event LedgerClaimed(address indexed account, uint256 totalPassiveRewards, uint256 nextReward);

    // constructor

    constructor() ERC20("Fortunas Token", "FRTNA") {
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
        address _pancakePair = IPancakeFactory(_pancakeRouter.factory())
            .createPair(address(this), BUSD);

        pancakeRouter = _pancakeRouter;
        pancakePair = _pancakePair;

        _setAutomatedMarketMakerPair(_pancakePair, true);

        fortunasLedger = new FortunasLedger();

    	liquidityWallet = address(owner());

        // TODO change
        treasuryWallet = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;

        // TODO change
        rewardWallet = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;

        uint256 _liquidityBuyingFee = 25;
        uint256 _treasuryBuyingFee = 75;
        uint256 _burnBuyingFee = 0;

        uint256 _liquiditySellingFee = 50;
        uint256 _treasurySellingFee = 25;
        uint256 _burnSellingFee = 25;

        liquidityBuyingFee = _liquidityBuyingFee;
        treasuryBuyingFee = _treasuryBuyingFee;
        burnBuyingFee = _burnBuyingFee;

        liquiditySellingFee = _liquiditySellingFee;
        treasurySellingFee = _treasurySellingFee;
        burnSellingFee = _burnSellingFee;

        maxBuyingFee = _liquidityBuyingFee.add(_treasuryBuyingFee).add(_burnBuyingFee);
        maxSellingFee = _liquiditySellingFee.add(_treasurySellingFee).add(_burnSellingFee);

        multiplierForTotalFee = 10 ** 3;

        // exclude from receiving passive holding rewards
        excludeFromPassiveRewards(address(this), true);
        excludeFromPassiveRewards(liquidityWallet, true);
        excludeFromPassiveRewards(treasuryWallet, true);
        excludeFromPassiveRewards(rewardWallet, true);
        excludeFromPassiveRewards(_pancakePair, true);
        excludeFromPassiveRewards(address(0), true);

        // exclude from paying fees
        excludeFromFees(address(this), true);
        excludeFromFees(liquidityWallet, true);
        excludeFromFees(treasuryWallet, true);
        excludeFromFees(rewardWallet, true);

        // enable owner to send tokens before trading is enabled
        canTransferBeforeTradingIsEnabled[owner()] = true;

        // TODO mint to reward wallet
        // TODO change initial supply
        _mint(owner(), 1000000000 * (10 ** 18));
    }

    // getters and setters

    function initializeBattling(address contractAddress) external onlyOwner {
        // TODO uncomment
        // require(battling == address(0), "FRTNA: Battling has already been initialized");
        battling = contractAddress;

        excludeFromPassiveRewards(battling, true);

        excludeFromFees(battling, true);
    }

    function updateBuyingFees(uint256 _liquidityBuyingFee, uint256 _treasuryBuyingFee, uint256 _burnBuyingFee) public onlyOwner {
        uint256 totalInputFee = _liquidityBuyingFee.add(_treasuryBuyingFee).add(_burnBuyingFee);
        require(totalInputFee <= maxBuyingFee, "FRTNA: Cannot exceed total Buying fees");

        liquidityBuyingFee = _liquidityBuyingFee;
        treasuryBuyingFee = _treasuryBuyingFee;
        burnBuyingFee = _burnBuyingFee;
    }

    function updateSellingFees(uint256 _liquiditySellingFee, uint256 _treasurySellingFee, uint256 _burnSellingFee) public onlyOwner {
        uint256 totalInputFee = _liquiditySellingFee.add(_treasurySellingFee).add(_burnSellingFee);
        require(totalInputFee <= maxSellingFee, "FRTNA: Cannot exceed total selling fees");

        liquiditySellingFee = _liquiditySellingFee;
        treasurySellingFee = _treasurySellingFee;
        burnSellingFee = _burnSellingFee;
    }

    function updatePancakeRouter(address newAddress) public onlyOwner {
        require(newAddress != address(pancakeRouter), "FRTNA: The router already has that address");
        emit UpdatePancakeRouter(newAddress, address(pancakeRouter));
        pancakeRouter = IPancakeRouter02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "FRTNA: Account is already the value of 'excluded'");
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function excludeFromPassiveRewards(address account, bool excluded) public onlyOwner {
        require(isExcludedFromPassiveRewards[account] != excluded, "FRTNA: Account is already the value of 'excluded'");

        isExcludedFromPassiveRewards[account] = excluded;
    }

    function excludeMultipleAccountsFromPassiveRewards(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromPassiveRewards[accounts[i]] = excluded;
        }
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != pancakePair, "FRTNA: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "FRTNA: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateLiquidityWallet(address newLiquidityWallet) public onlyOwner {
        require(newLiquidityWallet != liquidityWallet, "FRTNA: The liquidity wallet is already this address");
        excludeFromFees(liquidityWallet, false);
        excludeFromFees(newLiquidityWallet, true);
        emit LiquidityWalletUpdated(newLiquidityWallet, liquidityWallet);
        liquidityWallet = newLiquidityWallet;
    }

    function updateTreasuryWallet(address newTreasuryWallet) public onlyOwner {
        require(newTreasuryWallet != treasuryWallet, "FRTNA: The treasury wallet is already this address");
        excludeFromFees(treasuryWallet, false);
        excludeFromFees(newTreasuryWallet, true);
        emit TreasuryWalletUpdated(newTreasuryWallet, treasuryWallet);
        treasuryWallet = newTreasuryWallet;
    }

    function updateRewardWallet(address newRewardWallet) public onlyOwner {
        require(newRewardWallet != rewardWallet, "FRTNA: The staking wallet is already this address");
        excludeFromFees(rewardWallet, false);
        excludeFromFees(newRewardWallet, true);
        emit RewardWalletUpdated(newRewardWallet, rewardWallet);
        rewardWallet = newRewardWallet;
    }

    function getTradingIsEnabled() public view returns (bool) {
        return block.timestamp >= tradingEnabledTimestamp;
    }

    // functions

    function _isBuy(address from) internal view returns (bool) {
        // Transfer from pair is a buy swap
        return automatedMarketMakerPairs[from];
    }

    function _isSell(address from, address to) internal view returns (bool) {
        // Transfer to pair from non-router address is a sell swap
        return from != address(pancakeRouter) && automatedMarketMakerPairs[to];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        bool tradingIsEnabled = getTradingIsEnabled();

        if (!tradingIsEnabled) {
            require(canTransferBeforeTradingIsEnabled[from], "FRTNA: This account cannot send tokens until trading is enabled");
        }

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canTransfer = contractTokenBalance >= transferTokensAtAmount;

        if (
            tradingIsEnabled &&
            canTransfer &&
            !transferring &&
            !_isBuy(from) &&
            from != liquidityWallet &&
            to != liquidityWallet
        ) {
            transferring = true;

            uint256 totalBuyingFeesAccumulated = contractTokenBalance;
            uint256 toLiquidityAmount;
            uint256 toTreasuryAmount;
            uint256 toBurnAmount;

            if (totalSellingFeesAccumulated > 0) {
                totalBuyingFeesAccumulated -= totalSellingFeesAccumulated;

                toLiquidityAmount += totalSellingFeesAccumulated
                    .mul(liquiditySellingFee).div(100);

                toTreasuryAmount += totalSellingFeesAccumulated
                    .mul(treasurySellingFee).div(100);

                toBurnAmount += totalSellingFeesAccumulated
                    .mul(burnSellingFee).div(100);

                totalSellingFeesAccumulated = 0;
            }

            if (totalBuyingFeesAccumulated > 0) {
                toLiquidityAmount += totalBuyingFeesAccumulated
                    .mul(liquidityBuyingFee).div(100);
                
                toTreasuryAmount += totalBuyingFeesAccumulated
                    .mul(treasuryBuyingFee).div(100);

                toBurnAmount += totalBuyingFeesAccumulated
                    .mul(burnBuyingFee).div(100);
            }

            super._transfer(address(this), liquidityWallet, toLiquidityAmount);

            super._transfer(address(this), treasuryWallet, toTreasuryAmount);

            _burn(address(this), toBurnAmount);

            transferring = false;
        }

        if (
            _isBuy(from) &&
            !isExcludedFromFees[to]
        ) {
            uint256 totalBuyingFee = liquidityBuyingFee.add(treasuryBuyingFee).add(burnBuyingFee);

            uint256 buyingFee = amount.mul(totalBuyingFee).div(multiplierForTotalFee);
            amount -= buyingFee;

            super._transfer(from, address(this), buyingFee);
        }

        if (
            _isSell(from, to) &&
            !isExcludedFromFees[from]
        ) {
            uint256 totalSellingFee = liquiditySellingFee.add(treasurySellingFee).add(burnSellingFee);

            uint256 sellingFee = amount.mul(totalSellingFee).div(multiplierForTotalFee);
            totalSellingFeesAccumulated += sellingFee;
            amount -= sellingFee;

            super._transfer(from, address(this), sellingFee);
        }

        super._transfer(from, to, amount);

        if (!isExcludedFromPassiveRewards[from]) {
            _updateLedger(from);
        }
 
        if (!isExcludedFromPassiveRewards[to]) {
            _updateLedger(to);
        }
    }

    function updateLedger(address account) external {
        require(!isExcludedFromPassiveRewards[account], "FRTNA: Account is excluded from passive rewards");

        _updateLedger(account);
    }

    function _updateLedger(address account) internal {
        (uint256 totalPassiveRewards, bool isFirstTransaction) =
            fortunasLedger.updatePassiveRewards(account, balanceOf(account));

        uint256 nextPassiveReward =
            fortunasLedger.calculateNextPassiveReward(account, balanceOf(account));

        if (isFirstTransaction) {
            emit LedgerCreated(
                account,
                totalPassiveRewards,
                nextPassiveReward
            );

            return;
        }

        emit LedgerUpdated(
            account,
            totalPassiveRewards,
            nextPassiveReward
        );
    }

    function claimLedger() external {
        require(!isExcludedFromPassiveRewards[msg.sender], "FRTNA: Account is excluded from passive rewards");

        (uint256 totalPassiveRewards, uint256 nextPassiveReward) =
            fortunasLedger.claimPassiveRewards(msg.sender, balanceOf(msg.sender));

        if (totalPassiveRewards == 0) {
            require(false, "FRTNA: No rewards to claim");
        }

        uint256 rewardWalletBalance = balanceOf(rewardWallet);

        bool isMint = totalPassiveRewards > rewardWalletBalance;

        if (isMint) {
            if (rewardWalletBalance != 0) {
                _transfer(rewardWallet, msg.sender, rewardWalletBalance);
            }

            _mint(msg.sender, totalPassiveRewards.sub(rewardWalletBalance));
        }
        else {
            _transfer(rewardWallet, msg.sender, totalPassiveRewards);
        }

        emit LedgerClaimed(
            msg.sender,
            0,
            nextPassiveReward
        );
    }

    function viewLedger(address account) external view returns (uint256, uint256) {
        require(!isExcludedFromPassiveRewards[account], "FRTNA: Account is excluded from passive rewards");

        (uint256 totalPassiveRewards, uint256 nextPassiveReward) =
            fortunasLedger.getCurrentLedgerStatus(account, balanceOf(account));

        return (totalPassiveRewards, nextPassiveReward);
    }

    function mint(address account, uint256 amount) external onlyContract {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyContract {
        _burn(account, amount);
    }

    function circulatingSupply() external view returns (uint256) {
        uint256 lockedSupply = balanceOf(liquidityWallet).add(balanceOf(treasuryWallet)).add(balanceOf(rewardWallet));
        return totalSupply().sub(lockedSupply);
    }

    modifier onlyContract {
        require(msg.sender == battling, "FRTNA: Only Fortunas Battling Contract can call this function");
        _;
    }
}