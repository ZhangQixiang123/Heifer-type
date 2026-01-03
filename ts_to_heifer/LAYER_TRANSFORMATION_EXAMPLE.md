# Layer Transformation Example

This document shows how a simple TypeScript function transforms through each layer of the Heifer type system.

## Source Program

```typescript
// TypeScript source
let counter: number = 0;

function increment(): void {
  counter = counter + 1;
}
```

## Layer-by-Layer Transformation

### Input: TypeScript AST (JSON)

```json
{
  "kind": "SourceFile",
  "statements": [
    {
      "kind": "VariableStatement",
      "declarationList": {
        "kind": "VariableDeclarationList",
        "flags": 1,
        "declarations": [
          {
            "kind": "VariableDeclaration",
            "name": { "kind": "Identifier", "text": "counter" },
            "type": { "kind": "NumberKeyword" },
            "initializer": { "kind": "FirstLiteralToken", "value": 0 }
          }
        ]
      }
    },
    {
      "kind": "FunctionDeclaration",
      "name": { "kind": "Identifier", "text": "increment" },
      "parameters": [],
      "type": { "kind": "VoidKeyword" },
      "body": {
        "kind": "Block",
        "statements": [
          {
            "kind": "ExpressionStatement",
            "expression": {
              "kind": "BinaryExpression",
              "operator": "=",
              "left": { "kind": "Identifier", "text": "counter" },
              "right": {
                "kind": "BinaryExpression",
                "operator": "+",
                "left": { "kind": "Identifier", "text": "counter" },
                "right": { "kind": "FirstLiteralToken", "value": 1 }
              }
            }
          }
        ]
      }
    }
  ]
}
```

---

### Layer 1-2: Hiptypes (Untyped Core AST)

**Module**: `Hipcore.Hiptypes` (includes `Untyped_core_ast`)

**Built by**: `ts_to_heifer/lib/translator.ml`

#### OCaml AST Structure (Untyped)

```ocaml
(* Type definitions from untyped_core_ast.ml *)

(* The global variable declaration: let counter = ref 0 *)
CLet (
  "counter",                    (* variable name *)
  CRef (                        (* reference creation *)
    Const (Num 0)               (* initial value: term *)
  ),
  (* continuation: rest of program *)
  CLet (
    "increment",                (* function name *)
    (* Function body as lambda - simplified representation *)
    (* Actual structure is more complex, shown below *)
    CLambda (
      [],                       (* parameters: string list *)
      Some spec,                (* specification: staged_spec option *)
      (* function body: core_lang *)
      CSequence (
        CWrite (                (* assignment: counter := ... *)
          "counter",            (* variable to write *)
          BinOp (               (* value to write: term *)
            Plus,               (* operator *)
            CRead "counter",    (* read current value: term *)
            Const (Num 1)       (* add 1: term *)
          )
        ),
        CValue (Const ValUnit)  (* return () *)
      )
    ),
    CValue (Const ValUnit)      (* final continuation *)
  )
)

(* Where spec is: staged_spec *)
Sequence (
  (* Precondition: require *)
  Require (
    True,                       (* pi: pure assertion *)
    PointsTo (                  (* kappa: heap assertion *)
      "counter",                (* location *)
      Var "v_counter"           (* existential value variable *)
    )
  ),
  (* Postcondition: ensure *)
  NormalReturn (
    Colon ("res", Type UnitBty), (* res:() - pi *)
    PointsTo (                   (* kappa *)
      "counter",
      Var "v_counter'"          (* primed = modified *)
    )
  )
)
```

#### Type Definitions Used

```ocaml
(* From untyped_core_ast.ml *)

type term =
  | Const of const
  | Var of string
  | BinOp of bin_term_op * term * term
  | ...

type core_lang =
  | CValue of term
  | CLet of string * core_lang * core_lang
  | CSequence of core_lang * core_lang
  | CRef of term
  | CRead of string
  | CWrite of string * term
  | CLambda of string list * staged_spec option * core_lang
  | ...

type pi =
  | True
  | Colon of string * term
  | And of pi * pi
  | ...

type kappa =
  | EmptyHeap
  | PointsTo of string * term
  | SepConj of kappa * kappa

type staged_spec =
  | Require of pi * kappa
  | NormalReturn of pi * kappa
  | Sequence of staged_spec * staged_spec
  | ...
```

#### Key Observations - Layer 2

1. **No type annotations in constructors**:
   - `CLet ("counter", init, cont)` - just a string name
   - `Const (Num 0)` - no type attached to the constant
   - `Var "v_counter"` - variable is just a string

2. **Heap predicates at this level**:
   - `PointsTo ("counter", Var "v_counter")` is untyped
   - Describes heap at runtime, not static types

3. **Function body structure**:
   - Body is `core_lang` (untyped imperative code)
   - Parameters are `string list` (no types)
   - Spec is `staged_spec option` (untyped)

---

### Layer 3: Typed Core AST

**Module**: `Hipcore_typed.Typed_core_ast`

**Converted by**: `Hipcore_typed.Retypehip.retype_*`

#### OCaml AST Structure (Typed)

```ocaml
(* Type definitions from typed_core_ast.ml *)

(* The same program structure, but with type annotations *)
{
  core_desc = CLet (
    ("counter", TConstr ("ref", [TConstr ("int", [])])), (* binder with type *)
    {
      core_desc = CRef {
        term_desc = Const (Num 0);
        term_type = TConstr ("int", [])  (* type annotation added *)
      };
      core_type = TConstr ("ref", [TConstr ("int", [])])
    },
    (* continuation *)
    {
      core_desc = CLet (
        ("increment",                    (* function name with type *)
         TConstr ("arrow", [             (* function type *)
           TConstr ("unit", []);
           TConstr ("unit", [])
         ])),
        {
          core_desc = CLambda (
            [],                          (* parameters: binder list (empty) *)
            Some {
              (* Typed specification *)
              spec_desc = Sequence (
                Require (
                  True,
                  PointsTo (
                    "counter",
                    { term_desc = Var "v_counter";
                      term_type = TVar 42 }  (* type variable placeholder *)
                  )
                ),
                NormalReturn (
                  Colon ("res", {
                    term_desc = Type UnitBty;
                    term_type = TConstr ("type", [])
                  }),
                  PointsTo (
                    "counter",
                    { term_desc = Var "v_counter'";
                      term_type = TVar 42 }  (* same type variable *)
                  )
                )
              )
            },
            (* function body *)
            {
              core_desc = CSequence (
                {
                  core_desc = CWrite (
                    "counter",
                    {
                      term_desc = BinOp (
                        Plus,
                        { term_desc = CRead "counter";
                          term_type = TConstr ("int", []) },
                        { term_desc = Const (Num 1);
                          term_type = TConstr ("int", []) }
                      );
                      term_type = TConstr ("int", [])
                    }
                  );
                  core_type = TConstr ("unit", [])
                },
                {
                  core_desc = CValue {
                    term_desc = Const ValUnit;
                    term_type = TConstr ("unit", [])
                  };
                  core_type = TConstr ("unit", [])
                }
              );
              core_type = TConstr ("unit", [])
            }
          );
          core_type = TConstr ("arrow", [
            TConstr ("unit", []);
            TConstr ("unit", [])
          ])
        },
        {
          core_desc = CValue {
            term_desc = Const ValUnit;
            term_type = TConstr ("unit", [])
          };
          core_type = TConstr ("unit", [])
        }
      );
      core_type = TConstr ("unit", [])
    }
  );
  core_type = TConstr ("unit", [])
}
```

#### Type Definitions Used

```ocaml
(* From typed_core_ast.ml *)

type binder = string * typ  (* NOW includes type! *)

type term = {
  term_desc: term_desc;     (* same constructors as untyped *)
  term_type: typ            (* TYPE ANNOTATION ADDED *)
}

type core_lang = {
  core_desc: core_desc;     (* same constructors as untyped *)
  core_type: typ            (* TYPE ANNOTATION ADDED *)
}

(* term_desc and core_desc have same constructors as untyped layer,
   but now reference typed versions *)
```

#### Key Observations - Layer 3

1. **Records everywhere**:
   - Every `term` is now `{ term_desc; term_type }`
   - Every `core_lang` is now `{ core_desc; core_type }`

2. **Type variables as placeholders**:
   - `TVar 42` - fresh type variable, not yet solved
   - Created by `retype_*` functions
   - Will be unified in next layer

3. **Binders carry types**:
   - `("counter", TConstr ("ref", [...]))` instead of just `"counter"`
   - Parameters become `binder list` not `string list`

4. **Same structure, more annotations**:
   - All constructors are the same (`CLet`, `CRef`, etc.)
   - Just wrapped in records with type fields

---

### Layer 4: Type Inference

**Module**: `Hipprover.Infer_types`

**Process**: Constraint solving via unification

#### Type Constraint Generation

```ocaml
(* Type constraints generated during inference *)

(* From: counter = ref 0 *)
Constraint 1: typeof(0) = int
Constraint 2: typeof(ref 0) = ref(int)
Constraint 3: typeof(counter) = ref(int)

(* From: counter := counter + 1 *)
Constraint 4: typeof(!counter) = int       (* dereference *)
Constraint 5: typeof(1) = int
Constraint 6: typeof(!counter + 1) = int   (* + : int → int → int *)
Constraint 7: typeof(counter := ...) = ()  (* assignment returns unit *)

(* From: function increment() *)
Constraint 8: typeof(function body) = ()
Constraint 9: typeof(increment) = () → ()

(* From specification: counter->v_counter *)
Constraint 10: TVar 42 (v_counter) must unify with int
```

#### Unification Process

```ocaml
(* Type environment before unification *)
TEnv = {
  counter: TConstr ("ref", [TConstr ("int", [])]),
  increment: TConstr ("arrow", [TConstr ("unit", []); TConstr ("unit", [])]),
  v_counter: TVar 42,
  v_counter': TVar 42,
  ...
}

(* Unification steps *)
Step 1: TVar 42 ~ int           (* from counter dereference *)
        ⟹ TVar 42 := int

(* Type environment after unification *)
TEnv = {
  counter: TConstr ("ref", [TConstr ("int", [])]),
  increment: TConstr ("arrow", [TConstr ("unit", []); TConstr ("unit", [])]),
  v_counter: TConstr ("int", []),      (* RESOLVED *)
  v_counter': TConstr ("int", []),     (* RESOLVED *)
  ...
}
```

#### Fully Typed AST (after inference)

```ocaml
(* Now all TVar placeholders are replaced with concrete types *)
{
  core_desc = CLet (
    ("counter", TConstr ("ref", [TConstr ("int", [])])),
    {
      core_desc = CRef {
        term_desc = Const (Num 0);
        term_type = TConstr ("int", [])  (* concrete *)
      };
      core_type = TConstr ("ref", [TConstr ("int", [])])
    },
    {
      core_desc = CLet (
        ("increment", TConstr ("arrow", [
          TConstr ("unit", []); TConstr ("unit", [])
        ])),
        {
          core_desc = CLambda (
            [],
            Some {
              spec_desc = Sequence (
                Require (
                  True,
                  PointsTo ("counter", {
                    term_desc = Var "v_counter";
                    term_type = TConstr ("int", [])  (* RESOLVED from TVar 42 *)
                  })
                ),
                NormalReturn (
                  Colon ("res", {
                    term_desc = Type UnitBty;
                    term_type = TConstr ("type", [])
                  }),
                  PointsTo ("counter", {
                    term_desc = Var "v_counter'";
                    term_type = TConstr ("int", [])  (* RESOLVED *)
                  })
                )
              )
            },
            (* ... rest same but with concrete types ... *)
          );
          core_type = TConstr ("arrow", [
            TConstr ("unit", []); TConstr ("unit", [])
          ])
        },
        (* ... *)
      );
      core_type = TConstr ("unit", [])
    }
  );
  core_type = TConstr ("unit", [])
}
```

#### Key Observations - Layer 4

1. **All type variables resolved**:
   - `TVar 42` → `TConstr ("int", [])`
   - No more placeholders

2. **Type consistency verified**:
   - `!counter` has type `int`
   - `counter + 1` type checks as `int + int → int`
   - Assignment `counter := ...` type checks

3. **Specification types resolved**:
   - `v_counter` and `v_counter'` both have type `int`
   - Heap predicates are well-typed

---

### Layer 5: Verification

**Module**: `Hipprover.Entail`, `Hipprover.Forward_rules`

**Process**: Verify specifications using separation logic

#### Verification Conditions

For `increment()`, we must verify:

**Given precondition**: `counter→v_counter`
**After body execution**: `counter→v_counter'`
**Must prove**: Postcondition holds

```
Verification Goal:
  {counter→v_counter}
    counter := !counter + 1
  {counter→v_counter'}

Separation Logic Proof:
  1. Precondition: counter→v_counter     (heap: [counter ↦ v_counter])

  2. Read: let tmp = !counter
     Frame rule: counter→v_counter       (heap unchanged)
     Pure: tmp = v_counter

  3. Compute: tmp + 1
     Pure: result = v_counter + 1

  4. Write: counter := result
     Update heap: counter→(v_counter+1)  (heap: [counter ↦ v_counter+1])

  5. Postcondition: counter→v_counter'
     Match: v_counter' = v_counter + 1  ✓

Verification result: SUCCESS
```

#### Heap Evolution Trace

```
State 1 (Precondition):
  Pure: true
  Heap: counter→v_counter

State 2 (After !counter):
  Pure: tmp = v_counter
  Heap: counter→v_counter     (read doesn't modify heap)

State 3 (After tmp + 1):
  Pure: result = v_counter + 1
  Heap: counter→v_counter

State 4 (After counter := result):
  Pure: result = v_counter + 1
  Heap: counter→(v_counter + 1)  (heap updated!)

State 5 (Match postcondition):
  Pure: res = ()
  Heap: counter→v_counter'

  Matching: v_counter' ≡ v_counter + 1  ✓
```

---

### Output: Pretty-Printed Heifer Code

**Module**: `Hipcore_typed.Pretty`

```ocaml
let counter = ref 0 in
let increment = fun  (*@ req counter->v_counter; ens counter->v_counter'/\res:() @*) ->
  let tmp15 = let tmp14 = !counter in
  (tmp14 + 1) in
  counter := tmp15 in
()
```

**Specification breakdown**:
- `req counter->v_counter` - Requires heap cell `counter` with some value `v_counter`
- `ens counter->v_counter'` - Ensures heap cell `counter` with modified value `v_counter'`
- `/\ res:()` - And the result has type unit

---

## Transformation Summary Table

| Layer | Input | Key Types | Output | Purpose |
|-------|-------|-----------|--------|---------|
| **Input** | TypeScript source | - | JSON AST | Parsing |
| **Layer 2** | JSON AST | `Hiptypes.core_lang`<br>`term`, `pi`, `kappa` | Untyped AST | Structure |
| **Layer 3** | Untyped AST | `Typed_core_ast.term`<br>`{ term_desc; term_type }` | AST + type placeholders | Annotation |
| **Layer 4** | Typed AST (placeholders) | Type constraints<br>`TVar n` | Typed AST (concrete) | Inference |
| **Layer 5** | Typed AST + specs | Verification conditions<br>Heap states | Proof obligations | Verification |
| **Output** | Typed AST | - | Pretty-printed code | Display |

## Key Transformations by Function

### `retype_term : Hiptypes.term → Typed_core_ast.term`

```ocaml
(* Layer 2 → Layer 3 *)
Hiptypes.Var "x"
  ⟹
{ term_desc = Var "x";
  term_type = TVar (fresh()) }  (* type placeholder *)
```

### `infer_types_term : Typed_core_ast.term → Typed_core_ast.term`

```ocaml
(* Layer 3 → Layer 4 *)
{ term_desc = Var "x";
  term_type = TVar 42 }
  ⟹
{ term_desc = Var "x";
  term_type = TConstr ("int", []) }  (* type resolved *)
```

### `string_of_core_lang : Typed_core_ast.core_lang → string`

```ocaml
(* Layer 4 → Output *)
{ core_desc = CLet ("x", init, body);
  core_type = typ }
  ⟹
"let x = ... in ..."  (* Pretty-printed string *)
```

## Translator's Position in the Pipeline

```
┌─────────────────────────────────────────────────────┐
│ ts_to_heifer/lib/translator.ml                      │
│                                                     │
│ TypeScript JSON → constructs Layer 2 (Hiptypes)    │
│                                                     │
│ Key functions:                                      │
│ • translate_expr → Hiptypes.core_lang              │
│ • generate_spec_from_signature → Hiptypes.spec    │
│ • retype_staged_spec → Typed_core_ast.spec        │
│                                                     │
│ Produces: Hiptypes (Layer 2)                       │
│ Outputs via: Pretty (Layer 3 pretty printer)       │
└─────────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────────┐
│ Heifer Verification Pipeline                        │
│                                                     │
│ Layer 2 (Hiptypes) → Layer 3 (Typed) →             │
│ Layer 4 (Inferred) → Layer 5 (Verified)            │
└─────────────────────────────────────────────────────┘
```

## Conclusion

The layer architecture enables **separation of concerns**:

1. **Layer 2 (Hiptypes)**: What the program **does** - structure and semantics
2. **Layer 3 (Typed AST)**: What types the program **has** - type annotations
3. **Layer 4 (Inference)**: Are the types **consistent** - constraint solving
4. **Layer 5 (Verification)**: Does it **satisfy specs** - separation logic proofs

The translator only needs to work at **Layer 2**, building simple untyped constructors. The rest of the pipeline handles type checking and verification automatically.
