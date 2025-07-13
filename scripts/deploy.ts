import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import fs from "fs";
import path from "path";

interface DeploymentConfig {
  network: string;
  owner: string;
  treasuryWallet: string;
  teamWallet: string;
  liquidityWallet: string;
  developmentWallet: string;
  usdtAddress: string;
  usdcAddress: string;
  bnbUsdPriceFeed: string;
  usdtUsdPriceFeed: string;
  usdcUsdPriceFeed: string;
  presaleConfig: {
    startTime: number;
    endTime: number;
    hardCap: string;
    maxTokensForSale: string;
    minPurchaseAmount: string;
    maxPurchaseAmount: string;
    initialPrice: string;
    priceIncreaseRate: number;
    kycRequired: boolean;
    whitelistEnabled: boolean;
  };
}

interface DeployedContracts {
  epcsToken: string;
  priceOracle: string;
  securityManager: string;
  presaleContract: string;
}

class EpicStarterDeployer {
  private config: DeploymentConfig;
  private deployed: Partial<DeployedContracts> = {};
  private deploymentLog: string[] = [];

  constructor(config: DeploymentConfig) {
    this.config = config;
  }

  async deploy(): Promise<DeployedContracts> {
    console.log("🚀 Starting EpicStarter Presale Deployment...");
    console.log(`📡 Network: ${this.config.network}`);
    console.log(`👤 Owner: ${this.config.owner}`);

    this.log("=".repeat(60));
    this.log("EPICSTARTER PRESALE DEPLOYMENT STARTED");
    this.log("=".repeat(60));

    try {
      // Step 1: Deploy EPCS Token
      await this.deployEPCSToken();

      // Step 2: Deploy Price Oracle
      await this.deployPriceOracle();

      // Step 3: Deploy Security Manager
      await this.deploySecurityManager();

      // Step 4: Deploy Presale Contract
      await this.deployPresaleContract();

      // Step 5: Configure contracts
      await this.configureContracts();

      // Step 6: Verify contracts
      await this.verifyContracts();

      // Step 7: Save deployment info
      await this.saveDeploymentInfo();

      console.log("✅ Deployment completed successfully!");

      this.log("=".repeat(60));
      this.log("DEPLOYMENT COMPLETED SUCCESSFULLY");
      this.log("=".repeat(60));

      return this.deployed as DeployedContracts;

    } catch (error) {
      console.error("❌ Deployment failed:", error);
      this.log(`ERROR: ${error}`);
      throw error;
    }
  }

  private async deployEPCSToken(): Promise<void> {
    console.log("\n📄 Deploying EPCS Token...");
    this.log("\n1. DEPLOYING EPCS TOKEN");

    const EPCSToken: ContractFactory = await ethers.getContractFactory("EPCSToken");

    const epcsToken = await EPCSToken.deploy(
      this.config.owner,
      this.config.treasuryWallet,
      this.config.developmentWallet,
      this.config.liquidityWallet
    );

    await epcsToken.waitForDeployment();
    const address = await epcsToken.getAddress();

    this.deployed.epcsToken = address;

    console.log(`✅ EPCS Token deployed to: ${address}`);
    this.log(`   EPCS Token: ${address}`);

    // Wait for confirmations
    console.log("⏳ Waiting for confirmations...");
    await epcsToken.deploymentTransaction()?.wait(3);
    console.log("✅ Confirmed!");
  }

  private async deployPriceOracle(): Promise<void> {
    console.log("\n📊 Deploying Price Oracle...");
    this.log("\n2. DEPLOYING PRICE ORACLE");

    const PriceOracle: ContractFactory = await ethers.getContractFactory("PriceOracle");

    const priceOracle = await PriceOracle.deploy(this.config.owner);
    await priceOracle.waitForDeployment();
    const address = await priceOracle.getAddress();

    this.deployed.priceOracle = address;

    console.log(`✅ Price Oracle deployed to: ${address}`);
    this.log(`   Price Oracle: ${address}`);

    // Configure price feeds
    console.log("🔧 Configuring price feeds...");

    const oracle = await ethers.getContractAt("PriceOracle", address);

    // Add BNB/USD price feed
    if (this.config.bnbUsdPriceFeed !== "0x0000000000000000000000000000000000000000") {
      await oracle.addPriceFeed(
        "0x0000000000000000000000000000000000000000", // BNB address
        this.config.bnbUsdPriceFeed,
        3600 // 1 hour heartbeat
      );
      console.log("✅ BNB/USD price feed configured");
    }

    // Add USDT/USD price feed
    if (this.config.usdtUsdPriceFeed !== "0x0000000000000000000000000000000000000000") {
      await oracle.addPriceFeed(
        this.config.usdtAddress,
        this.config.usdtUsdPriceFeed,
        3600
      );
      console.log("✅ USDT/USD price feed configured");
    }

    // Add USDC/USD price feed
    if (this.config.usdcUsdPriceFeed !== "0x0000000000000000000000000000000000000000") {
      await oracle.addPriceFeed(
        this.config.usdcAddress,
        this.config.usdcUsdPriceFeed,
        3600
      );
      console.log("✅ USDC/USD price feed configured");
    }

    await oracle.deploymentTransaction()?.wait(3);
  }

  private async deploySecurityManager(): Promise<void> {
    console.log("\n🛡️ Deploying Security Manager...");
    this.log("\n3. DEPLOYING SECURITY MANAGER");

    const SecurityManager: ContractFactory = await ethers.getContractFactory("SecurityManager");

    const securityManager = await SecurityManager.deploy(this.config.owner);
    await securityManager.waitForDeployment();
    const address = await securityManager.getAddress();

    this.deployed.securityManager = address;

    console.log(`✅ Security Manager deployed to: ${address}`);
    this.log(`   Security Manager: ${address}`);

    await securityManager.deploymentTransaction()?.wait(3);
  }

  private async deployPresaleContract(): Promise<void> {
    console.log("\n🎯 Deploying Presale Contract...");
    this.log("\n4. DEPLOYING PRESALE CONTRACT");

    const EpicStarterPresale: ContractFactory = await ethers.getContractFactory("EpicStarterPresale");

    const presale = await EpicStarterPresale.deploy(
      this.config.owner,
      this.deployed.epcsToken!,
      this.deployed.priceOracle!,
      this.deployed.securityManager!,
      this.config.usdtAddress,
      this.config.usdcAddress,
      this.config.treasuryWallet
    );

    await presale.waitForDeployment();
    const address = await presale.getAddress();

    this.deployed.presaleContract = address;

    console.log(`✅ Presale Contract deployed to: ${address}`);
    this.log(`   Presale Contract: ${address}`);

    await presale.deploymentTransaction()?.wait(3);
  }

  private async configureContracts(): Promise<void> {
    console.log("\n⚙️ Configuring contracts...");
    this.log("\n5. CONFIGURING CONTRACTS");

    // Configure EPCS Token
    const epcsToken = await ethers.getContractAt("EPCSToken", this.deployed.epcsToken!);

    // Set presale contract as authorized minter
    await epcsToken.updateAuthorizedMinter(this.deployed.presaleContract!, true);
    console.log("✅ Presale contract authorized as minter");

    // Update presale contract address in token
    await epcsToken.updatePresaleContract(this.deployed.presaleContract!);
    console.log("✅ Presale contract address set in token");

    // Exclude presale contract from fees and reflection
    await epcsToken.excludeFromFee(this.deployed.presaleContract!, true);
    await epcsToken.excludeFromReflection(this.deployed.presaleContract!, true);
    console.log("✅ Presale contract excluded from fees and reflection");

    // Configure Security Manager
    const securityManager = await ethers.getContractAt("SecurityManager", this.deployed.securityManager!);

    // Add presale contract as security operator
    await securityManager.addSecurityOperator(this.deployed.presaleContract!);
    console.log("✅ Presale contract added as security operator");

    // Configure Presale Contract
    const presale = await ethers.getContractAt("EpicStarterPresale", this.deployed.presaleContract!);

    // Update presale configuration
    await presale.updatePresaleConfig({
      startTime: this.config.presaleConfig.startTime,
      endTime: this.config.presaleConfig.endTime,
      hardCap: ethers.parseEther(this.config.presaleConfig.hardCap),
      maxTokensForSale: ethers.parseEther(this.config.presaleConfig.maxTokensForSale),
      minPurchaseAmount: ethers.parseEther(this.config.presaleConfig.minPurchaseAmount),
      maxPurchaseAmount: ethers.parseEther(this.config.presaleConfig.maxPurchaseAmount),
      initialPrice: ethers.parseEther(this.config.presaleConfig.initialPrice),
      priceIncreaseRate: this.config.presaleConfig.priceIncreaseRate,
      kycRequired: this.config.presaleConfig.kycRequired,
      whitelistEnabled: this.config.presaleConfig.whitelistEnabled,
      paused: false
    });
    console.log("✅ Presale configuration updated");

    // Transfer tokens to presale contract
    const tokenAmount = ethers.parseEther(this.config.presaleConfig.maxTokensForSale);
    await epcsToken.transfer(this.deployed.presaleContract!, tokenAmount);
    console.log("✅ Tokens transferred to presale contract");

    this.log("   All contracts configured successfully");
  }

  private async verifyContracts(): Promise<void> {
    if (process.env.VERIFY_CONTRACTS !== "true") {
      console.log("\n⏭️ Skipping contract verification (VERIFY_CONTRACTS not set to true)");
      return;
    }

    console.log("\n🔍 Verifying contracts...");
    this.log("\n6. VERIFYING CONTRACTS");

    try {
      // Verify EPCS Token
      console.log("Verifying EPCS Token...");
      await this.verifyContract(
        this.deployed.epcsToken!,
        [
          this.config.owner,
          this.config.treasuryWallet,
          this.config.developmentWallet,
          this.config.liquidityWallet
        ]
      );

      // Verify Price Oracle
      console.log("Verifying Price Oracle...");
      await this.verifyContract(
        this.deployed.priceOracle!,
        [this.config.owner]
      );

      // Verify Security Manager
      console.log("Verifying Security Manager...");
      await this.verifyContract(
        this.deployed.securityManager!,
        [this.config.owner]
      );

      // Verify Presale Contract
      console.log("Verifying Presale Contract...");
      await this.verifyContract(
        this.deployed.presaleContract!,
        [
          this.config.owner,
          this.deployed.epcsToken!,
          this.deployed.priceOracle!,
          this.deployed.securityManager!,
          this.config.usdtAddress,
          this.config.usdcAddress,
          this.config.treasuryWallet
        ]
      );

      console.log("✅ All contracts verified successfully!");
      this.log("   All contracts verified successfully");

    } catch (error) {
      console.log("⚠️ Contract verification failed:", error);
      this.log(`   Verification failed: ${error}`);
    }
  }

  private async verifyContract(address: string, constructorArguments: any[]): Promise<void> {
    try {
      const { run } = require("hardhat");
      await run("verify:verify", {
        address: address,
        constructorArguments: constructorArguments,
      });
    } catch (error: any) {
      if (error.message.includes("already verified")) {
        console.log(`✅ Contract ${address} already verified`);
      } else {
        throw error;
      }
    }
  }

  private async saveDeploymentInfo(): Promise<void> {
    console.log("\n💾 Saving deployment information...");
    this.log("\n7. SAVING DEPLOYMENT INFO");

    const deploymentInfo = {
      network: this.config.network,
      timestamp: new Date().toISOString(),
      deployer: this.config.owner,
      contracts: this.deployed,
      configuration: this.config,
      gasUsed: await this.calculateTotalGasUsed(),
      transactionHashes: await this.getTransactionHashes()
    };

    // Save to JSON file
    const fileName = `deployment-${this.config.network}-${Date.now()}.json`;
    const filePath = path.join(__dirname, "../deployments", fileName);

    // Create deployments directory if it doesn't exist
    const deploymentsDir = path.dirname(filePath);
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2));
    console.log(`✅ Deployment info saved to: ${filePath}`);

    // Save deployment log
    const logFileName = `deployment-log-${this.config.network}-${Date.now()}.txt`;
    const logFilePath = path.join(deploymentsDir, logFileName);
    fs.writeFileSync(logFilePath, this.deploymentLog.join('\n'));
    console.log(`✅ Deployment log saved to: ${logFilePath}`);

    // Update latest deployment file
    const latestFilePath = path.join(deploymentsDir, `latest-${this.config.network}.json`);
    fs.writeFileSync(latestFilePath, JSON.stringify(deploymentInfo, null, 2));
    console.log(`✅ Latest deployment updated: ${latestFilePath}`);

    this.log(`   Deployment info saved successfully`);
  }

  private async calculateTotalGasUsed(): Promise<string> {
    // This would calculate total gas used across all transactions
    // Implementation depends on tracking transaction receipts
    return "0";
  }

  private async getTransactionHashes(): Promise<string[]> {
    // This would return all transaction hashes from deployment
    // Implementation depends on tracking transactions
    return [];
  }

  private log(message: string): void {
    this.deploymentLog.push(`[${new Date().toISOString()}] ${message}`);
  }
}

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)));

  // Load configuration based on network
  const config = await loadNetworkConfig(network.name, deployer.address);

  // Deploy contracts
  const epicDeployer = new EpicStarterDeployer(config);
  const deployedContracts = await epicDeployer.deploy();

  console.log("\n🎉 DEPLOYMENT SUMMARY:");
  console.log("=".repeat(50));
  console.log(`📄 EPCS Token: ${deployedContracts.epcsToken}`);
  console.log(`📊 Price Oracle: ${deployedContracts.priceOracle}`);
  console.log(`🛡️ Security Manager: ${deployedContracts.securityManager}`);
  console.log(`🎯 Presale Contract: ${deployedContracts.presaleContract}`);
  console.log("=".repeat(50));
}

async function loadNetworkConfig(networkName: string, deployerAddress: string): Promise<DeploymentConfig> {
  const configPath = path.join(__dirname, "../config", `${networkName}.json`);

  let config: Partial<DeploymentConfig> = {};

  if (fs.existsSync(configPath)) {
    const configFile = fs.readFileSync(configPath, 'utf8');
    config = JSON.parse(configFile);
  }

  // Default configuration
  const defaultConfig: DeploymentConfig = {
    network: networkName,
    owner: deployerAddress,
    treasuryWallet: process.env.TREASURY_WALLET || deployerAddress,
    teamWallet: process.env.TEAM_WALLET || deployerAddress,
    liquidityWallet: process.env.LIQUIDITY_WALLET || deployerAddress,
    developmentWallet: process.env.DEVELOPMENT_WALLET || deployerAddress,
    usdtAddress: process.env.USDT_ADDRESS || "0x55d398326f99059fF775485246999027B3197955",
    usdcAddress: process.env.USDC_ADDRESS || "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d",
    bnbUsdPriceFeed: process.env.BNB_USD_PRICE_FEED || "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE",
    usdtUsdPriceFeed: process.env.USDT_USD_PRICE_FEED || "0xB97Ad0E74fa7d920791E90258A6E2085088b4320",
    usdcUsdPriceFeed: process.env.USDC_USD_PRICE_FEED || "0x51597f405303C4377E36123cBc172b13269EA163",
    presaleConfig: {
      startTime: parseInt(process.env.PRESALE_START_TIME || String(Math.floor(Date.now() / 1000) + 3600)),
      endTime: parseInt(process.env.PRESALE_END_TIME || String(Math.floor(Date.now() / 1000) + 30 * 24 * 3600)),
      hardCap: process.env.HARD_CAP || "5000000000",
      maxTokensForSale: process.env.MAX_TOKENS_FOR_SALE || "100000000",
      minPurchaseAmount: process.env.MIN_PURCHASE_AMOUNT || "10",
      maxPurchaseAmount: process.env.MAX_PURCHASE_AMOUNT || "100000",
      initialPrice: process.env.INITIAL_PRICE || "1",
      priceIncreaseRate: parseInt(process.env.PRICE_INCREASE_RATE || "100"),
      kycRequired: process.env.KYC_REQUIRED === "true",
      whitelistEnabled: process.env.WHITELIST_ENABLED === "true"
    }
  };

  // Merge configurations
  return { ...defaultConfig, ...config } as DeploymentConfig;
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export { EpicStarterDeployer, loadNetworkConfig };
export type { DeploymentConfig, DeployedContracts };
