// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceOracle
 * @dev Interface for price oracle functionality with Chainlink integration
 * @author EpicChainLabs
 */
interface IPriceOracle {
    // ============ Structs ============

    struct PriceFeedConfig {
        address feedAddress;
        uint256 heartbeatTimeout;
        uint8 decimals;
        bool isActive;
        uint256 lastUpdate;
    }

    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint80 roundId;
        bool isValid;
    }

    // ============ Events ============

    event PriceFeedUpdated(
        address indexed token,
        address indexed feedAddress,
        uint256 heartbeatTimeout,
        uint256 timestamp
    );

    event PriceUpdated(
        address indexed token,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 timestamp
    );

    event PriceFeedStatusChanged(
        address indexed token,
        bool isActive,
        uint256 timestamp
    );

    event EmergencyPriceSet(
        address indexed token,
        uint256 price,
        uint256 timestamp,
        address indexed setter
    );

    event PriceDeviationAlert(
        address indexed token,
        uint256 currentPrice,
        uint256 lastPrice,
        uint256 deviation,
        uint256 timestamp
    );

    // ============ View Functions ============

    /**
     * @dev Get the latest price for a token in USD with 18 decimals
     * @param token Address of the token
     * @return price Latest price in USD (18 decimals)
     */
    function getLatestPrice(address token) external view returns (uint256 price);

    /**
     * @dev Get detailed price data for a token
     * @param token Address of the token
     * @return priceData Struct containing price and metadata
     */
    function getPriceData(address token) external view returns (PriceData memory priceData);

    /**
     * @dev Get historical price at a specific round
     * @param token Address of the token
     * @param roundId Round ID to query
     * @return priceData Historical price data
     */
    function getHistoricalPrice(address token, uint80 roundId) external view returns (PriceData memory priceData);

    /**
     * @dev Check if a price feed is valid and up-to-date
     * @param token Address of the token
     * @return isValid Whether the price feed is valid
     */
    function isPriceFeedValid(address token) external view returns (bool isValid);

    /**
     * @dev Get price feed configuration for a token
     * @param token Address of the token
     * @return config Price feed configuration
     */
    function getPriceFeedConfig(address token) external view returns (PriceFeedConfig memory config);

    /**
     * @dev Get all supported tokens
     * @return tokens Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory tokens);

    /**
     * @dev Check if a token is supported
     * @param token Address of the token
     * @return isSupported Whether the token is supported
     */
    function isTokenSupported(address token) external view returns (bool isSupported);

    /**
     * @dev Get price with staleness check
     * @param token Address of the token
     * @param maxAge Maximum age of price data in seconds
     * @return price Latest price if within maxAge, reverts otherwise
     */
    function getPriceWithMaxAge(address token, uint256 maxAge) external view returns (uint256 price);

    /**
     * @dev Calculate USD value of token amount
     * @param token Address of the token
     * @param amount Amount of tokens
     * @return usdValue USD value with 18 decimals
     */
    function getUSDValue(address token, uint256 amount) external view returns (uint256 usdValue);

    /**
     * @dev Calculate token amount for given USD value
     * @param token Address of the token
     * @param usdValue USD value with 18 decimals
     * @return tokenAmount Amount of tokens
     */
    function getTokenAmount(address token, uint256 usdValue) external view returns (uint256 tokenAmount);

    // ============ Admin Functions ============

    /**
     * @dev Add or update a price feed for a token
     * @param token Address of the token
     * @param feedAddress Address of the Chainlink price feed
     * @param heartbeatTimeout Maximum time between price updates
     */
    function addPriceFeed(
        address token,
        address feedAddress,
        uint256 heartbeatTimeout
    ) external;

    /**
     * @dev Remove a price feed for a token
     * @param token Address of the token
     */
    function removePriceFeed(address token) external;

    /**
     * @dev Update heartbeat timeout for a price feed
     * @param token Address of the token
     * @param heartbeatTimeout New heartbeat timeout
     */
    function updateHeartbeatTimeout(address token, uint256 heartbeatTimeout) external;

    /**
     * @dev Enable or disable a price feed
     * @param token Address of the token
     * @param isActive Whether the feed should be active
     */
    function setPriceFeedStatus(address token, bool isActive) external;

    /**
     * @dev Set emergency price for a token (circuit breaker)
     * @param token Address of the token
     * @param price Emergency price in USD (18 decimals)
     */
    function setEmergencyPrice(address token, uint256 price) external;

    /**
     * @dev Clear emergency price for a token
     * @param token Address of the token
     */
    function clearEmergencyPrice(address token) external;

    /**
     * @dev Update price deviation threshold for alerts
     * @param token Address of the token
     * @param deviationThreshold Deviation threshold in basis points
     */
    function setPriceDeviationThreshold(address token, uint256 deviationThreshold) external;

    /**
     * @dev Force update price data (emergency function)
     * @param token Address of the token
     */
    function forceUpdatePrice(address token) external;

    /**
     * @dev Batch update multiple price feeds
     * @param tokens Array of token addresses
     * @param feedAddresses Array of feed addresses
     * @param heartbeatTimeouts Array of heartbeat timeouts
     */
    function batchUpdatePriceFeeds(
        address[] calldata tokens,
        address[] calldata feedAddresses,
        uint256[] calldata heartbeatTimeouts
    ) external;

    // ============ Emergency Functions ============

    /**
     * @dev Pause all price feeds (emergency)
     */
    function pauseAllFeeds() external;

    /**
     * @dev Resume all price feeds
     */
    function resumeAllFeeds() external;

    /**
     * @dev Check if price feeds are paused
     * @return isPaused Whether price feeds are paused
     */
    function areFeedsPaused() external view returns (bool isPaused);
}
