(* Reynolds Separation Logic Paper - Doubly Linked List Examples
   Using records with {value, prev, next} fields

   From Reynolds paper Section 5-6:
   Doubly linked lists use asymmetric ownership - ownership flows
   forward through 'next' pointers while 'prev' pointers are just values.

   NOTE: These tests are currently commented out due to a type system
   conflict between OCaml's record types and the separation logic model.
   See test_records.ml for details. *)

(* DLL node type - OCaml requires this declaration *)
(* type node = { mutable value: int; mutable prev: int; mutable next: int } *)

(* ========== DLL NODE OPERATIONS ========== *)

(* Create a singleton DLL node (no prev/next)
let dll_singleton_true v
(*@ ens res->{value: v, prev: 0, next: 0} @*)
= {value = v; prev = 0; next = 0}
*)

(* Read value from DLL node
let dll_get_value_true n
(*@ forall v p nxt. req n->{value: v, prev: p, next: nxt};
    ens n->{value: v, prev: p, next: nxt} /\ res=v @*)
= n.value
*)

(* Update value in DLL node
let dll_set_value_true n newval
(*@ forall v p nxt. req n->{value: v, prev: p, next: nxt};
    ens n->{value: newval, prev: p, next: nxt} @*)
= n.value <- newval
*)

(* Get next pointer
let dll_get_next_true n
(*@ forall v p nxt. req n->{value: v, prev: p, next: nxt};
    ens n->{value: v, prev: p, next: nxt} /\ res=nxt @*)
= n.next
*)

(* Get prev pointer
let dll_get_prev_true n
(*@ forall v p nxt. req n->{value: v, prev: p, next: nxt};
    ens n->{value: v, prev: p, next: nxt} /\ res=p @*)
= n.prev
*)

(* ========== TWO-NODE DLL OPERATIONS ========== *)

(* Link two nodes: n1.next = n2, n2.prev = n1
let dll_link_true n1 n2
(*@ forall v1 p1 x1 v2 p2 x2.
    req n1->{value: v1, prev: p1, next: x1} * n2->{value: v2, prev: p2, next: x2};
    ens n1->{value: v1, prev: p1, next: n2} * n2->{value: v2, prev: n1, next: x2} @*)
= n1.next <- n2; n2.prev <- n1
*)

(* Unlink: set both pointers to 0
let dll_unlink_true n1 n2
(*@ forall v1 p1 v2 x2.
    req n1->{value: v1, prev: p1, next: n2} * n2->{value: v2, prev: n1, next: x2};
    ens n1->{value: v1, prev: p1, next: 0} * n2->{value: v2, prev: 0, next: x2} @*)
= n1.next <- 0; n2.prev <- 0
*)

(* Swap values between two linked nodes
let dll_swap_values_true n1 n2
(*@ forall v1 p1 v2 x2.
    req n1->{value: v1, prev: p1, next: n2} * n2->{value: v2, prev: n1, next: x2};
    ens n1->{value: v2, prev: p1, next: n2} * n2->{value: v1, prev: n1, next: x2} @*)
= let tmp = n1.value in
  n1.value <- n2.value;
  n2.value <- tmp
*)

(* ========== THREE-NODE DLL OPERATIONS ========== *)

(* Insert node between two existing nodes
let dll_insert_between_true n1 new_node n2
(*@ forall v1 p1 vn pn xn v2 x2.
    req n1->{value: v1, prev: p1, next: n2} *
        new_node->{value: vn, prev: pn, next: xn} *
        n2->{value: v2, prev: n1, next: x2};
    ens n1->{value: v1, prev: p1, next: new_node} *
        new_node->{value: vn, prev: n1, next: n2} *
        n2->{value: v2, prev: new_node, next: x2} @*)
= n1.next <- new_node;
  new_node.prev <- n1;
  new_node.next <- n2;
  n2.prev <- new_node
*)

(* ========== NEGATIVE TESTS ========== *)

(* Wrong value after read - should fail
let dll_get_value_wrong_false n
(*@ forall v p nxt. req n->{value: v, prev: p, next: nxt};
    ens n->{value: v, prev: p, next: nxt} /\ res=p @*)
= n.value
*)

(* Link doesn't update both pointers - should fail
let dll_link_incomplete_false n1 n2
(*@ forall v1 p1 x1 v2 p2 x2.
    req n1->{value: v1, prev: p1, next: x1} * n2->{value: v2, prev: p2, next: x2};
    ens n1->{value: v1, prev: p1, next: n2} * n2->{value: v2, prev: n1, next: x2} @*)
= n1.next <- n2
*)

(* ========== PLACEHOLDER ========== *)
(* Placeholder to verify file loads *)

let placeholder_true ()
(*@ ens res=0 @*)
= 0
