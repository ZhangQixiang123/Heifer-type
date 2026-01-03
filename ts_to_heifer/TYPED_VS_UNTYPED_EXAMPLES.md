# Typed vs Untyped: Concrete Examples from the Translator

This document shows **actual code from the translator** demonstrating when it generates typed vs untyped constructs.

## Summary: The Hybrid Approach

The translator uses:
- **Typed constructors** (Typed_core_ast) for program code
- **Untyped constructors** (Hiptypes) for specifications

## Example 1: Simple Constants (TYPED)

### Source Code Location
[translator.ml:325-345](lib/translator.ml#L325-L345)

### TypeScript Input
```typescript
42
```

### Translator Code
```ocaml
let translate_const json =
  match get_kind json with
  | "NumericLiteral" | "FirstLiteralToken" ->
      let value = json |> member "value" |> to_number |> int_of_float in
      { term_desc = Const (Num value);    (* ← Constructor *)
        term_type = Int }                  (* ← Type annotation! *)
```

### What's Generated
```ocaml
(* Typed_core_ast.term - a RECORD *)
{ term_desc = Const (Num 42);
  term_type = Int }
```

### Type Structure
```ocaml
(* From typed_core_ast.ml *)
type term = {
  term_desc: term_desc;    (* The actual expression *)
  term_type: typ           (* TYPE FIELD - makes it typed! *)
}
```

### Key Observation
Every term is a **record with a type field**. This is Typed_core_ast, not Hiptypes!

---

## Example 2: String Constants (TYPED)

### Source Code Location
[translator.ml:332-335](lib/translator.ml#L332-L335)

### TypeScript Input
```typescript
"hello"
```

### Translator Code
```ocaml
| "StringLiteral" ->
    let value = json |> member "value" |> to_string in
    { term_desc = Const (TStr value);
      term_type = TyString }              (* ← Type field! *)
```

### What's Generated
```ocaml
{ term_desc = Const (TStr "hello");
  term_type = TyString }
```

---

## Example 3: Variables (TYPED)

### Source Code Location
[translator.ml:357-372](lib/translator.ml#L357-L372)

### TypeScript Input
```typescript
counter  // where counter: number
```

### Translator Code
```ocaml
| "Identifier" ->
    let name = get_identifier json in
    let variance = get_variance ctx name in
    (match variance with
     | Immutable ->
         { term_desc = Var name;
           term_type = get_type ctx name }    (* ← Type from context! *)
     | Mutable ->
         { term_desc = Var name;
           term_type = get_type ctx name })
```

### What's Generated
```ocaml
{ term_desc = Var "counter";
  term_type = Int }    (* Type looked up from context *)
```

### Key Insight
The translator tracks types in `context.type_env` and uses them to build typed terms!

---

## Example 4: Binary Operations (TYPED)

### Source Code Location
[translator.ml:374-385](lib/translator.ml#L374-L385)

### TypeScript Input
```typescript
x + y
```

### Translator Code
```ocaml
| "BinaryExpression" ->
    let op = get_binop_operator json in
    let l = translate_term ctx (json |> member "left") in
    let r = translate_term ctx (json |> member "right") in
    let result_type = (* ... compute result type ... *) in
    { term_desc = BinOp (op, l, r);
      term_type = result_type }
```

### What's Generated
```ocaml
{ term_desc = BinOp (Plus,
                     { term_desc = Var "x"; term_type = Int },
                     { term_desc = Var "y"; term_type = Int });
  term_type = Int }
```

### Nested Structure
Notice how **every sub-term** also has a type field:
- `l` is typed: `{ term_desc = Var "x"; term_type = Int }`
- `r` is typed: `{ term_desc = Var "y"; term_type = Int }`
- Result is typed: `term_type = Int`

---

## Example 5: Increment Statement (TYPED core_lang)

### Source Code Location
[translator.ml:512-521](lib/translator.ml#L512-L521)

### TypeScript Input
```typescript
counter++
```

### Translator Code
```ocaml
let name = get_identifier operand in
let variance = get_variance ctx name in
assert (variance = Mutable);
let typ = get_type ctx name in
let new_val = { term_desc = BinOp (Plus,
                                    { term_desc = Var name; term_type = typ },
                                    { term_desc = Const (Num 1); term_type = Int });
                term_type = typ } in
{ core_desc = CSequence (
    { core_desc = CWrite (name, new_val); core_type = Unit },  (* ← core_type! *)
    { core_desc = CRead name; core_type = typ });              (* ← core_type! *)
  core_type = typ }                                            (* ← core_type! *)
```

### What's Generated
```ocaml
(* Typed_core_ast.core_lang - also a RECORD with type field! *)
{ core_desc = CSequence (
    { core_desc = CWrite ("counter", {
        term_desc = BinOp (Plus,
                           { term_desc = Var "counter"; term_type = Int },
                           { term_desc = Const (Num 1); term_type = Int });
        term_type = Int
      });
      core_type = Unit },  (* ← Every core_lang node has core_type *)
    { core_desc = CRead "counter";
      core_type = Int });
  core_type = Int }
```

### Type Structure
```ocaml
(* From typed_core_ast.ml *)
type core_lang = {
  core_desc: core_desc;    (* The actual computation *)
  core_type: typ           (* TYPE FIELD - makes it typed! *)
}
```

---

## Example 6: Let Binding (TYPED with typed binders)

### Source Code Location
[translator.ml:210-212](lib/translator.ml#L210-L212)

### TypeScript Input
```typescript
let tmp = expr;
```

### Translator Code
```ocaml
{ core_desc = CLet ((tmp, e.core_type), e, f { term_desc = Var tmp;
                                                term_type = e.core_type });
  core_type = (f { term_desc = Var tmp; term_type = e.core_type }).core_type }
```

### What's Generated
```ocaml
{ core_desc = CLet (
    ("tmp", Int),        (* ← Binder is (string, typ) tuple! *)
    { core_desc = ...; core_type = Int },
    ...
  );
  core_type = ... }
```

### Key Observation
Binders in Typed_core_ast are **tuples of (string, typ)**:

```ocaml
(* Typed_core_ast *)
type binder = string * typ    (* Has type! *)

(* Hiptypes *)
type binder = string          (* No type! *)
```

---

## Example 7: Heap Specifications (UNTYPED!)

### Source Code Location
[translator.ml:290-323](lib/translator.ml#L290-L323)

### TypeScript Input
```typescript
function increment() {
  counter = counter + 1;
}
// Generates spec: req counter->v_counter; ens counter->v_counter'
```

### Translator Code
```ocaml
let generate_spec_from_signature outer_ctx typed_params ret_type body_statements =
  (* ... *)

  (* Build heap precondition - UNTYPED constructors! *)
  let require_kappa = List.fold_left (fun acc global_name ->
    let fresh_var : Untyped_core_ast.term = Var ("v_" ^ global_name) in  (* ← UNTYPED term! *)
    let pts = Hiptypes.PointsTo (global_name, fresh_var) in              (* ← Hiptypes! *)
    match acc with
    | Hiptypes.EmptyHeap -> pts                                          (* ← Hiptypes! *)
    | _ -> Hiptypes.SepConj (acc, pts)                                   (* ← Hiptypes! *)
  ) Hiptypes.EmptyHeap all_accessed in

  (* Build heap postcondition - UNTYPED constructors! *)
  let ensure_kappa = List.fold_left (fun acc global_name ->
    let var_term : Untyped_core_ast.term = Var var_name in               (* ← UNTYPED term! *)
    let pts = Hiptypes.PointsTo (global_name, var_term) in
    match acc with
    | Hiptypes.EmptyHeap -> pts
    | _ -> Hiptypes.SepConj (acc, pts)
  ) Hiptypes.EmptyHeap all_accessed in

  (* Build specification - UNTYPED! *)
  Hiptypes.Sequence (                                                     (* ← Hiptypes! *)
    Hiptypes.Require (require_pi, require_kappa),
    Hiptypes.NormalReturn (ensure_pi, ensure_kappa)
  )
```

### What's Generated
```ocaml
(* Hiptypes.staged_spec - UNTYPED constructors! *)
Sequence (
  Require (
    True,
    PointsTo ("counter", Var "v_counter")    (* ← No type field! *)
  ),
  NormalReturn (
    Colon ("res", Type UnitBty),
    PointsTo ("counter", Var "v_counter'")
  )
)
```

### Type Comparison

**Untyped term** (Hiptypes):
```ocaml
Var "v_counter"    (* Just a constructor, no record wrapper *)
```

**Typed term** (Typed_core_ast):
```ocaml
{ term_desc = Var "v_counter";
  term_type = TVar 42 }    (* Record with type field *)
```

### Why Untyped for Specs?

From the code comments and type annotations:
```ocaml
let fresh_var : Untyped_core_ast.term = Var ("v_" ^ global_name) in
```

The translator **explicitly** creates `Untyped_core_ast.term` for spec variables!

**Reason**: Logic variables like `v_counter` don't exist in the program. They're existentially quantified variables in the specification. We don't know their types yet - type inference will figure it out later.

---

## Example 8: Conversion from Untyped to Typed

### Source Code Location
[translator.ml:857-861](lib/translator.ml#L857-L861)

### Translator Code
```ocaml
(* Generate spec - returns UNTYPED Hiptypes.staged_spec *)
let untyped_spec =
  try
    parse_to_hiptype json
  with e ->
    Printf.eprintf "Warning: Failed to parse JSDoc spec\n";
    generate_spec_from_signature outer_ctx typed_params ret_type body_statements
in

(* Convert to TYPED Typed_core_ast.staged_spec *)
let spec = retype_staged_spec untyped_spec in
```

### What Happens

**Step 1 - Generate Untyped**:
```ocaml
(* untyped_spec : Hiptypes.staged_spec *)
Sequence (
  Require (True, PointsTo ("counter", Var "v_counter")),
  NormalReturn (Colon ("res", Type UnitBty), PointsTo ("counter", Var "v_counter'"))
)
```

**Step 2 - Retype to Typed**:
```ocaml
(* spec : Typed_core_ast.staged_spec *)
{ spec_desc = Sequence (
    Require (True, PointsTo ("counter", {
      term_desc = Var "v_counter";
      term_type = TVar 42    (* ← Fresh type variable added! *)
    })),
    NormalReturn (Colon ("res", {...}), PointsTo ("counter", {
      term_desc = Var "v_counter'";
      term_type = TVar 42    (* ← Same type variable *)
    }))
  )
}
```

### The Conversion Function

From [retypehip.ml:11-32](lib/hipcore_typed/retypehip.ml#L11-L32):
```ocaml
let rec retype_term (term : Hiptypes.term) =
  let term_desc = match term with
  | Hiptypes.Var v -> Var v              (* Same constructor *)
  | Hiptypes.Const c -> Const c
  (* ... *)
  in
  { term_desc;                            (* Wrap in record *)
    term_type = Types.new_type_var () }   (* Add fresh type variable *)
```

**Key transformation**:
- Input: `Hiptypes.Var "v_counter"` (bare constructor)
- Output: `{ term_desc = Var "v_counter"; term_type = TVar 42 }` (typed record)

---

## Side-by-Side Comparison

### For Program Code: TYPED

| Construct | TypeScript | Generated (Typed_core_ast) |
|-----------|-----------|----------------------------|
| **Constant** | `42` | `{ term_desc = Const (Num 42); term_type = Int }` |
| **Variable** | `x` | `{ term_desc = Var "x"; term_type = Int }` |
| **BinOp** | `x + 1` | `{ term_desc = BinOp (Plus, x_term, one_term); term_type = Int }` |
| **Let** | `let x = 42` | `{ core_desc = CLet (("x", Int), init, body); core_type = ... }` |
| **Read** | `!counter` | `{ core_desc = CRead "counter"; core_type = Int }` |
| **Write** | `counter := 5` | `{ core_desc = CWrite ("counter", val); core_type = Unit }` |

**Pattern**: Every construct has a **type field** (`term_type` or `core_type`)

### For Specifications: UNTYPED → TYPED

| Construct | Generated (Hiptypes) | After retype (Typed_core_ast) |
|-----------|---------------------|-------------------------------|
| **Logic var** | `Var "v_counter"` | `{ term_desc = Var "v_counter"; term_type = TVar 42 }` |
| **PointsTo** | `PointsTo ("x", Var "v")` | `PointsTo ("x", { term_desc = Var "v"; term_type = TVar 43 })` |
| **SepConj** | `SepConj (k1, k2)` | `SepConj (k1_typed, k2_typed)` |
| **Require** | `Require (pi, kappa)` | `Require (pi_typed, kappa_typed)` |

**Pattern**: Start with **bare constructors**, then **wrap in records with type variables**

---

## Code Structure Revealed

### Typed Core Language Construction

```ocaml
(* Building a simple expression: x + 1 *)

(* The translator does: *)
let x_term = { term_desc = Var "x"; term_type = Int } in
let one_term = { term_desc = Const (Num 1); term_type = Int } in
let plus_term = { term_desc = BinOp (Plus, x_term, one_term);
                  term_type = Int } in

(* Every level is a record with term_type field! *)
```

### Untyped Specification Construction

```ocaml
(* Building a heap predicate: counter->v_counter *)

(* The translator does: *)
let logic_var = Var "v_counter" in                    (* Bare constructor *)
let heap_pred = Hiptypes.PointsTo ("counter", logic_var) in
let precond = Hiptypes.Require (Hiptypes.True, heap_pred) in

(* No type fields anywhere! *)

(* Then converts: *)
let typed_spec = retype_staged_spec precond in        (* Adds types *)
```

---

## The Module Boundary

### What's Imported

From [translator.ml:8-13](lib/translator.ml#L8-L13):
```ocaml
open Hipcore_typed.Typed_core_ast    (* ← For program code *)
open Yojson.Safe.Util
open Hipcore_common.Types
open Hipcore                         (* ← For specifications (includes Hiptypes) *)
open Parsing
open Hipcore_typed.Retypehip         (* ← For untyped→typed conversion *)
```

### What Each Module Provides

**Typed_core_ast**: Typed constructors
- `type term = { term_desc; term_type }`
- `type core_lang = { core_desc; core_type }`
- `type binder = string * typ`

**Hipcore (includes Hiptypes)**: Untyped constructors
- `type term = Var of string | Const of const | ...`
- `type kappa = EmptyHeap | PointsTo of string * term | ...`
- `type staged_spec = Require of pi * kappa | ...`

**Retypehip**: Conversion functions
- `retype_term : Hiptypes.term → Typed_core_ast.term`
- `retype_staged_spec : Hiptypes.staged_spec → Typed_core_ast.staged_spec`

---

## Complete Example: Function with Spec

### TypeScript Source
```typescript
let counter: number = 0;

function increment(): void {
  counter = counter + 1;
}
```

### Translation Process

**Step 1: Translate variable declaration** (TYPED)
```ocaml
{ core_desc = CLet (
    ("counter", TConstr ("ref", [TConstr ("int", [])])),    (* ← Typed binder *)
    { core_desc = CRef { term_desc = Const (Num 0);         (* ← Typed term *)
                         term_type = TConstr ("int", []) };
      core_type = TConstr ("ref", [TConstr ("int", [])]) },
    ...rest...
  );
  core_type = TConstr ("unit", []) }
```

**Step 2: Translate function body** (TYPED)
```ocaml
let body_expr = { core_desc = CSequence (
  { core_desc = CWrite ("counter", {
      term_desc = BinOp (Plus,
                         { term_desc = CRead "counter"; term_type = Int },
                         { term_desc = Const (Num 1); term_type = Int });
      term_type = Int
    });
    core_type = Unit },
  { core_desc = CValue { term_desc = Const ValUnit; term_type = Unit };
    core_type = Unit }
  );
  core_type = Unit }
```

**Step 3: Generate spec** (UNTYPED)
```ocaml
let untyped_spec = Hiptypes.Sequence (
  Hiptypes.Require (
    Hiptypes.True,
    Hiptypes.PointsTo ("counter", Var "v_counter")    (* ← Untyped Var *)
  ),
  Hiptypes.NormalReturn (
    Hiptypes.Colon ("res", Hiptypes.Type UnitBty),
    Hiptypes.PointsTo ("counter", Var "v_counter'")   (* ← Untyped Var *)
  )
)
```

**Step 4: Retype spec** (TYPED)
```ocaml
let typed_spec = retype_staged_spec untyped_spec
(* Result: *)
{ spec_desc = Sequence (
    Require (
      True,
      PointsTo ("counter", {
        term_desc = Var "v_counter";
        term_type = TVar 42              (* ← Fresh type variable *)
      })
    ),
    NormalReturn (
      Colon ("res", {...}),
      PointsTo ("counter", {
        term_desc = Var "v_counter'";
        term_type = TVar 42              (* ← Same type variable *)
      })
    )
  )
}
```

**Step 5: Combine** (ALL TYPED)
```ocaml
{ core_desc = CLambda (
    [],                    (* parameters *)
    Some typed_spec,       (* ← Typed spec *)
    body_expr              (* ← Typed body *)
  );
  core_type = TConstr ("arrow", [TConstr ("unit", []); TConstr ("unit", [])]) }
```

---

## Summary

### What Uses Typed Constructors
- **All program code**: expressions, statements, values
- **All core language**: CLet, CRef, CRead, CWrite, etc.
- **All terms in program**: constants, variables, operations
- **All binders**: `(name, typ)` tuples

### What Uses Untyped Constructors
- **Specification building**: Before conversion
- **Logic variables**: `v_counter`, `v_counter'`
- **Heap predicates**: PointsTo, SepConj, EmptyHeap
- **Staged specs**: Require, NormalReturn, Sequence

### The Workflow
```
Program Code: TypeScript → Typed_core_ast (direct)
                                ↓
                          No conversion needed
                                ↓
                          Output as-is

Specifications: Hiptypes (untyped) → retype_staged_spec → Typed_core_ast
                                              ↓
                                    Adds fresh type variables
                                              ↓
                                    Type inference resolves them
```

**The key insight**: Program code is built typed because we know the types. Specifications are built untyped because logic variables don't have types until inference.
