(* Full Swap Specification Tests

   Target specification from Heifer paper:

   swap: forall A:AnyP, a,b:Any. case [x, y] {
     x:Ref(A) /\ y:Ref(A) => ens [r] r:();           -- Case 1: type only
     x->Ref(a) * y->Ref(b) => ens [r] x->Ref(b) * y->Ref(a) /\ r:();  -- Case 2: separate
     x->Ref(a) /\ y:x => ens [r] x->Ref(a) /\ r:()   -- Case 3: aliased
   }

   In our syntax, this is expressed as:

   forall a b.
     (req x:Ref(a) /\ y:Ref(b); ens res=())              -- Case 1: type only
     \/
     (req x->a * y->b; ens x->b * y->a)                  -- Case 2: separate
     \/
     (req x->a /\ y=x; ens x->a)                         -- Case 3: aliased (self-swap)
*)

(* ========== SIMPLE SWAP (Case 2 only) ========== *)

(* Basic swap - already working *)
let swap_basic_true x y
(*@ forall a b.
    req x->a * y->b;
    ens x->b * y->a @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* ========== CASE 2: SEPARATE LOCATIONS ========== *)

(* Explicit separate case from full spec *)
let swap_separate_true x y
(*@ forall a b.
    req x->a * y->b;
    ens x->b * y->a @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* With frame preservation *)
let swap_separate_frame_true x y z
(*@ forall a b c.
    req x->a * y->b * z->c;
    ens x->b * y->a * z->c @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* ========== CASE 3: ALIASED (Self-swap) ========== *)

(* When x and y are the same reference, swap is a no-op.
   Spec: req x->a /\ y=x; ens x->a

   This requires alias-aware entailment.
*)
let self_swap_true x
(*@ forall a.
    req x->a;
    ens x->a @*)
= let tmp = !x in
  x := !x;
  x := tmp

(* Negative: wrong spec for self-swap *)
let self_swap_wrong_false x
(*@ forall a.
    req x->a;
    ens x->42 @*)
= let tmp = !x in
  x := !x;
  x := tmp

(* ========== DISJUNCTIVE DECLARED SPEC ========== *)

(* Simple disjunction: accepts either result *)
let swap_or_identity_true x y
(*@ forall a b.
    req x->a * y->b;
    ens x->b * y->a
    \/
    ens x->a * y->b @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* Disjunction where only second branch is satisfied.
   NOTE: Need parentheses around the disjunction to make precondition shared! *)
let identity_satisfies_disj_true x y
(*@ forall a b.
    req x->a * y->b;
    (ens x->999 * y->999 \/ ens x->a * y->b) @*)
= ()  (* identity: doesn't modify anything *)

(* Negative: neither branch satisfied *)
let swap_wrong_disj_false x y
(*@ forall a b.
    req x->a * y->b;
    ens x->100 * y->200
    \/
    ens x->300 * y->400 @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* ========== FULL CASE ANALYSIS (Simplified) ========== *)

(* Two-case version: separate or same
   This tests disjunction in declared spec with different preconditions *)
let swap_two_cases_true x y
(*@ forall a b.
    (req x->a * y->b; ens x->b * y->a)
    \/
    (req x->a; ens x->a) @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* Note: The full 3-case spec requires runtime case analysis which is beyond
   current forward verification. The spec assumes we can statically determine
   which case applies. *)

(* ========== HELPER TESTS ========== *)

(* Test that equality constraint parsing works *)
let equality_in_pre_true x y
(*@ forall a.
    req x->a /\ y=x;
    ens x->a @*)
= ()  (* identity when x=y *)

(* Test type predicate parsing (may not verify due to type checking) *)
(* let type_pred_test x
(*@ req x:Int; ens res=() @*)
= () *)

(* ========== NEGATIVE TESTS ========== *)

(* Wrong result for swap *)
let swap_identity_wrong_false x y
(*@ forall a b.
    req x->a * y->b;
    ens x->a * y->b @*)
= let tmp = !x in
  x := !y;
  y := tmp
(* Should fail: actual result is x->b, y->a but spec says x->a, y->b *)

(* Incomplete swap (only updates one) *)
let swap_partial_false x y
(*@ forall a b.
    req x->a * y->b;
    ens x->b * y->a @*)
= x := !y
(* Should fail: y still has b, not a *)
