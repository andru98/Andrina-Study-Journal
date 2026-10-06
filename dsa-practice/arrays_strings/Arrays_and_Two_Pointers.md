# Arrays & Two Pointers — Interview Notes

Personal prep notes from my DSA study plan for Data Engineer interviews at FAANG and top tech companies. Arrays are almost always where a technical interview starts — they're the "can you actually code" filter before anything harder — so getting the fundamentals genuinely solid here pays off across every other pattern (strings, hash maps, sliding window all build on this).

**Problems covered in this note:**
- [Two Sum II — Input Array Is Sorted](https://leetcode.com/problems/two-sum-ii-input-array-is-sorted/) (Easy)
- [Remove Duplicates from Sorted Array](https://leetcode.com/problems/remove-duplicates-from-sorted-array/) (Easy)
- [Rotate Array](https://leetcode.com/problems/rotate-array/) (Medium)

---

## 1. Time vs Space Complexity — the distinction interviewers probe first

Before patterns, it's worth being precise about what "complexity" actually measures, because time and space don't always move together.

**Time complexity** = how much work is done. **Space complexity** = how much memory is held onto *at once*. A function can do a huge amount of work (high time complexity) while barely using any extra memory (low space complexity) — these are independent questions.

A clean example of *space* complexity, a multiplication table:

```python
def multiplication_table(n):
    table = []
    for i in range(n):
        row = []
        for j in range(n):
            row.append((i + 1) * (j + 1))
        table.append(row)
    return table
```

This is `O(n²)` in **both** time and space — `n` rows times `n` columns of nested looping (time), and every single value gets stored in `table` before the function returns (space). That second part is the key: space complexity only grows when something is *kept*. If this function instead just summed the products and returned one number, it would still be `O(n²)` time (same amount of computation) but `O(1)` space (only one running total variable, regardless of how big `n` gets).

This distinction matters a lot in data engineering specifically: a nested-loop structure like this is exactly the shape of a SQL `CROSS JOIN` — join two tables of size `n` with no condition and you materialize `n²` result rows, all sitting in memory or disk at once. Same pattern, same cost.

---

## 2. The Two Pointers Pattern

Two pointers is the single highest-leverage pattern for array problems — once you can recognize when it applies, a large chunk of "Easy" and "Medium" array questions collapse from `O(n²)` brute force down to `O(n)`.

There are two distinct flavors, and conflating them is a common source of confusion:

### Flavor A — Converging pointers (opposite ends, walking inward)

**Signal to watch for:** a *sorted* array + "find a pair/triplet that satisfies some condition." Sortedness is what makes this work — it tells you which direction to move.

**Problem: Pair with Target Sum** — given a sorted array, find two numbers that add up to a target, return their indices.

```python
def pair_with_target_sum(numbers, target):
    left, right = 0, len(numbers) - 1
    while left < right:
        total = numbers[left] + numbers[right]
        if total == target:
            return [left, right]
        elif total < target:
            left += 1      # sum too small -> need a bigger number
        else:
            right -= 1     # sum too big -> need a smaller number
    return [-1, -1]        # no pair found
```

Why it's correct: because the array is sorted, moving `left` right can only *increase* the sum, and moving `right` left can only *decrease* it. Each pointer only ever moves in one direction, so every index is visited at most once — `O(n)` time, `O(1)` space, versus the `O(n²)` brute force of checking every pair.

### Flavor B — Same-direction pointers (slow + fast)

**Signal to watch for:** an in-place array mutation where you need to keep some elements and discard others, without extra memory.

**Problem: Remove Duplicates from Sorted Array** — given a sorted array with duplicates, remove them in-place and return the count of unique elements.

```python
def remove_duplicates(nums):
    if not nums:
        return 0
    slow = 0
    for fast in range(1, len(nums)):
        if nums[fast] != nums[slow]:
            slow += 1
            nums[slow] = nums[fast]
    return slow + 1
```

`slow` marks the last confirmed-unique position; `fast` scans ahead looking for the next new value. `fast` advances every iteration regardless; `slow` only advances (and writes) when a genuinely new value is found. `slow` is a 0-based index, so the final count of unique elements is `slow + 1`, not `slow`.

`O(n)` time, `O(1)` space — compare to the naive approach of dumping into a `set` and copying back, which costs `O(n)` *extra* space.

**The distinction worth internalizing:** Flavor A converges from both ends toward the middle; Flavor B both pointers move in the same direction at different speeds. Same pattern family, genuinely different mechanics — worth being able to name which one a new problem needs before writing code.

---

## 3. In-Place Array Reversal (the building block for what's next)

A simpler two-pointer variant, but it's the foundation the next section builds on directly.

```python
def reverse(arr, left, right):
    while left < right:
        temp = arr[left]
        arr[left] = arr[right]
        arr[right] = temp
        left += 1
        right -= 1
```

Why `temp` is non-negotiable: `arr[left] = arr[right]` overwrites `arr[left]`'s original value *before* that value has anywhere else to go. Without saving it first, it's gone — `arr[right] = arr[left]` afterward just assigns the same value back to itself. `temp` is a one-line "hold this value hostage" step, needed any time two values are being exchanged. `O(1)` space — only three variables (`left`, `right`, `temp`) regardless of array size.

---

## 4. Combining Techniques: Rotate Array

This problem is a great interview question specifically because it has a brute-force answer, a "pretty good" answer, and then one more level — it tests whether you'll stop at "working" or push to "optimal" when asked.

**Problem:** rotate an array right by `k` positions. `[1,2,3,4,5]`, `k=2` → `[4,5,1,2,3]`. If `k` is larger than the array length, it wraps around (`k=4` on a 3-element array behaves like `k=1`, since `4 % 3 = 1`).

### Brute force — `O(n)` time, `O(n)` space

For every index `i`, figure out directly where it lands after rotating, using the same wraparound idea (`%`) that handles `k` itself:

```python
def rotate_brute_force(nums, k):
    n = len(nums)
    k = k % n
    result = [0] * n
    for i in range(n):
        new_index = (i + k) % n
        result[new_index] = nums[i]
    return result
```

### Optimal — three reversals, `O(n)` time, `O(1)` space

This is the one that shows real pattern mastery — it reuses the `reverse()` helper from Section 3, called three times on different slices of the *same* array, with zero extra memory:

```python
def rotate(nums, k):
    n = len(nums)
    k = k % n                  # fixed once, trusted everywhere after

    reverse(nums, 0, n - 1)    # reverse the whole array
    reverse(nums, 0, k - 1)    # reverse the first k elements
    reverse(nums, k, n - 1)    # reverse the remaining elements

    return nums
```

Traced on `[1,2,3,4,5]`, `k=2`:

```
start:                [1, 2, 3, 4, 5]
reverse whole array:  [5, 4, 3, 2, 1]
reverse first k=2:    [4, 5, 3, 2, 1]
reverse the rest:     [4, 5, 1, 2, 3]   ✓
```

Worth noting for the wraparound edge case (`k` larger than array length): `k = k % n` runs *once*, at the very top, before any reversal happens — so the three `reverse()` calls never need to handle the raw, un-wrapped `k` at all. They only ever see the corrected value. That's a generally useful habit: fix an edge case once, early, and let everything downstream trust it rather than re-checking it everywhere.

---

## 5. Complexity Cheat-Sheet

| Technique | Problem | Time | Space |
|---|---|---|---|
| Nested loop, store everything | Multiplication table | O(n²) | O(n²) |
| Brute force pair check | (naive) pair sum | O(n²) | O(1) |
| Two pointers, converging | Pair with Target Sum | O(n) | O(1) |
| Two pointers, same-direction | Remove Duplicates | O(n) | O(1) |
| In-place reversal | Reverse Array | O(n) | O(1) |
| Extra array, direct placement | Rotate Array (brute force) | O(n) | O(n) |
| Three reversals | Rotate Array (optimal) | O(n) | O(1) |

---

## Why this matters for FAANG / Data Engineer interviews

Array and two-pointer questions carry disproportionate weight in early interview rounds because they're fast to state, fast to verify, and reveal a lot in a short window: can you spot the pattern, can you reason about a sorted invariant, can you push past a correct-but-wasteful solution to an optimal one. For a data engineering role specifically, the underlying ideas show up constantly outside of LeetCode too — two-pointer merging is how sorted joins work, in-place mutation with no extra memory is exactly the discipline that matters when processing data at a scale where `O(n)` extra space isn't free, and the "brute force first, then optimize" habit is the same instinct that catches an accidental cross join before it ships.

*Part of a 4-month, 30-45 min/day structured DSA prep plan — more pattern notes added as each is cleared.*
