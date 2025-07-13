// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "../interfaces/ISecurityManager.sol";
import "../libraries/SecurityLib.sol";

/**
 * @title SecurityManager
 * @dev Advanced security manager with comprehensive protection against attacks
 * @author EpicChainLabs
 */
contract SecurityManager is ISecurityManager, Ownable, Pausable, ReentrancyGuard {
    using SecurityLib for *;

    // ============ Constants ============

    uint256 private constant MAX_RISK_SCORE = 100;
    uint256 private constant DEFAULT_COOLDOWN = 30; // 30 seconds
    uint256 private constant DEFAULT_MAX_SLIPPAGE = 200; // 2%
    uint256 private constant MAX_ALERTS_STORED = 1000;
    uint256 private constant BLACKLIST_DURATION = 7 days;
    uint256 private constant MAX_GAS_PRICE = 100 gwei;

    // ============ State Variables ============

    SecurityConfig public securityConfig;

    mapping(address => UserSecurityData) public userSecurityData;
    mapping(address => bool) public blacklistedUsers;
    mapping(address => bool) public whitelistedUsers;
    mapping(address => bool) public kycApprovedUsers;
    mapping(address => uint256) public temporaryBans;
    mapping(address => uint256) public emergencyPrices;

    SecurityAlert[] public securityAlerts;
    address[] public blacklistedAddresses;
    address[] public whitelistedAddresses;

    uint256 public totalTransactions;
    uint256 public blockedTransactions;
    uint256 public detectedBots;
    uint256 public mevAttacks;
    uint256 public flashloanAttacks;

    bool public emergencyPaused;
    bool public circuitBreakerActive;
    string public pauseReason;

    // Transaction tracking
    mapping(uint256 => uint256) public blockTransactionCount;
    mapping(address => SecurityLib.TransactionData[]) public userTransactionHistory;

    // Role-based access
    mapping(address => bool) public securityOperators;
    mapping(address => bool) public emergencyResponders;

    // ============ Events ============

    event SecurityOperatorAdded(address indexed operator, uint256 timestamp);
    event SecurityOperatorRemoved(address indexed operator, uint256 timestamp);
    event EmergencyResponderAdded(address indexed responder, uint256 timestamp);
    event EmergencyResponderRemoved(address indexed responder, uint256 timestamp);
    event CircuitBreakerTriggered(string condition, uint256 timestamp);
    event CircuitBreakerReset(uint256 timestamp);

    // ============ Modifiers ============

    modifier onlySecurityOperator() {
        require(securityOperators[msg.sender] || owner() == msg.sender, "SecurityManager: Not security operator");
        _;
    }

    modifier onlyEmergencyResponder() {
        require(emergencyResponders[msg.sender] || owner() == msg.sender, "SecurityManager: Not emergency responder");
        _;
    }

    modifier notEmergencyPaused() {
        require(!emergencyPaused, "SecurityManager: Emergency paused");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "SecurityManager: Invalid address");
        _;
    }

    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {
        securityConfig = SecurityConfig({
            cooldownPeriod: DEFAULT_COOLDOWN,
            maxSlippage: DEFAULT_MAX_SLIPPAGE,
            maxGasPrice: MAX_GAS_PRICE,
            maxTxPerBlock: 10,
            maxTxPerUser: 5,
            antiMEVEnabled: true,
            flashloanProtectionEnabled: true,
            contractCallsBlocked: false
        });

        securityOperators[initialOwner] = true;
        emergencyResponders[initialOwner] = true;
    }

    // ============ Security Check Functions ============

    /**
     * @dev Check if user can perform a transaction
     */
    function canTransact(
        address user,
        uint256 amount,
        uint256 txType
    ) external view override returns (bool canTransact, string memory reason) {
        // Check emergency pause
        if (emergencyPaused) {
            return (false, "Emergency pause active");
        }

        // Check circuit breaker
        if (circuitBreakerActive) {
            return (false, "Circuit breaker active");
        }

        // Check blacklist
        if (blacklistedUsers[user]) {
            return (false, "User blacklisted");
        }

        // Check temporary ban
        if (temporaryBans[user] > block.timestamp) {
            return (false, "User temporarily banned");
        }

        UserSecurityData memory userData = userSecurityData[user];

        // Check cooldown
        if (block.timestamp < userData.lastTxTimestamp + securityConfig.cooldownPeriod) {
            return (false, "User in cooldown period");
        }

        // Check transaction limits
        if (userData.txCountInBlock >= securityConfig.maxTxPerUser) {
            return (false, "Too many transactions per user");
        }

        if (blockTransactionCount[block.number] >= securityConfig.maxTxPerBlock) {
            return (false, "Too many transactions per block");
        }

        // Check gas price
        if (tx.gasprice > securityConfig.maxGasPrice) {
            return (false, "Gas price too high");
        }

        // Check contract calls if blocked
        if (securityConfig.contractCallsBlocked && SecurityLib.isContract(user)) {
            return (false, "Contract calls blocked");
        }

        // Check risk score
        if (userData.riskScore > 80) {
            return (false, "Risk score too high");
        }

        return (true, "");
    }

    /**
     * @dev Check if user is in cooldown
     */
    function isInCooldown(address user) external view override returns (bool inCooldown, uint256 remainingTime) {
        UserSecurityData memory userData = userSecurityData[user];
        uint256 cooldownEnd = userData.lastTxTimestamp + securityConfig.cooldownPeriod;

        if (block.timestamp < cooldownEnd) {
            inCooldown = true;
            remainingTime = cooldownEnd - block.timestamp;
        }
    }

    /**
     * @dev Check if user is blacklisted
     */
    function isBlacklisted(address user) external view override returns (bool isBlacklisted) {
        return blacklistedUsers[user];
    }

    /**
     * @dev Check if user is whitelisted
     */
    function isWhitelisted(address user) external view override returns (bool isWhitelisted) {
        return whitelistedUsers[user];
    }

    /**
     * @dev Check if user has KYC approval
     */
    function isKYCApproved(address user) external view override returns (bool kycApproved) {
        return kycApprovedUsers[user];
    }

    /**
     * @dev Detect potential bot behavior
     */
    function detectBot(address user, bytes calldata txData) external view override returns (bool isBot, uint256 confidence) {
        SecurityLib.TransactionData[] memory history = userTransactionHistory[user];
        return SecurityLib.detectBotBehavior(user, history);
    }

    /**
     * @dev Check for flashloan attack
     */
    function isFlashloanAttack(address user, uint256 amount) external view override returns (bool isFlashloan) {
        uint256 userBalance = address(user).balance;
        return SecurityLib.detectFlashloanAttack(user, amount, userBalance);
    }

    /**
     * @dev Check for MEV attack
     */
    function isMEVAttack(address user) external view override returns (bool isMEV) {
        if (!securityConfig.antiMEVEnabled) return false;

        (bool detected,) = SecurityLib.detectMEVAttack(user, block.number, 0);
        return detected;
    }

    /**
     * @dev Validate slippage tolerance
     */
    function validateSlippage(uint256 expectedAmount, uint256 actualAmount) external view override returns (bool isValid) {
        return SecurityLib.validateSlippage(expectedAmount, actualAmount, securityConfig.maxSlippage);
    }

    // ============ Security Management Functions ============

    /**
     * @dev Update security configuration
     */
    function updateSecurityConfig(SecurityConfig calldata config) external override onlySecurityOperator {
        require(SecurityLib.validateSecurityParams(SecurityLib.SecurityParams({
            cooldownPeriod: config.cooldownPeriod,
            maxSlippage: config.maxSlippage,
            maxGasPrice: config.maxGasPrice,
            maxTxPerBlock: config.maxTxPerBlock,
            maxTxPerUser: config.maxTxPerUser,
            antiMEVEnabled: config.antiMEVEnabled,
            flashloanProtectionEnabled: config.flashloanProtectionEnabled,
            contractCallsBlocked: config.contractCallsBlocked,
            riskThreshold: 80
        })), "Invalid security parameters");

        securityConfig = config;

        emit SecurityConfigUpdated(
            config.cooldownPeriod,
            config.maxSlippage,
            config.maxGasPrice,
            block.timestamp
        );
    }

    /**
     * @dev Add users to blacklist
     */
    function addToBlacklist(address[] calldata users, string[] calldata reasons) external override onlySecurityOperator {
        require(users.length == reasons.length, "Array length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            if (!blacklistedUsers[users[i]]) {
                blacklistedUsers[users[i]] = true;
                blacklistedAddresses.push(users[i]);

                // Update risk score to maximum
                userSecurityData[users[i]].isBlacklisted = true;
                userSecurityData[users[i]].riskScore = MAX_RISK_SCORE;

                emit UserBlacklisted(users[i], reasons[i], block.timestamp);
            }
        }
    }

    /**
     * @dev Remove users from blacklist
     */
    function removeFromBlacklist(address[] calldata users) external override onlySecurityOperator {
        for (uint256 i = 0; i < users.length; i++) {
            if (blacklistedUsers[users[i]]) {
                blacklistedUsers[users[i]] = false;
                userSecurityData[users[i]].isBlacklisted = false;

                // Remove from array
                for (uint256 j = 0; j < blacklistedAddresses.length; j++) {
                    if (blacklistedAddresses[j] == users[i]) {
                        blacklistedAddresses[j] = blacklistedAddresses[blacklistedAddresses.length - 1];
                        blacklistedAddresses.pop();
                        break;
                    }
                }
            }
        }
    }

    /**
     * @dev Add users to whitelist
     */
    function addToWhitelist(address[] calldata users) external override onlySecurityOperator {
        for (uint256 i = 0; i < users.length; i++) {
            if (!whitelistedUsers[users[i]]) {
                whitelistedUsers[users[i]] = true;
                whitelistedAddresses.push(users[i]);
                userSecurityData[users[i]].isWhitelisted = true;

                emit UserWhitelisted(users[i], block.timestamp);
            }
        }
    }

    /**
     * @dev Remove users from whitelist
     */
    function removeFromWhitelist(address[] calldata users) external override onlySecurityOperator {
        for (uint256 i = 0; i < users.length; i++) {
            if (whitelistedUsers[users[i]]) {
                whitelistedUsers[users[i]] = false;
                userSecurityData[users[i]].isWhitelisted = false;

                // Remove from array
                for (uint256 j = 0; j < whitelistedAddresses.length; j++) {
                    if (whitelistedAddresses[j] == users[i]) {
                        whitelistedAddresses[j] = whitelistedAddresses[whitelistedAddresses.length - 1];
                        whitelistedAddresses.pop();
                        break;
                    }
                }
            }
        }
    }

    /**
     * @dev Update KYC status for users
     */
    function updateKYCStatus(address[] calldata users, bool[] calldata approved) external override onlySecurityOperator {
        require(users.length == approved.length, "Array length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            kycApprovedUsers[users[i]] = approved[i];
            userSecurityData[users[i]].kycApproved = approved[i];

            emit KYCStatusUpdated(users[i], approved[i], block.timestamp);
        }
    }

    /**
     * @dev Record transaction for security monitoring
     */
    function recordTransaction(address user, uint256 amount, uint256 txType) external override {
        // Only allow calls from authorized contracts
        require(securityOperators[msg.sender], "Unauthorized caller");

        UserSecurityData storage userData = userSecurityData[user];

        // Reset block counter if new block
        if (userData.lastTxTimestamp == 0 || block.number > userData.lastTxTimestamp) {
            userData.txCountInBlock = 0;
        }

        userData.lastTxTimestamp = block.timestamp;
        userData.txCountInBlock++;
        userData.totalTxCount++;

        // Update block transaction count
        blockTransactionCount[block.number]++;
        totalTransactions++;

        // Store transaction data
        SecurityLib.TransactionData memory txData = SecurityLib.TransactionData({
            user: user,
            amount: amount,
            timestamp: block.timestamp,
            blockNumber: block.number,
            gasPrice: tx.gasprice,
            gasUsed: gasleft(),
            txHash: keccak256(abi.encodePacked(user, amount, block.timestamp))
        });

        userTransactionHistory[user].push(txData);

        // Keep only last 10 transactions per user
        if (userTransactionHistory[user].length > 10) {
            for (uint256 i = 0; i < userTransactionHistory[user].length - 1; i++) {
                userTransactionHistory[user][i] = userTransactionHistory[user][i + 1];
            }
            userTransactionHistory[user].pop();
        }

        // Perform real-time security checks
        _performRealtimeSecurityCheck(user, amount, txData);
    }

    /**
     * @dev Trigger security alert
     */
    function triggerSecurityAlert(
        address user,
        uint256 alertType,
        string calldata description,
        uint256 severity
    ) external override onlySecurityOperator {
        SecurityAlert memory alert = SecurityAlert({
            user: user,
            timestamp: block.timestamp,
            alertType: alertType,
            description: description,
            severity: severity
        });

        securityAlerts.push(alert);

        // Remove oldest alerts if limit exceeded
        if (securityAlerts.length > MAX_ALERTS_STORED) {
            for (uint256 i = 0; i < securityAlerts.length - 1; i++) {
                securityAlerts[i] = securityAlerts[i + 1];
            }
            securityAlerts.pop();
        }

        emit SecurityAlertTriggered(user, alertType, description, severity, block.timestamp);

        // Auto-trigger circuit breaker for high severity alerts
        if (severity >= 4) {
            _triggerCircuitBreaker("High severity security alert");
        }
    }

    /**
     * @dev Update user risk score
     */
    function updateRiskScore(address user, uint256 riskScore) external override onlySecurityOperator {
        require(riskScore <= MAX_RISK_SCORE, "Risk score exceeds maximum");

        uint256 oldScore = userSecurityData[user].riskScore;
        userSecurityData[user].riskScore = riskScore;

        emit RiskScoreUpdated(user, oldScore, riskScore, block.timestamp);
    }

    /**
     * @dev Ban user temporarily
     */
    function temporaryBan(address user, uint256 duration, string calldata reason) external override onlySecurityOperator {
        temporaryBans[user] = block.timestamp + duration;

        triggerSecurityAlert(user, 3, reason, 3);
    }

    /**
     * @dev Lift temporary ban
     */
    function liftTemporaryBan(address user) external override onlySecurityOperator {
        temporaryBans[user] = 0;
    }

    // ============ Emergency Functions ============

    /**
     * @dev Emergency pause all operations
     */
    function emergencyPause(string calldata reason) external override onlyEmergencyResponder {
        emergencyPaused = true;
        pauseReason = reason;

        emit EmergencyPause(msg.sender, reason, block.timestamp);
    }

    /**
     * @dev Resume operations after emergency pause
     */
    function emergencyResume() external override onlyEmergencyResponder {
        emergencyPaused = false;
        pauseReason = "";

        emit EmergencyResume(msg.sender, block.timestamp);
    }

    /**
     * @dev Check if system is in emergency pause
     */
    function isEmergencyPaused() external view override returns (bool isPaused) {
        return emergencyPaused;
    }

    /**
     * @dev Circuit breaker - automatically pause if conditions are met
     */
    function circuitBreaker(string calldata condition) external override onlySecurityOperator {
        _triggerCircuitBreaker(condition);
    }

    /**
     * @dev Mass blacklist users (emergency function)
     */
    function massBlacklist(address[] calldata users, string calldata reason) external override onlyEmergencyResponder {
        string[] memory reasons = new string[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            reasons[i] = reason;
        }

        this.addToBlacklist(users, reasons);
    }

    // ============ View Functions ============

    /**
     * @dev Get user security data
     */
    function getUserSecurityData(address user) external view override returns (UserSecurityData memory securityData) {
        return userSecurityData[user];
    }

    /**
     * @dev Get security configuration
     */
    function getSecurityConfig() external view override returns (SecurityConfig memory config) {
        return securityConfig;
    }

    /**
     * @dev Get recent security alerts
     */
    function getRecentAlerts(uint256 limit) external view override returns (SecurityAlert[] memory alerts) {
        uint256 alertCount = securityAlerts.length;
        uint256 returnCount = limit > alertCount ? alertCount : limit;

        alerts = new SecurityAlert[](returnCount);

        for (uint256 i = 0; i < returnCount; i++) {
            alerts[i] = securityAlerts[alertCount - 1 - i];
        }
    }

    /**
     * @dev Get blacklisted users
     */
    function getBlacklistedUsers() external view override returns (address[] memory users) {
        return blacklistedAddresses;
    }

    /**
     * @dev Get whitelisted users
     */
    function getWhitelistedUsers() external view override returns (address[] memory users) {
        return whitelistedAddresses;
    }

    /**
     * @dev Get security statistics
     */
    function getSecurityStats() external view override returns (
        uint256 totalAlerts,
        uint256 activeThreats,
        uint256 blacklistedCount,
        uint256 whitelistedCount
    ) {
        totalAlerts = securityAlerts.length;
        activeThreats = emergencyPaused ? 1 : 0;
        if (circuitBreakerActive) activeThreats++;
        blacklistedCount = blacklistedAddresses.length;
        whitelistedCount = whitelistedAddresses.length;
    }

    /**
     * @dev Check if address is a contract
     */
    function isContract(address addr) external view override returns (bool isContract) {
        return SecurityLib.isContract(addr);
    }

    /**
     * @dev Get current gas price
     */
    function getCurrentGasPrice() external view override returns (uint256 gasPrice) {
        return tx.gasprice;
    }

    /**
     * @dev Get transaction count in current block
     */
    function getTxCountInBlock() external view override returns (uint256 txCount) {
        return blockTransactionCount[block.number];
    }

    // ============ Admin Functions ============

    /**
     * @dev Add security operator
     */
    function addSecurityOperator(address operator) external onlyOwner validAddress(operator) {
        securityOperators[operator] = true;
        emit SecurityOperatorAdded(operator, block.timestamp);
    }

    /**
     * @dev Remove security operator
     */
    function removeSecurityOperator(address operator) external onlyOwner {
        securityOperators[operator] = false;
        emit SecurityOperatorRemoved(operator, block.timestamp);
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
     * @dev Reset circuit breaker
     */
    function resetCircuitBreaker() external onlyOwner {
        circuitBreakerActive = false;
        emit CircuitBreakerReset(block.timestamp);
    }

    // ============ Internal Functions ============

    /**
     * @dev Perform real-time security check
     */
    function _performRealtimeSecurityCheck(
        address user,
        uint256 amount,
        SecurityLib.TransactionData memory txData
    ) internal {
        // Check for bot behavior
        (bool isBot, uint256 confidence) = this.detectBot(user, "");
        if (isBot && confidence > 80) {
            detectedBots++;
            triggerSecurityAlert(user, 1, "Bot behavior detected", 3);
        }

        // Check for MEV
        if (this.isMEVAttack(user)) {
            mevAttacks++;
            triggerSecurityAlert(user, 2, "MEV attack detected", 4);
        }

        // Check for flashloan
        if (this.isFlashloanAttack(user, amount)) {
            flashloanAttacks++;
            triggerSecurityAlert(user, 3, "Flashloan attack detected", 5);
        }

        // Update risk score based on behavior
        uint256 newRiskScore = SecurityLib.calculateRiskScore(
            user,
            userTransactionHistory[user],
            blacklistedUsers[user],
            whitelistedUsers[user],
            kycApprovedUsers[user]
        );

        if (newRiskScore != userSecurityData[user].riskScore) {
            userSecurityData[user].riskScore = newRiskScore;
        }
    }

    /**
     * @dev Internal function to trigger circuit breaker
     */
    function _triggerCircuitBreaker(string memory condition) internal {
        circuitBreakerActive = true;
        emit CircuitBreakerTriggered(condition, block.timestamp);
    }
}
