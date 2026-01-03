# Why Heifer Goes Untyped → Typed (Reverse of Traditional Compilers)

## The Surprising Design

Most programming language compilers follow this direction:

```
Source Code → Typed AST → Untyped IR → Machine Code
```

But Heifer does the **opposite**:

```
Source Code → Untyped Core AST → Typed Core AST → Verification
```

Why this reverse direction?

## Traditional Compiler Pipeline (Typed → Untyped)

### Example: OCaml Compiler

```
┌─────────────────────────────────────────────────────────┐
│ Phase 1: Parsing                                        │
│   Source → Parsetree (untyped syntax)                  │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 2: Type Checking                                  │
│   Parsetree → Typedtree (typed AST)                    │
│   - Infer types                                         │
│   - Check type consistency                              │
│   - Annotate every node with type                      │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 3: Lambda Conversion (TYPE ERASURE)               │
│   Typedtree → Lambda (untyped intermediate)            │
│   - Types are erased                                    │
│   - Simpler representation for optimization             │
│   - No type info needed for runtime                     │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 4: Code Generation                                │
│   Lambda → Assembly/Bytecode                            │
└─────────────────────────────────────────────────────────┘
```

**Why untype?**
- Types are only needed for **static checking**
- Runtime doesn't need types (type erasure)
- Simpler IR for optimization
- Smaller code representation

## Heifer's Pipeline (Untyped → Typed)

### For OCaml Source

```
┌─────────────────────────────────────────────────────────┐
│ Phase 1: OCaml Compiler (Reused!)                       │
│   Source → Typedtree                                    │
│   Uses OCaml's built-in type checker                    │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 2: Untype (Deliberate Type Erasure!)              │
│   Typedtree → Hiptypes (untyped core AST)              │
│                                                         │
│   Code: lib/heifer-parsing/core_lang_typed.ml:388      │
│   let untyped_items = Untypeast.untype_structure items │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 3: Transform to Core Language                     │
│   Untyped Parsetree → Hiptypes.core_lang               │
│   - Simpler representation                              │
│   - Language-agnostic IR                                │
│   - Multiple frontends can target this                  │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 4: Retype (Add types back!)                       │
│   Hiptypes → Typed_core_ast                            │
│   - Add type placeholders                               │
│                                                         │
│   Code: lib/hipcore_typed/retypehip.ml                 │
│   retype_staged_spec : Hiptypes → Typed_core_ast       │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 5: Type Inference (Fill in types!)                │
│   Typed_core_ast (placeholders) → Typed_core_ast (concrete) │
│   - Constraint-based type inference                     │
│   - Unification                                         │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 6: Verification                                    │
│   Typed_core_ast → Proof obligations                    │
│   - Separation logic reasoning                          │
│   - Needs type information                              │
└─────────────────────────────────────────────────────────┘
```

### For TypeScript Source

```
┌─────────────────────────────────────────────────────────┐
│ Phase 1: TypeScript Compiler                            │
│   Source → JSON AST (typed)                            │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 2: ts_to_heifer (Direct to Untyped!)              │
│   JSON AST → Hiptypes (untyped core AST)               │
│   - Ignores TypeScript's type information               │
│   - Builds untyped IR directly                          │
│                                                         │
│   Code: ts_to_heifer/lib/translator.ml                 │
│   translate_program : json → Hiptypes.core_lang        │
└─────────────────────────────────────────────────────────┘
                            ↓
         (Same Phase 4-6 as OCaml path above)
```

## Why This Design? The Key Insights

### 1. **Multiple Frontends Need a Common IR**

Heifer wants to verify multiple languages:
- OCaml (with OCaml compiler's type system)
- TypeScript (with TypeScript's type system)
- Potentially: JavaScript, Python, etc.

**Problem**: Each language has its own type system with different features:
- OCaml: algebraic data types, GADTs, modules
- TypeScript: structural types, union types, `any`

**Solution**: Use an **untyped common IR** (Hiptypes) that all frontends can target.

```
OCaml Frontend     → \
TypeScript Frontend → → Hiptypes (untyped, language-agnostic)
JavaScript Frontend → /
```

### 2. **Separation Logic Specifications Are Untyped**

Heap predicates describe **runtime heap**, not static types:

```ocaml
(* This is untyped - it's about heap locations *)
counter->v_counter

(* Not about what type 'counter' has,
   but about what value the heap cell contains *)
```

**From the code** ([retypehip.ml:1-4](lib/hipcore_typed/retypehip.ml#L1-L4)):
```ocaml
(** Module for transforming a Hiptypes AST element into a Typedhip element.
    All types are filled in with placeholders, to be populated during typechecking.
    Since there are utilities that take the Typedtree as input, most program types
    should be coming from the OCaml typechecker; this is used to typecheck annotations. *)
```

Key point: **"most program types should be coming from the OCaml typechecker"**

The untyped layer receives types from:
- **OCaml programs**: OCaml compiler's type checker
- **TypeScript programs**: TypeScript compiler's type checker
- **Manual annotations**: User-written separation logic specs

Then Heifer **re-types** everything with its own type system for verification.

### 3. **Type Systems Are Different From Verification**

**Type checking** (traditional compilers):
- "Does this expression have a valid type?"
- "Are function calls type-correct?"
- Happens **once** during compilation

**Verification** (Heifer):
- "Does this program satisfy its specification?"
- "Are the heap predicates preserved?"
- Happens **after** type checking
- Needs types, but for a **different purpose**

Heifer needs types for verification, not for compilation. So it:
1. **Accepts** typed input from various compilers
2. **Erases** types to get language-agnostic IR
3. **Re-adds** types for its own verification purposes

### 4. **Flexibility in Type Inference**

By going through an untyped layer, Heifer can:
- Use **constraint-based type inference** on the IR
- Support types that don't exist in source languages
- Add type variables for separation logic reasoning

Example from [retypehip.ml:9](lib/hipcore_typed/retypehip.ml#L9):
```ocaml
let binder_of_ident ?(typ=Types.new_type_var ()) (ident : string) : binder =
  (ident, typ)
```

Fresh type variables are created during retyping, then solved by constraint inference.

### 5. **Specification Parsing Is Easier on Untyped AST**

User-written specs in JSDoc/comments:
```typescript
/**
 * @req counter->v_counter
 * @ens counter->v_counter' /\ res:()
 */
```

These are parsed into **untyped Hiptypes** because:
- Specs reference program variables (may not be typed yet)
- Specs use logic variables (`v_counter`) that don't exist in source
- Easier to parse into simple constructors

From [translator.ml:852-857](ts_to_heifer/lib/translator.ml#L852-L857):
```ocaml
let untyped_spec =
  try
    parse_to_hiptype json
  with e ->
    Printf.eprintf "Warning: Failed to parse JSDoc spec\n";
    generate_spec_from_signature outer_ctx typed_params ret_type body_statements
in
```

Specs are parsed as **untyped Hiptypes**, then converted to typed.

## Comparison Table

| Aspect | Traditional Compiler | Heifer Verifier |
|--------|---------------------|-----------------|
| **Goal** | Generate machine code | Verify correctness |
| **Type Purpose** | Static checking only | Verification reasoning |
| **Direction** | Typed → Untyped | Untyped → Typed |
| **Why Untype?** | Runtime doesn't need types | Common IR for multiple frontends |
| **Why Retype?** | N/A (types discarded) | Verification needs types |
| **Multiple Frontends?** | No (single source language) | Yes (OCaml, TS, etc.) |
| **Type Erasure** | Permanent (for performance) | Temporary (for flexibility) |

## Concrete Example: OCaml Pipeline

### Step 1: OCaml Compiler Types the Code

```ocaml
(* Source *)
let counter = ref 0

(* After OCaml type checker: Typedtree *)
{ str_desc = Tstr_value (
    vb_pat = { pat_desc = Tpat_var "counter";
               pat_type = ref int };  (* TYPE INFO *)
    vb_expr = { exp_desc = Texp_apply (ref, [0]);
                exp_type = ref int }  (* TYPE INFO *)
  )
}
```

### Step 2: Heifer Untypes It

From [hiplib.ml:388](lib/hiplib/hiplib.ml#L388):
```ocaml
let untyped_items = Untypeast.untype_structure items in
```

Result:
```ocaml
(* Parsetree - untyped *)
{ pstr_desc = Pstr_value (
    pvb_pat = { ppat_desc = Ppat_var "counter" };  (* NO TYPE *)
    pvb_expr = { pexp_desc = Pexp_apply (ref, [0]) }  (* NO TYPE *)
  )
}
```

### Step 3: Transform to Hiptypes

From [core_lang_typed.ml:537-565](lib/heifer-parsing/core_lang_typed.ml#L537-L565):
```ocaml
let transform_str (bound_names : binder list) (s : structure_item) =
  (* Takes Typedtree.structure_item *)
  (* Returns Hiptypes.intermediate (untyped) *)

  (* But extracts type info from Typedtree! *)
  let formals, body, ((param_types, return_type) as types) =
    collect_param_info fn in  (* Gets types from Typedtree *)
```

Result:
```ocaml
(* Hiptypes.core_lang - untyped constructors *)
CLet ("counter", CRef (Const (Num 0)), ...)
```

**Key observation**: Even though the output is **untyped**, type information is extracted from the **typed tree** and stored separately!

### Step 4: Retype for Verification

From [retypehip.ml:11-32](lib/hipcore_typed/retypehip.ml#L11-L32):
```ocaml
let rec retype_term (term : Hiptypes.term) =
  let term_desc = match term with
  | Hiptypes.Var v -> Var v
  | Hiptypes.Const (Num n) -> Const (Num n)
  (* ... *)
  in
  { term_desc; term_type = Types.new_type_var () }  (* Fresh type var *)
```

Result:
```ocaml
(* Typed_core_ast.core_lang - typed *)
{ core_desc = CLet (
    ("counter", TVar 42),  (* Type placeholder *)
    { core_desc = CRef { term_desc = Const (Num 0);
                         term_type = TVar 43 };
      core_type = TVar 44 },
    ...
  );
  core_type = TVar 45
}
```

### Step 5: Type Inference Resolves Placeholders

From [infer_types.ml](lib/hipprover/infer_types.ml):
```ocaml
(* Constraints *)
TVar 43 ~ int           (* 0 is int *)
TVar 44 ~ ref(TVar 43)  (* ref takes int *)
TVar 42 ~ ref(int)      (* counter's type *)

(* After solving *)
TVar 42 := ref(int)
TVar 43 := int
TVar 44 := ref(int)
```

## Why Not Keep Types From Source?

You might ask: "Why erase OCaml's types if you're just going to infer them again?"

**Answer**: Because Heifer's type system is **different** from OCaml's:

1. **Heifer has separation logic types**:
   - Heap predicates: `counter->v`
   - Not in OCaml's type system

2. **Heifer needs constraint-based inference**:
   - For logic variables in specs
   - OCaml types don't have these

3. **TypeScript and OCaml have incompatible type systems**:
   - Common untyped IR makes both work
   - Re-inference with Heifer's type system unifies them

4. **Verification needs more than compilation types**:
   - Must track heap effects
   - Must reason about specifications
   - Must handle refinement types

## The Real Reason: Two-Phase Design

Heifer actually has **two separate type systems**:

```
┌─────────────────────────────────────────────────────────┐
│         Source Language Type System                     │
│    (OCaml types OR TypeScript types)                    │
│                                                         │
│  Used for: Program correctness in source language       │
│  Result: Typedtree or JSON AST                         │
└─────────────────────────────────────────────────────────┘
                            ↓
                   (Type Erasure)
                            ↓
┌─────────────────────────────────────────────────────────┐
│          Hiptypes (Untyped Common IR)                   │
│                                                         │
│  No types, just structure                               │
│  Language-agnostic                                      │
└─────────────────────────────────────────────────────────┘
                            ↓
                   (Retyping)
                            ↓
┌─────────────────────────────────────────────────────────┐
│         Heifer Type System                              │
│    (Separation logic + refinements)                     │
│                                                         │
│  Used for: Verification and separation logic            │
│  Result: Typed_core_ast with verification types         │
└─────────────────────────────────────────────────────────┘
```

The untyped layer is the **translation boundary** between:
- **Source language semantics** (what the program means)
- **Verification semantics** (what the program proves)

## Summary

**Traditional Compiler**: Typed → Untyped
- Types only needed for static checking
- Runtime doesn't use types
- Type erasure is permanent

**Heifer Verifier**: Untyped → Typed
- Multiple typed frontends (OCaml, TypeScript)
- Untyped common IR for language independence
- Retyping with verification-specific type system
- Type erasure is temporary (translation boundary)

The key insight: **Heifer doesn't erase types to discard them, it erases types to translate between type systems.**

## Architectural Benefits

1. **Modularity**: Frontends and verification are independent
2. **Extensibility**: Easy to add new source languages
3. **Simplicity**: Hiptypes is small and simple
4. **Flexibility**: Verification type system can evolve independently
5. **Reuse**: Can leverage existing compilers' type checkers

This design is actually quite elegant - it separates concerns between **source language typing** and **verification typing**, using an untyped IR as the clean interface between them.
