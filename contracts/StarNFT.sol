// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StarPlayerNFT is ERC721URIStorage, Ownable {
    uint256 public tokenCounter;

    constructor() ERC721("StarPlayerNFT", "SPNFT") Ownable(msg.sender) {
        tokenCounter = 0;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return type(ERC721URIStorage).interfaceId == interfaceId || type(Ownable).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }

    function createNFT(string memory tokenUri) public onlyOwner returns (uint256) {
        uint256 newItemId = tokenCounter;
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenUri);
        tokenCounter++;
        return newItemId;
    }

    function buyNFT(uint256 tokenId) public payable {
        require(tokenId <= tokenCounter, "Token does not exist");
        address owner = ownerOf(tokenId);
        require(msg.value > 0, "Payment should be greater than zero");
        require(owner != msg.sender, "Cannot buy your own NFT");

        _transfer(owner, msg.sender, tokenId);
        payable(owner).transfer(msg.value);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
