pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./IERC20.sol";

interface IFortunasToken is IERC20 {

    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;

}