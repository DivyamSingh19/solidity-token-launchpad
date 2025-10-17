// CommonJS syntax
import hre from "hardhat"
import dotenv from "dotenv"
import fs from "fs-extra"

dotenv.config();

async function main() {
  // Get the ethers from hardhat runtime environment
  const { ethers } = hre;
  
  // Get deployer account from configured network
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  let existingEnvData = "";
  try {
    existingEnvData = fs.readFileSync(".env", "utf8");
  } catch (error) {
    console.warn("No existing .env file found. Creating a new one.");
  }

  let newEnvData = "";

  // Deploy NFT contract first
  try {
    console.log(`🚀 Deploying NFT to Sepolia...`);
    const NFT = await ethers.getContractFactory("NFT");
    const nft = await NFT.deploy();
    await nft.deployed();
    console.log(`✅ NFT deployed at: ${nft.address}`);
    newEnvData += `NFT_ADDRESS=${nft.address}\n`;
  } catch (error) {
    console.error(`❌ Error deploying NFT:`, error);
    throw error;
  }

  // Deploy Marketplace with constructor arguments
  try {
    console.log(`🚀 Deploying Marketplace to Sepolia...`);
    const feePercent = 1; // Set your fee percentage here (e.g., 1 for 1%)
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = await Marketplace.deploy(feePercent);
    await marketplace.deployed();
    console.log(`✅ Marketplace deployed at: ${marketplace.address}`);
    newEnvData += `MARKETPLACE_ADDRESS=${marketplace.address}\n`;
    newEnvData += `FEE_PERCENT=${feePercent}\n`;
  } catch (error) {
    console.error(`❌ Error deploying Marketplace:`, error);
    throw error;
  }

  const updatedEnvData = existingEnvData + "\n" + newEnvData;
  fs.writeFileSync(".env", updatedEnvData);
  console.log("\n✅ All contract addresses saved to .env!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });