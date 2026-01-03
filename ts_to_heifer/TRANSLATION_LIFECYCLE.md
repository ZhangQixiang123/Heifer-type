# Translation Lifecycle: From TypeScript to Verification

## Your Questions Answered

### Q1: Does the untyped specification get translated into typed one?

**Answer: YES, absolutely!**

From [translator.ml:857-861](lib/translator.ml#L857-L861):
```ocaml
(* Step 1: Generate UNTYPED specification *)
let untyped_spec =
  try
    parse_to_hiptype json
  with e ->
    generate_spec_from_signature outer_ctx typed_params ret_type body_statements
in

(* Step 2: Convert to TYPED specification *)
let spec = retype_staged_spec untyped_spec in
```

**The conversion happens immediately** within the translator, before the function is even constructed.

### Q2: What is the future for code translated from the ts translator?

**Answer: Currently, it just gets pretty-printed. But it COULD be verified like OCaml code.**

## The Complete Lifecycle

### Current State (As Implemented)

```
┌─────────────────────────────────────────────────────────┐
│ 1. TypeScript Source                                    │
│    let counter: number = 0;                             │
│    function increment() { counter++; }                  │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 2. TypeScript Compiler                                  │
│    tsc --parse → JSON AST                               │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 3. ts_to_heifer Translator                              │
│                                                         │
│    A. Build Typed Core Language                         │
│       { core_desc = CLet (...);                        │
│         core_type = ... }                              │
│                                                         │
│    B. Generate Untyped Spec                             │
│       Hiptypes.Sequence (                              │
│         Require (..., PointsTo ("counter", Var "v")),  │
│         NormalReturn (...)                             │
│       )                                                 │
│                                                         │
│    C. Convert to Typed Spec (retype_staged_spec)       │
│       { spec_desc = Sequence (...);                    │
│         (* type vars added *) }                        │
│                                                         │
│    D. Combine into Typed Lambda                         │
│       { core_desc = CLambda (params, Some spec, body); │
│         core_type = arrow_type }                       │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Pretty Printer (Hipcore_typed.Pretty)                │
│    string_of_core_lang → OCaml-like syntax              │
│                                                         │
│    Output:                                              │
│    let counter = ref 0 in                               │
│    let increment = fun                                  │
│      (*@ req counter->v_counter;                        │
│          ens counter->v_counter'/\res:() @*)            │
│      -> counter := !counter + 1                         │
└─────────────────────────────────────────────────────────┘
                            ↓
                    *** STOPS HERE ***
                   (Currently just printed)
```

### Future State (Possible Integration)

```
[... steps 1-4 same as above ...]
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Type Inference (Hipprover.Infer_types)              │
│                                                         │
│    Fill in type variables:                              │
│    TVar 42 → TConstr ("int", [])                       │
│                                                         │
│    Result: Fully typed AST with concrete types         │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 6. Verification (Hipprover.Forward_rules)              │
│                                                         │
│    analyze_type_spec:                                   │
│    - Check precondition → postcondition                 │
│    - Verify separation logic properties                 │
│    - Prove heap safety                                  │
│                                                         │
│    Result: ✓ Verified or ✗ Error with counterexample   │
└─────────────────────────────────────────────────────────┘
```

## Detailed Transformation: Spec Lifecycle

### Stage 1: Generation (UNTYPED)

**Code**: [translator.ml:290-323](lib/translator.ml#L290-L323)

```ocaml
let generate_spec_from_signature outer_ctx typed_params ret_type body_statements =
  (* Scan function body for global accesses *)
  let access_info = collect_accessed_globals outer_ctx body_statements in

  (* Build UNTYPED heap predicate *)
  let require_kappa = List.fold_left (fun acc global_name ->
    let fresh_var : Untyped_core_ast.term = Var ("v_" ^ global_name) in
    let pts = Hiptypes.PointsTo (global_name, fresh_var) in
    match acc with
    | Hiptypes.EmptyHeap -> pts
    | _ -> Hiptypes.SepConj (acc, pts)
  ) Hiptypes.EmptyHeap all_accessed in

  (* Return UNTYPED specification *)
  Hiptypes.Sequence (
    Hiptypes.Require (require_pi, require_kappa),
    Hiptypes.NormalReturn (ensure_pi, ensure_kappa)
  )
```

**Output (Untyped Hiptypes)**:
```ocaml
(* Type: Hiptypes.staged_spec *)
Sequence (
  Require (
    True,
    PointsTo ("counter", Var "v_counter")    (* ← Bare term, no type *)
  ),
  NormalReturn (
    Colon ("res", Type UnitBty),
    PointsTo ("counter", Var "v_counter'")
  )
)
```

### Stage 2: Conversion (UNTYPED → TYPED)

**Code**: [translator.ml:861](lib/translator.ml#L861)

```ocaml
let spec = retype_staged_spec untyped_spec in
```

**What `retype_staged_spec` does** ([retypehip.ml:51-66](lib/hipcore_typed/retypehip.ml#L51-L66)):

```ocaml
let rec retype_staged_spec (spec : Hiptypes.staged_spec) =
  match spec with
  | Hiptypes.Sequence (s1, s2) ->
      Sequence (retype_staged_spec s1, retype_staged_spec s2)
  | Hiptypes.Require (pi, kappa) ->
      Require (retype_pi pi, retype_kappa kappa)
  | Hiptypes.NormalReturn (pi, kappa) ->
      NormalReturn (retype_pi pi, retype_kappa kappa)
  (* ... *)

and retype_kappa (kappa : Hiptypes.kappa) =
  match kappa with
  | Hiptypes.PointsTo (loc, value) ->
      PointsTo (loc, retype_term value)    (* ← Converts term! *)
  | Hiptypes.SepConj (k1, k2) ->
      SepConj (retype_kappa k1, retype_kappa k2)
  (* ... *)

and retype_term (term : Hiptypes.term) =
  let term_desc = match term with
  | Hiptypes.Var v -> Var v
  | Hiptypes.Const c -> Const c
  (* ... *)
  in
  { term_desc;
    term_type = Types.new_type_var () }    (* ← Add fresh type variable! *)
```

**Output (Typed Typed_core_ast)**:
```ocaml
(* Type: Typed_core_ast.staged_spec *)
{ spec_desc = Sequence (
    Require (
      True,
      PointsTo ("counter", {
        term_desc = Var "v_counter";
        term_type = TVar 42              (* ← Fresh type variable added! *)
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

### Stage 3: Integration (TYPED spec + TYPED body)

**Code**: [translator.ml:867-872](lib/translator.ml#L867-L872)

```ocaml
(* Combine typed spec with typed body *)
let fn_type = arrow_type_of_params typed_params ret_type in
let lambda = {
  core_desc = CLambda (typed_params, Some spec, body_with_ret_type);
  core_type = fn_type
} in
{ core_desc = CLet ((name, fn_type), lambda, continuation);
  core_type = continuation.core_type }
```

**Output (Complete Typed Function)**:
```ocaml
{ core_desc = CLet (
    ("increment", TConstr ("arrow", [TConstr ("unit", []); TConstr ("unit", [])])),
    { core_desc = CLambda (
        [],                              (* parameters *)
        Some {                           (* ← TYPED spec *)
          spec_desc = Sequence (
            Require (True, PointsTo ("counter", {
              term_desc = Var "v_counter";
              term_type = TVar 42
            })),
            NormalReturn (Colon ("res", {...}), PointsTo ("counter", {
              term_desc = Var "v_counter'";
              term_type = TVar 42
            }))
          )
        },
        { core_desc = CSequence (...);   (* ← TYPED body *)
          core_type = TConstr ("unit", []) }
      );
      core_type = TConstr ("arrow", [...]) }
    ),
    ...
  );
  core_type = ... }
```

**Everything is now TYPED!**

## What Happens to Type Variables?

### Current State (After Translation)
```ocaml
PointsTo ("counter", {
  term_desc = Var "v_counter";
  term_type = TVar 42          (* ← Placeholder! *)
})
```

### After Type Inference (If integrated)

**Type Inference** ([infer_types.ml](lib/hipprover/infer_types.ml)) would:

1. **Collect constraints**:
   ```ocaml
   (* From body: counter := !counter + 1 *)
   typeof(!counter) = int
   typeof(counter) = ref(int)

   (* From spec: counter->v_counter *)
   TVar 42 must be compatible with typeof(!counter)

   (* Constraint: *)
   TVar 42 ~ int
   ```

2. **Solve via unification**:
   ```ocaml
   TVar 42 := int
   ```

3. **Result**:
   ```ocaml
   PointsTo ("counter", {
     term_desc = Var "v_counter";
     term_type = TConstr ("int", [])    (* ← Concrete type! *)
   })
   ```

## Integration with Verification Pipeline

### How OCaml Code Gets Verified

From [hiplib.ml:374-384](lib/hiplib/hiplib.ml#L374-L384):

```ocaml
| Meth (m_name, m_params, m_spec, m_body, m_tactics, pure_fn_info) ->
    let meth : meth_def = {m_name; m_params; m_spec; m_body; m_tactics} in

    (* Type inference *)
    process_pure_fn_info meth pure_fn_info;

    (* Verification *)
    let prog = analyze_method prog meth in

    (* Add to program *)
    let function_type = List.fold_right (fun e acc -> Arrow (e, acc))
                          (List.map type_of_binder m_params) m_body.core_type in
    [m_name, function_type], prog
```

### What `analyze_method` Does

From [hiplib.ml:188-221](lib/hiplib/hiplib.ml#L188-L221):

```ocaml
let analyze_method (prog : core_program) (meth : meth_def) : core_program =
  (* Extract specification *)
  let given_spec = meth.m_spec in
  let initial_spec = match given_spec with
    | None -> failwith "must provide specs"
    | Some s -> s
  in

  (* Verify using forward rules *)
  let open Hipprover.Forward_rules in
  analyze_type_spec initial_spec meth prog
```

### How TypeScript Could Be Verified

**Option 1: Integrate into hiplib**

Add TypeScript support to hiplib:
```ocaml
(* New function in hiplib.ml *)
let process_typescript_file filename =
  (* 1. Call TS compiler to get JSON *)
  let json_ast = call_typescript_compiler filename in

  (* 2. Translate to Typed_core_ast *)
  let intermediates = Ts_to_heifer.Translator.translate_program_to_intermediates json_ast in

  (* 3. Process each function (same as OCaml) *)
  List.fold_left (fun prog item ->
    match item with
    | `Meth (m_name, m_params, m_spec, m_body, m_tactics, pure_fn_info) ->
        let meth : meth_def = {m_name; m_params; m_spec; m_body; m_tactics} in
        analyze_method prog meth    (* ← Same verification as OCaml! *)
  ) empty_program intermediates
```

**Option 2: Standalone Verification Tool**

Create a new binary:
```ocaml
(* ts_to_heifer/bin/verify.ml *)
let () =
  (* 1. Translate *)
  let json = Yojson.Safe.from_file input_file in
  let intermediates = translate_program_to_intermediates json in

  (* 2. Run type inference *)
  let typed_intermediates = List.map (fun item ->
    match item with
    | `Meth (name, params, spec, body, tactics, pure_info) ->
        (* Run type inference on spec and body *)
        let typed_spec = Hipprover.Infer_types.infer_types_staged_spec spec in
        let typed_body = Hipprover.Infer_types.infer_types_core typed_body in
        `Meth (name, params, typed_spec, typed_body, tactics, pure_info)
  ) intermediates in

  (* 3. Verify each function *)
  List.iter (fun item ->
    match item with
    | `Meth (name, params, spec, body, tactics, _) ->
        let meth = {m_name=name; m_params=params; m_spec=Some spec;
                    m_body=body; m_tactics=tactics} in
        let result = Hiplib.analyze_method empty_program meth in
        Printf.printf "Function %s: %s\n" name
          (if result then "✓ Verified" else "✗ Failed")
  ) typed_intermediates
```

## The Data Flow Diagram

```
TypeScript Source
       ↓
  TS Compiler
       ↓
    JSON AST
       ↓
┌──────────────────────────────────────────┐
│   ts_to_heifer/lib/translator.ml         │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ translate_expr/stmt                │  │
│  │   → Typed_core_ast.core_lang       │  │
│  └────────────────────────────────────┘  │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ generate_spec_from_signature       │  │
│  │   → Hiptypes.staged_spec (UNTYPED) │  │
│  └────────────────────────────────────┘  │
│                    ↓                     │
│  ┌────────────────────────────────────┐  │
│  │ retype_staged_spec                 │  │
│  │   → Typed_core_ast.staged_spec     │  │
│  │   (TYPED with type variables)      │  │
│  └────────────────────────────────────┘  │
│                    ↓                     │
│  ┌────────────────────────────────────┐  │
│  │ CLambda (params, Some spec, body)  │  │
│  │   → Complete typed function        │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
       ↓
  *** Currently: Pretty.string_of_core_lang ***
       ↓
  Printed Output
```

```
*** Future Integration ***
       ↓
┌──────────────────────────────────────────┐
│   Hipprover.Infer_types                  │
│                                          │
│  TVar 42 ~ int → TVar 42 := int         │
│  (Solve type constraints)                │
└──────────────────────────────────────────┘
       ↓
┌──────────────────────────────────────────┐
│   Hipprover.Forward_rules                │
│                                          │
│  analyze_type_spec:                      │
│  - Forward symbolic execution            │
│  - Check precondition → postcondition    │
│  - Verify separation logic               │
└──────────────────────────────────────────┘
       ↓
   Verification Result
   ✓ Verified / ✗ Failed
```

## Summary

### Q1: Do untyped specs become typed?

**YES!** The transformation happens in 3 stages:

1. **Generate**: Untyped `Hiptypes.staged_spec`
2. **Retype**: Typed `Typed_core_ast.staged_spec` (with type variables)
3. **Infer**: Typed `Typed_core_ast.staged_spec` (with concrete types - if verified)

### Q2: What is the future of translated code?

**Current**: Just printed as text

**Potential Future**:
1. **Type Inference**: Fill in type variables
2. **Verification**: Prove specifications hold
3. **Integration**: Part of full verification pipeline

The translated code is in the **exact same format** as OCaml-generated code:
- `Typed_core_ast.core_lang` with `Typed_core_ast.staged_spec`
- Ready for type inference
- Ready for verification
- Just needs integration!

The architecture is **already designed** for this - the translator produces output compatible with the verification pipeline. It just needs:
- A driver program to call type inference
- Integration with `analyze_method` from hiplib
- Error reporting for TypeScript code

**The hard part (translation to typed IR) is done!**
