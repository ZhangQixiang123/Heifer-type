# Formula Architecture in Heifer-type

This document describes all formula representations in the Heifer-type project and their relationships.

## Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FORMULA REPRESENTATIONS                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LEVEL 1: Atomic/Base Formulas                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │      pi         │    │     kappa       │    │      term       │        │
│  │  (pure logic)   │    │  (heap logic)   │    │   (values)      │        │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘        │
│           │                      │                      │                  │
│           └──────────┬───────────┘                      │                  │
│                      ↓                                  │                  │
│  LEVEL 2: Combined   ┌─────────────────┐               │                  │
│                      │     state       │               │                  │
│                      │   (pi * kappa)  │ ◄── State_entail.entail_state    │
│                      └────────┬────────┘               │                  │
│                               │                        │                  │
│                               ↓                        │                  │
│  LEVEL 3: Full Specs ┌─────────────────────────────────┴─────┐            │
│                      │           staged_spec                  │            │
│                      │  (logic + effects + control flow)      │ ◄── entail │
│                      └────────────────┬──────────────────────┘            │
│                                       │                                    │
│  LEVEL 4: Definitions ┌───────────────┼───────────────┐                   │
│                       ↓               ↓               ↓                    │
│               ┌───────────┐   ┌───────────┐   ┌───────────┐               │
│               │ pred_def  │   │  lemma    │   │ meth_def  │               │
│               └───────────┘   └───────────┘   └───────────┘               │
│                                                                             │
│  LEVEL 5: Proof State ┌─────────────────────────────────────┐             │
│                       │  pstate = (pctx, spec, spec)        │             │
│                       └─────────────────────────────────────┘             │
│                                                                             │
│  AUXILIARY:           ┌─────────────────────────────────────┐             │
│                       │  uterm (for unification/rewriting)  │             │
│                       └─────────────────────────────────────┘             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Level 1: Atomic Formulas

### `pi` - Pure Logic Formulas

**Location**: `lib/hipcore/untyped_core_ast.ml:110-120` and `lib/hipcore_typed/typed_core_ast.ml:134-144`

```ocaml
and pi =
  | True                                    (* ⊤ *)
  | False                                   (* ⊥ *)
  | Atomic of bin_rel_op * term * term      (* x = y, x < y, etc. *)
  | And of pi * pi                          (* φ ∧ ψ *)
  | Or of pi * pi                           (* φ ∨ ψ *)
  | Imply of pi * pi                        (* φ → ψ *)
  | Not of pi                               (* ¬φ *)
  | Predicate of string * term list         (* P(x, y, z) *)
  | Subsumption of term * term              (* t₁ <: t₂ *)
  | Colon of string * term                  (* x : τ (type annotation) *)
```

**Purpose**: Classical first-order logic without heap
**Used for**: Pure constraints, type assertions, arithmetic relations

### `kappa` - Heap Formulas

**Location**: `lib/hipcore/untyped_core_ast.ml:122-128` and `lib/hipcore_typed/typed_core_ast.ml:147-154`

```ocaml
and kappa =
  | EmptyHeap                               (* emp *)
  | PointsTo of string * term               (* x ↦ v *)
  | RecordPointsTo of string * (string * term) list  (* x ↦ {f₁:v₁, f₂:v₂} *)
  | SepConj of kappa * kappa                (* κ₁ * κ₂ *)
```

**Purpose**: Separation logic heap assertions
**Used for**: Memory/pointer reasoning

---

## Level 2: Combined State

### `state` - Program State

**Location**: `lib/hipcore/untyped_core_ast.ml:131` and `lib/hipcore_typed/typed_core_ast.ml:157`

```ocaml
and state = pi * kappa
```

**Purpose**: Complete program state = pure facts + heap
**Used for**: Pre/post conditions in simple separation logic, `entail_type` operates at this level

---

## Level 3: Full Specification Language

### `staged_spec` - Staged Specifications

**Location**: `lib/hipcore/untyped_core_ast.ml:137-160` and `lib/hipcore_typed/typed_core_ast.ml:165-188`

```ocaml
and staged_spec =
  (* Quantifiers *)
  | Exists of binder * staged_spec          (* ∃x. φ *)
  | ForAll of binder * staged_spec          (* ∀x. φ *)

  (* Basic state assertions *)
  | Require of pi * kappa                   (* req(π, κ) - precondition *)
  | NormalReturn of pi * kappa              (* ens(π, κ) - postcondition *)

  (* Composition *)
  | Sequence of staged_spec * staged_spec   (* φ ; ψ *)
  | Disjunction of staged_spec * staged_spec (* φ ∨ ψ *)
  | Bind of binder * staged_spec * staged_spec (* let x = φ in ψ *)

  (* Higher-order / Predicates *)
  | HigherOrder of string * term list       (* f(args) or P(args) *)

  (* Control effects *)
  | Shift of bool * binder * staged_spec * binder * staged_spec
  | Reset of staged_spec

  (* Exception effects *)
  | RaisingEff of (pi * kappa * instant * term)
  | TryCatch of (pi * kappa * trycatch * term)

  (* Multi-level / Assumptions *)
  | Multi of staged_spec * staged_spec
  | Assume of staged_spec
```

**Purpose**: THE main specification language combining everything
**Used for**: Method specs, predicate bodies, entailment goals. The main `entail` function operates at this level.

---

## Level 4: Definition Types

**Location**: `lib/hipcore_common/data.ml:7-48`

### `meth_def` - Method Definition

```ocaml
type meth_def = {
  m_name: string;
  m_params: binder list;
  m_spec: staged_spec option;    (* Optional declared spec *)
  m_body: core_lang;             (* Implementation *)
  m_tactics: tactic list;
}
```

### `pred_def` - Predicate Definition

```ocaml
type pred_def = {
  p_name: string;
  p_params: binder list;
  p_body: staged_spec;           (* Definition as a spec *)
  p_rec: bool;                   (* Is it recursive? *)
}
```

### `sl_pred_def` - Separation Logic Predicate

```ocaml
type sl_pred_def = {
  p_sl_ex: binder list;          (* Existential vars *)
  p_sl_name: string;
  p_sl_params: binder list;
  p_sl_body: state;              (* Just (pi, kappa), not staged_spec *)
}
```

### `lemma` - Entailment Lemma

```ocaml
type lemma = {
  l_name: string;
  l_params: binder list;
  l_left: staged_spec;           (* LHS of entailment *)
  l_right: staged_spec;          (* RHS of entailment *)
}
```

---

## Level 5: Proof State

**Location**: `lib/hipprover/entail.ml:23-31, 152`

### `pctx` - Proof Context

```ocaml
type pctx = {
  constants : term list;
  definitions_nonrec : (string * rule) list;
  definitions_rec : (string * rule) list;
  induction_hypotheses : (string * rule) list;
  lemmas : (string * rule) list;
  unfolded : use list;
  assumptions : pi list;         (* Accumulated pure facts *)
}
```

### `pstate` - Proof State

```ocaml
type pstate = pctx * staged_spec * staged_spec
```

---

## Auxiliary Types

### `uterm` - Unification Term

**Location**: `lib/hipprover/rewriting.ml:22-28`

```ocaml
type uterm =
  | Staged of staged_spec
  | Pure of pi
  | Heap of kappa
  | Term of term
  | Binder of binder
  | Type of typ
```

**Purpose**: Unified wrapper for pattern matching/rewriting
**Used for**: Unification during lemma application

---

## Entailment Functions Comparison

### `entail` (lib/hipprover/entail.ml)

```ocaml
(* Operates on Level 3: staged_spec *)
check_staged_spec_entailment : pctx -> staged_spec -> staged_spec -> bool
```

- **Input**: Two `staged_spec` formulas
- **Scope**: Full specification language (all constructors)
- **Features**: Backtracking, Z3 integration, induction, lemmas
- **Use case**: Final verification after forward execution

### `State_entail.entail_state` (lib/hipprover/state_entail.ml) - NEW

```ocaml
(* Operates on Level 2: state *)
entail_state : ?ctx:state_entail_ctx -> state -> state -> state_entail_result
```

- **Input**: Two `state` (pi * kappa) formulas
- **Scope**: Full state-level entailment with biabduction + Z3
- **Features**:
  - Heap entailment via `Biab.solve`
  - Pure entailment via Z3 (`Provers.entails_exists`)
  - Returns structured result with frame, anti-frame, and constraints
- **Use case**: General state-level entailment, can be used by both forward execution and verification
- **Result type**:
  ```ocaml
  type state_entail_result =
    | Success of { frame: state; anti_frame: state; constraints: pi list }
    | Failure of string
  ```

### `entail_type` (lib/hipprover/forward_rules.ml) - LEGACY

```ocaml
(* Operates on Level 2: state - but limited *)
entail_type : (pi * kappa) -> staged_spec -> mapping -> (pi * kappa) * (pi * kappa)
```

- **Input**: Left is `state` (pi * kappa), Right is `staged_spec` (but only extracts req/ens which are states)
- **Scope**: Only `state` level (pi * kappa pairs)
- **Features**: Simple type/heap matching, computes residue (no Z3, no full biabduction)
- **Use case**: Forward execution, function call handling
- **Note**: Consider migrating to `State_entail.entail_state` for proper entailment

### Visual Comparison

```
                    Formula Hierarchy

Level 3: staged_spec  ◄─────────── entail (full prover)
              │
              │ extracts req/ens
              ↓
Level 2: state (pi * kappa) ◄───── State_entail.entail_state (general)
              │                     entail_type (legacy, type-focused)
              │ components
              ↓
Level 1: pi, kappa ◄─────────────── Biab.solve (heap), Provers.entails (pure)
```

---

## Typed vs Untyped Versions

| Untyped (hipcore) | Typed (hipcore_typed) | Difference |
|-------------------|----------------------|------------|
| `Exists of string * spec` | `Exists of binder * spec` | binder = (string * typ) |
| `Shift of bool * string * ...` | `Shift of bool * binder * ...` | Carries type info |
| `Bind of string * ...` | `Bind of binder * ...` | Carries type info |

The typed version adds **type annotations** to binders, enabling type checking.

---

## Summary Table

| Type | Level | Expressiveness | Where Used |
|------|-------|----------------|------------|
| **pi** | 1 (Atomic) | Pure logic only | Constraints, assertions |
| **kappa** | 1 (Atomic) | Heap only | Memory assertions |
| **state** | 2 (Combined) | pi + kappa | Simple SL predicates, `State_entail` |
| **staged_spec** | 3 (Full) | Everything | Method specs, `entail` |
| **pred_def** | 4 (Definition) | Named staged_spec | Predicate definitions |
| **sl_pred_def** | 4 (Definition) | Named state | Simple SL predicates |
| **lemma** | 4 (Definition) | spec ⊢ spec | Rewrite rules |
| **pstate** | 5 (Proof) | Context + goal | Entailment prover |
| **uterm** | Auxiliary | Any of above | Unification/rewriting |

---

## File Locations

| File | Contents |
|------|----------|
| `lib/hipcore/untyped_core_ast.ml` | Core untyped formula types (pi, kappa, staged_spec) |
| `lib/hipcore_typed/typed_core_ast.ml` | Typed versions of formulas |
| `lib/hipcore_common/data.ml` | Definition structures (pred_def, lemma, etc.) |
| `lib/hipprover/entail.ml` | Main Level 3 entailment prover (pctx, pstate) |
| `lib/hipprover/state_entail.ml` | **NEW** Level 2 state entailment (state ⊢ state) |
| `lib/hipprover/biab.ml` | Level 1 heap biabduction |
| `lib/hipprover/forward_rules.ml` | Forward execution with entail_type |
| `lib/hipprover/rewriting.ml` | Unification and rewriting (uterm) |
| `lib/hipcore/syntax.ml` | Helper functions for constructing formulas |
| `lib/hipcore/pretty.ml` | Pretty-printing functions for all formula types |
| `lib/hipprover/simple_entail.ml` | Simple spec entailment with frame rule support |

---

## Simple Separation Logic Support

The `simple_entail.ml` module provides support for simple separation logic specifications using only `requires` and `ensures` clauses without effects. This enables the **frame rule** from separation logic.

### simple_spec Type

```ocaml
type simple_spec = {
  ss_precond: state option;   (* requires clause: pi /\ kappa *)
  ss_postcond: state;         (* ensures clause: pi /\ kappa *)
  ss_ex: binder list;         (* existentially quantified variables *)
  ss_fa: binder list;         (* universally quantified variables *)
}
```

### Frame Rule Support

For Hoare logic correctness with the frame rule:

1. **Precondition check**: `declared.pre ⊢ inferred.pre` (contravariant)
   - Computes FRAME: heap resources in declared.pre not used by inferred.pre

2. **Postcondition check**: `(inferred.post * frame) ⊢ declared.post` (covariant)
   - Implements the separation logic frame rule:
     `{P} c {Q}` implies `{P * R} c {Q * R}` when R is not modified

### Normalization Pipeline

The `simple_of_staged` function converts complex staged_spec to simple_spec via:

1. **normalize_staged_spec**: Flatten Bind/Sequence structures
2. **merge_sequential_requirements**: Unify redundant Requires on same heap locations
3. **remove_vacuous_quantifiers**: Remove quantifiers for unused variables
4. **collapse_trailing_postconditions**: Combine intermediate postconditions with mutation semantics

### Current Test Status (test/reynolds_examples.t/)

#### Passing Tests
| Test | Description |
|------|-------------|
| incr | Basic increment `x := !x + 1` |
| incr_with_frame | Increment with frame `y->b` preserved |
| mutation_frame_true | Basic mutation with frame |
| alloc_frame_true | Allocation with frame |
| alloc_preserve_true | Allocation preserves existing heap |
| lookup_frame_true | Read with frame |
| triple_first_true | Update first of three refs |
| triple_middle_true | Update middle of three refs |
| swap_wrong_false | Incorrect swap spec (expected fail) |
| missing_frame_false | Missing frame in postcondition (expected fail) |

#### Failing Tests (need more work)
| Test | Issue |
|------|-------|
| swap_true | Complex nested quantifiers not extractable |
| double_incr_true | Multiple variable operations |
| copy_value_true | Cross-variable operations |
| sum_into_first_true | Multi-variable operations |

### Limitations

1. **Complex quantifier structures**: Operations involving multiple variables generate deeply nested `ForAll`/`Exists` structures that `simple_of_staged` cannot flatten.

2. **Cross-variable operations**: Operations like `swap` or copying values between variables require tracking relationships that the current merge logic doesn't handle.
