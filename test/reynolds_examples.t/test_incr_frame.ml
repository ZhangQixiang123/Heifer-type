let incr_with_frame x y
(*@ forall a b. req x->a * y->b; ens x->a + 1 * y->b @*)
= x := !x + 1
