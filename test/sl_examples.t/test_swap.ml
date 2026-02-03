(* Swap tests for separation logic *)

(* Basic swap - distinct references *)
let swap_distinct_true x y
(*@ forall a b. req x->a * y->b; ens x->b * y->a @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* Swap with frame preservation *)
let swap_frame_true x y z
(*@ forall a b c. req x->a * y->b * z->c; ens x->b * y->a * z->c @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* Self-swap (aliased case simulation) - value unchanged *)
let self_swap_true x
(*@ forall a. req x->a; ens x->a @*)
= let tmp = !x in
  x := !x;
  x := tmp

(* Wrong swap spec - claims identity but actually swaps *)
let swap_not_identity_false x y
(*@ forall a b. req x->a * y->b; ens x->a * y->b @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* Incomplete swap - only updates one cell *)
let partial_swap_false x y
(*@ forall a b. req x->a * y->b; ens x->b * y->a @*)
= x := !y
(* Missing: y := tmp *)
