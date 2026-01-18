# Record Type Implementation Plan for Heifer

Date: 2026-01-03

## Overview

This document outlines the plan to extend Heifer's type system to fully support record types (objects/structs). While Heifer's type system already has record type definitions, the core language lacks the necessary constructs for record operations.

## Current State Analysis

### What Already Exists

#### 1. Type System Support
**File**: [lib/hipcore_common/types.ml:50-61](lib/hipcore_common/types.ml#L50-L61)

Record types are fully defined in the type system:
```ocaml
type record_field = {
  field_name: string;
  field_type: typ;
}

type type_decl_kind =
  | Tdecl_inductive of type_constructor list
  | Tdecl_record of record_field list

type type_declaration = {
  tdecl_name: string;
  tdecl_params: typ list;
  tdecl_kind: type_decl_kind
}
```

**Example**: The `ref` type is implemented as a record ([lib/hipcore_typed/globals.ml:22-26](lib/hipcore_typed/globals.ml#L22-L26)):
```ocaml
{
  tdecl_name = "ref";
  tdecl_params = [TVar "a"];
  tdecl_kind = Tdecl_record [{field_name = "contents"; field_type = TVar "a"}]
}
```

#### 2. OCaml Frontend Recognition
**File**: [lib/heifer-parsing/core_lang.ml:428-430](lib/heifer-parsing/core_lang.ml#L428-L430)

The parser recognizes three OCaml record operations:
- `Pexp_record` - Record construction: `{ field1 = val1; field2 = val2 }`
- `Pexp_field` - Field access: `record.field`
- `Pexp_setfield` - Field mutation: `record.field <- value`

**Status**: These are recognized but NOT translated (they fall through to default case).

### What's Missing

#### 1. Core Language Constructs
**Files**:
- [lib/hipcore/untyped_core_ast.ml:84-100](lib/hipcore/untyped_core_ast.ml#L84-L100)
- [lib/hipcore_typed/typed_core_ast.ml:103-121](lib/hipcore_typed/typed_core_ast.ml#L103-L121)

The typed and untyped ASTs have NO constructors for:
- `CRecord` - Record construction
- `CGetField` / `CFieldAccess` - Field access
- `CSetField` / `CFieldUpdate` - Field mutation

#### 2. Pattern Matching Support
**File**: [lib/hipcore_typed/patterns.ml:40](lib/hipcore_typed/patterns.ml#L40)

Explicitly marked as TODO:
```ocaml
(* TODO: record patterns currently not implemented *)
```

#### 3. Translation Logic
**File**: [lib/heifer-parsing/core_lang.ml:214-405](lib/heifer-parsing/core_lang.ml#L214-L405)

The `transformation` function doesn't handle record expression cases - they fall through to:
```ocaml
CValue (Const (ValUnit))
```

#### 4. Pretty Printing
**File**: [lib/hipcore_typed/Pretty.ml](lib/hipcore_typed/Pretty.ml)

No support for pretty-printing record operations.

#### 5. Type Inference/Checking
No forward rules for record operations.

#### 6. Verification
No separation logic reasoning about record fields.

### How `ref` Works Without Full Record Support

The `ref` type is declared as a record but uses special-purpose constructs:
- `CRef` for `ref value` (constructor)
- `CRead` for `!x` (dereference = field access to "contents")
- `CWrite` for `x := value` (assignment = field update of "contents")

These are hardcoded operations, NOT general record operations.

## Implementation Plan

### Phase 1: Core Language Extensions

#### File: [lib/hipcore/untyped_core_ast.ml](lib/hipcore/untyped_core_ast.ml)
Add to `core_lang` type (around line 84):

```ocaml
and core_lang =
  | CValue of core_value
  | CLet of string * core_lang * core_lang
  | CSequence of core_lang * core_lang
  | CIfELse of pi * core_lang * core_lang
  | CFunCall of string * (core_value) list
  | CWrite of string * core_value
  | CRef of core_value
  | CRead of string
  | CAssert of pi * kappa
  | CPerform of string * core_value option
  | CMatch of handler_type * tryCatchLemma option * core_lang * core_handler_ops * constr_cases
  | CResume of core_value list
  | CLambda of string list * staged_spec option * core_lang
  | CShift of bool * string * core_lang
  | CReset of core_lang
  (* NEW: Record operations *)
  | CRecord of string * (string * core_value) list  (* type_name, field_bindings *)
  | CGetField of core_value * string                (* record, field_name *)
  | CSetField of core_value * string * core_value   (* record, field_name, new_value *)
```

#### File: [lib/hipcore_typed/typed_core_ast.ml](lib/hipcore_typed/typed_core_ast.ml)
Add to `core_lang_desc` type (around line 103):

```ocaml
and core_lang_desc =
  | CValue of core_value
  | CLet of binder * core_lang * core_lang
  | CSequence of core_lang * core_lang
  | CIfElse of pi * core_lang * core_lang
  | CFunCall of string * (core_value) list
  | CWrite of string * core_value
  | CRef of core_value
  | CRead of string
  | CAssert of pi * kappa
  | CPerform of string * core_value option
  | CMatch of handler_type * tryCatchLemma option * core_lang * core_handler_ops * constr_cases
  | CResume of core_value list
  | CLambda of binder list * staged_spec option * core_lang
  | CShift of bool * binder * core_lang
  | CReset of core_lang
  (* NEW: Record operations *)
  | CRecord of string * (string * core_value) list
  | CGetField of core_value * string
  | CSetField of core_value * string * core_value
```

### Phase 2: OCaml Frontend Translation

#### File: [lib/heifer-parsing/core_lang.ml](lib/heifer-parsing/core_lang.ml)
Add translation cases in the `transformation` function (around line 214):

```ocaml
let rec transformation (bound_names:string list) (expr:expression) : core_lang =
  let open Variables in
  match expr.pexp_desc with
  (* ... existing cases ... *)

  (* Record construction: { field1 = expr1; field2 = expr2 } *)
  | Pexp_record (fields, base) ->
      if Option.is_some base then
        failwith "Record update syntax { r with field = value } not yet supported";
      (* Translate each field assignment *)
      let rec translate_fields remaining_fields acc_assignments =
        match remaining_fields with
        | [] ->
            (* All fields translated, create the record *)
            CRecord ("inferred_type", List.rev acc_assignments)
        | (field_ident, expr) :: rest ->
            let field_name = Longident.last field_ident.txt in
            transformation bound_names expr |> maybe_var (fun value ->
              translate_fields rest ((field_name, value) :: acc_assignments)
            )
      in
      translate_fields fields []

  (* Field access: record.field *)
  | Pexp_field (record_expr, field_ident) ->
      let field_name = Longident.last field_ident.txt in
      transformation bound_names record_expr
      |> maybe_var (fun record_val -> CGetField (record_val, field_name))

  (* Field mutation: record.field <- value *)
  | Pexp_setfield (record_expr, field_ident, value_expr) ->
      let field_name = Longident.last field_ident.txt in
      transformation bound_names record_expr
      |> maybe_var (fun record_val ->
          transformation bound_names value_expr
          |> maybe_var (fun value -> CSetField (record_val, field_name, value)))

  (* ... rest of cases ... *)
```

### Phase 3: Type Declarations

#### File: [lib/heifer-parsing/core_lang.ml](lib/heifer-parsing/core_lang.ml)
Update `transform_str` function (around line 492) to handle record type declarations:

```ocaml
let transform_str bound_names (s : structure_item) : intermediate option =
  let open Utils in
  match s.pstr_desc with
  (* ... existing cases ... *)

  (* Variant type declarations - existing *)
  | Pstr_type (_, [{ptype_kind = Ptype_variant constructors; ptype_name = {txt = name; _}; ptype_params = params; _}]) ->
      let params = params |> List.map (fun (core_type, _) -> core_type_to_simple_type core_type) in
      let constructors = constructors |> List.map (fun constructor ->
        let constr_args = match constructor.pcd_args with
        | Pcstr_tuple args -> List.map core_type_to_simple_type args
        | Pcstr_record _ -> failwith ("record as type constructor argument not supported") in
        (constructor.pcd_name.txt, constr_args)
      )
      in
      Some (Typedef {tdecl_name = name; tdecl_params = params; tdecl_kind = Tdecl_inductive constructors})

  (* NEW: Record type declarations *)
  | Pstr_type (_, [{ptype_kind = Ptype_record fields; ptype_name = {txt = name; _}; ptype_params = params; _}]) ->
      let params = params |> List.map (fun (core_type, _) -> core_type_to_simple_type core_type) in
      let record_fields = fields |> List.map (fun field ->
        { field_name = field.pld_name.txt;
          field_type = core_type_to_simple_type field.pld_type }
      ) in
      Some (Typedef {tdecl_name = name; tdecl_params = params; tdecl_kind = Tdecl_record record_fields})

  (* ... rest of cases ... *)
```

### Phase 4: Pretty Printing

#### File: [lib/hipcore_typed/Pretty.ml](lib/hipcore_typed/Pretty.ml)
Add cases in `string_of_core_lang` function:

```ocaml
let rec string_of_core_lang e =
  match e.core_desc with
  (* ... existing cases ... *)

  (* NEW: Record operations *)
  | CRecord (type_name, fields) ->
      let field_strs = fields |> List.map (fun (name, value) ->
        Format.sprintf "%s = %s" name (string_of_term value)
      ) |> String.concat "; " in
      Format.sprintf "{ %s }" field_strs

  | CGetField (record, field) ->
      Format.sprintf "%s.%s" (string_of_term record) field

  | CSetField (record, field, value) ->
      Format.sprintf "%s.%s <- %s"
        (string_of_term record) field (string_of_term value)

  (* ... rest of cases ... *)
```

### Phase 5: Retyping (Type Inference)

#### File: [lib/hipcore_typed/retypehip.ml](lib/hipcore_typed/retypehip.ml)
Add type inference for record operations:

```ocaml
(* This file needs to be examined to determine exact location *)

(* For CRecord: lookup record type definition, ensure all fields present with correct types *)
(* For CGetField: lookup record type, get field type *)
(* For CSetField: lookup record type, check field exists, check value type matches *)
```

**Note**: Need to examine this file to see the exact structure for type inference.

### Phase 6: Forward Rules (Verification)

#### File: [lib/hipprover/forward_rules.ml](lib/hipprover/forward_rules.ml)
Add separation logic rules for:

**Record Construction**:
```
Γ ⊢ {emp} let r = { f1 = v1; f2 = v2; ... fn = vn } {r.f1 ↦ v1 * r.f2 ↦ v2 * ... * r.fn ↦ vn}
```

**Field Access**:
```
Γ ⊢ {r.f ↦ v} let x = r.f {r.f ↦ v ∧ x = v}
```

**Field Update**:
```
Γ ⊢ {r.f ↦ vold} r.f <- vnew {r.f ↦ vnew}
```

### Phase 7: Pattern Matching

#### File: [lib/hipcore_typed/patterns.ml](lib/hipcore_typed/patterns.ml)
Implement record pattern matching support (line 40 TODO):

```ocaml
(* Support patterns like: let { x; y } = point in ... *)
(* Or: match r with | { field1 = p1; field2 = p2 } -> ... *)
```

## Alternative Approach: Tuple Encoding

A simpler initial approach could be to **encode records as tuples** during translation:

- `{ x = 1; y = 2 }` → `(1, 2)` with metadata tracking field positions
- `r.x` → `fst r` or tuple projection for the appropriate position
- `r.x <- v` → Not supported (tuples are immutable)

**Pros**:
- Faster to implement
- Leverages existing tuple support (if it exists)
- No changes to core AST needed

**Cons**:
- Less faithful to source semantics
- Cannot support mutable records
- Field names lost (debugging harder)
- Type errors less clear

**Recommendation**: Only use if tuple support already exists and time is limited.

## Implementation Priority

### Must Have (MVP):
1. Phase 1: Core language constructors
2. Phase 2: OCaml frontend translation
3. Phase 4: Pretty printing (for debugging)

### Should Have:
4. Phase 3: Type declarations
5. Phase 5: Type inference

### Nice to Have:
6. Phase 6: Forward rules for verification
7. Phase 7: Pattern matching

## Testing Strategy

### Test Cases Needed:

1. **Basic record construction**:
```ocaml
type point = { x : int; y : int }
let p = { x = 10; y = 20 }
```

2. **Field access**:
```ocaml
let get_x p = p.x
```

3. **Field mutation**:
```ocaml
let move_right p = p.x <- p.x + 1
```

4. **Nested records**:
```ocaml
type rect = { top_left : point; bottom_right : point }
```

5. **Records with functions**:
```ocaml
type counter = { value : int ref; increment : unit -> unit }
```

### Benchmarks to Use:

- **D_async.ml**: Uses `{ suspended = Queue.create () }` (line 88)
- Check other benchmarks in `benchmarks/effects/ocaml412/` for record usage

## Dependencies and Constraints

### Files That Must Be Modified:
- `lib/hipcore/untyped_core_ast.ml` - Core AST (untyped)
- `lib/hipcore_typed/typed_core_ast.ml` - Core AST (typed)
- `lib/heifer-parsing/core_lang.ml` - OCaml frontend translation
- `lib/hipcore_typed/Pretty.ml` - Pretty printing

### Files That Should Be Modified:
- `lib/hipcore_typed/retypehip.ml` - Type inference
- `lib/hipprover/forward_rules.ml` - Verification rules
- `lib/hipcore_typed/patterns.ml` - Pattern matching

### Files to Examine:
- `lib/hipcore_typed/untypehip.ml` - May need updates for untyping
- `lib/hipcore_typed/subst.ml` - Substitution for record operations
- `lib/hipprover/` - Other verification files

## Open Questions

1. **Type name inference in CRecord**: How to determine the record type name from field names?
   - Option A: Thread type context through translation
   - Option B: Leave as placeholder, infer during typing phase
   - Option C: Require explicit type annotations

2. **Separation logic for records**: Should each field be a separate heap cell?
   - If yes: `r.f1 ↦ v1 * r.f2 ↦ v2`
   - If no: `r ↦ {f1: v1, f2: v2}` (single heap cell with structure)

3. **Immutable vs mutable records**:
   - OCaml supports both
   - Should CSetField only work on mutable fields?
   - How to track mutability?

4. **Record update syntax**: `{ r with field = value }`
   - Should this create a new record or mutate?
   - Needs separate construct or desugar to mutation?

5. **TypeScript translation**: Once OCaml records work, how to map TypeScript objects?
   - TypeScript objects are always mutable
   - May need different semantics than OCaml records

## Related Work

This plan was developed alongside:
- TypeScript-to-Heifer translation infrastructure
- Analysis of Heifer's verification workflow
- Investigation of how `ref` type uses record infrastructure

## References

- **Type system**: [lib/hipcore_common/types.ml](lib/hipcore_common/types.ml)
- **OCaml frontend**: [lib/heifer-parsing/core_lang.ml](lib/heifer-parsing/core_lang.ml)
- **Typed AST**: [lib/hipcore_typed/typed_core_ast.ml](lib/hipcore_typed/typed_core_ast.ml)
- **Untyped AST**: [lib/hipcore/untyped_core_ast.ml](lib/hipcore/untyped_core_ast.ml)
- **Example usage**: [benchmarks/effects/ocaml412/D_async.ml](benchmarks/effects/ocaml412/D_async.ml)

## Status

- **Analysis**: ✅ Complete (2026-01-03)
- **Planning**: ✅ Complete (2026-01-03)
- **Implementation**: ⏳ Not started
- **Testing**: ⏳ Not started
- **Documentation**: ✅ This document

---

*Last updated: 2026-01-03*
