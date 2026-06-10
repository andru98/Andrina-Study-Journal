# ============================================================
# Problem : Group Anagrams
# Source  : LeetCode 49
# Link    : https://leetcode.com/problems/group-anagrams/
# Topic   : Arrays & Strings / HashMap / Sorting
# Level   : Medium
# Date    : 2026-06-09
# ============================================================

# PROBLEM STATEMENT:
# Given an array of strings, group all anagrams together.
# Two strings are anagrams if they contain the same characters
# in any order. Return the groups in any order.
#
# Input:  ["eat", "tea", "tan", "ate", "nat", "bat"]
# Output: [["eat","tea","ate"], ["tan","nat"], ["bat"]]

# ============================================================
# APPROACH — HashMap with sorted key:
# Key insight: two words are anagrams if and only if their
# sorted letters are identical.
#   "eat" → sorted → "aet"
#   "tea" → sorted → "aet"  ← same key, same group
#   "tan" → sorted → "ant"  ← different key, different group
#
# Use a defaultdict(list) to group words by their sorted key.
# The sorted key is just an address label — the original word
# is always what gets stored in the list.
#
# Step 1: For each word, compute key = "".join(sorted(word))
# Step 2: Append original word to group[key]
# Step 3: Return all groups as a list
# ============================================================

from collections import defaultdict
from typing import List


def groupAnagrams(strs: List[str]) -> List[List[str]]:
    group = defaultdict(list)

    for word in strs:
        key = "".join(sorted(word))  # sort letters to make the grouping key
        group[key].append(word)      # original word stored, not the sorted key

    return list(group.values())


# ============================================================
# EXAMPLE WALKTHROUGH:
# strs = ["eat", "tea", "tan", "ate", "nat", "bat"]
#
# Iteration 1: word="eat"  → key="aet" → group={"aet": ["eat"]}
# Iteration 2: word="tea"  → key="aet" → group={"aet": ["eat","tea"]}
# Iteration 3: word="tan"  → key="ant" → group={"aet": ["eat","tea"], "ant": ["tan"]}
# Iteration 4: word="ate"  → key="aet" → group={"aet": ["eat","tea","ate"], "ant": ["tan"]}
# Iteration 5: word="nat"  → key="ant" → group={"aet": [...], "ant": ["tan","nat"]}
# Iteration 6: word="bat"  → key="abt" → group={"aet": [...], "ant": [...], "abt": ["bat"]}
#
# return list(group.values())
# → [["eat","tea","ate"], ["tan","nat"], ["bat"]]
# ============================================================

# ============================================================
# COMPLEXITY:
# Time  : O(n * k log k)
#         n = number of words, k = length of longest word
#         sorting each word costs k log k, done n times
#         NOT O(n log n) — we sort letters inside each word,
#         not the list of words itself
# Space : O(n * k) — all words stored once in the hashmap
# ============================================================

# ============================================================
# EDGE CASES TO KEEP IN MIND:
# 1. Single character words — sorted("a") = ["a"], key = "a"
#    Works correctly, no special handling needed.
# 2. Empty string — sorted("") = [], "".join([]) = ""
#    All empty strings map to key "" and group together.
#    Correct behavior per problem constraints.
# 3. Single word input — ["bat"]
#    Returns [["bat"]] — one group of one. Correct.
# 4. All words are anagrams — ["eat","tea","ate"]
#    All map to "aet", returns one group. Correct.
# 5. No anagram pairs — ["cat","dog","bird"]
#    Each word is its own group. Returns [["cat"],["dog"],["bird"]].
# 6. group.values() returns a dict_values view object — must
#    wrap with list() to return the correct type for LeetCode.
# ============================================================

# ============================================================
# ALTERNATIVE APPROACH — tuple key (equally valid):
# key = tuple(sorted(word))
# Tuples are hashable so they work as dict keys.
# ("a","e","t") instead of "aet" — same logic, slightly
# less readable. Stick with string join in interviews.
# ============================================================

# ============================================================
# PATTERN TO REMEMBER:
# Anagram grouping = sorted letters as hashmap key.
# The key is just a label — always store the original word.
# defaultdict(list) handles missing keys automatically —
# no need to check if key exists before appending.
#
# Same pattern applies to:
# - Grouping events by user_id in DE pipelines
# - Grouping transactions by category
# - Any problem where you need to bucket items by a derived key
# ============================================================


# Quick test
if __name__ == "__main__":
    print(groupAnagrams(["eat", "tea", "tan", "ate", "nat", "bat"]))
    # Expected: [['eat', 'tea', 'ate'], ['tan', 'nat'], ['bat']]

    print(groupAnagrams([""]))
    # Expected: [['']]

    print(groupAnagrams(["a"]))
    # Expected: [['a']]
