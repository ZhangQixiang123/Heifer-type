(* Tests for heap entailment including frame rule *)

(* Basic heap allocation *)
let heap_basic ()
(*@ ex i. ens i->42 /\ res=() @*)
= let i = ref 42 in
  ()

(* Heap with read *)
let heap_read ()
(*@ ex i. ens i->42 /\ res=42 @*)
= let i = ref 42 in
  !i

(* Heap with update *)
let heap_update ()
(*@ ex i. ens i->43 /\ res=() @*)
= let i = ref 42 in
  i := 43

(* Two heap locations - separating conjunction *)
let heap_two ()
(*@ ex a b. ens a->1 * b->2 /\ res=3 @*)
= let a = ref 1 in
  let b = ref 2 in
  !a + !b

(* Frame rule: extra heap preserved *)
let heap_frame ()
(*@ ex a b. ens a->10 * b->0 /\ res=() @*)
= let a = ref 0 in
  let b = ref 0 in
  a := 10

(* Heap with precondition *)
let heap_precond x
(*@ forall v. req x->v; ens x->v /\ res=v @*)
= !x

(* Heap update with precondition *)
let heap_update_precond x
(*@ forall v. req x->v; ens x->v+1 /\ res=() @*)
= x := !x + 1

(* Expected failure: wrong heap value *)
let heap_wrong_false ()
(*@ ex i. ens i->100 /\ res=() @*)
= let i = ref 42 in
  ()

(* Expected failure: missing heap *)
let heap_missing_false ()
(*@ ens emp /\ res=() @*)
= let i = ref 42 in
  ()
