(* Tests for Disjunction entailment - verifies the bug fix in rewriting.ml *)

(* Simple disjunction *)
let disj_simple b
(*@ ens res=1 \/ ens res=2 @*)
= if b then 1 else 2

(* Disjunction subsumed by single spec *)
let disj_subsume b
(*@ ens res>0 @*)
= if b then 1 else 2

(* Disjunction with heap *)
let disj_heap b
(*@ ex i. ens i->1 /\ res=1 \/ ex i. ens i->2 /\ res=2 @*)
= if b then
    let i = ref 1 in 1
  else
    let i = ref 2 in 2

(* Nested if creating disjunction *)
let disj_nested a b
(*@ ens res=1 \/ ens res=2 \/ ens res=3 @*)
= if a then 1
  else if b then 2
  else 3

(* Expected failure: disjunction not covering all cases *)
let disj_incomplete_false b
(*@ ens res=1 @*)
= if b then 1 else 2
