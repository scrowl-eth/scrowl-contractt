// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SCROWLAccountNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 private _currentTokenId;
    address public marketplace;

    struct GameAccount {
        string encryptedData;     
        string gameId;            
        uint256 listingPrice;     
        bool isClaimed;           
        address claimer;          
    }

    mapping(uint256 => GameAccount) private gameAccounts;
    mapping(uint256 => bool) private _tokenExists;

    event AccountNFTMinted(
        uint256 indexed tokenId,
        address indexed minter,
        string gameId,
        uint256 listingPrice
    );

    event CredentialsClaimed(
        uint256 indexed tokenId,
        address indexed claimer
    );

    event ListingPriceUpdated(
        uint256 indexed tokenId,
        uint256 newPrice
    );

    constructor() ERC721("SCROWL Game Accounts", "SCROWL") Ownable(msg.sender) {
        marketplace = address(0); // Will be set later
    }

    function setMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }

    function tokenExists(uint256 tokenId) public view returns (bool) {
        return _tokenExists[tokenId];
    }

    function mintGameAccount(
        string memory encryptedData,
        string memory gameId,
        uint256 listingPrice,
        string memory tokenURI
    ) public returns (uint256) {
        _currentTokenId++;
        uint256 newTokenId = _currentTokenId;

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        _tokenExists[newTokenId] = true;

        gameAccounts[newTokenId] = GameAccount({
            encryptedData: encryptedData,
            gameId: gameId,
            listingPrice: listingPrice,
            isClaimed: false,
            claimer: address(0)
        });

        emit AccountNFTMinted(newTokenId, msg.sender, gameId, listingPrice);
        return newTokenId;
    }

    function claimCredentials(uint256 tokenId) public nonReentrant {
        require(tokenExists(tokenId), "Token does not exist");
        require(
            ownerOf(tokenId) == msg.sender || // Owner can claim
            msg.sender == gameAccounts[tokenId].claimer || // Approved claimer can claim
            msg.sender == marketplace, // Marketplace can claim
            "Not authorized to claim"
        );
        require(!gameAccounts[tokenId].isClaimed, "Already claimed");

        gameAccounts[tokenId].isClaimed = true;
        gameAccounts[tokenId].claimer = ownerOf(tokenId);

        emit CredentialsClaimed(tokenId, ownerOf(tokenId));
    }

    function getGameAccountDetails(uint256 tokenId) public view returns (
        string memory gameId,
        uint256 listingPrice,
        bool isClaimed,
        address claimer
    ) {
        require(tokenExists(tokenId), "Token does not exist");
        GameAccount memory account = gameAccounts[tokenId];
        return (
            account.gameId,
            account.listingPrice,
            account.isClaimed,
            account.claimer
        );
    }

    function getEncryptedData(uint256 tokenId) public view returns (string memory) {
        require(tokenExists(tokenId), "Token does not exist");
        require(
            msg.sender == ownerOf(tokenId) || msg.sender == gameAccounts[tokenId].claimer,
            "Not authorized"
        );
        return gameAccounts[tokenId].encryptedData;
    }

    function updateListingPrice(uint256 tokenId, uint256 newPrice) public {
        require(tokenExists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!gameAccounts[tokenId].isClaimed, "Account claimed");

        gameAccounts[tokenId].listingPrice = newPrice;
        emit ListingPriceUpdated(tokenId, newPrice);
    }

    function totalSupply() public view returns (uint256) {
        return _currentTokenId;
    }

    function burn(uint256 tokenId) public {
        require(tokenExists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        
        _burn(tokenId);
        delete gameAccounts[tokenId];
        _tokenExists[tokenId] = false;
    }
}