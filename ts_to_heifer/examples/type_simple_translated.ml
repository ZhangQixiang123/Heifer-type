(* Translated from TypeScript *)

let id2 y = y
 (*@ req y:#int ; ens res : # int @*)

let plus x y = (x + y)
 (*@ req x:#int /\ y:#int ; ens res : # int @*)

let id y = let x = y in
x
 (*@ req y:#int ; ens res : # int @*)

let id2_str y = y
 (*@ req y:#string ; ens res : # string @*)

let id3 x = id2_str x
 (*@ req x:#string ; ens res : # string @*)

(* Translation complete: 5 function(s) *)
