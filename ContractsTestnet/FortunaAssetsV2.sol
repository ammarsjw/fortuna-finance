pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./Ownable.sol";
import "./Strings.sol";

import "./ERC1155.sol";

contract FortunaAssetsV2 is ERC1155, Ownable {
    using Strings for string;

    bool public isTransferEnabled = false;

    string baseURI;

    // constructor

    constructor() ERC1155("ipfs://bafybeihankcvladvfywrbt5eq4qsc4irlc3abt3d2np76ljlhzg5imqemi/") {
        baseURI = "ipfs://bafybeihankcvladvfywrbt5eq4qsc4irlc3abt3d2np76ljlhzg5imqemi/";
    }

    // getters

    function balanceOfAllAssets(address _account) external view returns (uint256[] memory) {
        require(_account != address(0), "balanceOfAssetsBatch::Address zero is not a valid owner");

        uint256[] memory allAssetBalances = new uint256[](10);
        for (uint256 i = 0 ; i < 10 ; i++) {
            allAssetBalances[i] = balanceOf(_account, i + 1);
        }

        return allAssetBalances;
    }

    // setters

    function setIsTransferEnabled(bool _state) external onlyOwner {
        require(isTransferEnabled != _state, "setIsTransferEnabled::isTransferEnabled is already set to this state");
        isTransferEnabled = _state;
    }

    function setURI(string memory _uri) external onlyOwner {
        _setURI(_uri);
        baseURI = _uri;
    }

    // functions

    function mintWithCheck(address _to, uint256 _tokenId, uint256 _amount, bytes memory _data) external onlyOwner {
        require(1 <= _tokenId && _tokenId <= 10, "mint::Wrong token id given");
        _mint(_to, _tokenId, _amount, _data);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) public override {
        require(isTransferEnabled == true, "safeTransferFrom::Function not yet available");
        require(1 <= _tokenId && _tokenId <= 10, "safeTransferFrom::Wrong token id given");

        super.safeTransferFrom(_from, _to, _tokenId, _amount, _data);
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
            require(1 <= _tokenIds[i] && _tokenIds[i] <= 10, "safeBatchTransferFrom::Wrong token ids given");
        }

        super.safeBatchTransferFrom(_from, _to, _tokenIds, _amounts, _data);
    }

    function burnWithCheck(address _from, uint256 _tokenId, uint256 _amount) external onlyOwner {
        _burn(_from, _tokenId, _amount);
    }

    function uri(uint256 _tokenId) override public view returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
    }
}