// Test 19: Doubly Linked List Operations with Case Analysis
// Based on Reynolds' Separation Logic paper (Section 5.4 - Data Structures)
//
// A DLL node has three fields:
//   - val: the stored value
//   - prev: pointer to previous node (null = 0)
//   - next: pointer to next node (null = 0)
//
// We represent nodes using separate mutable cells for each field:
//   n1_val, n1_prev, n1_next for node 1
//   n2_val, n2_prev, n2_next for node 2
//   etc.
//
// This models the heap representation used in separation logic proofs.

// ========== DLL NODE CELLS ==========

// Node 1 fields
let n1_val: number = 0;
let n1_prev: number = 0;  // 0 = null
let n1_next: number = 0;

// Node 2 fields
let n2_val: number = 0;
let n2_prev: number = 0;
let n2_next: number = 0;

// Node 3 fields (for longer lists)
let n3_val: number = 0;
let n3_prev: number = 0;
let n3_next: number = 0;

// ========== BASIC DLL LINK OPERATIONS ==========

/**
 * Link n1 -> n2 (make n2 the successor of n1)
 * This establishes the DLL invariant: n1.next = n2 /\ n2.prev = n1
 *
 * @require n1_next -> x * n2_prev -> p
 * @ensure n1_next -> 2 * n2_prev -> 1
 */
function link_n1_n2_true(): void {
  n1_next = 2;  // n1.next points to node 2
  n2_prev = 1;  // n2.prev points to node 1
}

/**
 * Link n2 -> n3 (make n3 the successor of n2)
 *
 * @require n2_next -> x * n3_prev -> p
 * @ensure n2_next -> 3 * n3_prev -> 2
 */
function link_n2_n3_true(): void {
  n2_next = 3;  // n2.next points to node 3
  n3_prev = 2;  // n3.prev points to node 2
}

/**
 * Link failure: only one pointer updated - SHOULD FAIL
 *
 * @require n1_next -> x * n2_prev -> p
 * @ensure n1_next -> 2 * n2_prev -> 1
 */
function link_incomplete_false(): void {
  n1_next = 2;
  // Missing: n2_prev = 1;
}

// ========== DLL UNLINK OPERATIONS ==========

/**
 * Unlink n1 from n2: set both pointers to null
 *
 * @require n1_next -> x * n2_prev -> p
 * @ensure n1_next -> 0 * n2_prev -> 0
 */
function unlink_n1_n2_true(): void {
  n1_next = 0;
  n2_prev = 0;
}

// ========== DLL INSERT OPERATIONS ==========

/**
 * Insert n2 between n1 and n3
 * Precondition: n1 -> n3 link exists
 * Postcondition: n1 -> n2 -> n3
 *
 * This requires 4 pointer updates (2 for each link):
 *   n1.next = n2, n2.prev = n1 (link n1 -> n2)
 *   n2.next = n3, n3.prev = n2 (link n2 -> n3)
 *
 * @require n1_next -> x1 * n1_prev -> p1 * n2_next -> x2 * n2_prev -> p2 * n3_next -> x3 * n3_prev -> p3
 * @ensure n1_next -> 2 * n1_prev -> p1 * n2_next -> 3 * n2_prev -> 1 * n3_next -> x3 * n3_prev -> 2
 */
function insert_n2_between_true(): void {
  // Link n1 -> n2
  n1_next = 2;
  n2_prev = 1;
  // Link n2 -> n3
  n2_next = 3;
  n3_prev = 2;
}

/**
 * Partial insert (missing backward link) - SHOULD FAIL
 *
 * @require n1_next -> x1 * n2_next -> x2 * n2_prev -> p2 * n3_prev -> p3
 * @ensure n1_next -> 2 * n2_next -> 3 * n2_prev -> 1 * n3_prev -> 2
 */
function insert_partial_false(): void {
  n1_next = 2;
  n2_next = 3;
  // Missing: n2_prev = 1; n3_prev = 2;
}

// ========== DLL REMOVE OPERATIONS ==========

/**
 * Remove n2 from n1 -> n2 -> n3, leaving n1 -> n3
 *
 * @require n1_next -> 2 * n2_prev -> 1 * n2_next -> 3 * n3_prev -> 2
 * @ensure n1_next -> 3 * n2_prev -> 0 * n2_next -> 0 * n3_prev -> 1
 */
function remove_n2_true(): void {
  // Unlink n2
  n2_prev = 0;
  n2_next = 0;
  // Relink n1 -> n3
  n1_next = 3;
  n3_prev = 1;
}

// ========== VALUE OPERATIONS WITH FRAME ==========

/**
 * Read n1's value (frame preserves all pointers)
 *
 * @require n1_val -> v * n1_next -> x * n1_prev -> p
 * @ensure n1_val -> v * n1_next -> x * n1_prev -> p /\ res = v
 */
function read_n1_val_true(): number {
  return n1_val;
}

/**
 * Update n1's value (frame preserves pointers)
 *
 * @require n1_val -> v * n1_next -> x * n1_prev -> p
 * @ensure n1_val -> 42 * n1_next -> x * n1_prev -> p
 */
function set_n1_val_true(): void {
  n1_val = 42;
}

/**
 * Swap values between n1 and n2 (preserve structure)
 *
 * @require n1_val -> v1 * n2_val -> v2 * n1_next -> x1 * n2_prev -> p2
 * @ensure n1_val -> v2 * n2_val -> v1 * n1_next -> x1 * n2_prev -> p2
 */
function swap_values_preserve_structure_true(): void {
  const tmp = n1_val;
  n1_val = n2_val;
  n2_val = tmp;
}

// ========== DLL TRAVERSAL (SIMULATED WITHOUT LOOPS) ==========

/**
 * Copy n1's value to n2 (first step of traversal)
 *
 * @require n1_val -> v1 * n2_val -> v2 * n1_next -> 2
 * @ensure n1_val -> v1 * n2_val -> v1 * n1_next -> 2
 */
function copy_forward_one_true(): void {
  n2_val = n1_val;
}

/**
 * Sum values of n1 and n2 into n1
 *
 * @require n1_val -> v1 * n2_val -> v2
 * @ensure n1_val -> v1 + v2 * n2_val -> v2
 */
function sum_n1_n2_true(): void {
  n1_val = n1_val + n2_val;
}

/**
 * Sum values of all three nodes into n1 (simulating loop accumulation)
 *
 * @require n1_val -> v1 * n2_val -> v2 * n3_val -> v3
 * @ensure n1_val -> v1 + v2 + v3 * n2_val -> v2 * n3_val -> v3
 */
function sum_all_true(): void {
  n1_val = n1_val + n2_val;
  n1_val = n1_val + n3_val;
}

// ========== DLL INTEGRITY CHECKS ==========

/**
 * Verify DLL invariant: n1.next = 2 implies some node has prev = 1
 * This is a read-only operation that checks structure
 *
 * @require n1_next -> x * n2_prev -> p
 * @ensure n1_next -> x * n2_prev -> p /\ res : Bool
 */
function check_link_integrity_true(): boolean {
  if (n1_next === 2) {
    return n2_prev === 1;
  } else {
    return true;  // No link to check
  }
}

// ========== CASE ANALYSIS FOR NULLABLE POINTERS ==========

// In DLL operations, we often need to handle:
// 1. Both prev and next are null (single node)
// 2. Only prev is null (head of list)
// 3. Only next is null (tail of list)
// 4. Neither is null (middle node)

/**
 * Determine node position based on pointers
 * Returns: 0 = isolated, 1 = head, 2 = tail, 3 = middle
 *
 * @require n1_prev -> p * n1_next -> x
 * @ensure n1_prev -> p * n1_next -> x /\ res : Int
 */
function classify_node_true(): number {
  if (n1_prev === 0) {
    if (n1_next === 0) {
      return 0;  // Isolated: no connections
    } else {
      return 1;  // Head: no prev, has next
    }
  } else {
    if (n1_next === 0) {
      return 2;  // Tail: has prev, no next
    } else {
      return 3;  // Middle: has both
    }
  }
}

// ========== NOTES ON LOOP-BASED DLL OPERATIONS ==========

// The following operations would require while loops with invariants:
//
// /**
//  * Find length of DLL starting at n1
//  * @invariant current : NodePtr /\ count >= 0
//  * @variant distance_to_null(current)
//  * @ensure res = length(dll)
//  */
// function dll_length(): number {
//   let count = 0;
//   let current = 1;  // Start at n1
//   while (current !== 0) {
//     count = count + 1;
//     // current = current.next (would need indirection)
//   }
//   return count;
// }
//
// /**
//  * Reverse a DLL in place
//  * @invariant front_reversed * back_unreversed * join_point
//  * @variant length(back_unreversed)
//  * @ensure dll_reversed(original_head)
//  */
// function dll_reverse(): void {
//   // Would need while loop with careful pointer manipulation
// }

// ========== INDUCTIVE PREDICATES (FUTURE) ==========

// To properly verify DLL operations with loops, we need inductive predicates:
//
// pred dll(x, y, S) :=
//   x == null /\ y == null /\ S == {} \/
//   exists v, n, S'. x.val -> v * x.next -> n * x.prev -> y * dll(n, x, S') /\ S == {v} + S'
//
// This defines a DLL segment from x to y containing values S.
// The separating conjunction (*) ensures no sharing between nodes.
