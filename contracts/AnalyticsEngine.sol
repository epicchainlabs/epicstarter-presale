// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./libraries/MathLib.sol";

/**
 * @title AnalyticsEngine
 * @dev Advanced analytics contract for comprehensive monitoring and reporting
 * @author EpicChainLabs
 *
 * Features:
 * - Real-time metrics tracking
 * - Historical data analysis
 * - Performance indicators
 * - User behavior analytics
 * - Revenue tracking
 * - Market analysis
 * - Predictive modeling
 * - Custom reporting
 */
contract AnalyticsEngine is Ownable, ReentrancyGuard {
    using MathLib for uint256;

    // ============ Constants ============

    uint256 private constant PRECISION = 10**18;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant SECONDS_PER_HOUR = 3600;
    uint256 private constant MAX_HISTORY_DAYS = 365;
    uint256 private constant PERCENTILE_PRECISION = 100;

    // ============ Structs ============

    struct DailyMetrics {
        uint256 totalVolume;
        uint256 totalTransactions;
        uint256 uniqueUsers;
        uint256 averageTransactionSize;
        uint256 newUsers;
        uint256 returningUsers;
        uint256 totalGasUsed;
        uint256 averageGasPrice;
        uint256 peakHourVolume;
        uint256 timestamp;
    }

    struct HourlyMetrics {
        uint256 volume;
        uint256 transactions;
        uint256 uniqueUsers;
        uint256 gasUsed;
        uint256 timestamp;
    }

    struct UserMetrics {
        uint256 totalVolume;
        uint256 totalTransactions;
        uint256 firstTransactionTime;
        uint256 lastTransactionTime;
        uint256 averageTransactionSize;
        uint256 totalGasUsed;
        uint256 referralCount;
        uint256 lifetimeValue;
        bool isHighValue;
        uint256 riskScore;
    }

    struct TransactionMetrics {
        address user;
        uint256 amount;
        uint256 gasUsed;
        uint256 gasPrice;
        uint256 timestamp;
        address paymentToken;
        uint256 tokensReceived;
        uint256 priceAtTime;
        bool isReferral;
        address referrer;
    }

    struct MarketMetrics {
        uint256 totalMarketCap;
        uint256 priceVolatility;
        uint256 averageHoldingPeriod;
        uint256 whaleActivity;
        uint256 retailActivity;
        uint256 institutionalActivity;
        uint256 liquidityDepth;
        uint256 priceImpact;
    }

    struct PerformanceIndicators {
        uint256 conversionRate;
        uint256 userRetentionRate;
        uint256 averageSessionDuration;
        uint256 bounceRate;
        uint256 customerLifetimeValue;
        uint256 churnRate;
        uint256 engagementScore;
        uint256 satisfactionIndex;
    }

    struct PredictiveModel {
        uint256 expectedDailyVolume;
        uint256 expectedUserGrowth;
        uint256 expectedPriceMovement;
        uint256 expectedCompletion;
        uint256 riskAssessment;
        uint256 confidenceLevel;
        uint256 lastModelUpdate;
        bool isModelActive;
    }

    // ============ State Variables ============

    // Core metrics storage
    mapping(uint256 => DailyMetrics) public dailyMetrics;
    mapping(uint256 => HourlyMetrics) public hourlyMetrics;
    mapping(address => UserMetrics) public userMetrics;
    TransactionMetrics[] public transactionHistory;

    // Market and performance data
    MarketMetrics public currentMarketMetrics;
    PerformanceIndicators public currentPerformanceIndicators;
    PredictiveModel public currentPredictiveModel;

    // Tracking variables
    mapping(uint256 => address[]) public dailyActiveUsers;
    mapping(uint256 => address[]) public hourlyActiveUsers;
    mapping(address => uint256[]) public userTransactionIndices;
    mapping(address => bool) public isAnalyticsProvider;
    mapping(address => bool) public isDataConsumer;

    // Aggregated data
    uint256 public totalVolumeAllTime;
    uint256 public totalTransactionsAllTime;
    uint256 public totalUniqueUsers;
    uint256 public currentActiveUsers;
    uint256 public peakDailyVolume;
    uint256 public peakDailyUsers;

    // Configuration
    uint256 public analyticsStartTime;
    uint256 public dataRetentionPeriod;
    uint256 public modelUpdateInterval;
    uint256 public highValueThreshold;
    bool public analyticsEnabled;
    bool public predictiveModelEnabled;

    // Advanced tracking
    mapping(address => uint256) public userSegments;
    mapping(uint256 => string) public segmentNames;
    mapping(address => uint256) public userBehaviorFlags;
    mapping(bytes32 => uint256) public customMetrics;

    // ============ Events ============

    event TransactionRecorded(
        address indexed user,
        uint256 amount,
        uint256 gasUsed,
        uint256 timestamp,
        uint256 indexed transactionIndex
    );

    event DailyMetricsUpdated(
        uint256 indexed day,
        uint256 volume,
        uint256 transactions,
        uint256 uniqueUsers
    );

    event UserSegmentUpdated(
        address indexed user,
        uint256 oldSegment,
        uint256 newSegment
    );

    event PredictiveModelUpdated(
        uint256 expectedVolume,
        uint256 expectedGrowth,
        uint256 confidenceLevel,
        uint256 timestamp
    );

    event AnalyticsProviderAdded(address indexed provider);
    event AnalyticsProviderRemoved(address indexed provider);
    event CustomMetricUpdated(bytes32 indexed metricKey, uint256 value);
    event PerformanceAlert(string alertType, uint256 value, uint256 threshold);

    // ============ Modifiers ============

    modifier onlyAnalyticsProvider() {
        require(isAnalyticsProvider[msg.sender] || owner() == msg.sender, "Not analytics provider");
        _;
    }

    modifier onlyDataConsumer() {
        require(isDataConsumer[msg.sender] || owner() == msg.sender, "Not data consumer");
        _;
    }

    modifier analyticsActive() {
        require(analyticsEnabled, "Analytics disabled");
        _;
    }

    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {
        analyticsStartTime = block.timestamp;
        dataRetentionPeriod = 365 days;
        modelUpdateInterval = 24 hours;
        highValueThreshold = 10000 * PRECISION; // $10,000
        analyticsEnabled = true;
        predictiveModelEnabled = true;

        // Initialize segments
        segmentNames[0] = "New User";
        segmentNames[1] = "Regular User";
        segmentNames[2] = "High Value User";
        segmentNames[3] = "Whale";
        segmentNames[4] = "Institutional";

        isAnalyticsProvider[initialOwner] = true;
        isDataConsumer[initialOwner] = true;
    }

    // ============ Core Analytics Functions ============

    /**
     * @dev Record a new transaction for analytics
     */
    function recordTransaction(
        address user,
        uint256 amount,
        uint256 gasUsed,
        uint256 gasPrice,
        address paymentToken,
        uint256 tokensReceived,
        uint256 priceAtTime,
        bool isReferral,
        address referrer
    ) external onlyAnalyticsProvider analyticsActive nonReentrant {
        TransactionMetrics memory transaction = TransactionMetrics({
            user: user,
            amount: amount,
            gasUsed: gasUsed,
            gasPrice: gasPrice,
            timestamp: block.timestamp,
            paymentToken: paymentToken,
            tokensReceived: tokensReceived,
            priceAtTime: priceAtTime,
            isReferral: isReferral,
            referrer: referrer
        });

        uint256 transactionIndex = transactionHistory.length;
        transactionHistory.push(transaction);
        userTransactionIndices[user].push(transactionIndex);

        // Update user metrics
        _updateUserMetrics(user, amount, gasUsed, isReferral);

        // Update time-based metrics
        _updateDailyMetrics(amount, gasUsed, gasPrice, user);
        _updateHourlyMetrics(amount, gasUsed, user);

        // Update global counters
        totalVolumeAllTime = totalVolumeAllTime.safeAdd(amount);
        totalTransactionsAllTime = totalTransactionsAllTime.safeAdd(1);

        // Update user segment if needed
        _updateUserSegment(user);

        emit TransactionRecorded(user, amount, gasUsed, block.timestamp, transactionIndex);

        // Update predictive model if needed
        if (block.timestamp >= currentPredictiveModel.lastModelUpdate + modelUpdateInterval) {
            _updatePredictiveModel();
        }
    }

    /**
     * @dev Update market metrics
     */
    function updateMarketMetrics(
        uint256 totalMarketCap,
        uint256 priceVolatility,
        uint256 averageHoldingPeriod,
        uint256 whaleActivity,
        uint256 liquidityDepth
    ) external onlyAnalyticsProvider {
        currentMarketMetrics.totalMarketCap = totalMarketCap;
        currentMarketMetrics.priceVolatility = priceVolatility;
        currentMarketMetrics.averageHoldingPeriod = averageHoldingPeriod;
        currentMarketMetrics.whaleActivity = whaleActivity;
        currentMarketMetrics.liquidityDepth = liquidityDepth;

        // Calculate derived metrics
        currentMarketMetrics.retailActivity = _calculateRetailActivity();
        currentMarketMetrics.institutionalActivity = _calculateInstitutionalActivity();
        currentMarketMetrics.priceImpact = _calculatePriceImpact();
    }

    /**
     * @dev Set custom metric
     */
    function setCustomMetric(string calldata metricName, uint256 value) external onlyAnalyticsProvider {
        bytes32 metricKey = keccak256(abi.encodePacked(metricName));
        customMetrics[metricKey] = value;
        emit CustomMetricUpdated(metricKey, value);
    }

    // ============ Advanced Analytics Functions ============

    /**
     * @dev Calculate user cohort analysis
     */
    function calculateCohortAnalysis(uint256 cohortStartTime, uint256 cohortEndTime)
        external view returns (
            uint256 cohortSize,
            uint256 retentionDay1,
            uint256 retentionDay7,
            uint256 retentionDay30,
            uint256 averageLifetimeValue
        ) {
        uint256 cohortStart = cohortStartTime / SECONDS_PER_DAY;
        uint256 cohortEnd = cohortEndTime / SECONDS_PER_DAY;

        address[] memory cohortUsers = new address[](totalUniqueUsers);
        uint256 cohortCount = 0;
        uint256 totalLifetimeValue = 0;

        // Identify cohort users
        for (uint256 i = 0; i < transactionHistory.length; i++) {
            uint256 txDay = transactionHistory[i].timestamp / SECONDS_PER_DAY;
            if (txDay >= cohortStart && txDay <= cohortEnd) {
                address user = transactionHistory[i].user;
                if (!_isUserInArray(cohortUsers, user, cohortCount)) {
                    cohortUsers[cohortCount] = user;
                    cohortCount++;
                    totalLifetimeValue = totalLifetimeValue.safeAdd(userMetrics[user].lifetimeValue);
                }
            }
        }

        cohortSize = cohortCount;
        averageLifetimeValue = cohortCount > 0 ? totalLifetimeValue / cohortCount : 0;

        // Calculate retention
        (retentionDay1, retentionDay7, retentionDay30) = _calculateRetentionRates(
            cohortUsers,
            cohortCount,
            cohortEndTime
        );
    }

    /**
     * @dev Get user behavior insights
     */
    function getUserBehaviorInsights(address user) external view returns (
        uint256 segment,
        uint256 engagementScore,
        uint256 riskScore,
        uint256 predictedChurnProbability,
        uint256 lifetimeValuePrediction,
        bool isHighValue,
        string memory behaviorProfile
    ) {
        UserMetrics memory metrics = userMetrics[user];
        segment = userSegments[user];
        engagementScore = _calculateEngagementScore(user);
        riskScore = metrics.riskScore;
        predictedChurnProbability = _predictChurnProbability(user);
        lifetimeValuePrediction = _predictLifetimeValue(user);
        isHighValue = metrics.isHighValue;
        behaviorProfile = _getBehaviorProfile(user);
    }

    /**
     * @dev Calculate revenue attribution
     */
    function calculateRevenueAttribution() external view returns (
        uint256 organicRevenue,
        uint256 referralRevenue,
        uint256 whaleRevenue,
        uint256 retailRevenue,
        uint256 institutionalRevenue
    ) {
        for (uint256 i = 0; i < transactionHistory.length; i++) {
            TransactionMetrics memory tx = transactionHistory[i];
            uint256 segment = userSegments[tx.user];

            if (tx.isReferral) {
                referralRevenue = referralRevenue.safeAdd(tx.amount);
            } else {
                organicRevenue = organicRevenue.safeAdd(tx.amount);
            }

            if (segment == 3) { // Whale
                whaleRevenue = whaleRevenue.safeAdd(tx.amount);
            } else if (segment == 4) { // Institutional
                institutionalRevenue = institutionalRevenue.safeAdd(tx.amount);
            } else {
                retailRevenue = retailRevenue.safeAdd(tx.amount);
            }
        }
    }

    /**
     * @dev Get conversion funnel analysis
     */
    function getConversionFunnelAnalysis(uint256 timeframe) external view returns (
        uint256 totalVisitors,
        uint256 walletConnections,
        uint256 firstPurchases,
        uint256 repeatPurchases,
        uint256 highValueConversions
    ) {
        uint256 startTime = block.timestamp - timeframe;

        for (uint256 i = 0; i < transactionHistory.length; i++) {
            TransactionMetrics memory tx = transactionHistory[i];
            if (tx.timestamp >= startTime) {
                UserMetrics memory metrics = userMetrics[tx.user];

                if (metrics.firstTransactionTime >= startTime) {
                    firstPurchases++;
                } else {
                    repeatPurchases++;
                }

                if (metrics.isHighValue) {
                    highValueConversions++;
                }
            }
        }

        // Note: totalVisitors and walletConnections would need to be tracked separately
        // as they represent pre-transaction events
    }

    // ============ Predictive Analytics ============

    /**
     * @dev Update predictive model
     */
    function _updatePredictiveModel() internal {
        if (!predictiveModelEnabled) return;

        uint256 recentVolume = _getRecentVolumeTrend(7); // 7-day trend
        uint256 userGrowthRate = _getUserGrowthRate(30); // 30-day growth
        uint256 priceVolatility = currentMarketMetrics.priceVolatility;

        currentPredictiveModel.expectedDailyVolume = _predictDailyVolume(recentVolume);
        currentPredictiveModel.expectedUserGrowth = _predictUserGrowth(userGrowthRate);
        currentPredictiveModel.expectedPriceMovement = _predictPriceMovement(priceVolatility);
        currentPredictiveModel.expectedCompletion = _predictPresaleCompletion();
        currentPredictiveModel.riskAssessment = _assessRisk();
        currentPredictiveModel.confidenceLevel = _calculateConfidence();
        currentPredictiveModel.lastModelUpdate = block.timestamp;
        currentPredictiveModel.isModelActive = true;

        emit PredictiveModelUpdated(
            currentPredictiveModel.expectedDailyVolume,
            currentPredictiveModel.expectedUserGrowth,
            currentPredictiveModel.confidenceLevel,
            block.timestamp
        );
    }

    /**
     * @dev Predict daily volume based on trends
     */
    function _predictDailyVolume(uint256 recentTrend) internal pure returns (uint256) {
        // Simple linear projection with trend adjustment
        return recentTrend.safeMul(110).safeDiv(100); // 10% growth assumption
    }

    /**
     * @dev Predict user growth rate
     */
    function _predictUserGrowth(uint256 currentGrowthRate) internal pure returns (uint256) {
        // Apply diminishing returns model
        return currentGrowthRate.safeMul(95).safeDiv(100); // 5% deceleration
    }

    /**
     * @dev Predict price movement
     */
    function _predictPriceMovement(uint256 volatility) internal pure returns (uint256) {
        // Price prediction based on volatility and market conditions
        if (volatility > 500) { // High volatility (5%)
            return 15; // Expect 15% price change
        } else if (volatility > 200) { // Medium volatility (2%)
            return 8; // Expect 8% price change
        } else {
            return 3; // Expect 3% price change
        }
    }

    /**
     * @dev Predict presale completion time
     */
    function _predictPresaleCompletion() internal view returns (uint256) {
        if (totalVolumeAllTime == 0) return 0;

        uint256 recentDailyAverage = _getRecentVolumeTrend(7);
        if (recentDailyAverage == 0) return 0;

        // Assume a target completion amount (this would be set based on presale goals)
        uint256 targetAmount = 5000000000 * PRECISION; // $5B target
        uint256 remaining = targetAmount > totalVolumeAllTime ?
            targetAmount - totalVolumeAllTime : 0;

        return remaining / recentDailyAverage; // Days to completion
    }

    // ============ Internal Helper Functions ============

    /**
     * @dev Update user metrics
     */
    function _updateUserMetrics(address user, uint256 amount, uint256 gasUsed, bool isReferral) internal {
        UserMetrics storage metrics = userMetrics[user];

        if (metrics.firstTransactionTime == 0) {
            metrics.firstTransactionTime = block.timestamp;
            totalUniqueUsers++;
        }

        metrics.totalVolume = metrics.totalVolume.safeAdd(amount);
        metrics.totalTransactions = metrics.totalTransactions.safeAdd(1);
        metrics.lastTransactionTime = block.timestamp;
        metrics.totalGasUsed = metrics.totalGasUsed.safeAdd(gasUsed);
        metrics.lifetimeValue = metrics.totalVolume;

        if (metrics.totalTransactions > 0) {
            metrics.averageTransactionSize = metrics.totalVolume.safeDiv(metrics.totalTransactions);
        }

        if (isReferral) {
            metrics.referralCount = metrics.referralCount.safeAdd(1);
        }

        // Update high value status
        if (metrics.lifetimeValue >= highValueThreshold) {
            metrics.isHighValue = true;
        }

        // Update risk score
        metrics.riskScore = _calculateUserRiskScore(user);
    }

    /**
     * @dev Update daily metrics
     */
    function _updateDailyMetrics(uint256 amount, uint256 gasUsed, uint256 gasPrice, address user) internal {
        uint256 day = block.timestamp / SECONDS_PER_DAY;
        DailyMetrics storage daily = dailyMetrics[day];

        daily.totalVolume = daily.totalVolume.safeAdd(amount);
        daily.totalTransactions = daily.totalTransactions.safeAdd(1);
        daily.totalGasUsed = daily.totalGasUsed.safeAdd(gasUsed);

        // Update gas price average
        if (daily.totalTransactions == 1) {
            daily.averageGasPrice = gasPrice;
        } else {
            daily.averageGasPrice = (daily.averageGasPrice.safeMul(daily.totalTransactions - 1).safeAdd(gasPrice))
                .safeDiv(daily.totalTransactions);
        }

        // Track unique users
        if (!_isUserActiveToday(user, day)) {
            dailyActiveUsers[day].push(user);
            daily.uniqueUsers = daily.uniqueUsers.safeAdd(1);

            // Check if new user
            if (userMetrics[user].firstTransactionTime >= day * SECONDS_PER_DAY) {
                daily.newUsers = daily.newUsers.safeAdd(1);
            } else {
                daily.returningUsers = daily.returningUsers.safeAdd(1);
            }
        }

        // Update average transaction size
        daily.averageTransactionSize = daily.totalVolume.safeDiv(daily.totalTransactions);
        daily.timestamp = block.timestamp;

        // Update peak volume if needed
        if (daily.totalVolume > peakDailyVolume) {
            peakDailyVolume = daily.totalVolume;
        }

        emit DailyMetricsUpdated(day, daily.totalVolume, daily.totalTransactions, daily.uniqueUsers);
    }

    /**
     * @dev Update hourly metrics
     */
    function _updateHourlyMetrics(uint256 amount, uint256 gasUsed, address user) internal {
        uint256 hour = block.timestamp / SECONDS_PER_HOUR;
        HourlyMetrics storage hourly = hourlyMetrics[hour];

        hourly.volume = hourly.volume.safeAdd(amount);
        hourly.transactions = hourly.transactions.safeAdd(1);
        hourly.gasUsed = hourly.gasUsed.safeAdd(gasUsed);

        if (!_isUserActiveThisHour(user, hour)) {
            hourlyActiveUsers[hour].push(user);
            hourly.uniqueUsers = hourly.uniqueUsers.safeAdd(1);
        }

        hourly.timestamp = block.timestamp;
    }

    /**
     * @dev Update user segment
     */
    function _updateUserSegment(address user) internal {
        UserMetrics memory metrics = userMetrics[user];
        uint256 oldSegment = userSegments[user];
        uint256 newSegment = _determineUserSegment(metrics);

        if (newSegment != oldSegment) {
            userSegments[user] = newSegment;
            emit UserSegmentUpdated(user, oldSegment, newSegment);
        }
    }

    /**
     * @dev Determine user segment based on metrics
     */
    function _determineUserSegment(UserMetrics memory metrics) internal view returns (uint256) {
        if (metrics.lifetimeValue >= 1000000 * PRECISION) { // $1M+
            return 3; // Whale
        } else if (metrics.lifetimeValue >= 100000 * PRECISION) { // $100K+
            return 4; // Institutional
        } else if (metrics.lifetimeValue >= highValueThreshold) { // $10K+
            return 2; // High Value User
        } else if (metrics.totalTransactions >= 5) {
            return 1; // Regular User
        } else {
            return 0; // New User
        }
    }

    /**
     * @dev Calculate user risk score
     */
    function _calculateUserRiskScore(address user) internal view returns (uint256) {
        UserMetrics memory metrics = userMetrics[user];
        uint256 riskScore = 0;

        // Transaction frequency risk
        if (metrics.totalTransactions > 0) {
            uint256 avgTimeBetweenTx = (metrics.lastTransactionTime - metrics.firstTransactionTime)
                / metrics.totalTransactions;
            if (avgTimeBetweenTx < 300) { // Less than 5 minutes average
                riskScore += 30;
            }
        }

        // Large transaction risk
        if (metrics.averageTransactionSize > 100000 * PRECISION) { // $100K+ average
            riskScore += 20;
        }

        // Gas usage patterns
        if (metrics.totalTransactions > 0) {
            uint256 avgGasPerTx = metrics.totalGasUsed / metrics.totalTransactions;
            if (avgGasPerTx > 500000) { // High gas usage
                riskScore += 10;
            }
        }

        // Account age risk
        uint256 accountAge = block.timestamp - metrics.firstTransactionTime;
        if (accountAge < 86400) { // Less than 1 day old
            riskScore += 25;
        }

        return Math.min(riskScore, 100); // Cap at 100
    }

    /**
     * @dev Calculate engagement score
     */
    function _calculateEngagementScore(address user) internal view returns (uint256) {
        UserMetrics memory metrics = userMetrics[user];
        uint256 score = 0;

        // Transaction frequency
        if (metrics.totalTransactions >= 10) score += 30;
        else if (metrics.totalTransactions >= 5) score += 20;
        else if (metrics.totalTransactions >= 2) score += 10;

        // Account longevity
        uint256 accountAge = block.timestamp - metrics.firstTransactionTime;
        if (accountAge >= 30 days) score += 25;
        else if (accountAge >= 7 days) score += 15;
        else if (accountAge >= 1 days) score += 5;

        // Volume commitment
        if (metrics.lifetimeValue >= 50000 * PRECISION) score += 25;
        else if (metrics.lifetimeValue >= 10000 * PRECISION) score += 15;
        else if (metrics.lifetimeValue >= 1000 * PRECISION) score += 10;

        // Referral activity
        if (metrics.referralCount > 0) score += 20;

        return Math.min(score, 100);
    }

    /**
     * @dev Predict churn probability
     */
    function _predictChurnProbability(address user) internal view returns (uint256) {
        UserMetrics memory metrics = userMetrics[user];

        if (metrics.totalTransactions == 0) return 100;

        uint256 daysSinceLastTx = (block.timestamp - metrics.lastTransactionTime) / SECONDS_PER_DAY;
        uint256 churnProbability = 0;

        if (daysSinceLastTx > 30) churnProbability += 60;
        else if (daysSinceLastTx > 14) churnProbability += 40;
        else if (daysSinceLastTx > 7) churnProbability += 20;

        // Adjust for engagement
        uint256 engagement = _calculateEngagementScore(user);
        churnProbability = churnProbability > engagement ? churnProbability - engagement : 0;

        return Math.min(churnProbability, 100);
    }

    /**
     * @dev Predict lifetime value
     */
    function _predictLifetimeValue(address user) internal view returns (uint256) {
        UserMetrics memory metrics = userMetrics[user];

        if (metrics.totalTransactions == 0) return 0;

        uint256 accountAge = block.timestamp - metrics.firstTransactionTime;
        if (accountAge == 0) return metrics.averageTransactionSize;

        uint256 dailyValue = metrics.lifetimeValue * SECONDS_PER_DAY / accountAge;
        uint256 projectedDays = 365; // Project for 1 year

        // Adjust for user segment
        uint256 segment = userSegments[user];
        if (segment >= 3) projectedDays = 730; // 2 years for whales/institutional
        else if (segment >= 2) projectedDays = 547; // 1.5 years for high value

        return dailyValue * projectedDays;
    }

    /**
     * @dev Get behavior profile string
     */
    function _getBehaviorProfile(address user) internal view returns (string memory) {
        uint256 engagement = _calculateEngagementScore(user);
        uint256 risk = userMetrics[user].riskScore;
        uint256 segment = userSegments[user];

        if (segment >= 3) {
            return risk > 50 ? "High-Risk Whale" : "Stable Whale";
        } else if (engagement > 70) {
            return risk > 50 ? "Engaged High-Risk" : "Loyal Customer";
        } else if (engagement > 40) {
            return "Regular User";
        } else {
            return risk > 50 ? "Risky New User" : "Casual User";
        }
    }

    // ============ Utility Functions ============

    /**
     * @dev Check if user is in array
     */
    function _isUserInArray(address[] memory users, address user, uint256 length) internal pure returns (bool) {
        for (uint256 i = 0; i < length; i++) {
            if (users[i] == user) return true;
        }
        return false;
    }

    /**
     * @dev Check if user was active today
     */
    function _isUserActiveToday(address user, uint256 day) internal view returns (bool) {
        address[] memory todayUsers = dailyActiveUsers[day];
        for (uint256 i = 0; i < todayUsers.length; i++) {
            if (todayUsers[i] == user) return true;
        }
        return false;
    }

    /**
     * @dev Check if user was active this hour
     */
    function _isUserActiveThisHour(address user, uint256 hour) internal view returns (bool) {
        address[] memory hourUsers = hourlyActiveUsers[hour];
        for (uint256 i = 0; i < hourUsers.length; i++) {
            if (hourUsers[i] == user) return true;
        }
        return false;
    }

    /**
     * @dev Get recent volume trend
     */
    function _getRecentVolumeTrend(uint256 days) internal view returns (uint256) {
        uint256 totalVolume = 0;
        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;

        for (uint256 i = 0; i < days; i++) {
            totalVolume = total
