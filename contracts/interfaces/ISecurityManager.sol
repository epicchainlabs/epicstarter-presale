// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISecurityManager
 * @dev Interface for security management functionality including anti-bot measures, access control, and emergency procedures
 * @author EpicChainLabs
 */
interface ISecurityManager {
    // ============ Structs ============

    struct SecurityConfig {
        uint256 cooldownPeriod;
        uint256 maxSlippage;
        uint256 maxGasPrice;
        uint256 maxTxPerBlock;
        uint256 maxTxPerUser;
        bool antiMEVEnabled;
        bool flashloanProtectionEnabled;
        bool contractCallsBlocked;
    }

    struct UserSecurityData {
        uint256 lastTxTimestamp;
        uint256 txCountInBlock;
        uint256 totalTxCount;
        bool isBlacklisted;
        bool isWhitelisted;
        bool kycApproved;
        uint256 riskScore;
    }

    struct SecurityAlert {
        address user;
        uint256 timestamp;
        uint256 alertType;
        string description;
        uint256 severity;
    }

    // ============ Events ============

    event SecurityConfigUpdated(
        uint256 cooldownPeriod,
        uint256 maxSlippage,
        uint256 maxGasPrice,
        uint256 timestamp
    );

    event UserBlacklisted(
        address indexed user,
        string reason,
        uint256 timestamp
    );

    event UserWhitelisted(
        address indexed user,
        uint256 timestamp
    );

    event SecurityAlertTriggered(
        address indexed user,
        uint256 alertType,
        string description,
        uint256 severity,
        uint256 timestamp
    );

    event BotDetected(
        address indexed user,
        string reason,
        uint256 timestamp
    );

    event SuspiciousActivity(
        address indexed user,
        uint256 activityType,
        uint256 timestamp
    );

    event EmergencyPause(
        address indexed initiator,
        string reason,
        uint256 timestamp
    );

    event EmergencyResume(
        address indexed initiator,
        uint256 timestamp
    );

    event FlashloanDetected(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event MEVDetected(
        address indexed user,
        uint256 blockNumber,
        uint256 timestamp
    );

    event ContractCallBlocked(
        address indexed caller,
        address indexed target,
        uint256 timestamp
    );

    event RiskScoreUpdated(
        address indexed user,
        uint256 oldScore,
        uint256 newScore,
        uint256 timestamp
    );

    // ============ Security Check Functions ============

    /**
     * @dev Check if user can perform a transaction
     * @param user Address of the user
     * @param amount Transaction amount
     * @param txType Type of transaction
     * @return canTransact Whether user can transact
     * @return reason Reason if transaction is blocked
     */
    function canTransact(
        address user,
        uint256 amount,
        uint256 txType
    ) external view returns (bool canTransact, string memory reason);

    /**
     * @dev Check if user is subject to cooldown
     * @param user Address of the user
     * @return inCooldown Whether user is in cooldown
     * @return remainingTime Remaining cooldown time
     */
    function isInCooldown(address user) external view returns (bool inCooldown, uint256 remainingTime);

    /**
     * @dev Check if user is blacklisted
     * @param user Address of the user
     * @return isBlacklisted Whether user is blacklisted
     */
    function isBlacklisted(address user) external view returns (bool isBlacklisted);

    /**
     * @dev Check if user is whitelisted
     * @param user Address of the user
     * @return isWhitelisted Whether user is whitelisted
     */
    function isWhitelisted(address user) external view returns (bool isWhitelisted);

    /**
     * @dev Check if user has KYC approval
     * @param user Address of the user
     * @return kycApproved Whether user has KYC approval
     */
    function isKYCApproved(address user) external view returns (bool kycApproved);

    /**
     * @dev Detect potential bot behavior
     * @param user Address of the user
     * @param txData Transaction data
     * @return isBot Whether user exhibits bot behavior
     * @return confidence Confidence level (0-100)
     */
    function detectBot(address user, bytes calldata txData) external view returns (bool isBot, uint256 confidence);

    /**
     * @dev Check for flashloan attack
     * @param user Address of the user
     * @param amount Transaction amount
     * @return isFlashloan Whether transaction is a flashloan
     */
    function isFlashloanAttack(address user, uint256 amount) external view returns (bool isFlashloan);

    /**
     * @dev Check for MEV (Maximal Extractable Value) attack
     * @param user Address of the user
     * @return isMEV Whether transaction is MEV
     */
    function isMEVAttack(address user) external view returns (bool isMEV);

    /**
     * @dev Validate slippage tolerance
     * @param expectedAmount Expected amount
     * @param actualAmount Actual amount
     * @return isValid Whether slippage is within tolerance
     */
    function validateSlippage(uint256 expectedAmount, uint256 actualAmount) external view returns (bool isValid);

    // ============ Security Management Functions ============

    /**
     * @dev Update security configuration
     * @param config New security configuration
     */
    function updateSecurityConfig(SecurityConfig calldata config) external;

    /**
     * @dev Add users to blacklist
     * @param users Array of user addresses
     * @param reasons Array of blacklist reasons
     */
    function addToBlacklist(address[] calldata users, string[] calldata reasons) external;

    /**
     * @dev Remove users from blacklist
     * @param users Array of user addresses
     */
    function removeFromBlacklist(address[] calldata users) external;

    /**
     * @dev Add users to whitelist
     * @param users Array of user addresses
     */
    function addToWhitelist(address[] calldata users) external;

    /**
     * @dev Remove users from whitelist
     * @param users Array of user addresses
     */
    function removeFromWhitelist(address[] calldata users) external;

    /**
     * @dev Update KYC status for users
     * @param users Array of user addresses
     * @param approved Array of KYC approval statuses
     */
    function updateKYCStatus(address[] calldata users, bool[] calldata approved) external;

    /**
     * @dev Record transaction for security monitoring
     * @param user Address of the user
     * @param amount Transaction amount
     * @param txType Type of transaction
     */
    function recordTransaction(address user, uint256 amount, uint256 txType) external;

    /**
     * @dev Trigger security alert
     * @param user Address of the user
     * @param alertType Type of alert
     * @param description Alert description
     * @param severity Alert severity (1-5)
     */
    function triggerSecurityAlert(
        address user,
        uint256 alertType,
        string calldata description,
        uint256 severity
    ) external;

    /**
     * @dev Update user risk score
     * @param user Address of the user
     * @param riskScore New risk score (0-100)
     */
    function updateRiskScore(address user, uint256 riskScore) external;

    /**
     * @dev Ban user temporarily
     * @param user Address of the user
     * @param duration Ban duration in seconds
     * @param reason Ban reason
     */
    function temporaryBan(address user, uint256 duration, string calldata reason) external;

    /**
     * @dev Lift temporary ban
     * @param user Address of the user
     */
    function liftTemporaryBan(address user) external;

    // ============ Emergency Functions ============

    /**
     * @dev Emergency pause all operations
     * @param reason Reason for emergency pause
     */
    function emergencyPause(string calldata reason) external;

    /**
     * @dev Resume operations after emergency pause
     */
    function emergencyResume() external;

    /**
     * @dev Check if system is in emergency pause
     * @return isPaused Whether system is paused
     */
    function isEmergencyPaused() external view returns (bool isPaused);

    /**
     * @dev Circuit breaker - automatically pause if conditions are met
     * @param condition Condition that triggered circuit breaker
     */
    function circuitBreaker(string calldata condition) external;

    /**
     * @dev Mass blacklist users (emergency function)
     * @param users Array of user addresses to blacklist
     * @param reason Reason for mass blacklist
     */
    function massBlacklist(address[] calldata users, string calldata reason) external;

    // ============ View Functions ============

    /**
     * @dev Get user security data
     * @param user Address of the user
     * @return securityData User's security data
     */
    function getUserSecurityData(address user) external view returns (UserSecurityData memory securityData);

    /**
     * @dev Get security configuration
     * @return config Current security configuration
     */
    function getSecurityConfig() external view returns (SecurityConfig memory config);

    /**
     * @dev Get recent security alerts
     * @param limit Maximum number of alerts to return
     * @return alerts Array of recent security alerts
     */
    function getRecentAlerts(uint256 limit) external view returns (SecurityAlert[] memory alerts);

    /**
     * @dev Get blacklisted users
     * @return users Array of blacklisted addresses
     */
    function getBlacklistedUsers() external view returns (address[] memory users);

    /**
     * @dev Get whitelisted users
     * @return users Array of whitelisted addresses
     */
    function getWhitelistedUsers() external view returns (address[] memory users);

    /**
     * @dev Get security statistics
     * @return totalAlerts Total number of security alerts
     * @return activeThreats Number of active threats
     * @return blacklistedCount Number of blacklisted users
     * @return whitelistedCount Number of whitelisted users
     */
    function getSecurityStats() external view returns (
        uint256 totalAlerts,
        uint256 activeThreats,
        uint256 blacklistedCount,
        uint256 whitelistedCount
    );

    /**
     * @dev Check if address is a contract
     * @param addr Address to check
     * @return isContract Whether address is a contract
     */
    function isContract(address addr) external view returns (bool isContract);

    /**
     * @dev Get current gas price
     * @return gasPrice Current gas price
     */
    function getCurrentGasPrice() external view returns (uint256 gasPrice);

    /**
     * @dev Get transaction count in current block
     * @return txCount Number of transactions in current block
     */
    function getTxCountInBlock() external view returns (uint256 txCount);
}
