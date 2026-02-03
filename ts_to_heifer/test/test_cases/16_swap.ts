// Test 16: Swap operations with separation logic
// Tests the core swap pattern with various specifications

let cell1: number = 0;
let cell2: number = 0;
let cell3: number = 0;

// ========== BASIC SWAP ==========

/**
 * Basic swap of two separate cells
 * @require cell1 -> a * cell2 -> b
 * @ensure cell1 -> b * cell2 -> a
 */
function swap_basic_true(): void {
  let tmp = cell1;
  cell1 = cell2;
  cell2 = tmp;
}

/**
 * Swap with frame preservation (third cell unchanged)
 * @require cell1 -> a * cell2 -> b * cell3 -> c
 * @ensure cell1 -> b * cell2 -> a * cell3 -> c
 */
function swap_with_frame_true(): void {
  let tmp = cell1;
  cell1 = cell2;
  cell2 = tmp;
}

// ========== DISJUNCTIVE SPECS ==========

/**
 * Swap or identity - both are acceptable outcomes
 * @require cell1 -> a * cell2 -> b
 * @ensure cell1 -> b * cell2 -> a \/ cell1 -> a * cell2 -> b
 */
function swap_or_identity_true(): void {
  let tmp = cell1;
  cell1 = cell2;
  cell2 = tmp;
}

/**
 * Identity satisfies second branch of disjunction
 * NOTE: Need parentheses for shared precondition
 * @require cell1 -> a * cell2 -> b
 * @ensure (cell1 -> 999 * cell2 -> 999 \/ cell1 -> a * cell2 -> b)
 */
function identity_in_disj_true(): void {
  // no-op: doesn't modify anything
}

// ========== CASE ANALYSIS ==========

/**
 * Two-case specification:
 * - Case 1: If x and y are separate, swap them
 * - Case 2: If only x is specified, preserve it
 *
 * The code always does a full swap, which satisfies case 1
 * @require cell1 -> a * cell2 -> b
 * @ensure cell1 -> b * cell2 -> a
 */
function swap_case1_true(): void {
  let tmp = cell1;
  cell1 = cell2;
  cell2 = tmp;
}

// ========== NEGATIVE TESTS ==========

/**
 * Wrong swap result - should fail
 * Code swaps but spec says identity
 * @require cell1 -> a * cell2 -> b
 * @ensure cell1 -> a * cell2 -> b
 */
function swap_wrong_false(): void {
  let tmp = cell1;
  cell1 = cell2;
  cell2 = tmp;
}

/**
 * Incomplete swap - only updates one cell
 * @require cell1 -> a * cell2 -> b
 * @ensure cell1 -> b * cell2 -> a
 */
function partial_swap_false(): void {
  cell1 = cell2;
  // Missing: cell2 = tmp
}

/**
 * Disjunction where neither branch matches
 * Code swaps but spec only allows specific constants
 * @require cell1 -> a * cell2 -> b
 * @ensure cell1 -> 100 * cell2 -> 200 \/ cell1 -> 300 * cell2 -> 400
 */
function disj_mismatch_false(): void {
  let tmp = cell1;
  cell1 = cell2;
  cell2 = tmp;
}

// ========== SELF-SWAP (Same cell) ==========

/**
 * Self-swap is a no-op - cell value unchanged
 * @require cell1 -> a
 * @ensure cell1 -> a
 */
function self_swap_true(): void {
  let tmp = cell1;
  cell1 = cell1;
  cell1 = tmp;
}
