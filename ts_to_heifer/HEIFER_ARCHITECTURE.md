# Heifer Type System Architecture

## Overview

Heifer is a separation logic verification system for OCaml-like languages. The architecture is layered, with each layer serving a specific purpose in the type checking and verification pipeline.

## Architectural Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    User Level                               │
│  - TypeScript Source Code (ts_to_heifer)                    │
│  - OCaml Source Code (native frontend)                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Layer 1: Untyped Core AST                      │
│                                                             │
│  Module: lib/hipcore/untyped_core_ast.ml                   │
│  Package: hipcore (heifer.hipcore)                         │
│                                                             │
│  Purpose: Language-agnostic untyped representation          │
│                                                             │
│  Key Types:                                                 │
│  - term          : Pure logic terms                         │
│  - core_lang     : Imperative core language                 │
│  - pi            : Pure assertions (propositions)           │
│  - kappa         : Heap assertions (separation logic)       │
│  - staged_spec   : Specifications (pi, kappa) pairs         │
│                                                             │
│  Key Constructors:                                          │
│  - CValue, CLet, CSequence, CIfELse                        │
│  - CRef, CRead, CWrite (reference operations)              │
│  - EmptyHeap, PointsTo, SepConj (heap predicates)          │
│                                                             │
│  Dependencies: None (base layer)                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│           Layer 2: Hiptypes (Untyped + Data)                │
│                                                             │
│  Module: lib/hipcore/hiptypes.ml                           │
│  Package: hipcore                                          │
│                                                             │
│  Purpose: Extends untyped AST with program-level constructs │
│                                                             │
│  Adds:                                                      │
│  - include Untyped_core_ast                                │
│  - include Hipcore_common.Data.Make(Untyped_core_ast)      │
│  - meth_def      : Method definitions                      │
│  - pred_def      : Predicate definitions                   │
│  - lemma         : Verification lemmas                     │
│  - intermediate  : Top-level declarations                  │
│                                                             │
│  This is the PRIMARY TARGET for translators                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Layer 3: Typed Core AST                        │
│                                                             │
│  Module: lib/hipcore_typed/typed_core_ast.ml               │
│  Package: hipcore_typed (heifer.hipcore_typed)             │
│                                                             │
│  Purpose: Add explicit type annotations to AST              │
│                                                             │
│  Key Differences from Untyped:                              │
│  - term becomes:                                            │
│    { term_desc: term_desc;                                 │
│      term_type: typ }                                      │
│  - binder = string * typ (was just string)                 │
│  - core_lang becomes:                                       │
│    { core_desc: core_desc;                                 │
│      core_type: typ }                                      │
│                                                             │
│  Conversion Functions:                                      │
│  - retypehip.ml : Hiptypes → Typed_core_ast                │
│  - untypehip.ml : Typed_core_ast → Hiptypes                │
│                                                             │
│  Purpose: Enables type checking and inference               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Layer 4: Type Inference                        │
│                                                             │
│  Module: lib/hipprover/infer_types.ml                      │
│  Package: hipprover                                        │
│                                                             │
│  Purpose: Type checking and inference                       │
│                                                             │
│  Functions:                                                 │
│  - infer_types_term : term → typed term                    │
│  - infer_types_core : core_lang → typed core_lang          │
│  - unify : typ → typ → constraint solving                  │
│                                                             │
│  Uses: Type environment (TEnv) with unification             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│               Layer 5: Verification                         │
│                                                             │
│  Modules:                                                   │
│  - lib/hipprover/entail.ml       (entailment checking)     │
│  - lib/hipprover/forward_rules.ml (forward reasoning)      │
│  - lib/hipprover/normalize.ml    (normalization)           │
│                                                             │
│  Purpose: Verify separation logic specifications            │
│                                                             │
│  Uses external provers:                                     │
│  - Z3 (SMT solving)                                        │
│  - Why3 (theorem proving)                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 Output Layer                                │
│                                                             │
│  Module: lib/hipcore_typed/Pretty.ml                       │
│  Purpose: Pretty printing typed AST                         │
│                                                             │
│  Functions:                                                 │
│  - string_of_core_lang : core_lang → string                │
│  - string_of_staged_spec : staged_spec → string            │
│  - string_of_type : typ → string                           │
│                                                             │
│  Output Format: OCaml-like syntax with annotations          │
│  Example: let f x (*@ req x:int; ens res:int @*) = x+1     │
└─────────────────────────────────────────────────────────────┘
```

## TypeScript to Heifer Translator Position

```
┌────────────────────────────────────────────────────────────┐
│                  ts_to_heifer/lib/translator.ml            │
│                                                            │
│  Input: TypeScript AST (JSON from TS compiler)             │
│  Output: Hiptypes (Layer 2 - Untyped Core AST)            │
│                                                            │
│  Module Imports:                                           │
│  - open Hipcore_typed.Typed_core_ast                      │
│  - open Hipcore_common.Types                              │
│  - open Hipcore (Hiptypes)                                │
│  - open Parsing                                           │
│  - open Hipcore_typed.Retypehip                           │
│                                                            │
│  Key Translation Functions:                                │
│  ┌──────────────────────────────────────────────────┐     │
│  │ translate_program : json → core_lang             │     │
│  │   Builds untyped Hiptypes.core_lang directly     │     │
│  │   Uses: CValue, CLet, CRef, CRead, CWrite        │     │
│  └──────────────────────────────────────────────────┘     │
│                           ↓                                │
│  ┌──────────────────────────────────────────────────┐     │
│  │ generate_spec_from_signature :                   │     │
│  │   ctx → params → ret → stmts → staged_spec       │     │
│  │   Builds untyped Hiptypes.staged_spec            │     │
│  │   Uses: Require, NormalReturn, PointsTo          │     │
│  └──────────────────────────────────────────────────┘     │
│                           ↓                                │
│  ┌──────────────────────────────────────────────────┐     │
│  │ retype_staged_spec : Hiptypes → Typed_core_ast   │     │
│  │   Converts to typed AST with type placeholders   │     │
│  │   (from Hipcore_typed.Retypehip)                 │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
│  Output Forms:                                             │
│  1. translate_program → Hiptypes.core_lang (untyped)      │
│     Pretty printed via Typed_core_ast.Pretty              │
│                                                            │
│  2. translate_program_to_intermediates                     │
│     → list of `Meth (typed) for verification pipeline     │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

## Layer Interface Details

### Layer 1 → Layer 2 (Untyped Core → Hiptypes)

**Inclusion**: Hiptypes directly includes all Untyped_core_ast types.

```ocaml
(* lib/hipcore/hiptypes.ml *)
include Untyped_core_ast
include Hipcore_common.Data.Make(Untyped_core_ast)
```

**What Data.Make adds:**
- `meth_def` - Method with spec and body
- `pred_def` - Predicate definitions
- `intermediate` - Top-level declarations (`Meth | Pred | Typedef | ...`)

### Layer 2 → Layer 3 (Hiptypes → Typed_core_ast)

**Conversion**: `retypehip.ml` transforms untyped to typed.

```ocaml
(* lib/hipcore_typed/retypehip.ml *)
val retype_term : Hiptypes.term → Typed_core_ast.term
val retype_pi : Hiptypes.pi → Typed_core_ast.pi
val retype_kappa : Hiptypes.kappa → Typed_core_ast.kappa
val retype_staged_spec : Hiptypes.staged_spec → Typed_core_ast.staged_spec
val retype_core_lang : Hiptypes.core_lang → Typed_core_ast.core_lang
```

**Key transformation:**
```ocaml
(* Untyped *)
type term = Var of string | Const of const | ...

(* Typed *)
type term = { term_desc: term_desc; term_type: typ }
and term_desc = Var of string | Const of const | ...
```

### Layer 3 → Layer 4 (Typed AST → Type Inference)

**Type inference**: `infer_types.ml` fills in type placeholders.

```ocaml
(* Type variables created by retype_* are placeholders *)
{ term_desc = Var "x";
  term_type = TVar 42 }  (* placeholder *)

(* After type inference *)
{ term_desc = Var "x";
  term_type = TConstr ("int", []) }  (* concrete type *)
```

## Translator's Layer Usage

The `ts_to_heifer` translator operates at **Layer 2 (Hiptypes)** but uses types from **Layer 3 (Typed_core_ast)**:

### Why this hybrid approach?

1. **Construction at Layer 2 (Untyped)**
   - Builds `Hiptypes.core_lang` directly
   - Simpler constructors (no type annotations needed)
   - Example: `CLet (name, init, body)` vs `CLet ((name, typ), init, body)`

2. **Type annotations from Layer 3**
   - Uses `Typed_core_ast.typ` for internal bookkeeping
   - Tracks types in `context.type_env: (string, typ) Hashtbl.t`
   - Enables type-aware translation decisions

3. **Conversion via retypehip**
   - After building untyped spec: `generate_spec_from_signature → Hiptypes.staged_spec`
   - Convert to typed: `retype_staged_spec untyped_spec → Typed_core_ast.staged_spec`
   - Type placeholders filled later by `infer_types`

### Data Flow in Translator

```
TypeScript AST (JSON)
       ↓
[translate_expr/stmt/decl]
       ↓
Hiptypes.core_lang (untyped, but with typ annotations in context)
       ↓
[generate_spec_from_signature]
       ↓
Hiptypes.staged_spec (untyped)
       ↓
[retype_staged_spec]
       ↓
Typed_core_ast.staged_spec (typed with placeholders)
       ↓
[Pretty.string_of_*]
       ↓
Output: OCaml-like syntax with separation logic annotations
```

## Key Insights

1. **Hiptypes is the translator target**: All external translators (TypeScript, OCaml) produce Hiptypes (Layer 2).

2. **Typed layer is internal**: Layer 3 (Typed_core_ast) is for Heifer's internal type checking, not direct construction.

3. **Separation of concerns**:
   - **Layer 2**: What the program does (structure)
   - **Layer 3**: What types the program has (annotations)
   - **Layer 4**: Are the types consistent? (inference)
   - **Layer 5**: Does it satisfy specs? (verification)

4. **Type system is constraint-based**: Type variables are constraints, solved by unification in `infer_types`.

5. **Separation logic at Layer 2**: Heap predicates (`PointsTo`, `SepConj`, `EmptyHeap`) are in untyped layer because they describe runtime heap, not static types.

## Common Operations by Layer

### Layer 2 (Hiptypes) - What translators build

```ocaml
(* Building core language *)
let counter_ref = CRef (Const (Num 0))
let read_counter = CRead "counter"
let write_counter = CWrite ("counter", Const (Num 1))
let sequence = CSequence (expr1, expr2)

(* Building specifications *)
let require = Require (pi, kappa)
let ensure = NormalReturn (pi', kappa')
let spec = Sequence (require, ensure)

(* Building heap predicates *)
let heap_empty = EmptyHeap
let points_to = PointsTo ("x", Var "v")
let sep_conj = SepConj (points_to1, points_to2)
```

### Layer 3 (Typed) - What type checker works with

```ocaml
(* Terms have explicit types *)
let typed_term = {
  term_desc = Var "x";
  term_type = TConstr ("int", [])
}

(* Core language has explicit types *)
let typed_core = {
  core_desc = CValue typed_term;
  core_type = TConstr ("int", [])
}

(* Binders carry types *)
let binder = ("x", TConstr ("int", []))
```

## Module Dependencies

```
hipcore_common (base utilities)
    ↓
hipcore (untyped AST + Hiptypes)
    ↓
hipcore_typed (typed AST + conversions)
    ↓
hipprover (type inference + verification)
    ↓
provers (Z3, Why3 backends)
```

**Translator dependencies:**
```
ts_to_heifer
    ├→ Hipcore (Hiptypes) - primary target
    ├→ Hipcore_typed.Typed_core_ast - type system
    ├→ Hipcore_typed.Retypehip - untyped→typed conversion
    ├→ Hipcore_common.Types - type utilities
    └→ Parsing - JSDoc spec parsing
```

## Summary

The Heifer architecture is a **multi-layered type system** where:

1. **Layer 1-2 (Untyped)**: Structure and semantics - THIS IS WHERE TRANSLATORS WORK
2. **Layer 3 (Typed)**: Type annotations - for internal type checking
3. **Layer 4 (Inference)**: Type constraint solving
4. **Layer 5 (Verification)**: Separation logic verification

The `ts_to_heifer` translator **produces Layer 2 (Hiptypes)** but **uses Layer 3 types** for internal bookkeeping, then converts to typed AST via `retypehip` for the verification pipeline.
