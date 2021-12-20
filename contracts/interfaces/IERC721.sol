//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IERC721 {
  function ownerOf(uint256 _tokenId) external view returns (address);
  function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
  function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
}
