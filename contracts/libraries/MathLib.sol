// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MathLib
 * @dev Advanced mathematical utilities library for presale calculations with overflow protection
 * @author EpicChainLabs
 */
library MathLib {
    // ============ Constants ============

    uint256 private constant DECIMALS_18 = 10**18;
    uint256 private constant DECIMALS_8 = 10**8;
    uint256 private constant DECIMALS_6 = 10**6;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant PERCENTAGE = 100;
    uint256 private constant MAX_UINT256 = type(uint256).max;
    uint256 private constant PRICE_PRECISION = 10**18;
    uint256 private constant SQRT_PRECISION = 10**9;

    // ============ Errors ============

    error MathLib__DivisionByZero();
    error MathLib__Overflow();
    error MathLib__InvalidInput();
    error MathLib__PrecisionLoss();
    error MathLib__NegativeResult();

    // ============ Basic Math Operations ============

    /**
     * @dev Safe addition with overflow check
     * @param a First number
     * @param b Second number
     * @return result Sum of a and b
     */
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            result = a + b;
            if (result < a) revert MathLib__Overflow();
        }
    }

    /**
     * @dev Safe subtraction with underflow check
     * @param a First number
     * @param b Second number
     * @return result Difference of a and b
     */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (b > a) revert MathLib__NegativeResult();
        unchecked {
            result = a - b;
        }
    }

    /**
     * @dev Safe multiplication with overflow check
     * @param a First number
     * @param b Second number
     * @return result Product of a and b
     */
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (a == 0) return 0;
        unchecked {
            result = a * b;
            if (result / a != b) revert MathLib__Overflow();
        }
    }

    /**
     * @dev Safe division with zero check
     * @param a Dividend
     * @param b Divisor
     * @return result Quotient of a and b
     */
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (b == 0) revert MathLib__DivisionByZero();
        result = a / b;
    }

    /**
     * @dev Safe modulo operation
     * @param a Dividend
     * @param b Divisor
     * @return result Remainder of a divided by b
     */
    function safeMod(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (b == 0) revert MathLib__DivisionByZero();
        result = a % b;
    }

    // ============ Advanced Math Operations ============

    /**
     * @dev Calculate percentage of a number
     * @param amount Base amount
     * @param percentage Percentage (e.g., 15 for 15%)
     * @return result Percentage of the amount
     */
    function calculatePercentage(uint256 amount, uint256 percentage) internal pure returns (uint256 result) {
        if (amount == 0 || percentage == 0) return 0;
        result = safeMul(amount, percentage) / PERCENTAGE;
    }

    /**
     * @dev Calculate basis points of a number
     * @param amount Base amount
     * @param basisPoints Basis points (e.g., 150 for 1.5%)
     * @return result Basis points of the amount
     */
    function calculateBasisPoints(uint256 amount, uint256 basisPoints) internal pure returns (uint256 result) {
        if (amount == 0 || basisPoints == 0) return 0;
        result = safeMul(amount, basisPoints) / BASIS_POINTS;
    }

    /**
     * @dev Calculate compound interest
     * @param principal Initial amount
     * @param rate Interest rate (in basis points)
     * @param time Time periods
     * @return result Final amount after compound interest
     */
    function calculateCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 time
    ) internal pure returns (uint256 result) {
        if (principal == 0 || rate == 0 || time == 0) return principal;

        result = principal;
        for (uint256 i = 0; i < time; i++) {
            result = result + calculateBasisPoints(result, rate);
        }
    }

    /**
     * @dev Calculate square root using Newton's method
     * @param x Number to find square root of
     * @return result Square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) return 0;

        // Initial guess
        result = x;
        uint256 k = (x + 1) / 2;

        while (k < result) {
            result = k;
            k = (x / k + k) / 2;
        }
    }

    /**
     * @dev Calculate power function (x^y) with gas optimization
     * @param base Base number
     * @param exponent Exponent
     * @return result Base raised to the power of exponent
     */
    function pow(uint256 base, uint256 exponent) internal pure returns (uint256 result) {
        if (exponent == 0) return 1;
        if (base == 0) return 0;
        if (base == 1) return 1;

        result = 1;
        uint256 currentBase = base;

        while (exponent > 0) {
            if (exponent % 2 == 1) {
                result = safeMul(result, currentBase);
            }
            currentBase = safeMul(currentBase, currentBase);
            exponent /= 2;
        }
    }

    // ============ Price Calculation Functions ============

    /**
     * @dev Calculate dynamic price based on tokens sold
     * @param initialPrice Starting price
     * @param tokensSold Number of tokens already sold
     * @param totalSupply Total tokens available
     * @param priceIncreaseRate Rate of price increase (basis points)
     * @return newPrice Updated price
     */
    function calculateDynamicPrice(
        uint256 initialPrice,
        uint256 tokensSold,
        uint256 totalSupply,
        uint256 priceIncreaseRate
    ) internal pure returns (uint256 newPrice) {
        if (totalSupply == 0) revert MathLib__DivisionByZero();

        // Calculate percentage of tokens sold
        uint256 soldPercentage = safeMul(tokensSold, BASIS_POINTS) / totalSupply;

        // Calculate price increase
        uint256 priceIncrease = safeMul(initialPrice, safeMul(soldPercentage, priceIncreaseRate)) / (BASIS_POINTS * BASIS_POINTS);

        newPrice = safeAdd(initialPrice, priceIncrease);
    }

    /**
     * @dev Calculate exponential price increase
     * @param initialPrice Starting price
     * @param tokensSold Number of tokens already sold
     * @param totalSupply Total tokens available
     * @param multiplier Exponential multiplier
     * @return newPrice Updated price with exponential growth
     */
    function calculateExponentialPrice(
        uint256 initialPrice,
        uint256 tokensSold,
        uint256 totalSupply,
        uint256 multiplier
    ) internal pure returns (uint256 newPrice) {
        if (totalSupply == 0) revert MathLib__DivisionByZero();

        uint256 soldRatio = safeMul(tokensSold, PRICE_PRECISION) / totalSupply;
        uint256 exponent = safeMul(soldRatio, multiplier) / PRICE_PRECISION;

        // Simplified exponential calculation (e^x ≈ 1 + x + x²/2)
        uint256 exponentialFactor = PRICE_PRECISION + exponent + safeMul(exponent, exponent) / (2 * PRICE_PRECISION);

        newPrice = safeMul(initialPrice, exponentialFactor) / PRICE_PRECISION;
    }

    /**
     * @dev Calculate logarithmic price increase
     * @param initialPrice Starting price
     * @param tokensSold Number of tokens already sold
     * @param totalSupply Total tokens available
     * @param logBase Logarithmic base
     * @return newPrice Updated price with logarithmic growth
     */
    function calculateLogarithmicPrice(
        uint256 initialPrice,
        uint256 tokensSold,
        uint256 totalSupply,
        uint256 logBase
    ) internal pure returns (uint256 newPrice) {
        if (totalSupply == 0 || logBase <= 1) revert MathLib__InvalidInput();

        if (tokensSold == 0) return initialPrice;

        // Simplified logarithmic calculation
        uint256 soldRatio = safeMul(tokensSold, PRICE_PRECISION) / totalSupply;
        uint256 logValue = naturalLog(soldRatio + PRICE_PRECISION) - naturalLog(PRICE_PRECISION);

        uint256 priceIncrease = safeMul(initialPrice, logValue) / (PRICE_PRECISION * logBase);
        newPrice = safeAdd(initialPrice, priceIncrease);
    }

    /**
     * @dev Calculate tokens to receive for given payment
     * @param paymentAmount Amount of payment token
     * @param paymentTokenPrice Price of payment token in USD
     * @param tokenPrice Price of EPCS token in USD
     * @param paymentDecimals Decimals of payment token
     * @return tokenAmount Number of tokens to receive
     */
    function calculateTokensToReceive(
        uint256 paymentAmount,
        uint256 paymentTokenPrice,
        uint256 tokenPrice,
        uint256 paymentDecimals
    ) internal pure returns (uint256 tokenAmount) {
        if (tokenPrice == 0) revert MathLib__DivisionByZero();

        // Normalize payment amount to 18 decimals
        uint256 normalizedPayment = normalizeDecimals(paymentAmount, paymentDecimals, 18);

        // Calculate USD value of payment
        uint256 usdValue = safeMul(normalizedPayment, paymentTokenPrice) / PRICE_PRECISION;

        // Calculate tokens to receive
        tokenAmount = safeMul(usdValue, PRICE_PRECISION) / tokenPrice;
    }

    /**
     * @dev Calculate payment amount needed for desired tokens
     * @param tokenAmount Desired number of tokens
     * @param paymentTokenPrice Price of payment token in USD
     * @param tokenPrice Price of EPCS token in USD
     * @param paymentDecimals Decimals of payment token
     * @return paymentAmount Required payment amount
     */
    function calculatePaymentAmount(
        uint256 tokenAmount,
        uint256 paymentTokenPrice,
        uint256 tokenPrice,
        uint256 paymentDecimals
    ) internal pure returns (uint256 paymentAmount) {
        if (paymentTokenPrice == 0) revert MathLib__DivisionByZero();

        // Calculate USD value needed
        uint256 usdValue = safeMul(tokenAmount, tokenPrice) / PRICE_PRECISION;

        // Calculate payment amount in payment token
        uint256 normalizedPayment = safeMul(usdValue, PRICE_PRECISION) / paymentTokenPrice;

        // Convert to payment token decimals
        paymentAmount = normalizeDecimals(normalizedPayment, 18, paymentDecimals);
    }

    // ============ Decimal Conversion Functions ============

    /**
     * @dev Normalize token amount from one decimal precision to another
     * @param amount Token amount
     * @param fromDecimals Source decimal precision
     * @param toDecimals Target decimal precision
     * @return normalizedAmount Normalized amount
     */
    function normalizeDecimals(
        uint256 amount,
        uint256 fromDecimals,
        uint256 toDecimals
    ) internal pure returns (uint256 normalizedAmount) {
        if (fromDecimals == toDecimals) {
            return amount;
        }

        if (fromDecimals > toDecimals) {
            uint256 divisor = pow(10, fromDecimals - toDecimals);
            normalizedAmount = amount / divisor;
        } else {
            uint256 multiplier = pow(10, toDecimals - fromDecimals);
            normalizedAmount = safeMul(amount, multiplier);
        }
    }

    /**
     * @dev Convert price from one decimal precision to another
     * @param price Original price
     * @param fromDecimals Source decimal precision
     * @param toDecimals Target decimal precision
     * @return convertedPrice Converted price
     */
    function convertPriceDecimals(
        uint256 price,
        uint256 fromDecimals,
        uint256 toDecimals
    ) internal pure returns (uint256 convertedPrice) {
        return normalizeDecimals(price, fromDecimals, toDecimals);
    }

    // ============ Utility Functions ============

    /**
     * @dev Get minimum of two numbers
     * @param a First number
     * @param b Second number
     * @return result Minimum value
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = a < b ? a : b;
    }

    /**
     * @dev Get maximum of two numbers
     * @param a First number
     * @param b Second number
     * @return result Maximum value
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = a > b ? a : b;
    }

    /**
     * @dev Get absolute difference between two numbers
     * @param a First number
     * @param b Second number
     * @return result Absolute difference
     */
    function absDiff(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = a > b ? a - b : b - a;
    }

    /**
     * @dev Check if number is within range
     * @param value Number to check
     * @param minValue Minimum value
     * @param maxValue Maximum value
     * @return inRange Whether value is within range
     */
    function isInRange(uint256 value, uint256 minValue, uint256 maxValue) internal pure returns (bool inRange) {
        inRange = value >= minValue && value <= maxValue;
    }

    /**
     * @dev Calculate weighted average
     * @param values Array of values
     * @param weights Array of weights
     * @return average Weighted average
     */
    function weightedAverage(uint256[] memory values, uint256[] memory weights) internal pure returns (uint256 average) {
        if (values.length != weights.length || values.length == 0) revert MathLib__InvalidInput();

        uint256 totalWeightedValue = 0;
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < values.length; i++) {
            totalWeightedValue = safeAdd(totalWeightedValue, safeMul(values[i], weights[i]));
            totalWeight = safeAdd(totalWeight, weights[i]);
        }

        if (totalWeight == 0) revert MathLib__DivisionByZero();
        average = totalWeightedValue / totalWeight;
    }

    /**
     * @dev Calculate natural logarithm (simplified approximation)
     * @param x Input value (in 18 decimal precision)
     * @return result Natural logarithm of x
     */
    function naturalLog(uint256 x) internal pure returns (uint256 result) {
        if (x <= 0) revert MathLib__InvalidInput();
        if (x == PRICE_PRECISION) return 0;

        // Taylor series approximation for ln(1+x) where x is small
        // ln(1+x) ≈ x - x²/2 + x³/3 - x⁴/4 + ...

        if (x > PRICE_PRECISION) {
            // For x > 1, use ln(x) = ln(1 + (x-1))
            uint256 delta = x - PRICE_PRECISION;
            uint256 normalized = safeMul(delta, PRICE_PRECISION) / x;

            result = normalized;
            uint256 term = normalized;

            for (uint256 i = 2; i <= 10; i++) {
                term = safeMul(term, normalized) / PRICE_PRECISION;
                if (i % 2 == 0) {
                    if (result > term / i) {
                        result -= term / i;
                    }
                } else {
                    result += term / i;
                }
            }
        } else {
            // For 0 < x < 1
            uint256 invX = safeMul(PRICE_PRECISION, PRICE_PRECISION) / x;
            result = naturalLog(invX);
            // ln(1/x) = -ln(x), but we need to handle this carefully with unsigned integers
            // This is a simplified implementation
        }
    }

    /**
     * @dev Round number to specified decimal places
     * @param value Number to round
     * @param decimals Number of decimal places
     * @return rounded Rounded number
     */
    function roundToDecimals(uint256 value, uint256 decimals) internal pure returns (uint256 rounded) {
        if (decimals >= 18) return value;

        uint256 factor = pow(10, 18 - decimals);
        rounded = (value + factor / 2) / factor * factor;
    }

    /**
     * @dev Calculate average of an array of numbers
     * @param values Array of values
     * @return average Simple average
     */
    function average(uint256[] memory values) internal pure returns (uint256 average) {
        if (values.length == 0) revert MathLib__InvalidInput();

        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            sum = safeAdd(sum, values[i]);
        }

        average = sum / values.length;
    }

    /**
     * @dev Calculate median of an array of numbers
     * @param values Array of values (will be modified for sorting)
     * @return median Median value
     */
    function median(uint256[] memory values) internal pure returns (uint256 median) {
        if (values.length == 0) revert MathLib__InvalidInput();

        // Simple bubble sort for small arrays
        for (uint256 i = 0; i < values.length; i++) {
            for (uint256 j = i + 1; j < values.length; j++) {
                if (values[i] > values[j]) {
                    uint256 temp = values[i];
                    values[i] = values[j];
                    values[j] = temp;
                }
            }
        }

        if (values.length % 2 == 0) {
            median = (values[values.length / 2 - 1] + values[values.length / 2]) / 2;
        } else {
            median = values[values.length / 2];
        }
    }
}
