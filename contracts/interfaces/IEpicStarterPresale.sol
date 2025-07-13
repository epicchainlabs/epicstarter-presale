// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEpicStarterPresale
 * @dev Interface for the EpicStarter Presale contract with oracle-based dynamic pricing
 * @author EpicChainLabs
 */
interface IEpicStarterPresale {
    // ============ Structs ============

    struct PurchaseInfo {
        uint256 tokenAmount;
        uint256 usdAmount;
        uint256 timestamp;
        address paymentToken;
        uint256 price;
        bool claimed;
    }

    struct PresaleConfig {
        uint256 startTime;
        uint256 endTime;
        uint256 hardCap;
        uint256 maxTokensForSale;
        uint256 minPurchaseAmount;
        uint256 maxPurchaseAmount;
        uint256 initialPrice;
        uint256 priceIncreaseRate;
        bool kycRequired;
        bool whitelistEnabled;
        bool paused;
    }

    struct PriceFeeds {
        address bnbUsdFeed;
        address usdtUsdFeed;
        address usdcUsdFeed;
        uint256 heartbeatTimeout;
        uint256 priceDeviationThreshold;
    }

    // ============ Events ============

    event TokensPurchased(
        address indexed buyer,
        address indexed paymentToken,
        uint256 paymentAmount,
        uint256 tokenAmount,
        uint256 price,
        uint256 timestamp
    );

    event TokensClaimed(
        address indexed buyer,
        uint256 tokenAmount,
        uint256 timestamp
    );

    event PriceUpdated(
        uint256 newPrice,
        uint256 totalSold,
        uint256 timestamp
    );

    event PresaleConfigUpdated(
        uint256 startTime,
        uint256 endTime,
        uint256 hardCap,
        uint256 maxTokensForSale
    );

    event EmergencyWithdraw(
        address indexed token,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );

    event RefundIssued(
        address indexed buyer,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    event WhitelistUpdated(
        address indexed user,
        bool whitelisted,
        uint256 timestamp
    );

    event KYCStatusUpdated(
        address indexed user,
        bool kycApproved,
        uint256 timestamp
    );

    event PausedStateChanged(
        bool paused,
        uint256 timestamp
    );

    // ============ Purchase Functions ============

    /**
     * @dev Purchase tokens with BNB
     * @param minTokens Minimum tokens expected (slippage protection)
     */
    function buyWithBNB(uint256 minTokens) external payable;

    /**
     * @dev Purchase tokens with USDT
     * @param usdtAmount Amount of USDT to spend
     * @param minTokens Minimum tokens expected (slippage protection)
     */
    function buyWithUSDT(uint256 usdtAmount, uint256 minTokens) external;

    /**
     * @dev Purchase tokens with USDC
     * @param usdcAmount Amount of USDC to spend
     * @param minTokens Minimum tokens expected (slippage protection)
     */
    function buyWithUSDC(uint256 usdcAmount, uint256 minTokens) external;

    /**
     * @dev Claim purchased tokens (if claiming is enabled)
     */
    function claimTokens() external;

    /**
     * @dev Request refund (if refund is enabled)
     */
    function requestRefund() external;

    // ============ View Functions ============

    /**
     * @dev Get current EPCS token price in USD (18 decimals)
     */
    function getCurrentPrice() external view returns (uint256);

    /**
     * @dev Get latest price from Chainlink oracle
     * @param token Address of the token (BNB, USDT, USDC)
     */
    function getLatestPrice(address token) external view returns (uint256);

    /**
     * @dev Calculate tokens to receive for given payment amount
     * @param paymentToken Address of payment token
     * @param paymentAmount Amount of payment token
     */
    function calculateTokensToReceive(
        address paymentToken,
        uint256 paymentAmount
    ) external view returns (uint256);

    /**
     * @dev Get user's purchase history
     * @param user Address of the user
     */
    function getUserPurchases(address user) external view returns (PurchaseInfo[] memory);

    /**
     * @dev Get total tokens purchased by user
     * @param user Address of the user
     */
    function getUserTokenBalance(address user) external view returns (uint256);

    /**
     * @dev Get total USD contributed by user
     * @param user Address of the user
     */
    function getUserUSDContribution(address user) external view returns (uint256);

    /**
     * @dev Get presale statistics
     */
    function getPresaleStats() external view returns (
        uint256 totalTokensSold,
        uint256 totalUSDRaised,
        uint256 totalParticipants,
        uint256 currentPrice,
        uint256 remainingTokens,
        uint256 remainingCap
    );

    /**
     * @dev Check if user is whitelisted
     * @param user Address of the user
     */
    function isWhitelisted(address user) external view returns (bool);

    /**
     * @dev Check if user has completed KYC
     * @param user Address of the user
     */
    function isKYCApproved(address user) external view returns (bool);

    /**
     * @dev Check if presale is active
     */
    function isPresaleActive() external view returns (bool);

    /**
     * @dev Check if user can purchase tokens
     * @param user Address of the user
     * @param amount Amount to purchase in USD
     */
    function canPurchase(address user, uint256 amount) external view returns (bool, string memory);

    // ============ Admin Functions ============

    /**
     * @dev Update presale configuration
     * @param config New configuration parameters
     */
    function updatePresaleConfig(PresaleConfig calldata config) external;

    /**
     * @dev Update price feeds configuration
     * @param feeds New price feeds configuration
     */
    function updatePriceFeeds(PriceFeeds calldata feeds) external;

    /**
     * @dev Add/remove users from whitelist
     * @param users Array of user addresses
     * @param whitelisted Array of whitelist statuses
     */
    function updateWhitelist(address[] calldata users, bool[] calldata whitelisted) external;

    /**
     * @dev Update KYC status for users
     * @param users Array of user addresses
     * @param approved Array of KYC approval statuses
     */
    function updateKYCStatus(address[] calldata users, bool[] calldata approved) external;

    /**
     * @dev Pause/unpause the presale
     * @param paused New pause state
     */
    function setPaused(bool paused) external;

    /**
     * @dev Emergency withdraw tokens
     * @param token Address of token to withdraw
     * @param to Address to send tokens to
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, address to, uint256 amount) external;

    /**
     * @dev Finalize presale and distribute tokens
     */
    function finalizePresale() external;

    /**
     * @dev Enable/disable refunds
     * @param enabled Whether refunds are enabled
     */
    function setRefundEnabled(bool enabled) external;

    /**
     * @dev Enable/disable token claiming
     * @param enabled Whether claiming is enabled
     */
    function setClaimingEnabled(bool enabled) external;

    /**
     * @dev Set the EPCS token contract address
     * @param tokenAddress Address of the EPCS token contract
     */
    function setTokenAddress(address tokenAddress) external;

    /**
     * @dev Update supported payment tokens
     * @param tokens Array of token addresses
     * @param supported Array of support statuses
     */
    function updateSupportedTokens(address[] calldata tokens, bool[] calldata supported) external;

    /**
     * @dev Update cooldown period between purchases
     * @param cooldownPeriod New cooldown period in seconds
     */
    function setCooldownPeriod(uint256 cooldownPeriod) external;

    /**
     * @dev Update maximum slippage tolerance
     * @param maxSlippage New maximum slippage in basis points
     */
    function setMaxSlippage(uint256 maxSlippage) external;
}
