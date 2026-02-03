# Reynolds Separation Logic Paper - Examples Extraction

## Source
John C. Reynolds, "Separation Logic: A Logic for Shared Mutable Data Structures" (LICS 2002)

## Key Concepts for Test Cases

### Assertion Forms (Section 3)
- `emp` - empty heap
- `e → e'` - singleton heap (e points to e')
- `p * q` - separating conjunction (disjoint heaps)
- `p -* q` - separating implication

### Programming Language Commands (Section 2)
- `v := cons(e1,...,en)` - allocation
- `v := [e]` - lookup (dereference)
- `[e] := e'` - mutation
- `dispose e` - deallocation

---

## Extracted Examples

### 1. Mutation Rules (Section 4, p.8)

**Local Mutation:**
```
{e → −} [e] := e' {e → e'}
```

**Global Mutation (with frame):**
```
{(e → −) ∗ r} [e] := e' {(e → e') ∗ r}
```

OCaml test:
```ocaml
let mutation_local_true x v
(*@ forall w. req x->w; ens x->v @*)
= x := v

let mutation_global_true x y v
(*@ forall a b. req x->a * y->b; ens x->v * y->b @*)
= x := v
```

### 2. Deallocation Rules (Section 4, p.8)

**Local Deallocation:**
```
{e → −} dispose e {emp}
```

**Global Deallocation:**
```
{(e → −) ∗ r} dispose e {r}
```

Note: OCaml doesn't have explicit dispose, but we can test the frame preservation concept.

### 3. Allocation Rules (Section 4, p.8)

**Non-interfering Local:**
```
{emp} v := cons(e) {v → e}
```

**Non-interfering Global:**
```
{r} v := cons(e) {(v → e) ∗ r}
```

OCaml test:
```ocaml
let alloc_simple_true ()
(*@ ens res->42 @*)
= ref 42

let alloc_with_frame_true x
(*@ forall v. req x->v; ens res->0 * x->v @*)
= ref 0
```

### 4. Lookup Rules (Section 4, p.8-9)

**Local Lookup:**
```
{v = v' ∧ (e → v'')} v := [e] {v = v'' ∧ (e' → v'')}
```

**Global Lookup:**
```
{∃v''. (e → v'') ∗ (r/v → v)} v := [e] {∃v'. (e' → v) ∗ (r/v → v)}
```

OCaml test:
```ocaml
let lookup_true x
(*@ forall v. req x->v; ens x->v /\ res=v @*)
= !x
```

### 5. Cyclic Structure Construction (Section 4, p.9)

```
{emp}
x := cons(a, a) ;
{x → a, a}
y := cons(b, b) ;
{(x → a, a) ∗ (y → b, b)}
{(x → a, −) ∗ (y → b, −)}
[x + 1] := y − x ;
{(x → a, y − x) ∗ (y → b, −)}
[y + 1] := x − y ;
{(x → a, y − x) ∗ (y → b, x − y)}
{∃o. (x → a, o) ∗ (x + o → b, − o)}.
```

This is complex - we'll simplify to basic two-reference operations.

### 6. Swap Example (Section 4, implied by frame rule)

```
{x → a * y → b} swap(x,y) {x → b * y → a}
```

OCaml test:
```ocaml
let swap_true x y
(*@ forall a b. req x->a * y->b; ens x->b * y->a @*)
= let tmp = !x in
  x := !y;
  y := tmp
```

### 7. List Deletion (Section 5, p.10)

```
{list a·α (i, k)}
{∃j. i → a, j ∗ list α(j, k)}
{i → a ∗ ∃j. i + 1 → j ∗ list α(j, k)}
j := [i + 1] ;
{i → a ∗ i + 1 → j ∗ list α (j, k)}
dispose i ;
{i + 1 → j ∗ list α (j, k)}
dispose i +1;
{list α(j, k)}
i := j
{list α(i, k)}
```

Simplified for OCaml (without dispose):
```ocaml
(* Read first element of a "cons cell" represented as tuple ref *)
let read_head_true cell
(*@ forall h t. req cell->(h,t); ens cell->(h,t) /\ res=h @*)
= fst (!cell)
```

### 8. List Reversal Invariant (Section 5, p.10)

```
{∃α, β. (list α (i, nil) ∗ list β (j, nil)) ∧ α†_0 = α†·β ∧ i ≠ nil}
```

This requires inductive predicates - beyond simple_spec scope.

### 9. Tree Copy (Section 6, p.12)

```
{tree τ (i)} copytree(i; j) {tree τ (i) ∗ tree τ (j)}
```

Also requires inductive predicates.

### 10. Assertion Logic Examples (Section 3, p.4-5)

These show separating conjunction properties:

| Assertion | Meaning |
|-----------|---------|
| `x → 1` | x points to 1 |
| `x → 1 * y → 2` | x points to 1, y points to 2 (disjoint) |
| `x → 1 * x → 1` | false (same location can't be in disjoint heaps) |
| `x → 1 * true` | x points to 1, heap may have more |

OCaml tests:
```ocaml
(* Disjoint references *)
let disjoint_refs_true x y
(*@ forall a b. req x->a * y->b; ens x->a * y->b @*)
= ()

(* Frame preservation - reading doesn't change other refs *)
let read_preserves_frame_true x y
(*@ forall a b. req x->a * y->b; ens x->a * y->b /\ res=a @*)
= !x
```

---

## Test File Organization

### test/reynolds_examples.t/test_basic_ops.ml
- Mutation (local/global)
- Allocation
- Lookup
- Swap

### test/reynolds_examples.t/test_frame_rule.ml
- Frame preservation examples
- Disjoint heap operations

### test/reynolds_examples.t/test_sep_conj.ml
- Separating conjunction properties
- Multiple reference operations

### test/reynolds_examples.t/test_negative.ml
- Invalid specs that should fail
- Aliasing violations

---

## Mapping to OCaml/Heifer Syntax

| Reynolds Notation | Heifer Syntax |
|-------------------|---------------|
| `e → e'` | `e->e'` |
| `emp` | `emp` |
| `p * q` | `p * q` |
| `p ∧ q` | `p /\ q` |
| `∃x. p` | `exists x. p` |
| `∀x. p` | `forall x. p` |
| `{P} c {Q}` | `req P; ens Q` |

## Implementation Notes

1. The simple_spec system supports basic heap assertions
2. Inductive predicates (list, tree) are NOT supported in simple_spec
3. Separating implication (`-*`) is NOT supported in simple_spec
4. Focus on examples using only: `->`, `*`, `emp`, `/\`, `\/`, pure constraints
