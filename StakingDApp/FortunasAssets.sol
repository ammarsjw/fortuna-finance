pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC1155.sol";

contract FortunasAssets is Ownable, ERC1155 {

    address public battling;
    address public parent;

    bool public isTransferEnabled = false;

    // mappings

    mapping (uint256 => mapping(address => bool)) private _ownership;

    // constructor

    constructor(
        string memory _uri
    ) ERC1155(_uri) {
        battling = msg.sender;
        parent = tx.origin;
    }

    // getters

    function ownershipOf(
        address _account,
        uint256 _id
    ) external view returns (bool) {
        require(_account != address(0), "ownershipOf::Address zero is not a valid owner");
        return _ownership[_id][_account];
    }

    function ownershipOfBatch(
        address _account
    ) external view returns (bool[] memory) {
        require(_account != address(0), "ownershipOfBatch::Address zero is not a valid owner");

        bool[] memory ownershipBatch = new bool[](10);
        for (uint256 i = 0 ; i < 10 ; i++) {
            ownershipBatch[i] = _ownership[i + 1][_account];
        }

        return ownershipBatch;
    }

    // setters

    function setIsTransferEnabled(
        bool _state
    ) external onlyParent {
        require(isTransferEnabled != _state, "setIsTransferEnabled::isTransferEnabled is already of the value '_state'");

        isTransferEnabled = _state;
    }

    function setURI(
        string memory _uri
    ) external onlyParent {
        _setURI(_uri);
    }

    // functions

    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) external onlyOwner {
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
        require(isTransferEnabled == true, "safeTransferFrom::Function not yet available");
        require(_ownership[_tokenId][_to] == false, "safeTransferFrom::Cannot have more than 1 of any hero or cavalry type");

        super.safeTransferFrom(_from, _to, _tokenId, _amount, _data);

        _ownership[_tokenId][_from] = false;
        _ownership[_tokenId][_to] = true;
    }

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        bytes memory _data
    ) public override {
        require(isTransferEnabled == true, "safeBatchTransferFrom::Function not yet available");

        for (uint256 i = 0 ; i < _tokenIds.length ; i++) {
            if (_ownership[_tokenIds[i]][_to]) {
                require(false, "safeBatchTransferFrom::Cannot have more than 1 of any hero or cavalry type");
            }
            else {
                _ownership[_tokenIds[i]][_from] = false;
                _ownership[_tokenIds[i]][_to] = true;
            }
        }

        super.safeBatchTransferFrom(_from, _to, _tokenIds, _amounts, _data);
    }

    function safeTransferFromWithoutCheck(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) public onlyOwner {
        require(_to == battling || _from == battling, "safeTransferFromWithoutCheck::Either sender or recipient must be Battling contract");

        super.safeTransferFrom(_from, _to, _tokenId, _amount, _data);
    }

    function burnWithoutCheck(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external onlyOwner {
        require(_from != battling, "burnWithoutCheck::Incorrect argument given");
        _burn(msg.sender, _tokenId, _amount);

        _ownership[_tokenId][_from] = false;
    }

    // modifiers

    modifier onlyParent() {
        require(msg.sender == parent, "onlyParent::Only parent can call this function");
        _;
    } 
}