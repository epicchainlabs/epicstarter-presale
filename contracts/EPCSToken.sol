// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title EPCSToken
 * @dev EpicStarter (EPCS) token with advanced features including:
 * - Burnable tokens
 * - Pausable functionality
 * - Anti-bot protection
 * - Transfer restrictions
 * - Reflection rewards
 * - Liquidity pool management
 * - Deflationary mechanics
 * @author EpicChainLabs
 */
contract EPCSToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ReentrancyGuard {
    // ============ Constants ============

    uint256 private constant MAX_SUPPLY = 1000000000 * 10**18; // 1 billion tokens
    uint256 private constant INITIAL_SUPPLY = 100000000 * 10**18; // 100 million initial
    uint256 private constant BURN_RATE = 100; // 1% burn rate
    uint256 private constant REFLECTION_RATE = 200; // 2% reflection rate
    uint256 private constant LIQUIDITY_RATE = 100; // 1% liquidity rate
    uint256 private constant BASIS_POINTS = 10000;

    // ============ State Variables ============

    // Token distribution
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromReflection;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isAuthorizedMinter;
    mapping(address => uint256) public lastTransferTime;

    // Liquidity pools
    mapping(address => bool) public isLiquidityPool;
    address[] public liquidityPools;

    // Reflection system
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    address[] private _excluded;

    // Fee structure
    struct FeeStructure {
        uint256 burnFee;
        uint256 reflectionFee;
        uint256 liquidityFee;
        uint256 treasuryFee;
        uint256 developmentFee;
    }

    FeeStructure public buyFees;
    FeeStructure public sellFees;
    FeeStructure public transferFees;

    // Wallets
    address public treasuryWallet;
    address public developmentWallet;
    address public liquidityWallet;
    address public presaleContract;

    // Anti-bot and restrictions
    bool public tradingEnabled;
    bool public antiMEVEnabled;
    bool public transferRestrictionsEnabled;
    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;
    uint256 public tradingEnabledTime;
    uint256 public antiMEVDuration;

    // Liquidity management
    bool private inSwapAndLiquify;
    uint256 public swapTokensAtAmount;
    bool public swapAndLiquifyEnabled;

    // Staking integration
    mapping(address => bool) public isStakingContract;
    mapping(address => uint256) public stakingRewards;

    // Governance
    mapping(address => bool) public isGovernor;
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    struct Proposal {
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    // ============ Events ============

    event TradingEnabled(uint256 timestamp);
    event ReflectionDistributed(uint256 amount);
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount);
    event FeesUpdated(string feeType, FeeStructure fees);
    event ExcludeFromFee(address indexed account, bool excluded);
    event ExcludeFromReflection(address indexed account, bool excluded);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event AuthorizedMinterUpdated(address indexed account, bool authorized);
    event LiquidityPoolUpdated(address indexed pool, bool isPool);
    event MaxTransactionAmountUpdated(uint256 amount);
    event MaxWalletAmountUpdated(uint256 amount);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapTokensAtAmountUpdated(uint256 amount);
    event TreasuryWalletUpdated(address indexed wallet);
    event DevelopmentWalletUpdated(address indexed wallet);
    event LiquidityWalletUpdated(address indexed wallet);
    event PresaleContractUpdated(address indexed contract);
    event StakingContractUpdated(address indexed contract, bool isStaking);
    event GovernorUpdated(address indexed governor, bool isGovernor);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);

    // ============ Modifiers ============

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier onlyAuthorizedMinter() {
        require(isAuthorizedMinter[msg.sender] || owner() == msg.sender, "Not authorized minter");
        _;
    }

    modifier onlyGovernor() {
        require(isGovernor[msg.sender] || owner() == msg.sender, "Not a governor");
        _;
    }

    modifier tradingActive() {
        require(tradingEnabled || msg.sender == owner() || msg.sender == presaleContract, "Trading not enabled");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!isBlacklisted[account], "Account is blacklisted");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    // ============ Constructor ============

    constructor(
        address _owner,
        address _treasuryWallet,
        address _developmentWallet,
        address _liquidityWallet
    ) ERC20("EpicStarter", "EPCS") Ownable(_owner) {
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        require(_developmentWallet != address(0), "Invalid development wallet");
        require(_liquidityWallet != address(0), "Invalid liquidity wallet");

        treasuryWallet = _treasuryWallet;
        developmentWallet = _developmentWallet;
        liquidityWallet = _liquidityWallet;

        // Initialize reflection system
        _rTotal = (MAX_SUPPLY - INITIAL_SUPPLY) * 10**9;

        // Initial token distribution
        _mint(_owner, INITIAL_SUPPLY);

        // Set initial reflection balances
        _rOwned[_owner] = _rTotal;

        // Initialize fee structures
        buyFees = FeeStructure({
            burnFee: 100,        // 1%
            reflectionFee: 200,  // 2%
            liquidityFee: 100,   // 1%
            treasuryFee: 200,    // 2%
            developmentFee: 100  // 1%
        });

        sellFees = FeeStructure({
            burnFee: 200,        // 2%
            reflectionFee: 300,  // 3%
            liquidityFee: 200,   // 2%
            treasuryFee: 300,    // 3%
            developmentFee: 200  // 2%
        });

        transferFees = FeeStructure({
            burnFee: 50,         // 0.5%
            reflectionFee: 100,  // 1%
            liquidityFee: 50,    // 0.5%
            treasuryFee: 100,    // 1%
            developmentFee: 50   // 0.5%
        });

        // Exclude from fees
        isExcludedFromFee[_owner] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[_treasuryWallet] = true;
        isExcludedFromFee[_developmentWallet] = true;
        isExcludedFromFee[_liquidityWallet] = true;

        // Exclude from reflection
        isExcludedFromReflection[address(this)] = true;
        _excluded.push(address(this));

        // Set initial limits
        maxTransactionAmount = INITIAL_SUPPLY * 1 / 100; // 1% of initial supply
        maxWalletAmount = INITIAL_SUPPLY * 2 / 100; // 2% of initial supply
        swapTokensAtAmount = INITIAL_SUPPLY * 5 / 10000; // 0.05% of initial supply

        // Initialize settings
        swapAndLiquifyEnabled = true;
        antiMEVEnabled = true;
        transferRestrictionsEnabled = true;
        antiMEVDuration = 600; // 10 minutes

        // Set initial governors
        isGovernor[_owner] = true;
        isAuthorizedMinter[_owner] = true;
    }

    // ============ ERC20 Overrides ============

    /**
     * @dev Override transfer function with fees and restrictions
     */
    function transfer(address to, uint256 amount)
        public
        override
        tradingActive
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        _transferWithFees(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Override transferFrom function with fees and restrictions
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        tradingActive
        notBlacklisted(from)
        notBlacklisted(to)
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithFees(from, to, amount);
        return true;
    }

    /**
     * @dev Override _update function for pausable functionality
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }

    // ============ Reflection Functions ============

    /**
     * @dev Get reflection amount from token amount
     */
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= totalSupply(), "Amount must be less than supply");

        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    /**
     * @dev Get token amount from reflection amount
     */
    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");

        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    /**
     * @dev Distribute reflection to all holders
     */
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
        emit ReflectionDistributed(tFee);
    }

    /**
     * @dev Get reflection and transfer values
     */
    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    /**
     * @dev Get token values
     */
    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = calculateReflectionFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount - tFee - tLiquidity;
        return (tTransferAmount, tFee, tLiquidity);
    }

    /**
     * @dev Get reflection values
     */
    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 currentRate)
        private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rLiquidity;
        return (rAmount, rTransferAmount, rFee);
    }

    /**
     * @dev Get current reflection rate
     */
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    /**
     * @dev Get current supply for reflection calculations
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = totalSupply();

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply)
                return (_rTotal, totalSupply());
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }

        if (rSupply < _rTotal / totalSupply()) return (_rTotal, totalSupply());
        return (rSupply, tSupply);
    }

    // ============ Fee Calculation Functions ============

    /**
     * @dev Calculate reflection fee
     */
    function calculateReflectionFee(uint256 amount) public view returns (uint256) {
        return amount * _getCurrentReflectionFee() / BASIS_POINTS;
    }

    /**
     * @dev Calculate liquidity fee
     */
    function calculateLiquidityFee(uint256 amount) public view returns (uint256) {
        return amount * _getCurrentLiquidityFee() / BASIS_POINTS;
    }

    /**
     * @dev Calculate burn fee
     */
    function calculateBurnFee(uint256 amount) public view returns (uint256) {
        return amount * _getCurrentBurnFee() / BASIS_POINTS;
    }

    /**
     * @dev Get current reflection fee based on transaction type
     */
    function _getCurrentReflectionFee() private view returns (uint256) {
        return transferFees.reflectionFee; // Default to transfer fee
    }

    /**
     * @dev Get current liquidity fee based on transaction type
     */
    function _getCurrentLiquidityFee() private view returns (uint256) {
        return transferFees.liquidityFee; // Default to transfer fee
    }

    /**
     * @dev Get current burn fee based on transaction type
     */
    function _getCurrentBurnFee() private view returns (uint256) {
        return transferFees.burnFee; // Default to transfer fee
    }

    // ============ Transfer Functions ============

    /**
     * @dev Transfer with fees and restrictions
     */
    function _transferWithFees(address from, address to, uint256 amount) private {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // Check transfer restrictions
        if (transferRestrictionsEnabled) {
            _checkTransferRestrictions(from, to, amount);
        }

        // Check MEV protection
        if (antiMEVEnabled && tradingEnabled) {
            _checkMEVProtection(from, to);
        }

        // Handle swap and liquify
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= swapTokensAtAmount;

        if (overMinTokenBalance &&
            !inSwapAndLiquify &&
            !isLiquidityPool[from] &&
            swapAndLiquifyEnabled) {
            _swapAndLiquify(contractTokenBalance);
        }

        // Determine if fees should be taken
        bool takeFee = true;
        if (isExcludedFromFee[from] || isExcludedFromFee[to]) {
            takeFee = false;
        }

        // Transfer with or without fees
        if (takeFee) {
            _transferWithAllFees(from, to, amount);
        } else {
            _transferStandard(from, to, amount);
        }

        // Update last transfer time for MEV protection
        lastTransferTime[from] = block.timestamp;
        lastTransferTime[to] = block.timestamp;
    }

    /**
     * @dev Transfer with all fees applied
     */
    function _transferWithAllFees(address from, address to, uint256 amount) private {
        FeeStructure memory fees = _determineFeeStructure(from, to);

        // Calculate all fees
        uint256 burnAmount = amount * fees.burnFee / BASIS_POINTS;
        uint256 reflectionAmount = amount * fees.reflectionFee / BASIS_POINTS;
        uint256 liquidityAmount = amount * fees.liquidityFee / BASIS_POINTS;
        uint256 treasuryAmount = amount * fees.treasuryFee / BASIS_POINTS;
        uint256 developmentAmount = amount * fees.developmentFee / BASIS_POINTS;

        uint256 totalFees = burnAmount + reflectionAmount + liquidityAmount + treasuryAmount + developmentAmount;
        uint256 transferAmount = amount - totalFees;

        // Execute transfers
        if (burnAmount > 0) {
            _burn(from, burnAmount);
        }

        if (reflectionAmount > 0) {
            _reflectFee(reflectionAmount * _getRate(), reflectionAmount);
        }

        if (liquidityAmount > 0) {
            super._update(from, address(this), liquidityAmount);
        }

        if (treasuryAmount > 0) {
            super._update(from, treasuryWallet, treasuryAmount);
        }

        if (developmentAmount > 0) {
            super._update(from, developmentWallet, developmentAmount);
        }

        super._update(from, to, transferAmount);
    }

    /**
     * @dev Standard transfer without fees
     */
    function _transferStandard(address from, address to, uint256 amount) private {
        super._update(from, to, amount);
    }

    /**
     * @dev Determine fee structure based on transaction type
     */
    function _determineFeeStructure(address from, address to) private view returns (FeeStructure memory) {
        if (isLiquidityPool[from]) {
            // Buy transaction
            return buyFees;
        } else if (isLiquidityPool[to]) {
            // Sell transaction
            return sellFees;
        } else {
            // Regular transfer
            return transferFees;
        }
    }

    // ============ Restriction Functions ============

    /**
     * @dev Check transfer restrictions
     */
    function _checkTransferRestrictions(address from, address to, uint256 amount) private view {
        // Check max transaction amount
        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            require(amount <= maxTransactionAmount, "Transfer amount exceeds maximum");
        }

        // Check max wallet amount
        if (!isExcludedFromFee[to] && !isLiquidityPool[to]) {
            require(balanceOf(to) + amount <= maxWalletAmount, "Wallet amount exceeds maximum");
        }
    }

    /**
     * @dev Check MEV protection
     */
    function _checkMEVProtection(address from, address to) private view {
        if (block.timestamp < tradingEnabledTime + antiMEVDuration) {
            // More restrictive checks during MEV protection period
            require(
                isExcludedFromFee[from] || isExcludedFromFee[to] ||
                block.timestamp > lastTransferTime[from] + 60, // 1 minute cooldown
                "MEV protection active"
            );
        }
    }

    // ============ Liquidity Functions ============

    /**
     * @dev Swap tokens for ETH and add liquidity
     */
    function _swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // Split balance for liquidity
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        // Capture initial balance
        uint256 initialBalance = address(this).balance;

        // Swap tokens for ETH
        _swapTokensForEth(half);

        // Calculate how much ETH was swapped
        uint256 newBalance = address(this).balance - initialBalance;

        // Add liquidity
        _addLiquidity(otherHalf, newBalance);

        emit LiquidityAdded(otherHalf, newBalance);
    }

    /**
     * @dev Swap tokens for ETH (placeholder - requires DEX integration)
     */
    function _swapTokensForEth(uint256 tokenAmount) private {
        // This would integrate with a DEX like PancakeSwap
        // Implementation depends on the specific DEX being used
    }

    /**
     * @dev Add liquidity to DEX (placeholder - requires DEX integration)
     */
    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // This would integrate with a DEX like PancakeSwap
        // Implementation depends on the specific DEX being used
    }

    // ============ Minting Functions ============

    /**
     * @dev Mint new tokens (only authorized minters)
     */
    function mint(address to, uint256 amount) external onlyAuthorizedMinter {
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed max supply");
        _mint(to, amount);
    }

    /**
     * @dev Batch mint tokens
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external onlyAuthorizedMinter {
        require(recipients.length == amounts.length, "Array length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(totalSupply() + totalAmount <= MAX_SUPPLY, "Would exceed max supply");

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }

    // ============ Admin Functions ============

    /**
     * @dev Enable trading
     */
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        tradingEnabledTime = block.timestamp;
        emit TradingEnabled(block.timestamp);
    }

    /**
     * @dev Update fee structures
     */
    function updateBuyFees(FeeStructure calldata fees) external onlyOwner {
        require(_validateFeeStructure(fees), "Invalid fee structure");
        buyFees = fees;
        emit FeesUpdated("buy", fees);
    }

    function updateSellFees(FeeStructure calldata fees) external onlyOwner {
        require(_validateFeeStructure(fees), "Invalid fee structure");
        sellFees = fees;
        emit FeesUpdated("sell", fees);
    }

    function updateTransferFees(FeeStructure calldata fees) external onlyOwner {
        require(_validateFeeStructure(fees), "Invalid fee structure");
        transferFees = fees;
        emit FeesUpdated("transfer", fees);
    }

    /**
     * @dev Validate fee structure
     */
    function _validateFeeStructure(FeeStructure calldata fees) private pure returns (bool) {
        uint256 totalFees = fees.burnFee + fees.reflectionFee + fees.liquidityFee +
                           fees.treasuryFee + fees.developmentFee;
        return totalFees <= 2500; // Max 25% total fees
    }

    /**
     * @dev Exclude/include account from fees
     */
    function excludeFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
        emit ExcludeFromFee(account, excluded);
    }

    /**
     * @dev Exclude/include account from reflection
     */
    function excludeFromReflection(address account, bool excluded) external onlyOwner {
        require(isExcludedFromReflection[account] != excluded, "Account already in desired state");

        if (excluded) {
            if (_rOwned[account] > 0) {
                _tOwned[account] = tokenFromReflection(_rOwned[account]);
            }
            isExcludedFromReflection[account] = true;
            _excluded.push(account);
        } else {
            for (uint256 i = 0; i < _excluded.length; i++) {
                if (_excluded[i] == account) {
                    _excluded[i] = _excluded[_excluded.length - 1];
                    _excluded.pop();
                    break;
                }
            }
            _tOwned[account] = 0;
            isExcludedFromReflection[account] = false;
        }

        emit ExcludeFromReflection(account, excluded);
    }

    /**
     * @dev Update blacklist status
     */
    function updateBlacklist(address account, bool blacklisted) external onlyOwner {
        isBlacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }

    /**
     * @dev Batch update blacklist
     */
    function batchUpdateBlacklist(address[] calldata accounts, bool blacklisted) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isBlacklisted[accounts[i]] = blacklisted;
            emit BlacklistUpdated(accounts[i], blacklisted);
        }
    }

    /**
     * @dev Update authorized minter status
     */
    function updateAuthorizedMinter(address account, bool authorized) external onlyOwner {
        isAuthorizedMinter[account] = authorized;
        emit AuthorizedMinterUpdated(account, authorized);
    }

    /**
     * @dev Update liquidity pool status
     */
    function updateLiquidityPool(address pool, bool isPool) external onlyOwner {
        require(isLiquidityPool[pool] != isPool, "Pool already in desired state");

        isLiquidityPool[pool] = isPool;

        if (isPool) {
            liquidityPools.push(pool);
        } else {
            for (uint256 i = 0; i < liquidityPools.length; i++) {
                if (liquidityPools[i] == pool) {
                    liquidityPools[i] = liquidityPools[liquidityPools.length - 1];
                    liquidityPools.pop();
                    break;
                }
            }
        }

        emit LiquidityPoolUpdated(pool, isPool);
    }

    /**
     * @dev Update transaction limits
     */
    function updateMaxTransactionAmount(uint256 amount) external onlyOwner {
        require(amount >= totalSupply() / 1000, "Amount too low"); // Min 0.1%
        maxTransactionAmount = amount;
        emit MaxTransactionAmountUpdated(amount);
    }

    function updateMaxWalletAmount(uint256 amount) external onlyOwner {
        require(amount >= totalSupply() / 100, "Amount too low"); // Min 1%
        maxWalletAmount = amount;
        emit MaxWalletAmountUpdated(amount);
    }

    /**
     * @dev Update swap and liquify settings
     */
    function updateSwapAndLiquifyEnabled(bool enabled) external onlyOwner {
        swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(enabled);
    }

    function updateSwapTokensAtAmount(uint256 amount) external onlyOwner {
        swapTokensAtAmount = amount;
        emit SwapTokensAtAmountUpdated(amount);
    }

    /**
     * @dev Update wallet addresses
     */
    function updateTreasuryWallet(address wallet) external onlyOwner validAddress(wallet) {
        treasuryWallet = wallet;
        emit TreasuryWalletUpdated(wallet);
    }

    function updateDevelopmentWallet(address wallet) external onlyOwner validAddress(wallet) {
        developmentWallet = wallet;
        emit DevelopmentWalletUpdated(wallet);
    }

    function updateLiquidityWallet(address wallet) external onlyOwner validAddress(wallet) {
        liquidityWallet = wallet;
        emit LiquidityWalletUpdated(wallet);
    }

    function updatePresaleContract(address contractAddr) external onlyOwner {
        presaleContract = contractAddr;
        emit PresaleContractUpdated(contractAddr);
    }

    /**
     * @dev Update protection settings
     */
    function updateAntiMEVEnabled(bool enabled) external onlyOwner {
        antiMEVEnabled = enabled;
    }

    function updateTransferRestrictionsEnabled(bool enabled) external onlyOwner {
        transferRestrictionsEnabled = enabled;
    }

    function updateAntiMEVDuration(uint256 duration) external onlyOwner {
        require(duration <= 3600, "Duration too long"); // Max 1 hour
        antiMEVDuration = duration;
    }

    // ============ Staking Integration ============

    /**
     * @dev Update staking contract status
     */
    function updateStakingContract(address contractAddr, bool isStaking) external onlyOwner {
        isStakingContract[contractAddr] = isStaking;
        if (isStaking) {
            isExcludedFromFee[contractAddr] = true;
        }
        emit StakingContractUpdated(contractAddr, isStaking);
    }

    /**
     * @dev Award staking rewards
     */
    function awardStakingRewards(address user, uint256 amount) external {
        require(isStakingContract[msg.sender], "Not a staking contract");
        require(amount <= balanceOf(address(this)), "Insufficient contract balance");

        stakingRewards[user] += amount;
        _transfer(address(this), user, amount);
    }

    // ============ Governance Functions ============

    /**
     * @dev Update governor status
     */
    function updateGovernor(address governor, bool isGov) external onlyOwner {
        isGovernor[governor] = isGov;
        emit GovernorUpdated(governor, isGov);
    }

    /**
     * @dev Create governance proposal
     */
    function createProposal(string calldata description, uint256 votingDuration) external onlyGovernor {
        uint256 proposalId = proposalCount++;

        Proposal storage proposal = proposals[proposalId];
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.endTime = block.timestamp + votingDuration;
        proposal.executed = false;

        emit ProposalCreated(proposalId, msg.sender, description);
    }

    /**
     * @dev Vote on governance proposal
     */
    function vote(uint256 proposalId, bool support) external {
        require(proposalId < proposalCount, "Invalid proposal");
        require(balanceOf(msg.sender) > 0, "No voting power");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 votingPower = balanceOf(msg.sender);
        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }

    /**
     * @dev Execute governance proposal
     */
    function executeProposal(uint256 proposalId) external onlyOwner {
        require(proposalId < proposalCount, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    // ============ Emergency Functions ============

    /**
     * @dev Emergency pause
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Emergency unpause
     */
    function emergencyUnpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency withdraw (only owner)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }
    }

    // ============ View Functions ============

    /**
     * @dev Get total fees collected
     */
    function getTotalFeesCollected() external view returns (uint256) {
        return _tFeeTotal;
    }

    /**
     * @dev Get reflection info for account
     */
    function getReflectionInfo(address account) external view returns (
        bool isExcluded,
        uint256 reflectionBalance,
        uint256 tokenBalance
    ) {
        isExcluded = isExcludedFromReflection[account];

        if (isExcluded) {
            reflectionBalance = 0;
            tokenBalance = _tOwned[account];
        } else {
            reflectionBalance = _rOwned[account];
            tokenBalance = tokenFromReflection(_rOwned[account]);
        }
    }

    /**
     * @dev Get account info
     */
    function getAccountInfo(address account) external view returns (
        uint256 balance,
        bool excludedFromFee,
        bool excludedFromReflection,
        bool blacklisted,
        uint256 lastTransfer,
        uint256 stakingReward
    ) {
        balance = balanceOf(account);
        excludedFromFee = isExcludedFromFee[account];
        excludedFromReflection = isExcludedFromReflection[account];
        blacklisted = isBlacklisted[account];
        lastTransfer = lastTransferTime[account];
        stakingReward = stakingRewards[account];
    }

    /**
     * @dev Get contract settings
     */
    function getContractSettings() external view returns (
        bool tradingEnabledStatus,
        bool antiMEVEnabledStatus,
        bool transferRestrictionsEnabledStatus,
        bool swapAndLiquifyEnabledStatus,
        uint256 maxTxAmount,
        uint256 maxWalletSize,
        uint256 swapThreshold,
        uint256 tradingStartTime,
        uint256 mevProtectionTime
    ) {
        tradingEnabledStatus = tradingEnabled;
        antiMEVEnabledStatus = antiMEVEnabled;
        transferRestrictionsEnabledStatus = transferRestrictionsEnabled;
        swapAndLiquifyEnabledStatus = swapAndLiquifyEnabled;
        maxTxAmount = maxTransactionAmount;
        maxWalletSize = maxWalletAmount;
        swapThreshold = swapTokensAtAmount;
        tradingStartTime = tradingEnabledTime;
        mevProtectionTime = antiMEVDuration;
    }

    /**
     * @dev Get fee structures
     */
    function getFeeStructures() external view returns (
        FeeStructure memory buyFeesStruct,
        FeeStructure memory sellFeesStruct,
        FeeStructure memory transferFeesStruct
    ) {
        buyFeesStruct = buyFees;
        sellFeesStruct = sellFees;
        transferFeesStruct = transferFees;
    }

    /**
     * @dev Get wallet addresses
     */
    function getWalletAddresses() external view returns (
        address treasury,
        address development,
        address liquidity,
        address presale
    ) {
        treasury = treasuryWallet;
        development = developmentWallet;
        liquidity = liquidityWallet;
        presale = presaleContract;
    }

    /**
     * @dev Get liquidity pools
     */
    function getLiquidityPools() external view returns (address[] memory) {
        return liquidityPools;
    }

    /**
     * @dev Get excluded accounts from reflection
     */
    function getExcludedFromReflection() external view returns (address[] memory) {
        return _excluded;
    }

    /**
     * @dev Get proposal info
     */
    function getProposalInfo(uint256 proposalId) external view returns (
        address proposer,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed
    ) {
        require(proposalId < proposalCount, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];
        proposer = proposal.proposer;
        description = proposal.description;
        votesFor = proposal.votesFor;
        votesAgainst = proposal.votesAgainst;
        endTime = proposal.endTime;
        executed = proposal.executed;
    }

    /**
     * @dev Check if user voted on proposal
     */
    function hasVotedOnProposal(uint256 proposalId, address user) external view returns (bool) {
        require(proposalId < proposalCount, "Invalid proposal");
        return proposals[proposalId].hasVoted[user];
    }

    // ============ Receive Function ============

    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}

    /**
     * @dev Fallback function
     */
    fallback() external payable {}
}
