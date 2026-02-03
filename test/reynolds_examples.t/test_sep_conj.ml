(* Reynolds Separation Logic Paper - Separating Conjunction Examples
   Section 3: Assertions and their Inference Rules (p.4-5)

   Key properties of separating conjunction (∗):
   - p ∗ q asserts that p and q hold for DISJOINT parts of the heap
   - Commutative: p ∗ q ⟺ q ∗ p
   - Associative: (p ∗ q) ∗ r ⟺ p ∗ (q ∗ r)
   - emp is neutral: p ∗ emp ⟺ p
   - Distributive with ∨: (p1 ∨ p2) ∗ q ⟺ (p1 ∗ q) ∨ (p2 ∗ q)

   Important: x → 1 ∗ x → 1 is FALSE (same location cannot be in disjoint heaps) *)

(* ========== BASIC SEPARATING CONJUNCTION ========== *)

(* Two disjoint references - basic sep conj *)
let two_refs_true x y
(*@ forall a b. req x->a * y->b; ens x->a * y->b @*)
= ()

(* Commutativity: p ∗ q ⟺ q ∗ p *)
let sep_commutative_true x y
(*@ forall a b. req x->a * y->b; ens y->b * x->a @*)
= ()

(* ========== EMP PROPERTIES ========== *)

(* emp is neutral: p ∗ emp ⟺ p (allocation returns exactly what's specified) *)
let alloc_single_true ()
(*@ ens res->42 @*)
= ref 42

(* emp as precondition means no heap requirement *)
let pure_computation_true x
(*@ ens res=x + 1 @*)
= x + 1

(* ========== DISJOINTNESS EXAMPLES (p.5) ========== *)

(* From paper: x → 1 ∗ y → 2 means disjoint single-cell heaps *)
let disjoint_writes_true x y
(*@ forall a b. req x->a * y->b; ens x->1 * y->2 @*)
= x := 1; y := 2

(* Reading from disjoint locations *)
let disjoint_reads_true x y
(*@ forall a b. req x->a * y->b; ens x->a * y->b /\ res=a + b @*)
= !x + !y

(* ========== ASSOCIATIVITY ========== *)

(* (p ∗ q) ∗ r ⟺ p ∗ (q ∗ r) - three disjoint refs *)
let three_refs_true x y z
(*@ forall a b c. req x->a * y->b * z->c; ens x->a * y->b * z->c @*)
= ()

(* Four disjoint references *)
let four_refs_true w x y z
(*@ forall a b c d. req w->a * x->b * y->c * z->d; ens w->a * x->b * y->c * z->d @*)
= ()

(* ========== OPERATIONS PRESERVING DISJOINTNESS ========== *)

(* Modify one of two disjoint refs *)
let modify_first_true x y
(*@ forall a b. req x->a * y->b; ens x->0 * y->b @*)
= x := 0

(* Modify second of two disjoint refs *)
let modify_second_true x y
(*@ forall a b. req x->a * y->b; ens x->a * y->0 @*)
= y := 0

(* Modify both disjoint refs *)
let modify_both_true x y
(*@ forall a b. req x->a * y->b; ens x->b * y->a @*)
= let tmp = !x in
  x := !y;
  y := tmp

(* ========== DISTRIBUTIVITY WITH PURE CONSTRAINTS ========== *)

(* Pure ∧ spatial: (p ∧ q) ∗ r ⟺ p ∧ (q ∗ r) when p is pure *)
let pure_and_spatial_true x y
(*@ forall a b. req x->a * y->b /\ a>0; ens x->a * y->b /\ a>0 @*)
= ()

(* Combining pure result with heap *)
let pure_result_with_heap_true x
(*@ forall v. req x->v; ens x->v /\ res=v + v @*)
= !x + !x

(* ========== CREATING NEW DISJOINT HEAPS ========== *)

(* Create two new disjoint references *)
let create_two_refs_true ()
(*@ ens res->0 @*)
= ref 0

(* Allocate preserving existing *)
let alloc_disjoint_true x
(*@ forall v. req x->v; ens x->v * res->0 @*)
= ref 0

(* ========== COMPLEX COMBINATIONS ========== *)

(* Sum of three references *)
let sum_three_true x y z
(*@ forall a b c. req x->a * y->b * z->c; ens x->a * y->b * z->c /\ res=a + b + c @*)
= !x + !y + !z

(* Rotate values through three refs *)
let rotate_three_true x y z
(*@ forall a b c. req x->a * y->b * z->c; ens x->b * y->c * z->a @*)
= let va = !x in
  let vb = !y in
  let vc = !z in
  x := vb;
  y := vc;
  z := va

(* ========== NEGATIVE TESTS ========== *)

(* Aliasing - same ref can't be in two disjoint heaps
   This test would be unsound if x and y alias *)
let aliasing_test_true x y
(*@ forall a b. req x->a * y->b; ens x->1 * y->2 @*)
= x := 1; y := 2

(* Missing separating conjunction - should fail
   (spec requires disjoint but we don't preserve y) *)
let missing_sep_false x y
(*@ forall a b. req x->a * y->b; ens x->42 @*)
= x := 42

(* Wrong heap relationship - should fail *)
let wrong_sep_false x y
(*@ forall a b. req x->a * y->b; ens x->b * y->b @*)
= x := !y
(* This should fail because the spec says y->b but we're reading y,
   and if implementation differs, it would be caught *)
