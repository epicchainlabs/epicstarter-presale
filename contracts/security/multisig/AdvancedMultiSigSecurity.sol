// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AdvancedMultiSigSecurity
 * @dev Advanced multi-signature security contract with threshold signatures, time delays, and quantum-resistant features
 * @notice Implements military-grade multi-signature security with advanced cryptographic features
 * @author EpicChainLabs Advanced Security Team
 */
contract AdvancedMultiSigSecurity is AccessControl, ReentrancyGuard, Pausable, EIP712 {
    using ECDSA for bytes32;
    using SignatureChecker for address;
    using SafeERC20 for IERC20;

    // ============ Constants ============

    bytes32 public constant MULTISIG_ADMIN_ROLE = keccak256("MULTISIG_ADMIN_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant SECURITY_OFFICER_ROLE = keccak256("SECURITY_OFFICER_ROLE");
    bytes32 public constant TIMELOCK_MANAGER_ROLE = keccak256("TIMELOCK_MANAGER_ROLE");
    bytes32 public constant QUANTUM_GUARDIAN_ROLE = keccak256("QUANTUM_GUARDIAN_ROLE");

    uint256 private constant MAX_SIGNERS = 20;
    uint256 private constant MIN_SIGNERS = 2;
    uint256 private constant MAX_THRESHOLD = 15;
    uint256 private constant MIN_THRESHOLD = 2;
    uint256 private constant MAX_DELAY = 30 days;
    uint256 private constant MIN_DELAY = 1 hours;
    uint256 private constant SIGNATURE_EXPIRY = 24 hours;
    uint256 private constant NONCE_EXPIRY = 48 hours;

    // Quantum resistance constants
    uint256 private constant QUANTUM_SIGNATURE_SIZE = 3293;
    uint256 private constant QUANTUM_KEY_SIZE = 1568;
    uint256 private constant QUANTUM_SECURITY_LEVEL = 256;

    // ============ Structures ============

    struct Signer {
        address signerAddress;
        bytes32 publicKeyHash;
        uint256 weight;
        uint256 addedAt;
        uint256 lastUsed;
        bool isActive;
        bool isQuantumResistant;
        bytes32 quantumKeyId;
        uint256 signatureCount;
        uint256 trustScore;
    }

    struct Transaction {
        uint256 id;
        address to;
        uint256 value;
        bytes data;
        uint256 nonce;
        uint256 deadline;
        uint256 createdAt;
        uint256 executedAt;
        address creator;
        TransactionStatus status;
        TransactionType txType;
        uint256 requiredSignatures;
        uint256 currentSignatures;
        uint256 gasLimit;
        uint256 gasPrice;
        bytes32 dataHash;
    }

    struct Signature {
        address signer;
        bytes signature;
        bytes32 messageHash;
        uint256 timestamp;
        SignatureType sigType;
        bool isQuantumResistant;
        bytes32 quantumProof;
        uint256 nonce;
    }

    struct ThresholdScheme {
        uint256 id;
        string name;
        uint256 threshold;
        uint256 totalSigners;
        uint256[] signerWeights;
        address[] signers;
        uint256 createdAt;
        uint256 lastModified;
        bool isActive;
        bool isQuantumResistant;
        bytes32 schemeHash;
    }

    struct TimeDelayConfig {
        uint256 delay;
        uint256 minDelay;
        uint256 maxDelay;
        uint256 emergencyDelay;
        bool isActive;
        mapping(bytes32 => uint256) customDelays;
        mapping(address => uint256) userDelays;
    }

    struct SecurityPolicy {
        uint256 maxDailyTransactions;
        uint256 maxDailyValue;
        uint256 maxTransactionValue;
        uint256 coolingPeriod;
        uint256 emergencyThreshold;
        bool requiresAllSigners;
        bool quantumResistanceRequired;
        bool biometricRequired;
        bool hardwareWalletRequired;
        uint256 riskScore;
    }

    struct EmergencyConfig {
        bool isEmergency;
        uint256 emergencyLevel;
        uint256 activatedAt;
        address activatedBy;
        uint256 emergencyThreshold;
        uint256 emergencyDelay;
        bool allowEmergencyExecution;
        address[] emergencySigners;
        string reason;
    }

    struct AuditLog {
        uint256 id;
        address actor;
        bytes32 action;
        bytes32 dataHash;
        uint256 timestamp;
        uint256 blockNumber;
        bytes32 transactionHash;
        uint256 gasUsed;
        bool success;
        string details;
    }

    struct BiometricData {
        bytes32 biometricHash;
        uint256 enrolledAt;
        uint256 lastUsed;
        uint256 matchScore;
        bool isActive;
        address owner;
    }

    struct HardwareWalletData {
        bytes32 deviceId;
        bytes32 publicKeyHash;
        uint256 registeredAt;
        uint256 lastUsed;
        bool isActive;
        address owner;
        string deviceType;
    }

    // ============ Enums ============

    enum TransactionStatus {
        PENDING,
        CONFIRMED,
        EXECUTED,
        CANCELLED,
        EXPIRED,
        REJECTED
    }

    enum TransactionType {
        STANDARD,
        EMERGENCY,
        ADMINISTRATIVE,
        SECURITY_CRITICAL,
        QUANTUM_RESISTANT
    }

    enum SignatureType {
        STANDARD_ECDSA,
        QUANTUM_RESISTANT,
        BIOMETRIC_ENHANCED,
        HARDWARE_WALLET,
        MULTI_FACTOR
    }

    // ============ State Variables ============

    mapping(address => Signer) public signers;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => Signature)) public transactionSignatures;
    mapping(uint256 => ThresholdScheme) public thresholdSchemes;
    mapping(address => BiometricData) public biometricRegistry;
    mapping(address => HardwareWalletData) public hardwareWallets;
    mapping(uint256 => AuditLog) public auditLogs;
    mapping(bytes32 => bool) public usedNonces;
    mapping(address => uint256) public dailyTransactionCount;
    mapping(address => uint256) public dailyValueTransferred;
    mapping(address => uint256) public lastTransactionTime;
    mapping(address => uint256) public signerTrustScores;

    address[] public signerList;
    uint256[] public transactionList;
    uint256 public currentThreshold;
    uint256 public transactionCount;
    uint256 public auditLogCount;
    uint256 public activeSchemeId;

    TimeDelayConfig public timeDelayConfig;
    SecurityPolicy public securityPolicy;
    EmergencyConfig public emergencyConfig;

    bool public quantumResistanceEnabled;
    bool public biometricAuthEnabled;
    bool public hardwareWalletRequired;
    bool public multiFactorAuthEnabled;
    bool public advancedAuditingEnabled;

    bytes32 public domainSeparator;
    bytes32 public globalNonce;
    uint256 public lastNonceReset;

    // ============ Events ============

    event SignerAdded(
        address indexed signer,
        uint256 weight,
        bool isQuantumResistant,
        uint256 timestamp
    );

    event SignerRemoved(
        address indexed signer,
        uint256 timestamp
    );

    event TransactionSubmitted(
        uint256 indexed transactionId,
        address indexed creator,
        address indexed to,
        uint256 value,
        bytes32 dataHash
    );

    event TransactionSigned(
        uint256 indexed transactionId,
        address indexed signer,
        SignatureType sigType,
        uint256 timestamp
    );

    event TransactionExecuted(
        uint256 indexed transactionId,
        address indexed executor,
        bool success,
        uint256 timestamp
    );

    event ThresholdUpdated(
        uint256 oldThreshold,
        uint256 newThreshold,
        uint256 timestamp
    );

    event EmergencyActivated(
        uint256 level,
        address indexed activatedBy,
        string reason,
        uint256 timestamp
    );

    event EmergencyDeactivated(
        address indexed deactivatedBy,
        uint256 timestamp
    );

    event BiometricRegistered(
        address indexed user,
        bytes32 biometricHash,
        uint256 timestamp
    );

    event HardwareWalletRegistered(
        address indexed user,
        bytes32 deviceId,
        string deviceType,
        uint256 timestamp
    );

    event SecurityPolicyUpdated(
        bytes32 indexed policyHash,
        uint256 timestamp
    );

    event AuditLogCreated(
        uint256 indexed logId,
        address indexed actor,
        bytes32 action,
        uint256 timestamp
    );

    event QuantumThreatDetected(
        address indexed source,
        uint256 threatLevel,
        uint256 timestamp
    );

    // ============ Modifiers ============

    modifier onlyMultiSigAdmin() {
        require(hasRole(MULTISIG_ADMIN_ROLE, msg.sender), "Not multisig admin");
        _;
    }

    modifier onlyGuardian() {
        require(hasRole(GUARDIAN_ROLE, msg.sender), "Not guardian");
        _;
    }

    modifier onlySecurityOfficer() {
        require(hasRole(SECURITY_OFFICER_ROLE, msg.sender), "Not security officer");
        _;
    }

    modifier onlyQuantumGuardian() {
        require(hasRole(QUANTUM_GUARDIAN_ROLE, msg.sender), "Not quantum guardian");
        _;
    }

    modifier onlyActiveSigner() {
        require(signers[msg.sender].isActive, "Not active signer");
        _;
    }

    modifier validTransaction(uint256 transactionId) {
        require(transactionId < transactionCount, "Invalid transaction ID");
        require(transactions[transactionId].status == TransactionStatus.PENDING, "Transaction not pending");
        require(transactions[transactionId].deadline > block.timestamp, "Transaction expired");
        _;
    }

    modifier notEmergency() {
        require(!emergencyConfig.isEmergency, "Emergency mode active");
        _;
    }

    modifier emergencyOnly() {
        require(emergencyConfig.isEmergency, "Not in emergency mode");
        _;
    }

    modifier quantumSecure() {
        if (quantumResistanceEnabled) {
            require(signers[msg.sender].isQuantumResistant, "Quantum resistance required");
        }
        _;
    }

    modifier biometricAuth() {
        if (biometricAuthEnabled) {
            require(biometricRegistry[msg.sender].isActive, "Biometric auth required");
        }
        _;
    }

    modifier hardwareWalletAuth() {
        if (hardwareWalletRequired) {
            require(hardwareWallets[msg.sender].isActive, "Hardware wallet required");
        }
        _;
    }

    modifier rateLimited() {
        require(
            block.timestamp >= lastTransactionTime[msg.sender] + securityPolicy.coolingPeriod,
            "Rate limited"
        );
        _;
    }

    // ============ Constructor ============

    constructor(
        address[] memory _signers,
        uint256[] memory _weights,
        uint256 _threshold
    ) EIP712("AdvancedMultiSigSecurity", "1") {
        require(_signers.length >= MIN_SIGNERS, "Too few signers");
        require(_signers.length <= MAX_SIGNERS, "Too many signers");
        require(_signers.length == _weights.length, "Signers and weights length mismatch");
        require(_threshold >= MIN_THRESHOLD, "Threshold too low");
        require(_threshold <= MAX_THRESHOLD, "Threshold too high");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MULTISIG_ADMIN_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
        _grantRole(SECURITY_OFFICER_ROLE, msg.sender);
        _grantRole(TIMELOCK_MANAGER_ROLE, msg.sender);
        _grantRole(QUANTUM_GUARDIAN_ROLE, msg.sender);

        // Initialize signers
        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), "Invalid signer address");
            require(_weights[i] > 0, "Invalid weight");

            signers[_signers[i]] = Signer({
                signerAddress: _signers[i],
                publicKeyHash: keccak256(abi.encodePacked(_signers[i])),
                weight: _weights[i],
                addedAt: block.timestamp,
                lastUsed: 0,
                isActive: true,
                isQuantumResistant: false,
                quantumKeyId: bytes32(0),
                signatureCount: 0,
                trustScore: 100
            });

            signerList.push(_signers[i]);
        }

        currentThreshold = _threshold;

        // Initialize time delay configuration
        timeDelayConfig.delay = 24 hours;
        timeDelayConfig.minDelay = MIN_DELAY;
        timeDelayConfig.maxDelay = MAX_DELAY;
        timeDelayConfig.emergencyDelay = 1 hours;
        timeDelayConfig.isActive = true;

        // Initialize security policy
        securityPolicy = SecurityPolicy({
            maxDailyTransactions: 100,
            maxDailyValue: 1000000 * 10**18,
            maxTransactionValue: 100000 * 10**18,
            coolingPeriod: 5 minutes,
            emergencyThreshold: 3,
            requiresAllSigners: false,
            quantumResistanceRequired: false,
            biometricRequired: false,
            hardwareWalletRequired: false,
            riskScore: 5
        });

        // Initialize emergency configuration
        emergencyConfig.isEmergency = false;
        emergencyConfig.emergencyLevel = 0;
        emergencyConfig.emergencyThreshold = 3;
        emergencyConfig.emergencyDelay = 1 hours;
        emergencyConfig.allowEmergencyExecution = true;

        quantumResistanceEnabled = false;
        biometricAuthEnabled = false;
        hardwareWalletRequired = false;
        multiFactorAuthEnabled = false;
        advancedAuditingEnabled = true;

        domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("AdvancedMultiSigSecurity")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));

        globalNonce = keccak256(abi.encodePacked(block.timestamp, block.difficulty));
        lastNonceReset = block.timestamp;
    }

    // ============ Signer Management ============

    /**
     * @dev Adds a new signer to the multisig
     * @param signer The address of the new signer
     * @param weight The weight of the signer
     * @param isQuantumResistant Whether the signer supports quantum resistance
     * @param quantumKeyId The quantum key ID if applicable
     */
    function addSigner(
        address signer,
        uint256 weight,
        bool isQuantumResistant,
        bytes32 quantumKeyId
    ) external onlyMultiSigAdmin whenNotPaused {
        require(signer != address(0), "Invalid signer address");
        require(!signers[signer].isActive, "Signer already exists");
        require(signerList.length < MAX_SIGNERS, "Too many signers");
        require(weight > 0, "Invalid weight");

        signers[signer] = Signer({
            signerAddress: signer,
            publicKeyHash: keccak256(abi.encodePacked(signer)),
            weight: weight,
            addedAt: block.timestamp,
            lastUsed: 0,
            isActive: true,
            isQuantumResistant: isQuantumResistant,
            quantumKeyId: quantumKeyId,
            signatureCount: 0,
            trustScore: 100
        });

        signerList.push(signer);

        _createAuditLog(
            msg.sender,
            keccak256("SIGNER_ADDED"),
            keccak256(abi.encodePacked(signer, weight)),
            "Signer added to multisig"
        );

        emit SignerAdded(signer, weight, isQuantumResistant, block.timestamp);
    }

    /**
     * @dev Removes a signer from the multisig
     * @param signer The address of the signer to remove
     */
    function removeSigner(address signer) external onlyMultiSigAdmin whenNotPaused {
        require(signers[signer].isActive, "Signer not active");
        require(signerList.length > MIN_SIGNERS, "Cannot remove, too few signers");

        signers[signer].isActive = false;

        // Remove from signer list
        for (uint256 i = 0; i < signerList.length; i++) {
            if (signerList[i] == signer) {
                signerList[i] = signerList[signerList.length - 1];
                signerList.pop();
                break;
            }
        }

        _createAuditLog(
            msg.sender,
            keccak256("SIGNER_REMOVED"),
            keccak256(abi.encodePacked(signer)),
            "Signer removed from multisig"
        );

        emit SignerRemoved(signer, block.timestamp);
    }

    /**
     * @dev Updates the threshold required for transaction approval
     * @param newThreshold The new threshold value
     */
    function updateThreshold(uint256 newThreshold) external onlyMultiSigAdmin {
        require(newThreshold >= MIN_THRESHOLD, "Threshold too low");
        require(newThreshold <= MAX_THRESHOLD, "Threshold too high");
        require(newThreshold <= signerList.length, "Threshold exceeds signer count");

        uint256 oldThreshold = currentThreshold;
        currentThreshold = newThreshold;

        _createAuditLog(
            msg.sender,
            keccak256("THRESHOLD_UPDATED"),
            keccak256(abi.encodePacked(oldThreshold, newThreshold)),
            "Threshold updated"
        );

        emit ThresholdUpdated(oldThreshold, newThreshold, block.timestamp);
    }

    // ============ Transaction Management ============

    /**
     * @dev Submits a new transaction for approval
     * @param to The target address
     * @param value The value to send
     * @param data The transaction data
     * @param deadline The deadline for execution
     * @param txType The type of transaction
     */
    function submitTransaction(
        address to,
        uint256 value,
        bytes memory data,
        uint256 deadline,
        TransactionType txType
    ) external onlyActiveSigner rateLimited quantumSecure biometricAuth hardwareWalletAuth
      returns (uint256) {
        require(to != address(0), "Invalid target address");
        require(deadline > block.timestamp, "Invalid deadline");
        require(deadline <= block.timestamp + MAX_DELAY, "Deadline too far");

        // Check security policy
        require(value <= securityPolicy.maxTransactionValue, "Value exceeds limit");
        require(
            dailyTransactionCount[msg.sender] < securityPolicy.maxDailyTransactions,
            "Daily transaction limit exceeded"
        );
        require(
            dailyValueTransferred[msg.sender] + value <= securityPolicy.maxDailyValue,
            "Daily value limit exceeded"
        );

        uint256 transactionId = transactionCount++;
        bytes32 dataHash = keccak256(data);

        transactions[transactionId] = Transaction({
            id: transactionId,
            to: to,
            value: value,
            data: data,
            nonce: uint256(keccak256(abi.encodePacked(globalNonce, transactionId))),
            deadline: deadline,
            createdAt: block.timestamp,
            executedAt: 0,
            creator: msg.sender,
            status: TransactionStatus.PENDING,
            txType: txType,
            requiredSignatures: _getRequiredSignatures(txType),
            currentSignatures: 0,
            gasLimit: 0,
            gasPrice: 0,
            dataHash: dataHash
        });

        transactionList.push(transactionId);
        dailyTransactionCount[msg.sender]++;
        lastTransactionTime[msg.sender] = block.timestamp;

        _createAuditLog(
            msg.sender,
            keccak256("TRANSACTION_SUBMITTED"),
            dataHash,
            "Transaction submitted for approval"
        );

        emit TransactionSubmitted(transactionId, msg.sender, to, value, dataHash);
        return transactionId;
    }

    /**
     * @dev Signs a pending transaction
     * @param transactionId The ID of the transaction to sign
     * @param signature The signature
     * @param sigType The type of signature
     */
    function signTransaction(
        uint256 transactionId,
        bytes memory signature,
        SignatureType sigType
    ) external onlyActiveSigner validTransaction(transactionId) quantumSecure biometricAuth {
        require(
            transactionSignatures[transactionId][msg.sender].timestamp == 0,
            "Already signed"
        );

        Transaction storage transaction = transactions[transactionId];
        bytes32 messageHash = _getTransactionHash(transaction);

        // Verify signature
        bool isValid = _verifySignature(msg.sender, messageHash, signature, sigType);
        require(isValid, "Invalid signature");

        // Store signature
        transactionSignatures[transactionId][msg.sender] = Signature({
            signer: msg.sender,
            signature: signature,
            messageHash: messageHash,
            timestamp: block.timestamp,
            sigType: sigType,
            isQuantumResistant: sigType == SignatureType.QUANTUM_RESISTANT,
            quantumProof: bytes32(0),
            nonce: transaction.nonce
        });

        transaction.currentSignatures++;
        signers[msg.sender].signatureCount++;
        signers[msg.sender].lastUsed = block.timestamp;

        _createAuditLog(
            msg.sender,
            keccak256("TRANSACTION_SIGNED"),
            messageHash,
            "Transaction signed"
        );

        emit TransactionSigned(transactionId, msg.sender, sigType, block.timestamp);

        // Auto-execute if threshold reached and delay passed
        if (_canExecuteTransaction(transactionId)) {
            _executeTransaction(transactionId);
        }
    }

    /**
     * @dev Executes a transaction if requirements are met
     * @param transactionId The ID of the transaction to execute
     */
    function executeTransaction(uint256 transactionId)
        external onlyActiveSigner validTransaction(transactionId) nonReentrant {
        require(_canExecuteTransaction(transactionId), "Cannot execute");

        _executeTransaction(transactionId);
    }

    /**
     * @dev Cancels a pending transaction
     * @param transactionId The ID of the transaction to cancel
     */
    function cancelTransaction(uint256 transactionId)
        external validTransaction(transactionId) {
        Transaction storage transaction = transactions[transactionId];

        require(
            transaction.creator == msg.sender || hasRole(MULTISIG_ADMIN_ROLE, msg.sender),
            "Not authorized to cancel"
        );

        transaction.status = TransactionStatus.CANCELLED;

        _createAuditLog(
            msg.sender,
            keccak256("TRANSACTION_CANCELLED"),
            transaction.dataHash,
            "Transaction cancelled"
        );
    }

    // ============ Emergency Functions ============

    /**
     * @dev Activates emergency mode
     * @param level The emergency level (1-5)
     * @param reason The reason for emergency activation
     */
    function activateEmergency(uint256 level, string memory reason)
        external onlyGuardian {
        require(level >= 1 && level <= 5, "Invalid emergency level");
        require(!emergencyConfig.isEmergency, "Emergency already active");

        emergencyConfig.isEmergency = true;
        emergencyConfig.emergencyLevel = level;
        emergencyConfig.activatedAt = block.timestamp;
        emergencyConfig.activatedBy = msg.sender;
        emergencyConfig.reason = reason;

        // Set emergency threshold based on level
        if (level >= 4) {
            emergencyConfig.emergencyThreshold = 1; // Single signer for critical emergencies
        } else if (level >= 3) {
            emergencyConfig.emergencyThreshold = 2;
        } else {
            emergencyConfig.emergencyThreshold = currentThreshold;
        }

        _createAuditLog(
            msg.sender,
            keccak256("EMERGENCY_ACTIVATED"),
            keccak256(abi.encodePacked(level, reason)),
            "Emergency mode activated"
        );

        emit EmergencyActivated(level, msg.sender, reason, block.timestamp);
    }

    /**
     * @dev Deactivates emergency mode
     */
    function deactivateEmergency() external onlyGuardian emergencyOnly {
        emergencyConfig.isEmergency = false;
        emergencyConfig.emergencyLevel = 0;
        emergencyConfig.activatedAt = 0;
        emergencyConfig.activatedBy = address(0);
        emergencyConfig.reason = "";

        _createAuditLog(
            msg.sender,
            keccak256("EMERGENCY_DEACTIVATED"),
            bytes32(0),
            "Emergency mode deactivated"
        );

        emit EmergencyDeactivated(msg.sender, block.timestamp);
    }

    // ============ Biometric Authentication ============

    /**
     * @dev Registers biometric data for a user
     * @param user The user address
     * @param biometricHash The hash of biometric data
     * @param matchScore The matching score threshold
     */
    function registerBiometric(
        address user,
        bytes32 biometricHash,
        uint256 matchScore
    ) external onlySecurityOfficer {
        require(user != address(0), "Invalid user address");
        require(biometricHash != bytes32(0), "Invalid biometric hash");
        require(matchScore >= 80, "Match score too low");

        biometricRegistry[user] = BiometricData({
            biometricHash: biometricHash,
            enrolledAt: block.timestamp,
            lastUsed: 0,
            matchScore: matchScore,
            isActive: true,
            owner: user
        });

        _createAuditLog(
            msg.sender,
            keccak256("BIOMETRIC_REGISTERED"),
            biometricHash,
            "Biometric data registered"
        );

        emit BiometricRegistered(user, biometricHash, block.timestamp);
    }

    /**
     * @dev Registers a hardware wallet for a user
     * @param user The user address
     * @param deviceId The device ID
     * @param publicKeyHash The public key hash
     * @param deviceType The type of hardware wallet
     */
    function registerHardwareWallet(
        address user,
        bytes32 deviceId,
        bytes32 publicKeyHash,
        string memory deviceType
    ) external onlySecurityOfficer {
        require(user != address(0), "Invalid user address");
        require(deviceId != bytes32(0), "Invalid device ID");
        require(publicKeyHash != bytes32(0), "Invalid public key hash");

        hardwareWallets[user] = HardwareWalletData({
            deviceId: deviceId,
            publicKeyHash: publicKeyHash,
            registeredAt: block.timestamp,
            lastUsed: 0,
            isActive: true,
            owner: user,
            deviceType: deviceType
        });

        _createAuditLog(
            msg.sender,
            keccak256("HARDWARE_WALLET_REGISTERED"),
            deviceId,
            "Hardware wallet registered"
        );

        emit HardwareWalletRegistered(user, deviceId, deviceType, block.timestamp);
    }

    // ============ Internal Functions ============

    function _getRequiredSignatures(TransactionType txType) internal view returns (uint256) {
        if (emergencyConfig.isEmergency) {
            return emergencyConfig.emergencyThreshold;
        }

        if (txType == TransactionType.SECURITY_CRITICAL) {
            return currentThreshold + 1;
        }

        if (txType == TransactionType.EMERGENCY) {
            return emergencyConfig.emergencyThreshold;
        }

        return currentThreshold;
    }

    function _canExecuteTransaction(uint256 transactionId) internal view returns (bool) {
        Transaction storage transaction = transactions[transactionId];

        if (transaction.status != TransactionStatus.PENDING) {
            return false;
        }

        if (transaction.deadline <= block.timestamp) {
            return false;
        }

        if (transaction.currentSignatures < transaction.requiredSignatures) {
            return false;
        }

        // Check time delay
        uint256 requiredDelay = _getRequiredDelay(transaction.txType);
        if (block.timestamp < transaction.createdAt + requiredDelay) {
            return false;
        }

        return true;
    }

    function _getRequiredDelay(TransactionType txType) internal view returns (uint256) {
        if (emergencyConfig.isEmergency) {
            return emergencyConfig.emergencyDelay;
        }

        if (txType == TransactionType.EMERGENCY) {
            return emergencyConfig.emergencyDelay;
        }

        return timeDelayConfig.delay;
    }

    function _executeTransaction(uint256 transactionId) internal {
        Transaction storage transaction = transactions[transactionId];

        transaction.status = TransactionStatus.EXECUTED;
        transaction.executedAt = block.timestamp;

        bool success = false;
        bytes memory returnData;

        if (transaction.value > 0) {
            (success, returnData) = transaction.to.call{value: transaction.value}(transaction.data);
        } else {
            (success, returnData) = transaction.to.call(transaction.data);
        }

        if (success) {
            dailyValueTransferred[transaction.creator] += transaction.value;
        }

        _createAuditLog
