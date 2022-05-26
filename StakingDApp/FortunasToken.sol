pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./BEP20.sol";

contract FortunasToken is BEP20 {

    constructor() BEP20("Fortunas", "FRTNA", 18, 1000000000) {
    }

    function burn(address _account, uint256 _amount) external {
        _burn(_account, _amount);
    }

}