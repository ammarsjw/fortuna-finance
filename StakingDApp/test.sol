pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MathUpgradeable.sol";
import "./FortunasToken.sol";
import "./ABDKMath64x64.sol";

abstract contract BaseTest {

    mapping (uint256 => uint256) values;

    function adding(uint256 a, uint256 b) public virtual returns (uint256) {
        return a + b;
    }

    function getValues(uint256 x) external view returns (uint256) {
        return values[x];
    }

}

contract OtherTest is Ownable, BaseTest {

    address public sender;
    address public origin;

    constructor() {
        sender = msg.sender;
        origin = tx.origin;
    }

    function adding(uint256 a, uint256 b) public virtual override returns (uint256) {
        return a + b;
    }
    
    function outsideCall1() external view returns (address) {
        address x = msg.sender;
        return x;
    }

    function outsideCall2() public view returns (address) {
        address y = msg.sender;
        return y;
    }

    function changeValues(uint256 x, uint256 y) public {
        values[x] = y;
    }

}

contract Test is Ownable, BaseTest {
    using SafeMath for uint256;
    using MathUpgradeable for uint256;

    OtherTest public otherTest;
    
    uint256 public contractStartTime = 1652421600; // a certain epoch time for testing (11:00 AM, 13th May 2022) 
    
    uint256 rewardTime;
    uint256 oneDayTime;
    uint256 baseBattleTime;

    uint256[] public arr;

    mapping(uint256 => uint256) public map;

    FortunasToken public fortunasToken;

    struct Thing {
        uint256 a;
        uint256 b;
    }

    mapping (uint256 => Thing) public things;

    constructor() {
        arr = [1, 2, 3];
        map[1] = 5;
        things[1] = Thing(1, 2);

        // rewardTime = 1800;
        // oneDayTime = 86400;
        // baseBattleTime = 259200;
        rewardTime = 1;                                     // only for testing
        oneDayTime = 48;                                    // only for testing
        baseBattleTime = 144;                               // only for testing

        otherTest = new OtherTest();
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
        uint256 temp = block.timestamp.sub(contractStartTime).div(rewardTime); //number of rewards

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

    function getMapping2(uint256 x) external view returns (uint256) {
        return map[x];
    }

    function fun13(uint256 a, uint256 b) external pure returns (uint256) {
        return a.roundDiv(b);
    }

    function fun14(uint256 a, uint256 b) external pure returns (uint256) {
        return a.safeSub(b);
    }

    function fun15() external view returns (uint256, uint256[] memory, uint256, uint256) {
        uint256 _losses = 222;
        uint256 randHero = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));

        uint256 randHero2 = randHero.mod(1000);

        uint256 mapNum = map[1];

        uint256[] memory posLosses = new uint256[](mapNum);
        uint256 counter = 0;
        for (uint256 i = 0 ; i < 3 ; i++) {
            posLosses[i] = _losses.mod(10);
            _losses = _losses.div(10);
            counter++;
        }

        uint256[] memory posL = new uint256[](counter);
        for (uint256 i = 0 ; i < 3 ; i++) {
            posL[i] = posLosses[i];
        }

        return (counter, posL, randHero, randHero2);
    }

    function fun16() external pure returns (uint256) {
        uint256 x = 1000 * (10**18);
        uint256 y = 156250;
        uint256 z = 1000000000;

        x += x.mul(y).div(z);

        return x;
    }

    function fun17() external view returns (uint256) {
        uint256 a = 1653910671;
        uint256 c = 1653910671;

        uint256 numberOfRewardCycles = a.add(baseBattleTime).sub(c).div(rewardTime);

        return numberOfRewardCycles;
    }

    function fun18(uint256 _principal, uint256 _ratio, uint256 _exponent) external pure returns (uint256, uint256) {
        // Multiply _ratio by 10 ** 7 and then send it as an argument
        bool isInteger = false;
        if (_ratio.mod(10000000) == 0) {
            isInteger = true;
        }
        _ratio = _ratio.mul(10 ** 18).div(10 ** 9);

        uint256 accruedReward = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);

        if (isInteger) {
            return (accruedReward.add(1), accruedReward.sub(_principal).add(1));
        }

        return (accruedReward, accruedReward.sub(_principal));
    }

    function fun19(uint256 a, uint256 b) external view returns (uint256) {
        return a.add(baseBattleTime).add(b.mul(oneDayTime));
    }

    function fun20(uint256 a) external view returns (uint256) {
        return block.timestamp.sub(a).div(oneDayTime);
    }

    function fun21(uint256 _rationDays) external view returns (uint256, uint256) {
        uint256 currentTime = 1654499252;
        uint256 battleStartTime = 1654499098;
        uint256 rationsDaysTotal = 1;
        uint256 battleDaysExpended = 3;
        uint256 rationsExpended;
        uint256 currentRationsDays;

        if (currentTime >= battleStartTime.add(baseBattleTime).add(rationsDaysTotal.mul(oneDayTime))) {
            require(false, "sendRations::Cannot send rations to battles that have already finished");
        }
        else if (battleDaysExpended >= 3) {
            rationsExpended = currentTime.sub(battleStartTime.add(baseBattleTime)).ceilDiv(oneDayTime);
            currentRationsDays = rationsDaysTotal.sub(rationsExpended).add(_rationDays);
            require(currentRationsDays <= 5, "sendRations::Rations cannot exceed 5 days at a single given time");
        }

        return (rationsExpended, currentRationsDays);
    }

    function fun22() external pure returns (uint256) {
        uint256 x = 0;
        
        return x.add(3);
    }

    function fun23() external {
        map[1] = super.adding(1, 2);
    }

    function fun24() external view returns (Thing memory) {
        Thing memory tempThings = things[1];
        fun25(tempThings);

        return tempThings;
    }

    function fun25(Thing memory _tempThings) internal pure {
        _tempThings = Thing(5, 6);
    }

    function fun26() external view returns(address, address, address) {
        address x;
        address y;
        x = otherTest.outsideCall1();
        y = otherTest.outsideCall2();
        return (msg.sender, x, y);
    }

    function fun27(uint256 _principal, uint256 _ratio, uint256 _exponent) external pure returns (uint256, uint256) {
        _ratio *= 10 ** 7;
        // Ratio should be in whole numbers. If floating point numbers are required comment this^ out and multiply by 10 ** 7
        _ratio = _ratio.mul(10 ** 18).div(10 ** 9);

        uint256 accruedInterest1 = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
        _exponent = 1;
        uint256 accruedInterest2 = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), accruedInterest1);

        return (accruedInterest1, accruedInterest2);
    }

    function fun28(uint256 _principal, uint256 _ratio, uint256 _exponent) external pure returns (uint256, uint256) {
        _ratio *= 10 ** 7;
        // Ratio should be in whole numbers. If floating point numbers are required comment this^ out and multiply by 10 ** 7
        _ratio = _ratio.mul(10 ** 18).div(10 ** 9);

        _principal = _principal.mul(10 ** 18);

        uint256 accruedInterest1 = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), _principal);
        _exponent = 1;
        uint256 accruedInterest2 = ABDKMath64x64.mulu(ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), ABDKMath64x64.divu(_ratio,10**18)), _exponent), accruedInterest1);

        return (accruedInterest1, accruedInterest2);
    }

    function changeValues(uint256 x, uint256 y) public {
        values[x] = y;
    }

    function fun29(uint256 _ratio) external pure returns (uint256) {
        return _ratio.mod(10000000);
    }
}