# Plan: Fix TypeScript Global Variable Translation for Verification

## Problem Statement

When verifying TypeScript functions that use global variables, the verification fails with:
```
error occurred: Failure("! must operate on ref type")
```

### Root Cause Analysis

1. **Translation Phase** (translator.ml:1003-1036):
   - Global variables ARE registered in the context during pre-pass
   - Functions correctly use `CRead globalCounter` (dereference `!globalCounter`)
   - BUT: `translate_program_to_intermediates` **skips** global variable declarations (line 1031-1033)

2. **Verification Phase** (verify.ml:47-108):
   - Only method intermediates are converted to `meth_def`
   - Program starts with `empty_program` (no globals)
   - Methods are verified incrementally against this empty program

3. **Type Inference** (forward_rules.ml:759-767):
   - When `CRead x` is encountered, it looks up `x` in the state
   - Calls `return_ref_value` which expects `x` to have type `Ref<α>`
   - Fails because `globalCounter` is not in the program's type environment

## Solution Approach

### Option 1: Include Global Variables as Methods (Simpler)
Wrap global variable initialization as zero-parameter functions that return the ref.

**Pros:**
- Minimal changes to existing code
- Reuses existing `Meth` intermediate type
- Works with current verify.ml structure

**Cons:**
- Semantically inaccurate (globals aren't methods)
- May cause issues with scoping/visibility

### Option 2: Add Global Variables to Program Context (Correct) ⭐ **RECOMMENDED**

Add global variables directly to the program's type environment before verification.

**Approach:**
1. Create a new intermediate type for global variables
2. Emit global variable intermediates from translator
3. Update verify.ml to process globals and add them to the program

**Pros:**
- Semantically correct
- Matches how OCaml frontend handles globals
- Provides proper type information to verifier

**Cons:**
- Requires changes in multiple places
- Need to understand `core_program` structure better

### Option 3: Pre-populate Empty Program (Quick Fix)

Modify verify.ml to extract global variables from method specs and add them to the initial program.

**Pros:**
- Only changes verify.ml
- Quick to implement

**Cons:**
- Fragile - depends on parsing specs
- Doesn't solve the fundamental issue

## Recommended Solution: Option 2

### Implementation Plan

#### Step 1: Extend Intermediate Type

**File:** `lib/hipcore_common/data.ml` (if allowed) OR work around it in translator

Since we cannot modify core Heifer files, we'll use a workaround:
- Use polymorphic variants in translator.ml
- Add `GlobalVar` variant to the intermediate list

#### Step 2: Update Translator to Emit Global Variables

**File:** `ts_to_heifer/lib/translator.ml`

Lines 1003-1036: `translate_program_to_intermediates`

Changes:
```ocaml
(* Current - line 1031-1033 *)
| "VariableStatement" ->
    (* Skip variable statements in output *)
    None

(* NEW - emit global variables as intermediates *)
| "VariableStatement" | "FirstStatement" ->
    let variance = variance_from_ts_declaration stmt in
    let declarations = stmt |> member "declarationList" |> member "declarations" |> to_list in
    (* For each mutable global, create a GlobalVar intermediate *)
    List.filter_map (fun decl ->
      if variance = Mutable then
        let name = decl |> member "name" |> get_identifier in
        let typ = get_type ctx name in
        let init_opt = try Some (decl |> member "initializer") with _ -> None in
        let init_value = match init_opt with
          | Some json -> translate_term ctx json
          | None -> { term_desc = Const (Num 0); term_type = typ }
        in
        Some (`GlobalVar (name, typ, init_value))
      else
        None
    ) declarations |> (function [] -> None | lst -> Some lst)
```

#### Step 3: Update verify.ml to Handle Global Variables

**File:** `ts_to_heifer/bin/verify.ml`

Changes needed:

1. **Add global variable handling function:**
```ocaml
(** Convert global variable intermediate to a let-binding *)
let process_global_var (name, typ, init_value) prog =
  (* For now, we just need to register the variable in the program's context *)
  (* The actual implementation depends on how Heifer tracks global state *)
  (* We may need to add it to a global context that methods can reference *)
  prog  (* TODO: implement proper global registration *)
```

2. **Separate globals from methods:**
```ocaml
let intermediates = translate_program_to_intermediates json in

(* Separate globals from methods *)
let globals, methods_intermediate = List.partition (function
  | `GlobalVar _ -> true
  | `Meth _ -> false
) intermediates in

(* Initialize program with globals *)
let prog_ref = ref empty_program in
List.iter (fun (`GlobalVar (name, typ, init)) ->
  (* Register global in program context *)
  (* This is the key fix - globals must be in the program before methods are verified *)
  prog_ref := process_global_var (name, typ, init) !prog_ref
) globals;

(* Now verify methods *)
let methods = List.map to_meth_def methods_intermediate in
```

#### Step 4: Alternative if core_program Cannot Store Globals

If we cannot modify how `core_program` works, we need a different approach:

**Wrap globals in method bodies:**

For each method that uses globals, prepend the global declarations to its body:
```ocaml
let getCounter() =
  let globalCounter = ref 0 in  (* prepend *)
  !globalCounter                  (* original body *)
```

This approach:
- Transforms each method to be self-contained
- No need to modify core_program
- But changes semantics (each call gets fresh globals)

## Key Files to Modify

1. **ts_to_heifer/lib/translator.ml** (lines 1003-1036)
   - Emit global variable intermediates instead of skipping them

2. **ts_to_heifer/bin/verify.ml** (lines 40-52)
   - Process global variables before verifying methods
   - Add globals to program context

## Testing Strategy

1. Test with `11_impure_functions.json`
2. Verify that:
   - Global variables are properly extracted
   - Methods can reference globals
   - Type inference succeeds for `CRead` operations
   - Verification completes without "! must operate on ref type" error

## Open Questions

1. **How does `core_program` track global variables?**
   - Need to check if there's a field for globals
   - Or if they're implicit in method contexts

2. **Should globals be existentially quantified in specs?**
   - OCaml examples use `ex i. ens i->value`
   - Do we need to modify generated specs?

3. **Scope of globals across multiple methods?**
   - Should all methods share same global instances?
   - Or should each get fresh bindings?

## Next Steps

1. Investigate `core_program` structure to understand global storage
2. Implement Option 2 if feasible
3. Fall back to Option 4 (method body wrapping) if core modifications required
4. Test with impure functions example
5. Validate verification passes
