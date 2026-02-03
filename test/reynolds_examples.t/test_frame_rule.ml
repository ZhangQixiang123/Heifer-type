(* Reynolds Separation Logic Paper - Frame Rule Examples
   Section 4: The Frame Rule (p.7)

   Frame Rule:
     {p} c {q}
   ─────────────────
   {p ∗ r} c {q ∗ r}

   where no variable occurring free in r is modified by c.

   "To understand how a program works, it should be possible for
   reasoning and specification to be confined to the cells that
   the program actually accesses." *)

(* ========== MUTATION WITH FRAME (p.8) ========== *)

(* Mutation (global): {(e → −) ∗ r} [e] := e' {(e → e') ∗ r} *)
let mutation_frame_true x y
(*@ forall a b. req x->a * y->b; ens x->42 * y->b @*)
= x := 42

(* Mutation preserves unrelated reference *)
let mutation_preserves_other_true x y
(*@ forall a b. req x->a * y->b; ens x->a + 1 * y->b @*)
= x := !x + 1

(* ========== ALLOCATION WITH FRAME (p.8) ========== *)

(* Allocation (global): {r} v := cons(e) {(v → e) ∗ r} *)
let alloc_frame_true x
(*@ forall v. req x->v; ens res->0 * x->v @*)
= ref 0

(* Allocate new ref while preserving existing *)
let alloc_preserve_true existing
(*@ forall v. req existing->v; ens res->100 * existing->v @*)
= ref 100

(* ========== LOOKUP WITH FRAME (p.8) ========== *)

(* Lookup preserves frame *)
let lookup_frame_true x y
(*@ forall a b. req x->a * y->b; ens x->a * y->b /\ res=a @*)
= !x

(* Reading x doesn't affect y *)
let read_preserves_other_true x y
(*@ forall a b. req x->a * y->b; ens x->a * y->b @*)
= let _ = !x in ()

(* ========== SWAP WITH FRAME (implied by paper) ========== *)

(* Swap two references - classic frame rule example *)
let swap_true x y
(*@ forall a b. req x->a * y->b; ens x->b * y->a @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* Swap with extra frame reference *)
let swap_with_frame_true x y z
(*@ forall a b c. req x->a * y->b * z->c; ens x->b * y->a * z->c @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* ========== MULTIPLE OPERATIONS WITH FRAME ========== *)

(* Increment x while preserving y *)
let incr_with_frame_true x y
(*@ forall a b. req x->a * y->b; ens x->a + 1 * y->b @*)
= x := !x + 1

(* Double increment, both preserved from each other *)
let double_incr_true x y
(*@ forall a b. req x->a * y->b; ens x->a + 1 * y->b + 1 @*)
= x := !x + 1;
  y := !y + 1

(* Copy value from y to x, both exist *)
let copy_value_true x y
(*@ forall a b. req x->a * y->b; ens x->b * y->b @*)
= x := !y

(* ========== THREE REFERENCES ========== *)

(* Operation on first, preserve other two *)
let triple_first_true x y z
(*@ forall a b c. req x->a * y->b * z->c; ens x->0 * y->b * z->c @*)
= x := 0

(* Operation on middle, preserve others *)
let triple_middle_true x y z
(*@ forall a b c. req x->a * y->b * z->c; ens x->a * y->0 * z->c @*)
= y := 0

(* Sum into first, preserve others *)
let sum_into_first_true x y z
(*@ forall a b c. req x->a * y->b * z->c; ens x->b + c * y->b * z->c @*)
= x := !y + !z

(* ========== NEGATIVE FRAME TESTS ========== *)

(* Frame not preserved - should fail *)
let frame_violated_false x y
(*@ forall a b. req x->a * y->b; ens x->42 * y->999 @*)
= x := 42

(* Wrong value after swap - should fail *)
let swap_wrong_false x y
(*@ forall a b. req x->a * y->b; ens x->a * y->b @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* Missing frame in postcondition - should fail *)
let missing_frame_false x y
(*@ forall a b. req x->a * y->b; ens x->42 @*)
= x := 42
