pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ABDKMath64x64.sol";

contract FortunasTokenHelper is Ownable {
    using SafeMath for uint256;

    // mappings

    mapping (address => uint256) private _timeSinceLastReward;
    mapping (address => uint256) private _amountOfRewards;

    // constructor

    constructor() {
        
    }
}