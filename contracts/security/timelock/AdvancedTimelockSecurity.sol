// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AdvancedTimelockSecurity
 * @dev Advanced timelock security contract with multi-layer time delays, emergency controls, and quantum-resistant features
 * @notice Implements military-grade timelock security with advanced cryptographic features and multi-dimensional security layers
 * @author EpicChainLabs Advanced Security Team
 */
contract AdvancedTimelockSecurity is AccessControl, ReentrancyGuard, Pausable, EIP712 {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    // ============ Constants ============

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant TIMELOCK_EXECUTOR_ROLE = keccak256("TIMELOCK_EXECUTOR_ROLE");
    bytes32 public constant TIMELOCK_PROPOSER_ROLE = keccak256("TIMELOCK_PROPOSER_ROLE");
    bytes32 public constant TIMELOCK_CANCELLER_ROLE = keccak256("TIMELOCK_CANCELLER_ROLE");
    bytes32 public constant EMERGENCY_GUARDIAN_ROLE = keccak256("EMERGENCY_GUARDIAN_ROLE");
    bytes32 public constant QUANTUM_TIMELOCK_ROLE = keccak256("QUANTUM_TIMELOCK_ROLE");
    bytes32 public constant SECURITY_COUNCIL_ROLE = keccak256("SECURITY_COUNCIL_ROLE");

    uint256 private constant MIN_DELAY = 1 hours;
    uint256 private constant MAX_DELAY = 365 days;
    uint256 private constant EMERGENCY_DELAY = 30 minutes;
    uint256 private constant CRITICAL_DELAY = 7 days;
    uint256 private constant QUANTUM_DELAY = 24 hours;
    uint256 private constant GRACE_PERIOD = 14 days;

    // Multi-layer security constants
    uint256 private constant MAX_SECURITY_LAYERS = 5;
    uint256 private constant MAX_PROPOSALS_PER_BLOCK = 10;
    uint256 private constant MAX_PENDING_PROPOSALS = 100;
    uint256 private constant PROPOSAL_EXPIRY = 30 days;
    uint256 private constant BATCH_SIZE_LIMIT = 20;

    // Quantum resistance constants
    uint256 private constant QUANTUM_SIGNATURE_SIZE = 3293;
    uint256 private constant QUANTUM_PROOF_SIZE = 1024;
    uint256 private constant QUANTUM_ENTROPY_THRESHOLD = 256;

    // ============ Structures ============

    struct TimelockProposal {
        bytes32 id;
        address target;
        uint256 value;
        bytes data;
        bytes32 predecessor;
        bytes32 salt;
        uint256 delay;
        uint256 scheduledAt;
        uint256 readyAt;
        uint256 executedAt;
        uint256 cancelledAt;
        address proposer;
        ProposalStatus status;
        ProposalType proposalType;
        SecurityLevel securityLevel;
        uint256 confirmations;
        uint256 requiredConfirmations;
        bytes32 dataHash;
        bool isQuantumResistant;
        bytes32 quantumProof;
    }

    struct SecurityLayer {
        uint256 layerId;
        string name;
        uint256 delay;
        uint256 minDelay;
        uint256 maxDelay;
        uint256 priority;
        bool isActive;
        bool isQuantumResistant;
        bytes32 configHash;
        address[] guardians;
        uint256 guardiansThreshold;
        mapping(address => bool) hasConfirmed;
        uint256 confirmationCount;
    }

    struct EmergencyOverride {
        bytes32 proposalId;
        address guardian;
        uint256 timestamp;
        string reason;
        EmergencyLevel level;
        bool isActive;
        bytes32 signature;
        uint256 expiry;
    }

    struct DelayConfiguration {
        uint256 baseDelay;
        uint256 emergencyDelay;
        uint256 criticalDelay;
        uint256 quantumDelay;
        uint256 graceDelay;
        mapping(ProposalType => uint256) typeDelays;
        mapping(SecurityLevel => uint256) levelDelays;
        mapping(address => uint256) targetDelays;
        mapping(bytes4 => uint256) functionDelays;
    }

    struct BatchProposal {
        bytes32 batchId;
        bytes32[] proposalIds;
        uint256 scheduledAt;
        uint256 readyAt;
        BatchStatus status;
        address proposer;
        bool isAtomic;
        uint256 executedCount;
        uint256 failedCount;
    }

    struct QuantumTimelockData {
        bytes32 keyId;
        bytes quantumSignature;
        bytes quantumProof;
        uint256 entropyLevel;
        uint256 timestamp;
        bool isVerified;
        address signer;
    }

    struct SecurityMetrics {
        uint256 totalProposals;
        uint256 executedProposals;
        uint256 cancelledProposals;
        uint256 failedProposals;
        uint256 emergencyOverrides;
        uint256 quantumThreats;
        uint256 securityBreaches;
        uint256 averageDelay;
        uint256 lastSecurityAudit;
        uint256 threatLevel;
    }

    struct AuditLog {
        uint256 id;
        bytes32 proposalId;
        address actor;
        bytes32 action;
        uint256 timestamp;
        bytes32 dataHash;
        SecurityLevel securityLevel;
        string details;
        bool isQuantumSigned;
    }

    struct GuardianVote {
        address guardian;
        bool vote;
        uint256 timestamp;
        bytes32 reason;
        bytes signature;
        uint256 weight;
    }

    // ============ Enums ============

    enum ProposalStatus {
        PENDING,
        SCHEDULED,
        READY,
        EXECUTED,
        CANCELLED,
        EXPIRED,
        FAILED
    }

    enum ProposalType {
        STANDARD,
        EMERGENCY,
        CRITICAL,
        ADMINISTRATIVE,
        SECURITY_UPDATE,
        QUANTUM_RESISTANT,
        BATCH_EXECUTION
    }

    enum SecurityLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL,
        MAXIMUM
    }

    enum EmergencyLevel {
        MINOR,
        MODERATE,
        MAJOR,
        CRITICAL,
        CATASTROPHIC
    }

    enum BatchStatus {
        PENDING,
        SCHEDULED,
        EXECUTING,
        COMPLETED,
        FAILED,
        CANCELLED
    }

    // ============ State Variables ============

    mapping(bytes32 => TimelockProposal) public proposals;
    mapping(bytes32 => BatchProposal) public batches;
    mapping(uint256 => SecurityLayer) public securityLayers;
    mapping(bytes32 => EmergencyOverride) public emergencyOverrides;
    mapping(bytes32 => QuantumTimelockData) public quantumTimelocks;
    mapping(uint256 => AuditLog) public auditLogs;
    mapping(bytes32 => mapping(address => GuardianVote)) public guardianVotes;

    mapping(address => uint256) public proposalCount;
    mapping(address => uint256) public executionCount;
    mapping(address => uint256) public lastProposalTime;
    mapping(bytes32 => uint256) public proposalSecurityScore;
    mapping(address => bool) public emergencyGuardians;
    mapping(address => uint256) public guardianPowers;

    bytes32[] public proposalQueue;
    bytes32[] public executionQueue;
    uint256 public totalSecurityLayers;
    uint256 public totalAuditLogs;
    uint256 public globalSecurityLevel;

    DelayConfiguration public delayConfig;
    SecurityMetrics public securityMetrics;

    bool public quantumResistanceEnabled;
    bool public emergencyModeActive;
    bool public batchExecutionEnabled;
    bool public advancedSecurityEnabled;
    bool public auditingEnabled;

    uint256 public minimumDelay;
    uint256 public maximumDelay;
    uint256 public emergencyDelay;
    uint256 public gracePeriod;

    bytes32 public globalNonce;
    bytes32 public quantumEntropy;
    uint256 public lastQuantumUpdate;

    // ============ Events ============

    event ProposalScheduled(
        bytes32 indexed proposalId,
        address indexed target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay,
        uint256 scheduledAt,
        uint256 readyAt
    );

    event ProposalExecuted(
        bytes32 indexed proposalId,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executedAt,
        bool success
    );

    event ProposalCancelled(
        bytes32 indexed proposalId,
        address indexed canceller,
        uint256 cancelledAt,
        string reason
    );

    event SecurityLayerAdded(
        uint256 indexed layerId,
        string name,
        uint256 delay,
        uint256 priority,
        bool isQuantumResistant
    );

    event SecurityLayerUpdated(
        uint256 indexed layerId,
        uint256 newDelay,
        uint256 newPriority,
        bool isActive
    );

    event EmergencyOverrideActivated(
        bytes32 indexed proposalId,
        address indexed guardian,
        EmergencyLevel level,
        string reason,
        uint256 timestamp
    );

    event EmergencyOverrideDeactivated(
        bytes32 indexed proposalId,
        address indexed guardian,
        uint256 timestamp
    );

    event BatchProposalScheduled(
        bytes32 indexed batchId,
        bytes32[] proposalIds,
        uint256 scheduledAt,
        address indexed proposer,
        bool isAtomic
    );

    event BatchProposalExecuted(
        bytes32 indexed batchId,
        uint256 executedCount,
        uint256 failedCount,
        uint256 timestamp
    );

    event QuantumTimelockCreated(
        bytes32 indexed keyId,
        bytes32 indexed proposalId,
        uint256 entropyLevel,
        address signer
    );

    event SecurityMetricsUpdated(
        uint256 totalProposals,
        uint256 executedProposals,
        uint256 threatLevel,
        uint256 timestamp
    );

    event AuditLogCreated(
        uint256 indexed logId,
        bytes32 indexed proposalId,
        address indexed actor,
        bytes32 action,
        uint256 timestamp
    );

    event GuardianVoteCast(
        bytes32 indexed proposalId,
        address indexed guardian,
        bool vote,
        uint256 weight,
        bytes32 reason
    );

    // ============ Modifiers ============

    modifier onlyTimelockAdmin() {
        require(hasRole(TIMELOCK_ADMIN_ROLE, msg.sender), "Not timelock admin");
        _;
    }

    modifier onlyProposer() {
        require(hasRole(TIMELOCK_PROPOSER_ROLE, msg.sender), "Not proposer");
        _;
    }

    modifier onlyExecutor() {
        require(hasRole(TIMELOCK_EXECUTOR_ROLE, msg.sender), "Not executor");
        _;
    }

    modifier onlyCanceller() {
        require(hasRole(TIMELOCK_CANCELLER_ROLE, msg.sender), "Not canceller");
        _;
    }

    modifier onlyEmergencyGuardian() {
        require(hasRole(EMERGENCY_GUARDIAN_ROLE, msg.sender), "Not emergency guardian");
        _;
    }

    modifier onlyQuantumTimelock() {
        require(hasRole(QUANTUM_TIMELOCK_ROLE, msg.sender), "Not quantum timelock");
        _;
    }

    modifier onlySecurityCouncil() {
        require(hasRole(SECURITY_COUNCIL_ROLE, msg.sender), "Not security council");
        _;
    }

    modifier validProposal(bytes32 proposalId) {
        require(proposals[proposalId].scheduledAt != 0, "Proposal not found");
        _;
    }

    modifier readyForExecution(bytes32 proposalId) {
        require(proposals[proposalId].status == ProposalStatus.READY, "Proposal not ready");
        require(block.timestamp >= proposals[proposalId].readyAt, "Proposal not ready for execution");
        require(block.timestamp <= proposals[proposalId].readyAt + gracePeriod, "Proposal expired");
        _;
    }

    modifier emergencyMode() {
        require(emergencyModeActive, "Emergency mode not active");
        _;
    }

    modifier nonEmergencyMode() {
        require(!emergencyModeActive, "Emergency mode active");
        _;
    }

    modifier quantumSecure() {
        if (quantumResistanceEnabled) {
            require(securityMetrics.quantumThreats < 5, "Quantum threat level too high");
        }
        _;
    }

    modifier rateLimited() {
        require(
            block.timestamp >= lastProposalTime[msg.sender] + 1 minutes,
            "Rate limited"
        );
        _;
    }

    modifier securityLevelCheck(SecurityLevel required) {
        require(uint256(required) <= globalSecurityLevel, "Insufficient security level");
        _;
    }

    // ============ Constructor ============

    constructor(
        uint256 _minimumDelay,
        address[] memory _proposers,
        address[] memory _executors,
        address[] memory _cancellers,
        address[] memory _emergencyGuardians
    ) EIP712("AdvancedTimelockSecurity", "1") {
        require(_minimumDelay >= MIN_DELAY, "Minimum delay too low");
        require(_minimumDelay <= MAX_DELAY, "Minimum delay too high");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TIMELOCK_ADMIN_ROLE, msg.sender);
        _grantRole(SECURITY_COUNCIL_ROLE, msg.sender);
        _grantRole(QUANTUM_TIMELOCK_ROLE, msg.sender);

        // Grant roles to initial members
        for (uint256 i = 0; i < _proposers.length; i++) {
            _grantRole(TIMELOCK_PROPOSER_ROLE, _proposers[i]);
        }

        for (uint256 i = 0; i < _executors.length; i++) {
            _grantRole(TIMELOCK_EXECUTOR_ROLE, _executors[i]);
        }

        for (uint256 i = 0; i < _cancellers.length; i++) {
            _grantRole(TIMELOCK_CANCELLER_ROLE, _cancellers[i]);
        }

        for (uint256 i = 0; i < _emergencyGuardians.length; i++) {
            _grantRole(EMERGENCY_GUARDIAN_ROLE, _emergencyGuardians[i]);
            emergencyGuardians[_emergencyGuardians[i]] = true;
            guardianPowers[_emergencyGuardians[i]] = 1;
        }

        minimumDelay = _minimumDelay;
        maximumDelay = MAX_DELAY;
        emergencyDelay = EMERGENCY_DELAY;
        gracePeriod = GRACE_PERIOD;

        // Initialize delay configuration
        delayConfig.baseDelay = _minimumDelay;
        delayConfig.emergencyDelay = EMERGENCY_DELAY;
        delayConfig.criticalDelay = CRITICAL_DELAY;
        delayConfig.quantumDelay = QUANTUM_DELAY;
        delayConfig.graceDelay = GRACE_PERIOD;

        // Initialize security metrics
        securityMetrics.totalProposals = 0;
        securityMetrics.executedProposals = 0;
        securityMetrics.cancelledProposals = 0;
        securityMetrics.failedProposals = 0;
        securityMetrics.emergencyOverrides = 0;
        securityMetrics.quantumThreats = 0;
        securityMetrics.securityBreaches = 0;
        securityMetrics.averageDelay = _minimumDelay;
        securityMetrics.lastSecurityAudit = block.timestamp;
        securityMetrics.threatLevel = 1;

        globalSecurityLevel = 3;
        quantumResistanceEnabled = true;
        emergencyModeActive = false;
        batchExecutionEnabled = true;
        advancedSecurityEnabled = true;
        auditingEnabled = true;

        globalNonce = keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender));
        quantumEntropy = keccak256(abi.encodePacked(globalNonce, block.number));
        lastQuantumUpdate = block.timestamp;

        // Initialize default security layers
        _createSecurityLayer("Base Security", _minimumDelay, 1, true, false);
        _createSecurityLayer("Emergency Override", EMERGENCY_DELAY, 2, true, false);
        _createSecurityLayer("Critical Security", CRITICAL_DELAY, 3, true, false);
        _createSecurityLayer("Quantum Resistance", QUANTUM_DELAY, 4, true, true);
        _createSecurityLayer("Maximum Security", MAX_DELAY, 5, true, true);
    }

    // ============ Proposal Management ============

    /**
     * @dev Schedules a proposal for execution
     * @param target The target contract address
     * @param value The amount of ETH to send
     * @param data The call data
     * @param predecessor The predecessor proposal ID
     * @param salt The salt for unique proposal ID
     * @param delay The delay before execution
     * @param proposalType The type of proposal
     * @param securityLevel The required security level
     */
    function scheduleProposal(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay,
        ProposalType proposalType,
        SecurityLevel securityLevel
    ) external onlyProposer nonEmergencyMode rateLimited quantumSecure
      securityLevelCheck(securityLevel) returns (bytes32) {

        require(target != address(0), "Invalid target");
        require(delay >= minimumDelay, "Delay too low");
        require(delay <= maximumDelay, "Delay too high");
        require(proposalQueue.length < MAX_PENDING_PROPOSALS, "Too many pending proposals");

        // Calculate effective delay based on proposal type and security level
        uint256 effectiveDelay = _calculateEffectiveDelay(delay, proposalType, securityLevel);

        bytes32 proposalId = keccak256(abi.encode(
            target,
            value,
            data,
            predecessor,
            salt,
            block.timestamp,
            msg.sender
        ));

        require(proposals[proposalId].scheduledAt == 0, "Proposal already exists");

        // Check predecessor requirement
        if (predecessor != bytes32(0)) {
            require(proposals[predecessor].status == ProposalStatus.EXECUTED, "Predecessor not executed");
        }

        bytes32 dataHash = keccak256(data);
        uint256 scheduledAt = block.timestamp;
        uint256 readyAt = scheduledAt + effectiveDelay;

        proposals[proposalId] = TimelockProposal({
            id: proposalId,
            target: target,
            value: value,
            data: data,
            predecessor: predecessor,
            salt: salt,
            delay: effectiveDelay,
            scheduledAt: scheduledAt,
            readyAt: readyAt,
            executedAt: 0,
            cancelledAt: 0,
            proposer: msg.sender,
            status: ProposalStatus.SCHEDULED,
            proposalType: proposalType,
            securityLevel: securityLevel,
            confirmations: 0,
            requiredConfirmations: _getRequiredConfirmations(securityLevel),
            dataHash: dataHash,
            isQuantumResistant: quantumResistanceEnabled,
            quantumProof: bytes32(0)
        });

        proposalQueue.push(proposalId);
        proposalCount[msg.sender]++;
        lastProposalTime[msg.sender] = block.timestamp;
        securityMetrics.totalProposals++;

        // Calculate security score
        proposalSecurityScore[proposalId] = _calculateSecurityScore(
            proposalType,
            securityLevel,
            effectiveDelay,
            msg.sender
        );

        _createAuditLog(
            proposalId,
            msg.sender,
            keccak256("PROPOSAL_SCHEDULED"),
            dataHash,
            securityLevel,
            "Proposal scheduled for execution",
            false
        );

        emit ProposalScheduled(
            proposalId,
            target,
            value,
            data,
            predecessor,
            effectiveDelay,
            scheduledAt,
            readyAt
        );

        return proposalId;
    }

    /**
     * @dev Executes a ready proposal
     * @param proposalId The proposal ID to execute
     */
    function executeProposal(bytes32 proposalId)
        external onlyExecutor validProposal(proposalId) readyForExecution(proposalId)
        nonReentrant quantumSecure returns (bool) {

        TimelockProposal storage proposal = proposals[proposalId];

        // Check if proposal has required confirmations
        require(
            proposal.confirmations >= proposal.requiredConfirmations,
            "Insufficient confirmations"
        );

        // Check quantum resistance if enabled
        if (quantumResistanceEnabled && proposal.isQuantumResistant) {
            require(proposal.quantumProof != bytes32(0), "Quantum proof required");
        }

        proposal.status = ProposalStatus.EXECUTED;
        proposal.executedAt = block.timestamp;

        bool success = false;
        bytes memory returnData;

        // Execute the proposal
        if (proposal.value > 0) {
            (success, returnData) = proposal.target.call{value: proposal.value}(proposal.data);
        } else {
            (success, returnData) = proposal.target.call(proposal.data);
        }

        if (success) {
            securityMetrics.executedProposals++;
            executionCount[msg.sender]++;
        } else {
            securityMetrics.failedProposals++;
            proposal.status = ProposalStatus.FAILED;
        }

        // Update security metrics
        _updateSecurityMetrics();

        _createAuditLog(
            proposalId,
            msg.sender,
            keccak256("PROPOSAL_EXECUTED"),
            proposal.dataHash,
            proposal.securityLevel,
            success ? "Proposal executed successfully" : "Proposal execution failed",
            proposal.isQuantumResistant
        );

        emit ProposalExecuted(
            proposalId,
            proposal.target,
            proposal.value,
            proposal.data,
            proposal.executedAt,
            success
        );

        return success;
    }

    /**
     * @dev Cancels a pending proposal
     * @param proposalId The proposal ID to cancel
     * @param reason The reason for cancellation
     */
    function cancelProposal(bytes32 proposalId, string memory reason)
        external onlyCanceller validProposal(proposalId) {

        TimelockProposal storage proposal = proposals[proposalId];

        require(
            proposal.status == ProposalStatus.SCHEDULED ||
            proposal.status == ProposalStatus.READY,
            "Cannot cancel proposal"
        );

        proposal.status = ProposalStatus.CANCELLED;
        proposal.cancelledAt = block.timestamp;
        securityMetrics.cancelledProposals++;

        _createAuditLog(
            proposalId,
            msg.sender,
            keccak256("PROPOSAL_CANCELLED"),
            proposal.dataHash,
            proposal.securityLevel,
            reason,
            proposal.isQuantumResistant
        );

        emit ProposalCancelled(proposalId, msg.sender, proposal.cancelledAt, reason);
    }

    // ============ Security Layer Management ============

    /**
     * @dev Creates a new security layer
     * @param name The name of the security layer
     * @param delay The delay for this layer
     * @param priority The priority level
     * @param isActive Whether the layer is active
     * @param isQuantumResistant Whether quantum resistance is required
     */
    function createSecurityLayer(
        string memory name,
        uint256 delay,
        uint256 priority,
        bool isActive,
        bool isQuantumResistant
    ) external onlyTimelockAdmin returns (uint256) {
        return _createSecurityLayer(name, delay, priority, isActive, isQuantumResistant);
    }

    /**
     * @dev Updates an existing security layer
     * @param layerId The ID of the security layer
     * @param newDelay The new delay value
     * @param newPriority The new priority level
     * @param isActive Whether the layer is active
     */
    function updateSecurityLayer(
        uint256 layerId,
        uint256 newDelay,
        uint256 newPriority,
        bool isActive
    ) external onlyTimelockAdmin {
        require(layerId < totalSecurityLayers, "Invalid layer ID");
        require(newDelay >= MIN_DELAY && newDelay <= MAX_DELAY, "Invalid delay");

        SecurityLayer storage layer = securityLayers[layerId];
        layer.delay = newDelay;
        layer.priority = newPriority;
        layer.isActive = isActive;
        layer.configHash = keccak256(abi.encodePacked(newDelay, newPriority, isActive));

        emit SecurityLayerUpdated(layerId, newDelay, newPriority, isActive);
    }

    // ============ Emergency Functions ============

    /**
     * @dev Activates emergency override for a proposal
     * @param proposalId The proposal ID
     * @param level The emergency level
     * @param reason The reason for emergency override
     */
    function activateEmergencyOverride(
        bytes32 proposalId,
        EmergencyLevel level,
        string memory reason
    ) external onlyEmergencyGuardian validProposal(proposalId) {

        bytes32 overrideId = keccak256(abi.encodePacked(proposalId, msg.sender, block.timestamp));

        emergencyOverrides[overrideId] = EmergencyOverride({
            proposalId: proposalId,
            guardian: msg.sender,
            timestamp: block.timestamp,
            reason: reason,
            level: level,
            isActive: true,
            signature: keccak256(abi.encodePacked(proposalId, reason, level)),
            expiry: block.timestamp + 24 hours
        });

        securityMetrics.emergencyOverrides++;

        // Update proposal ready time based on emergency level
        TimelockProposal storage proposal = proposals[proposalId];
        if (level == EmergencyLevel.CATASTROPHIC) {
            proposal.readyAt = block.timestamp + emergencyDelay;
        } else if (level == EmergencyLevel.CRITICAL) {
            proposal.readyAt = block.timestamp + (emergencyDelay * 2);
        }

        emit EmergencyOverrideActivated(proposalId, msg.sender, level, reason, block.timestamp);
    }

    /**
     * @dev Deactivates emergency override
     * @param overrideId The override ID
     */
    function deactivateEmergencyOverride(bytes32 overrideId) external onlyEmergencyGuardian {
        require(emergencyOverrides[overrideId].isActive, "Override not active");
        require(emergencyOverrides[overrideId].guardian == msg.sender, "Not override creator");

        emergencyOverrides[overrideId].isActive = false;

        emit EmergencyOverrideDeactivated(
            emergencyOverrides[overrideId].proposalId,
            msg.sender,
            block.timestamp
        );
    }

    // ============ Batch Execution ============

    /**
     * @dev Schedules a batch of proposals for execution
     * @param proposalIds The array of proposal IDs
     * @param delay The delay before batch execution
     * @param isAtomic Whether batch execution is atomic
     */
    function scheduleBatchProposal(
        bytes32[] memory proposalIds,
        uint256 delay,
        bool isAtomic
    ) external onlyProposer returns (bytes32) {
        require(batchExecutionEnabled, "Batch execution disabled");
        require(proposalIds.length > 0, "Empty batch");
        require(proposalIds.length <= BATCH_SIZE_LIMIT, "Batch too large");
        require(delay >= minimumDelay, "Delay too low");

        bytes32 batchId = keccak256(abi.encodePacked(
            proposalIds,
            delay,
            isAtomic,
            block.timestamp,
            msg.sender
        ));

        batches[batchId] = BatchProposal({
            batchId: batchId,
            proposalIds: proposalIds,
            scheduledAt: block.timestamp,
            readyAt: block.timestamp + delay,
            status: BatchStatus.SCHEDULED,
            proposer: msg.sender,
            isAtomic: isAtomic,
            executedCount: 0,
            failedCount: 0
        });

        emit BatchProposalScheduled(batchId, proposalIds, block.timestamp, msg.sender, isAtomic);
        return batchId;
    }

    /**
     * @dev Executes a batch proposal
     * @param batchId The batch ID to execute
     */
    function executeBatchProposal(bytes32 batchId) external onlyExecutor nonReentrant {
        BatchProposal storage batch = batches[batchId];

        require(batch.status == BatchStatus.SCHEDULED, "Batch not scheduled");
        require(block.timestamp >= batch.readyAt, "Batch not ready");

        batch.status = BatchStatus.EXECUTING;

        for (uint256 i = 0; i < batch.proposalIds.length; i++) {
            bytes32 proposalId = batch.proposalIds[i];
            TimelockProposal storage proposal = proposals[proposalId];

            if (proposal.status == ProposalStatus.READY &&
                block.timestamp >= proposal.readyAt) {

                proposal.status = ProposalStatus.EXECUTED;
                proposal.executedAt = block.timestamp;

                bool success = false;
                if (proposal.value > 0) {
                    (success, ) = proposal.target.call{value: proposal.value}(proposal.data);
                } else {
                    (success, ) = proposal.target.call(proposal.data);
                }

                if (success) {
                    batch.executedCount++;
                } else {
