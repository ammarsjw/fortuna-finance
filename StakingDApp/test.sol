pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./FortunasToken.sol";

contract test is Ownable {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    uint256 public contractStartTime = 1652421600; // a certain epoch time for testing (11:00 AM, 13th May 2022) 
    uint256 public rebaseTime = 1800; // 30 minutes difference in epoch time

    uint256[] public arr;

    FortunasToken public fortunasToken;

    struct Thing {
        uint256 a;
        uint256 b;
    }

    mapping (uint256 => Thing) public things;

    constructor() {
        arr = [1, 2, 3];
    }

    function setFortunasTokenContractAddress(address payable _contractAddress) public onlyOwner {
        fortunasToken = FortunasToken(_contractAddress);
    }

    function test1(uint256 _amount) public pure returns (uint256) {
        uint256 temp = _amount.mul(520833).div(1000000000); // (1000000000000000000 ether * 520833) / 1000000000
        // amount to be given per rebase depending on type of battle

        return temp;
    }

    function test2() public view returns (uint256) {
        // uint256 contractStartTime = 1652421600;
        uint256 temp = block.timestamp.sub(contractStartTime).div(rebaseTime); //number of rebases

        return temp;
    }
    
    function test3(uint256 a, uint256 b) public pure returns (uint256, uint256) { // bitwise swap function
        a ^= b; // int temp = b
        b ^= a; // b = a
        a ^= b; // a = temp

        return (a, b);
    }

    function fun1() external returns(address, address) {
        address temp = fun2();

        fortunasToken.transferFrom(owner(), msg.sender, 1);

        return (msg.sender, temp);
    }

    function fun2() internal returns(address) {
        fortunasToken.transferFrom(owner(), msg.sender, 1);

        return msg.sender;
    }

    function fun3() external view returns (uint8, uint8) {
        uint256 time = block.timestamp - 172799;

        uint8 tempRationsExpended = uint8(block.timestamp.sub(time).div(86400));

        uint8 temptemp = uint8(tempRationsExpended);

        return (tempRationsExpended, temptemp);
    }

    function fun4() external pure returns (uint256, uint256) {
        // battleStartTime.add(3 days).add(_tempBattle.rationDaysTotal).mul(oneDayTime).sub(startTimeForRebase).div(rebaseTime);
        uint256 x = 5;
        uint256 y = 2;
        uint256 temp = x.add(3).add(2).mul(2);
        uint256 temp2 = x.add(3).add(y.mul(2));

        return (temp, temp2);
    }

    function fun5(uint256 x) external pure returns (uint256) {
        return x.mod(48);
    }

    function fun6() external pure returns(uint256, uint256) {
        uint256 x = 2;
        uint256 y = 2;
        
        fun7(x);
        y = fun7(y);

        return (x, y);
    }

    function fun7(uint256 _num) internal pure returns (uint256) {
        _num += 2;

        return _num;
    }

    function fun8(uint256 _num1) external pure returns (uint256, uint256) {
        uint256 num2 = _num1.mul(10).div(4);
        if (num2.mod(10) >= 5) {
            num2 = _num1.ceilDiv(4);
        }
        else {
            num2 = _num1.div(4);
        }

        return (num2, 0);
    }

    function fun9(uint256 _losses) external pure returns (uint256[3] memory) {
        uint256[3] memory posNums;
        for (uint256 i = 0 ; i < 3 ; i++) {
            posNums[i] = _losses.mod(10);
            _losses = _losses.div(10);
        }

        return posNums;
    }

    function fun10() external returns (Thing memory) {
        things[0] = Thing(1, 2);

        return things[0];
    }

    function fun11() external returns (Thing memory) {
        Thing memory thingy;
        
        things[0] = thingy;

        return things[0];
    }

    function fun12(uint256 _num2) external pure returns (uint256) {
        uint256 num = 50;
        num = num.sub(_num2);

        return num;
    }

    function setMapping(uint256 x, uint256 y) external {
        things[0] = Thing(x, y);
    }

    function getMapping(uint256 x) external view returns (Thing memory) {
        return things[x];
    }

    function fun13(uint256 a, uint256 b) external pure returns (uint256) {
        return a.roundDiv(b);
    }

    function fun14(uint256 a, uint256 b) external pure returns (uint256) {
        return a.safeSub(b);
    }
}