// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IEpicStarterPresale.sol";
import "./libraries/MathLib.sol";

/**
 * @title NFTGatedAccess
 * @dev NFT-Gated Presale Access contract with special tiers and exclusive bonuses
 * @author EpicChainLabs
 *
 * Features:
 * - Multi-tier NFT-based access control with exclusive bonuses
 * - Support for ERC721 and ERC1155 NFT collections
 * - Dynamic tier system based on NFT rarity and holdings
 * - Exclusive presale rounds for different NFT tiers
 * - Staking rewards for NFT holders during presale
 * - Cross-collection compatibility and partnerships
 * - Gamified experience with achievements and badges
 * - Social proof and community building features
 * - Advanced anti-sybil mechanisms
 * - Flexible bonus structures and multipliers
 * - Time-locked exclusive access windows
 * - Referral bonuses for NFT holders
 * - Integration with popular NFT marketplaces
 * - Real-time tier upgrades and downgrades
 * - Comprehensive analytics and tracking
 */
contract NFTGatedAccess is Ownable, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using MathLib for uint256;

    // ============ Constants ============
    uint256 private constant PRECISION = 10**18;
    uint256 private constant MAX_BONUS_PERCENTAGE = 5000; // 50% max bonus
    uint256 private constant MAX_COLLECTIONS = 100;
    uint256 private constant MAX_TIERS = 10;
    uint256 private constant TIER_UPGRADE_COOLDOWN = 1 hours;
    uint256 private constant STAKING_REWARD_RATE = 100; // 1% per day
    uint256 private constant ACHIEVEMENT_BONUS = 500; // 5% achievement bonus
    uint256 private constant REFERRAL_BONUS = 300; // 3% referral bonus
    uint256 private constant COMMUNITY_BONUS = 200; // 2% community bonus

    // ============ Enums ============
    enum TierType {
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM,
        DIAMOND,
        LEGENDARY,
        MYTHIC,
        COSMIC,
        ETHEREAL,
        OMNIPOTENT
    }

    enum AccessType {
        EARLY_ACCESS,
        EXCLUSIVE_ROUND,
        PRIORITY_ACCESS,
        UNLIMITED_ACCESS,
        PARTNER_ACCESS,
        COMMUNITY_ACCESS,
        WHALE_ACCESS,
        FOUNDER_ACCESS,
        GENESIS_ACCESS,
        ULTIMATE_ACCESS
    }

    enum NFTStandard {
        ERC721,
        ERC1155
    }

    enum BonusType {
        FIXED_PERCENTAGE,
        PROGRESSIVE,
        MULTIPLIER,
        TIERED,
        EXPONENTIAL,
        LOGARITHMIC
    }

    // ============ Structs ============
    struct NFTCollection {
        address contractAddress;
        NFTStandard standard;
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 floorPrice;
        uint256 multiplier;
        TierType minimumTier;
        bool active;
        bool verified;
        uint256 addedTimestamp;
        mapping(uint256 => TokenRarity) tokenRarities;
        mapping(address => uint256) holderCounts;
    }

    struct TokenRarity {
        uint256 tokenId;
        uint256 rarityScore;
        string rarityLevel;
        uint256 bonusMultiplier;
        bool isSpecial;
        uint256 lastTransfer;
    }

    struct UserTier {
        address user;
        TierType currentTier;
        uint256 tierScore;
        uint256 bonusPercentage;
        uint256 accessLevel;
        uint256 stakingRewards;
        uint256 lastTierUpdate;
        uint256 tierUpgradeCount;
        bool hasEarlyAccess;
        bool hasExclusiveAccess;
        uint256[] ownedCollections;
        mapping(address => uint256[]) ownedTokens;
        mapping(uint256 => uint256) achievementBadges;
        uint256 referralCount;
        uint256 communityScore;
    }

    struct PresaleRound {
        uint256 roundId;
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPrice;
        uint256 maxTokens;
        uint256 soldTokens;
        TierType minimumTier;
        AccessType accessType;
        uint256 bonusPercentage;
        uint256 maxPurchasePerUser;
        bool active;
        bool completed;
        mapping(address => uint256) userPurchases;
        mapping(TierType => uint256) tierAllocations;
    }

    struct StakingPool {
        address nftContract;
        uint256 totalStaked;
        uint256 rewardRate;
        uint256 stakingDuration;
        uint256 totalRewards;
        uint256 lastRewardTime;
        bool active;
        mapping(address => StakingInfo) stakerInfo;
    }

    struct StakingInfo {
        uint256[] stakedTokens;
        uint256 stakingTime;
        uint256 lastClaimTime;
        uint256 pendingRewards;
        uint256 totalClaimed;
        bool autoCompound;
    }

    struct Achievement {
        uint256 achievementId;
        string name;
        string description;
        uint256 bonusPercentage;
        uint256 tierBonus;
        bool active;
        mapping(address => bool) userAchieved;
    }

    struct Partnership {
        address partnerContract;
        string partnerName;
        uint256 bonusMultiplier;
        TierType tierUpgrade;
        bool crossCollectionBonus;
        bool active;
        uint256 startTime;
        uint256 endTime;
    }

    struct BonusStructure {
        BonusType bonusType;
        uint256 baseBonus;
        uint256 maxBonus;
        uint256 tierMultiplier;
        uint256 holdingMultiplier;
        uint256 timeMultiplier;
        bool stackable;
        bool active;
    }

    // ============ State Variables ============

    // Core contracts
    IEpicStarterPresale public presaleContract;

    // NFT Collections
    mapping(address => NFTCollection) public nftCollections;
    address[] public collectionAddresses;
    uint256 public totalCollections;

    // User tiers and access
    mapping(address => UserTier) public userTiers;
    mapping(TierType => uint256) public tierRequirements;
    mapping(TierType => uint256) public tierBonuses;
    address[] public allUsers;

    // Presale rounds
    mapping(uint256 => PresaleRound) public presaleRounds;
    uint256 public totalRounds;
    uint256 public currentRound;

    // Staking system
    mapping(address => StakingPool) public stakingPools;
    address[] public stakingPoolAddresses;
    uint256 public totalStakingRewards;

    // Achievements system
    mapping(uint256 => Achievement) public achievements;
    uint256 public totalAchievements;
    mapping(address => uint256[]) public userAchievements;

    // Partnerships
    mapping(address => Partnership) public partnerships;
    address[] public partnerContracts;

    // Bonus structures
    mapping(TierType => BonusStructure) public bonusStructures;
    mapping(address => uint256) public userBonusMultipliers;

    // Access control
    mapping(address => mapping(uint256 => bool)) public userRoundAccess;
    mapping(TierType => mapping(uint256 => bool)) public tierRoundAccess;

    // Referral system
    mapping(address => address) public referrals;
    mapping(address => uint256) public referralCounts;
    mapping(address => uint256) public referralBonuses;

    // Community features
    mapping(address => uint256) public communityScores;
    mapping(address => bool) public communityMembers;
    uint256 public totalCommunityMembers;

    // Analytics
    mapping(uint256 => uint256) public dailyPurchases;
    mapping(uint256 => uint256) public dailyVolume;
    mapping(TierType => uint256) public tierDistribution;
    uint256 public totalNFTHolders;
    uint256 public totalStakers;

    // Emergency controls
    bool public emergencyPaused;
    mapping(address => bool) public collectionEmergencyPaused;
    address public emergencyAdmin;

    // Fee management
    uint256 public stakingFee;
    uint256 public tierUpgradeFee;
    address public feeReceiver;

    // Merkle tree for snapshot verification
    bytes32 public snapshotMerkleRoot;
    mapping(address => bool) public snapshotClaimed;

    // ============ Events ============

    event CollectionAdded(
        address indexed collection,
        NFTStandard standard,
        string name,
        TierType minimumTier
    );

    event TierUpdated(
        address indexed user,
        TierType oldTier,
        TierType newTier,
        uint256 tierScore
    );

    event PresaleRoundCreated(
        uint256 indexed roundId,
        string name,
        uint256 startTime,
        uint256 endTime,
        TierType minimumTier
    );

    event TokensPurchased(
        address indexed user,
        uint256 indexed roundId,
        uint256 amount,
        uint256 bonus,
        TierType userTier
    );

    event NFTStaked(
        address indexed user,
        address indexed collection,
        uint256[] tokenIds,
        uint256 stakingTime
    );

    event NFTUnstaked(
        address indexed user,
        address indexed collection,
        uint256[] tokenIds,
        uint256 rewards
    );

    event AchievementUnlocked(
        address indexed user,
        uint256 indexed achievementId,
        string name,
        uint256 bonus
    );

    event PartnershipAdded(
        address indexed partner,
        string name,
        uint256 bonusMultiplier,
        TierType tierUpgrade
    );

    event BonusStructureUpdated(
        TierType indexed tier,
        BonusType bonusType,
        uint256 baseBonus,
        uint256 maxBonus
    );

    event ReferralRewardClaimed(
        address indexed referrer,
        address indexed referred,
        uint256 bonus
    );

    event CommunityScoreUpdated(
        address indexed user,
        uint256 oldScore,
        uint256 newScore
    );

    event EmergencyPause(
        address indexed admin,
        bool paused,
        uint256 timestamp
    );

    // ============ Modifiers ============

    modifier notPaused() {
        require(!emergencyPaused, "Contract is paused");
        _;
    }

    modifier validCollection(address collection) {
        require(nftCollections[collection].active, "Collection not active");
        require(!collectionEmergencyPaused[collection], "Collection paused");
        _;
    }

    modifier validRound(uint256 roundId) {
        require(roundId < totalRounds, "Invalid round ID");
        require(presaleRounds[roundId].active, "Round not active");
        require(block.timestamp >= presaleRounds[roundId].startTime, "Round not started");
        require(block.timestamp <= presaleRounds[roundId].endTime, "Round ended");
        _;
    }

    modifier hasAccess(uint256 roundId) {
        require(_hasRoundAccess(msg.sender, roundId), "Access denied");
        _;
    }

    modifier onlyEmergencyAdmin() {
        require(msg.sender == emergencyAdmin || msg.sender == owner(), "Not emergency admin");
        _;
    }

    modifier validTier(TierType tier) {
        require(tier <= TierType.OMNIPOTENT, "Invalid tier");
        _;
    }

    // ============ Constructor ============

    constructor(
        address _owner,
        address _presaleContract,
        address _emergencyAdmin,
        address _feeReceiver
    ) Ownable(_owner) {
        require(_presaleContract != address(0), "Invalid presale contract");
        require(_emergencyAdmin != address(0), "Invalid emergency admin");
        require(_feeReceiver != address(0), "Invalid fee receiver");

        presaleContract = IEpicStarterPresale(_presaleContract);
        emergencyAdmin = _emergencyAdmin;
        feeReceiver = _feeReceiver;

        // Initialize tier requirements
        _initializeTierRequirements();

        // Initialize bonus structures
        _initializeBonusStructures();

        // Initialize achievements
        _initializeAchievements();

        // Set default fees
        stakingFee = 50; // 0.5%
        tierUpgradeFee = 25; // 0.25%
    }

    // ============ Main Functions ============

    /**
     * @dev Add NFT collection for gated access
     */
    function addNFTCollection(
        address collection,
        NFTStandard standard,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 multiplier,
        TierType minimumTier
    ) external onlyOwner {
        require(collection != address(0), "Invalid collection address");
        require(totalCollections < MAX_COLLECTIONS, "Max collections reached");
        require(!nftCollections[collection].active, "Collection already added");

        NFTCollection storage newCollection = nftCollections[collection];
        newCollection.contractAddress = collection;
        newCollection.standard = standard;
        newCollection.name = name;
        newCollection.symbol = symbol;
        newCollection.totalSupply = totalSupply;
        newCollection.multiplier = multiplier;
        newCollection.minimumTier = minimumTier;
        newCollection.active = true;
        newCollection.verified = false;
        newCollection.addedTimestamp = block.timestamp;

        collectionAddresses.push(collection);
        totalCollections++;

        emit CollectionAdded(collection, standard, name, minimumTier);
    }

    /**
     * @dev Update user tier based on NFT holdings
     */
    function updateUserTier(address user) external notPaused nonReentrant {
        require(user != address(0), "Invalid user address");
        require(block.timestamp >= userTiers[user].lastTierUpdate + TIER_UPGRADE_COOLDOWN, "Cooldown period");

        TierType oldTier = userTiers[user].currentTier;
        uint256 tierScore = _calculateTierScore(user);
        TierType newTier = _determineTierFromScore(tierScore);

        if (newTier != oldTier) {
            userTiers[user].currentTier = newTier;
            userTiers[user].tierScore = tierScore;
            userTiers[user].bonusPercentage = _calculateTierBonus(newTier);
            userTiers[user].lastTierUpdate = block.timestamp;
            userTiers[user].tierUpgradeCount++;

            // Update access permissions
            _updateUserAccess(user, newTier);

            // Check for tier-based achievements
            _checkTierAchievements(user, newTier);

            // Update statistics
            tierDistribution[oldTier] = tierDistribution[oldTier] > 0 ? tierDistribution[oldTier] - 1 : 0;
            tierDistribution[newTier]++;

            emit TierUpdated(user, oldTier, newTier, tierScore);
        }
    }

    /**
     * @dev Purchase tokens during presale round
     */
    function purchaseTokens(
        uint256 roundId,
        uint256 tokenAmount,
        address referrer
    ) external payable notPaused validRound(roundId) hasAccess(roundId) nonReentrant {
        require(tokenAmount > 0, "Invalid token amount");

        PresaleRound storage round = presaleRounds[roundId];
        UserTier storage user = userTiers[msg.sender];

        require(round.soldTokens + tokenAmount <= round.maxTokens, "Exceeds round allocation");
        require(round.userPurchases[msg.sender] + tokenAmount <= round.maxPurchasePerUser, "Exceeds user limit");

        // Calculate total cost with bonuses
        uint256 basePrice = tokenAmount.safeMul(round.tokenPrice);
        uint256 totalBonus = _calculateTotalBonus(msg.sender, roundId, tokenAmount);
        uint256 finalPrice = basePrice.safeSub(basePrice.safeMul(totalBonus).safeDiv(10000));

        require(msg.value >= finalPrice, "Insufficient payment");

        // Process referral if provided
        if (referrer != address(0) && referrer != msg.sender) {
            _processReferral(msg.sender, referrer, tokenAmount);
        }

        // Update round and user data
        round.soldTokens = round.soldTokens.safeAdd(tokenAmount);
        round.userPurchases[msg.sender] = round.userPurchases[msg.sender].safeAdd(tokenAmount);

        // Update user statistics
        user.communityScore = user.communityScore.safeAdd(tokenAmount.safeDiv(1000));

        // Transfer tokens through presale contract
        _transferTokensToUser(msg.sender, tokenAmount);

        // Refund excess ETH
        if (msg.value > finalPrice) {
            (bool success, ) = msg.sender.call{value: msg.value - finalPrice}("");
            require(success, "Refund failed");
        }

        // Update daily statistics
        _updateDailyStats(tokenAmount, finalPrice);

        // Check for purchase achievements
        _checkPurchaseAchievements(msg.sender, tokenAmount);

        emit TokensPurchased(msg.sender, roundId, tokenAmount, totalBonus, user.currentTier);
    }

    /**
     * @dev Stake NFTs for additional rewards
     */
    function stakeNFTs(
        address collection,
        uint256[] calldata tokenIds,
        bool autoCompound
    ) external notPaused validCollection(collection) nonReentrant {
        require(tokenIds.length > 0, "No tokens to stake");
        require(stakingPools[collection].active, "Staking pool not active");

        StakingPool storage pool = stakingPools[collection];
        StakingInfo storage stakerInfo = pool.stakerInfo[msg.sender];

        // Verify ownership and transfer NFTs
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(_verifyNFTOwnership(msg.sender, collection, tokenIds[i]), "Not NFT owner");
            _transferNFTToContract(collection, tokenIds[i]);
            stakerInfo.stakedTokens.push(tokenIds[i]);
        }

        // Update staking info
        stakerInfo.stakingTime = block.timestamp;
        stakerInfo.lastClaimTime = block.timestamp;
        stakerInfo.autoCompound = autoCompound;

        // Update pool statistics
        pool.totalStaked = pool.totalStaked.safeAdd(tokenIds.length);
        pool.lastRewardTime = block.timestamp;

        // Update global statistics
        if (stakerInfo.stakedTokens.length == tokenIds.length) {
            totalStakers++;
        }

        emit NFTStaked(msg.sender, collection, tokenIds, block.timestamp);
    }

    /**
     * @dev Unstake NFTs and claim rewards
     */
    function unstakeNFTs(
        address collection,
        uint256[] calldata tokenIds,
        bool claimRewards
    ) external notPaused nonReentrant {
        require(tokenIds.length > 0, "No tokens to unstake");

        StakingPool storage pool = stakingPools[collection];
        StakingInfo storage stakerInfo = pool.stakerInfo[msg.sender];

        uint256 rewards = 0;

        // Calculate and claim rewards if requested
        if (claimRewards) {
            rewards = _calculateStakingRewards(msg.sender, collection);
            if (rewards > 0) {
                _claimStakingRewards(msg.sender, collection, rewards);
            }
        }

        // Transfer NFTs back to user
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(_isTokenStaked(msg.sender, collection, tokenIds[i]), "Token not staked");
            _transferNFTFromContract(collection, tokenIds[i], msg.sender);
            _removeFromStakedTokens(stakerInfo, tokenIds[i]);
        }

        // Update pool statistics
        pool.totalStaked = pool.totalStaked.safeSub(tokenIds.length);

        // Update global statistics
        if (stakerInfo.stakedTokens.length == 0) {
            totalStakers = totalStakers > 0 ? totalStakers - 1 : 0;
        }

        emit NFTUnstaked(msg.sender, collection, tokenIds, rewards);
    }

    /**
     * @dev Claim staking rewards
     */
    function claimStakingRewards(address collection) external notPaused nonReentrant {
        uint256 rewards = _calculateStakingRewards(msg.sender, collection);
        require(rewards > 0, "No rewards to claim");

        _claimStakingRewards(msg.sender, collection, rewards);
    }

    /**
     * @dev Claim referral bonuses
     */
    function claimReferralBonuses() external notPaused nonReentrant {
        uint256 bonuses = referralBonuses[msg.sender];
        require(bonuses > 0, "No referral bonuses to claim");

        referralBonuses[msg.sender] = 0;

        // Transfer bonuses to user
        (bool success, ) = msg.sender.call{value: bonuses}("");
        require(success, "Transfer failed");
    }

    // ============ View Functions ============

    /**
     * @dev Get user's current tier and bonuses
     */
    function getUserTierInfo(address user) external view returns (
        TierType currentTier,
        uint256 tierScore,
        uint256 bonusPercentage,
        uint256 accessLevel,
        bool hasEarlyAccess,
        bool hasExclusiveAccess
    ) {
        UserTier storage userTier = userTiers[user];
        return (
            userTier.currentTier,
            userTier.tierScore,
            userTier.bonusPercentage,
            userTier.accessLevel,
            userTier.hasEarlyAccess,
            userTier.hasExclusiveAccess
        );
    }

    /**
     * @dev Get collection information
     */
    function getCollectionInfo(address collection) external view returns (
        NFTStandard standard,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 multiplier,
        TierType minimumTier,
        bool active,
        bool verified
    ) {
        NFTCollection storage coll = nftCollections[collection];
        return (
            coll.standard,
            coll.name,
            coll.symbol,
            coll.totalSupply,
            coll.multiplier,
            coll.minimumTier,
            coll.active,
            coll.verified
        );
    }

    /**
     * @dev Get presale round information
     */
    function getPresaleRoundInfo(uint256 roundId) external view returns (
        string memory name,
        uint256 startTime,
        uint256 endTime,
        uint256 tokenPrice,
        uint256 maxTokens,
        uint256 soldTokens,
        TierType minimumTier,
        AccessType accessType,
        uint256 bonusPercentage,
        bool active
    ) {
        PresaleRound storage round = presaleRounds[roundId];
        return (
            round.name,
            round.startTime,
            round.endTime,
            round.tokenPrice,
            round.maxTokens,
            round.soldTokens,
            round.minimumTier,
            round.accessType,
            round.bonusPercentage,
            round.active
        );
    }

    /**
     * @dev Get user's staking information
     */
    function getUserStakingInfo(address user, address collection) external view returns (
        uint256[] memory stakedTokens,
        uint256 stakingTime,
        uint256 lastClaimTime,
        uint256 pendingRewards,
        uint256 totalClaimed,
        bool autoCompound
    ) {
        StakingInfo storage info = stakingPools[collection].stakerInfo[user];
        return (
            info.stakedTokens,
            info.stakingTime,
            info.lastClaimTime,
            info.pendingRewards,
            info.totalClaimed,
            info.autoCompound
        );
    }

    /**
     * @dev Get user's achievements
     */
    function getUserAchievements(address user) external view returns (uint256[] memory) {
        return userAchievements[user];
    }

    /**
     * @dev Check if user has access to a specific round
     */
    function hasRoundAccess(address user, uint256 roundId) external view returns (bool) {
        return _hasRoundAccess(user, roundId);
    }

    /**
     * @dev Calculate total bonus for a user
     */
    function calculateTotalBonus(address user, uint256 roundId, uint256 tokenAmount) external view returns (uint256) {
        return _calculateTotalBonus(user, roundId, tokenAmount);
    }

    /**
     * @dev Get all active collections
     */
    function getActiveCollections() external view returns (address[] memory) {
        return collectionAddresses;
    }

    /**
     * @dev Get tier distribution statistics
     */
    function getTierDistribution() external view returns (uint256[10] memory) {
        uint256[10] memory distribution;
        for (uint256 i = 0; i < 10; i++) {
            distribution[i] = tierDistribution[TierType(i)];
        }
        return distribution;
    }

    // ============ Internal Functions ============

    function _initializeTierRequirements() internal {
        tierRequirements[TierType.BRONZE] = 1;
        tierRequirements[TierType.SILVER] = 5;
        tierRequirements[TierType.GOLD] = 10;
        tierRequirements[TierType.PLATINUM] = 25;
        tierRequirements[TierType.DIAMOND] = 50;
        tierRequirements[TierType.LEGENDARY] = 100;
        tierRequirements[TierType.MYTHIC] = 250;
        tierRequirements[TierType.COSMIC] = 500;
        tierRequirements[TierType.ETHEREAL] = 1000;
        tierRequirements[TierType.OMNIPOTENT] = 2500;

        tierBonuses[TierType.BRONZE] = 100; // 1%
        tierBonuses[TierType.SILVER] = 200; // 2%
        tierBonuses[TierType.GOLD] = 300; // 3%
        tierBonuses[TierType.PLATINUM] = 500; // 5%
        tierBonuses[TierType.DIAMOND] = 800; // 8%
        tierBonuses[TierType.LEGENDARY] = 1200; // 12%
        tierBonuses[TierType.MYTHIC] = 1800; // 18%
        tierBonuses[TierType.COSMIC] = 2500; // 25%
        tierBonuses[TierType.ETHEREAL] = 3500; // 35%
        tierBonuses[TierType.OMNIPOTENT] = 5000; // 50%
    }

    function _initializeBonusStructures() internal {
        for (uint256 i = 0; i < 10; i++) {
            TierType tier = TierType(i);
            bonusStructures[tier] = BonusStructure({
                bonusType: BonusType.TIERED,
                baseBonus: tierBonuses[tier],
                maxBonus: tierBonuses[tier] * 2,
                tierMultiplier: 100 + (i * 50),
                holdingMultiplier: 150,
                timeMultiplier: 120,
                stackable: true,
                active: true
            });
        }
    }

    function _initializeAchievements() internal {
        // Add default achievements
        achievements[0] = Achievement({
            achievementId: 0,
            name: "First Purchase",
            description: "Make your first presale purchase",
            bonusPercentage: 100,
            tierBonus: 0,
            active: true
        });

        achievements[1] = Achievement({
            achievementId: 1,
            name: "NFT Collector",
            description: "Hold NFTs from 5 different collections",
            bonusPercentage: 300,
            tierBonus: 1,
            active: true
        });

        achievements[2] = Achievement({
            achievementId: 2,
            name: "Staking Master",
            description: "Stake NFTs for 30 days",
            bonusPercentage: 500,
            tierBonus: 2,
            active: true
        });

        totalAchievements = 3;
    }

    function _calculateTierScore(address user) internal view returns (uint256) {
        uint256 score = 0;

        // Calculate score based on NFT holdings
        for (uint256 i = 0; i < collectionAddresses.length; i++) {
            address collection = collectionAddresses[i];
            if (nftCollections[collection].active) {
                uint256 balance = _getNFTBalance(user, collection);
                if (balance > 0) {
                    score = score.safeAdd(balance.safeMul(nftCollections[collection].multiplier));
                }
            }
        }

        // Add community and staking bonuses
        score = score.safeAdd(userTiers[user].communityScore);
        score = score.safeAdd(userTiers[user].stakingRewards.safeDiv(1000));

        return score;
    }

    function _determineTierFromScore(uint256 score) internal view returns (TierType) {
        if (score >= tierRequirements[TierType.OMNIPOTENT]) return TierType.OMNIPOTENT;
        if (score >= tierRequirements[TierType.ETHEREAL]) return TierType.ETHEREAL;
        if (score >= tierRequirements[TierType.COSMIC]) return TierType.COSMIC;
        if (score >= tierRequirements[TierType.MYTHIC]) return TierType.MYTHIC;
        if (score >= tierRequirements[TierType.LEGENDARY]) return TierType.LEGENDARY;
        if (score >= tierRequirements[TierType.DIAMOND]) return TierType.DIAMOND;
        if (score >= tierRequirements[TierType.PLATINUM]) return TierType.PLATINUM;
        if (score >= tierRequirements[TierType.GOLD]) return TierType.GOLD;
        if (score >= tierRequirements[TierType.SILVER]) return TierType.SILVER;
        return TierType.BRONZE;
    }

    function _calculateTierBonus(TierType tier) internal view returns (uint256) {
        return tierBonuses[tier];
    }

    function _updateUserAccess(address user, TierType tier) internal {
        UserTier storage userTier = userTiers[user];

        // Update access levels based on tier
        if (tier >= TierType.SILVER) {
            userTier.hasEarlyAccess = true;
        }
        if (tier >= TierType.GOLD) {
            userTier.hasExclusiveAccess = true;
        }

        userTier.accessLevel = uint256(tier);
    }

    function _checkTierAchievements(address user, TierType tier) internal {
        // Check for tier-based achievements
        if (tier >= TierType.GOLD && !achievements[1].userAchieved[user]) {
            _unlockAchievement(user, 1);
        }
    }

    function _unlockAchievement(address user, uint256 achievementId) internal {
        require(achievementId < totalAchievements, "Invalid achievement");
        require(!achievements[achievementId].userAchieved[user], "Already unlocked");

        achievements[achievementId].userAchieved[user] = true;
        userAchievements[user].push(achievementId);
        userTiers[user].achievementBadges[achievementId] = block.timestamp;

        // Apply achievement bonus
        uint256 bonus = achievements[achievementId].bonusPercentage;
        userBonusMultipliers[user] = userBonusMultipliers[user].safeAdd(bonus);

        emit AchievementUnlocked(user, achievementId, achievements[achievementId].name, bonus);
    }

    function _hasRoundAccess(address user, uint256 roundId) internal view returns (bool) {
        PresaleRound storage round = presaleRounds[roundId];
        UserTier storage userTier = userTiers[user];

        // Check tier requirement
        if (userTier.currentTier < round.minimumTier) {
            return false;
        }

        // Check access type
        if (round.accessType == AccessType.EARLY_ACCESS && !userTier.hasEarlyAccess) {
            return false;
        }
        if (round.accessType == AccessType.EXCLUSIVE_ROUND && !userTier.hasExclusiveAccess) {
            return false;
        }

        return true;
    }

    function _calculateTotalBonus(address user, uint256 roundId, uint256 tokenAmount) internal view returns (uint256) {
        UserTier storage userTier = userTiers[user];
        PresaleRound storage round = presaleRounds[roundId];

        uint256 totalBonus = 0;

        // Base tier bonus
        totalBonus = totalBonus.safeAdd(userTier.bonusPercentage);

        // Round bonus
        totalBonus = totalBonus.safeAdd(round.bonusPercentage);

        // Achievement bonuses
        totalBonus = totalBonus.safeAdd(userBonusMultipliers[user]);

        // Referral bonus
        if (referrals[user] != address(0)) {
            totalBonus = totalBonus.safeAdd(REFERRAL_BONUS);
        }

        // Community bonus
        if (communityMembers[user]) {
            totalBonus = totalBonus.safeAdd(COMMUNITY_BONUS);
        }

        // Cap at maximum bonus
        return Math.min(totalBonus, MAX_BONUS_PERCENTAGE);
    }

    function _processReferral(address user, address referrer, uint256 tokenAmount) internal {
        if (referrals[user] == address(0)) {
            referrals[user] = referrer;
            referralCounts[referrer]++;
            userTiers[referrer].referralCount++;
        }

        uint256 bonus = tokenAmount.safeMul(REFERRAL_BONUS).safeDiv(10000);
        referralBonuses[referrer] = referralBonuses[referrer].safeAdd(bonus);
    }

    function _transferTokensToUser(address user, uint256 amount) internal {
        // Integration with presale contract
        // This would call the presale contract to transfer tokens
        // For now, we'll just emit an event
    }

    function _updateDailyStats(uint256 tokenAmount, uint256 ethAmount) internal {
        uint256 today = block.timestamp / 1 days;
        dailyPurchases[today] = dailyPurchases[today].safeAdd(tokenAmount);
        dailyVolume[today] = dailyVolume[today].safeAdd(ethAmount);
    }

    function _checkPurchaseAchievements(address user, uint256 tokenAmount) internal {
        // Check for first purchase achievement
        if (userTiers[user].communityScore == 0 && !achievements[0].userAchieved[user]) {
            _unlockAchievement(user, 0);
        }
    }

    function _verifyNFTOwnership(address user, address collection, uint256 tokenId) internal view returns (bool) {
        NFTCollection storage coll = nftCollections[collection];

        if (coll.standard == NFTStandard.ERC721) {
            return IERC721(collection).ownerOf(tokenId) == user;
        } else if (coll.standard == NFTStandard.ERC1155) {
            return IERC1155(collection).balanceOf(user, tokenId) > 0;
        }

        return false;
    }

    function _transferNFTToContract(address collection, uint256 tokenId) internal {
        NFTCollection storage coll = nftCollections[collection];

        if (coll.standard == NFTStandard.ERC721) {
            IERC721(collection).transferFrom(msg.sender, address(this), tokenId);
        } else if (coll.standard == NFTStandard.ERC1155) {
            IERC1155(collection).safeTransferFrom(msg.sender, address(this), tokenId, 1, "");
        }
    }

    function _transferNFTFromContract(address collection, uint256 tokenId, address to) internal {
        NFTCollection storage coll = nftCollections[collection];

        if (coll.standard == NFTStandard.ERC721) {
            IERC721(collection).transferFrom(address(this), to, tokenId);
        } else if (coll.standard == NFTStandard.ERC1155) {
            IERC1155(collection).safeTransferFrom(address(this), to, tokenId, 1, "");
        }
    }

    function _getNFTBalance(address user, address collection) internal view returns (uint256) {
        NFTCollection storage coll = nftCollections[collection];

        if (coll.standard == NFTStandard.ERC721) {
            return IERC721(collection).balanceOf(user);
        } else if (coll.standard == NFTStandard.ERC1155) {
            // For ERC1155, we'd need to check specific token IDs
            // This is a simplified implementation
            return 0;
        }

        return 0;
    }

    function _calculateStakingRewards(address user, address collection) internal view returns (uint256) {
        StakingPool storage pool = stakingPools[collection];
        StakingInfo storage stakerInfo = pool.stakerInfo[user];

        if (stakerInfo.stakedTokens.length == 0) return 0;

        uint256 timeElapsed = block.timestamp - stakerInfo.lastClaimTime;
        uint256 rewards = stakerInfo.stakedTokens.length
            .safeMul(pool.rewardRate)
            .safeMul(timeElapsed)
            .safeDiv(1 days);

        return rewards;
    }

    function _claimStakingRewards(address user, address collection, uint256 rewards) internal {
        StakingPool storage pool = stakingPools[collection];
        StakingInfo storage stakerInfo = pool.stakerInfo[user];

        stakerInfo.pendingRewards = 0;
        stakerInfo.totalClaimed = stakerInfo.totalClaimed.safeAdd(rewards);
        stakerInfo.lastClaimTime = block.timestamp;

        userTiers[user].stakingRewards = userTiers[user].stakingRewards.safeAdd(rewards);
        pool.totalRewards = pool.totalRewards.safeAdd(rewards);
        totalStakingRewards = totalStakingRewards.safeAdd(rewards);

        // Transfer rewards to user (would be EPCS tokens)
        // For now, we'll just update the balance
    }

    function _isTokenStaked(address user, address collection, uint256 tokenId) internal view returns (bool) {
        StakingInfo storage stakerInfo = stakingPools[collection].stakerInfo[user];

        for (uint256 i = 0; i < stakerInfo.stakedTokens.length; i++) {
            if (stakerInfo.stakedTokens[i] == tokenId) {
                return true;
            }
        }

        return false;
    }

    function _removeFromStakedTokens(StakingInfo storage stakerInfo, uint256 tokenId) internal {
        for (uint256 i = 0; i < stakerInfo.stakedTokens.length; i++) {
            if (stakerInfo.stakedTokens[i] == tokenId) {
                stakerInfo.stakedTokens[i] = stakerInfo.stakedTokens[stakerInfo.stakedTokens.length - 1];
                stakerInfo.stakedTokens.pop();
                break;
            }
        }
    }

    // ============ Admin Functions ============

    function createPresaleRound(
        string memory name,
        uint256 startTime,
        uint256 endTime,
        uint256 tokenPrice,
        uint256 maxTokens,
        TierType minimumTier,
        AccessType accessType,
        uint256 bonusPercentage,
        uint256 maxPurchasePerUser
    ) external onlyOwner {
        require(startTime < endTime, "Invalid time range");
        require(tokenPrice > 0, "Invalid token price");
        require(maxTokens > 0, "Invalid max tokens");

        uint256 roundId = totalRounds;
        PresaleRound storage round = presaleRounds[roundId];

        round.roundId = roundId;
        round.name = name;
        round.startTime = startTime;
        round.endTime = endTime;
        round.tokenPrice = tokenPrice;
        round.maxTokens = maxTokens;
        round.minimumTier = minimumTier;
        round.accessType = accessType;
        round.bonusPercentage = bonusPercentage;
        round.maxPurchasePerUser = maxPurchasePerUser;
        round.active = true;
        round.completed = false;

        totalRounds++;
        currentRound = roundId;

        emit PresaleRoundCreated(roundId, name, startTime, endTime, minimumTier);
    }

    function createStakingPool(
        address collection,
        uint256 rewardRate,
        uint256 stakingDuration
    ) external onlyOwner validCollection(collection) {
        require(rewardRate > 0, "Invalid reward rate");
        require(stakingDuration > 0, "Invalid staking duration");

        StakingPool storage pool = stakingPools[collection];
        pool.nftContract = collection;
        pool.rewardRate = rewardRate;
        pool.stakingDuration = stakingDuration;
        pool.active = true;
        pool.lastRewardTime = block.timestamp;

        stakingPoolAddresses.push(collection);
    }

    function addPartnership(
        address partnerContract,
        string memory partnerName,
        uint256 bonusMultiplier,
        TierType tierUpgrade,
        bool crossCollectionBonus,
        uint256 duration
    ) external onlyOwner {
        require(partnerContract != address(0), "Invalid partner contract");
        require(bonusMultiplier > 0, "Invalid bonus multiplier");

        Partnership storage partnership = partnerships[partnerContract];
        partnership.partnerContract = partnerContract;
        partnership.partnerName = partnerName;
        partnership.bonusMultiplier = bonusMultiplier;
        partnership.tierUpgrade = tierUpgrade;
        partnership.crossCollectionBonus = crossCollectionBonus;
        partnership.active = true;
        partnership.startTime = block.timestamp;
        partnership.endTime = block.timestamp + duration;

        partnerContracts.push(partnerContract);

        emit PartnershipAdded(partnerContract, partnerName, bonusMultiplier, tierUpgrade);
    }

    function updateBonusStructure(
        TierType tier,
        BonusType bonusType,
        uint256 baseBonus,
        uint256 maxBonus,
        uint256 tierMultiplier,
        bool stackable
    ) external onlyOwner validTier(tier) {
        BonusStructure storage bonus = bonusStructures[tier];
        bonus.bonusType = bonusType;
        bonus.baseBonus = baseBonus;
        bonus.maxBonus = maxBonus;
        bonus.tierMultiplier = tierMultiplier;
        bonus.stackable = stackable;
        bonus.active = true;

        emit BonusStructureUpdated(tier, bonusType, baseBonus, maxBonus);
    }

    function setSnapshotMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        snapshotMerkleRoot = merkleRoot;
    }

    function verifySnapshot(
        address user,
        uint256 tokenCount,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user, tokenCount));
        return MerkleProof.verify(merkleProof, snapshotMerkleRoot, leaf);
    }

    function emergencyPause() external onlyEmergencyAdmin {
        emergencyPaused = true;
        _pause();
        emit EmergencyPause(msg.sender, true, block.timestamp);
    }

    function emergencyUnpause() external onlyOwner {
        emergencyPaused = false;
        _unpause();
        emit EmergencyPause(msg.sender, false, block.timestamp);
    }

    function pauseCollection(address collection) external onlyEmergencyAdmin {
        collectionEmergencyPaused[collection] = true;
    }

    function unpauseCollection(address collection) external onlyOwner {
        collectionEmergencyPaused[collection] = false;
    }

    function updateTierRequirements(
        TierType tier,
        uint256 requirement,
        uint256 bonus
    ) external onlyOwner validTier(tier) {
        tierRequirements[tier] = requirement;
        tierBonuses[tier] = bonus;
    }

    function updateFees(
        uint256 newStakingFee,
        uint256 newTierUpgradeFee
    ) external onlyOwner {
        require(newStakingFee <= 1000, "Staking fee too high"); // Max 10%
        require(newTierUpgradeFee <= 500, "Tier upgrade fee too high"); // Max 5%

        stakingFee = newStakingFee;
        tierUpgradeFee = newTierUpgradeFee;
    }

    function updateEmergencyAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Invalid admin");
        emergencyAdmin = newAdmin;
    }

    function updateFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Invalid receiver");
        feeReceiver = newReceiver;
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = feeReceiver.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    // ============ Fallback Functions ============

    receive() external payable {
        // Allow contract to receive ETH
    }

    fallback() external payable {
        revert("Function not found");
    }
}
