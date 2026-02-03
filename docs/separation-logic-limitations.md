# Separation Logic Verification: Limitations and Improvements

## Current State

The verification system now correctly handles simple separation logic operations with frame rule support. However, several categories of tests still fail.

### Test Results Summary

| Category | Examples | Status |
|----------|----------|--------|
| Single heap access + frame | `mutation_frame_true`, `alloc_frame_true` | ✓ Pass |
| Read-only with frame | `lookup_frame_true`, `read_preserves_other_true` | ✓ Pass |
| Single write in multi-ref context | `triple_first_true`, `triple_middle_true` | ✓ Pass |
| Read-then-write (`!x + 1`) | `mutation_preserves_other_true`, `incr_with_frame_true` | ✗ Fail |
| Multiple read/write (swap) | `swap_true`, `swap_cells_true` | ✗ Fail |
| Negative tests (should fail) | `frame_violated_false`, `missing_frame_false` | ✗ Incorrectly pass |

---

## Limitation 1: Sequential Requirements Not Combinable

### The Problem

For operations like `x := !x + 1`, the forward verifier produces:

```
let v5 = (
  let v4 = (forall v9. (req x->v9; ens x->v9 /\ res=v9))  (* read *)
  in (ens res=(v4 + 1))
) in (
  forall v10. (req x->v10; ens x->v5)  (* write *)
)
```

After normalization, this becomes:
```
forall v9. (req x->v9; forall v10. (ens x->v9; req x->v10; ens x->(v9 + 1)))
```

This has **two separate Require clauses** with different heap states:
1. `req x->v9` - initial state for read
2. `req x->v10` - state for write (should be v9, but is fresh v10)

The `simple_spec` model only supports **one precondition**.

### Why It Happens

The forward verifier treats each heap operation independently:
- `!x` produces `forall v. (req x->v; ens x->v /\ res=v)`
- `x := e` produces `forall v. (req x->v; ens x->e)`

When composed with `Bind`, they stay separate.

### Proposed Solution

**Option A: Semantic Requirement Merging**

Add a normalization pass that recognizes sequential requirements on the same location and merges them:

```ocaml
(* Pattern: req x->v1; ...; req x->v2  where v1 should equal v2 *)
| Sequence(Require(p1, PointsTo(loc1, v1)),
           Sequence(_, Sequence(Require(p2, PointsTo(loc2, v2)), rest)))
  when loc1 = loc2 ->
    (* Unify v1 and v2, keep only first requirement *)
    Sequence(Require(p1, PointsTo(loc1, v1)),
             subst [(v2, v1)] rest)
```

**Option B: Weakest Precondition Style**

Instead of forward symbolic execution, use weakest precondition to compute what's needed:
- Start from postcondition
- Work backwards through operations
- Naturally combines requirements

**Option C: Direct State Entailment**

Skip `simple_of_staged` for complex specs and use `State_entail` directly on the combined heap state:

```ocaml
let verify_with_state_entail inferred_staged declared_staged =
  (* Extract all heap facts from inferred *)
  let inferred_heap = collect_all_heap_facts inferred_staged in
  let declared_pre, declared_post = extract_pre_post declared_staged in
  (* Check: declared_pre ⊢ inferred_heap.pre (with frame) *)
  (* Check: inferred_heap.post * frame ⊢ declared_post *)
```

---

## Limitation 2: ForAll Inside Bind Not Fully Normalized

### The Problem

The forward verifier produces specs with `ForAll` quantifiers inside `Bind` structures:

```
let tmp = (forall v14. (req x->v14; ens x->v14 /\ res=v14)) in ...
```

While the normalization lifts `ForAll` outside, it doesn't fully flatten when there are nested `Bind`s with multiple `ForAll`s.

### Current Handling

The normalization handles some patterns:
```ocaml
| Bind (x, ForAll (y, inner1), inner2) ->
    ForAll (y, normalize (Bind (x, inner1, inner2)))
```

But fails for complex nesting like:
```
let tmp = (forall v1. (req x->v1; ...)) in
  (let v2 = (forall v3. (req y->v3; ...)) in ...)
```

### Proposed Solution

Implement a more aggressive flattening that:
1. Collects all `ForAll` quantifiers to the top level
2. Collects all `Require` clauses and combines them with `*`
3. Collects all `NormalReturn` clauses and combines them

```ocaml
type flat_spec = {
  quantifiers: binder list;       (* forall variables *)
  existentials: binder list;      (* exists variables *)
  precondition: state option;     (* combined req *)
  postcondition: state;           (* combined ens *)
}

let flatten_to_simple : staged_spec -> flat_spec option
```

---

## Limitation 3: Negative Tests Incorrectly Pass

### The Problem

Tests like `frame_violated_false` and `missing_frame_false` should fail but pass:

```ocaml
(* Should FAIL: frame not preserved *)
let frame_violated_false x y
(*@ forall a b. req x->a * y->b; ens x->42 * y->999 @*)
= x := 42  (* Only modifies x, can't change y to 999 *)

(* Should FAIL: missing y in postcondition *)
let missing_frame_false x y
(*@ forall a b. req x->a * y->b; ens x->42 @*)
= x := 42
```

### Why It Happens

These tests fall through to the staged entailment path because:
1. The inferred spec is complex (can't be simplified)
2. The staged entailment in `entail.ml` doesn't properly verify frame preservation

Looking at the entailment debug output, the staged path doesn't correctly check that:
- `y->999` can't be derived from `y->b` alone (frame_violated)
- `y->b` must appear in postcondition if in precondition (missing_frame)

### Proposed Solution

**Option A: Enhance Simple Entailment Coverage**

Make `simple_of_staged` more aggressive so these specs can use the simple path:
- Even if the inferred spec is complex, if the declared spec is simple, try to verify
- Extract key properties from inferred spec that matter for verification

**Option B: Fix Staged Entailment Frame Rule**

Add frame rule checking to `entail.ml`:

```ocaml
(* When matching Require clauses, track the frame *)
| Sequence (Require (p1, h1), f1), Sequence (Require (p2, h2), f2) ->
    let frame = compute_frame h2 h1 in
    (* Frame must appear in both postconditions *)
    check_frame_preserved frame f1 f2;
    ...
```

**Option C: Separate Frame Verification Pass**

After entailment, run a separate pass that:
1. Computes the frame from precondition matching
2. Verifies the frame appears unchanged in both postconditions

---

## Limitation 4: Y Variable Not Tracked

### The Problem

For `x := 42` with declared spec `req x->a * y->b; ens x->42 * y->b`:

The forward verifier only produces:
```
forall v. (req x->v; ens x->42)
```

It doesn't know about `y` at all because the code never accesses `y`.

### Why It's a Problem

The frame rule says: if code only touches `x`, then `y->b` is preserved. But the forward verifier doesn't track what ISN'T touched.

### Current Solution (Partial)

The simple_entail frame rule implementation handles this:
1. `declared.pre = x->a * y->b`
2. `inferred.pre = x->v`
3. Frame = `y->b` (what's in declared but not inferred)
4. Check: `inferred.post * frame ⊢ declared.post`
5. So: `x->42 * y->b ⊢ x->42 * y->b` ✓

This works for simple cases but fails when the inferred spec can't be simplified.

### Proposed Solution

Extend the frame computation to work on staged specs:

```ocaml
let compute_frame_from_staged declared inferred =
  let declared_reqs = collect_all_requires declared in
  let inferred_reqs = collect_all_requires inferred in
  (* Frame = declared_reqs - inferred_reqs (set difference on locations) *)
  heap_difference declared_reqs inferred_reqs
```

---

## Limitation 5: Fresh Variable Proliferation

### The Problem

Each heap access introduces fresh universally quantified variables:
- Read `!x` → `forall v1. (req x->v1; ...)`
- Read `!x` again → `forall v2. (req x->v2; ...)`
- Write `x := e` → `forall v3. (req x->v3; ...)`

These are semantically the same (all refer to x's value) but syntactically different.

### Current Partial Solution

`State_entail` substitutes equalities:
- If we have `res=v1` in pure part, substitute `v1->42` to `res->42`

But this only works for `res`, not for arbitrary variable unification.

### Proposed Solution

Implement proper unification of heap location variables:

```ocaml
let unify_heap_vars spec =
  (* Build equivalence classes of variables pointing to same location *)
  let location_vars = collect_location_vars spec in
  (* For each location, pick canonical representative *)
  let canonical = pick_representatives location_vars in
  (* Substitute all vars to canonical form *)
  subst_to_canonical canonical spec
```

---

## Implementation Priority

### Phase 1: Make More Tests Pass (High Impact)

1. **Semantic Requirement Merging** - Handle read-then-write pattern
2. **Variable Unification** - Recognize same-location accesses

### Phase 2: Fix Negative Tests (Correctness)

3. **Frame Preservation Check** - Verify frame unchanged in postcondition
4. **Anti-frame Checking** - Ensure nothing extra appears in postcondition

### Phase 3: General Improvements (Robustness)

5. **Flatten All Specs** - Convert any spec to flat form before checking
6. **Better Error Messages** - Report why verification failed

---

## Architecture Recommendation

The current 5-level hierarchy is:
```
pi (pure) → kappa (heap) → state (pi*kappa) → staged_spec → pstate
```

For simple separation logic, we should add a parallel "simple" path:

```
                    ┌─────────────────┐
                    │   staged_spec   │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │ normalize    │ complex only │
              ▼              ▼              ▼
     ┌────────────────┐  ┌──────────────────────┐
     │  simple_spec   │  │ entailment_search    │
     │ (req P; ens Q) │  │ (staged entail)      │
     └───────┬────────┘  └──────────────────────┘
             │
             ▼
     ┌────────────────┐
     │ State_entail   │
     │ (biabduction)  │
     └────────────────┘
```

The simple path should:
1. Handle all cases where declared spec is `req P; ens Q`
2. Use frame rule with biabduction
3. Fall back to staged entail only for effects/exceptions

This architecture separates concerns and makes the simple case robust.
