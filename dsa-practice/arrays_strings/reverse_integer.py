# Reverse Integer
# Topic: Arrays & Strings, Math
# ------------------------------
# Given an integer, return it with its digits reversed.
# Note: the input is an integer, not a string.
#
# Example:
#   Input:  1234   →  Output: 4321
#   Input: -1234   →  Output: -4321
#   Input:  1200   →  Output: 21    (leading zeros dropped)
#
# Edge Cases to handle:
#   1. Negative numbers  →  -1234 should return -4321, not 4321
#   2. Trailing zeros    →  1200 should return 21, not 0021
#   3. Single digit      →  5 should return 5


# ------------------------------
# Approach 1: Manual Loop (Explicit)
# ------------------------------
# Step 1: Convert integer to string so we can index each digit.
# Step 2: Loop from the last index to the first using range in reverse.
# Step 3: Build a new output string by appending each digit.
# Step 4: Handle sign separately using abs(), restore it at the end.
# Step 5: Convert output back to integer (drops leading zeros automatically).
#
# Why a separate variable for the string?
#   Using the same variable name for both the integer and the string
#   causes a conflict — the loop variable overwrites your string.
#   Always use a different name (s, digits, etc.) when converting.
#
# How reverse range works:
#   range(len(s)-1, -1, -1)
#   start = last valid index  → len(s) - 1
#   stop  = one before index 0 → -1  (stop is exclusive)
#   step  = -1 to go backwards
#
#   s = "1234" → range(3, -1, -1) → indices 3, 2, 1, 0
#
# Time:  O(n) - visits every digit once
# Space: O(n) - output string grows with input size
#
# Note: O(n) is the theoretical minimum for this problem.
# You must look at every digit at least once, so no faster solution exists.

def reverse_integer_loop(n):
    sign = -1 if n < 0 else 1       # store the sign before removing it
    s = str(abs(n))                  # convert to string, abs() removes minus sign
    output = ''

    for i in range(len(s) - 1, -1, -1):   # loop from last index to 0
        output += s[i]                      # build reversed string

    return sign * int(output)        # int() drops leading zeros, restore sign


# ------------------------------
# Approach 2: Pythonic One-liner (Recommended)
# ------------------------------
# Python's slice syntax [::-1] reverses any sequence in one step.
# Cleaner and more readable — preferred in interviews after explaining
# the manual approach first.
#
# [::-1] breakdown:
#   start : not specified → from end
#   stop  : not specified → to beginning
#   step  : -1            → go backwards
#
# Time:  O(n) - slicing visits every character
# Space: O(n) - creates a new reversed string
#
# What to say in an interview:
#   "Both approaches are O(n) — reversing requires visiting every digit
#    once, so this is already optimal. I handle negatives with abs() and
#    restore the sign at the end. int() automatically drops any leading
#    zeros when converting back."

def reverse_integer(n):
    sign = -1 if n < 0 else 1       # store the sign
    reversed_val = int(str(abs(n))[::-1])   # reverse digits, int() drops leading zeros
    return sign * reversed_val


# ------------------------------
# Bonus: Returning a String (leading zeros matter)
# ------------------------------
# If the problem asked for a string return instead of an integer,
# int() won't help us drop leading zeros automatically.
# We use lstrip('0') to strip them manually.
#
# lstrip('0') removes all leading zeros from the left of a string:
#   "0021".lstrip('0')  →  "21"
#   "0000".lstrip('0')  →  ""   ← edge case, all zeros
#   "" or '0'           →  "0"  ← handle empty string safely

def reverse_integer_as_string(n):
    sign = '-' if n < 0 else ''
    reversed_str = str(abs(n))[::-1].lstrip('0') or '0'
    return sign + reversed_str


# ------------------------------
# Test Cases
# ------------------------------
if __name__ == "__main__":
    tests = [
        # (input, expected_int, expected_str, note)
        (1234,   4321,   "4321",  "standard case"),
        (-1234,  -4321,  "-4321", "negative number"),
        (1200,   21,     "21",    "trailing zeros become leading zeros"),
        (5,      5,      "5",     "single digit"),
        (0,      0,      "0",     "zero"),
        (100,    1,      "1",     "multiple trailing zeros"),
        (-900,   -9,     "-9",    "negative with trailing zeros"),
    ]

    print("Reverse Integer Results")
    print("-" * 55)
    for n, exp_int, exp_str, note in tests:
        loop     = reverse_integer_loop(n)
        oneliner = reverse_integer(n)
        as_str   = reverse_integer_as_string(n)
        status   = "PASS" if oneliner == exp_int else "FAIL"
        print(f"[{status}] Input: {n} ({note})")
        print(f"       Loop       : {loop}")
        print(f"       One-liner  : {oneliner}")
        print(f"       As String  : {as_str}")
        print()
