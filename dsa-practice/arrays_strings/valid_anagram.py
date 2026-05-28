# Valid Anagram
# LeetCode #242 - Easy
# Topic: Arrays & Strings, HashMap, Sorting
# ------------------------------------------
# Given two strings, return True if one is an anagram of the other.
# An anagram uses the same characters the same number of times,
# just in a different order.
#
# Example:
#   Input:  str1 = "listen", str2 = "silent"  →  True
#   Input:  str1 = "hello",  str2 = "world"   →  False
#
# Real world relevance for Data Engineering:
#   - Deduplicating records where column order varies
#   - Comparing schema fields that may be reordered
#   - Grouping similar string keys in pipelines


# ------------------------------------------
# Approach 1: Sorting
# ------------------------------------------
# Sort both strings alphabetically and compare.
# If they are anagrams, sorted versions will be identical.
#
# Why it works:
#   "listen" → sorted → "eilnst"
#   "silent" → sorted → "eilnst"
#   "eilnst" == "eilnst" → True
#
# Time:  O(n log n) - sorting dominates
# Space: O(n)       - sorted() creates a new list
#
# When to use:
#   Simple and readable. Good starting point in an interview.
#   Mention this first, then offer the O(n) solution.

def is_anagram_sorted(str1, str2):
    # different lengths can never be anagrams - early exit
    if len(str1) != len(str2):
        return False

    return sorted(str1) == sorted(str2)


# ------------------------------------------
# Approach 2: Counter / Frequency Map (Optimized)
# ------------------------------------------
# Count the frequency of each character in both strings.
# If the frequency maps are identical, they are anagrams.
#
# Why it works:
#   Counter("listen") → {'l':1, 'i':1, 's':1, 't':1, 'e':1, 'n':1}
#   Counter("silent") → {'s':1, 'i':1, 'l':1, 'e':1, 'n':1, 't':1}
#   same map → True
#
# Why Counter over sorting:
#   Sorting rearranges characters to compare → O(n log n)
#   Counter just counts in one pass → O(n)
#   Same space cost, better time complexity.
#
# Time:  O(n) - single pass through each string
# Space: O(n) - counter stores up to 26 characters (alphabet)
#
# Interview tip:
#   Start with sorting, then say "we can do better with a
#   frequency map in O(n)" - shows progressive thinking.

from collections import Counter

def is_anagram_counter(str1, str2):
    # different lengths can never be anagrams - early exit
    if len(str1) != len(str2):
        return False

    return Counter(str1) == Counter(str2)


# ------------------------------------------
# Edge Cases Worth Knowing
# ------------------------------------------
# 1. Different lengths        → always False (caught early)
# 2. Empty strings            → True (both empty, technically anagrams)
# 3. Same string              → True ("abc" and "abc")
# 4. Case sensitivity         → "Listen" vs "Silent" → False by default
#                               lowercase both if case should be ignored
# 5. Spaces and punctuation   → "conversation" vs "voices rant on"
#                               strip spaces if needed
# 6. Unicode / special chars  → Counter handles these naturally
# 7. Single character         → "a" vs "a" → True, "a" vs "b" → False


# ------------------------------------------
# Test Cases
# ------------------------------------------
if __name__ == "__main__":
    tests = [
        # (str1, str2, expected, note)
        ("listen",       "silent",       True,  "classic anagram"),
        ("hello",        "world",        False, "no match"),
        ("",             "",             True,  "both empty strings"),
        ("a",            "a",            True,  "single same character"),
        ("a",            "b",            False, "single different character"),
        ("abc",          "abc",          True,  "identical strings"),
        ("abc",          "ab",           False, "different lengths"),
        ("anagram",      "nagaram",      True,  "leetcode example"),
        ("rat",          "car",          False, "same chars different count"),
        ("Listen",       "Silent",       False, "case sensitive by default"),
        ("conversation", "voicesranton", True,  "longer anagram"),
    ]

    print("Valid Anagram Results")
    print("-" * 55)
    for str1, str2, expected, note in tests:
        sorting = is_anagram_sorted(str1, str2)
        counter = is_anagram_counter(str1, str2)
        status  = "PASS" if counter == expected else "FAIL"
        print(f"[{status}] \"{str1}\" vs \"{str2}\" ({note})")
        print(f"       Sorting : {sorting}")
        print(f"       Counter : {counter}")
        print()
