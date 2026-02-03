let incr x
(*@ forall a. req x->a; ens x->a + 1 @*)
= x := !x + 1
