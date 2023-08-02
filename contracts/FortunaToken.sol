pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";

import "./ERC20.sol";
import "./FortunaLedger.sol";

import "./IPancakeFactory.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";

contract FortunaToken is ERC20, Ownable {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    // BUSD mainnet
    address public BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    // PancakeSwap
    IPancakeRouter02 public pancakeRouter;
    address public immutable pancakePair;

    bool private transferring;

    // Ledger for all FRTNA holders
    FortunaLedger public fortunaLedger;

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
    uint256 public multiplierForTotalFee;

    uint256 public totalSellingFeesAccumulated;

    uint256 public transferTokensAtAmount = 1000 * (10**18);

    // mappings

    // Addresses that are excluded from buying and selling fees
    mapping (address => bool) private isExcludedFromFees;

    // Addresses that are excluded from FRTNA holder's rewards
    mapping (address => bool) private isExcludedFromPassiveRewards;

    // Store addresses that are automatic market maker pairs
    mapping (address => bool) public automatedMarketMakerPairs;

    // events

    event UpdatedBuyingFees(uint256 newLiquidityBuyingFee, uint256 newTreasuryBuyingFee, uint256 newBurnBuyingFee);
    
    event UpdatedSellingFees(uint256 newLiquiditySellingFee, uint256 newTreasurySellingFee, uint256 newBurnSellingFee);

    event UpdatedPancakeRouter(address indexed newAddress, address indexed oldAddress);

    event ExcludedFromFees(address indexed account, bool isExcluded);

    event ExcludedMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event ExcludedFromPassiveRewards(address indexed account, bool isExcluded);

    event ExcludedMultipleAccountsFromPassiveRewards(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event UpdatedLiquidityWallet(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);

    event UpdatedTreasuryWallet(address indexed newTreasuryWallet, address indexed oldTreasuryWallet);

    event UpdatedRewardWallet(address indexed newRewardWallet, address indexed oldRewardWallet);

    event CreatedLedger(address indexed account);

    event ClaimedLedger(address indexed account, uint256 totalPassiveRewards);

    // constructor

    constructor() ERC20("Fortuna", "FRTNA") {
        // PancakeRouter02 mainnet
    	IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address _pancakePair = IPancakeFactory(_pancakeRouter.factory())
            .createPair(address(this), BUSD);

        pancakeRouter = _pancakeRouter;
        pancakePair = _pancakePair;

        _setAutomatedMarketMakerPair(_pancakePair, true);

        fortunaLedger = new FortunaLedger();

    	liquidityWallet = address(owner());

        treasuryWallet = 0x8E98A208b3128066b8e1BA46BD8e34Dc09F8bf4f;

        rewardWallet = 0x6429B65da9EEE43ECE3771c5A840145fddcd95bd;

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
        excludeFromPassiveRewards(address(_pancakeRouter), true);
        excludeFromPassiveRewards(liquidityWallet, true);
        excludeFromPassiveRewards(treasuryWallet, true);
        excludeFromPassiveRewards(rewardWallet, true);
        excludeFromPassiveRewards(address(0), true);

        // exclude from paying fees
        excludeFromFees(address(this), true);
        excludeFromFees(liquidityWallet, true);
        excludeFromFees(treasuryWallet, true);
        excludeFromFees(rewardWallet, true);

        _mint(rewardWallet, 50000000 * (10 ** 18));
    }

    // getters and setters

    function initializeBattling(address battlingContractAddress) external onlyOwner {
        require(battling == address(0), "FRTNA::Battling has already been initialized");
        battling = battlingContractAddress;

        excludeFromPassiveRewards(battling, true);

        excludeFromFees(battling, true);
    }

    function updateBuyingFees(uint256 newLiquidityBuyingFee, uint256 newTreasuryBuyingFee, uint256 newBurnBuyingFee) public onlyOwner {
        uint256 totalInputFee = newLiquidityBuyingFee.add(newTreasuryBuyingFee).add(newBurnBuyingFee);
        require(totalInputFee <= maxBuyingFee, "FRTNA::Cannot exceed total Buying fees");

        liquidityBuyingFee = newLiquidityBuyingFee;
        treasuryBuyingFee = newTreasuryBuyingFee;
        burnBuyingFee = newBurnBuyingFee;

        emit UpdatedBuyingFees(newLiquidityBuyingFee, newTreasuryBuyingFee, newBurnBuyingFee);
    }

    function updateSellingFees(uint256 newLiquiditySellingFee, uint256 newTreasurySellingFee, uint256 newBurnSellingFee) public onlyOwner {
        uint256 totalInputFee = newLiquiditySellingFee.add(newTreasurySellingFee).add(newBurnSellingFee);
        require(totalInputFee <= maxSellingFee, "FRTNA::Cannot exceed total selling fees");

        liquiditySellingFee = newLiquiditySellingFee;
        treasurySellingFee = newTreasurySellingFee;
        burnSellingFee = newBurnSellingFee;

        emit UpdatedSellingFees(newLiquiditySellingFee, newTreasurySellingFee, newBurnSellingFee);
    }

    function updatePancakeRouter(address router) public onlyOwner {
        require(router != address(pancakeRouter), "FRTNA::The router already has that address");
        emit UpdatedPancakeRouter(router, address(pancakeRouter));
        pancakeRouter = IPancakeRouter02(router);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "FRTNA::Account is already the value of 'excluded'");
        isExcludedFromFees[account] = excluded;

        emit ExcludedFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludedMultipleAccountsFromFees(accounts, excluded);
    }

    function excludeFromPassiveRewards(address account, bool excluded) public onlyOwner {
        require(isExcludedFromPassiveRewards[account] != excluded, "FRTNA::Account is already the value of 'excluded'");

        isExcludedFromPassiveRewards[account] = excluded;

        emit ExcludedFromPassiveRewards(account, excluded);
    }

    function excludeMultipleAccountsFromPassiveRewards(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromPassiveRewards[accounts[i]] = excluded;
        }

        emit ExcludedMultipleAccountsFromPassiveRewards(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != pancakePair, "FRTNA::The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "FRTNA::Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        if (automatedMarketMakerPairs[pair]) {
            excludeFromPassiveRewards(pair, true);
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateLiquidityWallet(address newLiquidityWallet) public onlyOwner {
        require(newLiquidityWallet != liquidityWallet, "FRTNA::The liquidity wallet is already this address");
        excludeFromFees(liquidityWallet, false);
        excludeFromFees(newLiquidityWallet, true);
        emit UpdatedLiquidityWallet(newLiquidityWallet, liquidityWallet);
        liquidityWallet = newLiquidityWallet;
    }

    function updateTreasuryWallet(address newTreasuryWallet) public onlyOwner {
        require(newTreasuryWallet != treasuryWallet, "FRTNA::The treasury wallet is already this address");
        excludeFromFees(treasuryWallet, false);
        excludeFromFees(newTreasuryWallet, true);
        emit UpdatedTreasuryWallet(newTreasuryWallet, treasuryWallet);
        treasuryWallet = newTreasuryWallet;
    }

    function updateRewardWallet(address newRewardWallet) public onlyOwner {
        require(newRewardWallet != rewardWallet, "FRTNA::The staking wallet is already this address");
        excludeFromFees(rewardWallet, false);
        excludeFromFees(newRewardWallet, true);
        emit UpdatedRewardWallet(newRewardWallet, rewardWallet);
        rewardWallet = newRewardWallet;
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
        require(from != address(0), "ERC20::transfer from the zero address");
        require(to != address(0), "ERC20::transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canTransfer = contractTokenBalance >= transferTokensAtAmount;

        if (
            canTransfer &&
            !transferring &&
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
                    .mul(liquiditySellingFee).roundDiv(100);
                toTreasuryAmount += totalSellingFeesAccumulated
                    .mul(treasurySellingFee).roundDiv(100);
                toBurnAmount += totalSellingFeesAccumulated
                    .mul(burnSellingFee).roundDiv(100);
                totalSellingFeesAccumulated = 0;
            }
            if (totalBuyingFeesAccumulated > 0) {
                toLiquidityAmount += totalBuyingFeesAccumulated
                    .mul(liquidityBuyingFee).roundDiv(100);
                toTreasuryAmount += totalBuyingFeesAccumulated
                    .mul(treasuryBuyingFee).roundDiv(100);
                toBurnAmount += totalBuyingFeesAccumulated
                    .mul(burnBuyingFee).roundDiv(100);
            }
            super._transfer(address(this), liquidityWallet, toLiquidityAmount);
            super._transfer(address(this), treasuryWallet, toTreasuryAmount);
            _burn(address(this), toBurnAmount);

            transferring = false;
        }
        if (_isBuy(from) && !isExcludedFromFees[to]) {
            uint256 totalBuyingFee = liquidityBuyingFee.add(treasuryBuyingFee).add(burnBuyingFee);
            uint256 buyingFee = amount.mul(totalBuyingFee).div(multiplierForTotalFee);
            amount -= buyingFee;
            super._transfer(from, address(this), buyingFee);
        }
        if (_isSell(from, to) && !isExcludedFromFees[from]) {
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
        require(balanceOf(account) > 0, "FRTNA::Insufficient balance");
        require(!isExcludedFromPassiveRewards[account], "FRTNA::Account is excluded from passive rewards");
        _updateLedger(account);
    }

    function _updateLedger(address account) internal {
        (, bool isFirstTransaction) =
            fortunaLedger.updatePassiveRewards(account, balanceOf(account));

        if (isFirstTransaction) emit CreatedLedger(account);
    }

    function claimLedger() external {
        require(!isExcludedFromPassiveRewards[msg.sender], "FRTNA::Account is excluded from passive rewards");
        uint256 totalPassiveRewards =
            fortunaLedger.claimPassiveRewards(msg.sender, balanceOf(msg.sender));

        require(totalPassiveRewards > 0, "FRTNA::No rewards to claim");
        uint256 rewardWalletBalance = balanceOf(rewardWallet);
        bool isMint = totalPassiveRewards > rewardWalletBalance;

        if (isMint) {
            if (rewardWalletBalance != 0) {
                _transfer(rewardWallet, msg.sender, rewardWalletBalance);
            }
            _mint(msg.sender, totalPassiveRewards.sub(rewardWalletBalance));
        } else {
            _transfer(rewardWallet, msg.sender, totalPassiveRewards);
        }

        emit ClaimedLedger(msg.sender, totalPassiveRewards);
    }

    function viewLedger(address account) external view returns (uint256) {
        require(!isExcludedFromPassiveRewards[account], "FRTNA::Account is excluded from passive rewards");

        uint256 totalPassiveRewards =
            fortunaLedger.getCurrentLedgerStatus(account, balanceOf(account));

        return totalPassiveRewards;
    }

    function mint(address account, uint256 amount) external onlyContract {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyContract {
        _burn(account, amount);
    }

    // modifiers

    modifier onlyContract {
        require(msg.sender == battling, "FRTNA::Only Fortuna Battling Contract can call this function");
        _;
    }
}