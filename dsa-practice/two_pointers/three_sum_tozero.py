"""
3Sum (LeetCode 15): brute force vs sort + two pointers
=====================================================

Problem
-------
Given a list of integers, return all UNIQUE triplets [a, b, c] with a + b + c == 0.
The order of triplets does not matter, but no triplet may appear twice.

Example
-------
    [-1, 0, 1, 2, -1, -4]  ->  [[-1, -1, 2], [-1, 0, 1]]

Approach summary
----------------
| Approach              | Time    | Extra space            |
|-----------------------|---------|------------------------|
| Brute force (3 loops) | O(n^3)  | O(k) for the result set|
| Sort + two pointers   | O(n^2)  | O(1) auxiliary*        |

* Excluding the output list and the sort's internal buffer. Python's sort can use
  up to O(n) temporary space in the worst case, so "O(1) auxiliary" assumes an
  in-place sort. Say this out loud in an interview if asked.

Why two pointers works
----------------------
1. Sort the list. Now "too small" and "too big" have a direction.
2. Fix the first number nums[i]. We now need a pair in the REST of the list that
   sums to -nums[i]. That is the sorted two-sum problem.
3. Put one pointer at each end of the remaining part:
       total < 0  -> sum is too small, move the left pointer right (bigger number)
       total > 0  -> sum is too big,   move the right pointer left (smaller number)
       total == 0 -> record it, move both pointers inward
4. Each pointer only moves in one direction, so the inner scan is O(n).
   n values of i  x  O(n) scan  =  O(n^2).

Skipping duplicates (the part people get wrong)
-----------------------------------------------
- Same first number: if nums[i] == nums[i-1], skip i. Otherwise the same triplets
  would be found again.
- Same second number: after recording a triplet and moving left forward, keep
  moving left while it equals the value before it.
  (The right side needs no extra skip: once left moves, the sum no longer
  matches and the loop adjusts right by itself.)
"""

import random


# ---------------------------------------------------------------------------
# 1. Brute force: O(n^3) time
# ---------------------------------------------------------------------------
def three_sum_brute(nums):
    """Try every set of three positions. A set of sorted tuples removes duplicates."""
    result = set()
    n = len(nums)
    for i in range(n):
        for j in range(i + 1, n):
            for k in range(j + 1, n):
                if nums[i] + nums[j] + nums[k] == 0:
                    triplet = tuple(sorted([nums[i], nums[j], nums[k]]))
                    result.add(triplet)
    return [list(t) for t in result]


# ---------------------------------------------------------------------------
# 2. Sort + two pointers: O(n^2) time
# ---------------------------------------------------------------------------
def three_sum(nums):
    """
    Note: nums.sort() sorts the caller's list IN PLACE (it mutates the input).
    If the caller needs the original order, pass a copy: three_sum(list(nums)).
    """
    nums.sort()
    result = []

    for i in range(len(nums) - 2):
        # Skip a repeated first number, otherwise we would repeat triplets.
        if i > 0 and nums[i] == nums[i - 1]:
            continue

        left = i + 1
        right = len(nums) - 1

        while left < right:
            total = nums[i] + nums[left] + nums[right]

            if total == 0:
                result.append([nums[i], nums[left], nums[right]])
                left += 1
                right -= 1
                # Skip repeated second numbers.
                while left < right and nums[left] == nums[left - 1]:
                    left += 1
            elif total < 0:
                left += 1       # sum too small, need a bigger number
            else:
                right -= 1      # sum too big, need a smaller number

    return result


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
def normalize(triplets):
    """Compare results regardless of triplet order."""
    return sorted(sorted(t) for t in triplets)


def run_tests():
    cases = [
        # (input, expected, what it checks)
        ([-1, 0, 1, 2, -1, -4], [[-1, -1, 2], [-1, 0, 1]], "classic example"),
        ([], [], "empty list"),
        ([0], [], "fewer than 3 items"),
        ([0, 0], [], "two items"),
        ([0, 0, 0], [[0, 0, 0]], "exactly three zeros"),
        ([0, 0, 0, 0, 0], [[0, 0, 0]], "many zeros, one triplet only"),
        ([1, 2, 3], [], "no solution"),
        ([-1, -2, -3], [], "all negative"),
        ([-2, 0, 0, 2, 2], [[-2, 0, 2]], "duplicates must not repeat triplets"),
        ([-4, -2, -2, -2, 0, 1, 2, 2, 2, 3, 3, 4, 4, 6, 6],
         [[-4, -2, 6], [-4, 0, 4], [-4, 1, 3], [-4, 2, 2],
          [-2, -2, 4], [-2, 0, 2]],
         "many duplicates on every side"),
    ]

    for nums, expected, label in cases:
        brute = normalize(three_sum_brute(list(nums)))
        fast = normalize(three_sum(list(nums)))     # copy, because it sorts in place
        assert brute == normalize(expected), f"brute failed: {label}"
        assert fast == normalize(expected), f"two-pointer failed: {label}"
        print(f"ok  {label}")


def random_check(rounds=2000):
    """Compare both solutions on random inputs. Disagreement would mean a bug."""
    random.seed(7)
    for _ in range(rounds):
        nums = [random.randint(-6, 6) for _ in range(random.randint(0, 12))]
        assert normalize(three_sum_brute(list(nums))) == normalize(three_sum(list(nums))), nums
    print(f"ok  {rounds} random inputs agree with brute force")


if __name__ == "__main__":
    run_tests()
    random_check()
    print("all checks passed")
