# Best Time to Buy and Sell Stock
# LeetCode #121 - Easy
# Topic: Arrays, Sliding Window
# ------------------------------
# Given an array where prices[i] is the stock price on day i,
# return the maximum profit you can achieve.
# You must buy before you sell.
# If no profit is possible, return 0.
#
# Example:
#   Input:  [7, 1, 5, 3, 6, 4]  →  5  (buy at 1, sell at 6)
#   Input:  [7, 6, 4, 3, 1]     →  0  (prices only go down)


# ------------------------------
# Approach 1: Brute Force
# ------------------------------
# Try every possible pair of buy day and sell day.
# For each pair, calculate the profit and keep track of the maximum.
# The sell day must always come after the buy day.
#
# Time:  O(n²) - every pair of days is checked
# Space: O(1)  - only tracking the max profit

def max_profit_brute(prices):
    max_profit = 0

    for i in range(len(prices)):              # buy day
        for j in range(i + 1, len(prices)):   # sell day (must be after buy)
            profit = prices[j] - prices[i]
            if profit > max_profit:
                max_profit = profit

    return max_profit


# ------------------------------
# Approach 2: Sliding Window (Optimized)
# ------------------------------
# The key insight: to maximize profit on any given sell day,
# you want to have bought at the lowest price seen so far.
#
# So as we slide through the array, we track two things:
#   1. min_price  - the cheapest buy price seen so far (left pointer)
#   2. max_profit - the best profit seen so far
#
# Every day we ask two questions:
#   - Is today cheaper than my best buy price? → update min_price
#   - Is today's profit better than my best?   → update max_profit
#
# How the window works:
#   Left pointer  = cheapest price seen so far (buy day)
#   Right pointer = today's price (sell day)
#   Left only moves when a cheaper price is found.
#   Right moves forward every single day.
#
# Time:  O(n) - single pass through the array
# Space: O(1) - only two variables tracked

def max_profit(prices):
    min_price  = prices[0]   # best buy price seen so far
    max_profit = 0           # best profit seen so far

    for i in range(len(prices)):
        if prices[i] < min_price:
            min_price = prices[i]           # found a cheaper buy day

        if prices[i] - min_price > max_profit:
            max_profit = prices[i] - min_price   # found a better profit

    return max_profit


# ------------------------------
# Test Cases
# ------------------------------
if __name__ == "__main__":
    tests = [
        ([7, 1, 5, 3, 6, 4], 5),
        ([7, 6, 4, 3, 1],    0),
        ([1, 2],             1),
        ([2, 4, 1],          2),
        ([3, 3, 3],          0),
    ]

    print("Buy and Sell Stock Results")
    print("-" * 40)
    for prices, expected in tests:
        brute     = max_profit_brute(prices)
        optimized = max_profit(prices)
        status    = "PASS" if optimized == expected else "FAIL"
        print(f"[{status}] prices={prices}")
        print(f"       Brute Force    : {brute}")
        print(f"       Sliding Window : {optimized}")
        print()
