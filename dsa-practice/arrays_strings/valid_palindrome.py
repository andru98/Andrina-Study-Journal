# Valid Palindrome
# LeetCode #125 - Easy
# Topic: Arrays & Strings, Two Pointers
# --------------------------------------
# Given a string, return True if it is a palindrome considering
# only alphanumeric characters and ignoring case.
# A palindrome reads the same forward and backward.
#
# Example:
#   Input:  "A man, a plan, a canal: Panama"  →  True
#   Input:  "race a car"                       →  False
#
# Key string methods used:
#   str.isalnum() → True if character is a letter or digit
#   str.lower()   → converts character to lowercase
#   s[::-1]       → reverses a string (slice with step -1)


# --------------------------------------
# Approach 1: Brute Force - Clean then Reverse
# --------------------------------------
# Step 1: Remove all non-alphanumeric characters and lowercase everything.
# Step 2: Compare the cleaned string to its reverse.
#
# Time:  O(n) - one pass to clean, one to reverse
# Space: O(n) - cleaned string stored in memory

def is_palindrome_brute(s):
    cleaned = ""
    for char in s:
        if char.isalnum():             # skip spaces, commas, colons etc.
            cleaned += char.lower()    # normalize so 'A' == 'a'

    return cleaned == cleaned[::-1]    # compare to reverse


# --------------------------------------
# Approach 2: Two Pointers (Optimized)
# --------------------------------------
# Place one pointer at the left end, one at the right end.
# Skip any non-alphanumeric characters on both sides.
# Compare the characters at both pointers.
# If they don't match, it's not a palindrome.
# Move both pointers inward and repeat until they cross.
#
# Why no sorting needed?
#   Two pointers here works on positions, not values.
#   We're comparing left vs right characters, not magnitudes.
#   Sorting is only needed when we need directional decisions
#   based on numeric comparison (like Two Sum II).
#
# Time:  O(n) - each character visited at most once
# Space: O(1) - no extra data structure, just two index pointers

def is_palindrome(s):
    left, right = 0, len(s) - 1

    while left < right:
        # skip non-alphanumeric on the left
        while left < right and not s[left].isalnum():
            left += 1

        # skip non-alphanumeric on the right
        while left < right and not s[right].isalnum():
            right -= 1

        # compare valid characters (ignore case)
        if s[left].lower() != s[right].lower():
            return False   # mismatch found, not a palindrome

        left += 1    # move inward
        right -= 1   # move inward

    return True   # all characters matched


# --------------------------------------
# Test Cases
# --------------------------------------
if __name__ == "__main__":
    tests = [
        ("A man, a plan, a canal: Panama", True),
        ("race a car",                     False),
        (" ",                              True),
        ("Was it a car or a cat I saw?",   True),
        ("No lemon, no melon",             True),
        ("hello",                          False),
    ]

    print("Valid Palindrome Results")
    print("-" * 40)
    for s, expected in tests:
        brute     = is_palindrome_brute(s)
        optimized = is_palindrome(s)
        status    = "PASS" if optimized == expected else "FAIL"
        print(f"[{status}] Input: \"{s}\"")
        print(f"       Brute Force  : {brute}")
        print(f"       Two Pointers : {optimized}")
        print()
