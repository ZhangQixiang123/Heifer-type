(* Tests for RaisingEff entailment *)

(* Simple effect *)
let eff_simple ()
(*@ ex r; Eff(emp, r); Norm(emp, r) @*)
= let r = perform Eff in
  r

(* Effect with heap *)
let eff_with_heap ()
(*@ ex i r; Eff(i->0, r); Norm(i->0, r) @*)
= let i = Sys.opaque_identity (ref 0) in
  let r = perform Eff in
  r

(* Sequential effects *)
let eff_seq ()
(*@ ex r1; Eff1(emp, r1); ex r2; Eff2(emp, r2); Norm(emp, r2) @*)
= let _ = perform Eff1 in
  perform Eff2

(* Effect followed by normal computation *)
let eff_then_compute ()
(*@ ex r; Eff(emp, r); Norm(emp, r+1) @*)
= let r = perform Eff in
  r + 1

(* Expected failure: wrong effect return value *)
let eff_wrong_false ()
(*@ ex r; Eff(emp, r); Norm(emp, 999) @*)
= perform Eff
