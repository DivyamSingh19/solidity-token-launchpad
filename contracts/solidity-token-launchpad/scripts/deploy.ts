import hre from "hardhat";
import dotenv from "dotenv";
import fs from "fs-extra";

dotenv.config();

async function main() {
    const { ethers } = hre;
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying contracts with the account: ${deployer.address}`);
  
    let existingEnvData = "";
    try {
      existingEnvData = fs.readFileSync(".env", "utf8");
    } catch (error) {
      console.warn("No existing .env file found. Creating a new one.");
    }
  
    let newEnvData = "";
  
    const contractsToDeploy = [
      { name: "lauchpad", args: [] },
       { name: "token", args: [] },
      // { name: "ResultManager", args: [] },
      // { name: "SubmissionManager", args: [] },
      // { name: "zkSync", args: [] }
    ];
  
    for (const contract of contractsToDeploy) {
      try {
        console.log(`🚀 Deploying ${contract.name}...`);
        const ContractFactory = await ethers.getContractFactory(contract.name);
        const instance = await ContractFactory.deploy(...contract.args);
        
        
        await instance.waitForDeployment();
        
        // Get the contract address
        const address = await instance.getAddress();
        
        console.log(`✅ ${contract.name} deployed at: ${address}`);
        newEnvData += `${contract.name.toUpperCase()}_ADDRESS=${address}\n`;
      } catch (error) {
        console.error(`❌ Error deploying ${contract.name}:`, error);
        throw error;
      }
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
