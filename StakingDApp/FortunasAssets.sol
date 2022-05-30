pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Context.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC1155.sol";

contract FortunasAssets is ERC1155 {

    // variables

    address public battlingContractAddress;

    // constructor

    constructor(string memory _uri, address _battlingContractAddress) ERC1155(_uri) {
        battlingContractAddress = _battlingContractAddress;
    }

    // setters

    function setBattling(address _battlingContractAddress) external onlyContract {
        battlingContractAddress = _battlingContractAddress;
    }

    // functions

    function mint(
    address _to,
    uint256 _tokenId,
    uint256 _amount,
    bytes memory _data) external onlyContract {
        _mint(_to, _tokenId, _amount, _data);
    }

    function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    uint256 _amount,
    bytes calldata _data) public override {
        require(balanceOf(_to, _tokenId) == 0, "safeTransferFrom::Cannot have more than 1 of any hero or cavalry type");
        super.safeTransferFrom(_from, _to, _tokenId, _amount, _data);
    }

    function burn(
    address _from,
    uint256 _tokenId,
    uint256 _amount) external {
        _burn(_from, _tokenId, _amount);
    }

    modifier onlyContract {
        require(msg.sender == battlingContractAddress, "onlyContract::Only Fortunas Battling contract can call this function");
        _;
    }
}