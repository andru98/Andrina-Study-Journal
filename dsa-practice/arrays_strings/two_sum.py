# Two Sum
# LeetCode #1 - Easy
# Topic: Arrays, HashMap
# ---------------------
# Given an array of integers and a target, return the indices
# of the two numbers that add up to the target.
# Each input has exactly one solution.
# You cannot use the same element twice.
#
# Example:
#   Input:  nums = [2, 7, 11, 15], target = 9
#   Output: [0, 1]  →  2 + 7 = 9


# ---------------------
# Approach 1: Brute Force
# ---------------------
# Check every possible pair using two nested loops.
# For each pair (i, j), check if they sum to the target.
#
# Time:  O(n²) - every pair is checked
# Space: O(1)  - no extra memory used

def two_sum_brute(nums, target):
    n = len(nums)
    for i in range(n):
        for j in range(i + 1, n):
            if nums[i] + nums[j] == target:
                return [i, j]
    return []


# ---------------------
# Approach 2: HashMap (Optimized)
# ---------------------
# As we iterate, we store each number and its index in a dictionary.
# For every number, we check if its complement (target - number)
# has already been seen. If yes, we have our answer.
#
# Why not two pointers?
#   Two pointers requires a sorted array. Sorting costs O(n log n),
#   which is worse than the O(n) we get with a hashmap here.
#
# Time:  O(n) - single pass through the array
# Space: O(n) - dictionary stores up to n elements

def two_sum_hashmap(nums, target):
    seen = {}  # stores number → index

    for i, num in enumerate(nums):
        complement = target - num

        if complement in seen:
            return [seen[complement], i]

        seen[num] = i  # haven't found the pair yet, store for later

    return []


# ---------------------
# Test Cases
# ---------------------
if __name__ == "__main__":
    tests = [
        ([2, 7, 11, 15], 9,  [0, 1]),
        ([3, 2, 4],      6,  [1, 2]),
        ([3, 3],         6,  [0, 1]),
        ([1, 5, 3, 7],   10, [2, 3]),
    ]

    print("Two Sum Results")
    print("-" * 40)
    for nums, target, expected in tests:
        brute = two_sum_brute(nums, target)
        optimized = two_sum_hashmap(nums, target)
        status = "PASS" if optimized == expected else "FAIL"
        print(f"[{status}] nums={nums}, target={target}")
        print(f"       Brute Force : {brute}")
        print(f"       HashMap     : {optimized}")
        print()
