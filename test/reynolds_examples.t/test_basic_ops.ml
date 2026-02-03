(* Reynolds Separation Logic Paper - Basic Operations Examples
   Section 4: Specifications and their Inference Rules *)

(* ========== MUTATION RULES (p.8) ========== *)

(* Mutation (local): {e → −} [e] := e' {e → e'} *)
let mutation_local_true x
(*@ forall v. req x->v; ens x->42 @*)
= x := 42

(* Mutation with value from parameter *)
let mutation_param_true x newval
(*@ forall v. req x->v; ens x->newval @*)
= x := newval

(* ========== ALLOCATION RULES (p.8) ========== *)

(* Allocation (local): {emp} v := cons(e) {v → e} *)
let alloc_local_true ()
(*@ ens res->42 @*)
= ref 42

(* Allocation with expression *)
let alloc_expr_true n
(*@ ens res->n + 1 @*)
= ref (n + 1)

(* ========== LOOKUP RULES (p.8-9) ========== *)

(* Lookup (local): {e → v} v := [e] {v = v'' ∧ e → v''} *)
let lookup_local_true x
(*@ forall v. req x->v; ens x->v /\ res=v @*)
= !x

(* Lookup preserves heap *)
let lookup_preserves_true x
(*@ forall v. req x->v; ens x->v @*)
= let _ = !x in ()

(* ========== COMBINED OPERATIONS ========== *)

(* Read then write - common pattern *)
let read_modify_write_true x
(*@ forall v. req x->v; ens x->v + v @*)
= let old = !x in x := old + old

(* Increment - from paper's idiom *)
let increment_true x
(*@ forall v. req x->v; ens x->v + 1 @*)
= x := !x + 1

(* Decrement *)
let decrement_true x
(*@ forall v. req x->v; ens x->v - 1 @*)
= x := !x - 1

(* ========== NEGATIVE TESTS ========== *)

(* Wrong mutation value - should fail *)
let mutation_wrong_false x
(*@ forall v. req x->v; ens x->100 @*)
= x := 42

(* Allocation with wrong value - should fail *)
let alloc_wrong_false ()
(*@ ens res->100 @*)
= ref 42

(* Lookup returns wrong value - should fail *)
let lookup_wrong_false x
(*@ forall v. req x->v; ens res=v + 1 @*)
= !x

(* Increment by 2 but spec says 1 - should fail *)
let increment_wrong_false x
(*@ forall v. req x->v; ens x->v + 1 @*)
= x := !x + 2
