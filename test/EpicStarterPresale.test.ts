import { expect } from "chai";
import { ethers } from "hardhat";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import {
  EpicStarterPresale,
  EPCSToken,
  PriceOracle,
  SecurityManager,
  MockERC20,
  MockV3Aggregator
} from "../typechain-types";

describe("EpicStarter Presale System", function () {
  // Constants
  const INITIAL_PRICE = ethers.parseEther("1"); // $1
  const HARD_CAP = ethers.parseEther("5000000000"); // $5B
  const MAX_TOKENS = ethers.parseEther("100000000"); // 100M tokens
  const MIN_PURCHASE = ethers.parseEther("10"); // $10
  const MAX_PURCHASE = ethers.parseEther("100000"); // $100k
  const PRICE_INCREASE_RATE = 100; // 1%

  // Test fixture
  async function deployPresaleSystemFixture() {
    const [owner, treasury, team, liquidity, development, user1, user2, user3, user4] = await ethers.getSigners();

    // Deploy mock price feeds
    const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");

    const bnbPriceFeed = await MockV3Aggregator.deploy(8, ethers.parseUnits("300", 8)); // $300
    const usdtPriceFeed = await MockV3Aggregator.deploy(8, ethers.parseUnits("1", 8)); // $1
    const usdcPriceFeed = await MockV3Aggregator.deploy(8, ethers.parseUnits("1", 8)); // $1

    // Deploy mock tokens
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const usdt = await MockERC20.deploy("Tether USD", "USDT", 18);
    const usdc = await MockERC20.deploy("USD Coin", "USDC", 18);

    // Mint tokens to users
    await usdt.mint(user1.address, ethers.parseEther("1000000"));
    await usdt.mint(user2.address, ethers.parseEther("1000000"));
    await usdt.mint(user3.address, ethers.parseEther("1000000"));
    await usdt.mint(user4.address, ethers.parseEther("1000000"));

    await usdc.mint(user1.address, ethers.parseEther("1000000"));
    await usdc.mint(user2.address, ethers.parseEther("1000000"));
    await usdc.mint(user3.address, ethers.parseEther("1000000"));
    await usdc.mint(user4.address, ethers.parseEther("1000000"));

    // Deploy EPCS Token
    const EPCSToken = await ethers.getContractFactory("EPCSToken");
    const epcsToken = await EPCSToken.deploy(
      owner.address,
      treasury.address,
      development.address,
      liquidity.address
    );

    // Deploy Price Oracle
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const priceOracle = await PriceOracle.deploy(owner.address);

    // Configure price feeds
    await priceOracle.addPriceFeed(
      ethers.ZeroAddress, // BNB
      await bnbPriceFeed.getAddress(),
      3600
    );
    await priceOracle.addPriceFeed(
      await usdt.getAddress(),
      await usdtPriceFeed.getAddress(),
      3600
    );
    await priceOracle.addPriceFeed(
      await usdc.getAddress(),
      await usdcPriceFeed.getAddress(),
      3600
    );

    // Deploy Security Manager
    const SecurityManager = await ethers.getContractFactory("SecurityManager");
    const securityManager = await SecurityManager.deploy(owner.address);

    // Deploy Presale Contract
    const EpicStarterPresale = await ethers.getContractFactory("EpicStarterPresale");
    const presale = await EpicStarterPresale.deploy(
      owner.address,
      await epcsToken.getAddress(),
      await priceOracle.getAddress(),
      await securityManager.getAddress(),
      await usdt.getAddress(),
      await usdc.getAddress(),
      treasury.address
    );

    // Configure contracts
    await epcsToken.updateAuthorizedMinter(await presale.getAddress(), true);
    await epcsToken.updatePresaleContract(await presale.getAddress());
    await epcsToken.excludeFromFee(await presale.getAddress(), true);
    await securityManager.addSecurityOperator(await presale.getAddress());

    // Configure presale
    const startTime = (await time.latest()) + 3600; // 1 hour from now
    const endTime = startTime + (30 * 24 * 3600); // 30 days

    await presale.updatePresaleConfig({
      startTime,
      endTime,
      hardCap: HARD_CAP,
      maxTokensForSale: MAX_TOKENS,
      minPurchaseAmount: MIN_PURCHASE,
      maxPurchaseAmount: MAX_PURCHASE,
      initialPrice: INITIAL_PRICE,
      priceIncreaseRate: PRICE_INCREASE_RATE,
      kycRequired: false,
      whitelistEnabled: false,
      paused: false
    });

    // Transfer tokens to presale contract
    await epcsToken.transfer(await presale.getAddress(), MAX_TOKENS);

    return {
      owner,
      treasury,
      team,
      liquidity,
      development,
      user1,
      user2,
      user3,
      user4,
      epcsToken,
      priceOracle,
      securityManager,
      presale,
      usdt,
      usdc,
      bnbPriceFeed,
      usdtPriceFeed,
      usdcPriceFeed,
      startTime,
      endTime
    };
  }

  describe("Deployment", function () {
    it("Should deploy all contracts successfully", async function () {
      const { presale, epcsToken, priceOracle, securityManager } = await loadFixture(deployPresaleSystemFixture);

      expect(await presale.getAddress()).to.be.properAddress;
      expect(await epcsToken.getAddress()).to.be.properAddress;
      expect(await priceOracle.getAddress()).to.be.properAddress;
      expect(await securityManager.getAddress()).to.be.properAddress;
    });

    it("Should have correct initial configuration", async function () {
      const { presale, owner, treasury } = await loadFixture(deployPresaleSystemFixture);

      const config = await presale.presaleConfig();
      expect(config.hardCap).to.equal(HARD_CAP);
      expect(config.maxTokensForSale).to.equal(MAX_TOKENS);
      expect(config.initialPrice).to.equal(INITIAL_PRICE);
      expect(config.priceIncreaseRate).to.equal(PRICE_INCREASE_RATE);

      expect(await presale.owner()).to.equal(owner.address);
      expect(await presale.treasuryWallet()).to.equal(treasury.address);
    });

    it("Should have tokens transferred to presale contract", async function () {
      const { presale, epcsToken } = await loadFixture(deployPresaleSystemFixture);

      const balance = await epcsToken.balanceOf(await presale.getAddress());
      expect(balance).to.equal(MAX_TOKENS);
    });
  });

  describe("Price Oracle Integration", function () {
    it("Should get correct prices from oracles", async function () {
      const { priceOracle, usdt, usdc } = await loadFixture(deployPresaleSystemFixture);

      const bnbPrice = await priceOracle.getLatestPrice(ethers.ZeroAddress);
      const usdtPrice = await priceOracle.getLatestPrice(await usdt.getAddress());
      const usdcPrice = await priceOracle.getLatestPrice(await usdc.getAddress());

      expect(bnbPrice).to.equal(ethers.parseEther("300")); // $300
      expect(usdtPrice).to.equal(ethers.parseEther("1")); // $1
      expect(usdcPrice).to.equal(ethers.parseEther("1")); // $1
    });

    it("Should calculate token amounts correctly", async function () {
      const { presale, usdt } = await loadFixture(deployPresaleSystemFixture);

      const paymentAmount = ethers.parseEther("100"); // 100 USDT
      const tokenAmount = await presale.calculateTokensToReceive(
        await usdt.getAddress(),
        paymentAmount
      );

      // 100 USDT @ $1 each = $100 USD
      // At $1 per EPCS token, should get 100 EPCS tokens
      expect(tokenAmount).to.equal(ethers.parseEther("100"));
    });
  });

  describe("Security Manager Integration", function () {
    it("Should enforce security checks", async function () {
      const { presale, securityManager, user1 } = await loadFixture(deployPresaleSystemFixture);

      // Add user to blacklist
      await securityManager.addToBlacklist([user1.address], ["Test blacklist"]);

      const [canPurchase, reason] = await presale.canPurchase(user1.address, MIN_PURCHASE);
      expect(canPurchase).to.be.false;
      expect(reason).to.include("blacklisted");
    });

    it("Should allow whitelisted users during whitelist period", async function () {
      const { presale, securityManager, user1, owner } = await loadFixture(deployPresaleSystemFixture);

      // Enable whitelist
      await presale.updatePresaleConfig({
        startTime: (await time.latest()) + 3600,
        endTime: (await time.latest()) + (30 * 24 * 3600),
        hardCap: HARD_CAP,
        maxTokensForSale: MAX_TOKENS,
        minPurchaseAmount: MIN_PURCHASE,
        maxPurchaseAmount: MAX_PURCHASE,
        initialPrice: INITIAL_PRICE,
        priceIncreaseRate: PRICE_INCREASE_RATE,
        kycRequired: false,
        whitelistEnabled: true,
        paused: false
      });

      // Add user to whitelist
      await securityManager.addToWhitelist([user1.address]);

      const [canPurchase, reason] = await presale.canPurchase(user1.address, MIN_PURCHASE);
      expect(canPurchase).to.be.true;
    });
  });

  describe("Purchase Functions", function () {
    beforeEach(async function () {
      const { startTime } = await loadFixture(deployPresaleSystemFixture);
      await time.increaseTo(startTime);
    });

    it("Should allow BNB purchases", async function () {
      const { presale, user1 } = await loadFixture(deployPresaleSystemFixture);

      const bnbAmount = ethers.parseEther("1"); // 1 BNB
      const minTokens = ethers.parseEther("250"); // Expect at least 250 tokens

      await expect(
        presale.connect(user1).buyWithBNB(minTokens, { value: bnbAmount })
      ).to.emit(presale, "TokensPurchased");

      const userBalance = await presale.getUserTokenBalance(user1.address);
      expect(userBalance).to.be.greaterThan(minTokens);
    });

    it("Should allow USDT purchases", async function () {
      const { presale, usdt, user1 } = await loadFixture(deployPresaleSystemFixture);

      const usdtAmount = ethers.parseEther("100"); // 100 USDT
      const minTokens = ethers.parseEther("90"); // Expect at least 90 tokens

      // Approve USDT spending
      await usdt.connect(user1).approve(await presale.getAddress(), usdtAmount);

      await expect(
        presale.connect(user1).buyWithUSDT(usdtAmount, minTokens)
      ).to.emit(presale, "TokensPurchased");

      const userBalance = await presale.getUserTokenBalance(user1.address);
      expect(userBalance).to.be.greaterThan(minTokens);
    });

    it("Should allow USDC purchases", async function () {
      const { presale, usdc, user1 } = await loadFixture(deployPresaleSystemFixture);

      const usdcAmount = ethers.parseEther("100"); // 100 USDC
      const minTokens = ethers.parseEther("90"); // Expect at least 90 tokens

      // Approve USDC spending
      await usdc.connect(user1).approve(await presale.getAddress(), usdcAmount);

      await expect(
        presale.connect(user1).buyWithUSDC(usdcAmount, minTokens)
      ).to.emit(presale, "TokensPurchased");

      const userBalance = await presale.getUserTokenBalance(user1.address);
      expect(userBalance).to.be.greaterThan(minTokens);
    });

    it("Should enforce minimum purchase amount", async function () {
      const { presale, user1 } = await loadFixture(deployPresaleSystemFixture);

      const smallAmount = ethers.parseEther("0.01"); // 0.01 BNB (< $10 minimum)

      await expect(
        presale.connect(user1).buyWithBNB(0, { value: smallAmount })
      ).to.be.revertedWith("Below minimum purchase");
    });

    it("Should enforce maximum purchase amount", async function () {
      const { presale, user1 } = await loadFixture(deployPresaleSystemFixture);

      const largeAmount = ethers.parseEther("1000"); // 1000 BNB (> $100k maximum)

      await expect(
        presale.connect(user1).buyWithBNB(0, { value: largeAmount })
      ).to.be.revertedWith("Exceeds maximum purchase");
    });

    it("Should handle referral purchases", async function () {
      const { presale, usdt, user1, user2 } = await loadFixture(deployPresaleSystemFixture);

      const usdtAmount = ethers.parseEther("100");
      await usdt.connect(user1).approve(await presale.getAddress(), usdtAmount);

      await expect(
        presale.connect(user1).buyWithReferral(
          await usdt.getAddress(),
          usdtAmount,
          0,
          user2.address
        )
      ).to.emit(presale, "ReferralSet");

      const [referrer, earnings] = await presale.getReferralInfo(user1.address);
      expect(referrer).to.equal(user2.address);
    });
  });

  describe("Dynamic Pricing", function () {
    beforeEach(async function () {
      const { startTime } = await loadFixture(deployPresaleSystemFixture);
      await time.increaseTo(startTime);
    });

    it("Should increase price as tokens are sold", async function () {
      const { presale, user1, user2, usdt } = await loadFixture(deployPresaleSystemFixture);

      const initialPrice = await presale.getCurrentPrice();

      // Make a large purchase to trigger price increase
      const purchaseAmount = ethers.parseEther("1000000"); // $1M
      await usdt.connect(user1).approve(await presale.getAddress(), purchaseAmount);
      await presale.connect(user1).buyWithUSDT(purchaseAmount, 0);

      const newPrice = await presale.getCurrentPrice();
      expect(newPrice).to.be.greaterThan(initialPrice);
    });

    it("Should calculate correct token amounts at different price points", async function () {
      const { presale, user1, usdt } = await loadFixture(deployPresaleSystemFixture);

      // First purchase at initial price
      const firstPurchase = ethers.parseEther("100");
      await usdt.connect(user1).approve(await presale.getAddress(), firstPurchase);
      await presale.connect(user1).buyWithUSDT(firstPurchase, 0);

      const tokensFromFirstPurchase = await presale.getUserTokenBalance(user1.address);

      // Make a large purchase to increase price
      const largePurchase = ethers.parseEther("100000");
      await usdt.connect(user1).approve(await presale.getAddress(), largePurchase);
      await presale.connect(user1).buyWithUSDT(largePurchase, 0);

      // Second purchase at higher price should give fewer tokens per dollar
      const secondPurchase = ethers.parseEther("100");
      await usdt.connect(user1).approve(await presale.getAddress(), secondPurchase);

      const balanceBeforeSecond = await presale.getUserTokenBalance(user1.address);
      await presale.connect(user1).buyWithUSDT(secondPurchase, 0);
      const balanceAfterSecond = await presale.getUserTokenBalance(user1.address);

      const tokensFromSecondPurchase = balanceAfterSecond - balanceBeforeSecond;
      expect(tokensFromSecondPurchase).to.be.lessThan(tokensFromFirstPurchase);
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to update presale config", async function () {
      const { presale, owner } = await loadFixture(deployPresaleSystemFixture);

      const newConfig = {
        startTime: (await time.latest()) + 7200,
        endTime: (await time.latest()) + (60 * 24 * 3600),
        hardCap: ethers.parseEther("10000000000"),
        maxTokensForSale: ethers.parseEther("200000000"),
        minPurchaseAmount: ethers.parseEther("20"),
        maxPurchaseAmount: ethers.parseEther("200000"),
        initialPrice: ethers.parseEther("2"),
        priceIncreaseRate: 200,
        kycRequired: true,
        whitelistEnabled: true,
        paused: false
      };

      await expect(
        presale.connect(owner).updatePresaleConfig(newConfig)
      ).to.emit(presale, "PresaleConfigUpdated");

      const updatedConfig = await presale.presaleConfig();
      expect(updatedConfig.hardCap).to.equal(newConfig.hardCap);
      expect(updatedConfig.initialPrice).to.equal(newConfig.initialPrice);
    });

    it("Should allow owner to pause/unpause presale", async function () {
      const { presale, owner, user1 } = await loadFixture(deployPresaleSystemFixture);

      await presale.connect(owner).setPaused(true);

      await expect(
        presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") })
      ).to.be.revertedWith("Presale not active");

      await presale.connect(owner).setPaused(false);
      await time.increaseTo((await loadFixture(deployPresaleSystemFixture)).startTime);

      await expect(
        presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") })
      ).to.emit(presale, "TokensPurchased");
    });

    it("Should restrict admin functions to owner", async function () {
      const { presale, user1 } = await loadFixture(deployPresaleSystemFixture);

      await expect(
        presale.connect(user1).setPaused(true)
      ).to.be.revertedWithCustomError(presale, "OwnableUnauthorizedAccount");
    });
  });

  describe("Token Claiming", function () {
    beforeEach(async function () {
      const { startTime } = await loadFixture(deployPresaleSystemFixture);
      await time.increaseTo(startTime);
    });

    it("Should allow users to claim tokens after presale ends", async function () {
      const { presale, epcsToken, user1, owner, endTime } = await loadFixture(deployPresaleSystemFixture);

      // Make a purchase
      await presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") });
      const purchasedAmount = await presale.getUserTokenBalance(user1.address);

      // End presale and enable claiming
      await time.increaseTo(endTime + 1);
      await presale.connect(owner).finalizePresale();

      // Claim tokens
      await expect(
        presale.connect(user1).claimTokens()
      ).to.emit(presale, "TokensClaimed");

      const userTokenBalance = await epcsToken.balanceOf(user1.address);
      expect(userTokenBalance).to.equal(purchasedAmount);
    });

    it("Should prevent double claiming", async function () {
      const { presale, user1, owner, endTime } = await loadFixture(deployPresaleSystemFixture);

      // Make a purchase
      await presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") });

      // End presale and enable claiming
      await time.increaseTo(endTime + 1);
      await presale.connect(owner).finalizePresale();

      // First claim should succeed
      await presale.connect(user1).claimTokens();

      // Second claim should fail
      await expect(
        presale.connect(user1).claimTokens()
      ).to.be.revertedWith("Already claimed");
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow emergency withdrawal by owner", async function () {
      const { presale, usdt, owner, user1 } = await loadFixture(deployPresaleSystemFixture);

      // Enable emergency withdraw
      await presale.connect(owner).enableEmergencyWithdraw();

      // Make a purchase to have funds in contract
      await time.increaseTo((await loadFixture(deployPresaleSystemFixture)).startTime);
      const usdtAmount = ethers.parseEther("100");
      await usdt.connect(user1).approve(await presale.getAddress(), usdtAmount);
      await presale.connect(user1).buyWithUSDT(usdtAmount, 0);

      const contractBalance = await usdt.balanceOf(await presale.getAddress());
      expect(contractBalance).to.be.greaterThan(0);

      // Emergency withdraw
      await expect(
        presale.connect(owner).emergencyWithdraw(
          await usdt.getAddress(),
          owner.address,
          contractBalance
        )
      ).to.emit(presale, "EmergencyWithdraw");
    });

    it("Should prevent emergency withdrawal when not enabled", async function () {
      const { presale, usdt, owner } = await loadFixture(deployPresaleSystemFixture);

      await expect(
        presale.connect(owner).emergencyWithdraw(
          await usdt.getAddress(),
          owner.address,
          ethers.parseEther("100")
        )
      ).to.be.revertedWith("Emergency withdraw not enabled");
    });
  });

  describe("Presale Statistics", function () {
    beforeEach(async function () {
      const { startTime } = await loadFixture(deployPresaleSystemFixture);
      await time.increaseTo(startTime);
    });

    it("Should track presale statistics correctly", async function () {
      const { presale, user1, user2, usdt } = await loadFixture(deployPresaleSystemFixture);

      // Initial stats
      let stats = await presale.getPresaleStats();
      expect(stats._totalTokensSold).to.equal(0);
      expect(stats._totalUSDRaised).to.equal(0);
      expect(stats._totalParticipants).to.equal(0);

      // First purchase
      await presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") });

      stats = await presale.getPresaleStats();
      expect(stats._totalParticipants).to.equal(1);
      expect(stats._totalTokensSold).to.be.greaterThan(0);
      expect(stats._totalUSDRaised).to.be.greaterThan(0);

      // Second purchase from different user
      const usdtAmount = ethers.parseEther("100");
      await usdt.connect(user2).approve(await presale.getAddress(), usdtAmount);
      await presale.connect(user2).buyWithUSDT(usdtAmount, 0);

      stats = await presale.getPresaleStats();
      expect(stats._totalParticipants).to.equal(2);
    });

    it("Should calculate remaining tokens and cap correctly", async function () {
      const { presale, user1 } = await loadFixture(deployPresaleSystemFixture);

      const initialStats = await presale.getPresaleStats();
      expect(initialStats._remainingTokens).to.equal(MAX_TOKENS);
      expect(initialStats._remainingCap).to.equal(HARD_CAP);

      // Make a purchase
      await presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") });

      const updatedStats = await presale.getPresaleStats();
      expect(updatedStats._remainingTokens).to.be.lessThan(MAX_TOKENS);
      expect(updatedStats._remainingCap).to.be.lessThan(HARD_CAP);
    });
  });

  describe("Anti-Bot Protection", function () {
    beforeEach(async function () {
      const { startTime } = await loadFixture(deployPresaleSystemFixture);
      await time.increaseTo(startTime);
    });

    it("Should enforce cooldown between purchases", async function () {
      const { presale, user1 } = await loadFixture(deployPresaleSystemFixture);

      // First purchase
      await presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("0.1") });

      // Second purchase immediately should fail
      await expect(
        presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("0.1") })
      ).to.be.revertedWith("Cooldown period active");

      // Wait for cooldown and try again
      await time.increase(31); // 31 seconds (cooldown is 30 seconds)

      await expect(
        presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("0.1") })
      ).to.emit(presale, "TokensPurchased");
    });
  });

  describe("Integration Tests", function () {
    beforeEach(async function () {
      const { startTime } = await loadFixture(deployPresaleSystemFixture);
      await time.increaseTo(startTime);
    });

    it("Should handle full presale lifecycle", async function () {
      const {
        presale,
        epcsToken,
        user1,
        user2,
        user3,
        owner,
        usdt,
        endTime
      } = await loadFixture(deployPresaleSystemFixture);

      // Phase 1: Multiple users make purchases
      await presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") });

      const usdtAmount = ethers.parseEther("500");
      await usdt.connect(user2).approve(await presale.getAddress(), usdtAmount);
      await presale.connect(user2).buyWithUSDT(usdtAmount, 0);

      await time.increase(31); // Wait for cooldown
      await presale.connect(user3).buyWithBNB(0, { value: ethers.parseEther("2") });

      // Verify purchases recorded
      const stats = await presale.getPresaleStats();
      expect(stats._totalParticipants).to.equal(3);
      expect(stats._totalTokensSold).to.be.greaterThan(0);

      // Phase 2: End presale and finalize
      await time.increaseTo(endTime + 1);
      await presale.connect(owner).finalizePresale();

      // Phase 3: Users claim tokens
      await presale.connect(user1).claimTokens();
      await presale.connect(user2).claimTokens();
      await presale.connect(user3).claimTokens();

      // Verify final state
      const user1Balance = await epcsToken.balanceOf(user1.address);
      const user2Balance = await epcsToken.balanceOf(user2.address);
      const user3Balance = await epcsToken.balanceOf(user3.address);

      expect(user1Balance).to.be.greaterThan(0);
      expect(user2Balance).to.be.greaterThan(0);
      expect(user3Balance).to.be.greaterThan(0);
    });

    it("Should handle edge cases and error conditions", async function () {
      const { presale, user1, owner } = await loadFixture(deployPresaleSystemFixture);

      // Test purchase before presale starts
      await time.setNextBlockTimestamp((await time.latest()) - 7200); // 2 hours ago
      await expect(
        presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") })
      ).to.be.revertedWith("Presale not active");

      // Test claiming before enabled
      await expect(
        presale.connect(user1).claimTokens()
      ).to.be.revertedWith("Claiming not enabled");

      // Test finalization before presale ends
      await expect(
        presale.connect(owner).finalizePresale()
      ).to.be.revertedWith("Presale still active");
    });
  });

  describe("Gas Optimization Tests", function () {
    beforeEach(async function () {
      const { startTime } = await loadFixture(deployPresaleSystemFixture);
      await time.increaseTo(startTime);
    });

    it("Should have reasonable gas costs for purchases", async function () {
      const { presale, user1 } = await loadFixture(deployPresaleSystemFixture);

      const tx = await presale.connect(user1).buyWithBNB(0, { value: ethers.parseEther("1") });
      const receipt = await tx.wait();

      // Gas usage should be reasonable (adjust threshold as needed)
      expect(receipt!.gasUsed).to.be.lessThan(500000);
    });

    it("Should have optimized gas for multiple operations", async function () {
      const { presale, usdt, user1 } = await loadFixture(deployPresaleSystemFixture);

      const usdtAmount = ethers.parseEther("100");
      await usdt.connect(user1).approve(await presale.getAddress(), usdtAmount);

      const tx = await presale.connect(user1).buyWithUSDT(usdtAmount, 0);
      const receipt = await tx.wait();

      // USDT purchases might use more gas due to ERC20 transfers
      expect(receipt!.gasUsed).to.be.lessThan(600000);
    });
  });
});
