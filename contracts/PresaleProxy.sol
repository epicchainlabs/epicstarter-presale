// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IEpicStarterPresale.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/ISecurityManager.sol";
import "./libraries/MathLib.sol";
import "./libraries/PriceLib.sol";

/**
 * @title PresaleProxy
 * @dev Upgradeable proxy implementation of the EpicStarter presale contract
 * @author EpicChainLabs
 *
 * This contract provides upgradeable functionality while maintaining state across upgrades.
 * It implements the UUPS (Universal Upgradeable Proxy Standard) pattern for secure upgrades.
 */
contract PresaleProxy is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IEpicStarterPresale
{
    using SafeERC20 for IERC20;
    using MathLib for uint256;

    // ============ Storage ============

    /// @custom:storage-location erc7201:epicstarter.storage.PresaleProxy
    struct PresaleStorage {
        // Core configuration
        PresaleConfig presaleConfig;
        PriceFeeds priceFeeds;

        // Contracts
        IERC20 epcsToken;
        IPriceOracle priceOracle;
        ISecurityManager securityManager;

        // Supported tokens
        mapping(address => bool) supportedTokens;
        mapping(address => uint256) tokenDecimals;

        // Payment token addresses
        address usdtAddress;
        address usdcAddress;

        // User data
        mapping(address => PurchaseInfo[]) userPurchases;
        mapping(address => uint256) userTokenBalance;
        mapping(address => uint256) userUSDContribution;
        mapping(address => uint256) lastPurchaseTime;
        mapping(address => bool) hasClaimed;

        // Presale statistics
        uint256 totalTokensSold;
        uint256 totalUSDRaised;
        uint256 totalParticipants;
        uint256 currentPrice;

        // Price configuration
        PriceLib.PriceConfig priceConfig;
        PriceLib.PriceTier[] priceTiers;

        // Bonding curve
        PriceLib.BondingCurveConfig bondingCurve;
        bool bondingCurveEnabled;

        // Controls
        bool claimingEnabled;
        bool refundEnabled;
        bool presaleFinalized;
        bool emergencyWithdrawEnabled;

        // Vesting
        mapping(address => uint256) vestingStart;
        mapping(address => uint256) vestingDuration;
        mapping(address => uint256) vestedAmount;
        bool vestingEnabled;

        // Treasury and team
        address treasuryWallet;
        address teamWallet;
        address liquidityWallet;

        // Fees
        uint256 platformFee;
        uint256 referralBonus;
        mapping(address => address) referrals;
        mapping(address => uint256) referralEarnings;

        // Analytics
        mapping(uint256 => uint256) dailyVolume;
        mapping(uint256 => uint256) dailyParticipants;
        uint256 lastAnalyticsUpdate;

        // Upgrade controls
        address upgradeAdmin;
        uint256 upgradeDelay;
        mapping(bytes32 => uint256) pendingUpgrades;

        // Emergency controls
        address emergencyCouncil;
        mapping(address => bool) emergencyResponders;

        // Feature flags
        mapping(string => bool) featureFlags;

        // Reserved storage slots for future upgrades
        uint256[50] __gap;
    }

    // keccak256(abi.encode(uint256(keccak256("epicstarter.storage.PresaleProxy")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PresaleStorageLocation = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    function _getPresaleStorage() private pure returns (PresaleStorage storage $) {
        assembly {
            $.slot := PresaleStorageLocation
        }
    }

    // ============ Constants ============

    uint256 private constant PRICE_PRECISION = 10**18;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MIN_PURCHASE_USD = 10 * PRICE_PRECISION;
    uint256 private constant MAX_PURCHASE_USD = 100000 * PRICE_PRECISION;
    uint256 private constant COOLDOWN_PERIOD = 30;
    uint256 private constant UPGRADE_DELAY = 48 hours;

    // ============ Events ============

    event UpgradeProposed(address indexed newImplementation, uint256 upgradeTime);
    event UpgradeExecuted(address indexed newImplementation, uint256 timestamp);
    event UpgradeCancelled(address indexed implementation, uint256 timestamp);
    event EmergencyCouncilUpdated(address indexed oldCouncil, address indexed newCouncil);
    event FeatureFlagUpdated(string indexed feature, bool enabled);

    // ============ Modifiers ============

    modifier onlyUpgradeAdmin() {
        PresaleStorage storage $ = _getPresaleStorage();
        require(msg.sender == $.upgradeAdmin || msg.sender == owner(), "Not upgrade admin");
        _;
    }

    modifier onlyEmergencyCouncil() {
        PresaleStorage storage $ = _getPresaleStorage();
        require(msg.sender == $.emergencyCouncil || msg.sender == owner(), "Not emergency council");
        _;
    }

    modifier onlyDuringPresale() {
        require(isPresaleActive(), "Presale not active");
        _;
    }

    modifier onlyAfterPresale() {
        PresaleStorage storage $ = _getPresaleStorage();
        require(block.timestamp > $.presaleConfig.endTime, "Presale still active");
        _;
    }

    modifier featureEnabled(string memory feature) {
        PresaleStorage storage $ = _getPresaleStorage();
        require($.featureFlags[feature], "Feature disabled");
        _;
    }

    // ============ Initializer ============

    /**
     * @dev Initialize the proxy contract
     */
    function initialize(
        address _owner,
        address _epcsToken,
        address _priceOracle,
        address _securityManager,
        address _usdtAddress,
        address _usdcAddress,
        address _treasuryWallet
    ) public initializer {
        __Ownable_init(_owner);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        PresaleStorage storage $ = _getPresaleStorage();

        // Initialize contracts
        $.epcsToken = IERC20(_epcsToken);
        $.priceOracle = IPriceOracle(_priceOracle);
        $.securityManager = ISecurityManager(_securityManager);
        $.usdtAddress = _usdtAddress;
        $.usdcAddress = _usdcAddress;
        $.treasuryWallet = _treasuryWallet;

        // Initialize supported tokens
        $.supportedTokens[address(0)] = true; // BNB
        $.supportedTokens[_usdtAddress] = true;
        $.supportedTokens[_usdcAddress] = true;

        $.tokenDecimals[address(0)] = 18;
        $.tokenDecimals[_usdtAddress] = 18;
        $.tokenDecimals[_usdcAddress] = 18;

        // Initialize configuration
        $.presaleConfig = PresaleConfig({
            startTime: 0,
            endTime: 0,
            hardCap: 5000000000 * PRICE_PRECISION,
            maxTokensForSale: 100000000 * PRICE_PRECISION,
            minPurchaseAmount: MIN_PURCHASE_USD,
            maxPurchaseAmount: MAX_PURCHASE_USD,
            initialPrice: 1 * PRICE_PRECISION,
            priceIncreaseRate: 100,
            kycRequired: false,
            whitelistEnabled: false,
            paused: false
        });

        // Initialize price configuration
        $.priceConfig = PriceLib.PriceConfig({
            initialPrice: $.presaleConfig.initialPrice,
            finalPrice: 10 * PRICE_PRECISION,
            totalSupply: $.presaleConfig.maxTokensForSale,
            currentSupply: 0,
            startTime: 0,
            endTime: 0,
            model: PriceLib.PricingModel.LINEAR,
            parameters: new uint256[](0)
        });

        $.currentPrice = $.presaleConfig.initialPrice;
        $.platformFee = 250; // 2.5%
        $.referralBonus = 500; // 5%
        $.upgradeAdmin = _owner;
        $.upgradeDelay = UPGRADE_DELAY;

        // Enable core features
        $.featureFlags["PURCHASES"] = true;
        $.featureFlags["DYNAMIC_PRICING"] = true;
        $.featureFlags["REFERRALS"] = true;
        $.featureFlags["VESTING"] = false;
    }

    // ============ Purchase Functions ============

    /**
     * @dev Purchase tokens with BNB
     */
    function buyWithBNB(uint256 minTokens)
        external
        payable
        override
        onlyDuringPresale
        nonReentrant
        featureEnabled("PURCHASES")
    {
        require(msg.value > 0, "Invalid BNB amount");
        _processPurchase(msg.sender, address(0), msg.value, minTokens, address(0));
    }

    /**
     * @dev Purchase tokens with USDT
     */
    function buyWithUSDT(uint256 usdtAmount, uint256 minTokens)
        external
        override
        onlyDuringPresale
        nonReentrant
        featureEnabled("PURCHASES")
    {
        require(usdtAmount > 0, "Invalid USDT amount");
        PresaleStorage storage $ = _getPresaleStorage();

        IERC20($.usdtAddress).safeTransferFrom(msg.sender, address(this), usdtAmount);
        _processPurchase(msg.sender, $.usdtAddress, usdtAmount, minTokens, address(0));
    }

    /**
     * @dev Purchase tokens with USDC
     */
    function buyWithUSDC(uint256 usdcAmount, uint256 minTokens)
        external
        override
        onlyDuringPresale
        nonReentrant
        featureEnabled("PURCHASES")
    {
        require(usdcAmount > 0, "Invalid USDC amount");
        PresaleStorage storage $ = _getPresaleStorage();

        IERC20($.usdcAddress).safeTransferFrom(msg.sender, address(this), usdcAmount);
        _processPurchase(msg.sender, $.usdcAddress, usdcAmount, minTokens, address(0));
    }

    /**
     * @dev Claim purchased tokens
     */
    function claimTokens() external override nonReentrant {
        PresaleStorage storage $ = _getPresaleStorage();
        require($.claimingEnabled, "Claiming not enabled");
        require(!$.hasClaimed[msg.sender], "Already claimed");
        require($.userTokenBalance[msg.sender] > 0, "No tokens to claim");

        uint256 claimableAmount = _calculateClaimableAmount(msg.sender);
        require(claimableAmount > 0, "No tokens available for claim");

        $.hasClaimed[msg.sender] = true;

        if ($.vestingEnabled) {
            _setupVesting(msg.sender, claimableAmount);
        } else {
            $.epcsToken.safeTransfer(msg.sender, claimableAmount);
        }

        emit TokensClaimed(msg.sender, claimableAmount, block.timestamp);
    }

    /**
     * @dev Request refund
     */
    function requestRefund() external override nonReentrant {
        PresaleStorage storage $ = _getPresaleStorage();
        require($.refundEnabled, "Refunds not enabled");
        require($.userUSDContribution[msg.sender] > 0, "No contribution to refund");
        require(!$.hasClaimed[msg.sender], "Cannot refund after claiming");

        uint256 refundAmount = $.userUSDContribution[msg.sender];
        PurchaseInfo[] memory purchases = $.userPurchases[msg.sender];

        // Clear user data
        $.userTokenBalance[msg.sender] = 0;
        $.userUSDContribution[msg.sender] = 0;
        delete $.userPurchases[msg.sender];

        // Process refunds
        for (uint256 i = 0; i < purchases.length; i++) {
            _processRefund(msg.sender, purchases[i]);
        }

        // Update statistics
        $.totalTokensSold = $.totalTokensSold.safeSub($.userTokenBalance[msg.sender]);
        $.totalUSDRaised = $.totalUSDRaised.safeSub(refundAmount);
        $.totalParticipants = $.totalParticipants > 0 ? $.totalParticipants - 1 : 0;

        emit RefundIssued(msg.sender, address(0), refundAmount, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @dev Get current EPCS token price
     */
    function getCurrentPrice() external view override returns (uint256) {
        PresaleStorage storage $ = _getPresaleStorage();

        if ($.bondingCurveEnabled) {
            return PriceLib.calculateBondingCurvePrice($.bondingCurve, 0);
        }

        if ($.priceTiers.length > 0) {
            (uint256 price, ) = PriceLib.calculateTieredPrice($.priceTiers, $.totalTokensSold);
            return price;
        }

        return PriceLib.calculatePrice($.priceConfig, $.totalTokensSold);
    }

    /**
     * @dev Get latest price from oracle
     */
    function getLatestPrice(address token) external view override returns (uint256) {
        PresaleStorage storage $ = _getPresaleStorage();
        return $.priceOracle.getLatestPrice(token);
    }

    /**
     * @dev Calculate tokens to receive
     */
    function calculateTokensToReceive(address paymentToken, uint256 paymentAmount)
        external
        view
        override
        returns (uint256)
    {
        PresaleStorage storage $ = _getPresaleStorage();
        require($.supportedTokens[paymentToken], "Token not supported");

        uint256 paymentTokenPrice = $.priceOracle.getLatestPrice(paymentToken);
        uint256 tokenPrice = this.getCurrentPrice();

        return MathLib.calculateTokensToReceive(
            paymentAmount,
            paymentTokenPrice,
            tokenPrice,
            $.tokenDecimals[paymentToken]
        );
    }

    /**
     * @dev Get user purchases
     */
    function getUserPurchases(address user) external view override returns (PurchaseInfo[] memory) {
        PresaleStorage storage $ = _getPresaleStorage();
        return $.userPurchases[user];
    }

    /**
     * @dev Get user token balance
     */
    function getUserTokenBalance(address user) external view override returns (uint256) {
        PresaleStorage storage $ = _getPresaleStorage();
        return $.userTokenBalance[user];
    }

    /**
     * @dev Get user USD contribution
     */
    function getUserUSDContribution(address user) external view override returns (uint256) {
        PresaleStorage storage $ = _getPresaleStorage();
        return $.userUSDContribution[user];
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
        PresaleStorage storage $ = _getPresaleStorage();
        _totalTokensSold = $.totalTokensSold;
        _totalUSDRaised = $.totalUSDRaised;
        _totalParticipants = $.totalParticipants;
        _currentPrice = this.getCurrentPrice();
        _remainingTokens = $.presaleConfig.maxTokensForSale.safeSub($.totalTokensSold);
        _remainingCap = $.presaleConfig.hardCap.safeSub($.totalUSDRaised);
    }

    /**
     * @dev Check if user is whitelisted
     */
    function isWhitelisted(address user) external view override returns (bool) {
        PresaleStorage storage $ = _getPresaleStorage();
        return $.securityManager.isWhitelisted(user);
    }

    /**
     * @dev Check if user has KYC approval
     */
    function isKYCApproved(address user) external view override returns (bool) {
        PresaleStorage storage $ = _getPresaleStorage();
        return $.securityManager.isKYCApproved(user);
    }

    /**
     * @dev Check if presale is active
     */
    function isPresaleActive() public view override returns (bool) {
        PresaleStorage storage $ = _getPresaleStorage();
        return block.timestamp >= $.presaleConfig.startTime &&
               block.timestamp <= $.presaleConfig.endTime &&
               !$.presaleConfig.paused &&
               !$.presaleFinalized &&
               $.totalUSDRaised < $.presaleConfig.hardCap &&
               $.totalTokensSold < $.presaleConfig.maxTokensForSale;
    }

    /**
     * @dev Check if user can purchase
     */
    function canPurchase(address user, uint256 amount) external view override returns (bool, string memory) {
        PresaleStorage storage $ = _getPresaleStorage();

        if (!isPresaleActive()) {
            return (false, "Presale not active");
        }

        (bool canTransact, string memory reason) = $.securityManager.canTransact(user, amount, 1);
        if (!canTransact) {
            return (false, reason);
        }

        if ($.presaleConfig.kycRequired && !$.securityManager.isKYCApproved(user)) {
            return (false, "KYC required");
        }

        if ($.presaleConfig.whitelistEnabled && !$.securityManager.isWhitelisted(user)) {
            return (false, "User not whitelisted");
        }

        if (amount < $.presaleConfig.minPurchaseAmount) {
            return (false, "Below minimum purchase");
        }

        uint256 newContribution = $.userUSDContribution[user].safeAdd(amount);
        if (newContribution > $.presaleConfig.maxPurchaseAmount) {
            return (false, "Exceeds maximum purchase");
        }

        if (block.timestamp < $.lastPurchaseTime[user] + COOLDOWN_PERIOD) {
            return (false, "Cooldown period active");
        }

        return (true, "");
    }

    // ============ Admin Functions ============

    /**
     * @dev Update presale configuration
     */
    function updatePresaleConfig(PresaleConfig calldata config) external override onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        require(config.startTime < config.endTime, "Invalid time range");
        require(config.hardCap > 0, "Invalid hard cap");
        require(config.maxTokensForSale > 0, "Invalid max tokens");
        require(config.initialPrice > 0, "Invalid initial price");

        $.presaleConfig = config;
        $.currentPrice = config.initialPrice;

        emit PresaleConfigUpdated(
            config.startTime,
            config.endTime,
            config.hardCap,
            config.maxTokensForSale
        );
    }

    /**
     * @dev Update price feeds
     */
    function updatePriceFeeds(PriceFeeds calldata feeds) external override onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        $.priceFeeds = feeds;
    }

    /**
     * @dev Update whitelist
     */
    function updateWhitelist(address[] calldata users, bool[] calldata whitelisted) external override onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        $.securityManager.updateWhitelist(users, whitelisted);
    }

    /**
     * @dev Update KYC status
     */
    function updateKYCStatus(address[] calldata users, bool[] calldata approved) external override onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        $.securityManager.updateKYCStatus(users, approved);
    }

    /**
     * @dev Set paused state
     */
    function setPaused(bool paused) external override onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        $.presaleConfig.paused = paused;
        emit PausedStateChanged(paused, block.timestamp);
    }

    /**
     * @dev Emergency withdraw
     */
    function emergencyWithdraw(address token, address to, uint256 amount) external override onlyEmergencyCouncil {
        PresaleStorage storage $ = _getPresaleStorage();
        require($.emergencyWithdrawEnabled, "Emergency withdraw not enabled");

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
        PresaleStorage storage $ = _getPresaleStorage();
        require(!$.presaleFinalized, "Already finalized");

        $.presaleFinalized = true;
        $.claimingEnabled = true;

        uint256 remainingTokens = $.epcsToken.balanceOf(address(this)).safeSub($.totalTokensSold);
        if (remainingTokens > 0) {
            $.epcsToken.safeTransfer($.treasuryWallet, remainingTokens);
        }

        _distributeFunds();
    }

    /**
     * @dev Set refund enabled
     */
    function setRefundEnabled(bool enabled) external override onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        $.refundEnabled = enabled;
    }

    /**
     * @dev Set claiming enabled
     */
    function setClaimingEnabled(bool enabled) external override onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        $.claimingEnabled = enabled;
    }

    /**
     * @dev Set token address
     */
    function setTokenAddress(address tokenAddress) external override onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        require(tokenAddress != address(0), "Invalid address");
        $.epcsToken = IERC20(tokenAddress);
    }

    /**
     * @dev Update supported tokens
     */
    function updateSupportedTokens(address[] calldata tokens, bool[] calldata supported) external override onlyOwner {
        require(tokens.length == supported.length, "Array length mismatch");
        PresaleStorage storage $ = _getPresaleStorage();

        for (uint256 i = 0; i < tokens.length; i++) {
            $.supportedTokens[tokens[i]] = supported[i];
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
        require(maxSlippage <= 1000, "Slippage too high");
        // Implementation would update security manager
    }

    // ============ Upgrade Functions ============

    /**
     * @dev Propose upgrade to new implementation
     */
    function proposeUpgrade(address newImplementation) external onlyUpgradeAdmin {
        PresaleStorage storage $ = _getPresaleStorage();
        bytes32 upgradeHash = keccak256(abi.encodePacked(newImplementation));
        uint256 upgradeTime = block.timestamp + $.upgradeDelay;

        $.pendingUpgrades[upgradeHash] = upgradeTime;

        emit UpgradeProposed(newImplementation, upgradeTime);
    }

    /**
     * @dev Execute pending upgrade
     */
    function executeUpgrade(address newImplementation) external onlyUpgradeAdmin {
        PresaleStorage storage $ = _getPresaleStorage();
        bytes32 upgradeHash = keccak256(abi.encodePacked(newImplementation));
        uint256 upgradeTime = $.pendingUpgrades[upgradeHash];

        require(upgradeTime != 0, "Upgrade not proposed");
        require(block.timestamp >= upgradeTime, "Upgrade delay not met");

        delete $.pendingUpgrades[upgradeHash];
        _upgradeToAndCall(newImplementation, "", false);

        emit UpgradeExecuted(newImplementation, block.timestamp);
    }

    /**
     * @dev Cancel pending upgrade
     */
    function cancelUpgrade(address implementation) external onlyUpgradeAdmin {
        PresaleStorage storage $ = _getPresaleStorage();
        bytes32 upgradeHash = keccak256(abi.encodePacked(implementation));
        delete $.pendingUpgrades[upgradeHash];

        emit UpgradeCancelled(implementation, block.timestamp);
    }

    /**
     * @dev Set upgrade admin
     */
    function setUpgradeAdmin(address newAdmin) external onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        $.upgradeAdmin = newAdmin;
    }

    /**
     * @dev Set emergency council
     */
    function setEmergencyCouncil(address newCouncil) external onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        address oldCouncil = $.emergencyCouncil;
        $.emergencyCouncil = newCouncil;

        emit EmergencyCouncilUpdated(oldCouncil, newCouncil);
    }

    /**
     * @dev Update feature flag
     */
    function setFeatureFlag(string calldata feature, bool enabled) external onlyOwner {
        PresaleStorage storage $ = _getPresaleStorage();
        $.featureFlags[feature] = enabled;

        emit FeatureFlagUpdated(feature, enabled);
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
        PresaleStorage storage $ = _getPresaleStorage();

        (bool canTransact, string memory reason) = this.canPurchase(buyer, paymentAmount);
        require(canTransact, reason);

        uint256 paymentTokenPrice = $.priceOracle.getLatestPrice(paymentToken);
        uint256 usdValue = MathLib.calculateTokensToReceive(
            paymentAmount,
            paymentTokenPrice,
            PRICE_PRECISION,
            $.tokenDecimals[paymentToken]
        );

        uint256 tokenPrice = this.getCurrentPrice();
        uint256 tokenAmount = MathLib.calculateTokensToReceive(
            paymentAmount,
            paymentTokenPrice,
            tokenPrice,
            $.tokenDecimals[paymentToken]
        );

        require(tokenAmount >= minTokens, "Slippage too high");

        // Update user data
        if ($.userUSDContribution[buyer] == 0) {
            $.totalParticipants = $.totalParticipants.safeAdd(1);
        }

        $.userTokenBalance[buyer] = $.userTokenBalance[buyer].safeAdd(tokenAmount);
        $.userUSDContribution[buyer] = $.userUSDContribution[buyer].safeAdd(usdValue);
        $.lastPurchaseTime[buyer] = block.timestamp;

        // Store purchase info
        $.userPurchases[buyer].push(PurchaseInfo({
            tokenAmount: tokenAmount,
            usdAmount: usdValue,
            timestamp: block.timestamp,
            paymentToken: paymentToken,
            price: tokenPrice,
            claimed: false
        }));

        // Update global statistics
        $.totalTokensSold = $.totalTokensSold.safeAdd(tokenAmount);
        $.totalUSDRaised = $.totalUSDRaised.safeAdd(usdValue);

        // Update price
        _updatePrice();

        // Handle referral
        if (referrer != address(0)) {
            _processReferral(buyer, referrer, usdValue);
        }

        emit TokensPurchased(buyer, paymentToken, paymentAmount, tokenAmount, tokenPrice, block.timestamp);
    }

    /**
     * @dev Update price based on current model
     */
    function _updatePrice() internal {
        PresaleStorage storage $ = _getPresaleStorage();
        uint256 newPrice;

        if ($.bondingCurveEnabled) {
            $.bondingCurve.currentSupply = $.totalTokensSold;
            newPrice = PriceLib.calculateBondingCurvePrice($.bondingCurve, 0);
        } else if ($.priceTiers.length > 0) {
            (newPrice, ) = PriceLib.calculateTieredPrice($.priceTiers, $.totalTokensSold);
        } else {
            newPrice = PriceLib.calculatePrice($.priceConfig, $.totalTokensSold);
        }

        if (newPrice != $.currentPrice) {
            $.currentPrice = newPrice;
            emit PriceUpdated(newPrice, $.totalTokensSold, block.timestamp);
        }
    }

    /**
     * @dev Process referral bonus
     */
    function _processReferral(address buyer, address referrer, uint256 usdValue) internal {
        PresaleStorage storage $ = _getPresaleStorage();

        if ($.referrals[buyer] == address(0)) {
            $.referrals[buyer] = referrer;
        }

        uint256 bonus = usdValue.calculateBasisPoints($.referralBonus);
        $.referralEarnings[referrer] = $.referralEarnings[referrer].safeAdd(bonus);
    }

    /**
     * @dev Process refund for a purchase
     */
    function _processRefund(address user, PurchaseInfo memory purchase) internal {
        PresaleStorage storage $ = _getPresaleStorage();

        if (purchase.paymentToken == address(0)) {
            uint256 bnbPrice = $.priceOracle.getLatestPrice(address(0));
            uint256 bnbAmount = purchase.usdAmount.safeMul(PRICE_PRECISION).safeDiv(bnbPrice);

            (bool success, ) = user.call{value: bnbAmount}("");
            require(success, "BNB refund failed");
        } else {
            uint256 tokenPrice = $.priceOracle.getLatestPrice(purchase.paymentToken);
            uint256 tokenAmount = purchase.usdAmount.safeMul(PRICE_PRECISION).safeDiv(tokenPrice);

            IERC20(purchase.paymentToken).safeTransfer(user, tokenAmount);
        }
    }

    /**
     * @dev Calculate claimable amount for user
     */
    function _calculateClaimableAmount(address user) internal view returns (uint256) {
        PresaleStorage storage $ = _getPresaleStorage();

        if ($.vestingEnabled) {
            return _calculateVestedAmount(user);
        }
        return $.userTokenBalance[user];
    }

    /**
     * @dev Calculate vested amount for user
     */
    function _calculateVestedAmount(address user) internal view returns (uint256) {
        PresaleStorage storage $ = _getPresaleStorage();

        if ($.vestingStart[user] == 0) return 0;

        uint256 elapsed = block.timestamp.safeSub($.vestingStart[user]);
        uint256 duration = $.vestingDuration[user];

        if (elapsed >= duration) {
            return $.userTokenBalance[user].safeSub($.vestedAmount[user]);
        }

        uint256 totalVestable = $.userTokenBalance[user];
        uint256 vested = totalVestable.safeMul(elapsed).safeDiv(duration);
        return vested.safeSub($.vestedAmount[user]);
    }

    /**
     * @dev Setup vesting for user
     */
    function _setupVesting(address user, uint256 amount) internal {
        PresaleStorage storage $ = _getPresaleStorage();

        $.vestingStart[user] = block.timestamp;
        $.vestingDuration[user] = 180 days; // 6 months default
    }

    /**
     * @dev Distribute raised funds
     */
    function _distributeFunds() internal {
        PresaleStorage storage $ = _getPresaleStorage();

        uint256 totalBNB = address(this).balance;
        uint256 totalUSDT = IERC20($.usdtAddress).balanceOf(address(this));
        uint256 totalUSDC = IERC20($.usdcAddress).balanceOf(address(this));

        // Calculate platform fee
        uint256 bnbFee = totalBNB.calculateBasisPoints($.platformFee);
        uint256 usdtFee = totalUSDT.calculateBasisPoints($.platformFee);
        uint256 usdcFee = totalUSDC.calculateBasisPoints($.platformFee);

        // Transfer platform fees
        if (bnbFee > 0) {
            (bool success, ) = $.treasuryWallet.call{value: bnbFee}("");
            require(success, "BNB fee transfer failed");
        }

        if (usdtFee > 0) {
            IERC20($.usdtAddress).safeTransfer($.treasuryWallet, usdtFee);
        }

        if (usdcFee > 0) {
            IERC20($.usdcAddress).safeTransfer($.treasuryWallet, usdcFee);
        }

        // Transfer remaining funds
        uint256 remainingBNB = totalBNB.safeSub(bnbFee);
        uint256 remainingUSDT = totalUSDT.safeSub(usdtFee);
        uint256 remainingUSDC = totalUSDC.safeSub(usdcFee);

        if (remainingBNB > 0) {
            (bool success, ) = $.teamWallet.call{value: remainingBNB}("");
            require(success, "BNB transfer failed");
        }

        if (remainingUSDT > 0) {
            IERC20($.usdtAddress).safeTransfer($.teamWallet, remainingUSDT);
        }

        if (remainingUSDC > 0) {
            IERC20($.usdcAddress).safeTransfer($.teamWallet, remainingUSDC);
        }
    }

    /**
     * @dev Authorize upgrade (required by UUPSUpgradeable)
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyUpgradeAdmin {
        // Additional authorization logic can be added here
    }

    // ============ Additional View Functions ============

    /**
     * @dev Get upgrade information
     */
    function getUpgradeInfo() external view returns (
        address upgradeAdmin,
        uint256 upgradeDelay,
        address emergencyCouncil
    ) {
        PresaleStorage storage $ = _getPresaleStorage();
        upgradeAdmin = $.upgradeAdmin;
        upgradeDelay = $.upgradeDelay;
        emergencyCouncil = $.emergencyCouncil;
    }

    /**
     * @dev Get feature flag status
     */
    function getFeatureFlag(string calldata feature) external view returns (bool) {
        PresaleStorage storage $ = _getPresaleStorage();
        return $.featureFlags[feature];
    }

    /**
     * @dev Get contract version
     */
    function getVersion() external pure returns (string memory) {
        return "2.0.0";
    }

    /**
     * @dev Get pending upgrade time
     */
    function getPendingUpgradeTime(address implementation) external view returns (uint256) {
        PresaleStorage storage $ = _getPresaleStorage();
        bytes32 upgradeHash = keccak256(abi.encodePacked(implementation));
        return $.pendingUpgrades[upgradeHash];
    }

    // ============ Receive Function ============

    /**
     * @dev Receive function to handle direct BNB transfers
     */
    receive() external payable {
        require(isPresaleActive(), "Presale not active");
        _processPurchase(msg.sender, address(0), msg.value, 0, address(0));
    }

    /**
     * @dev Fallback function
     */
    fallback() external payable {
        revert("Function not found");
    }
}
