# Architecture Correction: Translator Actually Targets Typed Layer!

## The Error in Previous Documentation

I previously stated that `ts_to_heifer` targets **Layer 2 (Hiptypes - untyped)**. This was **WRONG**!

The translator actually targets **Layer 3 (Typed_core_ast - typed)** directly.

## Evidence

### 1. Module Imports

From [translator.ml:8](ts_to_heifer/lib/translator.ml#L8):
```ocaml
open Hipcore_typed.Typed_core_ast
```

The translator opens the **Typed_core_ast** module, not Hiptypes!

### 2. Constructor Usage

From [translator.ml:329-330](ts_to_heifer/lib/translator.ml#L329-L330):
```ocaml
{ term_desc = Const (Num value);
  term_type = Int }
```

This is **Typed_core_ast.term**, which is a record with `term_type` field!

Compare with untyped version (Hiptypes.term):
```ocaml
Const (Num value)  (* Just the constructor, no record wrapper *)
```

### 3. Core Language Construction

From [translator.ml:570-577](ts_to_heifer/lib/translator.ml#L570-L577):
```ocaml
{ core_desc = CLet ((tmp, typ),          (* binder = string * typ *)
                    { core_desc = CRead name;
                      core_type = typ },  (* core_type field! *)
                    ...);
  core_type = typ }                      (* core_type field! *)
```

This is **Typed_core_ast.core_lang**:
- Binders are `(string, typ)` tuples (typed!)
- Core_lang nodes have `core_type` fields

### 4. Return Type in main.ml

From [main.ml:60](ts_to_heifer/bin/main.ml#L60):
```ocaml
Printf.printf "Type: %s\n" (string_of_type heifer_ir.core_type);
```

Accessing `.core_type` field proves it's a typed record!

## Corrected Architecture

### What I Said Before (WRONG)

```
TypeScript JSON
    ↓ translate_program
Hiptypes.core_lang (UNTYPED) ❌
    ↓ retype_staged_spec
Typed_core_ast (typed)
```

### What Actually Happens (CORRECT)

```
TypeScript JSON
    ↓ translate_program
Typed_core_ast.core_lang (TYPED) ✅
    ↓ (no conversion needed!)
Pretty printing / Verification
```

## Why I Was Confused

Looking at `generate_spec_from_signature`:

From [translator.ml:273-323](ts_to_heifer/lib/translator.ml#L273-L323):
```ocaml
let generate_spec_from_signature outer_ctx typed_params ret_type body_statements =
  (* ... builds spec ... *)
  Hiptypes.Sequence (           (* ← Looks untyped! *)
    Hiptypes.Require (require_pi, require_kappa),
    Hiptypes.NormalReturn (ensure_pi, ensure_kappa)
  )
```

This **appears** to return `Hiptypes.staged_spec` (untyped).

But then at [translator.ml:857](ts_to_heifer/lib/translator.ml#L857):
```ocaml
let untyped_spec = generate_spec_from_signature outer_ctx ... in
```

It's stored in a variable called `untyped_spec`!

And immediately after [translator.ml:861](ts_to_heifer/lib/translator.ml#L861):
```ocaml
let spec = retype_staged_spec untyped_spec in
```

It's converted to typed via `retype_staged_spec`.

**So**: The **specifications** go through untyped→typed, but the **core language** is typed from the start!

## The Actual Layer Usage

The translator uses a **mixed approach**:

### Core Language (CLet, CRef, etc.): TYPED

```ocaml
(* Builds Typed_core_ast.core_lang directly *)
{ core_desc = CLet ((name, typ), init, body);
  core_type = typ }
```

### Specifications (req/ens): UNTYPED → TYPED

```ocaml
(* Step 1: Build Hiptypes.staged_spec (untyped) *)
let untyped_spec =
  Hiptypes.Sequence (
    Hiptypes.Require (pi, kappa),
    Hiptypes.NormalReturn (pi', kappa')
  )

(* Step 2: Convert to Typed_core_ast.staged_spec *)
let typed_spec = retype_staged_spec untyped_spec
```

## Why This Hybrid Approach?

### For Core Language: Build Typed Directly

**Reason**: We know the types from TypeScript!

```typescript
let counter: number = 0;  // Type is explicit
```

```ocaml
(* We can build typed directly *)
{ core_desc = CLet (("counter", TConstr ("ref", [TConstr ("int", [])])), ...);
  core_type = TConstr ("unit", []) }
```

### For Specifications: Build Untyped First

**Reason**: Specs reference logic variables that don't exist yet!

```ocaml
(* Spec references v_counter and v_counter' *)
PointsTo ("counter", Var "v_counter")

(* But v_counter doesn't exist in the program! *)
(* It's a logic variable for the specification *)
(* We don't know its type yet *)
```

So we build untyped:
```ocaml
Hiptypes.PointsTo ("counter", Hiptypes.Var "v_counter")
```

Then retype with fresh type variables:
```ocaml
{ term_desc = PointsTo ("counter", {
    term_desc = Var "v_counter";
    term_type = TVar 42  (* Fresh type variable *)
  });
  term_type = ... }
```

## Updated Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│              TypeScript Source                          │
│         let counter: number = 0;                        │
│         function increment() { counter++; }             │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│           TypeScript Compiler → JSON AST                │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│         ts_to_heifer/lib/translator.ml                  │
│                                                         │
│  Core Language Translation:                             │
│  ┌───────────────────────────────────────────────┐     │
│  │ translate_expr/stmt                           │     │
│  │   → Typed_core_ast.core_lang                  │     │
│  │                                                │     │
│  │ { core_desc = CLet ((name, typ), ...);        │     │
│  │   core_type = typ }                           │     │
│  └───────────────────────────────────────────────┘     │
│                                                         │
│  Specification Generation:                              │
│  ┌───────────────────────────────────────────────┐     │
│  │ generate_spec_from_signature                  │     │
│  │   → Hiptypes.staged_spec (untyped)            │     │
│  │   → retype_staged_spec                        │     │
│  │   → Typed_core_ast.staged_spec (typed)        │     │
│  └───────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│            Typed_core_ast.core_lang                     │
│         with Typed_core_ast.staged_spec                 │
│                                                         │
│  { core_desc = CLet (("counter", ref(int)), ...);      │
│    core_type = unit }                                  │
│                                                         │
│  with spec:                                             │
│  Sequence (                                             │
│    Require (pi, PointsTo ("counter", {...})),          │
│    NormalReturn (pi', PointsTo ("counter", {...}))     │
│  )                                                      │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│         Hipprover.Infer_types (Layer 4)                 │
│  Type inference fills in any remaining type variables   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│         Verification (Layer 5)                          │
└─────────────────────────────────────────────────────────┘
```

## Comparison with OCaml Frontend

### OCaml Frontend Pipeline

```
OCaml Source
    ↓
OCaml Compiler → Typedtree (OCaml's typed AST)
    ↓
Untypeast.untype_structure → Parsetree (untyped)
    ↓
transform_str → Hiptypes.core_lang (untyped!)
    ↓
retype_* → Typed_core_ast.core_lang (typed)
```

OCaml frontend **does** go through untyped layer!

### TypeScript Frontend Pipeline

```
TypeScript Source
    ↓
TS Compiler → JSON AST
    ↓
translate_program → Typed_core_ast.core_lang (typed!)
    ↓
(Already typed, no conversion needed)
```

TypeScript frontend **skips** the untyped layer!

## Why the Difference?

### OCaml Frontend: Uses OCaml Compiler

The OCaml compiler provides a **rich Typedtree** with:
- Full type information from OCaml's type checker
- Module types, GADTs, polymorphic variants
- Very detailed type annotations

So they:
1. **Untype** to get simpler representation
2. **Transform** to core language (simpler than full OCaml)
3. **Retype** with Heifer's type system

### TypeScript Frontend: Direct Translation

We don't use TypeScript's type checker internals. We just:
1. Parse TypeScript types from annotations
2. Translate directly to Heifer types
3. Build typed AST immediately

**Benefit**: Simpler, no need for two-phase translation.

**Tradeoff**: We lose some TypeScript type information (structural types, union types, etc.)

## Corrected Layer Diagram

```
                     ┌─────────────────────┐
                     │  TypeScript Source  │
                     └─────────────────────┘
                              ↓
                     ┌─────────────────────┐
                     │    TS Compiler      │
                     │    (JSON AST)       │
                     └─────────────────────┘
                              ↓
                              │
                   ts_to_heifer (direct build)
                              │
                              ↓
         ┌────────────────────────────────────────┐
         │    Layer 3: Typed_core_ast             │
         │                                        │
         │  • term = { term_desc; term_type }     │
         │  • core_lang = { core_desc; core_type }│
         │  • binder = string * typ               │
         │                                        │
         │  Translator builds this directly!      │
         └────────────────────────────────────────┘
                              ↓
         ┌────────────────────────────────────────┐
         │    Layer 4: Type Inference             │
         │  (Fills in any remaining type vars)    │
         └────────────────────────────────────────┘
                              ↓
         ┌────────────────────────────────────────┐
         │    Layer 5: Verification               │
         └────────────────────────────────────────┘
```

**Key correction**: The translator skips Layer 2 entirely!

## Why Layer 2 (Hiptypes) Exists

If TypeScript translator skips it, what's Layer 2 for?

**Answer**: For the OCaml frontend!

Layer 2 is the **common untyped IR** for frontends that:
1. Start with complex typed ASTs (OCaml's Typedtree)
2. Need to simplify before retyping
3. Want language-agnostic intermediate representation

TypeScript is simpler, so we go **directly to Layer 3**.

## Summary: The Truth

| Component | Target Layer | Why |
|-----------|-------------|-----|
| **OCaml frontend** | Layer 2 (Hiptypes) | Simplifies OCaml's complex types |
| **TypeScript translator** | Layer 3 (Typed_core_ast) | Simple enough to build typed directly |
| **Specifications** | Layer 2 → Layer 3 | Logic variables need type inference |

The TypeScript translator is actually **more direct** than the OCaml frontend - it builds typed AST immediately, only using the untyped layer for specifications.

## Why My Documentation Was Wrong

I looked at:
1. `generate_spec_from_signature` returns `Hiptypes.staged_spec`
2. Module imports `Hipcore` (which includes Hiptypes)
3. Comment in retypehip.ml about untyped→typed

But I **didn't look carefully** at what constructors were actually being used!

The constructor usage clearly shows:
- `{ term_desc = ...; term_type = ... }` (typed term)
- `{ core_desc = ...; core_type = ... }` (typed core_lang)
- `(name, typ)` tuples for binders (typed binders)

**All typed constructors!**

Thank you for catching this critical error!
