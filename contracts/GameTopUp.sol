// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GameTopUp is Ownable, ReentrancyGuard {
    // Game currency struct
    struct GameCurrency {
        string name;
        uint256 rate;     // Rate per 1 USD in wei
        bool isActive;
    }
    
    // Purchase history struct
    struct Purchase {
        address buyer;
        string gameId;
        string userId;
        uint256 amount;
        uint256 cost;
        uint256 timestamp;
    }

    // Mapping of game currencies (gameId => GameCurrency)
    mapping(string => GameCurrency) public gameCurrencies;
    
    // Mapping of user purchases (buyer => Purchase[])
    mapping(address => Purchase[]) public userPurchases;
    
    // Events
    event CurrencyAdded(string gameId, string name, uint256 rate);
    event CurrencyUpdated(string gameId, uint256 newRate);
    event TopUpCompleted(
        address indexed buyer,
        string gameId,
        string userId,
        uint256 amount,
        uint256 cost,
        uint256 timestamp
    );

    constructor() Ownable(msg.sender) {
        // Initialize with some game currencies
        addGameCurrency("valorant", "VP", 100000000000000); // 0.0001 ETH per VP
        addGameCurrency("pubg", "UC", 50000000000000);     // 0.00005 ETH per UC
        addGameCurrency("mlbb", "Diamonds", 75000000000000); // 0.000075 ETH per Diamond
    }

    // Add new game currency
    function addGameCurrency(
        string memory gameId,
        string memory name,
        uint256 rate
    ) public onlyOwner {
        require(!gameCurrencies[gameId].isActive, "Game currency already exists");
        gameCurrencies[gameId] = GameCurrency(name, rate, true);
        emit CurrencyAdded(gameId, name, rate);
    }

    // Update currency rate
    function updateCurrencyRate(string memory gameId, uint256 newRate) public onlyOwner {
        require(gameCurrencies[gameId].isActive, "Game currency does not exist");
        gameCurrencies[gameId].rate = newRate;
        emit CurrencyUpdated(gameId, newRate);
    }

    // Calculate cost for top-up
    function calculateCost(
        string memory gameId,
        uint256 amount
    ) public view returns (uint256) {
        require(gameCurrencies[gameId].isActive, "Game currency does not exist");
        return amount * gameCurrencies[gameId].rate;
    }

    // Purchase top-up
    function purchaseTopUp(
        string memory gameId,
        string memory userId,
        uint256 amount
    ) public payable nonReentrant {
        require(gameCurrencies[gameId].isActive, "Game currency does not exist");
        
        uint256 cost = calculateCost(gameId, amount);
        require(msg.value >= cost, "Insufficient payment");

        // Record the purchase
        Purchase memory newPurchase = Purchase(
            msg.sender,
            gameId,
            userId,
            amount,
            cost,
            block.timestamp
        );
        userPurchases[msg.sender].push(newPurchase);

        // Refund excess payment
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }

        emit TopUpCompleted(
            msg.sender,
            gameId,
            userId,
            amount,
            cost,
            block.timestamp
        );
    }

    // Get user purchase history
    function getUserPurchases(address user) public view returns (Purchase[] memory) {
        return userPurchases[user];
    }

    // Get game currency details
    function getGameCurrency(string memory gameId) public view returns (GameCurrency memory) {
        require(gameCurrencies[gameId].isActive, "Game currency does not exist");
        return gameCurrencies[gameId];
    }

    // Withdraw contract balance (only owner)
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Get contract balance
    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }
}