# 🚀 EpicStarter Presale Setup Guide

This guide will walk you through setting up and running the EpicStarter Presale project from scratch.

## 📋 Prerequisites

### Required Software
- **Node.js v18+** - [Download here](https://nodejs.org/)
- **npm or yarn** - Comes with Node.js
- **Git** - [Download here](https://git-scm.com/)

### Check Your Installation
```bash
node --version    # Should be v18 or higher
npm --version     # Should be 8.0 or higher
git --version     # Any recent version
```

## 🔧 Step 1: Install Dependencies

```bash
# Navigate to project directory
cd epicstarter-presale

# Install all dependencies
npm install

# Alternative with yarn
yarn install
```

## 🔐 Step 2: Environment Configuration

Create a `.env` file in the root directory with the following variables:

```bash
# Copy the example file
cp .env.example .env

# Or create manually
touch .env
```

### Required Environment Variables

Add these to your `.env` file:

```env
# ============ NETWORK CONFIGURATION ============
# Private key for deployment (NEVER share this!)
PRIVATE_KEY=your_private_key_here

# RPC URLs
BSC_MAINNET_RPC_URL=https://bsc-dataseed1.binance.org/
BSC_TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
POLYGON_RPC_URL=https://polygon-rpc.com/
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY

# Block Explorer API Keys
BSCSCAN_API_KEY=your_bscscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key

# ============ ORACLE PRICE FEEDS ============
# BSC Mainnet Chainlink Price Feeds
BNB_USD_PRICE_FEED=0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
USDT_USD_PRICE_FEED=0xB97Ad0E74fa7d920791E90258A6E2085088b4320
USDC_USD_PRICE_FEED=0x51597f405303C4377E36123cBc172b13269EA163

# BSC Testnet Price Feeds (for testing)
BNB_USD_PRICE_FEED_TESTNET=0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
USDT_USD_PRICE_FEED_TESTNET=0xEca2605f0BCF2BA5966372C99837b1F182d3D620
USDC_USD_PRICE_FEED_TESTNET=0x90c069C4538adAc136E051052E14c1cD799C41B7

# ============ TOKEN ADDRESSES ============
# BSC Mainnet
USDT_ADDRESS_MAINNET=0x55d398326f99059fF775485246999027B3197955
USDC_ADDRESS_MAINNET=0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d

# BSC Testnet
USDT_ADDRESS_TESTNET=0x337610d27c682E347C9cD60BD4b3b107C9d34dDd
USDC_ADDRESS_TESTNET=0x64544969ed7EBf5f083679233325356EbE738930

# ============ WALLET ADDRESSES ============
TREASURY_WALLET=0x0000000000000000000000000000000000000000
TEAM_WALLET=0x0000000000000000000000000000000000000000
LIQUIDITY_WALLET=0x0000000000000000000000000000000000000000
DEVELOPMENT_WALLET=0x0000000000000000000000000000000000000000

# ============ PRESALE CONFIGURATION ============
PRESALE_START_TIME=1700000000
PRESALE_END_TIME=1800000000
HARD_CAP=5000000000000000000000000000
MAX_TOKENS_FOR_SALE=100000000000000000000000000
MIN_PURCHASE_AMOUNT=10000000000000000000
MAX_PURCHASE_AMOUNT=100000000000000000000000
INITIAL_PRICE=1000000000000000000
PRICE_INCREASE_RATE=100
KYC_REQUIRED=false
WHITELIST_ENABLED=false

# ============ SECURITY SETTINGS ============
COOLDOWN_PERIOD=30
MAX_SLIPPAGE=1000
ANTI_MEV_ENABLED=true
CIRCUIT_BREAKER_ENABLED=true
BLACKLIST_ENABLED=true

# ============ OPTIONAL SETTINGS ============
REPORT_GAS=true
COINMARKETCAP_API_KEY=your_cmc_api_key
```

## 🔑 Step 3: Get API Keys and Addresses

### 1. Get Private Key
```bash
# From MetaMask: Account Details > Export Private Key
# NEVER share this key publicly!
```

### 2. Get API Keys
- **BSCScan API**: [https://bscscan.com/apis](https://bscscan.com/apis)
- **Etherscan API**: [https://etherscan.io/apis](https://etherscan.io/apis)
- **Infura**: [https://infura.io/](https://infura.io/)

### 3. Set Wallet Addresses
Replace the zero addresses with your actual wallet addresses for:
- Treasury (receives fees)
- Team (receives raised funds)
- Liquidity (for DEX listings)
- Development (for ongoing development)

## 🔨 Step 4: Compilation

```bash
# Compile smart contracts
npm run compile

# Check contract sizes
npm run size

# Clean and recompile if needed
npm run clean
npm run compile
```

### If Compilation Fails
```bash
# Clear cache and try again
rm -rf cache/ artifacts/
npm run compile

# Update dependencies if needed
npm update
```

## 🧪 Step 5: Testing

```bash
# Run all tests
npm test

# Run tests with coverage report
npm run test:coverage

# Run tests with gas reporting
npm run test:gas

# Run specific test file
npx hardhat test test/EpicStarterPresale.test.ts
```

## 🚀 Step 6: Deployment

### Local Development Network
```bash
# Start local Hardhat network
npm run node

# In another terminal, deploy to local network
npm run deploy:local
```

### Testnet Deployment
```bash
# Deploy to BSC Testnet
npm run deploy:testnet

# Verify contracts on BSCScan
npm run verify
```

### Mainnet Deployment
```bash
# Deploy to BSC Mainnet (be very careful!)
npm run deploy:mainnet

# Verify contracts
npm run verify
```

## 🔍 Step 7: Verification

After deployment, verify your contracts:

```bash
# Verify all contracts
npm run verify

# Verify specific contract
npx hardhat verify --network bsc CONTRACT_ADDRESS "Constructor" "Arguments"
```

## 📊 Step 8: Post-Deployment Setup

### 1. Configure Presale Parameters
```bash
# Update presale configuration
# Set start/end times
# Configure price feeds
# Set security parameters
```

### 2. Transfer Tokens
```bash
# Transfer EPCS tokens to presale contract
# Set up initial liquidity if needed
```

### 3. Security Setup
```bash
# Configure whitelist if enabled
# Set up KYC integration
# Test security features
```

## 🛠️ Common Commands

```bash
# Development
npm run compile          # Compile contracts
npm run test            # Run tests
npm run coverage        # Test coverage
npm run size           # Check contract sizes
npm run clean          # Clean artifacts
npm run node           # Start local network

# Deployment
npm run deploy:local    # Deploy to local network
npm run deploy:testnet  # Deploy to testnet
npm run deploy:mainnet  # Deploy to mainnet

# Code Quality
npm run lint           # Lint TypeScript files
npm run lint:fix       # Fix linting issues
npm run format         # Format code
```

## 🐛 Troubleshooting

### Common Issues

1. **"hardhat: not found"**
   ```bash
   npm install -g hardhat
   # Or use npx
   npx hardhat compile
   ```

2. **Gas estimation failed**
   ```bash
   # Increase gas limit in hardhat.config.ts
   # Check network connection
   # Verify contract addresses
   ```

3. **Compilation errors**
   ```bash
   # Update Solidity version
   # Check import paths
   # Clear cache: rm -rf cache/ artifacts/
   ```

4. **Test failures**
   ```bash
   # Check network configuration
   # Verify mock contracts
   # Update test parameters
   ```

### Getting Help

- Check the [Issues](https://github.com/epicchainlabs/epicstarter-presale/issues) page
- Join our [Discord](https://discord.gg/epicchainlabs)
- Read the [Documentation](./docs/)

## 🔐 Security Checklist

Before mainnet deployment:

- [ ] Private keys are secure and not exposed
- [ ] All wallet addresses are correct
- [ ] Price feeds are configured properly
- [ ] Security parameters are set correctly
- [ ] Contracts have been audited
- [ ] Tests are passing with high coverage
- [ ] Emergency procedures are documented
- [ ] Multi-signature wallets are set up
- [ ] Monitoring and alerting is configured

## 📝 Next Steps

1. **Testing**: Thoroughly test on testnet
2. **Audit**: Get professional security audit
3. **Insurance**: Consider smart contract insurance
4. **Monitoring**: Set up contract monitoring
5. **Documentation**: Update user documentation
6. **Launch**: Coordinate marketing and launch

---

**⚠️ Important Security Note**: Never commit your `.env` file or share your private keys. Always use test networks before mainnet deployment.

**Built with ❤️ by EpicChain Labs Team**