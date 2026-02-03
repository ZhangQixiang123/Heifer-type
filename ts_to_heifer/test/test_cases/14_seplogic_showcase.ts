// Test 14: Separation Logic Showcase
// Classic examples from Reynolds' separation logic papers
// Demonstrates: DLL operations, frame rule, disjoint heap regions

// ========== DOUBLY LINKED LIST NODES ==========
// Each node has: value, prev pointer, next pointer
// Represented as separate heap cells (Reynolds style)

// Node 1
let n1_val: number = 0;
let n1_prev: number = 0;
let n1_next: number = 0;

// Node 2
let n2_val: number = 0;
let n2_prev: number = 0;
let n2_next: number = 0;

// Node 3
let n3_val: number = 0;
let n3_prev: number = 0;
let n3_next: number = 0;

// ========== DLL SEGMENT: n1 <-> n2 ==========

/**
 * Create DLL segment: link n1 and n2 bidirectionally
 * Classic DLL invariant: n1.next = n2 /\ n2.prev = n1
 * @require n1_next -> x1 * n2_prev -> p2
 * @ensure n1_next -> 2 * n2_prev -> 1
 */
function dll_link_two_true(): void {
  n1_next = 2;
  n2_prev = 1;
}

/**
 * Extend DLL: n1 <-> n2 to n1 <-> n2 <-> n3
 * Must update both n2.next and n3.prev
 * @require n2_next -> x2 * n3_prev -> p3
 * @ensure n2_next -> 3 * n3_prev -> 2
 */
function dll_extend_true(): void {
  n2_next = 3;
  n3_prev = 2;
}

/**
 * Full 3-node DLL creation: n1 <-> n2 <-> n3
 * @require n1_next -> a * n2_prev -> b * n2_next -> c * n3_prev -> d
 * @ensure n1_next -> 2 * n2_prev -> 1 * n2_next -> 3 * n3_prev -> 2
 */
function dll_create_three_true(): void {
  n1_next = 2;
  n2_prev = 1;
  n2_next = 3;
  n3_prev = 2;
}

// ========== DLL NODE REMOVAL ==========

/**
 * Remove middle node n2 from n1 <-> n2 <-> n3
 * Result: n1 <-> n3 (bypass n2)
 * @require n1_next -> 2 * n3_prev -> 2
 * @ensure n1_next -> 3 * n3_prev -> 1
 */
function dll_remove_middle_true(): void {
  n1_next = 3;
  n3_prev = 1;
}

/**
 * Unlink n2 from list (clear its pointers)
 * @require n2_prev -> p * n2_next -> x
 * @ensure n2_prev -> 0 * n2_next -> 0
 */
function dll_isolate_node_true(): void {
  n2_prev = 0;
  n2_next = 0;
}

// ========== FRAME RULE: DISJOINT REGIONS ==========

/**
 * Modify n1's value, n2 and n3 completely untouched (frame)
 * Demonstrates separation: operations on n1 don't affect n2, n3
 * @require n1_val -> v1 * n2_val -> v2 * n3_val -> v3
 * @ensure n1_val -> 99 * n2_val -> v2 * n3_val -> v3
 */
function frame_disjoint_regions_true(): void {
  n1_val = 99;
}

/**
 * Modify n2's pointers, n1 and n3 values preserved
 * @require n1_val -> v1 * n2_prev -> p2 * n2_next -> x2 * n3_val -> v3
 * @ensure n1_val -> v1 * n2_prev -> 0 * n2_next -> 0 * n3_val -> v3
 */
function frame_mixed_fields_true(): void {
  n2_prev = 0;
  n2_next = 0;
}

// ========== SWAP: CLASSIC SEPARATION LOGIC EXAMPLE ==========

/**
 * Swap values of two DLL nodes
 * Requires both cells, ensures values exchanged
 * @require n1_val -> v1 * n2_val -> v2
 * @ensure n1_val -> v2 * n2_val -> v1
 */
function dll_swap_values_true(): void {
  const tmp: number = n1_val;
  n1_val = n2_val;
  n2_val = tmp;
}

/**
 * Swap next pointers of two nodes
 * @require n1_next -> x1 * n2_next -> x2
 * @ensure n1_next -> x2 * n2_next -> x1
 */
function dll_swap_next_true(): void {
  const tmp: number = n1_next;
  n1_next = n2_next;
  n2_next = tmp;
}

// ========== CYCLIC ROTATION (3 cells) ==========

/**
 * Rotate values: n1 <- n2 <- n3 <- n1
 * @require n1_val -> v1 * n2_val -> v2 * n3_val -> v3
 * @ensure n1_val -> v2 * n2_val -> v3 * n3_val -> v1
 */
function rotate_values_true(): void {
  const tmp: number = n1_val;
  n1_val = n2_val;
  n2_val = n3_val;
  n3_val = tmp;
}

// ========== IN-PLACE REVERSAL (2-node DLL segment) ==========

/**
 * Reverse DLL segment: n1 <-> n2 becomes n2 <-> n1
 * Swap the direction of links
 * @require n1_prev -> p1 * n1_next -> 2 * n2_prev -> 1 * n2_next -> x2
 * @ensure n1_prev -> 2 * n1_next -> p1 * n2_prev -> x2 * n2_next -> 1
 */
function dll_reverse_two_true(): void {
  // Swap n1's pointers
  const tmp1: number = n1_prev;
  n1_prev = n1_next;
  n1_next = tmp1;
  // Swap n2's pointers
  const tmp2: number = n2_prev;
  n2_prev = n2_next;
  n2_next = tmp2;
}

// ========== NEGATIVE TESTS ==========

/**
 * FAIL: Incomplete DLL link (missing n2.prev update)
 * @require n1_next -> x1 * n2_prev -> p2
 * @ensure n1_next -> 2 * n2_prev -> 1
 */
function dll_link_incomplete_false(): void {
  n1_next = 2;
  // Missing: n2_prev = 1
}

/**
 * FAIL: Wrong swap result (claims unchanged)
 * @require n1_val -> v1 * n2_val -> v2
 * @ensure n1_val -> v1 * n2_val -> v2
 */
function swap_claims_unchanged_false(): void {
  const tmp: number = n1_val;
  n1_val = n2_val;
  n2_val = tmp;
}

/**
 * FAIL: Wrong removal (only updates one pointer)
 * @require n1_next -> 2 * n3_prev -> 2
 * @ensure n1_next -> 3 * n3_prev -> 1
 */
function dll_remove_partial_false(): void {
  n1_next = 3;
  // Missing: n3_prev = 1
}
