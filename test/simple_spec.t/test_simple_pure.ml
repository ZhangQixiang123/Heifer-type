(* Tests for simple separation logic specifications on pure computations *)

(* Basic arithmetic *)
let add_true x y
(*@ ens res=x+y @*)
= x + y

(* Constant function *)
let const_true ()
(*@ ens res=42 @*)
= 42

(* Identity function *)
let id_true x
(*@ ens res=x @*)
= x

(* Boolean function *)
let is_positive_true x
(*@ ens res=x>0 \/ res=x<=0 @*)
= x > 0

(* Tuple unpacking *)
let fst_pair_true x y
(*@ ens res=x @*)
= fst (x, y)

(* Wrong result - should fail *)
let add_wrong_false x y
(*@ ens res=x-y @*)
= x + y

(* Overconstrained - should fail *)
let const_wrong_false ()
(*@ ens res=100 @*)
= 42
