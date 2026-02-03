(* Reynolds Separation Logic Paper - Cons Cell / List-like Examples
   Section 5: Lists (p.9-11)

   The paper defines list predicates inductively:
     list ε (i, j) ≝ emp ∧ i = j
     list a·α (i, k) ≝ ∃j. i → a, j ∗ list α (j, k)

   Since simple_spec doesn't support inductive predicates,
   we test the basic building blocks: cons cells represented
   as pairs of references or tuple references. *)

(* ========== CONS CELL AS PAIR OF REFS ========== *)

(* Create a cons cell (head, tail) - simplified *)
let make_cons_true h t
(*@ ens res->h @*)
= ref h

(* Read head of cons cell *)
let read_head_true cell
(*@ forall h. req cell->h; ens cell->h /\ res=h @*)
= !cell

(* Update head of cons cell *)
let set_head_true cell newhead
(*@ forall h. req cell->h; ens cell->newhead @*)
= cell := newhead

(* ========== TWO-CELL OPERATIONS (like list segment) ========== *)

(* Two separate cons cells - like list α (i, j) ∗ list β (j, k) *)
let two_cells_true c1 c2
(*@ forall a b. req c1->a * c2->b; ens c1->a * c2->b @*)
= ()

(* Read both cells *)
let read_two_cells_true c1 c2
(*@ forall a b. req c1->a * c2->b; ens c1->a * c2->b /\ res=a + b @*)
= !c1 + !c2

(* Swap values between two cells *)
let swap_cells_true c1 c2
(*@ forall a b. req c1->a * c2->b; ens c1->b * c2->a @*)
= let tmp = !c1 in
  c1 := !c2;
  c2 := tmp

(* ========== LIST DELETION PATTERN (Section 5, p.10) ========== *)

(* From paper's list deletion proof outline:
   {list a·α (i, k)}
   j := [i + 1] ;
   dispose i ;
   dispose i + 1;
   i := j
   {list α(i, k)}

   Simplified: given a cell, read and return its value *)
let cell_extract_true cell
(*@ forall v. req cell->v; ens cell->v /\ res=v @*)
= !cell

(* ========== LIST-LIKE TRAVERSAL PATTERNS ========== *)

(* Process two adjacent cells (like reading first two elements) *)
let process_adjacent_true c1 c2
(*@ forall a b. req c1->a * c2->b; ens c1->a + a * c2->b + b @*)
= c1 := !c1 + !c1;
  c2 := !c2 + !c2

(* Copy value from first to second cell *)
let copy_forward_true c1 c2
(*@ forall a b. req c1->a * c2->b; ens c1->a * c2->a @*)
= c2 := !c1

(* ========== CYCLIC STRUCTURE EXAMPLE (Section 4, p.9) ========== *)

(* From paper:
   {emp}
   x := cons(a, a) ;
   y := cons(b, b) ;
   {(x → a, a) ∗ (y → b, b)}

   Simplified: create two independent cells *)
let create_two_cells_true ()
(*@ ens res->0 @*)
= ref 0

(* ========== PATTERNS FROM LIST REVERSAL (Section 5) ========== *)

(* The reversal invariant involves:
   ∃α, β. (list α (i, nil) ∗ list β (j, nil)) ∧ α†₀ = α†·β

   Simplified: maintain two separate cell chains *)
let reverse_step_true curr prev
(*@ forall a b. req curr->a * prev->b; ens curr->b * prev->a @*)
= let tmp = !curr in
  curr := !prev;
  prev := tmp

(* ========== TREE-LIKE OPERATIONS (Section 6) ========== *)

(* The paper defines tree τ (i) inductively.
   Simplified: just two children references *)
let create_tree_node_true left right
(*@ forall l r. req left->l * right->r; ens left->l * right->r @*)
= ()

(* Read both children *)
let read_children_true left right
(*@ forall l r. req left->l * right->r; ens left->l * right->r /\ res=l + r @*)
= !left + !right

(* ========== NEGATIVE TESTS ========== *)

(* Wrong cell value after read - should fail *)
let cell_read_wrong_false cell
(*@ forall v. req cell->v; ens cell->v /\ res=v + 1 @*)
= !cell

(* Missing cell in postcondition - should fail *)
let missing_cell_false c1 c2
(*@ forall a b. req c1->a * c2->b; ens c1->42 @*)
= c1 := 42

(* Wrong swap result - should fail *)
let swap_wrong_false c1 c2
(*@ forall a b. req c1->a * c2->b; ens c1->a * c2->b @*)
= let tmp = !c1 in
  c1 := !c2;
  c2 := tmp
