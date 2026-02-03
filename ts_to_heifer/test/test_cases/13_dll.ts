// Test 13: Doubly Linked List Operations
// Testing DLL operations using separation logic specs
// Based on Reynolds' Separation Logic Paper

// DLL nodes are represented as separate mutable cells:
// - n_val: the value stored in the node
// - n_prev: pointer to previous node (0 = null)
// - n_next: pointer to next node (0 = null)

// Global mutable variables for DLL node fields
let n1_val: number = 0;
let n1_prev: number = 0;
let n1_next: number = 0;

let n2_val: number = 0;
let n2_prev: number = 0;
let n2_next: number = 0;

// ========== BASIC NODE OPERATIONS ==========

/**
 * Update the next pointer of a node
 * @require n1_next -> old_next
 * @ensure n1_next -> new_target
 */
function update_next_true(new_target: number): void {
  n1_next = new_target;
}

/**
 * Update the prev pointer of a node
 * @require n2_prev -> old_prev
 * @ensure n2_prev -> new_target
 */
function update_prev_true(new_target: number): void {
  n2_prev = new_target;
}

/**
 * Read a node's value
 * @require n1_val -> v
 * @ensure n1_val -> v /\ res = v
 */
function read_value_true(): number {
  return n1_val;
}

// ========== DLL LINK OPERATIONS ==========

/**
 * Link two nodes: n1.next = n2, n2.prev = n1
 * @require n1_next -> x1 * n2_prev -> p2
 * @ensure n1_next -> 2 * n2_prev -> 1
 */
function link_nodes_true(): void {
  n1_next = 2;  // n1.next points to n2 (id=2)
  n2_prev = 1;  // n2.prev points to n1 (id=1)
}

/**
 * Unlink two nodes: set both pointers to null (0)
 * @require n1_next -> x1 * n2_prev -> p2
 * @ensure n1_next -> 0 * n2_prev -> 0
 */
function unlink_nodes_true(): void {
  n1_next = 0;
  n2_prev = 0;
}

// ========== SWAP OPERATIONS ==========

/**
 * Swap values between two nodes
 * @require n1_val -> v1 * n2_val -> v2
 * @ensure n1_val -> v2 * n2_val -> v1
 */
function swap_values_true(): void {
  const tmp: number = n1_val;
  n1_val = n2_val;
  n2_val = tmp;
}

// ========== FRAME PRESERVATION ==========

/**
 * Update one node, preserve the other (frame rule test)
 * @require n1_val -> v1 * n2_val -> v2
 * @ensure n1_val -> 42 * n2_val -> v2
 */
function update_with_frame_true(): void {
  n1_val = 42;
}

/**
 * Three cells with frame preservation
 * @require n1_val -> v1 * n1_prev -> p1 * n1_next -> x1
 * @ensure n1_val -> v1 * n1_prev -> p1 * n1_next -> 0
 */
function update_next_preserve_others_true(): void {
  n1_next = 0;
}

// ========== NEGATIVE TESTS ==========

/**
 * Incomplete link - only updates one pointer (should fail)
 * @require n1_next -> x1 * n2_prev -> p2
 * @ensure n1_next -> 2 * n2_prev -> 1
 */
function link_incomplete_false(): void {
  n1_next = 2;
  // Missing: n2_prev = 1
}

/**
 * Wrong swap result (should fail)
 * @require n1_val -> v1 * n2_val -> v2
 * @ensure n1_val -> v1 * n2_val -> v2
 */
function swap_wrong_false(): void {
  const tmp: number = n1_val;
  n1_val = n2_val;
  n2_val = tmp;
  // Spec says values unchanged, but we swapped them
}
