# Automatic Specification Generation from TypeScript Types

## Goal

**Generate Heifer verification specifications automatically from TypeScript type annotations**, eliminating the need for manual JSDoc annotations while still enabling formal verification.

## Philosophy

TypeScript's type system already encodes important invariants:
- Parameter types → preconditions
- Return types → postconditions
- Nullable types → null checks
- Union types → case analysis
- Literal types → exact values
- Type guards → refinements

**Our approach:** Extract these implicit contracts and translate them into explicit Heifer `staged_spec` annotations.

---

## What TypeScript Types Tell Us

### 1. **Function Signatures → Pre/Postconditions**

**TypeScript:**
```typescript
function add(x: number, y: number): number {
  return x + y;
}
```

**Implicit Contract:**
- Requires: `x` is a number, `y` is a number
- Ensures: result is a number

**Generated Heifer Spec:**
```ocaml
let add x y = (x + y)
 (*@ req x:#int /\ y:#int ; ens res:#int @*)
```

### 2. **Nullable Types → Null Safety**

**TypeScript:**
```typescript
function getLength(s: string | null): number {
  if (s !== null) {
    return s.length;
  }
  return 0;
}
```

**Implicit Contract:**
- Requires: `s` is string or null
- Ensures: if `s` is not null, result equals `s.length`; else result is 0

**Generated Heifer Spec:**
```ocaml
let getLength s =
  if (s <> null) then
    string_length s
  else
    0
 (*@ req s:(#string | #unit) ;
     ens (s <> #unit => res:#int /\ res = |s|) /\
         (s = #unit => res:#int /\ res = 0) @*)
```

### 3. **Literal Types → Exact Values**

**TypeScript:**
```typescript
function getStatus(): "success" | "error" {
  return "success";
}
```

**Generated Heifer Spec:**
```ocaml
let getStatus () = "success"
 (*@ req emp ; ens res:(#string /\ (res = "success" \/ res = "error")) @*)
```

### 4. **Type Guards → Refinement Types**

**TypeScript:**
```typescript
function process(x: unknown): number {
  if (typeof x === "number") {
    return x + 1;
  }
  return 0;
}
```

**Generated Heifer Spec:**
```ocaml
let process x =
  if (typeof x = "number") then
    (x + 1)
  else
    0
 (*@ req x:#any ;
     ens (typeof(x) = "number" => res:#int /\ res = x + 1) /\
         (typeof(x) <> "number" => res:#int /\ res = 0) @*)
```

### 5. **Object Types → Heap Structure**

**TypeScript:**
```typescript
interface Point {
  x: number;
  y: number;
}

function moveX(p: Point, dx: number): void {
  p.x = p.x + dx;
}
```

**Generated Heifer Spec:**
```ocaml
type point = { x: int ref; y: int ref }

let moveX p dx =
  p.x := (!p.x + dx)
 (*@ req p:(#point /\ p.x |-> x0 /\ p.y |-> y0) /\ dx:#int ;
     ens p.x |-> (x0 + dx) * p.y |-> y0 @*)
```

**Key insight:** Object fields become heap locations with separation logic!

### 6. **Array Types → List Structures**

**TypeScript:**
```typescript
function sum(arr: number[]): number {
  let total = 0;
  for (let i = 0; i < arr.length; i++) {
    total += arr[i];
  }
  return total;
}
```

**Generated Heifer Spec:**
```ocaml
let rec sum arr =
  match arr with
  | [] -> 0
  | x :: xs -> x + sum xs
 (*@ req arr:#list<int> ;
     ens res:#int /\ res = sum(arr) @*)
```

### 7. **Union Types → Disjunction**

**TypeScript:**
```typescript
function stringify(x: number | string): string {
  if (typeof x === "number") {
    return x.toString();
  }
  return x;
}
```

**Generated Heifer Spec:**
```ocaml
let stringify x =
  if (typeof x = "number") then
    int_to_string x
  else
    x
 (*@ req x:(#int | #string) ;
     ens (x:#int => res:#string /\ res = to_string(x)) /\
         (x:#string => res:#string /\ res = x) @*)
```

---

## Specification Generation Strategy

### Phase 1: Type Extraction (Already in TypeScript AST)

For each function, extract:
```typescript
interface FunctionSignature {
  name: string;
  parameters: Array<{name: string, type: TypeNode}>;
  returnType: TypeNode;
  body: Statement[];
}
```

### Phase 2: Precondition Generation

**Algorithm:**
```ocaml
let generate_precondition (params: parameter list) : pi =
  let type_constraints = params |> List.map (fun p ->
    match p.ts_type with
    | NumberType -> Atomic (HasType, Var p.name, TyInt)
    | StringType -> Atomic (HasType, Var p.name, TyString)
    | BooleanType -> Atomic (HasType, Var p.name, TyBool)
    | UnionType types ->
        Or (List.map (fun t -> type_to_formula p.name t) types)
    | ObjectType fields ->
        And [
          Atomic (HasType, Var p.name, object_type fields);
          heap_structure fields p.name
        ]
    | _ -> True
  ) in
  And type_constraints
```

### Phase 3: Postcondition Generation

**Strategy:**
1. **Simple cases:** Return type → result type constraint
2. **Conditional returns:** Analyze control flow paths
3. **Mutations:** Track heap changes using separation logic

**Algorithm:**
```ocaml
let rec generate_postcondition
    (return_type: typ)
    (body: statement list)
    (params: parameter list) : pi * kappa =

  match analyze_return_paths body with
  | SingleReturn expr ->
      (* Simple case: one return path *)
      let type_constraint = Atomic (HasType, Var "res", return_type) in
      let value_constraint = generate_value_constraint expr params in
      (And [type_constraint; value_constraint], EmptyHeap)

  | ConditionalReturns branches ->
      (* Multiple return paths: generate disjunction *)
      let branch_specs = branches |> List.map (fun (condition, return_expr) ->
        Implies (condition,
          And [
            Atomic (HasType, Var "res", return_type);
            Atomic (EQ, Var "res", return_expr)
          ]
        )
      ) in
      (Or branch_specs, EmptyHeap)

  | WithMutations (returns, mutations) ->
      (* Heap mutations: use separation logic *)
      let type_constraint = Atomic (HasType, Var "res", return_type) in
      let heap_spec = generate_heap_postcondition mutations params in
      (type_constraint, heap_spec)
```

### Phase 4: Heap Formula Generation

For object field mutations:

```ocaml
let generate_heap_postcondition (mutations: mutation list) (params: parameter list) : kappa =
  (* Find all heap locations *)
  let locations = analyze_heap_locations params mutations in

  (* Generate initial heap formula (precondition) *)
  let pre_heap = locations |> List.map (fun loc ->
    PointsTo (loc.path, fresh_var (loc.name ^ "0"))
  ) |> sep_conj in

  (* Generate final heap formula (postcondition) *)
  let post_heap = locations |> List.map (fun loc ->
    match find_final_value loc mutations with
    | Some new_value -> PointsTo (loc.path, new_value)
    | None -> PointsTo (loc.path, Var (loc.name ^ "0"))  (* Unchanged *)
  ) |> sep_conj in

  post_heap
```

---

## Implementation Roadmap

### Step 1: Extend Translator with Spec Generator

**New Module:** `lib/spec_generator.ml`

```ocaml
module Spec_generator = struct
  open Hipcore_typed.Typed_core_ast
  open Hipcore_common.Types

  (* Extract function signature from TypeScript AST *)
  val extract_signature : Yojson.Basic.t -> function_signature

  (* Generate precondition from parameter types *)
  val generate_precondition : parameter list -> pi

  (* Generate postcondition from return type and body *)
  val generate_postcondition : typ -> statement list -> parameter list -> pi * kappa

  (* Combine into staged_spec *)
  val generate_spec : function_signature -> staged_spec option
end
```

### Step 2: Enhance AST Analysis

**Add to `lib/translator.ml`:**

```ocaml
(* Analyze control flow to find return paths *)
type return_path =
  | SingleReturn of term
  | ConditionalReturns of (pi * term) list
  | WithMutations of return_path * mutation list

val analyze_return_paths : statement list -> return_path

(* Track mutations within function body *)
type mutation = {
  target: string;        (* Variable or field path *)
  new_value: term;       (* Assigned value *)
  condition: pi option;  (* Under what condition? *)
}

val collect_mutations : statement list -> mutation list
```

### Step 3: Type System Mapping

**Complete TypeScript → Heifer type mapping:**

```ocaml
let rec ts_type_to_heifer_type (ts_type: ts_type_node) : typ =
  match ts_type with
  | TsNumber -> TyInt
  | TsString -> TyString
  | TsBoolean -> TyBool
  | TsNull | TsUndefined -> TyUnit
  | TsUnion types ->
      TyUnion (List.map ts_type_to_heifer_type types)
  | TsObject fields ->
      TyRecord (List.map (fun f ->
        (f.name, TyRef (ts_type_to_heifer_type f.type))
      ) fields)
  | TsArray elem_type ->
      TyList (ts_type_to_heifer_type elem_type)
  | TsFunction (params, return_type) ->
      TyArrow (
        List.map (fun p -> ts_type_to_heifer_type p.type) params,
        ts_type_to_heifer_type return_type
      )
  | TsLiteral value ->
      TySingleton value  (* Exact value type *)
  | TsAny -> TyAny
  | _ -> failwith "Unsupported TypeScript type"
```

### Step 4: Integration with Translation Pipeline

**Modified function translation:**

```ocaml
let translate_function (json: Yojson.Basic.t) env : declaration =
  let signature = Spec_generator.extract_signature json in

  (* Generate specification automatically *)
  let auto_spec = Spec_generator.generate_spec signature in

  (* Translate body *)
  let params = translate_parameters signature.parameters in
  let body = translate_statements signature.body env in

  (* Create Heifer method with auto-generated spec *)
  Meth (
    signature.name,
    params,
    auto_spec,  (* ← Automatically generated! *)
    body,
    [],
    None
  )
```

---

## Examples: Before & After

### Example 1: Simple Arithmetic

**TypeScript:**
```typescript
function add(x: number, y: number): number {
  return x + y;
}
```

**Generated Heifer (with auto-spec):**
```ocaml
let add x y = (x + y)
 (*@ req x:#int /\ y:#int ;
     ens res:#int /\ res = (x + y) @*)
```

### Example 2: Nullable Handling

**TypeScript:**
```typescript
function safeDivide(a: number, b: number | null): number {
  if (b !== null && b !== 0) {
    return a / b;
  }
  return 0;
}
```

**Generated Heifer:**
```ocaml
let safeDivide a b =
  if (b <> null && b <> 0) then
    a / b
  else
    0
 (*@ req a:#int /\ b:(#int | #unit) ;
     ens (b <> #unit /\ b <> 0 => res:#int /\ res = a / b) /\
         (b = #unit \/ b = 0 => res:#int /\ res = 0) @*)
```

### Example 3: Object Mutation

**TypeScript:**
```typescript
interface Counter {
  count: number;
}

function increment(c: Counter): void {
  c.count = c.count + 1;
}
```

**Generated Heifer:**
```ocaml
type counter = { count: int ref }

let increment c =
  c.count := (!c.count + 1)
 (*@ req c:#counter /\ c.count |-> n ;
     ens c.count |-> (n + 1) @*)
```

### Example 4: Array Processing

**TypeScript:**
```typescript
function firstOrDefault(arr: number[], defaultValue: number): number {
  if (arr.length > 0) {
    return arr[0];
  }
  return defaultValue;
}
```

**Generated Heifer:**
```ocaml
let firstOrDefault arr defaultValue =
  match arr with
  | [] -> defaultValue
  | x :: _ -> x
 (*@ req arr:#list<int> /\ defaultValue:#int ;
     ens (arr = [] => res:#int /\ res = defaultValue) /\
         (arr <> [] => res:#int /\ res = hd(arr)) @*)
```

### Example 5: Union Type Discrimination

**TypeScript:**
```typescript
type Result = { ok: true; value: number } | { ok: false; error: string };

function getValue(r: Result): number {
  if (r.ok) {
    return r.value;
  }
  return -1;
}
```

**Generated Heifer:**
```ocaml
type result =
  | Ok of int
  | Error of string

let getValue r =
  match r with
  | Ok value -> value
  | Error _ -> -1
 (*@ req r:#result ;
     ens (r:Ok(n) => res:#int /\ res = n) /\
         (r:Error(_) => res:#int /\ res = -1) @*)
```

---

## Advanced Features

### 1. Variance-Aware Specifications

**TypeScript:**
```typescript
function swap(x: number, y: number): void {
  const temp = x;
  x = y;
  y = temp;
}
```

**Challenge:** Parameters are immutable in Heifer!

**Solution:** Detect parameter mutation and create local refs:

```ocaml
let swap x_param y_param =
  let x = ref x_param in
  let y = ref y_param in
  let temp = !x in
  x := !y;
  y := temp
 (*@ req x_param:#int /\ y_param:#int /\ x_param.acc:%I /\ y_param.acc:%I ;
     ens emp  (* No visible effect - parameters are immutable *) @*)
```

**Better:** Detect this pattern and warn or transform to return tuple:
```typescript
function swap(x: number, y: number): [number, number] {
  return [y, x];
}
```

### 2. Invariant Generation for Loops

**TypeScript:**
```typescript
function sumToN(n: number): number {
  let sum = 0;
  for (let i = 0; i <= n; i++) {
    sum += i;
  }
  return sum;
}
```

**Generated Heifer with Loop Invariant:**
```ocaml
let sumToN n =
  let rec loop sum i =
    if i <= n then
      loop (sum + i) (i + 1)
    else
      sum
   (*@ inv sum:#int /\ i:#int /\ 0 <= i <= n+1 /\ sum = Σ[0..i) ;
       variant n - i @*)
  in
  loop 0 0
 (*@ req n:#int /\ n >= 0 ;
     ens res:#int /\ res = Σ[0..n+1) @*)
```

**Invariant inference:**
- Sum accumulator: `sum = Σ[0..i)`
- Loop counter: `0 <= i <= n+1`
- Termination: `n - i` decreases

### 3. Refinement Types from Assertions

**TypeScript:**
```typescript
function divide(a: number, b: number): number {
  if (b === 0) {
    throw new Error("Division by zero");
  }
  return a / b;
}
```

**Generated Heifer:**
```ocaml
let divide a b =
  if (b = 0) then
    perform (Exception "Division by zero")
  else
    a / b
 (*@ req a:#int /\ b:#int ;
     ens (b <> 0 => res:#int /\ res = a / b) /\
         (b = 0 => raises Exception) @*)
```

---

## Getting Started

### Step 1: Add Spec Generator Module

Create `ts_to_heifer/lib/spec_generator.ml`:

```ocaml
open Hipcore_typed.Typed_core_ast
open Hipcore_common.Types

type parameter = {
  name: string;
  ts_type: Yojson.Basic.t;
  heifer_type: typ;
}

type function_signature = {
  name: string;
  parameters: parameter list;
  return_type: typ;
  body: Yojson.Basic.t;
}

(* Extract function signature from TypeScript AST JSON *)
let extract_signature (json: Yojson.Basic.t) : function_signature =
  let open Yojson.Basic.Util in
  let name = json |> member "name" |> member "text" |> to_string in
  let params_json = json |> member "parameters" |> to_list in

  let parameters = params_json |> List.map (fun p ->
    let param_name = p |> member "name" |> member "text" |> to_string in
    let param_type = p |> member "type" in
    {
      name = param_name;
      ts_type = param_type;
      heifer_type = Translator.ts_type_to_heifer param_type;
    }
  ) in

  let return_json = json |> member "type" in
  let return_type = Translator.ts_type_to_heifer return_json in

  let body = json |> member "body" in

  { name; parameters; return_type; body }

(* Generate precondition: parameter type constraints *)
let generate_precondition (params: parameter list) : pi =
  match params with
  | [] -> True
  | _ ->
      let constraints = params |> List.map (fun p ->
        Atomic (HasType (Var p.name, p.heifer_type))
      ) in
      and_list constraints

(* Generate postcondition: return type constraint *)
let generate_postcondition (return_type: typ) (body: Yojson.Basic.t) : pi =
  (* For now, just type constraint - will enhance with value constraints *)
  Atomic (HasType (Var "res", return_type))

(* Combine into staged_spec *)
let generate_spec (sig: function_signature) : staged_spec option =
  let pre_pi = generate_precondition sig.parameters in
  let post_pi = generate_postcondition sig.return_type sig.body in

  Some (Sequence (
    Require (pre_pi, EmptyHeap),
    NormalReturn (post_pi, EmptyHeap)
  ))
```

### Step 2: Update `dune` file

Edit `ts_to_heifer/lib/dune`:
```lisp
(library
 (name ts_to_heifer)
 (modules translator spec_generator)
 (libraries yojson hipcore_common hipcore_typed))
```

### Step 3: Integrate with Translator

Modify `ts_to_heifer/lib/translator.ml` to call spec generator:

```ocaml
let translate_function_declaration json env =
  let signature = Spec_generator.extract_signature json in
  let auto_spec = Spec_generator.generate_spec signature in

  (* Rest of translation... *)
  Meth (signature.name, params, auto_spec, body, [], None)
```

### Step 4: Test

Create `ts_to_heifer/examples/auto_spec.ts`:
```typescript
function add(x: number, y: number): number {
  return x + y;
}

function safeDivide(a: number, b: number | null): number {
  if (b !== null && b !== 0) {
    return a / b;
  }
  return 0;
}
```

Run:
```bash
cd ts_to_heifer
./translate.sh examples/auto_spec.ts
```

Expected output:
```ocaml
let add x y = (x + y)
 (*@ req x:#int /\ y:#int ; ens res:#int @*)

let safeDivide a b =
  if (b <> null && b <> 0) then
    a / b
  else
    0
 (*@ req a:#int /\ b:(#int | #unit) ;
     ens res:#int @*)
```

---

## Roadmap

### Phase 1: Basic Type Constraints ✅ (Start Here)
- [x] Document specification generation approach
- [ ] Extract parameter types → preconditions
- [ ] Extract return types → postconditions
- [ ] Generate simple `staged_spec` with `Require`/`NormalReturn`

### Phase 2: Value Constraints
- [ ] Analyze return expressions for exact values
- [ ] Handle conditional returns (if/else branches)
- [ ] Generate implications (condition ⇒ result)

### Phase 3: Heap Formulas
- [ ] Track object mutations
- [ ] Generate `PointsTo` formulas
- [ ] Use separation logic (`*`) for disjoint fields

### Phase 4: Advanced Features
- [ ] Loop invariant inference
- [ ] Nullable type handling
- [ ] Union type discrimination
- [ ] Array specifications

### Phase 5: Optimization
- [ ] Simplify generated formulas
- [ ] Eliminate redundant constraints
- [ ] Pretty-print specifications

---

## Summary

**Key Innovation:** Use TypeScript's type system as a specification language!

**Benefits:**
1. **No manual annotations needed** - types are already there
2. **Type safety for free** - TypeScript checks types, we verify behavior
3. **Gradual enhancement** - start with types, add JSDoc for complex invariants
4. **Better ergonomics** - developers write TypeScript, get verification

**Next Steps:**
1. Implement `spec_generator.ml` (Phase 1)
2. Test with simple functions
3. Gradually add more sophisticated analysis
4. Eventually support JSDoc for user-provided specifications

This bridges the gap between **type-level reasoning** (TypeScript) and **value-level verification** (Heifer)!
