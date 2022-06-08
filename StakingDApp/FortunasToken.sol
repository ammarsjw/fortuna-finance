pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC20.sol";
import "./IPancakeFactory.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";

contract FortunasToken is ERC20, Ownable {
    using SafeMath for uint256;

    address public battlingContractAddress;

    IPancakeRouter02 public pancakeRouter;
    // address public immutable pancakePair;
    address public pancakePair;

    // BUSD mainnet
    // address public immutable BUSD =
    //     address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    // BUSD testnet (TestnetERC20Token)
    address public BUSD =
        address(0x7D9385C733a967793EE14D933212ee44025f1B9d);

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

    uint256 public transferTokensAtAmount = 100000 * (10**18);

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
    mapping (address => bool) private isExcludedFromFees;

    // addresses that can make transfers before presale is over
    mapping (address => bool) private canTransferBeforeTradingIsEnabled;

    mapping (address => bool) public fixedSaleEarlyParticipants;

    // store addresses that a automatic market maker pairs
    mapping (address => bool) public automatedMarketMakerPairs;

    // events

    event UpdatePancakeRouter(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsToFees(address[] accounts, bool isExcluded);

    event FixedSaleEarlyParticipantsAdded(address[] participants);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);

    event TreasuryWalletUpdated(address indexed newTreasuryWallet, address indexed oldTreasuryWallet);

    event FixedSaleBuy(address indexed account, uint256 indexed amount, bool indexed earlyParticipant, uint256 numberOfBuyers);

    // constructor

    constructor() ERC20("Fortunas Token", "FRTNA") {
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

        multiplierForFee = 1000;

        // TODO
    	liquidityWallet = address(0x45faf7923BAb5A5380515E055CA700519B3e4705);
        treasuryWallet = address(0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80);

        // PancakeRouter02 mainnet
    	// IPancakeRouter02 _pancakeRouter = IPancakeRouter02(address(0));
        // PancakeRouter02 testnet
        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
        // address _pancakePair = IPancakeFactory(_pancakeRouter.factory())
        //     .createPair(address(this), BUSD);

        // pancakeRouter = _pancakeRouter;
        // pancakePair = _pancakePair;

        // _setAutomatedMarketMakerPair(_pancakePair, true);

        // exclude from paying fees
        excludeFromFees(liquidityWallet, true);
        excludeFromFees(treasuryWallet, true);
        excludeFromFees(owner(), true);

        // enable owner and fixed-sale wallet to send tokens before presales are over
        canTransferBeforeTradingIsEnabled[owner()] = true;

        _mint(owner(), 1000000000 * (10**18));
    }

    function postConstructor(address _battlingContractAddress/*, address _lotteryContractAddress*/) external onlyOwner {
        battlingContractAddress = _battlingContractAddress;
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

    function excludeMultipleAccountsToFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsToFees(accounts, excluded);
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

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateLiquidityWallet(address newLiquidityWallet) public onlyOwner {
        require(newLiquidityWallet != liquidityWallet, "FRTNA: The liquidity wallet is already this address");
        excludeFromFees(newLiquidityWallet, true);
        emit LiquidityWalletUpdated(newLiquidityWallet, liquidityWallet);
        liquidityWallet = newLiquidityWallet;
    }

    function updateTreasuryWallet(address newTreasuryWallet) public onlyOwner {
        require(newTreasuryWallet != treasuryWallet, "FRTNA: The treasury wallet is already this address");
        excludeFromFees(newTreasuryWallet, true);
        emit TreasuryWalletUpdated(newTreasuryWallet, treasuryWallet);
        treasuryWallet = newTreasuryWallet;
    }

    function getTradingIsEnabled() public view returns (bool) {
        return block.timestamp >= tradingEnabledTimestamp;
    }

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

        if (canTransfer) {
            uint256 totalBuyingFeesAccumulated = contractTokenBalance;
            uint256 toLiquidityAmount;
            uint256 toTreasuryAmount;
            uint256 toBurnAmount;

            if (totalSellingFeesAccumulated > 0) {
                totalBuyingFeesAccumulated -= totalSellingFeesAccumulated;

                toLiquidityAmount = totalSellingFeesAccumulated
                    .mul(liquiditySellingFee)
                    .div(multiplierForFee);
                super._transfer(address(this), liquidityWallet, toLiquidityAmount);

                toTreasuryAmount = totalSellingFeesAccumulated
                    .mul(treasurySellingFee)
                    .div(multiplierForFee);
                super._transfer(address(this), treasuryWallet, toTreasuryAmount);

                toBurnAmount = totalSellingFeesAccumulated
                    .mul(burnSellingFee)
                    .div(multiplierForFee);
                _burn(address(this), toBurnAmount);
            }
            
            if (totalBuyingFeesAccumulated > 0) {
                toLiquidityAmount = totalBuyingFeesAccumulated
                    .mul(liquidityBuyingFee)
                    .div(multiplierForFee);
                super._transfer(address(this), liquidityWallet, toLiquidityAmount);

                toTreasuryAmount = totalBuyingFeesAccumulated
                    .mul(treasuryBuyingFee)
                    .div(multiplierForFee);
                super._transfer(address(this), treasuryWallet, toTreasuryAmount);

                toBurnAmount = totalBuyingFeesAccumulated
                    .mul(burnBuyingFee)
                    .div(multiplierForFee);
                _burn(address(this), toBurnAmount);
            }

            totalSellingFeesAccumulated = 0;
        }

        if (
            _isBuy(from)
            && !isExcludedFromFees[to]
        ) {
            uint256 buyingFee = amount.mul(totalBuyingFee).div(multiplierForFee);
            amount -= buyingFee;

            super._transfer(from, address(this), buyingFee);
        }

        if (
            _isSell(from, to)
            && !isExcludedFromFees[from]
        ) {
            uint256 sellingFee = amount.mul(totalSellingFee).div(multiplierForFee);
            totalSellingFeesAccumulated += sellingFee;
            amount -= sellingFee;

            super._transfer(from, address(this), sellingFee);
        }

        super._transfer(from, to, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external onlyContract {
        _mint(account, amount);
    }

    modifier onlyContract {
        require(msg.sender == battlingContractAddress, "onlyContract::Only Fortunas Battling Contract can call this function");
        _;
    }

    receive() external payable {

  	}
}