// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle
 * @dev Advanced price oracle with Chainlink integration and emergency fallback mechanisms
 * @author EpicChainLabs
 */
contract PriceOracle is IPriceOracle, Ownable, Pausable, ReentrancyGuard {
    // ============ Constants ============

    uint256 private constant PRICE_PRECISION = 10**18;
    uint256 private constant CHAINLINK_PRECISION = 10**8;
    uint256 private constant DEFAULT_HEARTBEAT = 3600; // 1 hour
    uint256 private constant MAX_DEVIATION = 1000; // 10%
    uint256 private constant MIN_VALID_PRICE = 1; // $0.01
    uint256 private constant MAX_VALID_PRICE = 1000000 * PRICE_PRECISION; // $1M

    // ============ State Variables ============

    mapping(address => PriceFeedConfig) public priceFeeds;
    mapping(address => uint256) public emergencyPrices;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public priceDeviationThresholds;
    mapping(address => uint256) public lastValidPrices;

    address[] public supportedTokensList;

    bool public emergencyMode;
    uint256 public globalHeartbeat;
    uint256 public globalDeviationThreshold;

    // Oracle operators and emergency responders
    mapping(address => bool) public oracleOperators;
    mapping(address => bool) public emergencyResponders;
    mapping(address => bool) public priceValidators;

    // Circuit breaker
    uint256 public circuitBreakerThreshold;
    uint256 public circuitBreakerCount;
    bool public circuitBreakerActive;

    // Price history for analytics
    mapping(address => PriceData[]) public priceHistory;
    mapping(address => uint256) public maxHistoryLength;

    // ============ Events ============

    event OracleOperatorAdded(address indexed operator, uint256 timestamp);
    event OracleOperatorRemoved(address indexed operator, uint256 timestamp);
    event EmergencyResponderAdded(address indexed responder, uint256 timestamp);
    event EmergencyResponderRemoved(address indexed responder, uint256 timestamp);
    event PriceValidatorAdded(address indexed validator, uint256 timestamp);
    event PriceValidatorRemoved(address indexed validator, uint256 timestamp);

    event EmergencyModeEnabled(uint256 timestamp);
    event EmergencyModeDisabled(uint256 timestamp);
    event CircuitBreakerActivated(uint256 timestamp);
    event CircuitBreakerDeactivated(uint256 timestamp);

    event PriceHistoryUpdated(address indexed token, uint256 price, uint256 timestamp);
    event InvalidPriceDetected(address indexed token, uint256 invalidPrice, uint256 timestamp);

    // ============ Modifiers ============

    modifier onlyOracleOperator() {
        require(oracleOperators[msg.sender] || owner() == msg.sender, "PriceOracle: Not oracle operator");
        _;
    }

    modifier onlyEmergencyResponder() {
        require(emergencyResponders[msg.sender] || owner() == msg.sender, "PriceOracle: Not emergency responder");
        _;
    }

    modifier onlyPriceValidator() {
        require(priceValidators[msg.sender] || owner() == msg.sender, "PriceOracle: Not price validator");
        _;
    }

    modifier validToken(address token) {
        require(supportedTokens[token], "PriceOracle: Token not supported");
        _;
    }

    modifier notCircuitBroken() {
        require(!circuitBreakerActive, "PriceOracle: Circuit breaker active");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "PriceOracle: Invalid address");
        _;
    }

    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {
        globalHeartbeat = DEFAULT_HEARTBEAT;
        globalDeviationThreshold = MAX_DEVIATION;
        circuitBreakerThreshold = 5;

        oracleOperators[initialOwner] = true;
        emergencyResponders[initialOwner] = true;
        priceValidators[initialOwner] = true;
    }

    // ============ View Functions ============

    /**
     * @dev Get the latest price for a token in USD with 18 decimals
     */
    function getLatestPrice(address token) external view override validToken(token) returns (uint256 price) {
        // Check if emergency price is set
        if (emergencyPrices[token] > 0) {
            return emergencyPrices[token];
        }

        PriceFeedConfig memory config = priceFeeds[token];
        require(config.isActive, "PriceOracle: Price feed inactive");

        try AggregatorV3Interface(config.feedAddress).latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            require(answer > 0, "PriceOracle: Invalid price");
            require(updatedAt > 0, "PriceOracle: Invalid timestamp");
            require(block.timestamp - updatedAt <= config.heartbeatTimeout, "PriceOracle: Price too stale");

            // Convert to 18 decimals
            price = _convertDecimals(uint256(answer), config.decimals, 18);

            // Validate price is within reasonable bounds
            require(price >= MIN_VALID_PRICE && price <= MAX_VALID_PRICE, "PriceOracle: Price out of bounds");

            // Check for price deviation if we have a last valid price
            if (lastValidPrices[token] > 0) {
                uint256 deviation = _calculateDeviation(price, lastValidPrices[token]);
                require(deviation <= priceDeviationThresholds[token], "PriceOracle: Price deviation too high");
            }

            return price;
        } catch {
            // Fallback to last valid price if available
            require(lastValidPrices[token] > 0, "PriceOracle: No valid price available");
            return lastValidPrices[token];
        }
    }

    /**
     * @dev Get detailed price data for a token
     */
    function getPriceData(address token) external view override validToken(token) returns (PriceData memory priceData) {
        PriceFeedConfig memory config = priceFeeds[token];

        if (emergencyPrices[token] > 0) {
            return PriceData({
                price: emergencyPrices[token],
                timestamp: block.timestamp,
                roundId: 0,
                isValid: true
            });
        }

        require(config.isActive, "PriceOracle: Price feed inactive");

        try AggregatorV3Interface(config.feedAddress).latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            uint256 price = _convertDecimals(uint256(answer), config.decimals, 18);

            priceData = PriceData({
                price: price,
                timestamp: updatedAt,
                roundId: roundId,
                isValid: answer > 0 &&
                         updatedAt > 0 &&
                         block.timestamp - updatedAt <= config.heartbeatTimeout &&
                         price >= MIN_VALID_PRICE &&
                         price <= MAX_VALID_PRICE
            });
        } catch {
            priceData = PriceData({
                price: lastValidPrices[token],
                timestamp: block.timestamp,
                roundId: 0,
                isValid: lastValidPrices[token] > 0
            });
        }
    }

    /**
     * @dev Get historical price at a specific round
     */
    function getHistoricalPrice(address token, uint80 roundId) external view override validToken(token) returns (PriceData memory priceData) {
        PriceFeedConfig memory config = priceFeeds[token];
        require(config.isActive, "PriceOracle: Price feed inactive");

        try AggregatorV3Interface(config.feedAddress).getRoundData(roundId) returns (
            uint80 id,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            uint256 price = _convertDecimals(uint256(answer), config.decimals, 18);

            priceData = PriceData({
                price: price,
                timestamp: updatedAt,
                roundId: id,
                isValid: answer > 0 && updatedAt > 0
            });
        } catch {
            priceData = PriceData({
                price: 0,
                timestamp: 0,
                roundId: 0,
                isValid: false
            });
        }
    }

    /**
     * @dev Check if a price feed is valid and up-to-date
     */
    function isPriceFeedValid(address token) external view override validToken(token) returns (bool isValid) {
        if (emergencyPrices[token] > 0) {
            return true;
        }

        PriceFeedConfig memory config = priceFeeds[token];
        if (!config.isActive) {
            return false;
        }

        try AggregatorV3Interface(config.feedAddress).latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            return answer > 0 &&
                   updatedAt > 0 &&
                   block.timestamp - updatedAt <= config.heartbeatTimeout;
        } catch {
            return false;
        }
    }

    /**
     * @dev Get price feed configuration for a token
     */
    function getPriceFeedConfig(address token) external view override validToken(token) returns (PriceFeedConfig memory config) {
        return priceFeeds[token];
    }

    /**
     * @dev Get all supported tokens
     */
    function getSupportedTokens() external view override returns (address[] memory tokens) {
        return supportedTokensList;
    }

    /**
     * @dev Check if a token is supported
     */
    function isTokenSupported(address token) external view override returns (bool isSupported) {
        return supportedTokens[token];
    }

    /**
     * @dev Get price with staleness check
     */
    function getPriceWithMaxAge(address token, uint256 maxAge) external view override validToken(token) returns (uint256 price) {
        PriceData memory data = this.getPriceData(token);
        require(data.isValid, "PriceOracle: Invalid price data");
        require(block.timestamp - data.timestamp <= maxAge, "PriceOracle: Price too old");
        return data.price;
    }

    /**
     * @dev Calculate USD value of token amount
     */
    function getUSDValue(address token, uint256 amount) external view override validToken(token) returns (uint256 usdValue) {
        uint256 price = this.getLatestPrice(token);
        usdValue = (amount * price) / PRICE_PRECISION;
    }

    /**
     * @dev Calculate token amount for given USD value
     */
    function getTokenAmount(address token, uint256 usdValue) external view override validToken(token) returns (uint256 tokenAmount) {
        uint256 price = this.getLatestPrice(token);
        tokenAmount = (usdValue * PRICE_PRECISION) / price;
    }

    // ============ Admin Functions ============

    /**
     * @dev Add or update a price feed for a token
     */
    function addPriceFeed(
        address token,
        address feedAddress,
        uint256 heartbeatTimeout
    ) external override onlyOracleOperator validAddress(token) validAddress(feedAddress) {
        // Get decimals from the price feed
        uint8 decimals = AggregatorV3Interface(feedAddress).decimals();

        priceFeeds[token] = PriceFeedConfig({
            feedAddress: feedAddress,
            heartbeatTimeout: heartbeatTimeout > 0 ? heartbeatTimeout : globalHeartbeat,
            decimals: decimals,
            isActive: true,
            lastUpdate: block.timestamp
        });

        if (!supportedTokens[token]) {
            supportedTokens[token] = true;
            supportedTokensList.push(token);
        }

        // Set default deviation threshold
        if (priceDeviationThresholds[token] == 0) {
            priceDeviationThresholds[token] = globalDeviationThreshold;
        }

        // Set default history length
        if (maxHistoryLength[token] == 0) {
            maxHistoryLength[token] = 100;
        }

        emit PriceFeedUpdated(token, feedAddress, heartbeatTimeout, block.timestamp);

        // Update price history
        _updatePriceHistory(token);
    }

    /**
     * @dev Remove a price feed for a token
     */
    function removePriceFeed(address token) external override onlyOracleOperator {
        require(supportedTokens[token], "PriceOracle: Token not supported");

        priceFeeds[token].isActive = false;
        supportedTokens[token] = false;

        // Remove from supported tokens list
        for (uint256 i = 0; i < supportedTokensList.length; i++) {
            if (supportedTokensList[i] == token) {
                supportedTokensList[i] = supportedTokensList[supportedTokensList.length - 1];
                supportedTokensList.pop();
                break;
            }
        }

        emit PriceFeedStatusChanged(token, false, block.timestamp);
    }

    /**
     * @dev Update heartbeat timeout for a price feed
     */
    function updateHeartbeatTimeout(address token, uint256 heartbeatTimeout) external override onlyOracleOperator validToken(token) {
        priceFeeds[token].heartbeatTimeout = heartbeatTimeout;
        priceFeeds[token].lastUpdate = block.timestamp;

        emit PriceFeedUpdated(token, priceFeeds[token].feedAddress, heartbeatTimeout, block.timestamp);
    }

    /**
     * @dev Enable or disable a price feed
     */
    function setPriceFeedStatus(address token, bool isActive) external override onlyOracleOperator validToken(token) {
        priceFeeds[token].isActive = isActive;
        priceFeeds[token].lastUpdate = block.timestamp;

        emit PriceFeedStatusChanged(token, isActive, block.timestamp);
    }

    /**
     * @dev Set emergency price for a token (circuit breaker)
     */
    function setEmergencyPrice(address token, uint256 price) external override onlyEmergencyResponder validToken(token) {
        require(price >= MIN_VALID_PRICE && price <= MAX_VALID_PRICE, "PriceOracle: Invalid emergency price");

        emergencyPrices[token] = price;

        emit EmergencyPriceSet(token, price, block.timestamp, msg.sender);
    }

    /**
     * @dev Clear emergency price for a token
     */
    function clearEmergencyPrice(address token) external override onlyEmergencyResponder validToken(token) {
        delete emergencyPrices[token];
    }

    /**
     * @dev Update price deviation threshold for alerts
     */
    function setPriceDeviationThreshold(address token, uint256 deviationThreshold) external override onlyOracleOperator validToken(token) {
        require(deviationThreshold <= 5000, "PriceOracle: Deviation threshold too high"); // Max 50%

        priceDeviationThresholds[token] = deviationThreshold;
    }

    /**
     * @dev Force update price data (emergency function)
     */
    function forceUpdatePrice(address token) external override onlyPriceValidator validToken(token) {
        _updatePriceHistory(token);

        // Update last valid price
        try this.getLatestPrice(token) returns (uint256 price) {
            lastValidPrices[token] = price;
        } catch {
            // Price update failed
        }
    }

    /**
     * @dev Batch update multiple price feeds
     */
    function batchUpdatePriceFeeds(
        address[] calldata tokens,
        address[] calldata feedAddresses,
        uint256[] calldata heartbeatTimeouts
    ) external override onlyOracleOperator {
        require(tokens.length == feedAddresses.length &&
                tokens.length == heartbeatTimeouts.length,
                "PriceOracle: Array length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            this.addPriceFeed(tokens[i], feedAddresses[i], heartbeatTimeouts[i]);
        }
    }

    // ============ Emergency Functions ============

    /**
     * @dev Pause all price feeds (emergency)
     */
    function pauseAllFeeds() external override onlyEmergencyResponder {
        emergencyMode = true;
        _pause();

        emit EmergencyModeEnabled(block.timestamp);
    }

    /**
     * @dev Resume all price feeds
     */
    function resumeAllFeeds() external override onlyEmergencyResponder {
        emergencyMode = false;
        _unpause();

        emit EmergencyModeDisabled(block.timestamp);
    }

    /**
     * @dev Check if price feeds are paused
     */
    function areFeedsPaused() external view override returns (bool isPaused) {
        return paused() || emergencyMode;
    }

    // ============ Role Management ============

    /**
     * @dev Add oracle operator
     */
    function addOracleOperator(address operator) external onlyOwner validAddress(operator) {
        oracleOperators[operator] = true;
        emit OracleOperatorAdded(operator, block.timestamp);
    }

    /**
     * @dev Remove oracle operator
     */
    function removeOracleOperator(address operator) external onlyOwner {
        oracleOperators[operator] = false;
        emit OracleOperatorRemoved(operator, block.timestamp);
    }

    /**
     * @dev Add emergency responder
     */
    function addEmergencyResponder(address responder) external onlyOwner validAddress(responder) {
        emergencyResponders[responder] = true;
        emit EmergencyResponderAdded(responder, block.timestamp);
    }

    /**
     * @dev Remove emergency responder
     */
    function removeEmergencyResponder(address responder) external onlyOwner {
        emergencyResponders[responder] = false;
        emit EmergencyResponderRemoved(responder, block.timestamp);
    }

    /**
     * @dev Add price validator
     */
    function addPriceValidator(address validator) external onlyOwner validAddress(validator) {
        priceValidators[validator] = true;
        emit PriceValidatorAdded(validator, block.timestamp);
    }

    /**
     * @dev Remove price validator
     */
    function removePriceValidator(address validator) external onlyOwner {
        priceValidators[validator] = false;
        emit PriceValidatorRemoved(validator, block.timestamp);
    }

    // ============ Circuit Breaker Functions ============

    /**
     * @dev Activate circuit breaker
     */
    function activateCircuitBreaker() external onlyEmergencyResponder {
        circuitBreakerActive = true;
        emit CircuitBreakerActivated(block.timestamp);
    }

    /**
     * @dev Deactivate circuit breaker
     */
    function deactivateCircuitBreaker() external onlyOwner {
        circuitBreakerActive = false;
        circuitBreakerCount = 0;
        emit CircuitBreakerDeactivated(block.timestamp);
    }

    /**
     * @dev Update circuit breaker threshold
     */
    function updateCircuitBreakerThreshold(uint256 threshold) external onlyOwner {
        require(threshold > 0 && threshold <= 10, "PriceOracle: Invalid threshold");
        circuitBreakerThreshold = threshold;
    }

    // ============ Configuration Functions ============

    /**
     * @dev Update global heartbeat timeout
     */
    function updateGlobalHeartbeat(uint256 heartbeat) external onlyOwner {
        require(heartbeat >= 300 && heartbeat <= 86400, "PriceOracle: Invalid heartbeat"); // 5 min to 24 hours
        globalHeartbeat = heartbeat;
    }

    /**
     * @dev Update global deviation threshold
     */
    function updateGlobalDeviationThreshold(uint256 threshold) external onlyOwner {
        require(threshold <= 5000, "PriceOracle: Threshold too high"); // Max 50%
        globalDeviationThreshold = threshold;
    }

    /**
     * @dev Update max history length for a token
     */
    function updateMaxHistoryLength(address token, uint256 length) external onlyOracleOperator validToken(token) {
        require(length >= 10 && length <= 1000, "PriceOracle: Invalid history length");
        maxHistoryLength[token] = length;
    }

    // ============ Internal Functions ============

    /**
     * @dev Convert price from one decimal precision to another
     */
    function _convertDecimals(uint256 amount, uint256 fromDecimals, uint256 toDecimals) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return amount;
        } else if (fromDecimals > toDecimals) {
            return amount / (10**(fromDecimals - toDecimals));
        } else {
            return amount * (10**(toDecimals - fromDecimals));
        }
    }

    /**
     * @dev Calculate price deviation percentage
     */
    function _calculateDeviation(uint256 newPrice, uint256 oldPrice) internal pure returns (uint256) {
        if (oldPrice == 0) return 0;

        uint256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        return (diff * 10000) / oldPrice; // Return in basis points
    }

    /**
     * @dev Update price history for a token
     */
    function _updatePriceHistory(address token) internal {
        try this.getPriceData(token) returns (PriceData memory data) {
            if (data.isValid) {
                priceHistory[token].push(data);

                // Keep only the last N entries
                if (priceHistory[token].length > maxHistoryLength[token]) {
                    // Shift array elements
                    for (uint256 i = 0; i < priceHistory[token].length - 1; i++) {
                        priceHistory[token][i] = priceHistory[token][i + 1];
                    }
                    priceHistory[token].pop();
                }

                lastValidPrices[token] = data.price;
                emit PriceHistoryUpdated(token, data.price, block.timestamp);
            }
        } catch {
            // Failed to update price history
        }
    }

    /**
     * @dev Check if price deviation triggers circuit breaker
     */
    function _checkCircuitBreaker(address token, uint256 newPrice, uint256 oldPrice) internal {
        if (oldPrice > 0) {
            uint256 deviation = _calculateDeviation(newPrice, oldPrice);
            if (deviation > priceDeviationThresholds[token]) {
                circuitBreakerCount++;

                emit PriceDeviationAlert(token, newPrice, oldPrice, deviation, block.timestamp);

                if (circuitBreakerCount >= circuitBreakerThreshold) {
                    circuitBreakerActive = true;
                    emit CircuitBreakerActivated(block.timestamp);
                }
            }
        }
    }

    // ============ View Functions for Analytics ============

    /**
     * @dev Get price history for a token
     */
    function getPriceHistory(address token, uint256 limit) external view validToken(token) returns (PriceData[] memory history) {
        uint256 length = priceHistory[token].length;
        uint256 returnLength = limit > length ? length : limit;

        history = new PriceData[](returnLength);

        for (uint256 i = 0; i < returnLength; i++) {
            history[i] = priceHistory[token][length - returnLength + i];
        }
    }

    /**
     * @dev Get price statistics for a token
     */
    function getPriceStatistics(address token) external view validToken(token) returns (
        uint256 currentPrice,
        uint256 averagePrice,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 volatility
    ) {
        PriceData[] memory history = priceHistory[token];

        if (history.length == 0) {
            currentPrice = this.getLatestPrice(token);
            return (currentPrice, currentPrice, currentPrice, currentPrice, 0);
        }

        currentPrice = history[history.length - 1].price;

        uint256 sum = 0;
        minPrice = type(uint256).max;
        maxPrice = 0;

        for (uint256 i = 0; i < history.length; i++) {
            uint256 price = history[i].price;
            sum += price;

            if (price < minPrice) minPrice = price;
            if (price > maxPrice) maxPrice = price;
        }

        averagePrice = sum / history.length;

        // Simple volatility calculation (standard deviation approximation)
        if (history.length > 1) {
            uint256 variance = 0;
            for (uint256 i = 0; i < history.length; i++) {
                uint256 diff = history[i].price > averagePrice ?
                    history[i].price - averagePrice :
                    averagePrice - history[i].price;
                variance += (diff * diff);
            }
            volatility = variance / history.length;
        }
    }
}
