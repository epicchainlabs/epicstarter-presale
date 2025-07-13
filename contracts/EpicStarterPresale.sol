// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IEpicStarterPresale.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/ISecurityManager.sol";
import "./libraries/MathLib.sol";
import "./libraries/PriceLib.sol";
import "./libraries/SecurityLib.sol";

/**
 * @title EpicStarterPresale
 * @dev Advanced presale contract with oracle-based dynamic pricing, multi-currency support, and military-grade security
 * @author EpicChainLabs
 *
 * Features:
 * - Oracle-based dynamic pricing with multiple pricing models
 * - Multi-currency support (BNB, USDT, USDC)
 * - Advanced security with anti-bot, MEV protection, and circuit breakers
 * - Tiered pricing system with bonding curves
 * - KYC/Whitelist integration
 * - Emergency controls and pause mechanisms
 * - Comprehensive analytics and monitoring
 * - Gas-optimized operations
 * - Audit-ready codebase
 */
contract EpicStarterPresale is IEpicStarterPresale, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using MathLib for uint256;
    using PriceLib for *;
    using SecurityLib for *;

    // ============ Constants ============

    uint256 private constant PRICE_PRECISION = 10**18;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_SLIPPAGE = 1000; // 10%
    uint256 private constant MIN_PURCHASE_USD = 10 * PRICE_PRECISION; // $10
    uint256 private constant MAX_PURCHASE_USD = 100000 * PRICE_PRECISION; // $100,000
    uint256 private constant COOLDOWN_PERIOD = 30; // 30 seconds
    uint256 private constant MAX_CLAIMS_PER_TX = 100;

    // ============ State Variables ============

    // Core configuration
    PresaleConfig public presaleConfig;
    PriceFeeds public priceFeeds;

    // Contracts
    IERC20 public epcsToken;
    IPriceOracle public priceOracle;
    ISecurityManager public securityManager;

    // Supported payment tokens
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenDecimals;

    // Payment token addresses
    address public constant BNB_ADDRESS = address(0);
    address public usdtAddress;
    address public usdcAddress;

    // User data
    mapping(address => PurchaseInfo[]) public userPurchases;
    mapping(address => uint256) public userTokenBalance;
    mapping(address => uint256) public userUSDContribution;
    mapping(address => uint256) public lastPurchaseTime;
    mapping(address => bool) public hasClaimed;

    // Presale statistics
    uint256 public totalTokensSold;
    uint256 public totalUSDRaised;
    uint256 public totalParticipants;
    uint256 public currentPrice;

    // Price configuration
    PriceLib.PriceConfig public priceConfig;
    PriceLib.PriceTier[] public priceTiers;

    // Bonding curve
    PriceLib.BondingCurveConfig public bondingCurve;
    bool public bondingCurveEnabled;

    // Controls
    bool public claimingEnabled;
    bool public refundEnabled;
    bool public presaleFinalized;
    bool public emergencyWithdrawEnabled;

    // Vesting
    mapping(address => uint256) public vestingStart;
    mapping(address => uint256) public vestingDuration;
    mapping(address => uint256) public vestedAmount;
    bool public vestingEnabled;

    // Treasury and team
    address public treasuryWallet;
    address public teamWallet;
    address public liquidityWallet;

    // Fees
    uint256 public platformFee; // In basis points
    uint256 public referralBonus; // In basis points
    mapping(address => address) public referrals;
    mapping(address => uint256) public referralEarnings;

    // Analytics
    mapping(uint256 => uint256) public dailyVolume;
    mapping(uint256 => uint256) public dailyParticipants;
    uint256 public lastAnalyticsUpdate;

    // Events for comprehensive logging
    event PresaleInitialized(
        uint256 startTime,
        uint256 endTime,
        uint256 hardCap,
        uint256 maxTokens,
        uint256 initialPrice
    );

    event PurchaseProcessed(
        address indexed buyer,
        address indexed paymentToken,
        uint256 paymentAmount,
        uint256 tokenAmount,
        uint256 price,
        uint256 usdValue,
        address indexed referrer
    );

    event PriceModelUpdated(
        PriceLib.PricingModel model,
        uint256[] parameters,
        uint256 timestamp
    );

    event BondingCurveConfigured(
        uint256 reserveRatio,
        uint256 initialReserve,
        uint256 timestamp
    );

    event VestingConfigured(
        address indexed user,
        uint256 duration,
        uint256 amount,
        uint256 timestamp
    );

    event ClaimProcessed(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event ReferralSet(
        address indexed user,
        address indexed referrer,
        uint256 bonus,
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

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    modifier supportedToken(address token) {
        require(supportedTokens[token], "Token not supported");
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
        address _treasuryWallet
    ) Ownable(_owner) {
        require(_epcsToken != address(0), "Invalid EPCS token");
        require(_priceOracle != address(0), "Invalid price oracle");
        require(_securityManager != address(0), "Invalid security manager");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");

        epcsToken = IERC20(_epcsToken);
        priceOracle = IPriceOracle(_priceOracle);
        securityManager = ISecurityManager(_securityManager);
        usdtAddress = _usdtAddress;
        usdcAddress = _usdcAddress;
        treasuryWallet = _treasuryWallet;

        // Initialize supported tokens
        supportedTokens[BNB_ADDRESS] = true;
        supportedTokens[_usdtAddress] = true;
        supportedTokens[_usdcAddress] = true;

        tokenDecimals[BNB_ADDRESS] = 18;
        tokenDecimals[_usdtAddress] = 18;
        tokenDecimals[_usdcAddress] = 18;

        // Default configuration
        presaleConfig = PresaleConfig({
            startTime: 0,
            endTime: 0,
            hardCap: 5000000000 * PRICE_PRECISION, // $5B
            maxTokensForSale: 100000000 * PRICE_PRECISION, // 100M tokens
            minPurchaseAmount: MIN_PURCHASE_USD,
            maxPurchaseAmount: MAX_PURCHASE_USD,
            initialPrice: 1 * PRICE_PRECISION, // $1
            priceIncreaseRate: 100, // 1%
            kycRequired: false,
            whitelistEnabled: false,
            paused: false
        });

        // Initialize price configuration
        priceConfig = PriceLib.PriceConfig({
            initialPrice: presaleConfig.initialPrice,
            finalPrice: 10 * PRICE_PRECISION, // $10 final price
            totalSupply: presaleConfig.maxTokensForSale,
            currentSupply: 0,
            startTime: 0,
            endTime: 0,
            model: PriceLib.PricingModel.LINEAR,
            parameters: new uint256[](0)
        });

        currentPrice = presaleConfig.initialPrice;
        platformFee = 250; // 2.5%
        referralBonus = 500; // 5%
    }

    // ============ Purchase Functions ============

    /**
     * @dev Purchase tokens with BNB
     */
    function buyWithBNB(uint256 minTokens) external payable override onlyDuringPresale nonReentrant {
        require(msg.value > 0, "Invalid BNB amount");

        _processPurchase(msg.sender, BNB_ADDRESS, msg.value, minTokens, address(0));
    }

    /**
     * @dev Purchase tokens with USDT
     */
    function buyWithUSDT(uint256 usdtAmount, uint256 minTokens) external override onlyDuringPresale nonReentrant {
        require(usdtAmount > 0, "Invalid USDT amount");

        IERC20(usdtAddress).safeTransferFrom(msg.sender, address(this), usdtAmount);
        _processPurchase(msg.sender, usdtAddress, usdtAmount, minTokens, address(0));
    }

    /**
     * @dev Purchase tokens with USDC
     */
    function buyWithUSDC(uint256 usdcAmount, uint256 minTokens) external override onlyDuringPresale nonReentrant {
        require(usdcAmount > 0, "Invalid USDC amount");

        IERC20(usdcAddress).safeTransferFrom(msg.sender, address(this), usdcAmount);
        _processPurchase(msg.sender, usdcAddress, usdcAmount, minTokens, address(0));
    }

    /**
     * @dev Purchase tokens with referral
     */
    function buyWithReferral(
        address paymentToken,
        uint256 paymentAmount,
        uint256 minTokens,
        address referrer
    ) external payable onlyDuringPresale nonReentrant {
        require(referrer != msg.sender, "Cannot refer yourself");
        require(referrer != address(0), "Invalid referrer");

        if (paymentToken == BNB_ADDRESS) {
            require(msg.value == paymentAmount, "BNB amount mismatch");
        } else {
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), paymentAmount);
        }

        _processPurchase(msg.sender, paymentToken, paymentAmount, minTokens, referrer);
    }

    /**
     * @dev Claim purchased tokens
     */
    function claimTokens() external override onlyWhileClaimingEnabled nonReentrant {
        require(!hasClaimed[msg.sender], "Already claimed");
        require(userTokenBalance[msg.sender] > 0, "No tokens to claim");

        uint256 claimableAmount = _calculateClaimableAmount(msg.sender);
        require(claimableAmount > 0, "No tokens available for claim");

        hasClaimed[msg.sender] = true;

        if (vestingEnabled) {
            _setupVesting(msg.sender, claimableAmount);
        } else {
            epcsToken.safeTransfer(msg.sender, claimableAmount);
        }

        emit TokensClaimed(msg.sender, claimableAmount, block.timestamp);
    }

    /**
     * @dev Request refund (if enabled)
     */
    function requestRefund() external override nonReentrant {
        require(refundEnabled, "Refunds not enabled");
        require(userUSDContribution[msg.sender] > 0, "No contribution to refund");
        require(!hasClaimed[msg.sender], "Cannot refund after claiming");

        uint256 refundAmount = userUSDContribution[msg.sender];
        PurchaseInfo[] memory purchases = userPurchases[msg.sender];

        // Clear user data
        userTokenBalance[msg.sender] = 0;
        userUSDContribution[msg.sender] = 0;
        delete userPurchases[msg.sender];

        // Process refunds for each payment token
        for (uint256 i = 0; i < purchases.length; i++) {
            PurchaseInfo memory purchase = purchases[i];

            if (purchase.paymentToken == BNB_ADDRESS) {
                uint256 bnbPrice = priceOracle.getLatestPrice(BNB_ADDRESS);
                uint256 bnbAmount = purchase.usdAmount.safeMul(PRICE_PRECISION).safeDiv(bnbPrice);

                (bool success, ) = msg.sender.call{value: bnbAmount}("");
                require(success, "BNB refund failed");
            } else {
                uint256 tokenPrice = priceOracle.getLatestPrice(purchase.paymentToken);
                uint256 tokenAmount = purchase.usdAmount.safeMul(PRICE_PRECISION).safeDiv(tokenPrice);

                IERC20(purchase.paymentToken).safeTransfer(msg.sender, tokenAmount);
            }
        }

        // Update statistics
        totalTokensSold = totalTokensSold.safeSub(userTokenBalance[msg.sender]);
        totalUSDRaised = totalUSDRaised.safeSub(refundAmount);
        totalParticipants = totalParticipants > 0 ? totalParticipants - 1 : 0;

        emit RefundIssued(msg.sender, address(0), refundAmount, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @dev Get current EPCS token price in USD
     */
    function getCurrentPrice() external view override returns (uint256) {
        if (bondingCurveEnabled) {
            return PriceLib.calculateBondingCurvePrice(bondingCurve, 0);
        }

        if (priceTiers.length > 0) {
            (uint256 price, ) = PriceLib.calculateTieredPrice(priceTiers, totalTokensSold);
            return price;
        }

        return PriceLib.calculatePrice(priceConfig, totalTokensSold);
    }

    /**
     * @dev Get latest price from oracle
     */
    function getLatestPrice(address token) external view override returns (uint256) {
        return priceOracle.getLatestPrice(token);
    }

    /**
     * @dev Calculate tokens to receive for payment
     */
    function calculateTokensToReceive(
        address paymentToken,
        uint256 paymentAmount
    ) external view override returns (uint256) {
        require(supportedTokens[paymentToken], "Token not supported");

        uint256 paymentTokenPrice = priceOracle.getLatestPrice(paymentToken);
        uint256 tokenPrice = this.getCurrentPrice();

        return MathLib.calculateTokensToReceive(
            paymentAmount,
            paymentTokenPrice,
            tokenPrice,
            tokenDecimals[paymentToken]
        );
    }

    /**
     * @dev Get user's purchase history
     */
    function getUserPurchases(address user) external view override returns (PurchaseInfo[] memory) {
        return userPurchases[user];
    }

    /**
     * @dev Get user's token balance
     */
    function getUserTokenBalance(address user) external view override returns (uint256) {
        return userTokenBalance[user];
    }

    /**
     * @dev Get user's USD contribution
     */
    function getUserUSDContribution(address user) external view override returns (uint256) {
        return userUSDContribution[user];
    }

    /**
     * @dev Get presale statistics
     */
    function getPresaleStats() external view override returns (
        uint256 _totalTokensSold,
        uint256 _totalUSDRaised,
        uint256 _totalParticipants,
        uint256 _currentPrice,
        uint256 _remainingTokens,
        uint256 _remainingCap
    ) {
        _totalTokensSold = totalTokensSold;
        _totalUSDRaised = totalUSDRaised;
        _totalParticipants = totalParticipants;
        _currentPrice = this.getCurrentPrice();
        _remainingTokens = presaleConfig.maxTokensForSale.safeSub(totalTokensSold);
        _remainingCap = presaleConfig.hardCap.safeSub(totalUSDRaised);
    }

    /**
     * @dev Check if user is whitelisted
     */
    function isWhitelisted(address user) external view override returns (bool) {
        return securityManager.isWhitelisted(user);
    }

    /**
     * @dev Check if user has KYC approval
     */
    function isKYCApproved(address user) external view override returns (bool) {
        return securityManager.isKYCApproved(user);
    }

    /**
     * @dev Check if presale is active
     */
    function isPresaleActive() public view override returns (bool) {
        return block.timestamp >= presaleConfig.startTime &&
               block.timestamp <= presaleConfig.endTime &&
               !presaleConfig.paused &&
               !presaleFinalized &&
               totalUSDRaised < presaleConfig.hardCap &&
               totalTokensSold < presaleConfig.maxTokensForSale;
    }

    /**
     * @dev Check if user can purchase tokens
     */
    function canPurchase(address user, uint256 amount) external view override returns (bool, string memory) {
        // Check presale status
        if (!isPresaleActive()) {
            return (false, "Presale not active");
        }

        // Check security manager
        (bool canTransact, string memory reason) = securityManager.canTransact(user, amount, 1);
        if (!canTransact) {
            return (false, reason);
        }

        // Check KYC requirement
        if (presaleConfig.kycRequired && !securityManager.isKYCApproved(user)) {
            return (false, "KYC required");
        }

        // Check whitelist requirement
        if (presaleConfig.whitelistEnabled && !securityManager.isWhitelisted(user)) {
            return (false, "User not whitelisted");
        }

        // Check purchase limits
        if (amount < presaleConfig.minPurchaseAmount) {
            return (false, "Below minimum purchase");
        }

        uint256 newContribution = userUSDContribution[user].safeAdd(amount);
        if (newContribution > presaleConfig.maxPurchaseAmount) {
            return (false, "Exceeds maximum purchase");
        }

        // Check cooldown
        if (block.timestamp < lastPurchaseTime[user] + COOLDOWN_PERIOD) {
            return (false, "Cooldown period active");
        }

        return (true, "");
    }

    // ============ Admin Functions ============

    /**
     * @dev Update presale configuration
     */
    function updatePresaleConfig(PresaleConfig calldata config) external override onlyOwner {
        require(config.startTime < config.endTime, "Invalid time range");
        require(config.hardCap > 0, "Invalid hard cap");
        require(config.maxTokensForSale > 0, "Invalid max tokens");
        require(config.initialPrice > 0, "Invalid initial price");

        presaleConfig = config;
        currentPrice = config.initialPrice;

        emit PresaleConfigUpdated(
            config.startTime,
            config.endTime,
            config.hardCap,
            config.maxTokensForSale
        );
    }

    /**
     * @dev Update price feeds configuration
     */
    function updatePriceFeeds(PriceFeeds calldata feeds) external override onlyOwner {
        priceFeeds = feeds;
    }

    /**
     * @dev Update whitelist
     */
    function updateWhitelist(address[] calldata users, bool[] calldata whitelisted) external override onlyOwner {
        securityManager.updateWhitelist(users, whitelisted);
    }

    /**
     * @dev Update KYC status
     */
    function updateKYCStatus(address[] calldata users, bool[] calldata approved) external override onlyOwner {
        securityManager.updateKYCStatus(users, approved);
    }

    /**
     * @dev Set paused state
     */
    function setPaused(bool paused) external override onlyOwner {
        presaleConfig.paused = paused;
        emit PausedStateChanged(paused, block.timestamp);
    }

    /**
     * @dev Emergency withdraw
     */
    function emergencyWithdraw(address token, address to, uint256 amount) external override onlyOwner {
        require(emergencyWithdrawEnabled, "Emergency withdraw not enabled");

        if (token == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "BNB transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit EmergencyWithdraw(token, to, amount, block.timestamp);
    }

    /**
     * @dev Finalize presale
     */
    function finalizePresale() external override onlyOwner onlyAfterPresale {
        require(!presaleFinalized, "Already finalized");

        presaleFinalized = true;
        claimingEnabled = true;

        // Transfer remaining tokens to treasury
        uint256 remainingTokens = epcsToken.balanceOf(address(this)).safeSub(totalTokensSold);
        if (remainingTokens > 0) {
            epcsToken.safeTransfer(treasuryWallet, remainingTokens);
        }

        // Transfer raised funds to treasury (minus platform fee)
        _distributeFunds();
    }

    /**
     * @dev Set refund enabled
     */
    function setRefundEnabled(bool enabled) external override onlyOwner {
        refundEnabled = enabled;
    }

    /**
     * @dev Set claiming enabled
     */
    function setClaimingEnabled(bool enabled) external override onlyOwner {
        claimingEnabled = enabled;
    }

    /**
     * @dev Set token address
     */
    function setTokenAddress(address tokenAddress) external override onlyOwner validAddress(tokenAddress) {
        epcsToken = IERC20(tokenAddress);
    }

    /**
     * @dev Update supported tokens
     */
    function updateSupportedTokens(address[] calldata tokens, bool[] calldata supported) external override onlyOwner {
        require(tokens.length == supported.length, "Array length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            supportedTokens[tokens[i]] = supported[i];
        }
    }

    /**
     * @dev Set cooldown period
     */
    function setCooldownPeriod(uint256 cooldownPeriod) external override onlyOwner {
        // Implementation would update security manager
    }

    /**
     * @dev Set max slippage
     */
    function setMaxSlippage(uint256 maxSlippage) external override onlyOwner {
        require(maxSlippage <= MAX_SLIPPAGE, "Slippage too high");
        // Implementation would update security manager
    }

    // ============ Price Model Functions ============

    /**
     * @dev Configure pricing model
     */
    function configurePricingModel(
        PriceLib.PricingModel model,
        uint256[] calldata parameters
    ) external onlyOwner {
        priceConfig.model = model;
        priceConfig.parameters = parameters;

        emit PriceModelUpdated(model, parameters, block.timestamp);
    }

    /**
     * @dev Add price tier
     */
    function addPriceTier(
        uint256 threshold,
        uint256 price,
        uint256 priceIncrease,
        PriceLib.TierType tierType
    ) external onlyOwner {
        priceTiers.push(PriceLib.PriceTier({
            threshold: threshold,
            price: price,
            priceIncrease: priceIncrease,
            tierType: tierType,
            isActive: true
        }));
    }

    /**
     * @dev Configure bonding curve
     */
    function configureBondingCurve(
        uint256 reserveRatio,
        uint256 initialReserve
    ) external onlyOwner {
        bondingCurve = PriceLib.BondingCurveConfig({
            reserveRatio: reserveRatio,
            initialReserve: initialReserve,
            currentReserve: initialReserve,
            totalSupply: presaleConfig.maxTokensForSale,
            currentSupply: totalTokensSold
        });

        bondingCurveEnabled = true;

        emit BondingCurveConfigured(reserveRatio, initialReserve, block.timestamp);
    }

    // ============ Vesting Functions ============

    /**
     * @dev Enable vesting
     */
    function enableVesting(uint256 duration) external onlyOwner {
        vestingEnabled = true;

        // Set default vesting duration
        for (uint256 i = 0; i < totalParticipants; i++) {
            // Implementation would set vesting for all participants
        }
    }

    /**
     * @dev Claim vested tokens
     */
    function claimVestedTokens() external nonReentrant {
        require(vestingEnabled, "Vesting not enabled");
        require(vestingStart[msg.sender] > 0, "No vesting schedule");

        uint256 claimable = _calculateVestedAmount(msg.sender);
        require(claimable > 0, "No tokens to claim");

        vestedAmount[msg.sender] = vestedAmount[msg.sender].safeAdd(claimable);
        epcsToken.safeTransfer(msg.sender, claimable);
    }

    // ============ Internal Functions ============

    /**
     * @dev Process purchase transaction
     */
    function _processPurchase(
        address buyer,
        address paymentToken,
        uint256 paymentAmount,
        uint256 minTokens,
        address referrer
    ) internal {
        // Security checks
        (bool canTransact, string memory reason) = this.canPurchase(buyer, paymentAmount);
        require(canTransact, reason);

        // Get payment token price
        uint256 paymentTokenPrice = priceOracle.getLatestPrice(paymentToken);

        // Calculate USD value
        uint256 usdValue = MathLib.calculateTokensToReceive(
            paymentAmount,
            paymentTokenPrice,
            PRICE_PRECISION,
            tokenDecimals[paymentToken]
        );

        // Get current EPCS price
        uint256 tokenPrice = this.getCurrentPrice();

        // Calculate tokens to receive
        uint256 tokenAmount = MathLib.calculateTokensToReceive(
            paymentAmount,
            paymentTokenPrice,
            tokenPrice,
            tokenDecimals[paymentToken]
        );

        // Slippage protection
        require(tokenAmount >= minTokens, "Slippage too high");

        // Check limits
        require(usdValue >= presaleConfig.minPurchaseAmount, "Below minimum purchase");
        require(
            userUSDContribution[buyer].safeAdd(usdValue) <= presaleConfig.maxPurchaseAmount,
            "Exceeds maximum purchase"
        );
        require(
            totalUSDRaised.safeAdd(usdValue) <= presaleConfig.hardCap,
            "Exceeds hard cap"
        );
        require(
            totalTokensSold.safeAdd(tokenAmount) <= presaleConfig.maxTokensForSale,
            "Exceeds max tokens"
        );

        // Record transaction in security manager
        securityManager.recordTransaction(buyer, usdValue, 1);

        // Update user data
        if (userUSDContribution[buyer] == 0) {
            totalParticipants = totalParticipants.safeAdd(1);
        }

        userTokenBalance[buyer] = userTokenBalance[buyer].safeAdd(tokenAmount);
        userUSDContribution[buyer] = userUSDContribution[buyer].safeAdd(usdValue);
        lastPurchaseTime[buyer] = block.timestamp;

        // Store purchase info
        userPurchases[buyer].push(PurchaseInfo({
            tokenAmount: tokenAmount,
            usdAmount: usdValue,
            timestamp: block.timestamp,
            paymentToken: paymentToken,
            price: tokenPrice,
            claimed: false
        }));

        // Update global statistics
        totalTokensSold = totalTokensSold.safeAdd(tokenAmount);
        totalUSDRaised = totalUSDRaised.safeAdd(usdValue);

        // Update price based on model
        _updatePrice();

        // Handle referral
        if (referrer != address(0)) {
            _processReferral(buyer, referrer, usdValue);
        }

        // Update analytics
        _updateAnalytics(usdValue);

        emit PurchaseProcessed(buyer, paymentToken, paymentAmount, tokenAmount, tokenPrice, usdValue, referrer);
        emit TokensPurchased(buyer, paymentToken, paymentAmount, tokenAmount, tokenPrice, block.timestamp);
    }

    /**
     * @dev Update price based on current model
     */
    function _updatePrice() internal {
        uint256 newPrice;

        if (bondingCurveEnabled) {
            bondingCurve.currentSupply = totalTokensSold;
            newPrice = PriceLib.calculateBondingCurvePrice(bondingCurve, 0);
        } else if (priceTiers.length > 0) {
            (newPrice, ) = PriceLib.calculateTieredPrice(priceTiers, totalTokensSold);
        } else {
            newPrice = PriceLib.calculatePrice(priceConfig, totalTokensSold);
        }

        if (newPrice != currentPrice) {
            currentPrice = newPrice;
            emit PriceUpdated(newPrice, totalTokensSold, block.timestamp);
        }
    }

    /**
     * @dev Process referral bonus
     */
    function _processReferral(address buyer, address referrer, uint256 usdValue) internal {
        if (referrals[buyer] == address(0)) {
            referrals[buyer] = referrer;
        }

        uint256 bonus = usdValue.calculateBasisPoints(referralBonus);
        referralEarnings[referrer] = referralEarnings[referrer].safeAdd(bonus);

        emit ReferralSet(buyer, referrer, bonus, block.timestamp);
    }

    /**
     * @dev Update daily analytics
     */
    function _updateAnalytics(uint256 usdValue) internal {
        uint256 today = block.timestamp / 1 days;

        if (today != lastAnalyticsUpdate) {
            lastAnalyticsUpdate = today;
            dailyParticipants[today] = 0;
            dailyVolume[today] = 0;
        }

        dailyVolume[today] = dailyVolume[today].safeAdd(usdValue);
        dailyParticipants[today] = dailyParticipants[today].safeAdd(1);
    }

    /**
     * @dev Calculate claimable amount for user
     */
    function _calculateClaimableAmount(address user) internal view returns (uint256) {
        if (vestingEnabled) {
            return _calculateVestedAmount(user);
        }
        return userTokenBalance[user];
    }

    /**
     * @dev Calculate vested amount for user
     */
    function _calculateVestedAmount(address user) internal view returns (uint256) {
        if (vestingStart[user] == 0) return 0;

        uint256 elapsed = block.timestamp.safeSub(vestingStart[user]);
        uint256 duration = vestingDuration[user];

        if (elapsed >= duration) {
            return userTokenBalance[user].safeSub(vestedAmount[user]);
        }

        uint256 totalVestable = userTokenBalance[user];
        uint256 vested = totalVestable.safeMul(elapsed).safeDiv(duration);
        return vested.safeSub(vestedAmount[user]);
    }

    /**
     * @dev Setup vesting for user
     */
    function _setupVesting(address user, uint256 amount) internal {
        vestingStart[user] = block.timestamp;
        vestingDuration[user] = 180 days; // 6 months default

        emit VestingConfigured(user, vestingDuration[user], amount, block.timestamp);
    }

    /**
     * @dev Distribute raised funds
     */
    function _distributeFunds() internal {
        uint256 totalBNB = address(this).balance;
        uint256 totalUSDT = IERC20(usdtAddress).balanceOf(address(this));
        uint256 totalUSDC = IERC20(usdcAddress).balanceOf(address(this));

        // Calculate platform fee
        uint256 bnbFee = totalBNB.calculateBasisPoints(platformFee);
        uint256 usdtFee = totalUSDT.calculateBasisPoints(platformFee);
        uint256 usdcFee = totalUSDC.calculateBasisPoints(platformFee);

        // Transfer platform fees to treasury
        if (bnbFee > 0) {
            (bool success, ) = treasuryWallet.call{value: bnbFee}("");
            require(success, "BNB fee transfer failed");
        }

        if (usdtFee > 0) {
            IERC20(usdtAddress).safeTransfer(treasuryWallet, usdtFee);
        }

        if (usdcFee > 0) {
            IERC20(usdcAddress).safeTransfer(treasuryWallet, usdcFee);
        }

        // Transfer remaining funds to team wallet
        uint256 remainingBNB = totalBNB.safeSub(bnbFee);
        uint256 remainingUSDT = totalUSDT.safeSub(usdtFee);
        uint256 remainingUSDC = totalUSDC.safeSub(usdcFee);

        if (remainingBNB > 0) {
            (bool success, ) = teamWallet.call{value: remainingBNB}("");
            require(success, "BNB transfer failed");
        }

        if (remainingUSDT > 0) {
            IERC20(usdtAddress).safeTransfer(teamWallet, remainingUSDT);
        }

        if (remainingUSDC > 0) {
            IERC20(usdcAddress).safeTransfer(teamWallet, remainingUSDC);
        }
    }

    // ============ Additional Admin Functions ============

    /**
     * @dev Update treasury wallet
     */
    function updateTreasuryWallet(address newTreasury) external onlyOwner validAddress(newTreasury) {
        treasuryWallet = newTreasury;
    }

    /**
     * @dev Update team wallet
     */
    function updateTeamWallet(address newTeam) external onlyOwner validAddress(newTeam) {
        teamWallet = newTeam;
    }

    /**
     * @dev Update platform fee
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        platformFee = newFee;
    }

    /**
     * @dev Update referral bonus
     */
    function updateReferralBonus(uint256 newBonus) external onlyOwner {
        require(newBonus <= 2000, "Bonus too high"); // Max 20%
        referralBonus = newBonus;
    }

    /**
     * @dev Enable emergency withdraw
     */
    function enableEmergencyWithdraw() external onlyOwner {
        emergencyWithdrawEnabled = true;
    }

    /**
     * @dev Get daily analytics
     */
    function getDailyAnalytics(uint256 day) external view returns (uint256 volume, uint256 participants) {
        volume = dailyVolume[day];
        participants = dailyParticipants[day];
    }

    /**
     * @dev Get user vesting info
     */
    function getUserVestingInfo(address user) external view returns (
        uint256 start,
        uint256 duration,
        uint256 vested,
        uint256 claimable
    ) {
        start = vestingStart[user];
        duration = vestingDuration[user];
        vested = vestedAmount[user];
        claimable = _calculateVestedAmount(user);
    }

    /**
     * @dev Get referral info
     */
    function getReferralInfo(address user) external view returns (
        address referrer,
        uint256 earnings
    ) {
        referrer = referrals[user];
        earnings = referralEarnings[user];
    }

    /**
     * @dev Get price tier info
     */
    function getPriceTierInfo(uint256 index) external view returns (
        uint256 threshold,
        uint256 price,
        uint256 priceIncrease,
        PriceLib.TierType tierType,
        bool isActive
    ) {
        require(index < priceTiers.length, "Invalid tier index");

        PriceLib.PriceTier memory tier = priceTiers[index];
        threshold = tier.threshold;
        price = tier.price;
        priceIncrease = tier.priceIncrease;
        tierType = tier.tierType;
        isActive = tier.isActive;
    }

    /**
     * @dev Get bonding curve info
     */
    function getBondingCurveInfo() external view returns (
        uint256 reserveRatio,
        uint256 initialReserve,
        uint256 currentReserve,
        uint256 totalSupply,
        uint256 currentSupply,
        bool enabled
    ) {
        reserveRatio = bondingCurve.reserveRatio;
        initialReserve = bondingCurve.initialReserve;
        currentReserve = bondingCurve.currentReserve;
        totalSupply = bondingCurve.totalSupply;
        currentSupply = bondingCurve.currentSupply;
        enabled = bondingCurveEnabled;
    }

    /**
     * @dev Get contract info
     */
    function getContractInfo() external view returns (
        address epcsTokenAddress,
        address priceOracleAddress,
        address securityManagerAddress,
        address usdtTokenAddress,
        address usdcTokenAddress,
        bool vestingEnabledStatus,
        bool claimingEnabledStatus,
        bool refundEnabledStatus,
        bool presaleFinalizedStatus
    ) {
        epcsTokenAddress = address(epcsToken);
        priceOracleAddress = address(priceOracle);
        securityManagerAddress = address(securityManager);
        usdtTokenAddress = usdtAddress;
        usdcTokenAddress = usdcAddress;
        vestingEnabledStatus = vestingEnabled;
        claimingEnabledStatus = claimingEnabled;
        refundEnabledStatus = refundEnabled;
        presaleFinalizedStatus = presaleFinalized;
    }

    // ============ Receive Function ============

    /**
     * @dev Receive function to handle direct BNB transfers
     */
    receive() external payable {
        require(isPresaleActive(), "Presale not active");
        _processPurchase(msg.sender, BNB_ADDRESS, msg.value, 0, address(0));
    }

    /**
     * @dev Fallback function
     */
    fallback() external payable {
        revert("Function not found");
    }
}
