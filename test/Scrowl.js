// test/SCROWL.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");
const crypto = require('crypto');

class CredentialEncryption {
    static generateKey() {
        return crypto.randomBytes(32);
    }

    static encrypt(data, key) {
        const iv = crypto.randomBytes(16);
        const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
        let encrypted = cipher.update(JSON.stringify(data), 'utf8', 'hex');
        encrypted += cipher.final('hex');
        return {
            iv: iv.toString('hex'),
            encrypted: encrypted
        };
    }

    static decrypt(encryptedData, key) {
        const decipher = crypto.createDecipheriv(
            'aes-256-cbc',
            key,
            Buffer.from(encryptedData.iv, 'hex')
        );
        let decrypted = decipher.update(encryptedData.encrypted, 'hex', 'utf8');
        decrypted += decipher.final('utf8');
        return JSON.parse(decrypted);
    }
}

describe("SCROWL Complete System Test", function() {
    let accountNFT;
    let marketplace;
    let owner;
    let seller;
    let buyer;
    let encryptionKey;

    const testCredentials = {
        email: "player@game.com",
        password: "secure123!",
        gameId: "GAME123",
        listingPrice: ethers.parseEther("0.1")
    };

    beforeEach(async function() {
        [owner, seller, buyer] = await ethers.getSigners();
        
        const SCROWLAccountNFT = await ethers.getContractFactory("SCROWLAccountNFT");
        accountNFT = await SCROWLAccountNFT.deploy();
    
        const SCROWLMarketplace = await ethers.getContractFactory("SCROWLMarketplace");
        marketplace = await SCROWLMarketplace.deploy();
    
        // Set marketplace address
        await accountNFT.setMarketplace(marketplace.getAddress());
    
        encryptionKey = CredentialEncryption.generateKey();
    });

    describe("NFT Contract Tests", function() {
        it("Should mint game account NFT with encrypted credentials", async function() {
            const credentials = {
                email: testCredentials.email,
                password: testCredentials.password
            };
            const encrypted = CredentialEncryption.encrypt(credentials, encryptionKey);
            
            await accountNFT.connect(seller).mintGameAccount(
                JSON.stringify(encrypted),
                testCredentials.gameId,
                testCredentials.listingPrice,
                "ipfs://metadata"
            );

            expect(await accountNFT.ownerOf(1)).to.equal(seller.address);
            
            const details = await accountNFT.getGameAccountDetails(1);
            expect(details.gameId).to.equal(testCredentials.gameId);
            expect(details.listingPrice).to.equal(testCredentials.listingPrice);
            expect(details.isClaimed).to.equal(false);
            expect(details.claimer).to.equal(ethers.ZeroAddress);
        });

        it("Should prevent unauthorized access to credentials", async function() {
            const credentials = {
                email: testCredentials.email,
                password: testCredentials.password
            };
            const encrypted = CredentialEncryption.encrypt(credentials, encryptionKey);
            
            await accountNFT.connect(seller).mintGameAccount(
                JSON.stringify(encrypted),
                testCredentials.gameId,
                testCredentials.listingPrice,
                "ipfs://metadata"
            );

            await expect(
                accountNFT.connect(buyer).getEncryptedData(1)
            ).to.be.revertedWith("Not authorized");
        });

        it("Should update listing price", async function() {
            const credentials = {
                email: testCredentials.email,
                password: testCredentials.password
            };
            const encrypted = CredentialEncryption.encrypt(credentials, encryptionKey);
            
            await accountNFT.connect(seller).mintGameAccount(
                JSON.stringify(encrypted),
                testCredentials.gameId,
                testCredentials.listingPrice,
                "ipfs://metadata"
            );

            const newPrice = ethers.parseEther("0.2");
            await accountNFT.connect(seller).updateListingPrice(1, newPrice);
            
            const details = await accountNFT.getGameAccountDetails(1);
            expect(details.listingPrice).to.equal(newPrice);
        });
    });

    describe("Marketplace Contract Tests", function() {
        beforeEach(async function() {
            const credentials = {
                email: testCredentials.email,
                password: testCredentials.password
            };
            const encrypted = CredentialEncryption.encrypt(credentials, encryptionKey);
            
            await accountNFT.connect(seller).mintGameAccount(
                JSON.stringify(encrypted),
                testCredentials.gameId,
                testCredentials.listingPrice,
                "ipfs://metadata"
            );
            
            await accountNFT.connect(seller).approve(marketplace.getAddress(), 1);
        });

        it("Should list account for sale", async function() {
            await marketplace.connect(seller).listAccount(
                await accountNFT.getAddress(),
                1,
                testCredentials.listingPrice,
                "seller.eth"
            );

            const listing = await marketplace.getListing(1);
            expect(listing.seller).to.equal(seller.address);
            expect(listing.price).to.equal(testCredentials.listingPrice);
            expect(listing.isActive).to.be.true;
            expect(listing.isSold).to.be.false;
        });

            // it("Should execute purchase and transfer", async function() {
            //     await marketplace.connect(seller).listAccount(
            //         await accountNFT.getAddress(),
            //         1,
            //         testCredentials.listingPrice,
            //         "seller.eth"
            //     );

            //     const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);

            //     await marketplace.connect(buyer).buyAccount(1, {
            //         value: testCredentials.listingPrice
            //     });

            //     await marketplace.connect(buyer).confirmReceiptAndClaim(1);

            //     expect(await accountNFT.ownerOf(1)).to.equal(buyer.address);
                
            //     const sellerBalanceAfter = await ethers.provider.getBalance(seller.address);
            //     expect(sellerBalanceAfter - sellerBalanceBefore).to.equal(testCredentials.listingPrice);

            //     const details = await accountNFT.getGameAccountDetails(1);
            //     expect(details.isClaimed).to.be.true;
            //     expect(details.claimer).to.equal(buyer.address);
            // });
            it("Should execute purchase and transfer", async function() {
                // Setup: Grant approval to marketplace
                await accountNFT.connect(seller).setApprovalForAll(marketplace.getAddress(), true);
                
                // List account
                await marketplace.connect(seller).listAccount(
                    await accountNFT.getAddress(),
                    1,
                    testCredentials.listingPrice,
                    "seller.eth"
                );
            
                // Record initial balances
                const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);
                const buyerBalanceBefore = await ethers.provider.getBalance(buyer.address);
            
                // Buy account
                const buyTx = await marketplace.connect(buyer).buyAccount(1, {
                    value: testCredentials.listingPrice
                });
                const buyReceipt = await buyTx.wait();
                const buyGasUsed = buyReceipt.gasUsed * buyReceipt.gasPrice;
            
                // Confirm and claim
                const claimTx = await marketplace.connect(buyer).confirmReceiptAndClaim(1);
                const claimReceipt = await claimTx.wait();
                const claimGasUsed = claimReceipt.gasUsed * claimReceipt.gasPrice;
            
                // Verify ownership transfer
                expect(await accountNFT.ownerOf(1)).to.equal(buyer.address);
                
                // Verify seller received payment
                const sellerBalanceAfter = await ethers.provider.getBalance(seller.address);
                expect(sellerBalanceAfter).to.equal(sellerBalanceBefore + testCredentials.listingPrice);
            
                // Verify buyer balance changes (price + gas)
                const expectedBuyerBalance = buyerBalanceBefore - testCredentials.listingPrice - buyGasUsed - claimGasUsed;
                expect(await ethers.provider.getBalance(buyer.address)).to.be.closeTo(
                    expectedBuyerBalance,
                    ethers.parseEther("0.0001") // Allow small deviation for gas estimation
                );
            
                // Verify claim status
                const details = await accountNFT.getGameAccountDetails(1);
                expect(details.isClaimed).to.be.true;
                expect(details.claimer).to.equal(buyer.address);
            });

        it("Should handle listing cancellation", async function() {
            await marketplace.connect(seller).listAccount(
                await accountNFT.getAddress(),
                1,
                testCredentials.listingPrice,
                "seller.eth"
            );

            await marketplace.connect(seller).cancelListing(1);

            const listing = await marketplace.getListing(1);
            expect(listing.isActive).to.be.false;
        });

        it("Should handle disputes", async function() {
            await marketplace.connect(seller).listAccount(
                await accountNFT.getAddress(),
                1,
                testCredentials.listingPrice,
                "seller.eth"
            );

            await marketplace.connect(buyer).buyAccount(1, {
                value: testCredentials.listingPrice
            });

            await expect(marketplace.connect(buyer).initiateDispute(1))
                .to.emit(marketplace, "DisputeInitiated")
                .withArgs(1, buyer.address);
        });

        it("Should verify credential decryption after transfer", async function() {
            await marketplace.connect(seller).listAccount(
                await accountNFT.getAddress(),
                1,
                testCredentials.listingPrice,
                "seller.eth"
            );

            await marketplace.connect(buyer).buyAccount(1, {
                value: testCredentials.listingPrice
            });

            await marketplace.connect(buyer).confirmReceiptAndClaim(1);

            const encryptedData = JSON.parse(await accountNFT.connect(buyer).getEncryptedData(1));
            const decrypted = CredentialEncryption.decrypt(encryptedData, encryptionKey);

            expect(decrypted.email).to.equal(testCredentials.email);
            expect(decrypted.password).to.equal(testCredentials.password);
        });

        it("Should prevent multiple claims", async function() {
            await marketplace.connect(seller).listAccount(
                await accountNFT.getAddress(),
                1,
                testCredentials.listingPrice,
                "seller.eth"
            );

            await marketplace.connect(buyer).buyAccount(1, {
                value: testCredentials.listingPrice
            });

            await marketplace.connect(buyer).confirmReceiptAndClaim(1);

            await expect(accountNFT.connect(buyer).claimCredentials(1))
                .to.be.revertedWith("Already claimed");
        });

        it("Should handle invalid purchase attempts", async function() {
            await marketplace.connect(seller).listAccount(
                await accountNFT.getAddress(),
                1,
                testCredentials.listingPrice,
                "seller.eth"
            );

            await expect(marketplace.connect(buyer).buyAccount(1, {
                value: ethers.parseEther("0.05")
            })).to.be.revertedWith("Wrong price");
        });
    });
});