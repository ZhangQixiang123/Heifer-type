(* Tests for Reset entailment *)

(* Reset of pure value - should eliminate *)
let reset_pure ()
(*@ ens res=42 @*)
= reset 42

(* Reset of computation *)
let reset_add ()
(*@ ens res=3 @*)
= reset (1 + 2)

(* Nested reset *)
let reset_nested ()
(*@ ens res=5 @*)
= reset (reset (2 + 3))

(* Reset with let binding *)
let reset_let ()
(*@ ens res=10 @*)
= reset (let x = 5 in x + x)

(* Expected failure: wrong result *)
let reset_wrong_false ()
(*@ ens res=100 @*)
= reset 42
