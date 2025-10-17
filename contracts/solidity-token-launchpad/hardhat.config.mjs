
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv"
dotenv.config()
const config = {
  solidity: "0.8.28",
  paths: {
    artifacts: "./artifacts",
    sources: "./contracts",
    cache: "./cache",
    tests: "./test"
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL ,  
      accounts:[process.env.PRIVATE_KEY],  
    },
  },
};

export default config;
