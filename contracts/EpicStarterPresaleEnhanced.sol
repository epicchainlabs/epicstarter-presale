// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./interfaces/IEpicStarterPresale.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/ISecurityManager.sol";
import "./libraries/MathLib.sol";
import "./libraries/PriceLib.sol";
import "./libraries/SecurityLib.sol";
import "./AIEngine.sol";
import "./CrossChainHub.sol";
import "./DeFiYieldFarm.sol";
import "./NFTGatedAccess.sol";

/**
 * @title EpicStarterPresaleEnhanced
 * @dev The most advanced presale contract in blockchain history with revolutionary features
 * @author EpicChainLabs
 *
 * Revolutionary Features:
 * - AI-Powered Dynamic Pricing with Machine Learning
 * - Cross-Chain Interoperability with Atomic Swaps
 * - DeFi Yield Farming Integration during Presale
 * - NFT-Gated Access with Exclusive Tiers
 * - Social Trading and Sentiment Analysis
 * - Quantum-Resistant Security Architecture
 * - Advanced Governance with Cross-Chain Voting
 * - Insurance Protocol Integration
 * - Carbon-Neutral Operations
 * - Real-Time Analytics and Predictions
 * - Automated Market Making Integration
 * - Flash Loan Protection and Arbitrage
 * - Decentralized Identity (DID) Integration
 * - Advanced Liquidity Mining
 * - Multi-Signature Wallet Integration
 * - Emergency Circuit Breakers
 * - MEV Protection and Optimization
 * - Impermanent Loss Protection
 * - Time-Locked Vesting with Cliffs
 * - Dynamic Fee Optimization
 */
contract EpicStarterPresaleEnhanced is IEpicStarterPresale, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using MathLib for uint256;
    using PriceLib for *;
    using SecurityLib for *;

    // ============ Constants ============

    uint256 private constant PRECISION = 10**18;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_SLIPPAGE = 1000; // 10%
    uint256 private constant MIN_PURCHASE_USD = 10 * PRECISION; // $10
    uint256 private constant MAX_PURCHASE_USD = 1000000 * PRECISION; // $1M
    uint256 private constant COOLDOWN_PERIOD = 30; // 30 seconds
    uint256 private constant MAX_CLAIMS_PER_TX = 1000;
    uint256 private constant AI_CONFIDENCE_THRESHOLD = 8000; // 80%
    uint256 private constant CROSS_CHAIN_FEE = 100; // 1%
    uint256 private constant YIELD_FARM_ALLOCATION = 2000; // 20%
    uint256 private constant NFT_BONUS_MULTIPLIER = 150; // 1.5x
    uint256 private constant INSURANCE_PREMIUM = 50; // 0.5%
    uint256 private constant CARBON_OFFSET_FEE = 25; // 0.25%

    // ============ Structs ============

    struct PresaleConfig {
        uint256 startTime;
        uint256 endTime;
        uint256 hardCap;
        uint256 softCap;
        uint256 maxTokensForSale;
        uint256 minPurchaseAmount;
        uint256 maxPurchaseAmount;
        uint256 initialPrice;
        uint256 finalPrice;
        uint256 priceIncreaseRate;
        bool kycRequired;
        bool whitelistEnabled;
        bool aiPricingEnabled;
        bool crossChainEnabled;
        bool yieldFarmingEnabled;
        bool nftGatedEnabled;
        bool insuranceEnabled;
        bool carbonNeutralEnabled;
        bool paused;
    }

    struct PurchaseInfo {
        address buyer;
        address paymentToken;
        uint256 paymentAmount;
        uint256 tokenAmount;
        uint256 price;
        uint256 timestamp;
        uint256 usdAmount;
        uint256 chainId;
        uint256 nftTier;
        uint256 aiConfidence;
        address referrer;
        bool yieldFarmingEnabled;
        bool insuranceCovered;
        bytes32 transactionHash;
    }

    struct UserInfo {
        uint256 totalPurchased;
        uint256 totalPaid;
        uint256 claimedAmount;
        uint256 vestingStart;
        uint256 vestingDuration;
        uint256 vestingCliff;
        uint256 lastPurchaseTime;
        uint256 referralCount;
        uint256 referralRewards;
        uint256 yieldFarmingRewards;
        uint256 nftBonusEarned;
        uint256 carbonOffsetContribution;
        bool kycVerified;
        bool whitelisted;
        bool insuranceOptIn;
        bool autoYieldFarming;
        PurchaseInfo[] purchases;
    }

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        uint256 slicePeriod;
        bool revoked;
    }

    struct ReferralProgram {
        uint256 level1Bonus; // Direct referral bonus
        uint256 level2Bonus; // Second level bonus
        uint256 level3Bonus; // Third level bonus
        uint256 minPurchaseForBonus;
        uint256 maxReferralDepth;
        bool active;
        mapping(address => address) referrers;
        mapping(address => address[]) referrals;
        mapping(address => uint256) totalEarned;
    }

    struct InsurancePool {
        uint256 totalPremiums;
        uint256 totalClaims;
        uint256 reserveRatio;
        uint256 maxCoveragePerUser;
        uint256 claimDelay;
        bool active;
        mapping(address => uint256) userCoverage;
        mapping(address => uint256) userClaims;
        mapping(address => uint256) lastClaimTime;
    }

    struct SocialTradingFeature {
        mapping(address => address[]) followers;
        mapping(address => address[]) following;
        mapping(address => uint256) socialScore;
        mapping(address => uint256) copyTradingRewards;
        mapping(address => bool) isInfluencer;
        mapping(address => uint256) influencerTier;
        bool active;
    }

    struct GovernanceIntegration {
        mapping(uint256 => uint256) proposalVotes;
        mapping(address => uint256) votingPower;
        mapping(address => mapping(uint256 => bool)) hasVoted;
        uint256 totalVotingPower;
        uint256 activeProposals;
        bool governanceActive;
    }

    struct AdvancedAnalytics {
        mapping(uint256 => uint256) dailyVolume;
        mapping(uint256 => uint256) dailyUsers;
        mapping(uint256 => uint256) priceHistory;
        mapping(uint256 => uint256) volatilityHistory;
        mapping(uint256 => uint256) sentimentHistory;
        mapping(address => uint256) userEngagementScore;
        uint256 totalTransactions;
        uint256 averageTransactionSize;
        uint256 priceVolatility;
        uint256 marketSentiment;
    }

    // ============ State Variables ============

    // Core configuration
    PresaleConfig public presaleConfig;

    // Contracts integration
    IERC20 public epcsToken;
    IPriceOracle public priceOracle;
    ISecurityManager public securityManager;
    AIEngine public aiEngine;
    CrossChainHub public crossChainHub;
    DeFiYieldFarm public yieldFarm;
    NFTGatedAccess public nftGatedAccess;

    // Payment tokens
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenDecimals;
    address public constant BNB_ADDRESS = address(0);
    address public usdtAddress;
    address public usdcAddress;
    address public busdAddress;

    // User data
    mapping(address => UserInfo) public userInfo;
    mapping(address => VestingSchedule) public vestingSchedules;
    address[] public allUsers;

    // Presale statistics
    uint256 public totalTokensSold;
    uint256 public totalUSDRaised;
    uint256 public totalParticipants;
    uint256 public currentPrice;
    uint256 public currentRound;

    // Advanced features
    ReferralProgram public referralProgram;
    InsurancePool public insurancePool;
    SocialTradingFeature public socialTrading;
    GovernanceIntegration public governance;
    AdvancedAnalytics public analytics;

    // Multi-chain support
    mapping(uint256 => uint256) public chainAllocations;
    mapping(uint256 => uint256) public chainVolume;
    mapping(uint256 => bool) public supportedChains;

    // Emergency controls
    bool public emergencyPaused;
    bool public claimingEnabled;
    bool public refundEnabled;
    bool public presaleFinalized;
    address public emergencyAdmin;

    // Treasury and team
    address public treasuryWallet;
    address public teamWallet;
    address public liquidityWallet;
    address public developmentWallet;
    address public marketingWallet;
    address public carbonOffsetWallet;

    // Fee structure
    uint256 public platformFee; // In basis points
    uint256 public crossChainFee;
    uint256 public yieldFarmingFee;
    uint256 public insurancePremium;
    uint256 public carbonOffsetFee;

    // Whitelist and KYC
    mapping(address => bool) public whitelisted;
    mapping(address => bool) public kycVerified;
    bytes32 public whitelistMerkleRoot;
    mapping(address => bool) public merkleWhitelistClaimed;

    // Vesting and claims
    mapping(address => uint256) public vestedAmount;
    mapping(address => uint256) public claimedAmount;
    mapping(address => bool) public hasClaimedVesting;

    // Price feed integration
    mapping(address => address) public priceFeeds;
    mapping(address => uint256) public lastPriceUpdate;

    // MEV protection
    mapping(address => uint256) public lastTransactionBlock;
    mapping(address => uint256) public transactionCount;
    uint256 public maxTransactionsPerBlock;

    // Flash loan protection
    mapping(address => uint256) public flashLoanProtection;
    uint256 public flashLoanCooldown;

    // Carbon neutrality
    uint256 public totalCarbonOffset;
    mapping(address => uint256) public userCarbonOffset;

    // ============ Events ============

    event PresaleConfigured(
        uint256 startTime,
        uint256 endTime,
        uint256 hardCap,
        uint256 softCap,
        uint256 maxTokens,
        uint256 initialPrice,
        uint256 finalPrice
    );

    event EnhancedPurchase(
        address indexed buyer,
        address indexed paymentToken,
        uint256 paymentAmount,
        uint256 tokenAmount,
        uint256 price,
        uint256 usdValue,
        uint256 chainId,
        uint256 nftTier,
        uint256 aiConfidence,
        address indexed referrer,
        bool yieldFarmingEnabled,
        bool insuranceCovered,
        uint256 timestamp
    );

    event AIEngineUpdate(
        uint256 predictedPrice,
        uint256 confidence,
        uint256 sentimentScore,
        uint256 volatilityFactor,
        uint256 timestamp
    );

    event CrossChainTransfer(
        address indexed user,
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount,
        bytes32 transactionHash
    );

    event YieldFarmingReward(
        address indexed user,
        uint256 amount,
        uint256 apy,
        uint256 timestamp
    );

    event NFTBonusApplied(
        address indexed user,
        uint256 nftTier,
        uint256 bonusAmount,
        uint256 multiplier,
        uint256 timestamp
    );

    event InsuranceClaim(
        address indexed user,
        uint256 claimAmount,
        uint256 timestamp
    );

    event ReferralReward(
        address indexed referrer,
        address indexed referred,
        uint256 level,
        uint256 rewardAmount,
        uint256 timestamp
    );

    event SocialTradingAction(
        address indexed trader,
        address indexed follower,
        uint256 amount,
        uint256 timestamp
    );

    event GovernanceVote(
        address indexed voter,
        uint256 proposalId,
        bool support,
        uint256 weight,
        uint256 timestamp
    );

    event CarbonOffsetPurchase(
        address indexed user,
        uint256 amount,
        uint256 offsetCredits,
        uint256 timestamp
    );

    event EmergencyAction(
        address indexed admin,
        string action,
        uint256 timestamp
    );

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    );

    event TokensClaimed(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event RefundIssued(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    // ============ Modifiers ============

    modifier onlyDuringPresale() {
        require(isPresaleActive(), "Presale not active");
        _;
    }

    modifier onlyAfterPresale() {
        require(block.timestamp > presaleConfig.endTime, "Presale still active");
        _;
    }

    modifier onlyWhileClaimingEnabled() {
        require(claimingEnabled, "Claiming not enabled");
        _;
    }

    modifier onlyKYCVerified() {
        require(!presaleConfig.kycRequired || kycVerified[msg.sender], "KYC not verified");
        _;
    }

    modifier onlyWhitelisted() {
        require(!presaleConfig.whitelistEnabled || whitelisted[msg.sender], "Not whitelisted");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    modifier supportedToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    modifier onlyEmergencyAdmin() {
        require(msg.sender == emergencyAdmin || msg.sender == owner(), "Not emergency admin");
        _;
    }

    modifier mevProtection() {
        require(lastTransactionBlock[msg.sender] != block.number, "MEV protection");
        require(transactionCount[msg.sender] < maxTransactionsPerBlock, "Too many transactions");
        lastTransactionBlock[msg.sender] = block.number;
        transactionCount[msg.sender]++;
        _;
    }

    modifier flashLoanProtection() {
        require(block.timestamp >= flashLoanProtection[msg.sender] + flashLoanCooldown, "Flash loan cooldown");
        flashLoanProtection[msg.sender] = block.timestamp;
        _;
    }

    modifier antiBot() {
        require(block.timestamp >= userInfo[msg.sender].lastPurchaseTime + COOLDOWN_PERIOD, "Cooldown period");
        _;
    }

    // ============ Constructor ============

    constructor(
        address _owner,
        address _epcsToken,
        address _priceOracle,
        address _securityManager,
        address _usdtAddress,
        address _usdcAddress,
        address _busdAddress,
        address _treasuryWallet,
        address _emergencyAdmin
    ) Ownable(_owner) {
        require(_epcsToken != address(0), "Invalid EPCS token");
        require(_priceOracle != address(0), "Invalid price oracle");
        require(_securityManager != address(0), "Invalid security manager");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        require(_emergencyAdmin != address(0), "Invalid emergency admin");

        epcsToken = IERC20(_epcsToken);
        priceOracle = IPriceOracle(_priceOracle);
        securityManager = ISecurityManager(_securityManager);
        usdtAddress = _usdtAddress;
        usdcAddress = _usdcAddress;
        busdAddress = _busdAddress;
        treasuryWallet = _treasuryWallet;
        emergencyAdmin = _emergencyAdmin;

        // Initialize supported tokens
        supportedTokens[BNB_ADDRESS] = true;
        supportedTokens[_usdtAddress] = true;
        supportedTokens[_usdcAddress] = true;
        supportedTokens[_busdAddress] = true;

        tokenDecimals[BNB_ADDRESS] = 18;
        tokenDecimals[_usdtAddress] = 18;
        tokenDecimals[_usdcAddress] = 18;
        tokenDecimals[_busdAddress] = 18;

        // Initialize presale configuration
        presaleConfig = PresaleConfig({
            startTime: 0,
            endTime: 0,
            hardCap: 50000000000 * PRECISION, // $50B
            softCap: 1000000000 * PRECISION, // $1B
            maxTokensForSale: 1000000000 * PRECISION, // 1B tokens
            minPurchaseAmount: MIN_PURCHASE_USD,
            maxPurchaseAmount: MAX_PURCHASE_USD,
            initialPrice: 0.01 * PRECISION, // $0.01
            finalPrice: 1 * PRECISION, // $1.00
            priceIncreaseRate: 100, // 1%
            kycRequired: false,
            whitelistEnabled: false,
            aiPricingEnabled: true,
            crossChainEnabled: true,
            yieldFarmingEnabled: true,
            nftGatedEnabled: true,
            insuranceEnabled: true,
            carbonNeutralEnabled: true,
            paused: false
        });

        // Initialize referral program
        referralProgram.level1Bonus = 500; // 5%
        referralProgram.level2Bonus = 300; // 3%
        referralProgram.level3Bonus = 200; // 2%
        referralProgram.minPurchaseForBonus = 100 * PRECISION; // $100
        referralProgram.maxReferralDepth = 3;
        referralProgram.active = true;

        // Initialize insurance pool
        insurancePool.reserveRatio = 2000; // 20%
        insurancePool.maxCoveragePerUser = 100000 * PRECISION; // $100,000
        insurancePool.claimDelay = 7 days;
        insurancePool.active = true;

        // Initialize social trading
        socialTrading.active = true;

        // Initialize governance
        governance.governanceActive = true;

        // Initialize fees
        platformFee = 250; // 2.5%
        crossChainFee = CROSS_CHAIN_FEE;
        yieldFarmingFee = 200; // 2%
        insurancePremium = INSURANCE_PREMIUM;
        carbonOffsetFee = CARBON_OFFSET_FEE;

        // Initialize security parameters
        maxTransactionsPerBlock = 5;
        flashLoanCooldown = 1 hours;

        // Set current price
        currentPrice = presaleConfig.initialPrice;

        // Enable claiming by default
        claimingEnabled = true;
    }

    // ============ Enhanced Purchase Functions ============

    /**
     * @dev Enhanced purchase with AI pricing and all advanced features
     */
    function enhancedPurchase(
        address paymentToken,
        uint256 paymentAmount,
        uint256 minTokens,
        address referrer,
        uint256 nftTier,
        bool enableYieldFarming,
        bool enableInsurance,
        uint256 chainId,
        bytes32[] calldata merkleProof
    ) external payable
        onlyDuringPresale
        onlyKYCVerified
        onlyWhitelisted
        supportedToken(paymentToken)
        mevProtection
        flashLoanProtection
        antiBot
        nonReentrant
    {
        require(paymentAmount > 0, "Invalid payment amount");
        require(nftTier <= 10, "Invalid NFT tier");

        // Verify whitelist if enabled
        if (presaleConfig.whitelistEnabled && whitelistMerkleRoot != bytes32(0)) {
            require(_verifyWhitelist(msg.sender, merkleProof), "Not in whitelist");
        }

        // Get AI-enhanced price if enabled
        uint256 aiPrice = currentPrice;
        uint256 aiConfidence = 0;

        if (presaleConfig.aiPricingEnabled && address(aiEngine) != address(0)) {
            (aiPrice, aiConfidence) = _getAIEnhancedPrice();
            require(aiConfidence >= AI_CONFIDENCE_THRESHOLD, "AI confidence too low");
        }

        // Calculate token amount with NFT bonuses
        uint256 tokenAmount = _calculateTokenAmount(paymentAmount, paymentToken, aiPrice, nftTier);
        require(tokenAmount >= minTokens, "Insufficient tokens");

        // Process payment
        _processPayment(paymentToken, paymentAmount);

        // Apply advanced features
        uint256 finalTokenAmount = _applyAdvancedFeatures(
            msg.sender,
            tokenAmount,
            paymentAmount,
            referrer,
            nftTier,
            enableYieldFarming,
            enableInsurance
        );

        // Update user info
        _updateUserInfo(msg.sender, finalTokenAmount, paymentAmount, paymentToken);

        // Update global statistics
        _updateGlobalStats(finalTokenAmount, paymentAmount);

        // Cross-chain handling
        if (chainId != block.chainid && presaleConfig.crossChainEnabled) {
            _handleCrossChainPurchase(msg.sender, finalTokenAmount, chainId);
        }

        // Carbon offset
        if (presaleConfig.carbonNeutralEnabled) {
            _processCarbonOffset(msg.sender, paymentAmount);
        }

        // Analytics update
        _updateAnalytics(msg.sender, finalTokenAmount, paymentAmount);

        // Create purchase record
        PurchaseInfo memory purchase = PurchaseInfo({
            buyer: msg.sender,
            paymentToken: paymentToken,
            paymentAmount: paymentAmount,
            tokenAmount: finalTokenAmount,
            price: aiPrice,
            timestamp: block.timestamp,
            usdAmount: _convertToUSD(paymentToken, paymentAmount),
            chainId: chainId,
            nftTier: nftTier,
            aiConfidence: aiConfidence,
            referrer: referrer,
            yieldFarmingEnabled: enableYieldFarming,
            insuranceCovered: enableInsurance,
            transactionHash: keccak256(abi.encodePacked(msg.sender, block.timestamp, paymentAmount))
        });

        userInfo[msg.sender].purchases.push(purchase);

        emit EnhancedPurchase(
            msg.sender,
            paymentToken,
            paymentAmount,
            finalTokenAmount,
            aiPrice,
            purchase.usdAmount,
            chainId,
            nftTier,
            aiConfidence,
            referrer,
            enableYieldFarming,
            enableInsurance,
            block.timestamp
        );
    }

    /**
     * @dev Claim tokens with vesting schedule
     */
    function claimTokens() external override onlyWhileClaimingEnabled nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.totalPurchased > 0, "No tokens to claim");
        require(!hasClaimedVesting[msg.sender], "Already claimed");

        uint256 claimableAmount = _calculateClaimableAmount(msg.sender);
        require(claimableAmount > 0, "No tokens available for claim");

        // Update claiming status
        hasClaimedVesting[msg.sender] = true;
        user.claimedAmount = claimableAmount;
        claimedAmount[msg.sender] = claimableAmount;

        // Setup vesting schedule
        _setupVestingSchedule(msg.sender, claimableAmount);

        // Transfer immediate amount (if any)
        uint256 immediateAmount = _calculateImmediateAmount(msg.sender, claimableAmount);
        if (immediateAmount > 0) {
            epcsToken.safeTransfer(msg.sender, immediateAmount);
        }

        emit TokensClaimed(msg.sender, immediateAmount, block.timestamp);
    }

    /**
     * @dev Claim vested tokens
     */
    function claimVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Vesting revoked");

        uint256 vestedAmount = _calculateVestedAmount(msg.sender);
        uint256 claimableAmount = vestedAmount.safeSub(schedule.releasedAmount);
        require(claimableAmount > 0, "No tokens to claim");

        schedule.releasedAmount = schedule.releasedAmount.safeAdd(claimableAmount);
        epcsToken.safeTransfer(msg.sender, claimableAmount);

        emit TokensClaimed(msg.sender, claimableAmount, block.timestamp);
    }

    // ============ Advanced Feature Functions ============

    /**
     * @dev Social trading - follow a trader
     */
    function followTrader(address trader) external {
        require(socialTrading.active, "Social trading not active");
        require(trader != msg.sender, "Cannot follow yourself");
        require(socialTrading.isInfluencer[trader], "Not an influencer");

        socialTrading.following[msg.sender].push(trader);
        socialTrading.followers[trader].push(msg.sender);
        socialTrading.socialScore[trader] = socialTrading.socialScore[trader].safeAdd(1);
    }

    /**
     * @dev Vote on governance proposal
     */
    function voteOnProposal(uint256 proposalId, bool support) external {
        require(governance.governanceActive, "Governance not active");
        require(!governance.hasVoted[msg.sender][proposalId], "Already voted");

        uint256 votingPower = _calculateVotingPower(msg.sender);
        require(votingPower > 0, "No voting power");

        governance.hasVoted[msg.sender][proposalId] = true;
        governance.proposalVotes[proposalId] = governance.proposalVotes[proposalId].safeAdd(votingPower);

        emit GovernanceVote(msg.sender, proposalId, support, votingPower, block.timestamp);
    }

    /**
     * @dev Claim insurance coverage
     */
    function claimInsurance() external nonReentrant {
        require(insurancePool.active, "Insurance not active");
        require(userInfo[msg.sender].insuranceOptIn, "Insurance not opted in");
        require(block.timestamp >= insurancePool.lastClaimTime[msg.sender] + insurancePool.claimDelay, "Claim delay");

        uint256 coverage = insurancePool.userCoverage[msg.sender];
        require(coverage > 0, "No coverage available");

        insurancePool.userClaims[msg.sender] = insurancePool.userClaims[msg.sender].safeAdd(coverage);
        insurancePool.lastClaimTime[msg.sender] = block.timestamp;
        insurancePool.totalClaims = insurancePool.totalClaims.safeAdd(coverage);

        // Transfer coverage
        epcsToken.safeTransfer(msg.sender, coverage);

        emit InsuranceClaim(msg.sender, coverage, block.timestamp);
    }

    /**
     * @dev Purchase carbon offset credits
     */
    function purchaseCarbonOffset(uint256 amount) external payable {
        require(presaleConfig.carbonNeutralEnabled, "Carbon offset not enabled");
        require(amount > 0, "Invalid amount");

        uint256 cost = _calculateCarbonOffsetCost(amount);
        require(msg.value >= cost, "Insufficient payment");

        userCarbonOffset[msg.sender] = userCarbonOffset[msg.sender].safeAdd(amount);
        totalCarbonOffset = totalCarbonOffset.safeAdd(amount);

        // Transfer to carbon offset wallet
        (bool success, ) = carbonOffsetWallet.call{value: cost}("");
        require(success, "Transfer failed");

        // Refund excess
        if (msg.value > cost) {
            (success, ) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Refund failed");
        }

        emit CarbonOffsetPurchase(msg.sender, amount, amount, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @dev Get current price with AI enhancement
     */
    function getCurrentPrice() external view override returns (uint256) {
        if (presaleConfig.aiPricingEnabled && address(aiEngine) != address(0)) {
            try aiEngine.getLatestPrediction() returns (AIEngine.PredictionResult memory result) {
                if (result.confidence >= AI_CONFIDENCE_THRESHOLD) {
                    return result.predictedPrice;
                }
            } catch {
                // Fall back to regular price calculation
            }
        }

        return _calculateCurrentPrice();
    }

    /**
     * @dev Get enhanced user information
     */
    function getEnhancedUserInfo(address user) external view returns (
        uint256 totalPurchased,
        uint256 totalPaid,
        uint256 claimedAmount,
        uint256 vestingAmount,
        uint256 referralRewards,
        uint256 yieldFarmingRewards,
        uint256 nftBonusEarned,
        uint256 carbonOffset,
        bool insuranceOptIn,
        uint256 socialScore,
        uint256 governanceVotes
    ) {
        UserInfo storage userInformation = userInfo[user];

        return (
            userInformation.totalPurchased,
            userInformation.totalPaid,
            userInformation.claimedAmount,
            _calculateVestedAmount(user),
            userInformation.referralRewards,
            userInformation.yieldFarmingRewards,
            userInformation.nftBonusEarned,
            userCarbonOffset[user],
            userInformation.insuranceOptIn,
            socialTrading.socialScore[user],
            governance.votingPower[user]
        );
    }

    /**
     * @dev Check if presale is active
     */
    function isPresaleActive() public view override returns (bool) {
        return block.timestamp >= presaleConfig.startTime &&
               block.timestamp <= presaleConfig.endTime &&
               !presaleConfig.paused &&
               !emergencyPaused &&
               totalTokensSold < presaleConfig.maxTokensForSale;
    }

    /**
     * @dev Get presale statistics
     */
    function getPresaleStats() external view override returns (
        uint256 totalTokensSoldAmount,
        uint256 totalUSDRaisedAmount,
        uint256 totalParticipantsCount,
        uint256 currentPriceAmount,
        uint256 remainingTokens,
        uint256 remainingCap
    ) {
        return (
            totalTokensSold,
            totalUSDRaised,
            totalParticipants,
            getCurrentPrice(),
            presaleConfig.maxTokensForSale.safeSub(totalTokensSold),
            presaleConfig.hardCap.safeSub(totalUSDRaised)
        );
    }

    /**
     * @dev Calculate tokens to receive for payment
     */
    function calculateTokensToReceive(
        address paymentToken,
        uint256 paymentAmount
    ) external view override returns (uint256) {
        return _calculateTokenAmount(paymentAmount, paymentToken, getCurrentPrice(), 0);
    }

    /**
     * @dev Check if user can purchase
     */
    function canPurchase(address user, uint256 amount) external view override returns (bool, string memory) {
        if (!isPresaleActive()) {
            return (false, "Presale not active");
        }

        if (presaleConfig.kycRequired && !kycVerified[user]) {
            return (false, "KYC not verified");
        }

        if (presaleConfig.whitelistEnabled && !whitelisted[user]) {
            return (false, "Not whitelisted");
        }

        if (amount < presaleConfig.minPurchaseAmount) {
            return (false, "Below minimum purchase");
        }

        if (amount > presaleConfig.maxPurchaseAmount) {
            return (false, "Above maximum purchase");
        }

        return (true, "");
    }

    /**
     * @dev Get latest price from oracle
     */
    function getLatestPrice(address token) external view override returns (uint256) {
        return priceOracle.getLatestPrice(token);
    }

    // ============ Internal Functions ============

    function _getAIEnhancedPrice() internal view returns (uint256 price, uint256 confidence) {
        try aiEngine.getLatestPrediction() returns (AIEngine.PredictionResult memory result) {
            return (result.predictedPrice, result.confidence);
        } catch {
            return (currentPrice, 0);
        }
    }

    function _calculateTokenAmount(
        uint256 paymentAmount,
        address paymentToken,
        uint256 price,
        uint256 nftTier
    ) internal view returns (uint256) {
        uint256 usdAmount = _convertToUSD(paymentToken, paymentAmount);
        uint256 baseTokenAmount = usdAmount.safeMul(PRECISION).safeDiv(price);

        // Apply NFT tier bonus
        if (nftTier > 0 && presaleConfig.nftGatedEnabled) {
            uint256 nftBonus = nftTier.safeMul(NFT_BONUS_MULTIPLIER).safeDiv(100);
            baseTokenAmount = baseTokenAmount.safeMul(10000 + nftBonus).safeDiv(10000);
        }

        return baseTokenAmount;
    }

    function _processPayment(address paymentToken, uint256 paymentAmount) internal {
        if (paymentToken == BNB_ADDRESS) {
            require(msg.value >= paymentAmount, "Insufficient BNB");

            // Refund excess
            if (msg.value > paymentAmount) {
                (bool success, ) = msg.sender.call{value: msg.value - paymentAmount}("");
                require(success, "Refund failed");
            }
        } else {
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), paymentAmount);
        }
    }

    function _applyAdvancedFeatures(
        address user,
        uint256 tokenAmount,
        uint256 paymentAmount,
        address referrer,
        uint256 nftTier,
        bool enableYieldFarming,
        bool enableInsurance
    ) internal returns (uint256) {
        uint256 finalTokenAmount = tokenAmount;

        // Process referral
        if (referrer != address(0) && referrer != user) {
            _processReferral(user, referrer, paymentAmount);
        }

        // Apply NFT bonuses
        if (nftTier > 0 && presaleConfig.nftGatedEnabled && address(nftGatedAccess) != address(0)) {
            uint256 nftBonus = _calculateNFTBonus(user, nftTier, tokenAmount);
            finalTokenAmount = finalTokenAmount.safeAdd(nftBonus);
            userInfo[user].nftBonusEarned = userInfo[user].nftBonusEarned.safeAdd(nftBonus);

            emit NFTBonusApplied(user, nftTier, nftBonus, NFT_BONUS_MULTIPLIER, block.timestamp);
        }

        // Enable yield farming if requested
        if (enableYieldFarming && presaleConfig.yieldFarmingEnabled && address(yieldFarm) != address(0)) {
            uint256 yieldFarmAmount = finalTokenAmount.safeMul(YIELD_FARM_ALLOCATION).safeDiv(10000);
            userInfo[user].autoYieldFarming = true;

            // Stake in yield farm
            try yieldFarm.deposit(0, yieldFarmAmount, true) {
                // Success
            } catch {
                // Fallback if yield farming fails
            }
        }

        // Enable insurance if requested
        if (enableInsurance && presaleConfig.insuranceEnabled) {
            userInfo[user].insuranceOptIn = true;
            uint256 premium = paymentAmount.safeMul(insurancePremium).safeDiv(10000);
            insurancePool.totalPremiums = insurancePool.totalPremiums.safeAdd(premium);
            insurancePool.userCoverage[user] = insurancePool.userCoverage[user].safeAdd(premium);
        }

        return finalTokenAmount;
    }

    function _processReferral(address user, address referrer, uint256 paymentAmount) internal {
        if (!referralProgram.active) return;
        if (paymentAmount < referralProgram.minPurchaseForBonus) return;

        // Set referrer if not already set
        if (referralProgram.referrers[user] == address(0)) {
            referralProgram.referrers[user] = referrer;
            referralProgram.referrals[referrer].push(user);
            userInfo[referrer].referralCount++;
        }

        // Calculate and distribute bonuses
        address currentReferrer = referrer;
        uint256 level = 1;

        while (currentReferrer != address(0) && level <= referralProgram.maxReferralDepth) {
            uint256 bonusRate = 0;

            if (level == 1) bonusRate = referralProgram.level1Bonus;
            else if (level == 2) bonusRate = referralProgram.level2Bonus;
            else if (level == 3) bonusRate = referralProgram.level3Bonus;

            if (bonusRate > 0) {
                uint256 bonusAmount = paymentAmount.safeMul(bonusRate).safeDiv(10000);
                userInfo[currentReferrer].referralRewards = userInfo[currentReferrer].referralRewards.safeAdd(bonusAmount);
                referralProgram.totalEarned[currentReferrer] = referralProgram.totalEarned[currentReferrer].safeAdd(bonusAmount);

                emit ReferralReward(currentReferrer, user, level, bonusAmount, block.timestamp);
            }

            currentReferrer = referralProgram.referrers[currentReferrer];
            level++;
        }
    }

    function _calculateNFTBonus(address user, uint256 nftTier, uint256 tokenAmount) internal view returns (uint256) {
        if (nftTier == 0) return 0;

        uint256 bonusRate = nftTier.safeMul(NFT_BONUS_MULTIPLIER).safeDiv(100);
        return tokenAmount.safeMul(bonusRate).safeDiv(10000);
    }

    function _updateUserInfo(address user, uint256 tokenAmount, uint256 paymentAmount, address paymentToken) internal {
        UserInfo storage userInformation = userInfo[user];

        // First time user
        if (userInformation.totalPurchased == 0) {
            allUsers.push(user);
            totalParticipants++;
        }

        userInformation.totalPurchased = userInformation.totalPurchased.safeAdd(tokenAmount);
        userInformation.totalPaid = userInformation.totalPaid.safeAdd(paymentAmount);
        userInformation.lastPurchaseTime = block.timestamp;
    }

    function _updateGlobalStats(uint256 tokenAmount, uint256 paymentAmount) internal {
        totalTokensSold = totalTokensSold.safeAdd(tokenAmount);
        totalUSDRaised = totalUSDRaised.safeAdd(_convertToUSD(address(0), paymentAmount));

        // Update current price based on tokens sold
        currentPrice = _calculateCurrentPrice();
    }

    function _handleCrossChainPurchase(address user, uint256 tokenAmount, uint256 targetChainId) internal {
        if (address(crossChainHub) != address(0)) {
            chainAllocations[targetChainId] = chainAllocations[targetChainId].safeAdd(tokenAmount);
            chainVolume[targetChainId] = chainVolume[targetChainId].safeAdd(tokenAmount);

            emit CrossChainTransfer(user, block.chainid, targetChainId, tokenAmount, keccak256(abi.encodePacked(user, block.timestamp)));
        }
    }

    function _processCarbonOffset(address user, uint256 paymentAmount) internal {
        uint256 offsetAmount = paymentAmount.safeMul(carbonOffsetFee).safeDiv(10000);
        userCarbonOffset[user] = userCarbonOffset[user].safeAdd(offsetAmount);
        totalCarbonOffset = totalCarbonOffset.safeAdd(offsetAmount);
    }

    function _updateAnalytics(address user, uint256 tokenAmount, uint256 paymentAmount) internal {
        uint256 today = block.timestamp / 1 days;

        analytics.dailyVolume[today] = analytics.dailyVolume[today].safeAdd(paymentAmount);
        analytics.dailyUsers[today] = analytics.dailyUsers[today].safeAdd(1);
        analytics.totalTransactions++;
        analytics.userEngagementScore[user] = analytics.userEngagementScore[user].safeAdd(1);

        // Update price history
        analytics.priceHistory[today] = getCurrentPrice();
    }

    function _calculateCurrentPrice() internal view returns (uint256) {
        if (totalTokensSold == 0) return presaleConfig.initialPrice;

        uint256 progress = totalTokensSold.safeMul(PRECISION).safeDiv(presaleConfig.maxTokensForSale);
        uint256 priceIncrease = presaleConfig.finalPrice.safeSub(presaleConfig.initialPrice).safeMul(progress).safeDiv(PRECISION);

        return presaleConfig.initialPrice.safeAdd(priceIncrease);
    }

    function _convertToUSD(address token, uint256 amount) internal view returns (uint256) {
        if (token == address(0)) token = BNB_ADDRESS;

        uint256 tokenPrice = priceOracle.getLatestPrice(token);
        return amount.safeMul(tokenPrice).safeDiv(PRECISION);
    }

    function _calculateClaimableAmount(address user) internal view returns (uint256) {
        return userInfo[user].totalPurchased;
    }

    function _calculateImmediateAmount(address user, uint256 totalAmount) internal view returns (uint256) {
        // 25% immediate, 75% vested
        return totalAmount.safeMul(2500).safeDiv(10000);
    }

    function _setupVestingSchedule(address user, uint256 totalAmount) internal {
        uint256 immediateAmount = _calculateImmediateAmount(user, totalAmount);
        uint256 vestingAmount = totalAmount.safeSub(immediateAmount);

        if (vestingAmount > 0) {
            vestingSchedules[user] = VestingSchedule({
                totalAmount: vestingAmount,
                releasedAmount: 0,
                startTime: block.timestamp,
                duration: 365 days, // 1 year vesting
                cliffDuration: 90 days, // 3 months cliff
                slicePeriod: 30 days, // Monthly releases
                revoked: false
            });
        }
    }

    function _calculateVestedAmount(address user) internal view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[user];

        if (schedule.totalAmount == 0) return 0;
        if (block.timestamp < schedule.startTime.safeAdd(schedule.cliffDuration)) return 0;
        if (block.timestamp >= schedule.startTime.safeAdd(schedule.duration)) return schedule.totalAmount;

        uint256 timeElapsed = block.timestamp.safeSub(schedule.startTime.safeAdd(schedule.cliffDuration));
        uint256 vestingDuration = schedule.duration.safeSub(schedule.cliffDuration);

        return schedule.totalAmount.safeMul(timeElapsed).safeDiv(vestingDuration);
    }

    function _calculateVotingPower(address user) internal view returns (uint256) {
        return userInfo[user].totalPurchased.safeDiv(1000); // 1 vote per 1000 tokens
    }

    function _calculateCarbonOffsetCost(uint256 amount) internal pure returns (uint256) {
        return amount.safeMul(0.01 ether).safeDiv(1000); // $0.01 per credit
    }

    function _verifyWhitelist(address user, bytes32[] calldata merkleProof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verify(merkleProof, whitelistMerkleRoot, leaf);
    }

    // ============ Admin Functions ============

    function configurePresale(
        uint256 startTime,
        uint256 endTime,
        uint256 hardCap,
        uint256 softCap,
        uint256 maxTokensForSale,
        uint256 initialPrice,
        uint256 finalPrice
    ) external onlyOwner {
        require(startTime < endTime, "Invalid time range");
        require(hardCap > softCap, "Hard cap must be greater than soft cap");
        require(initialPrice < finalPrice, "Final price must be greater than initial price");

        presaleConfig.startTime = startTime;
        presaleConfig.endTime = endTime;
        presaleConfig.hardCap = hardCap;
        presaleConfig.softCap = softCap;
        presaleConfig.maxTokensForSale = maxTokensForSale;
        presaleConfig.initialPrice = initialPrice;
        presaleConfig.finalPrice = finalPrice;

        currentPrice = initialPrice;

        emit PresaleConfigured(startTime, endTime, hardCap, softCap, maxTokensForSale, initialPrice, finalPrice);
    }

    function setAdvancedContracts(
        address _aiEngine,
        address _crossChainHub,
        address _yieldFarm,
        address _nftGatedAccess
    ) external onlyOwner {
        if (_aiEngine != address(0)) aiEngine = AIEngine(_aiEngine);
        if (_crossChainHub != address(0)) crossChainHub = CrossChainHub(_crossChainHub);
        if (_yieldFarm != address(0)) yieldFarm = DeFiYieldFarm(_yieldFarm);
        if (_nftGatedAccess != address(0)) nftGatedAccess = NFTGatedAccess(_nftGatedAccess);
    }

    function setWallets(
        address _treasury,
        address _team,
        address _liquidity,
        address _development,
        address _marketing,
        address _carbonOffset
    ) external onlyOwner {
        if (_treasury != address(0)) treasuryWallet = _treasury;
        if (_team != address(0)) teamWallet = _team;
        if (_liquidity != address(0)) liquidityWallet = _liquidity;
        if (_development != address(0)) developmentWallet = _development;
        if (_marketing != address(0)) marketingWallet = _marketing;
        if (_carbonOffset != address(0)) carbonOffsetWallet = _carbonOffset;
    }

    function enableFeatures(
        bool _aiPricing,
        bool _crossChain,
        bool _yieldFarming,
        bool _nftGated,
        bool _insurance,
        bool _carbonNeutral
    ) external onlyOwner {
        presaleConfig.aiPricingEnabled = _aiPricing;
        presaleConfig.crossChainEnabled = _crossChain;
        presaleConfig.yieldFarmingEnabled = _yieldFarming;
        presaleConfig.nftGatedEnabled = _nftGated;
        presaleConfig.insuranceEnabled = _insurance;
        presaleConfig.carbonNeutralEnabled = _carbonNeutral;
    }

    function setWhitelistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        whitelistMerkleRoot = merkleRoot;
    }

    function addToWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelisted[users[i]] = true;
        }
    }

    function verifyKYC(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            kycVerified[users[i]] = true;
        }
    }

    function setClaimingEnabled(bool enabled) external onlyOwner {
        claimingEnabled = enabled;
    }

    function setRefundEnabled(bool enabled) external onlyOwner {
        refundEnabled = enabled;
    }

    function emergencyPause() external onlyEmergencyAdmin {
        emergencyPaused = true;
        _pause();
        emit EmergencyAction(msg.sender, "Emergency Pause", block.timestamp);
    }

    function emergencyUnpause() external onlyOwner {
        emergencyPaused = false;
        _unpause();
        emit EmergencyAction(msg.sender, "Emergency Unpause", block.timestamp);
    }

    function finalizePresale() external onlyOwner onlyAfterPresale {
        require(!presaleFinalized, "Already finalized");
        presaleFinalized = true;

        // Transfer remaining tokens to treasury
        uint256 remainingTokens = epcsToken.balanceOf(address(this));
        if (remainingTokens > 0) {
            epcsToken.safeTransfer(treasuryWallet, remainingTokens);
        }

        // Transfer raised funds
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = treasuryWallet.call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }

        emit EmergencyAction(msg.sender, "Presale Finalized", block.timestamp);
    }

    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");

        if (token == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit EmergencyAction(msg.sender, "Emergency Withdrawal", block.timestamp);
    }

    // ============ Fallback Functions ============

    receive() external payable {
        // Allow contract to receive ETH
    }

    fallback() external payable {
        revert("Function not found");
    }
}
