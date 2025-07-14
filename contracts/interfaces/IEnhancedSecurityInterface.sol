// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEnhancedSecurityInterface
 * @dev Enhanced security interface that integrates all advanced security systems
 * @notice Provides a unified interface for military-grade security operations
 * @author EpicChainLabs Enhanced Security Team
 */
interface IEnhancedSecurityInterface {

    // ============ Structures ============

    struct SecurityConfiguration {
        uint256 securityLevel;
        uint256 threatLevel;
        uint256 encryptionComplexity;
        uint256 quantumResistanceLevel;
        uint256 monitoringIntensity;
        bool emergencyMode;
        bool quantumProtectionEnabled;
        bool biometricAuthEnabled;
        bool multifactorAuthEnabled;
        bool forensicModeEnabled;
        bool aiThreatDetectionEnabled;
        bool realtimeMonitoringEnabled;
    }

    struct ThreatAssessment {
        uint256 riskScore;
        uint256 threatLevel;
        uint256 confidence;
        uint256 urgency;
        address[] threateningAddresses;
        bytes32[] threatSignatures;
        string[] threatTypes;
        uint256 timestamp;
        bool requiresImmediateAction;
        bool isQuantumThreat;
        bool isAiDetected;
        bool isCorrelated;
    }

    struct SecurityMetrics {
        uint256 totalThreatsDetected;
        uint256 totalThreatsBlocked;
        uint256 totalSecurityEvents;
        uint256 averageResponseTime;
        uint256 systemUptime;
        uint256 detectionAccuracy;
        uint256 falsePositiveRate;
        uint256 quantumThreats;
        uint256 aiDetections;
        uint256 forensicAnalyses;
        uint256 lastUpdate;
    }

    struct SecurityAction {
        bytes32 actionId;
        uint256 actionType;
        address target;
        uint256 severity;
        uint256 timestamp;
        uint256 expiresAt;
        bool isActive;
        bool isAutomatic;
        bool requiresApproval;
        address approver;
        string reason;
    }

    struct AccessControl {
        address user;
        uint256 accessLevel;
        uint256 permissions;
        bool isActive;
        bool isBiometricVerified;
        bool isQuantumAuthenticated;
        bool isMultiFactorAuthenticated;
        uint256 lastAccess;
        uint256 accessCount;
        uint256 trustScore;
    }

    struct SecurityAuditLog {
        bytes32 logId;
        uint256 eventType;
        address actor;
        bytes32 dataHash;
        uint256 timestamp;
        uint256 securityLevel;
        bytes32 signature;
        bool isQuantumSigned;
        bool isVerified;
        string description;
    }

    // ============ Events ============

    event SecurityLevelChanged(
        uint256 indexed oldLevel,
        uint256 indexed newLevel,
        address indexed actor,
        uint256 timestamp
    );

    event ThreatDetected(
        bytes32 indexed threatId,
        uint256 indexed threatLevel,
        address indexed source,
        uint256 riskScore,
        uint256 timestamp
    );

    event SecurityActionExecuted(
        bytes32 indexed actionId,
        uint256 indexed actionType,
        address indexed target,
        uint256 severity,
        uint256 timestamp
    );

    event AccessGranted(
        address indexed user,
        uint256 indexed accessLevel,
        uint256 permissions,
        uint256 timestamp
    );

    event AccessRevoked(
        address indexed user,
        uint256 indexed reason,
        address indexed revoker,
        uint256 timestamp
    );

    event EmergencyModeActivated(
        uint256 indexed emergencyLevel,
        address indexed activator,
        string reason,
        uint256 timestamp
    );

    event EmergencyModeDeactivated(
        address indexed deactivator,
        uint256 timestamp
    );

    event QuantumThreatDetected(
        bytes32 indexed quantumThreatId,
        uint256 indexed quantumLevel,
        address indexed source,
        uint256 timestamp
    );

    event BiometricAuthenticationFailed(
        address indexed user,
        uint256 indexed attemptCount,
        uint256 timestamp
    );

    event SecurityAuditPerformed(
        bytes32 indexed auditId,
        address indexed auditor,
        uint256 securityScore,
        uint256 timestamp
    );

    event ForensicAnalysisCompleted(
        bytes32 indexed analysisId,
        address indexed analyst,
        bool evidenceFound,
        uint256 timestamp
    );

    event AIThreatDetected(
        bytes32 indexed aiThreatId,
        address indexed target,
        uint256 anomalyScore,
        uint256 confidence,
        uint256 timestamp
    );

    // ============ Core Security Functions ============

    /**
     * @dev Initializes the security system with configuration
     * @param config The security configuration
     */
    function initializeSecurity(SecurityConfiguration memory config) external;

    /**
     * @dev Updates the global security level
     * @param newLevel The new security level (1-10)
     * @param reason The reason for the change
     */
    function updateSecurityLevel(uint256 newLevel, string memory reason) external;

    /**
     * @dev Performs comprehensive threat assessment
     * @param target The address to assess
     * @param analysisDepth The depth of analysis
     * @return assessment The threat assessment result
     */
    function performThreatAssessment(
        address target,
        uint256 analysisDepth
    ) external returns (ThreatAssessment memory assessment);

    /**
     * @dev Executes security action based on threat level
     * @param actionType The type of security action
     * @param target The target address
     * @param severity The severity level
     * @param reason The reason for the action
     * @return actionId The ID of the executed action
     */
    function executeSecurityAction(
        uint256 actionType,
        address target,
        uint256 severity,
        string memory reason
    ) external returns (bytes32 actionId);

    /**
     * @dev Grants access to a user with specific permissions
     * @param user The user address
     * @param accessLevel The access level
     * @param permissions The permissions bitmap
     * @param requiresBiometric Whether biometric auth is required
     * @param requiresQuantum Whether quantum auth is required
     */
    function grantAccess(
        address user,
        uint256 accessLevel,
        uint256 permissions,
        bool requiresBiometric,
        bool requiresQuantum
    ) external;

    /**
     * @dev Revokes access from a user
     * @param user The user address
     * @param reason The reason for revocation
     */
    function revokeAccess(address user, uint256 reason) external;

    /**
     * @dev Activates emergency mode
     * @param emergencyLevel The emergency level (1-5)
     * @param reason The reason for activation
     */
    function activateEmergencyMode(uint256 emergencyLevel, string memory reason) external;

    /**
     * @dev Deactivates emergency mode
     */
    function deactivateEmergencyMode() external;

    // ============ Cryptographic Security Functions ============

    /**
     * @dev Encrypts data using multiple cryptographic layers
     * @param data The data to encrypt
     * @param encryptionLayers The number of encryption layers
     * @param useQuantumResistance Whether to use quantum-resistant encryption
     * @return encryptedData The encrypted data
     * @return encryptionId The encryption ID for decryption
     */
    function encryptData(
        bytes memory data,
        uint256 encryptionLayers,
        bool useQuantumResistance
    ) external returns (bytes memory encryptedData, bytes32 encryptionId);

    /**
     * @dev Decrypts data using encryption ID
     * @param encryptedData The encrypted data
     * @param encryptionId The encryption ID
     * @param decryptionKey The decryption key
     * @return decryptedData The decrypted data
     */
    function decryptData(
        bytes memory encryptedData,
        bytes32 encryptionId,
        bytes32 decryptionKey
    ) external returns (bytes memory decryptedData);

    /**
     * @dev Generates quantum-resistant key pair
     * @param keyStrength The key strength (bits)
     * @param algorithm The quantum algorithm to use
     * @return keyId The key ID
     * @return publicKey The public key
     */
    function generateQuantumKeyPair(
        uint256 keyStrength,
        uint256 algorithm
    ) external returns (bytes32 keyId, bytes memory publicKey);

    /**
     * @dev Hides data using advanced steganography
     * @param hiddenData The data to hide
     * @param coverData The cover data
     * @param steganographyAlgorithm The steganography algorithm
     * @return stegoData The data with hidden information
     * @return extractionKey The key for extraction
     */
    function hideDataSteganographically(
        bytes memory hiddenData,
        bytes memory coverData,
        uint256 steganographyAlgorithm
    ) external returns (bytes memory stegoData, bytes32 extractionKey);

    /**
     * @dev Extracts hidden data from steganographic container
     * @param stegoData The steganographic data
     * @param extractionKey The extraction key
     * @return hiddenData The extracted hidden data
     */
    function extractHiddenData(
        bytes memory stegoData,
        bytes32 extractionKey
    ) external returns (bytes memory hiddenData);

    // ============ Multi-Signature Security Functions ============

    /**
     * @dev Creates a multi-signature security proposal
     * @param target The target address
     * @param value The value to send
     * @param data The call data
     * @param requiredSignatures The number of required signatures
     * @param deadline The deadline for execution
     * @return proposalId The proposal ID
     */
    function createMultiSigProposal(
        address target,
        uint256 value,
        bytes memory data,
        uint256 requiredSignatures,
        uint256 deadline
    ) external returns (bytes32 proposalId);

    /**
     * @dev Signs a multi-signature proposal
     * @param proposalId The proposal ID
     * @param signature The signature
     * @param signatureType The type of signature
     */
    function signMultiSigProposal(
        bytes32 proposalId,
        bytes memory signature,
        uint256 signatureType
    ) external;

    /**
     * @dev Executes a multi-signature proposal
     * @param proposalId The proposal ID
     * @return success Whether the execution was successful
     */
    function executeMultiSigProposal(bytes32 proposalId) external returns (bool success);

    // ============ Timelock Security Functions ============

    /**
     * @dev Schedules a timelock proposal
     * @param target The target address
     * @param value The value to send
     * @param data The call data
     * @param delay The delay before execution
     * @param securityLevel The required security level
     * @return proposalId The proposal ID
     */
    function scheduleTimelockProposal(
        address target,
        uint256 value,
        bytes memory data,
        uint256 delay,
        uint256 securityLevel
    ) external returns (bytes32 proposalId);

    /**
     * @dev Executes a timelock proposal
     * @param proposalId The proposal ID
     * @return success Whether the execution was successful
     */
    function executeTimelockProposal(bytes32 proposalId) external returns (bool success);

    /**
     * @dev Cancels a timelock proposal
     * @param proposalId The proposal ID
     * @param reason The reason for cancellation
     */
    function cancelTimelockProposal(bytes32 proposalId, string memory reason) external;

    // ============ Threat Detection Functions ============

    /**
     * @dev Adds a threat signature to the detection system
     * @param signature The threat signature
     * @param threatType The type of threat
     * @param severity The severity level
     * @param confidence The confidence level
     * @return signatureId The signature ID
     */
    function addThreatSignature(
        bytes memory signature,
        uint256 threatType,
        uint256 severity,
        uint256 confidence
    ) external returns (bytes32 signatureId);

    /**
     * @dev Detects threats in real-time
     * @param transactionData The transaction data to analyze
     * @param behaviorData The behavioral data
     * @return threatDetected Whether a threat was detected
     * @return threatLevel The detected threat level
     * @return confidence The confidence level
     */
    function detectThreats(
        bytes memory transactionData,
        bytes memory behaviorData
    ) external returns (bool threatDetected, uint256 threatLevel, uint256 confidence);

    /**
     * @dev Performs AI-powered threat analysis
     * @param target The target address
     * @param analysisData The data for analysis
     * @param modelId The AI model ID
     * @return anomalyScore The anomaly score
     * @return confidence The confidence level
     */
    function performAIThreatAnalysis(
        address target,
        bytes memory analysisData,
        bytes32 modelId
    ) external returns (uint256 anomalyScore, uint256 confidence);

    /**
     * @dev Monitors quantum threats
     * @param quantumState The quantum state to monitor
     * @param monitoringParams The monitoring parameters
     * @return quantumThreatDetected Whether a quantum threat was detected
     * @return quantumThreatLevel The quantum threat level
     */
    function monitorQuantumThreats(
        uint256 quantumState,
        bytes memory monitoringParams
    ) external returns (bool quantumThreatDetected, uint256 quantumThreatLevel);

    // ============ Authentication Functions ============

    /**
     * @dev Authenticates user with biometric data
     * @param user The user address
     * @param biometricData The biometric data
     * @return authenticated Whether authentication was successful
     * @return confidence The confidence level
     */
    function authenticateBiometric(
        address user,
        bytes memory biometricData
    ) external returns (bool authenticated, uint256 confidence);

    /**
     * @dev Performs multi-factor authentication
     * @param user The user address
     * @param factors The authentication factors
     * @return authenticated Whether authentication was successful
     * @return factorsVerified The number of factors verified
     */
    function performMultiFactorAuth(
        address user,
        bytes[] memory factors
    ) external returns (bool authenticated, uint256 factorsVerified);

    /**
     * @dev Authenticates using quantum cryptography
     * @param user The user address
     * @param quantumProof The quantum proof
     * @param quantumKey The quantum key
     * @return authenticated Whether authentication was successful
     */
    function authenticateQuantum(
        address user,
        bytes memory quantumProof,
        bytes32 quantumKey
    ) external returns (bool authenticated);

    // ============ Forensic Functions ============

    /**
     * @dev Performs forensic analysis on suspicious activity
     * @param suspiciousData The suspicious data
     * @param analysisType The type of analysis
     * @param depth The analysis depth
     * @return analysisId The analysis ID
     * @return evidenceFound Whether evidence was found
     * @return confidence The confidence level
     */
    function performForensicAnalysis(
        bytes memory suspiciousData,
        uint256 analysisType,
        uint256 depth
    ) external returns (bytes32 analysisId, bool evidenceFound, uint256 confidence);

    /**
     * @dev Creates a security audit log
     * @param eventType The event type
     * @param actor The actor address
     * @param dataHash The data hash
     * @param description The description
     * @return logId The log ID
     */
    function createSecurityAuditLog(
        uint256 eventType,
        address actor,
        bytes32 dataHash,
        string memory description
    ) external returns (bytes32 logId);

    /**
     * @dev Verifies the integrity of security logs
     * @param logId The log ID
     * @param signature The signature to verify
     * @return verified Whether the log is verified
     */
    function verifySecurityLog(
        bytes32 logId,
        bytes memory signature
    ) external returns (bool verified);

    // ============ View Functions ============

    /**
     * @dev Gets the current security configuration
     * @return config The current security configuration
     */
    function getSecurityConfiguration() external view returns (SecurityConfiguration memory config);

    /**
     * @dev Gets the current security metrics
     * @return metrics The current security metrics
     */
    function getSecurityMetrics() external view returns (SecurityMetrics memory metrics);

    /**
     * @dev Gets the threat assessment for an address
     * @param target The target address
     * @return assessment The threat assessment
     */
    function getThreatAssessment(address target) external view returns (ThreatAssessment memory assessment);

    /**
     * @dev Gets the access control information for a user
     * @param user The user address
     * @return accessControl The access control information
     */
    function getAccessControl(address user) external view returns (AccessControl memory accessControl);

    /**
     * @dev Gets the security action information
     * @param actionId The action ID
     * @return action The security action information
     */
    function getSecurityAction(bytes32 actionId) external view returns (SecurityAction memory action);

    /**
     * @dev Checks if an address is blacklisted
     * @param addr The address to check
     * @return blacklisted Whether the address is blacklisted
     */
    function isBlacklisted(address addr) external view returns (bool blacklisted);

    /**
     * @dev Checks if an address is whitelisted
     * @param addr The address to check
     * @return whitelisted Whether the address is whitelisted
     */
    function isWhitelisted(address addr) external view returns (bool whitelisted);

    /**
     * @dev Gets the risk score for an address
     * @param addr The address to check
     * @return riskScore The risk score
     */
    function getRiskScore(address addr) external view returns (uint256 riskScore);

    /**
     * @dev Gets the current threat level
     * @return threatLevel The current threat level
     */
    function getCurrentThreatLevel() external view returns (uint256 threatLevel);

    /**
     * @dev Checks if emergency mode is active
     * @return emergencyActive Whether emergency mode is active
     * @return emergencyLevel The emergency level
     */
    function isEmergencyMode() external view returns (bool emergencyActive, uint256 emergencyLevel);

    /**
     * @dev Gets the security audit log
     * @param logId The log ID
     * @return auditLog The security audit log
     */
    function getSecurityAuditLog(bytes32 logId) external view returns (SecurityAuditLog memory auditLog);

    /**
     * @dev Checks if quantum protection is enabled
     * @return quantumEnabled Whether quantum protection is enabled
     */
    function isQuantumProtectionEnabled() external view returns (bool quantumEnabled);

    /**
     * @dev Gets the system uptime
     * @return uptime The system uptime in seconds
     */
    function getSystemUptime() external view returns (uint256 uptime);

    /**
     * @dev Gets the detection accuracy
     * @return accuracy The detection accuracy percentage
     */
    function getDetectionAccuracy() external view returns (uint256 accuracy);

    /**
     * @dev Gets the false positive rate
     * @return falsePositiveRate The false positive rate percentage
     */
    function getFalsePositiveRate() external view returns (uint256 falsePositiveRate);

    /**
     * @dev Gets the average response time
     * @return responseTime The average response time in seconds
     */
    function getAverageResponseTime() external view returns (uint256 responseTime);
}
