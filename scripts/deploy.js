async function main() {
    // Deploy NFT contract
    const SCROWLAccountNFT = await ethers.getContractFactory("SCROWLAccountNFT");
    const nft = await SCROWLAccountNFT.deploy();
    await nft.waitForDeployment();
    console.log("SCROWLAccountNFT deployed to:", await nft.getAddress());
  
    // Deploy Marketplace
    const SCROWLMarketplace = await ethers.getContractFactory("SCROWLMarketplace");
    const marketplace = await SCROWLMarketplace.deploy();
    await marketplace.waitForDeployment();
    console.log("SCROWLMarketplace deployed to:", await marketplace.getAddress());
  
    // Set marketplace in NFT contract
    await nft.setMarketplace(await marketplace.getAddress());
    console.log("Marketplace set in NFT contract");
  
    // Verify contracts
    try {
      await run("verify:verify", {
        address: await nft.getAddress(),
        contract: "contracts/SCROWLAccountNFT.sol:SCROWLAccountNFT"
      });
  
      await run("verify:verify", {
        address: await marketplace.getAddress(),
        contract: "contracts/SCROWLMarketplace.sol:SCROWLMarketplace"
      });
    } catch (e) {
      console.log("Verification error:", e);
    }
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });