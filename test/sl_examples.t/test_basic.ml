(* Basic separation logic tests for the new sl_spec system *)

(* Basic reference creation *)
let ref_create_true ()
(*@ ens res->42 @*)
= ref 42

(* Read from reference *)
let ref_read_true x
(*@ forall v. req x->v; ens x->v /\ res=v @*)
= !x

(* Write to reference *)
let ref_write_true x
(*@ forall v. req x->v; ens x->100 @*)
= x := 100

(* Write with frame - preserves y *)
let write_frame_true x y
(*@ forall a b. req x->a * y->b; ens x->42 * y->b @*)
= x := 42

(* Read-then-write: increment *)
let incr_true x
(*@ forall v. req x->v; ens x->v+1 @*)
= x := !x + 1

(* Increment with frame *)
let incr_frame_true x y
(*@ forall a b. req x->a * y->b; ens x->a+1 * y->b @*)
= x := !x + 1

(* Wrong postcondition - should fail *)
let incr_wrong_false x
(*@ forall v. req x->v; ens x->v+2 @*)
= x := !x + 1

(* Frame violated - should fail *)
let frame_violated_false x y
(*@ forall a b. req x->a * y->b; ens x->42 * y->999 @*)
= x := 42
