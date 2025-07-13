// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SecurityLib
 * @dev Advanced security library with anti-bot measures, MEV protection, and comprehensive security checks
 * @author EpicChainLabs
 */
library SecurityLib {
    // ============ Constants ============

    uint256 private constant MAX_RISK_SCORE = 100;
    uint256 private constant FLASHLOAN_THRESHOLD = 1000000 * 10**18; // 1M tokens
    uint256 private constant MEV_DETECTION_BLOCKS = 3;
    uint256 private constant BOT_DETECTION_THRESHOLD = 80;
    uint256 private constant MAX_GAS_MULTIPLIER = 150; // 150% of average gas price
    uint256 private constant MIN_HUMAN_DELAY = 1000; // 1 second minimum between actions

    // ============ Structs ============

    struct SecurityParams {
        uint256 cooldownPeriod;
        uint256 maxSlippage;
        uint256 maxGasPrice;
        uint256 maxTxPerBlock;
        uint256 maxTxPerUser;
        bool antiMEVEnabled;
        bool flashloanProtectionEnabled;
        bool contractCallsBlocked;
        uint256 riskThreshold;
    }

    struct TransactionData {
        address user;
        uint256 amount;
        uint256 timestamp;
        uint256 blockNumber;
        uint256 gasPrice;
        uint256 gasUsed;
        bytes32 txHash;
    }

    struct BotDetectionData {
        uint256 txFrequency;
        uint256 gasConsistency;
        uint256 amountPattern;
        uint256 timingPattern;
        uint256 contractInteraction;
        uint256 totalScore;
    }

    struct MEVDetectionData {
        uint256 blockNumber;
        uint256 txIndex;
        uint256 frontrunningScore;
        uint256 sandwichScore;
        uint256 arbitrageScore;
        bool isSuspicious;
    }

    // ============ Errors ============

    error SecurityLib__UserInCooldown(uint256 remainingTime);
    error SecurityLib__ExceedsMaxSlippage(uint256 actualSlippage, uint256 maxSlippage);
    error SecurityLib__GasPriceTooHigh(uint256 gasPrice, uint256 maxGasPrice);
    error SecurityLib__TooManyTransactions(uint256 txCount, uint256 maxTx);
    error SecurityLib__FlashloanDetected(address user, uint256 amount);
    error SecurityLib__MEVDetected(address user, uint256 blockNumber);
    error SecurityLib__BotDetected(address user, uint256 confidence);
    error SecurityLib__ContractCallBlocked(address caller);
    error SecurityLib__RiskScoreTooHigh(address user, uint256 riskScore);
    error SecurityLib__InvalidSecurityParams();
    error SecurityLib__EmergencyPaused();

    // ============ Events ============

    event SecurityCheckPassed(address indexed user, uint256 checkType, uint256 timestamp);
    event SecurityCheckFailed(address indexed user, uint256 checkType, string reason, uint256 timestamp);
    event BotActivityDetected(address indexed user, BotDetectionData data, uint256 timestamp);
    event MEVActivityDetected(address indexed user, MEVDetectionData data, uint256 timestamp);
    event FlashloanActivityDetected(address indexed user, uint256 amount, uint256 timestamp);
    event AnomalousTransactionDetected(address indexed user, TransactionData data, uint256 timestamp);

    // ============ Security Check Functions ============

    /**
     * @dev Comprehensive security check for user transaction
     * @param user Address of the user
     * @param amount Transaction amount
     * @param params Security parameters
     * @param userLastTx User's last transaction timestamp
     * @param userTxCount User's transaction count in current block
     * @return isValid Whether transaction passes security checks
     * @return reason Failure reason if not valid
     */
    function performSecurityCheck(
        address user,
        uint256 amount,
        SecurityParams memory params,
        uint256 userLastTx,
        uint256 userTxCount
    ) internal view returns (bool isValid, string memory reason) {
        // Check cooldown period
        if (block.timestamp < userLastTx + params.cooldownPeriod) {
            return (false, "User in cooldown period");
        }

        // Check transaction frequency
        if (userTxCount >= params.maxTxPerUser) {
            return (false, "Too many transactions per user");
        }

        // Check gas price
        if (tx.gasprice > params.maxGasPrice) {
            return (false, "Gas price too high");
        }

        // Check if contract calls are blocked
        if (params.contractCallsBlocked && isContract(user)) {
            return (false, "Contract calls blocked");
        }

        return (true, "");
    }

    /**
     * @dev Detect bot behavior based on transaction patterns
     * @param user Address of the user
     * @param txHistory Array of recent transactions
     * @return isBot Whether user exhibits bot behavior
     * @return confidence Confidence level (0-100)
     */
    function detectBotBehavior(
        address user,
        TransactionData[] memory txHistory
    ) internal pure returns (bool isBot, uint256 confidence) {
        if (txHistory.length < 3) {
            return (false, 0);
        }

        BotDetectionData memory detection = BotDetectionData({
            txFrequency: 0,
            gasConsistency: 0,
            amountPattern: 0,
            timingPattern: 0,
            contractInteraction: 0,
            totalScore: 0
        });

        // Analyze transaction frequency
        detection.txFrequency = _analyzeTransactionFrequency(txHistory);

        // Analyze gas consistency
        detection.gasConsistency = _analyzeGasConsistency(txHistory);

        // Analyze amount patterns
        detection.amountPattern = _analyzeAmountPatterns(txHistory);

        // Analyze timing patterns
        detection.timingPattern = _analyzeTimingPatterns(txHistory);

        // Check contract interaction
        detection.contractInteraction = isContract(user) ? 30 : 0;

        // Calculate total score
        detection.totalScore = (
            detection.txFrequency +
            detection.gasConsistency +
            detection.amountPattern +
            detection.timingPattern +
            detection.contractInteraction
        ) / 5;

        isBot = detection.totalScore >= BOT_DETECTION_THRESHOLD;
        confidence = detection.totalScore;

        return (isBot, confidence);
    }

    /**
     * @dev Detect MEV (Maximal Extractable Value) attacks
     * @param user Address of the user
     * @param blockNumber Current block number
     * @param txIndex Transaction index in block
     * @return isMEV Whether transaction is MEV
     * @return data MEV detection data
     */
    function detectMEVAttack(
        address user,
        uint256 blockNumber,
        uint256 txIndex
    ) internal view returns (bool isMEV, MEVDetectionData memory data) {
        data = MEVDetectionData({
            blockNumber: blockNumber,
            txIndex: txIndex,
            frontrunningScore: 0,
            sandwichScore: 0,
            arbitrageScore: 0,
            isSuspicious: false
        });

        // Check for frontrunning patterns
        data.frontrunningScore = _detectFrontrunning(user, blockNumber, txIndex);

        // Check for sandwich attacks
        data.sandwichScore = _detectSandwichAttack(user, blockNumber, txIndex);

        // Check for arbitrage patterns
        data.arbitrageScore = _detectArbitrage(user, blockNumber);

        // Determine if MEV is detected
        uint256 totalMEVScore = (data.frontrunningScore + data.sandwichScore + data.arbitrageScore) / 3;
        data.isSuspicious = totalMEVScore > 70;

        return (data.isSuspicious, data);
    }

    /**
     * @dev Detect flashloan attacks
     * @param user Address of the user
     * @param amount Transaction amount
     * @param userBalance User's balance before transaction
     * @return isFlashloan Whether transaction is a flashloan
     */
    function detectFlashloanAttack(
        address user,
        uint256 amount,
        uint256 userBalance
    ) internal pure returns (bool isFlashloan) {
        // Check if transaction amount is significantly larger than user balance
        if (amount > userBalance * 10 && amount > FLASHLOAN_THRESHOLD) {
            return true;
        }

        // Check if user is a contract (potential flashloan borrower)
        if (isContract(user) && amount > FLASHLOAN_THRESHOLD) {
            return true;
        }

        return false;
    }

    /**
     * @dev Validate slippage tolerance
     * @param expectedAmount Expected amount
     * @param actualAmount Actual amount
     * @param maxSlippage Maximum allowed slippage in basis points
     * @return isValid Whether slippage is within tolerance
     */
    function validateSlippage(
        uint256 expectedAmount,
        uint256 actualAmount,
        uint256 maxSlippage
    ) internal pure returns (bool isValid) {
        if (expectedAmount == 0) return false;

        uint256 slippage;
        if (actualAmount < expectedAmount) {
            slippage = ((expectedAmount - actualAmount) * 10000) / expectedAmount;
        } else {
            slippage = ((actualAmount - expectedAmount) * 10000) / expectedAmount;
        }

        return slippage <= maxSlippage;
    }

    /**
     * @dev Calculate risk score for a user
     * @param user Address of the user
     * @param txHistory Transaction history
     * @param isBlacklisted Whether user is blacklisted
     * @param isWhitelisted Whether user is whitelisted
     * @param kycApproved Whether user has KYC approval
     * @return riskScore Risk score (0-100)
     */
    function calculateRiskScore(
        address user,
        TransactionData[] memory txHistory,
        bool isBlacklisted,
        bool isWhitelisted,
        bool kycApproved
    ) internal pure returns (uint256 riskScore) {
        // Base risk score
        riskScore = 50;

        // Adjust for blacklist/whitelist status
        if (isBlacklisted) {
            riskScore = 100;
            return riskScore;
        }

        if (isWhitelisted) {
            riskScore -= 20;
        }

        // Adjust for KYC approval
        if (kycApproved) {
            riskScore -= 15;
        } else {
            riskScore += 10;
        }

        // Adjust for contract interaction
        if (isContract(user)) {
            riskScore += 25;
        }

        // Adjust for transaction patterns
        if (txHistory.length > 0) {
            (bool isBot, uint256 confidence) = detectBotBehavior(user, txHistory);
            if (isBot) {
                riskScore += confidence / 2;
            }
        }

        // Ensure risk score is within bounds
        if (riskScore > MAX_RISK_SCORE) {
            riskScore = MAX_RISK_SCORE;
        }

        return riskScore;
    }

    /**
     * @dev Anti-sandwich attack protection
     * @param user Address of the user
     * @param blockNumber Current block number
     * @return isProtected Whether user is protected from sandwich attacks
     */
    function antiSandwichProtection(
        address user,
        uint256 blockNumber
    ) internal view returns (bool isProtected) {
        // Check if there are suspicious transactions in previous blocks
        for (uint256 i = 1; i <= MEV_DETECTION_BLOCKS; i++) {
            if (blockNumber >= i) {
                uint256 checkBlock = blockNumber - i;
                if (_hasSuspiciousActivity(user, checkBlock)) {
                    return false;
                }
            }
        }

        return true;
    }

    // ============ Internal Helper Functions ============

    /**
     * @dev Analyze transaction frequency patterns
     */
    function _analyzeTransactionFrequency(
        TransactionData[] memory txHistory
    ) private pure returns (uint256 score) {
        if (txHistory.length < 2) return 0;

        uint256 totalIntervals = 0;
        uint256 constantIntervals = 0;

        for (uint256 i = 1; i < txHistory.length; i++) {
            uint256 interval = txHistory[i].timestamp - txHistory[i-1].timestamp;
            totalIntervals += interval;

            // Check for suspiciously consistent intervals
            if (i > 1) {
                uint256 prevInterval = txHistory[i-1].timestamp - txHistory[i-2].timestamp;
                if (interval == prevInterval || (interval > prevInterval ? interval - prevInterval : prevInterval - interval) < 10) {
                    constantIntervals++;
                }
            }
        }

        uint256 avgInterval = totalIntervals / (txHistory.length - 1);

        // High frequency transactions
        if (avgInterval < MIN_HUMAN_DELAY) {
            score += 40;
        }

        // Consistent timing patterns
        if (constantIntervals > txHistory.length / 2) {
            score += 30;
        }

        return score > 100 ? 100 : score;
    }

    /**
     * @dev Analyze gas price consistency
     */
    function _analyzeGasConsistency(
        TransactionData[] memory txHistory
    ) private pure returns (uint256 score) {
        if (txHistory.length < 3) return 0;

        uint256 consistentGas = 0;

        for (uint256 i = 1; i < txHistory.length; i++) {
            if (txHistory[i].gasPrice == txHistory[i-1].gasPrice) {
                consistentGas++;
            }
        }

        // If most transactions have the same gas price, likely a bot
        if (consistentGas > txHistory.length * 2 / 3) {
            return 25;
        }

        return 0;
    }

    /**
     * @dev Analyze amount patterns
     */
    function _analyzeAmountPatterns(
        TransactionData[] memory txHistory
    ) private pure returns (uint256 score) {
        if (txHistory.length < 3) return 0;

        uint256 identicalAmounts = 0;
        uint256 roundNumbers = 0;

        for (uint256 i = 0; i < txHistory.length; i++) {
            // Check for identical amounts
            for (uint256 j = i + 1; j < txHistory.length; j++) {
                if (txHistory[i].amount == txHistory[j].amount) {
                    identicalAmounts++;
                }
            }

            // Check for round numbers (ending in many zeros)
            if (txHistory[i].amount % (10**18) == 0) {
                roundNumbers++;
            }
        }

        score = 0;

        // Too many identical amounts
        if (identicalAmounts > txHistory.length / 2) {
            score += 20;
        }

        // Too many round numbers
        if (roundNumbers > txHistory.length * 2 / 3) {
            score += 15;
        }

        return score;
    }

    /**
     * @dev Analyze timing patterns
     */
    function _analyzeTimingPatterns(
        TransactionData[] memory txHistory
    ) private pure returns (uint256 score) {
        if (txHistory.length < 3) return 0;

        uint256 sameBlockTx = 0;
        uint256 consecutiveBlocks = 0;

        for (uint256 i = 1; i < txHistory.length; i++) {
            if (txHistory[i].blockNumber == txHistory[i-1].blockNumber) {
                sameBlockTx++;
            }

            if (txHistory[i].blockNumber == txHistory[i-1].blockNumber + 1) {
                consecutiveBlocks++;
            }
        }

        score = 0;

        // Multiple transactions in same block
        if (sameBlockTx > 0) {
            score += 30;
        }

        // Transactions in consecutive blocks
        if (consecutiveBlocks > txHistory.length / 2) {
            score += 20;
        }

        return score;
    }

    /**
     * @dev Detect frontrunning patterns
     */
    function _detectFrontrunning(
        address user,
        uint256 blockNumber,
        uint256 txIndex
    ) private view returns (uint256 score) {
        // Check if transaction is at the beginning of a block
        if (txIndex == 0) {
            score += 30;
        }

        // Check for high gas price (frontrunning indicator)
        if (tx.gasprice > block.basefee * MAX_GAS_MULTIPLIER / 100) {
            score += 40;
        }

        // Check if user is a contract (MEV bot)
        if (isContract(user)) {
            score += 30;
        }

        return score > 100 ? 100 : score;
    }

    /**
     * @dev Detect sandwich attack patterns
     */
    function _detectSandwichAttack(
        address user,
        uint256 blockNumber,
        uint256 txIndex
    ) private view returns (uint256 score) {
        // This is a simplified detection - in practice, you'd need to analyze
        // the entire block's transactions and their relationships

        // Check if transaction is surrounded by similar transactions
        if (txIndex > 0 && txIndex < 10) { // Assuming max 10 tx per block for simplicity
            score += 25;
        }

        // Check for contract interaction (sandwich bots are usually contracts)
        if (isContract(user)) {
            score += 35;
        }

        // Check for high gas price
        if (tx.gasprice > block.basefee * 120 / 100) {
            score += 40;
        }

        return score > 100 ? 100 : score;
    }

    /**
     * @dev Detect arbitrage patterns
     */
    function _detectArbitrage(
        address user,
        uint256 blockNumber
    ) private view returns (uint256 score) {
        // Check if user is a contract (arbitrage bots are usually contracts)
        if (isContract(user)) {
            score += 40;
        }

        // Check for high gas price (arbitrage requires speed)
        if (tx.gasprice > block.basefee * 130 / 100) {
            score += 35;
        }

        // Check transaction timing (arbitrage happens quickly)
        if (blockNumber > 0 && block.timestamp - block.timestamp < 30) {
            score += 25;
        }

        return score > 100 ? 100 : score;
    }

    /**
     * @dev Check for suspicious activity in a specific block
     */
    function _hasSuspiciousActivity(
        address user,
        uint256 blockNumber
    ) private view returns (bool) {
        // This would need to be implemented with actual block analysis
        // For now, we'll use a simplified check
        return false;
    }

    /**
     * @dev Check if address is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Generate transaction hash for tracking
     */
    function generateTxHash(
        address user,
        uint256 amount,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, amount, timestamp, block.difficulty));
    }

    /**
     * @dev Validate security parameters
     */
    function validateSecurityParams(
        SecurityParams memory params
    ) internal pure returns (bool isValid) {
        return (
            params.cooldownPeriod >= 1 &&
            params.cooldownPeriod <= 3600 &&
            params.maxSlippage >= 10 &&
            params.maxSlippage <= 1000 &&
            params.maxGasPrice > 0 &&
            params.maxTxPerBlock > 0 &&
            params.maxTxPerUser > 0 &&
            params.riskThreshold <= MAX_RISK_SCORE
        );
    }
}
