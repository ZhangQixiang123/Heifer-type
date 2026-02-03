(* Tests for Shift entailment *)

(* Basic shift/reset - continuation applied once *)
let shift_basic ()
(*@ ens res=2 @*)
= reset (1 + shift (fun k -> k 1))

(* Shift returning without using continuation *)
let shift_abort ()
(*@ ens res=42 @*)
= reset (1 + shift (fun _k -> 42))

(* Shift with identity continuation *)
let shift_identity ()
(*@ ens res=10 @*)
= reset (shift (fun k -> k 10))

(* Shift0 basic *)
let shift0_basic ()
(*@ ens res=5 @*)
= reset (shift0 (fun k -> k 5))

(* Expected failure: wrong shift result *)
let shift_wrong_false ()
(*@ ens res=100 @*)
= reset (1 + shift (fun k -> k 1))
