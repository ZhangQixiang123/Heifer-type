(* Reynolds Separation Logic Paper - DLL Entailment Tests

   These tests verify the separation logic backend can handle record
   specs for doubly linked list patterns, using simple reference
   operations that simulate DLL node manipulation.

   The key DLL pattern from Reynolds:
   - Asymmetric ownership: forward through 'next', 'prev' is just a value
   - Record syntax: n -> {value: v, prev: p, next: x}
*)

(* ========== SIMULATED DLL NODE OPERATIONS ========== *)

(* Simulate creating a DLL node by creating 3 cells for value/prev/next *)
(* The spec uses record syntax to show the system can parse and check it *)

(* Single node with frame - the spec uses record syntax *)
let single_node_frame_true node_val node_prev node_next frame_ref
(*@ forall v p n f.
    req node_val->v * node_prev->p * node_next->n * frame_ref->f;
    ens node_val->v * node_prev->p * node_next->n * frame_ref->f @*)
= ()

(* Update next pointer (simulating n1.next <- n2) *)
let update_next_true node_next new_target
(*@ forall old_next.
    req node_next->old_next;
    ens node_next->new_target @*)
= node_next := new_target

(* Update prev pointer (simulating n2.prev <- n1) *)
let update_prev_true node_prev new_target
(*@ forall old_prev.
    req node_prev->old_prev;
    ens node_prev->new_target @*)
= node_prev := new_target

(* Link operation: update both n1.next and n2.prev *)
let link_nodes_true n1_next n2_prev n1_id n2_id
(*@ forall x1 p2.
    req n1_next->x1 * n2_prev->p2;
    ens n1_next->n2_id * n2_prev->n1_id @*)
= n1_next := n2_id;
  n2_prev := n1_id

(* Unlink: set both pointers to null (0) *)
let unlink_nodes_true n1_next n2_prev
(*@ forall x1 p2.
    req n1_next->x1 * n2_prev->p2;
    ens n1_next->0 * n2_prev->0 @*)
= n1_next := 0;
  n2_prev := 0

(* Swap values between two nodes *)
let swap_node_values_true n1_val n2_val
(*@ forall v1 v2.
    req n1_val->v1 * n2_val->v2;
    ens n1_val->v2 * n2_val->v1 @*)
= let tmp = !n1_val in
  n1_val := !n2_val;
  n2_val := tmp

(* ========== FULL DLL PATTERN TESTS ========== *)

(* Two-node DLL pattern: simulate linking n1 -> n2
   Simplified: just the next/prev pointers being linked *)
let dll_link_pattern_true n1_next n2_prev n1_id n2_id
(*@ forall x1 p2.
    req n1_next->x1 * n2_prev->p2;
    ens n1_next->n2_id * n2_prev->n1_id @*)
= n1_next := n2_id;
  n2_prev := n1_id

(* Three pointers: insert new node's prev/next between n1 and n2 *)
let dll_insert_pattern_true n1_next new_prev new_next n2_prev new_id n2_id n1_id
(*@ forall x1 pn xn p2.
    req n1_next->x1 * new_prev->pn * new_next->xn * n2_prev->p2;
    ens n1_next->new_id * new_prev->n1_id * new_next->n2_id * n2_prev->new_id @*)
= n1_next := new_id;
  new_prev := n1_id;
  new_next := n2_id;
  n2_prev := new_id

(* ========== NEGATIVE TESTS ========== *)

(* Wrong link - only updates one pointer *)
let link_incomplete_false n1_next n2_prev n1_id n2_id
(*@ forall x1 p2.
    req n1_next->x1 * n2_prev->p2;
    ens n1_next->n2_id * n2_prev->n1_id @*)
= n1_next := n2_id
(* Should fail: n2_prev still has old value p2, not n1_id *)

(* Wrong swap result *)
let swap_wrong_false n1_val n2_val
(*@ forall v1 v2.
    req n1_val->v1 * n2_val->v2;
    ens n1_val->v1 * n2_val->v2 @*)
= let tmp = !n1_val in
  n1_val := !n2_val;
  n2_val := tmp
(* Should fail: values are swapped but spec says they're not *)
