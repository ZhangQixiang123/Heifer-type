# Separation Logic & Reference Type Investigation

## Date: 2025-01-XX
## Context: TypeScript to Heifer Translator - Global Variable Support

---

## 1. Research Question

How does Heifer handle reference types with respect to:
- Flow sensitivity (fixed vs varying inner types)
- Aliasing analysis
- Case-based/conditional specifications
- Heap predicates in separation logic

---

## 2. Key Findings Summary

### Reference Type System

**Heifer uses FLOW-INSENSITIVE reference types:**
- `ref(α)` has a **fixed inner type** `α` determined at allocation
- Type does NOT vary across program execution
- Inner type `α` is bound at `ref v` and preserved through all operations

### Type Signatures (Flow-Insensitive View)

```ocaml
mkRef  : α → ref(α)
(!)    : ref(α) → α
(:=)   : ref(α) × α → unit
```

**Evidence from codebase:**
```ocaml
(* File: lib/hipprover/infer_types.ml lines 189-195 *)
| CRef value ->
    let* value = infer_types_term value in
    return (CRef value, wrap_as_ref value.term_type)  (* Type fixed here *)

| CRead value ->
    let val_type = fresh_type_var () in
    let* _ = assert_var_has_type (value, wrap_as_ref val_type) (wrap_as_ref val_type) in
    return (CRead value, val_type)  (* Must match fixed type *)

| CWrite (loc, value) ->
    let* value = infer_types_term value in
    let loc_type = wrap_as_ref value.term_type in
    let* _ = assert_var_has_type (loc, loc_type) loc_type in  (* Type consistency enforced *)
    return (CWrite (loc, value), Unit)
```

---

## 3. Separation Logic: Heap vs Types

While **types are flow-insensitive**, **heap assertions are flow-sensitive**:

### Type System (Flow-Insensitive)
```
x : ref(int)  (* Fixed throughout execution *)
```

### Heap Assertions (Flow-Sensitive)
```
Before: x → 5
After:  x → 42
```

**The heap content evolves, but the type stays `ref(int)`**

---

## 4. Refined Type Signatures with Heap Reasoning

### Actual Heifer Specifications (with Aliasing Awareness)

```
mkRef : req [x] x:Any
        ens [r] r→Ref(x)

(!)   : ∀T:AnyP, q:Any. case [m] {
          m:Ref(T) ⇒ ens [r] r:T;
          m→Ref(q) ⇒ ens [r] m→Ref(q) ∧ r:q
        }

update : ∀T:AnyP. case [m,v] {
          m:Ref(T) ∧ v:T ⇒ ens [r] r:();
          m→Ref(_) ∧ v:Any ⇒ ens [r] m→Ref(v) ∧ r:()
        }
```

**Interpretation:**
- **First branch**: Type-based reasoning (flow-insensitive, no heap)
- **Second branch**: Heap-based reasoning (flow-sensitive, tracks actual values)

---

## 5. Case-Based Specifications in Heifer

### Does Heifer Support `case` syntax?

**NO explicit `case` keyword**, but **YES through disjunctive specifications** using `\/`

### Evidence from Codebase

**Parser support** (`lib/parsing/parser.mly` line 274):
```mly
| s1 = single_staged_spec DISJUNCTION s2 = single_staged_spec
    { Disjunction (s1, s2) }
```

**AST support** (`lib/hipcore_typed/typed_core_ast.ml` line 175):
```ocaml
and staged_spec =
  ...
  | Disjunction of staged_spec * staged_spec
  ...
```

---

## 6. Real Examples from Heifer Codebase

### Example 1: Simple Disjunction (Boolean Result)
**File**: `test/basic.t/test_new_entail.ml`
```ocaml
let if_disj b
(*@ ens emp/\res=1 \/ ens emp/\res=2 @*)
= if b then 1 else 2
```

### Example 2: Heap-Based Branching
**File**: `test/demo/8_schduler.ml`
```ocaml
let queue_is_empty queue
(*@ ex q ; req queue->q /\ effNo(q)=0; ens queue->q /\ res=true
\/  ex q ; req queue->q /\ effNo(q)>0; ens queue->q /\ res=false @*)
= let (front, back) = !queue in
  List.length front = 0 && List.length back = 0
```

**Two branches with different heap predicates:**
- Branch 1: `effNo(q)=0` → result is `true`
- Branch 2: `effNo(q)>0` → result is `false`

### Example 3: Recursive with Disjunction
**File**: `test/demo/5_Shallow_Right_Toss.ml`
```ocaml
let rec tossNtimeRight n
(*@ req n>=1; ex r; Flip(n=1, r) ; Norm(res=r, res) \/
    req n>=1; ex r1; Flip(emp, r1); ex r2; tossNtimeRight(n-1, r2); Norm(n>1, r1&&r2)  @*)
= if n==1 then perform Flip
  else let r1 = perform Flip in
       let r2 = tossNtimeRight (n-1) in
       r1 && r2
```

---

## 7. Translating Case-Based Specs to Heifer Syntax

### Original "Case" Syntax (Proposed)
```
swap : case [x, y] {
  x:Ref(A) ∧ y:Ref(A) ⇒ ens [r] r:();
  x→Ref(a) * y→Ref(b) ⇒ ens [r] x→Ref(b) * y→Ref(a) ∧ r:();
  x→Ref(a) ∧ y:x ⇒ ens [r] x→Ref(a) ∧ r:()
}
```

### Heifer Equivalent (Using Disjunction)
```ocaml
let swap x y
  (*@ forall A. req x:Ref(A) /\ y:Ref(A); ens res:()
      \/
      forall a b. req x→Ref(a) * y→Ref(b); ens x→Ref(b) * y→Ref(a) /\ res:()
      \/
      forall a. req x→Ref(a) /\ y:x; ens x→Ref(a) /\ res:()
  @*)
  = let v1 = !x in
    let v2 = !y in
    x := v2;
    y := v1
```

**Three branches:**
1. Type-level only (no heap assertions)
2. **Non-aliased** case: `x→Ref(a) * y→Ref(b)` (separating conjunction `*` implies distinct locations)
3. **Aliased** case: `x→Ref(a) /\ y:x` (conjunction `/\` with equality `y:x`)

---

## 8. Prover Support for Disjunctions

**File**: `lib/hipprover/entail.ml`

### Disjunction on Left (Precondition)
```ocaml
| Disjunction (f1, f2), f2 ->
  (* Try left branch *)
  let@ _ = entailment_search (pctx, f1, f2) in
  (* Try right branch *)
  entailment_search (pctx, f2, f2) k
```

### Disjunction on Right (Postcondition)
```ocaml
| f1, Disjunction (f3, f4) ->
  (* Try either disjunct *)
  or_
    (fun k1 -> entailment_search (pctx, f1, f3) k1)
    (fun k1 -> entailment_search (pctx, f1, f4) k1)
    k
```

---

## 9. Forward Semantics for Reference Operations

### Reference Allocation (`CRef`)
**File**: `lib/hipprover/forward_rules.ml` lines 353-355
```ocaml
| CRef t ->
    let x = (fresh_variable (), TConstr ("ref", [t.term_type])) in
    Exists (x, NormalReturn (res_eq (var_of_binder x),
            PointsTo (ident_of_binder x, t))), env
```

**Spec**: `∃x. res=x ∧ x→t` (allocate fresh location `x` pointing to `t`)

### Dereference (`CRead`)
**File**: `lib/hipprover/forward_rules.ml` lines 361-367
```ocaml
| CRead x ->
    let v = fresh_variable () in
    let t = var ~typ:expr.core_type v in
    let kappa = PointsTo (x, t) in
    let req = Require (True, kappa) in
    let ens = NormalReturn (res_eq t, kappa) in
    ForAll (binder_of_var t, (Sequence (req, ens))), env
```

**Spec**: `∀v. req x→v; ens res=v ∧ x→v` (read value, preserve heap)

### Write (`CWrite`)
**File**: `lib/hipprover/forward_rules.ml` lines 356-360
```ocaml
| CWrite (x, t) ->
    let v = (fresh_variable (), t.term_type) in
    let req = Require (True, PointsTo (x, var_of_binder v)) in
    let ens = NormalReturn (True, PointsTo (x, t)) in
    ForAll (v, Sequence (req, ens)), env
```

**Spec**: `∀v. req x→v; ens x→t` (overwrite old value `v` with `t`)

---

## 10. Implications for TypeScript Translator

### Global Variables
Each TypeScript global `let globalX: number = 0` translates to:
```ocaml
let globalX = ref 0 in
```

**Type**: `ref(int)` (flow-insensitive, fixed)
**Heap**: Initially `globalX → 0`, evolves with writes

### No Aliasing Between Distinct Globals
```typescript
let x: number = 0;
let y: number = 0;
```

Translates to:
```ocaml
let x = ref 0 in
let y = ref 0 in
```

**`x` and `y` are DISTINCT heap locations** (no aliasing possible)

### Spec Generation Strategy

#### Phase 1-2: Enable Global Access (IMPLEMENT NOW)
- Pass outer context to functions
- Functions can read/write globals
- Globals translated as `ref` cells

#### Phase 3: Basic Heap Specs (IMPLEMENT NOW - Simple Version)
**Auto-generate conservative specs:**
```
function increment(): void {
  globalCounter = globalCounter + 1;
}
```

**Generated spec:**
```ocaml
(*@ req globalCounter→?v;
    ens globalCounter→v' /\ res:unit
@*)
```

✅ **Sound** (correct for all executions)
❌ **Imprecise** (doesn't say `v' = v + 1`)

#### Future: Advanced Specs (MANUAL ANNOTATIONS)
For precise specs, users write JSDoc:
```typescript
/**
 * @requires globalCounter → ?v
 * @ensures globalCounter → v+1 /\ res:unit
 */
function increment(): void {
  globalCounter = globalCounter + 1;
}
```

Or with disjunctions for complex cases:
```typescript
/**
 * @requires x→?a * y→?b
 * @ensures x→b * y→a /\ res:unit
 *   \/
 * @requires x→?a /\ y:x
 * @ensures x→a /\ res:unit
 */
function swap(): void { ... }
```

---

## 11. Key Decisions for Implementation

### ✅ DECIDED: Use Flow-Insensitive Typing
- Each global gets fixed type at allocation
- No type refinement based on values
- Matches Heifer's design

### ✅ DECIDED: No Aliasing Between Globals
- Different global names = distinct heap locations
- Simplifies spec generation
- Aliasing only relevant for parameters (future work)

### ✅ DECIDED: Simple Specs First
- Auto-generate: `req global→?v; ens global→v'` (weak but sound)
- Users can write precise specs manually via JSDoc
- JSDoc parser takes precedence over auto-generation

### ✅ DECIDED: Support Disjunctions via JSDoc
- Users can write `\/ ` in JSDoc annotations
- Parser already supports `Disjunction`
- Enables case-based specs for advanced users

---

## 12. Reference Documentation

### Type System Files
- `lib/hipcore_typed/typed_core_ast.ml` - Core AST with `RefBty` type
- `lib/hipcore_typed/globals.ml` - Type constructor definitions
- `lib/hipprover/infer_types.ml` - Type inference for ref operations

### Specification Files
- `lib/hipcore/untyped_core_ast.ml` - `staged_spec` with `Disjunction`
- `lib/parsing/parser.mly` - Parser support for `\/` operator
- `lib/hipprover/entail.ml` - Entailment checking for disjunctions

### Forward Semantics
- `lib/hipprover/forward_rules.ml` - Weakest precondition generation
- `lib/hipprover/normalize.ml` - Spec normalization rules

### Examples
- `test/demo/1_State_Monad.ml` - State handling with refs
- `test/demo/8_schduler.ml` - Heap-based branching
- `test/basic.t/test_new_entail.ml` - Disjunctive specs

---

## 13. Glossary

**Flow-insensitive typing**: Type of a variable is fixed throughout execution
**Flow-sensitive typing**: Type can vary based on program point
**Separation logic**: Logic for reasoning about heap with `*` (separating conjunction)
**Heap predicate**: Assertion about heap state (e.g., `x→5`)
**Disjunctive spec**: Specification with multiple branches (`s1 \/ s2`)
**Aliasing**: Two names referring to the same heap location
**Frame condition**: Specification of unmodified heap portions

---

## 14. Open Questions for Future Work

1. **Parameter aliasing**: Should we handle refs passed as parameters?
   - Current: No (only global variables)
   - Future: Yes (requires more sophisticated analysis)

2. **Precise value tracking**: Can we infer `v' = v + 1` for increment?
   - Current: No (too complex for Phase 3)
   - Future: Maybe (requires symbolic execution)

3. **Frame inference**: Auto-minimize heap footprint?
   - Current: Include all accessed globals
   - Future: Infer minimal frame (only modified globals)

4. **Disjunction generation**: Auto-generate branches for common patterns?
   - Current: No (users write manually)
   - Future: Maybe (pattern recognition for swap, etc.)

---

## Conclusion

Heifer provides a **rich separation logic framework** with:
- Flow-insensitive reference types
- Flow-sensitive heap reasoning
- Disjunctive specifications for case analysis
- Strong prover support for entailment

For our TypeScript translator:
- **Phase 1-2**: Enable global variable access ✅ (IMPLEMENT)
- **Phase 3**: Generate simple heap specs ✅ (IMPLEMENT)
- **Future**: Support manual precise specs via JSDoc ⏳

The foundation is solid. We can start with conservative specs and let users refine as needed.
