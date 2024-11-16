require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.27",
  networks: {
    scrollSepolia: {
      url: "https://sepolia-rpc.scroll.io",
      accounts: ["6f04f80b5b4bc88558d097d8db62f35cf3851a939a1d661a827640d0befd2639"],
      chainId: 534351
    }
  },
  etherscan: {
    apiKey: {
      scrollSepolia: "YY54XQNRG72ZGWN3KBXP1FE93FSZ561CGK"
    },
    customChains: [
      {
        network: "scrollSepolia",
        chainId: 534351,
        urls: {
          apiURL: 'https://api-sepolia.scrollscan.com/api',
          browserURL: 'https://sepolia.scrollscan.com/',
        }
      }
    ]
  }
};
