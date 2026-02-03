(* Tests for simple separation logic specifications on heap operations *)

(* Basic reference creation - using simple pre/post *)
let ref_create_true ()
(*@ ens res->42 @*)
= ref 42

(* Read from reference with precondition *)
let ref_read_true x
(*@ forall v. req x->v; ens x->v /\ res=v @*)
= !x

(* Write to reference with precondition *)
let ref_write_true x
(*@ forall v. req x->v; ens x->100 @*)
= x := 100

(* Swap two references *)
let swap_true x y
(*@ forall a b. req x->a * y->b; ens x->b * y->a @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* Increment reference *)
let incr_ref_true x
(*@ forall v. req x->v; ens x->v+1 @*)
= x := !x + 1

(* Wrong postcondition - should fail *)
let ref_wrong_false x
(*@ forall v. req x->v; ens x->v+2 @*)
= x := !x + 1

(* Missing heap in postcondition - should fail *)
let ref_missing_false x
(*@ forall v. req x->v; ens emp @*)
= !x
