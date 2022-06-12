pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC20.sol";
import "./IPancakeFactory.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";
import "./FortunasLedger.sol";

contract FortunasToken is ERC20, Ownable {
    using SafeMath for uint256;

    address public battlingContractAddress;

    IPancakeRouter02 public pancakeRouter;
    address public immutable pancakePair;

    bool private swapping;

    // BUSD mainnet
    // address public BUSD =
    //     address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    // BUSD testnet (TestnetERC20Token)
    address public BUSD =
        address(0x7D9385C733a967793EE14D933212ee44025f1B9d);

    // Bookkeeper for all FRTNA holders
    FortunasLedger public fortunasLedger;
    
    address public liquidityWallet;
    address public treasuryWallet;

    // buy fees
    uint256 public liquidityBuyingFee;
    uint256 public treasuryBuyingFee;
    uint256 public burnBuyingFee;

    // sell fees
    uint256 public liquiditySellingFee;
    uint256 public treasurySellingFee;
    uint256 public burnSellingFee;

    uint256 public totalBuyingFee;
    uint256 public totalSellingFee;
    uint256 public immutable multiplierForFee;

    uint256 public totalSellingFeesAccumulated;

    uint256 public transferTokensAtAmount = 10000 * (10**18);

    // timestamp for when the token can be traded freely on PanackeSwap
    uint256 public immutable tradingEnabledTimestamp = 1623967200; //June 17, 22:00 UTC, 2021

    // mappings

    // exlcude from fees
    mapping (address => bool) private isExcludedFromFees;

    // exclude from FRTNA holder's rewards
    mapping (address => bool) private isExcludedFromPassiveRewards;

    // addresses that can make transfers before trading is enabled
    mapping (address => bool) private canTransferBeforeTradingIsEnabled;

    // store addresses that are automatic market maker pairs
    mapping (address => bool) public automatedMarketMakerPairs;

    // events

    event UpdatePancakeRouter(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);

    event TreasuryWalletUpdated(address indexed newTreasuryWallet, address indexed oldTreasuryWallet);

    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);

    event LedgerCreated(address indexed account, uint256 totalPassiveRewards, uint256 nextReward);

    event LedgerUpdated(address indexed account, uint256 totalPassiveRewards, uint256 nextReward);
    
    event LedgerClaimed(address indexed account, uint256 totalPassiveRewards, uint256 nextReward);

    // constructor

    constructor() ERC20("Fortunas Token", "FRTNA") {
        fortunasLedger = new FortunasLedger();

        // TODO
    	liquidityWallet = address(owner());
        treasuryWallet = address(0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80);

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

        totalBuyingFee = _liquidityBuyingFee.add(_treasuryBuyingFee).add(_burnBuyingFee);
        totalSellingFee = _liquiditySellingFee.add(_treasurySellingFee).add(_burnSellingFee);

        multiplierForFee = 10 ** 3;

        // PancakeRouter02 mainnet
    	// IPancakeRouter02 _pancakeRouter = IPancakeRouter02(address(0));
        // PancakeRouter02 testnet
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
        address _pancakePair = IPancakeFactory(_pancakeRouter.factory())
            .createPair(address(this), BUSD);

        pancakeRouter = _pancakeRouter;
        pancakePair = _pancakePair;

        _setAutomatedMarketMakerPair(_pancakePair, true);

        // exclude from receiving rewards
        excludeFromPassiveRewards(address(this), true);
        excludeFromPassiveRewards(liquidityWallet, true);
        excludeFromPassiveRewards(treasuryWallet, true);
        excludeFromPassiveRewards(_pancakePair, true);
        excludeFromPassiveRewards(address(0), true);

        // exclude from paying fees
        excludeFromFees(address(this), true);
        excludeFromFees(liquidityWallet, true);
        excludeFromFees(treasuryWallet, true);

        // enable owner to send tokens before trading is enabled
        canTransferBeforeTradingIsEnabled[owner()] = true;

        _mint(owner(), 1000000000 * (10 ** 18));
    }

    // getters and setters

    function setAssociatedContracts(address _battlingContractAddress/*, address _lotteryContractAddress*/) external onlyOwner {
        battlingContractAddress = _battlingContractAddress;

        excludeFromPassiveRewards(_battlingContractAddress, true);
        // excludeFromPassiveRewards(_lotteryContractAddress, true);

        excludeFromFees(_battlingContractAddress, true);
        // excludeFromFees(_lotteryContractAddress, true);
    }

    function updateBuyFee(uint256 _liquidityBuyingFee, uint256 _treasuryBuyingFee, uint256 _burnBuyingFee) public onlyOwner {
        require(_liquidityBuyingFee.add(_treasuryBuyingFee).add(_burnBuyingFee) == totalBuyingFee,
            "FRTNA: Cannot exceed total selling fees");

        liquidityBuyingFee = _liquidityBuyingFee;
        treasuryBuyingFee = _treasuryBuyingFee;
        burnBuyingFee = _burnBuyingFee;
    }

    function updateSellingFee(uint256 _liquiditySellingFee, uint256 _treasurySellingFee, uint256 _burnSellingFee) public onlyOwner {
        require(_liquiditySellingFee.add(_treasurySellingFee).add(_burnSellingFee) == totalSellingFee,
            "FRTNA: Cannot exceed total selling fees");

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

        if (!isExcludedFromPassiveRewards[from]) {
            updateLedger(from);
        }
        
        if (!isExcludedFromPassiveRewards[to]) {
            updateLedger(to);
        }

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= transferTokensAtAmount;

        if (
            tradingIsEnabled &&
            canSwap &&
            !swapping &&
            !_isBuy(from) &&
            from != liquidityWallet &&
            to != liquidityWallet
        ) {
            uint256 totalBuyingFeesAccumulated = contractTokenBalance;
            uint256 toLiquidityAmount;
            uint256 toTreasuryAmount;
            uint256 toBurnAmount;

            if (totalSellingFeesAccumulated > 0) {
                totalBuyingFeesAccumulated -= totalSellingFeesAccumulated;

                toLiquidityAmount = totalSellingFeesAccumulated
                    .mul(liquiditySellingFee)
                    .div(multiplierForFee);
                swapAndLiquify(toLiquidityAmount);

                toTreasuryAmount = totalSellingFeesAccumulated
                    .mul(treasurySellingFee)
                    .div(multiplierForFee);
                super._transfer(address(this), treasuryWallet, toTreasuryAmount);

                toBurnAmount = totalSellingFeesAccumulated
                    .mul(burnSellingFee)
                    .div(multiplierForFee);
                _burn(address(this), toBurnAmount);

                totalSellingFeesAccumulated = 0;
            }
            
            if (totalBuyingFeesAccumulated > 0) {
                toLiquidityAmount = totalBuyingFeesAccumulated
                    .mul(liquidityBuyingFee)
                    .div(multiplierForFee);
                swapAndLiquify(toLiquidityAmount);

                toTreasuryAmount = totalBuyingFeesAccumulated
                    .mul(treasuryBuyingFee)
                    .div(multiplierForFee);
                super._transfer(address(this), treasuryWallet, toTreasuryAmount);

                toBurnAmount = totalBuyingFeesAccumulated
                    .mul(burnBuyingFee)
                    .div(multiplierForFee);
                _burn(address(this), toBurnAmount);
            }
        }

        if (
            _isBuy(from) &&
            !isExcludedFromFees[to]
        ) {
            uint256 buyingFee = amount.mul(totalBuyingFee).div(multiplierForFee);
            amount -= buyingFee;

            super._transfer(from, address(this), buyingFee);
        }

        if (
            _isSell(from, to) &&
            !isExcludedFromFees[from]
        ) {
            uint256 sellingFee = amount.mul(totalSellingFee).div(multiplierForFee);
            totalSellingFeesAccumulated += sellingFee;
            amount -= sellingFee;

            super._transfer(from, address(this), sellingFee);
        }

        super._transfer(from, to, amount);
    }

    function swapAndLiquify(uint256 tokens) private {
        // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        _approve(address(this), address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp.add(1800)
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeRouter), tokenAmount);

        // add the liquidity
        pancakeRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityWallet,
            block.timestamp.add(1800)
        );
    }

    function claimLedger() external {
        require(!isExcludedFromPassiveRewards[msg.sender], "FRTNA: Account is excluded from passive rewards");

        (uint256 totalPassiveRewards, uint256 nextPassiveReward) =
            fortunasLedger.claimPassiveRewards(msg.sender, balanceOf(msg.sender));

        if (totalPassiveRewards == 0) {
            require(false, "FRTNA: No rewards to claim");
        }

        _mint(msg.sender, totalPassiveRewards);

        emit LedgerClaimed(
            msg.sender,
            totalPassiveRewards,
            nextPassiveReward
        );
    }

    function updateLedger(address account) internal {
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

    function viewLedger(address account) external view returns (uint256, uint256) {
        require(!isExcludedFromPassiveRewards[account], "FRTNA: Account is excluded from passive rewards");

        (uint256 totalPassiveRewards, uint256 nextPassiveReward) =
            fortunasLedger.getPassiveRewards(account, balanceOf(account));

        return (totalPassiveRewards, nextPassiveReward);
    }

    function mint(address account, uint256 amount) external onlyContract {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    modifier onlyContract {
        require(msg.sender == battlingContractAddress, "FRTNA: Only Fortunas Battling Contract can call this function");
        _;
    }

    receive() external payable {

  	}
}