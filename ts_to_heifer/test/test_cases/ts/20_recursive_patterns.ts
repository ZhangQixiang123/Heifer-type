// Test 20: Recursive Patterns for Loop-like Operations
// In separation logic, loops are often modeled as recursive procedures
// with invariants specified as the recursive function's spec.
//
// This file tests recursive patterns that would be used for:
// - Iteration over heap structures
// - Accumulator patterns
// - Conditional iteration (like while loops with break)

// Ref type for reference semantics
type Ref<T> = { value: T };

// Counter cells for recursive operations
let counter: number = 0;
let accumulator: number = 0;
let limit: number = 0;

// ========== BASE CASE: SINGLE RECURSIVE STEP ==========

/**
 * Decrement counter once (base case of countdown)
 * This is one iteration of a countdown loop
 *
 * @require counter -> n
 * @ensure counter -> n - 1
 */
function decrement_once_true(): void {
  counter = counter - 1;
}

/**
 * Increment accumulator by counter (one step of sum)
 *
 * @require counter -> c * accumulator -> a
 * @ensure counter -> c * accumulator -> a + c
 */
function accumulate_once_true(): void {
  accumulator = accumulator + counter;
}

// ========== CONDITIONAL STEP (GUARDS) ==========

/**
 * Decrement if positive, else no-op
 * This models the guard condition of a while loop
 *
 * @require counter -> n
 * @ensure (counter -> n - 1 /\ n > 0) \/ (counter -> n /\ n <= 0)
 */
function guarded_decrement_true(): void {
  if (counter > 0) {
    counter = counter - 1;
  }
}

/**
 * Accumulate and decrement if counter positive
 * One iteration of: while (i > 0) { sum += i; i--; }
 *
 * @require counter -> c * accumulator -> a
 * @ensure (counter -> c - 1 * accumulator -> a + c /\ c > 0) \/ (counter -> c * accumulator -> a /\ c <= 0)
 */
function sum_step_true(): void {
  if (counter > 0) {
    accumulator = accumulator + counter;
    counter = counter - 1;
  }
}

// ========== FIXED ITERATION (UNROLLED LOOPS) ==========

/**
 * Decrement 3 times (unrolled loop of 3 iterations)
 *
 * @require counter -> n
 * @ensure counter -> n - 3
 */
function decrement_three_true(): void {
  counter = counter - 1;
  counter = counter - 1;
  counter = counter - 1;
}

/**
 * Sum first 3 natural numbers into accumulator
 * Unrolling of: for (i = 1; i <= 3; i++) acc += i;
 *
 * @require accumulator -> a
 * @ensure accumulator -> a + 6
 */
function sum_one_to_three_true(): void {
  accumulator = accumulator + 1;
  accumulator = accumulator + 2;
  accumulator = accumulator + 3;
}

/**
 * Double counter 3 times (2^3 = 8x multiplication)
 *
 * @require counter -> n
 * @ensure counter -> n * 8
 */
function double_three_times_true(): void {
  counter = counter * 2;
  counter = counter * 2;
  counter = counter * 2;
}

// ========== CASE ANALYSIS WITH ITERATION PATTERNS ==========

/**
 * Transfer from x to y in steps (models iterative transfer)
 * Two references with aliasing cases
 *
 * @forall a, b
 * @params x, y
 * @case x : Ref(Int) /\ y : Ref(Int) => r : ()
 * @case x -> a * y -> b => x -> a - 1 * y -> b + 1 /\ r : ()
 * @case x -> a /\ y : x => x -> a /\ r : ()
 */
function transfer_one_true(x: Ref<number>, y: Ref<number>): void {
  const from_val = x.value;
  const to_val = y.value;
  x.value = from_val - 1;
  y.value = to_val + 1;
}

/**
 * Missing aliased case for transfer - SHOULD FAIL
 *
 * @forall a, b
 * @params x, y
 * @case x : Ref(Int) /\ y : Ref(Int) => r : ()
 * @case x -> a * y -> b => x -> a - 1 * y -> b + 1 /\ r : ()
 */
function transfer_incomplete_false(x: Ref<number>, y: Ref<number>): void {
  const from_val = x.value;
  const to_val = y.value;
  x.value = from_val - 1;
  y.value = to_val + 1;
}

// ========== BRANCHING ITERATION PATTERNS ==========

/**
 * Conditional accumulation based on sign
 * Models: if (n > 0) positive_sum += n; else negative_sum += n;
 *
 * Two separate accumulators with no aliasing concern
 *
 * @require counter -> n * accumulator -> pos * limit -> neg
 * @ensure (counter -> n * accumulator -> pos + n * limit -> neg /\ n > 0) \/ (counter -> n * accumulator -> pos * limit -> neg + n /\ n <= 0)
 */
function categorize_and_accumulate_true(): void {
  if (counter > 0) {
    accumulator = accumulator + counter;
  } else {
    limit = limit + counter;
  }
}

// ========== NESTED CONDITIONAL PATTERNS ==========

/**
 * Two-level conditional update
 * Models nested loops or multi-condition iteration
 *
 * @require counter -> c * accumulator -> a * limit -> l
 * @ensure counter -> c * accumulator -> a + c * l + c + 1 * limit -> l + c + 1
 */
function nested_update_true(): void {
  if (counter > 0) {
    accumulator = accumulator + counter;
    if (counter > limit) {
      limit = limit + counter;
    } else {
      limit = limit + 1;
    }
  } else {
    accumulator = accumulator + counter;
    limit = limit + 1;
  }
}

// ========== TERMINATION-LIKE PATTERNS ==========

/**
 * Ensure counter stays non-negative (invariant preservation)
 * This is the kind of property needed for termination proofs
 *
 * @require counter -> n /\ n >= 0
 * @ensure counter -> n /\ n >= 0
 */
function check_nonnegative_true(): void {
  // No-op: just verify the invariant is preserved
}

/**
 * Bounded decrement: don't go below zero
 * Models a loop that stops at zero
 *
 * @require counter -> n
 * @ensure (counter -> n - 1 /\ n > 0) \/ (counter -> 0 /\ n <= 0)
 */
function bounded_decrement_true(): void {
  if (counter > 0) {
    counter = counter - 1;
  } else {
    counter = 0;
  }
}

// ========== MULTI-CELL ITERATION SIMULATION ==========

/**
 * Rotate values: a -> b -> c -> a
 * One step of a circular buffer rotation
 *
 * @require counter -> a * accumulator -> b * limit -> c
 * @ensure counter -> b * accumulator -> c * limit -> a
 */
function rotate_values_true(): void {
  const tmp_a = counter;
  const tmp_b = accumulator;
  const tmp_c = limit;
  counter = tmp_b;
  accumulator = tmp_c;
  limit = tmp_a;
}

/**
 * Reverse rotate: c -> b -> a -> c
 *
 * @require counter -> a * accumulator -> b * limit -> c
 * @ensure counter -> c * accumulator -> a * limit -> b
 */
function reverse_rotate_true(): void {
  const tmp_a = counter;
  const tmp_b = accumulator;
  const tmp_c = limit;
  counter = tmp_c;
  accumulator = tmp_a;
  limit = tmp_b;
}

// ========== NOTES ON FULL RECURSIVE VERIFICATION ==========

// For full recursive function verification, we would need:
//
// 1. Recursive function definitions in TypeScript
// 2. Spec annotations with termination measures
// 3. Inductive reasoning support in the prover
//
// Example (not currently supported):
//
// /**
//  * @spec countdown
//  * @require counter -> n /\ n >= 0
//  * @ensure counter -> 0
//  * @variant n
//  */
// function countdown(): void {
//   if (counter > 0) {
//     counter = counter - 1;
//     countdown();  // Recursive call
//   }
// }
//
// The verification would prove:
// 1. Base case: n = 0 => already at postcondition
// 2. Inductive case: n > 0 => after decrement, n-1 >= 0 and variant decreases
// 3. Termination: variant n decreases and is bounded below by 0

// ========== NOTES ON WHILE LOOP DESUGARING ==========

// Heifer desugars while loops to recursive functions:
//
// while (cond) { body }
// becomes:
// let rec loop () =
//   if cond then (body; loop())
//   else ()
// in loop ()
//
// For separation logic verification:
// - Loop invariant becomes the recursive function's spec
// - Loop variant becomes the termination measure
// - Body must maintain invariant and decrease variant
