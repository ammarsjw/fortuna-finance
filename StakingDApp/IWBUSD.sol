pragma solidity >=0.5.0;
// SPDX-License-Identifier: Unlicense

interface IWBUSD {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}