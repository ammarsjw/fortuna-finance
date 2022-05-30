pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Context.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./FortunasToken.sol";

contract FortunasLottery is Ownable {
    using SafeMath for uint256;

    FortunasToken fortunasToken;

    uint256 lotteryStartTime;
    uint256 timeTillLotteryEnd;

    struct Player {
        uint256 index;
        uint256 tokens;
    }

    address[] public addressIndexes;
    mapping(address => Player) addressForPlayers;

    bool public isLotteryLive;

    // constructor

    constructor() {
        fortunasToken = FortunasToken(payable(0));

        lotteryStartTime = block.timestamp;
        timeTillLotteryEnd = 86400;
    }

    // setters

    function setFortunasToken(address _contractAddress) external onlyOwner {
        fortunasToken = FortunasToken(payable(_contractAddress));
    }

    // functions

    function activateLottery() external onlyOwner {
        isLotteryLive = true;
    }

    function deactivateLottery() external onlyOwner {
        isLotteryLive = false;
    }

    function depositLottery(uint256 _tokens) external {
        require(isLotteryLive, "depositLottery::Lottery is currently inactive. Please try again later");
        require(fortunasToken.balanceOf(msg.sender) != 0, "depositLottery::Insufficient balance");
        require(msg.sender != address(0), "depositLotter::msg.sender cannot be dead address");

        if (isNewPlayer(msg.sender)) {
            addressForPlayers[msg.sender].tokens = _tokens;
            addressIndexes.push(msg.sender);
            uint256 index = addressIndexes.length;
            addressForPlayers[msg.sender].index = index - 1;
        } else {
            addressForPlayers[msg.sender].tokens += _tokens;
        }

        fortunasToken.transferFrom(msg.sender, address(this), _tokens);
    }

    function withdrawLottery(uint256 _tokens) external {
        require(isLotteryLive, "withdrawLottery::Lottery is currently inactive. Please try again later");
        require(isNewPlayer(msg.sender) == false, "withdrawLottery::User is not a participent");
        require(addressForPlayers[msg.sender].tokens >= _tokens, "withdrawLottery::Not enough tokens staked");

        if (addressForPlayers[msg.sender].tokens == _tokens) {
            addressIndexes[addressForPlayers[msg.sender].index] = address(0);
            Player memory emptyPlayer;
            addressForPlayers[msg.sender] = emptyPlayer;
        }
        else {
            addressForPlayers[msg.sender].tokens -= _tokens;
        }

        fortunasToken.transfer(msg.sender, _tokens);
    }

    function declareWinner() external onlyOwner returns (bool) {
        bool isWinnable;
        require(isLotteryLive, "declareWinner::Lottery is currently inactive. Please try again later");
        require(block.timestamp >= lotteryStartTime + timeTillLotteryEnd, "finalizeLottery::Lottery not ended yet");
        
        
        isLotteryLive = false;

        if (addressIndexes.length <= 10) {
            isWinnable = false;
        }
        else {
            isWinnable = true;

            uint256 winningAmount = fortunasToken.balanceOf(address(this)).div(10);

            uint256[10] memory winners = generateRandomNumbers();
            for (uint256 i = 0 ; i < 10 ; i++) {
                fortunasToken.transfer(addressIndexes[winners[i]], winningAmount);
            }
        }

        // emptying mapping and array for next lottery
        deleteMapping();
        addressIndexes = new address[](0);

        lotteryStartTime = block.timestamp;

        isLotteryLive = true;

        return isWinnable;
    }

    function getPlayers() external view returns(address[] memory) {
        return addressIndexes;
    }

    function getPlayer(address playerAddress) external view returns (Player memory) {
        if (isNewPlayer(playerAddress)) {
            Player memory newPlayer;
            return newPlayer;
        }

        return addressForPlayers[playerAddress];
    }

    function getPrizePool() external view returns (uint256) {
        return fortunasToken.balanceOf(address(this));
    }

    function isNewPlayer(address playerAddress) internal view returns (bool) {
        if (addressIndexes.length == 0) {
            return true;
        }

        return (addressIndexes[addressForPlayers[playerAddress].index] != playerAddress);
    }

    function deleteMapping() internal {
        for (uint256 i = 0 ; i < addressIndexes.length ; i++) {
            if (addressIndexes[i] != address(0)) {
                Player memory emptyPlayer;
                addressForPlayers[addressIndexes[i]] = emptyPlayer;
            }
        }
    }

    // TODO randomizer
    function generateRandomNumbers() internal view returns (uint256[10] memory) {
        uint256[10] memory winners;
        uint256 counter;
        bool isUnique;
        while (counter < 10) {
            isUnique = true;
            uint256 randNum = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, addressIndexes)));
            randNum = randNum.mod(addressIndexes.length);
            for (uint256 i = 0 ; i < 10 ; i++) {
                if (winners[i] == randNum) {
                    isUnique = false;
                }
            }
            if (isUnique && addressIndexes[randNum] != address(0)) {
                winners[counter] = randNum;
                counter++;
            }
        }

        return winners;
    }
}