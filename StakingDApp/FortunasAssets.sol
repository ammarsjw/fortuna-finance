pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Context.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC1155.sol";

contract FortunasAssets is Ownable, ERC1155 {

    // variables

    address public battlingContractAddress;

    mapping(uint256 => mapping(address => bool)) private _ownership;

    // constructor

    constructor(
        string memory _uri,
        address _battlingContractAddress
    ) ERC1155(_uri) {
        battlingContractAddress = _battlingContractAddress;
    }

    // functions

    function ownershipOf(
        address _account,
        uint256 _id
    ) external view returns (bool) {
        require(_account != address(0), "ownershipOf::Address zero is not a valid owner");
        return _ownership[_id][_account];
    }

    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) external onlyContract {
        require(_ownership[_tokenId][_to] == false, "mint::Cannot have more than 1 of any hero or cavalry type");
        _mint(_to, _tokenId, _amount, _data);

        _ownership[_tokenId][_to] = true;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) public override {
        require(_ownership[_tokenId][_to] == false, "safeTransferFrom::Cannot have more than 1 of any hero or cavalry type");
        super.safeTransferFrom(_from, _to, _tokenId, _amount, _data);

        _ownership[_tokenId][_to] = true;
        _ownership[_tokenId][_from] = false;
    }

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        bytes memory _data
    ) public override {
        super.safeBatchTransferFrom(_from, _to, _tokenIds, _amounts, _data);

        for (uint256 i = 0 ; i < _tokenIds.length ; i++) {
            if (_ownership[_tokenIds[i]][_to]) {
                require(false, "safeBatchTransferFrom::Cannot have more than 1 of any hero or cavalry type");
            }
            else {
                _ownership[_tokenIds[i]][_to] = true;
                _ownership[_tokenIds[i]][_from] = false;
            }
        }
    }

    function safeTransferFromWithoutCheck(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) public onlyContract {
        require(_to == battlingContractAddress || _from == battlingContractAddress, "safeTransferFromWithoutCheck::Either sender or recipient must be contract");
        super.safeTransferFrom(_from, _to, _tokenId, _amount, _data);
    }

    function burnWithoutCheck(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external onlyContract {
        require(_from != battlingContractAddress, "burnWithoutCheck::Incorrect arguments given");
        _burn(msg.sender, _tokenId, _amount);

        _ownership[_tokenId][_from] = false;
    }

    modifier onlyContract {
        require(msg.sender == battlingContractAddress, "onlyContract::Only Fortunas Battling contract can call this function");
        _;
    }
}