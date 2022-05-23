pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./BEP20.sol";

contract FortunasToken is BEP20 {

    constructor() BEP20("Fortunas", "FRTNA", 18, 1000000000) {
    }

}

/*

to do:
BEP20 "FRTNA" "Fortunas"
6 scenarios
Longer battles - 5 Levels
Heroes and Cavalry
Rebase tokens
APY
RFV
Treasury
Buy/Sell Fees + Slippage
Pancake swap

*/