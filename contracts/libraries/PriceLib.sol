// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MathLib.sol";

/**
 * @title PriceLib
 * @dev Advanced price calculation library for dynamic pricing models with multiple algorithms
 * @author EpicChainLabs
 */
library PriceLib {
    using MathLib for uint256;

    // ============ Constants ============

    uint256 private constant PRICE_PRECISION = 10**18;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant PERCENTAGE = 100;
    uint256 private constant TIME_UNIT = 1 hours;
    uint256 private constant MAX_PRICE_MULTIPLIER = 1000; // 10x max price increase
    uint256 private constant MIN_PRICE_MULTIPLIER = 10; // 0.1x min price (for discounts)

    // ============ Enums ============

    enum PricingModel {
        LINEAR,
        EXPONENTIAL,
        LOGARITHMIC,
        SIGMOID,
        DUTCH_AUCTION,
        BONDING_CURVE,
        TIME_WEIGHTED,
        VOLUME_WEIGHTED
    }

    enum TierType {
        FIXED,
        PERCENTAGE_INCREASE,
        EXPONENTIAL_INCREASE,
        LOGARITHMIC_INCREASE
    }

    // ============ Structs ============

    struct PriceConfig {
        uint256 initialPrice;
        uint256 finalPrice;
        uint256 totalSupply;
        uint256 currentSupply;
        uint256 startTime;
        uint256 endTime;
        PricingModel model;
        uint256[] parameters;
    }

    struct PriceTier {
        uint256 threshold;
        uint256 price;
        uint256 priceIncrease;
        TierType tierType;
        bool isActive;
    }

    struct BondingCurveConfig {
        uint256 reserveRatio;
        uint256 initialReserve;
        uint256 currentReserve;
        uint256 totalSupply;
        uint256 currentSupply;
    }

    struct DutchAuctionConfig {
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 decreaseRate;
    }

    struct PriceOracle {
        uint256 price;
        uint256 timestamp;
        uint256 volume;
        uint256 confidence;
        bool isValid;
    }

    // ============ Errors ============

    error PriceLib__InvalidPricingModel();
    error PriceLib__InvalidTimeRange();
    error PriceLib__InvalidPriceRange();
    error PriceLib__InvalidParameters();
    error PriceLib__PriceExceedsLimit();
    error PriceLib__InsufficientLiquidity();
    error PriceLib__InvalidTierConfig();

    // ============ Events ============

    event PriceCalculated(
        PricingModel model,
        uint256 inputAmount,
        uint256 calculatedPrice,
        uint256 timestamp
    );

    event TierActivated(
        uint256 indexed tierIndex,
        uint256 threshold,
        uint256 newPrice,
        uint256 timestamp
    );

    event BondingCurveUpdate(
        uint256 newReserve,
        uint256 newSupply,
        uint256 newPrice,
        uint256 timestamp
    );

    // ============ Main Price Calculation Functions ============

    /**
     * @dev Calculate price based on specified pricing model
     * @param config Price configuration
     * @param tokensSold Number of tokens already sold
     * @return price Calculated price
     */
    function calculatePrice(
        PriceConfig memory config,
        uint256 tokensSold
    ) internal pure returns (uint256 price) {
        if (config.model == PricingModel.LINEAR) {
            price = calculateLinearPrice(config, tokensSold);
        } else if (config.model == PricingModel.EXPONENTIAL) {
            price = calculateExponentialPrice(config, tokensSold);
        } else if (config.model == PricingModel.LOGARITHMIC) {
            price = calculateLogarithmicPrice(config, tokensSold);
        } else if (config.model == PricingModel.SIGMOID) {
            price = calculateSigmoidPrice(config, tokensSold);
        } else if (config.model == PricingModel.DUTCH_AUCTION) {
            price = calculateDutchAuctionPrice(config);
        } else if (config.model == PricingModel.TIME_WEIGHTED) {
            price = calculateTimeWeightedPrice(config, tokensSold);
        } else if (config.model == PricingModel.VOLUME_WEIGHTED) {
            price = calculateVolumeWeightedPrice(config, tokensSold);
        } else {
            revert PriceLib__InvalidPricingModel();
        }

        // Ensure price is within acceptable bounds
        if (price < config.initialPrice / MIN_PRICE_MULTIPLIER ||
            price > config.initialPrice * MAX_PRICE_MULTIPLIER) {
            revert PriceLib__PriceExceedsLimit();
        }
    }

    /**
     * @dev Calculate price using bonding curve
     * @param config Bonding curve configuration
     * @param purchaseAmount Amount of tokens to purchase
     * @return price Calculated price
     */
    function calculateBondingCurvePrice(
        BondingCurveConfig memory config,
        uint256 purchaseAmount
    ) internal pure returns (uint256 price) {
        if (config.reserveRatio == 0 || config.currentReserve == 0) {
            revert PriceLib__InvalidParameters();
        }

        // Bancor formula: Price = Reserve / (Supply * ReserveRatio)
        uint256 newSupply = config.currentSupply + purchaseAmount;

        // Calculate new reserve needed
        uint256 priceNumerator = config.currentReserve.safeMul(PRICE_PRECISION);
        uint256 priceDenominator = newSupply.safeMul(config.reserveRatio);

        price = priceNumerator.safeDiv(priceDenominator);
    }

    /**
     * @dev Calculate price for tiered pricing system
     * @param tiers Array of price tiers
     * @param tokensSold Number of tokens sold
     * @return price Current tier price
     * @return tierIndex Active tier index
     */
    function calculateTieredPrice(
        PriceTier[] memory tiers,
        uint256 tokensSold
    ) internal pure returns (uint256 price, uint256 tierIndex) {
        if (tiers.length == 0) revert PriceLib__InvalidTierConfig();

        // Find active tier
        for (uint256 i = 0; i < tiers.length; i++) {
            if (tokensSold <= tiers[i].threshold && tiers[i].isActive) {
                tierIndex = i;

                if (tiers[i].tierType == TierType.FIXED) {
                    price = tiers[i].price;
                } else if (tiers[i].tierType == TierType.PERCENTAGE_INCREASE) {
                    price = tiers[i].price.safeAdd(
                        tiers[i].price.calculatePercentage(tiers[i].priceIncrease)
                    );
                } else if (tiers[i].tierType == TierType.EXPONENTIAL_INCREASE) {
                    uint256 multiplier = tokensSold.safeDiv(tiers[i].threshold.safeDiv(100));
                    price = tiers[i].price.safeMul(
                        MathLib.pow(2, multiplier)
                    ).safeDiv(MathLib.pow(2, multiplier - 1));
                } else if (tiers[i].tierType == TierType.LOGARITHMIC_INCREASE) {
                    uint256 logFactor = MathLib.naturalLog(
                        tokensSold.safeMul(PRICE_PRECISION).safeDiv(tiers[i].threshold).safeAdd(PRICE_PRECISION)
                    );
                    price = tiers[i].price.safeAdd(
                        tiers[i].priceIncrease.safeMul(logFactor).safeDiv(PRICE_PRECISION)
                    );
                }

                return (price, tierIndex);
            }
        }

        // If no tier found, use last tier
        tierIndex = tiers.length - 1;
        price = tiers[tierIndex].price;
    }

    // ============ Specific Pricing Model Implementations ============

    /**
     * @dev Calculate linear price increase
     * @param config Price configuration
     * @param tokensSold Number of tokens sold
     * @return price Linear price
     */
    function calculateLinearPrice(
        PriceConfig memory config,
        uint256 tokensSold
    ) internal pure returns (uint256 price) {
        if (config.totalSupply == 0) revert PriceLib__InvalidParameters();

        uint256 progressRatio = tokensSold.safeMul(PRICE_PRECISION).safeDiv(config.totalSupply);
        uint256 priceIncrease = config.finalPrice.safeSub(config.initialPrice);

        price = config.initialPrice.safeAdd(
            priceIncrease.safeMul(progressRatio).safeDiv(PRICE_PRECISION)
        );
    }

    /**
     * @dev Calculate exponential price increase
     * @param config Price configuration
     * @param tokensSold Number of tokens sold
     * @return price Exponential price
     */
    function calculateExponentialPrice(
        PriceConfig memory config,
        uint256 tokensSold
    ) internal pure returns (uint256 price) {
        if (config.totalSupply == 0 || config.parameters.length == 0) {
            revert PriceLib__InvalidParameters();
        }

        uint256 progressRatio = tokensSold.safeMul(PRICE_PRECISION).safeDiv(config.totalSupply);
        uint256 exponentFactor = config.parameters[0]; // Growth rate

        // Exponential formula: P = P0 * e^(r*x)
        // Simplified: P = P0 * (1 + r*x + (r*x)^2/2)
        uint256 rateProduct = progressRatio.safeMul(exponentFactor).safeDiv(PRICE_PRECISION);
        uint256 exponentialTerm = PRICE_PRECISION.safeAdd(rateProduct).safeAdd(
            rateProduct.safeMul(rateProduct).safeDiv(2 * PRICE_PRECISION)
        );

        price = config.initialPrice.safeMul(exponentialTerm).safeDiv(PRICE_PRECISION);
    }

    /**
     * @dev Calculate logarithmic price increase
     * @param config Price configuration
     * @param tokensSold Number of tokens sold
     * @return price Logarithmic price
     */
    function calculateLogarithmicPrice(
        PriceConfig memory config,
        uint256 tokensSold
    ) internal pure returns (uint256 price) {
        if (config.totalSupply == 0 || tokensSold == 0) {
            return config.initialPrice;
        }

        uint256 progressRatio = tokensSold.safeMul(PRICE_PRECISION).safeDiv(config.totalSupply);
        uint256 logValue = MathLib.naturalLog(progressRatio.safeAdd(PRICE_PRECISION));
        uint256 scalingFactor = config.parameters.length > 0 ? config.parameters[0] : PRICE_PRECISION;

        uint256 priceIncrease = config.finalPrice.safeSub(config.initialPrice);
        uint256 logIncrease = priceIncrease.safeMul(logValue).safeMul(scalingFactor).safeDiv(PRICE_PRECISION * PRICE_PRECISION);

        price = config.initialPrice.safeAdd(logIncrease);
    }

    /**
     * @dev Calculate sigmoid (S-curve) price
     * @param config Price configuration
     * @param tokensSold Number of tokens sold
     * @return price Sigmoid price
     */
    function calculateSigmoidPrice(
        PriceConfig memory config,
        uint256 tokensSold
    ) internal pure returns (uint256 price) {
        if (config.totalSupply == 0) revert PriceLib__InvalidParameters();

        uint256 progressRatio = tokensSold.safeMul(PRICE_PRECISION).safeDiv(config.totalSupply);
        uint256 steepness = config.parameters.length > 0 ? config.parameters[0] : PRICE_PRECISION / 2;
        uint256 midpoint = config.parameters.length > 1 ? config.parameters[1] : PRICE_PRECISION / 2;

        // Simplified sigmoid: 1 / (1 + e^(-k*(x-x0)))
        // We'll use a rational approximation for computational efficiency
        int256 x = int256(progressRatio) - int256(midpoint);
        int256 kx = (x * int256(steepness)) / int256(PRICE_PRECISION);

        uint256 sigmoidValue;
        if (kx >= 0) {
            uint256 ukx = uint256(kx);
            sigmoidValue = PRICE_PRECISION.safeMul(PRICE_PRECISION).safeDiv(
                PRICE_PRECISION.safeAdd(PRICE_PRECISION.safeMul(PRICE_PRECISION).safeDiv(PRICE_PRECISION.safeAdd(ukx)))
            );
        } else {
            uint256 ukx = uint256(-kx);
            uint256 exp_kx = PRICE_PRECISION.safeAdd(ukx); // Simplified e^kx
            sigmoidValue = exp_kx.safeMul(PRICE_PRECISION).safeDiv(PRICE_PRECISION.safeAdd(exp_kx));
        }

        uint256 priceRange = config.finalPrice.safeSub(config.initialPrice);
        price = config.initialPrice.safeAdd(
            priceRange.safeMul(sigmoidValue).safeDiv(PRICE_PRECISION)
        );
    }

    /**
     * @dev Calculate Dutch auction price (decreasing over time)
     * @param config Price configuration
     * @return price Dutch auction price
     */
    function calculateDutchAuctionPrice(
        PriceConfig memory config
    ) internal view returns (uint256 price) {
        if (block.timestamp < config.startTime) {
            return config.initialPrice;
        }

        if (block.timestamp >= config.endTime) {
            return config.finalPrice;
        }

        uint256 timeElapsed = block.timestamp - config.startTime;
        uint256 totalDuration = config.endTime - config.startTime;
        uint256 timeRatio = timeElapsed.safeMul(PRICE_PRECISION).safeDiv(totalDuration);

        uint256 priceDecrease = config.initialPrice.safeSub(config.finalPrice);
        uint256 currentDecrease = priceDecrease.safeMul(timeRatio).safeDiv(PRICE_PRECISION);

        price = config.initialPrice.safeSub(currentDecrease);
    }

    /**
     * @dev Calculate time-weighted price
     * @param config Price configuration
     * @param tokensSold Number of tokens sold
     * @return price Time-weighted price
     */
    function calculateTimeWeightedPrice(
        PriceConfig memory config,
        uint256 tokensSold
    ) internal view returns (uint256 price) {
        uint256 basePrice = calculateLinearPrice(config, tokensSold);

        if (block.timestamp < config.startTime || config.endTime <= config.startTime) {
            return basePrice;
        }

        uint256 timeElapsed = block.timestamp > config.endTime ?
            config.endTime - config.startTime :
            block.timestamp - config.startTime;
        uint256 totalDuration = config.endTime - config.startTime;
        uint256 timeWeight = timeElapsed.safeMul(PRICE_PRECISION).safeDiv(totalDuration);

        // Apply time-based multiplier
        uint256 timeMultiplier = config.parameters.length > 0 ? config.parameters[0] : PRICE_PRECISION;
        uint256 adjustment = basePrice.safeMul(timeWeight).safeMul(timeMultiplier).safeDiv(PRICE_PRECISION * PRICE_PRECISION);

        price = basePrice.safeAdd(adjustment);
    }

    /**
     * @dev Calculate volume-weighted price
     * @param config Price configuration
     * @param tokensSold Number of tokens sold
     * @return price Volume-weighted price
     */
    function calculateVolumeWeightedPrice(
        PriceConfig memory config,
        uint256 tokensSold
    ) internal pure returns (uint256 price) {
        uint256 basePrice = calculateLinearPrice(config, tokensSold);

        if (config.totalSupply == 0) return basePrice;

        uint256 volumeRatio = tokensSold.safeMul(PRICE_PRECISION).safeDiv(config.totalSupply);
        uint256 volumeWeight = config.parameters.length > 0 ? config.parameters[0] : PRICE_PRECISION / 10;

        // Higher volume = higher price multiplier
        uint256 volumeMultiplier = PRICE_PRECISION.safeAdd(
            volumeRatio.safeMul(volumeWeight).safeDiv(PRICE_PRECISION)
        );

        price = basePrice.safeMul(volumeMultiplier).safeDiv(PRICE_PRECISION);
    }

    // ============ Utility Functions ============

    /**
     * @dev Calculate price impact for large purchases
     * @param currentPrice Current token price
     * @param purchaseAmount Amount of tokens to purchase
     * @param totalLiquidity Total available liquidity
     * @param impactFactor Price impact factor (basis points)
     * @return newPrice Price after impact
     * @return impact Price impact amount
     */
    function calculatePriceImpact(
        uint256 currentPrice,
        uint256 purchaseAmount,
        uint256 totalLiquidity,
        uint256 impactFactor
    ) internal pure returns (uint256 newPrice, uint256 impact) {
        if (totalLiquidity == 0) revert PriceLib__InsufficientLiquidity();

        uint256 liquidityRatio = purchaseAmount.safeMul(BASIS_POINTS).safeDiv(totalLiquidity);
        impact = currentPrice.safeMul(liquidityRatio).safeMul(impactFactor).safeDiv(BASIS_POINTS * BASIS_POINTS);
        newPrice = currentPrice.safeAdd(impact);
    }

    /**
     * @dev Calculate average price over a range of token amounts
     * @param config Price configuration
     * @param startAmount Starting token amount
     * @param endAmount Ending token amount
     * @param steps Number of calculation steps
     * @return averagePrice Average price over the range
     */
    function calculateAveragePrice(
        PriceConfig memory config,
        uint256 startAmount,
        uint256 endAmount,
        uint256 steps
    ) internal pure returns (uint256 averagePrice) {
        if (steps == 0 || endAmount <= startAmount) revert PriceLib__InvalidParameters();

        uint256 stepSize = (endAmount - startAmount).safeDiv(steps);
        uint256 totalPrice = 0;

        for (uint256 i = 0; i < steps; i++) {
            uint256 currentAmount = startAmount.safeAdd(stepSize.safeMul(i));
            uint256 price = calculatePrice(config, currentAmount);
            totalPrice = totalPrice.safeAdd(price);
        }

        averagePrice = totalPrice.safeDiv(steps);
    }

    /**
     * @dev Validate pricing configuration
     * @param config Price configuration to validate
     * @return isValid Whether configuration is valid
     */
    function validatePriceConfig(PriceConfig memory config) internal view returns (bool isValid) {
        // Basic validation
        if (config.initialPrice == 0 || config.totalSupply == 0) return false;
        if (config.endTime != 0 && config.endTime <= config.startTime) return false;
        if (config.finalPrice != 0 && config.finalPrice < config.initialPrice / MAX_PRICE_MULTIPLIER) return false;

        // Model-specific validation
        if (config.model == PricingModel.EXPONENTIAL && config.parameters.length == 0) return false;
        if (config.model == PricingModel.DUTCH_AUCTION && config.finalPrice >= config.initialPrice) return false;
        if (config.model == PricingModel.TIME_WEIGHTED && config.endTime == 0) return false;

        return true;
    }

    /**
     * @dev Get price information for display
     * @param config Price configuration
     * @param tokensSold Current tokens sold
     * @return currentPrice Current price
     * @return nextTierPrice Price at next tier (if applicable)
     * @return priceChange Change from initial price
     * @return changePercentage Percentage change from initial price
     */
    function getPriceInfo(
        PriceConfig memory config,
        uint256 tokensSold
    ) internal pure returns (
        uint256 currentPrice,
        uint256 nextTierPrice,
        uint256 priceChange,
        uint256 changePercentage
    ) {
        currentPrice = calculatePrice(config, tokensSold);

        // Calculate next tier price (10% more tokens sold)
        uint256 nextAmount = tokensSold.safeAdd(config.totalSupply.safeDiv(10));
        if (nextAmount <= config.totalSupply) {
            nextTierPrice = calculatePrice(config, nextAmount);
        } else {
            nextTierPrice = calculatePrice(config, config.totalSupply);
        }

        // Calculate price change
        if (currentPrice >= config.initialPrice) {
            priceChange = currentPrice.safeSub(config.initialPrice);
            changePercentage = priceChange.safeMul(PERCENTAGE).safeDiv(config.initialPrice);
        } else {
            priceChange = config.initialPrice.safeSub(currentPrice);
            changePercentage = priceChange.safeMul(PERCENTAGE).safeDiv(config.initialPrice);
        }
    }

    /**
     * @dev Calculate required reserves for bonding curve
     * @param targetPrice Desired price
     * @param currentSupply Current token supply
     * @param reserveRatio Reserve ratio (in basis points)
     * @return requiredReserve Required reserve amount
     */
    function calculateRequiredReserve(
        uint256 targetPrice,
        uint256 currentSupply,
        uint256 reserveRatio
    ) internal pure returns (uint256 requiredReserve) {
        if (reserveRatio == 0) revert PriceLib__InvalidParameters();

        requiredReserve = targetPrice.safeMul(currentSupply).safeMul(reserveRatio).safeDiv(PRICE_PRECISION);
    }
}
