# Contains Duplicate
# LeetCode #217 - Easy
# Topic: Arrays, HashSet
# ----------------------
# Given an integer array, return True if any value appears
# at least twice. Return False if all elements are distinct.
#
# Example:
#   Input:  [1, 2, 3, 1]  →  True  (1 appears twice)
#   Input:  [1, 2, 3, 4]  →  False (all unique)


# ----------------------
# Approach 1: Brute Force
# ----------------------
# Compare every pair of elements using two nested loops.
# If any two elements are equal, return True.
# If we finish all comparisons with no match, return False.
#
# Time:  O(n²) - every pair is checked
# Space: O(1)  - no extra memory used

def contains_duplicate_brute(nums):
    for i in range(len(nums)):
        for j in range(i + 1, len(nums)):
            if nums[i] == nums[j]:
                return True
    return False  # only reached after ALL pairs are checked


# ----------------------
# Approach 2: Set (One-liner)
# ----------------------
# A set automatically removes duplicates.
# If the set is smaller than the original list,
# duplicates must have existed.
#
# Note: This always visits every element before returning.
#
# Time:  O(n) - building the set visits every element
# Space: O(n) - set stores up to n elements

def contains_duplicate_set(nums):
    return len(nums) != len(set(nums))


# ----------------------
# Approach 3: Set with Early Exit (Optimized)
# ----------------------
# Same idea as above but stops the moment a duplicate is found.
# More efficient in practice when duplicates appear early.
#
# Why set over hashmap?
#   We only care about existence, not storing any extra value.
#   A set is cleaner - it's a hashmap where the value doesn't matter.
#
# Time:  O(n) - worst case visits every element (no duplicates)
# Space: O(n) - set stores up to n elements

def contains_duplicate_optimized(nums):
    seen = set()
    for num in nums:
        if num in seen:   # already encountered this number
            return True
        seen.add(num)     # first time seeing it, store it
    return False


# ----------------------
# Test Cases
# ----------------------
if __name__ == "__main__":
    tests = [
        ([1, 2, 3, 1],    True),
        ([1, 2, 3, 4],    False),
        ([1, 1, 1, 3, 3], True),
        ([1],             False),
    ]

    print("Contains Duplicate Results")
    print("-" * 40)
    for nums, expected in tests:
        brute     = contains_duplicate_brute(nums)
        one_liner = contains_duplicate_set(nums)
        optimized = contains_duplicate_optimized(nums)
        status    = "PASS" if optimized == expected else "FAIL"
        print(f"[{status}] nums={nums}")
        print(f"       Brute Force  : {brute}")
        print(f"       Set One-liner: {one_liner}")
        print(f"       Set + Early  : {optimized}")
        print()
