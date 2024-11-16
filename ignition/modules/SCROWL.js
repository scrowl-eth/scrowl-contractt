const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("SCROWL", (m) => {
  const nft = m.contract("SCROWLAccountNFT");
  const marketplace = m.contract("SCROWLMarketplace");
  const gameTopUp = m.contract("GameTopUp");

  m.call(nft, "setMarketplace", [marketplace]);

  return { nft, marketplace, gameTopUp };
});