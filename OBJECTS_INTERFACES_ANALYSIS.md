# Objects, Interfaces, and Typeclasses for Heifer

Date: 2026-01-04

## Executive Summary

This document analyzes three related OOP/polymorphism features and their implementation paths for the Heifer verification system:

1. **Objects with Methods** - Heap-allocated records containing both data fields and function fields
2. **Interfaces** - Type constraints for structural subtyping with method dispatch
3. **Typeclasses** - Ad-hoc polymorphism with dictionary-passing or monomorphization

**Key Finding**: For TypeScript verification, **structural records with function fields** are sufficient for most use cases. True nominal interfaces and typeclasses add significant complexity for marginal benefit in the verification context.

---

## Current State Analysis

### What Already Exists

#### 1. Heap-Based Records (JUST IMPLEMENTED)
**Status**: ✅ **COMPLETE** (as of 2026-01-04)

**Capabilities**:
- Record allocation: `CRecord of (string * core_lang) list`
- Field access: `CGetField of core_lang * string`
- Field mutation: `CSetField of core_lang * string * core_lang`
- Heap predicate: `RecordPointsTo of string * (string * term) list`
- Term-level records: `TRecordTerm of (string * term) list`
- Field projection in specs: `TGetField of term * string`

**Example verified code**:
```typescript
function makePoint(x: number, y: number) {
  return { x: x, y: y };
}
// Inferred spec: ∃rec. (ens rec->{x: x; y: y} ∧ res=rec)

function getX(p: Point): number {
  return p.x;
}
// Inferred spec: let rec = (ens res=p) in (ens res=rec.x)
```

#### 2. Type System Support
**File**: [lib/hipcore_common/types.ml](lib/hipcore_common/types.ml)

**Current types**:
```ocaml
type typ =
  | Any | Unit | Int | Bool | TyString | Lamb
  | Arrow of typ * typ
  | TConstr of string * typ list
  | TRecord of (string * typ) list  (* Structural record types *)
  | TVar of string
```

**Key observations**:
- `TRecord` is **structural** (duck-typed by field names/types)
- No nominal types (beyond `TConstr` for ADTs)
- No subtyping relation
- No trait/interface/typeclass mechanism

#### 3. Algebraic Data Types (ADTs)
**Status**: ✅ Fully supported

**Type declarations**:
```ocaml
type type_decl_kind =
  | Tdecl_inductive of type_constructor list  (* Sum types/variants *)
  | Tdecl_record of record_field list          (* Product types/records *)
```

**Example - list type**:
```ocaml
Tdecl_inductive [
  ("::", [TVar "a"; TConstr ("list", [TVar "a"])]);
  ("[]", [])
]
```

**Usage**:
- Pattern matching on variants (in `CMatch`)
- Constructor application: `Construct of string * term list`
- Type-driven dispatch based on constructor

#### 4. Lambda/Function Support
**Current capabilities**:
- First-class functions: `Lamb` type
- Function arrows: `Arrow of typ * typ`
- Lambda terms: `TLambda of string * binder list * staged_spec option * core_lang option`
- Lambda expressions: `CLambda of binder list * staged_spec option * core_lang`
- Higher-order specs: `HigherOrder of string * term list`

**Verification**:
- Can verify higher-order functions
- Supports lambda obligations for verifying function-passing code
- Predicates can take function arguments

---

## Design Space Analysis

### Option 1: Objects as Records with Function Fields

**Concept**: Represent objects as heap-allocated records where some fields are functions.

#### Implementation

**Type representation**:
```ocaml
(* A drawable object *)
TRecord [
  ("x", Int);
  ("y", Int);
  ("draw", Arrow (Unit, Unit));
  ("move", Arrow (Int, Arrow (Int, Unit)))
]
```

**Heap representation**:
```
RecordPointsTo(obj, {
  x: 10,
  y: 20,
  draw: λ(). console.log(...),
  move: λdx. λdy. ...
})
```

**Method call**:
```typescript
obj.draw();
```

**Translation**:
```ocaml
(* Get the draw method *)
let draw_fn = CGetField(obj, "draw") in
(* Call it *)
CFunCall(draw_fn, [])
```

**But wait - problem!** `CFunCall` takes a **string** (function name), not a term.

**Solution**: Add new construct `CApply` for first-class function application:
```ocaml
| CApply of core_lang * core_value list  (* Apply function value to arguments *)
```

#### Advantages
✅ Minimal new machinery - builds on existing records
✅ Structural typing works naturally
✅ No vtable/dispatch complexity
✅ Field names preserved for verification
✅ Matches TypeScript's object model closely

#### Disadvantages
❌ No nominal interfaces (can't distinguish "Shape with draw()" from "Widget with draw()")
❌ No subtyping (can't pass `Circle` where `Drawable` expected)
❌ Every object carries full method implementations (no code sharing)
❌ Method updates via field mutation (unusual semantics)

#### Verification Challenges

**Specifications for method calls**:
```
// TypeScript
function render(shape: Drawable): void {
  shape.draw();
}
```

**Verification question**: What's the spec for `draw()`?

**Approach 1: Require specification in field type**
```ocaml
TRecord [
  ("draw", Arrow (Unit, Unit) with spec "req emp ens emp")
]
```
**Problem**: Need to extend type system with refinement types.

**Approach 2: Higher-order specification**
```
req RecordPointsTo(shape, {draw: f, ...}) ∧ draw_spec(f)
ens emp
```
Where `draw_spec` is a predicate:
```
pred draw_spec(f) := f$() ⊨ req emp ens emp
```

**Approach 3: Existential specification (pessimistic)**
```
req RecordPointsTo(shape, {draw: f, ...})
ens ∃h. h  (* Unknown postcondition - assume arbitrary effects *)
```

---

### Option 2: Nominal Interfaces with Vtables

**Concept**: Add explicit interface types with dynamic dispatch through vtables.

#### Type System Extension

**New type constructor**:
```ocaml
type typ =
  | ...
  | Interface of string  (* Nominal interface type *)
  | InstanceOf of typ * string  (* value : type implements interface *)
```

**Interface declaration**:
```ocaml
type interface_decl = {
  iface_name: string;
  iface_methods: (string * typ) list;  (* method_name -> function_type *)
}
```

**Example**:
```ocaml
{
  iface_name = "Drawable";
  iface_methods = [
    ("draw", Arrow (Unit, Unit));
    ("move", Arrow (Int, Arrow (Int, Unit)))
  ]
}
```

#### Runtime Representation

**Vtable approach** (like C++/Java):
```
Object layout:
[ vtable_ptr | field1 | field2 | ... ]

Vtable for Circle:
{
  draw: circle_draw_impl,
  move: circle_move_impl
}
```

**Dictionary passing** (like Haskell typeclasses):
```ocaml
(* Explicitly pass method dictionary *)
type drawable_dict = {
  draw: 'a -> unit;
  move: 'a -> int -> int -> unit
}

let render (dict: drawable_dict) (obj: 'a) : unit =
  dict.draw obj
```

#### Implementation Complexity

**New AST constructs needed**:
```ocaml
(* Interface implementation *)
| CImplements of string * string * (string * core_lang) list
  (* type_name implements interface_name with method_impls *)

(* Virtual method call *)
| CVirtCall of core_value * string * string * core_value list
  (* object.method_name via interface_name with args *)
```

**Type checking**:
- Maintain interface -> method signatures mapping
- Check that implementing types provide all methods
- Subtyping: `Circle <: Drawable` if Circle implements Drawable

**Verification**:
- Each interface method needs a specification
- Implementations must satisfy interface spec
- Virtual calls use interface spec (not implementation spec)

#### Advantages
✅ Nominal typing (can distinguish different interfaces)
✅ Subtyping support
✅ Code reuse (shared vtable across instances)
✅ Matches Java/C# model

#### Disadvantages
❌ Much more complex than structural typing
❌ Requires vtable allocation/management
❌ Verification complexity (modular specs per interface)
❌ Doesn't match TypeScript's structural model well

---

### Option 3: Typeclasses (Ad-hoc Polymorphism)

**Concept**: Like Haskell/Rust traits - polymorphic functions with instance resolution.

#### Type System Extension

**Typeclass declaration**:
```ocaml
typeclass Drawable a where
  draw : a -> unit
  move : a -> int -> int -> unit
```

**In Heifer syntax**:
```ocaml
type typeclass_decl = {
  tc_name: string;
  tc_param: typ;
  tc_methods: (string * typ) list
}
```

**Instance declaration**:
```ocaml
instance Drawable Circle where
  draw c = ...
  move c dx dy = ...
```

**Polymorphic function**:
```ocaml
let render (type a) (drawable_a : Drawable a) (obj : a) : unit =
  drawable_a.draw obj
```

#### Implementation Strategies

**Strategy 1: Dictionary Passing**
- Compile typeclass constraint to explicit dictionary parameter
- `render : forall a. Drawable a => a -> unit` becomes
  `render : forall a. drawable_dict<a> -> a -> unit`

**Strategy 2: Monomorphization**
- Generate separate code for each instance
- `render<Circle>`, `render<Square>`, etc.
- No runtime overhead, but code size increase

#### Heifer Integration

**Problem**: Heifer is **unityped** in the core language - no parametric polymorphism.

**Current situation**:
- Type variables exist in specs (`TVar`)
- But core_lang has concrete types
- Typechecking happens via OCaml's type system (external)

**To add typeclasses**:
```ocaml
(* Add to typ *)
| TClassConstraint of string * typ  (* Drawable a *)

(* Add to core_lang *)
| CDict of string * typ  (* Get dictionary for typeclass instance *)
| CDictCall of core_value * string * core_value list
  (* Call method on dictionary *)
```

**Verification challenges**:
- Specifications must be polymorphic over typeclass constraints
- Each instance must prove it satisfies the typeclass spec
- Very similar to interface verification, but with more complex instance resolution

#### Advantages
✅ Supports ad-hoc polymorphism (different behavior per type)
✅ Compile-time resolution (no vtables if monomorphized)
✅ Can have multiple "implementations" via newtype wrappers
✅ Matches Rust/Haskell model

#### Disadvantages
❌ **Doesn't match TypeScript at all** (TS has no typeclasses)
❌ Requires parametric polymorphism in core language
❌ Complex instance resolution algorithm
❌ High implementation cost
❌ Unclear verification story for polymorphic specs

---

## Comparison Matrix

| Feature | Records+Functions | Interfaces+Vtables | Typeclasses |
|---------|------------------|-------------------|-------------|
| **Implementation Complexity** | ⭐ Low | ⭐⭐⭐ High | ⭐⭐⭐⭐ Very High |
| **Matches TypeScript** | ⭐⭐⭐⭐ Excellent | ⭐⭐⭐ Good | ⭐ Poor |
| **Structural Typing** | ✅ Native | ❌ Requires work | ❌ Not typical |
| **Nominal Typing** | ❌ No | ✅ Yes | ✅ Yes |
| **Subtyping** | ❌ No | ✅ Yes | ⚠️ Via constraints |
| **Code Reuse** | ❌ No sharing | ✅ Vtable sharing | ✅ Monomorphization |
| **Verification Difficulty** | ⭐⭐ Moderate | ⭐⭐⭐ High | ⭐⭐⭐⭐ Very High |
| **New AST Constructs** | 1 (CApply) | 5+ | 6+ |
| **Type System Changes** | None | Medium | Large |
| **Runtime Overhead** | Low | Medium (vtable) | None (mono) / Low (dict) |

---

## Separation Logic Considerations

### Records with Function Fields

**Heap assertion**:
```
RecordPointsTo(obj, {
  x: 10,
  y: 20,
  draw: λ(). ...,
  move: λdx dy. ...
})
```

**Method call verification**:
```
req RecordPointsTo(obj, {draw: f, ...}) ∧ f$() ⊨ (req P ens Q)
ens Q
```

**Challenges**:
- Higher-order predicates needed
- Specifications for lambda values
- Framing around unknown function effects

### Interfaces with Vtables

**Heap assertion**:
```
ImplementsInterface(obj, "Drawable", vtable) ∧
VtableValid("Drawable", vtable) ∧
RecordPointsTo(obj, fields)
```

**Method call verification**:
```
req ImplementsInterface(obj, "Drawable", vtable)
let f = vtable.draw in
ens f$() ⊨ DrawableSpec.draw
```

**Challenges**:
- Need invariants relating vtables to specs
- Modular verification across interface boundaries
- Vtable immutability invariants

### Typeclasses

**No direct heap representation** - purely type-level.

**Verification**:
```
req Drawable a ⊢ a -> (req P ens Q)
```

**Challenges**:
- Polymorphic specifications
- Instance coherence (only one instance per type)
- Proof parametricity

---

## Recommendations

### For TypeScript to Heifer Translation

**Recommendation: Use Records with Function Fields (Option 1)**

**Rationale**:
1. **TypeScript uses structural typing** - interfaces are just shape constraints
2. **Minimal implementation cost** - builds directly on newly implemented records
3. **Matches TS object model** - objects are property bags, methods are properties
4. **Sufficient for verification** - most TS code doesn't rely on nominal types

**Implementation plan**:

#### Phase 1: Add `CApply` for First-Class Function Calls
```ocaml
(* In typed_core_ast.ml *)
| CApply of core_lang * core_value list
  (* Apply a function value (from variable or field) to arguments *)
```

**Forward rule**:
```ocaml
| CApply (fn_expr, args) ->
    (* Evaluate function expression to get lambda *)
    let fn_spec, env = forward env fn_expr in
    (* Evaluate arguments *)
    let arg_specs, env = forward_list env args in
    (* Apply the lambda - use higher-order spec *)
    Bind ((fn_var, fn_expr.core_type), fn_spec,
      HigherOrder (fn_var, args)), env
```

#### Phase 2: TypeScript Interface Translation
```typescript
interface Drawable {
  x: number;
  y: number;
  draw(): void;
}
```

**Translate to**:
```ocaml
(* Anonymous structural record type *)
TRecord [
  ("x", Int);
  ("y", Int);
  ("draw", Arrow (Unit, Unit))
]
```

#### Phase 3: Method Call Translation
```typescript
obj.draw()
```

**Translate to**:
```ocaml
let draw_method = CGetField(obj, "draw") in
CApply(draw_method, [])
```

**Alternative**: Add sugar construct `CMethodCall`:
```ocaml
| CMethodCall of core_lang * string * core_value list
  (* Desugar to: let m = CGetField(obj, method) in CApply(m, args) *)
```

#### Phase 4: Verification Annotations for Interfaces

**User provides interface specification**:
```typescript
/**
 * @interface_spec Drawable
 * @method draw
 *   @requires emp
 *   @ensures emp
 * @method move
 *   @requires emp
 *   @ensures emp
 */
interface Drawable {
  draw(): void;
  move(dx: number, dy: number): void;
}
```

**Store in environment**:
```ocaml
type interface_spec = {
  iface_name: string;
  iface_methods: (string * staged_spec) SMap.t
}
```

**Use during verification**:
```ocaml
(* When verifying: obj.draw() *)
(* Look up Drawable interface spec for 'draw' method *)
let draw_spec = lookup_interface_method "Drawable" "draw" in
(* Use this spec instead of inferring from implementation *)
```

---

### When to Add Interfaces/Typeclasses

**Add nominal interfaces IF**:
- You need to verify code with polymorphic subtyping
- You're targeting Java/C# (not TypeScript)
- You need modular verification across interface boundaries
- Code reuse through inheritance is critical

**Add typeclasses IF**:
- You're targeting Haskell/Rust
- You need ad-hoc polymorphism (same function name, different implementations)
- You want compile-time resolution (no runtime overhead)
- Your codebase uses heavy generic programming

**For TypeScript**: Neither is necessary in the short term.

---

## Implementation Roadmap

### Immediate (1-2 weeks)
1. ✅ Heap-based records - **DONE**
2. 🔄 Add `CApply` for first-class function application
3. 🔄 Translate TypeScript method calls to `CGetField` + `CApply`
4. 🔄 Test with simple object examples

### Short-term (1 month)
5. Add `CMethodCall` syntactic sugar
6. Support TypeScript class translation to records
7. Add interface spec annotations (JSDoc)
8. Verify object-oriented examples

### Medium-term (3 months)
9. If needed: Add nominal interfaces with structural checking
10. If needed: Add simple subtyping (`TRecord` width/depth subtyping)

### Long-term (6+ months)
11. If targeting Rust: Consider trait/typeclass support
12. If targeting Java: Consider full nominal OOP with inheritance

---

## Examples

### Example 1: Object with Methods (Records+Functions)

**TypeScript**:
```typescript
interface Point {
  x: number;
  y: number;
  move(dx: number, dy: number): void;
}

function makePoint(x: number, y: number): Point {
  return {
    x: x,
    y: y,
    move: (dx: number, dy: number) => {
      this.x += dx;
      this.y += dy;
    }
  };
}

function translatePoint(p: Point, dx: number, dy: number): void {
  p.move(dx, dy);
}
```

**Translation to Heifer**:
```ocaml
(* makePoint *)
let makePoint (x : int) (y : int) : TRecord[("x", Int); ("y", Int); ("move", Arrow...)] =
  CRecord [
    ("x", CValue (Var x));
    ("y", CValue (Var y));
    ("move", CLambda (
      [("dx", Int); ("dy", Int)],
      Some (req ... ens ...),
      CSequence (
        CSetField (this, "x", BinOp (Plus, CGetField(this, "x"), Var "dx")),
        CSetField (this, "y", BinOp (Plus, CGetField(this, "y"), Var "dy"))
      )
    ))
  ]

(* translatePoint *)
let translatePoint (p : Point) (dx : int) (dy : int) : unit =
  let move_fn = CGetField (p, "move") in
  CApply (move_fn, [Var "dx"; Var "dy"])
```

**Verification**:
```
makePoint:
  ex rec. (ens rec->{x: x, y: y, move: λdx dy. ...} ∧ res=rec)

translatePoint:
  req RecordPointsTo(p, {move: f, ...}) ∧ f$(dx, dy) ⊨ (req ... ens ...)
  ens ...
```

---

### Example 2: Polymorphic Interface (Future Extension)

**TypeScript**:
```typescript
interface Comparable<T> {
  compareTo(other: T): number;
}

function max<T extends Comparable<T>>(a: T, b: T): T {
  return a.compareTo(b) > 0 ? a : b;
}
```

**With Records+Functions** (current approach):
```ocaml
(* Works if T has a compareTo field *)
type t = TRecord [("compareTo", Arrow (TVar "T", Int))]

let max (a : t) (b : t) : t =
  let cmp = CGetField (a, "compareTo") in
  let result = CApply (cmp, [b]) in
  CIfElse (Atomic (GT, result, 0), a, b)
```

**Limitation**: Can't enforce that `T` has `compareTo` at compile time - only checked when accessing field.

**With Typeclasses** (future):
```ocaml
typeclass Comparable a where
  compareTo : a -> a -> int

let max (type a) (cmp : Comparable a) (a : a) (b : a) : a =
  if cmp.compareTo a b > 0 then a else b
```

**Benefit**: Type safety - won't compile unless `Comparable` instance exists.

---

## Conclusion

**For Heifer's TypeScript verification goals**, the recommended path is:

1. ✅ **Heap-based records** - COMPLETE
2. 🎯 **Add `CApply` for method calls** - NEXT STEP
3. 🎯 **Translate interfaces as structural record types** - SIMPLE
4. 🎯 **Support interface specs via annotations** - MODERATE

This provides **80% of the value with 20% of the complexity** compared to full nominal interfaces or typeclasses.

**Defer** nominal interfaces and typeclasses until:
- Concrete use case requiring nominal typing emerges
- Verification of real-world polymorphic code needs it
- Targeting languages with nominal OOP (Java, C#)

---

*Last updated: 2026-01-04*
