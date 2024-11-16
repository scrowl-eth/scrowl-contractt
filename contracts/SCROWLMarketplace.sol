// contracts/SCROWLMarketplace.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./SCROWLAccountNFT.sol";

contract SCROWLMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 tokenId;
        address seller;
        address nftContract;
        uint256 price;
        bool isActive;
        bool isSold;
        string ensName;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingCount;
    mapping(uint256 => address) public listingEscrow;

    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        string ensName
    );

    event Sale(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );

    event ListingCanceled(uint256 indexed listingId);
    event DisputeInitiated(uint256 indexed listingId, address initiator);

    constructor() {
        listingCount = 0;
    }

    function listAccount(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        string memory ensName
    ) external nonReentrant {
        require(price > 0, "Price must be > 0");
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");
        
        // Check approval
        require(nft.getApproved(tokenId) == address(this) || 
                nft.isApprovedForAll(msg.sender, address(this)), 
                "Not approved");

        listingCount++;
        listings[listingCount] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            nftContract: nftContract,
            price: price,
            isActive: true,
            isSold: false,
            ensName: ensName
        });

        emit Listed(
            listingCount,
            msg.sender,
            nftContract,
            tokenId,
            price,
            ensName
        );
    }

    function buyAccount(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "Not active");
        require(!listing.isSold, "Already sold");
        require(msg.value == listing.price, "Wrong price");

        listing.isActive = false;
        listing.isSold = true;
        listingEscrow[listingId] = msg.sender;

        emit Sale(
            listingId,
            msg.sender,
            listing.seller,
            listing.price
        );
    }

    function confirmReceiptAndClaim(uint256 listingId) external nonReentrant {
        require(listingEscrow[listingId] == msg.sender, "Not buyer");
        
        Listing storage listing = listings[listingId];
        require(listing.isSold, "Not sold");

        SCROWLAccountNFT nft = SCROWLAccountNFT(listing.nftContract);
        
        // Transfer NFT first
        nft.transferFrom(listing.seller, msg.sender, listing.tokenId);
        
        // Now claim as the new owner
        nft.claimCredentials(listing.tokenId);
        
        // Transfer payment last
        payable(listing.seller).transfer(listing.price);
        
        delete listingEscrow[listingId];
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.isActive, "Not active");
        require(!listing.isSold, "Already sold");

        listing.isActive = false;
        emit ListingCanceled(listingId);
    }

    function initiateDispute(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(
            msg.sender == listing.seller || msg.sender == listingEscrow[listingId],
            "Not authorized"
        );
        require(listing.isSold, "Not sold");

        emit DisputeInitiated(listingId, msg.sender);
    }

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }
}

// contract SCROWLMarketplace is ReentrancyGuard {
//     struct Listing {
//         uint256 tokenId;
//         address seller;
//         address nftContract;
//         uint256 price;
//         bool isActive;
//         bool isSold;
//         string ensName;
//     }

//     mapping(uint256 => Listing) public listings;
//     uint256 public listingCount;
//     mapping(uint256 => address) public listingEscrow;

//     event Listed(
//         uint256 indexed listingId,
//         address indexed seller,
//         address nftContract,
//         uint256 tokenId,
//         uint256 price,
//         string ensName
//     );

//     event Sale(
//         uint256 indexed listingId,
//         address indexed buyer,
//         address indexed seller,
//         uint256 price
//     );

//     event ListingCanceled(uint256 indexed listingId);
//     event DisputeInitiated(uint256 indexed listingId, address initiator);

//     constructor() {
//         listingCount = 0;
//     }

//     function listAccount(
//         address nftContract,
//         uint256 tokenId,
//         uint256 price,
//         string memory ensName
//     ) external nonReentrant {
//         require(price > 0, "Price must be > 0");
        
//         IERC721 nft = IERC721(nftContract);
//         require(nft.ownerOf(tokenId) == msg.sender, "Not owner");
//         require(nft.getApproved(tokenId) == address(this), "Not approved");

//         listingCount++;
//         listings[listingCount] = Listing({
//             tokenId: tokenId,
//             seller: msg.sender,
//             nftContract: nftContract,
//             price: price,
//             isActive: true,
//             isSold: false,
//             ensName: ensName
//         });

//         emit Listed(
//             listingCount,
//             msg.sender,
//             nftContract,
//             tokenId,
//             price,
//             ensName
//         );
//     }

//     function buyAccount(uint256 listingId) external payable nonReentrant {
//         Listing storage listing = listings[listingId];
//         require(listing.isActive, "Not active");
//         require(!listing.isSold, "Already sold");
//         require(msg.value == listing.price, "Wrong price");

//         listing.isActive = false;
//         listing.isSold = true;
//         listingEscrow[listingId] = msg.sender;

//         emit Sale(
//             listingId,
//             msg.sender,
//             listing.seller,
//             listing.price
//         );
//     }

//     function confirmReceiptAndClaim(uint256 listingId) external nonReentrant {
//         require(listingEscrow[listingId] == msg.sender, "Not buyer");
        
//         Listing storage listing = listings[listingId];
//         require(listing.isSold, "Not sold");

//         SCROWLAccountNFT nft = SCROWLAccountNFT(listing.nftContract);
        
//         // Transfer NFT first
//         nft.transferFrom(listing.seller, msg.sender, listing.tokenId);
        
//         // Transfer payment
//         payable(listing.seller).transfer(listing.price);
        
//         // Claim credentials after transfer
//         nft.claimCredentials(listing.tokenId);
        
//         delete listingEscrow[listingId];
//     }

//     function cancelListing(uint256 listingId) external nonReentrant {
//         Listing storage listing = listings[listingId];
//         require(listing.seller == msg.sender, "Not seller");
//         require(listing.isActive, "Not active");
//         require(!listing.isSold, "Already sold");

//         listing.isActive = false;
//         emit ListingCanceled(listingId);
//     }

//     function initiateDispute(uint256 listingId) external {
//         Listing storage listing = listings[listingId];
//         require(
//             msg.sender == listing.seller || msg.sender == listingEscrow[listingId],
//             "Not authorized"
//         );
//         require(listing.isSold, "Not sold");

//         emit DisputeInitiated(listingId, msg.sender);
//     }

//     function getListing(uint256 listingId) external view returns (Listing memory) {
//         return listings[listingId];
//     }
// }