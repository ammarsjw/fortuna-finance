pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicense

import "./IERC1155.sol";

interface IFortunasAssets is IERC1155 {

    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) external;

    function safeTransferFromWithCheck(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) external;

    function burnWithCheck(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external;
}