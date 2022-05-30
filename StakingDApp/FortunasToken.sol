pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./DividendPayingToken.sol";
import "./IPancakeFactory.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";

contract FortunasToken is ERC20, Ownable {
    using SafeMath for uint256;

    IPancakeRouter02 public pancakeRouter;
    // address public immutable pancakePair;
    address public pancakePair;

    address public immutable bounceFixedSaleWallet;

    bool private swapping;

    address public BUSD =
        address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); //BUSD

    FRTNADividendTracker public dividendTracker;

    address public liquidityWallet;
    address public treasuryWallet;

    uint256 public maxSellTransactionAmount = 1000000 * (10**18);
    uint256 public swapTokensAtAmount = 200000 * (10**18);

    // buy fees
    uint256 public immutable liquidityFeeBuy;
    uint256 public immutable treasuryFeeBuy;

    // sell fees
    uint256 public immutable liquidityFeeSell;
    uint256 public immutable treasuryFeeSell;

    uint256 public sellFeeTotalAmount;
    
    uint256 public immutable totalFees;
    uint256 public immutable multiplierForFees;

    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;


    /*   Fixed Sale   */

    // timestamp for when purchases on the fixed-sale are available to early participants
    uint256 public immutable fixedSaleStartTimestamp = 1623960000; //June 17, 20:00 UTC, 2021

    // the fixed-sale will be open to the public 10 minutes after fixedSaleStartTimestamp,
    // or after 600 buys, whichever comes first.
    uint256 public immutable fixedSaleEarlyParticipantDuration = 600;
    uint256 public immutable fixedSaleEarlyParticipantBuysThreshold = 600;

    // track number of buys. once this reaches fixedSaleEarlyParticipantBuysThreshold,
    // the fixed-sale will be open to the public even if it's still in the first 10 minutes
    uint256 public numberOfFixedSaleBuys;
    // track who has bought
    mapping (address => bool) public fixedSaleBuyers;


    /******************/

    // timestamp for when the token can be traded freely on PanackeSwap
    uint256 public immutable tradingEnabledTimestamp = 1623967200; //June 17, 22:00 UTC, 2021

    // exlcude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;

    // addresses that can make transfers before presale is over
    mapping (address => bool) private canTransferBeforeTradingIsEnabled;

    mapping (address => bool) public fixedSaleEarlyParticipants;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    event UpdateDividendTracker(address indexed newAddress, address indexed oldAddress);

    event UpdatepancakeRouter(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event FixedSaleEarlyParticipantsAdded(address[] participants);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);

    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event FixedSaleBuy(address indexed account, uint256 indexed amount, bool indexed earlyParticipant, uint256 numberOfBuyers);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SendDividends(
    	uint256 tokensSwapped,
    	uint256 amount
    );

    event ProcessedDividendTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );

    constructor() ERC20("Fortunas Token", "FRTNA") {
        uint256 _liquidityFeeBuy = 25;
        uint256 _treasuryFeeBuy = 75;

        uint256 _liquidityFeeSell = 75;
        uint256 _treasuryFeeSell = 25;

        treasuryFeeBuy = _treasuryFeeBuy;
        liquidityFeeBuy = _liquidityFeeBuy;

        liquidityFeeSell = _liquidityFeeSell;
        treasuryFeeSell = _treasuryFeeSell;

        totalFees = _treasuryFeeBuy.add(_liquidityFeeBuy);

        multiplierForFees = 1000;

    	dividendTracker = new FRTNADividendTracker(address(this));

    	liquidityWallet = owner();


    	// IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        // address _pancakePair = IPancakeFactory(_pancakeRouter.factory())
        //     .createPair(address(this), BUSD);

        // pancakeRouter = _pancakeRouter;
        // pancakePair = _pancakePair;

        // _setAutomatedMarketMakerPair(_pancakePair, true);

        address _bounceFixedSaleWallet = 0x4Fc4bFeDc5c82644514fACF716C7F888a0C73cCc;
        bounceFixedSaleWallet = _bounceFixedSaleWallet;

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(owner());
        // dividendTracker.excludeFromDividends(address(_pancakeRouter));
        dividendTracker.excludeFromDividends(_bounceFixedSaleWallet);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(liquidityWallet, true);
        excludeFromFees(address(this), true);

        // enable owner and fixed-sale wallet to send tokens before presales are over
        canTransferBeforeTradingIsEnabled[owner()] = true;
        canTransferBeforeTradingIsEnabled[_bounceFixedSaleWallet] = true;

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1000000000 * (10**18));
    }

    receive() external payable {

  	}

    function setBattling(address _battlingContractAddress) external onlyOwner {
        dividendTracker.excludeFromDividends(_battlingContractAddress);
        excludeFromFees(_battlingContractAddress, true);
        // TODO
        _mint(_battlingContractAddress, 100 * (10**18));
    }

    function updateDividendTracker(address newAddress) public onlyOwner {
        require(newAddress != address(dividendTracker), "FRTNA: The dividend tracker already has that address");

        FRTNADividendTracker newDividendTracker = FRTNADividendTracker(payable(newAddress));

        require(newDividendTracker.owner() == address(this), "FRTNA: The new dividend tracker must be owned by the FRTNA token contract");

        newDividendTracker.excludeFromDividends(address(newDividendTracker));
        newDividendTracker.excludeFromDividends(address(this));
        newDividendTracker.excludeFromDividends(owner());
        newDividendTracker.excludeFromDividends(address(pancakeRouter));

        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    function updatepancakeRouter(address newAddress) public onlyOwner {
        require(newAddress != address(pancakeRouter), "FRTNA: The router already has that address");
        emit UpdatepancakeRouter(newAddress, address(pancakeRouter));
        pancakeRouter = IPancakeRouter02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "FRTNA: Account is already the value of 'excluded'");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function addFixedSaleEarlyParticipants(address[] calldata accounts) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            fixedSaleEarlyParticipants[accounts[i]] = true;
        }

        emit FixedSaleEarlyParticipantsAdded(accounts);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != pancakePair, "FRTNA: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "FRTNA: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        if(value) {
            dividendTracker.excludeFromDividends(pair);
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }


    function updateLiquidityWallet(address newLiquidityWallet) public onlyOwner {
        require(newLiquidityWallet != liquidityWallet, "FRTNA: The liquidity wallet is already this address");
        excludeFromFees(newLiquidityWallet, true);
        emit LiquidityWalletUpdated(newLiquidityWallet, liquidityWallet);
        liquidityWallet = newLiquidityWallet;
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue >= 200000 && newValue <= 500000, "FRTNA: gasForProcessing must be between 200,000 and 500,000");
        require(newValue != gasForProcessing, "FRTNA: Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns(uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account) public view returns(uint256) {
    	return dividendTracker.withdrawableDividendOf(account);
  	}

	function dividendTokenBalanceOf(address account) public view returns (uint256) {
		return dividendTracker.balanceOf(account);
	}

    function getAccountDividendsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return dividendTracker.getAccount(account);
    }

	function getAccountDividendsInfoAtIndex(uint256 index)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	return dividendTracker.getAccountAtIndex(index);
    }

	function processDividendTracker(uint256 gas) external {
		(uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = dividendTracker.process(gas);
		emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
    }

    function claim() external {
		dividendTracker.processAccount(payable(msg.sender), false);
    }

    function getLastProcessedIndex() external view returns(uint256) {
    	return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns(uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function getTradingIsEnabled() public view returns (bool) {
        return block.timestamp >= tradingEnabledTimestamp;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        bool tradingIsEnabled = getTradingIsEnabled();

        // only whitelisted addresses can make transfers after the fixed-sale has started
        // and before the public presale is over
        if(!tradingIsEnabled) {
            require(canTransferBeforeTradingIsEnabled[from], "FRTNA: This account cannot send tokens until trading is enabled");
        }

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        bool isFixedSaleBuy = from == bounceFixedSaleWallet && to != owner();

        // the fixed-sale can only send tokens to the owner or early participants of the fixed sale in the first 10 minutes,
        // or 600 transactions, whichever is first.
        if(isFixedSaleBuy) {
            require(block.timestamp >= fixedSaleStartTimestamp, "FRTNA: The fixed-sale has not started yet.");

            bool openToEveryone = block.timestamp.sub(fixedSaleStartTimestamp) >= fixedSaleEarlyParticipantDuration ||
                                  numberOfFixedSaleBuys >= fixedSaleEarlyParticipantBuysThreshold;

            if(!openToEveryone) {
                require(fixedSaleEarlyParticipants[to], "FRTNA: The fixed-sale is only available to certain participants at the start");
            }

            if(!fixedSaleBuyers[to]) {
                fixedSaleBuyers[to] = true;
                numberOfFixedSaleBuys = numberOfFixedSaleBuys.add(1);
            }

            emit FixedSaleBuy(to, amount, fixedSaleEarlyParticipants[to], numberOfFixedSaleBuys);
        }

        if( 
        	!swapping &&
        	tradingIsEnabled &&
            automatedMarketMakerPairs[to] && //sells only by detecting transfer to automated market maker pair
        	from != address(pancakeRouter) && //router -> pair is removing liquidity which shouldn't have max
            !_isExcludedFromFees[to] //no max for those excluded from fees
        ) {
            require(amount <= maxSellTransactionAmount, "Sell transfer amount exceeds the maxSellTransactionAmount.");
        }

		uint256 contractTokenBalance = balanceOf(address(this));
        
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if(
            tradingIsEnabled && 
            canSwap &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            from != liquidityWallet &&
            to != liquidityWallet
        ) {
            swapping = true;

            uint256 sellPortionOfContractTokenBalance = contractTokenBalance.sub(sellFeeTotalAmount);
            contractTokenBalance -= sellFeeTotalAmount;

            if (contractTokenBalance != 0) {
                uint256 swapTokens = contractTokenBalance.mul(liquidityFeeBuy).div(totalFees);
                swapAndLiquify(swapTokens);

                uint256 sellTokens = balanceOf(address(this));
                swapAndSendDividends(sellTokens);
            }

            if (sellPortionOfContractTokenBalance != 0) {
                uint256 swapTokens = contractTokenBalance.mul(liquidityFeeSell).div(totalFees);
                swapAndLiquify(swapTokens);

                uint256 sellTokens = balanceOf(address(this));
                swapAndSendDividends(sellTokens);
            }

            swapping = false;
        }


        bool takeFee = !isFixedSaleBuy && tradingIsEnabled && !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if(takeFee) {
        	uint256 fees = amount.mul(totalFees).div(multiplierForFees);

            // if sell
            if(automatedMarketMakerPairs[to]) {
                sellFeeTotalAmount += fees;
            }

        	amount = amount.sub(fees);

            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);

        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if(!swapping) {
	    	uint256 gas = gasForProcessing;

	    	try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
	    		emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
	    	} 
	    	catch {

	    	}
        }
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

        // add liquidity to pancake swap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {

        
        // generate the pancake swap pair path of token -> busd
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = BUSD;

        _approve(address(this), address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
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
            block.timestamp
        );
        
    }

    function swapAndSendDividends(uint256 tokens) private {
        swapTokensForEth(tokens);
        uint256 dividends = address(this).balance;
        (bool success,) = address(dividendTracker).call{value: dividends}("");

        if(success) {
   	 		emit SendDividends(tokens, dividends);
        }
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract FRTNADividendTracker is DividendPayingToken, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;

    mapping (address => bool) public excludedFromDividends;

    mapping (address => uint256) public lastClaimTimes;

    uint256 public claimWait;
    uint256 public immutable minimumTokenBalanceForDividends;

    event ExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event Claim(address indexed account, uint256 amount, bool indexed automatic);

    constructor(address _fortunasToken) DividendPayingToken("FRTNA_Dividend_Tracker", "FRTNA_Dividend_Tracker", _fortunasToken) {
    	claimWait = 1800;
        minimumTokenBalanceForDividends = 10000 * (10**18); //must hold 10000+ tokens
    }

    function _transfer(address, address, uint256) internal pure override {
        require(false, "FRTNA_Dividend_Tracker: No transfers allowed");
    }

    function withdrawDividend() public pure override {
        require(false, "FRTNA_Dividend_Tracker: withdrawDividend disabled. Use the 'claim' function on the main FRTNA contract.");
    }

    function excludeFromDividends(address account) external onlyOwner {
    	require(!excludedFromDividends[account]);
    	excludedFromDividends[account] = true;

    	_setBalance(account, 0);
    	tokenHoldersMap.remove(account);

    	emit ExcludeFromDividends(account);
    }

    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait >= 3600 && newClaimWait <= 86400, "FRTNA_Dividend_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "FRTNA_Dividend_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }

    function getLastProcessedIndex() external view returns(uint256) {
    	return lastProcessedIndex;
    }

    function getNumberOfTokenHolders() external view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }



    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;

        index = tokenHoldersMap.getIndexOfKey(account);

        iterationsUntilProcessed = -1;

        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;


                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }


        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);

        lastClaimTime = lastClaimTimes[account];

        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }

    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }

        address account = tokenHoldersMap.getKeyAtIndex(index);

        return getAccount(account);
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    	if(lastClaimTime > block.timestamp)  {
    		return false;
    	}

    	return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    	if(excludedFromDividends[account]) {
    		return;
    	}

    	if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
    		tokenHoldersMap.set(account, newBalance);
    	}
    	else {
            _setBalance(account, 0);
    		tokenHoldersMap.remove(account);
    	}

    	processAccount(account, true);
    }

    function process(uint256 gas) public returns (uint256, uint256, uint256) {
    	uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

    	if(numberOfTokenHolders == 0) {
    		return (0, 0, lastProcessedIndex);
    	}

    	uint256 _lastProcessedIndex = lastProcessedIndex;

    	uint256 gasUsed = 0;

    	uint256 gasLeft = gasleft();

    	uint256 iterations = 0;
    	uint256 claims = 0;

    	while(gasUsed < gas && iterations < numberOfTokenHolders) {
    		_lastProcessedIndex++;

    		if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
    			_lastProcessedIndex = 0;
    		}

    		address account = tokenHoldersMap.keys[_lastProcessedIndex];

    		if(canAutoClaim(lastClaimTimes[account])) {
    			if(processAccount(payable(account), true)) {
    				claims++;
    			}
    		}

    		iterations++;

    		uint256 newGasLeft = gasleft();

    		if(gasLeft > newGasLeft) {
    			gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
    		}

    		gasLeft = newGasLeft;
    	}

    	lastProcessedIndex = _lastProcessedIndex;

    	return (iterations, claims, lastProcessedIndex);
    }

    function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);

    	if(amount > 0) {
    		lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
    		return true;
    	}

    	return false;
    }
}