# Complete TypeScript AST Node Translation Reference

This document maps **every** TypeScript `SyntaxKind` to Heifer IR translation strategy.

> **Sources:**
> - [TypeScript Compiler API Wiki](https://github.com/microsoft/TypeScript/wiki/Using-the-Compiler-API)
> - [SyntaxKind Enum Reference](https://typestrong.org/typedoc-auto-docs/typedoc/enums/TypeScript.SyntaxKind.html)
> - [TypeScript AST Viewer](https://ts-ast-viewer.com/)
> - [TypeScript Source: types.ts](https://github.com/microsoft/TypeScript/blob/main/src/compiler/types.ts)

---

## Translation Categories

###  1. **LITERALS** → `term` (CValue)

| SyntaxKind | TypeScript Example | Heifer IR | Notes |
|------------|-------------------|-----------|-------|
| `NumericLiteral` | `42`, `3.14` | `{ term_desc = Const (Num 42); term_type = Int }` | ⚠️ Float → Int (truncate or error) |
| `BigIntLiteral` | `123n` | `Const (Num 123)` | Convert to int (may overflow) |
| `StringLiteral` | `"hello"`, `'world'` | `Const (TStr "hello")` | Direct mapping |
| `TrueKeyword` | `true` | `Const TTrue` | Direct |
| `FalseKeyword` | `false` | `Const TFalse` | Direct |
| `NullKeyword` | `null` | `Const ValUnit` | Null → Unit |
| `UndefinedKeyword` | `undefined` | `Const ValUnit` | Undefined → Unit |
| `RegularExpressionLiteral` | `/pattern/` | ❌ **UNSUPPORTED** | No regex in Heifer |
| `NoSubstitutionTemplateLiteral` | `` `text` `` | `Const (TStr "text")` | Static template → string |
| `TemplateHead` | `` `start ${` `` | See Template Expression below | Part of interpolation |
| `TemplateMiddle` | `` `} middle ${` `` | See Template Expression below | Part of interpolation |
| `TemplateTail` | `` `} end` `` | See Template Expression below | Part of interpolation |

**Translation:**
```ocaml
| NumericLiteral value ->
    { term_desc = Const (Num (int_of_float value));
      term_type = Int }
| StringLiteral text ->
    { term_desc = Const (TStr text);
      term_type = TyString }
```

---

### 2. **IDENTIFIERS** → `term` (Var)

| SyntaxKind | TypeScript Example | Heifer IR | Notes |
|------------|-------------------|-----------|-------|
| `Identifier` | `myVariable`, `x` | `{ term_desc = Var "myVariable"; term_type = <from env> }` | Lookup in environment |
| `PrivateIdentifier` | `#privateField` | ⚠️ Map to regular identifier | Strip `#` prefix |
| `ThisKeyword` | `this` | `Var "this"` | In methods, `this` is parameter |
| `SuperKeyword` | `super` | ❌ **UNSUPPORTED** | No inheritance in Heifer |

**Translation:**
```ocaml
| Identifier name ->
    let typ = lookup_var env name in
    { term_desc = Var name; term_type = typ }
```

---

### 3. **BINARY OPERATORS** → `BinOp` or `Rel`

| SyntaxKind | TS Op | TypeScript Example | Heifer IR | Category |
|------------|-------|-------------------|-----------|----------|
| `PlusToken` | `+` | `x + y` | `BinOp (Plus, x, y)` | Arithmetic |
| `MinusToken` | `-` | `x - y` | `BinOp (Minus, x, y)` | Arithmetic |
| `AsteriskToken` | `*` | `x * y` | `BinOp (TTimes, x, y)` | Arithmetic |
| `SlashToken` | `/` | `x / y` | `BinOp (TDiv, x, y)` | Arithmetic |
| `PercentToken` | `%` | `x % y` | ⚠️ **NO DIRECT SUPPORT** | Use division + multiply |
| `AsteriskAsteriskToken` | `**` | `x ** y` | `BinOp (TPower, x, y)` | Arithmetic |
| `LessThanToken` | `<` | `x < y` | `Rel (LT, x, y)` or `Atomic (LT, x, y)` | Comparison |
| `LessThanEqualsToken` | `<=` | `x <= y` | `Rel (LTEQ, x, y)` | Comparison |
| `GreaterThanToken` | `>` | `x > y` | `Rel (GT, x, y)` | Comparison |
| `GreaterThanEqualsToken` | `>=` | `x >= y` | `Rel (GTEQ, x, y)` | Comparison |
| `EqualsEqualsToken` | `==` | `x == y` | `Rel (EQ, x, y)` | Comparison |
| `EqualsEqualsEqualsToken` | `===` | `x === y` | `Rel (EQ, x, y)` | Comparison (prefer this) |
| `ExclamationEqualsToken` | `!=` | `x != y` | `TNot (Rel (EQ, x, y))` | Comparison |
| `ExclamationEqualsEqualsToken` | `!==` | `x !== y` | `TNot (Rel (EQ, x, y))` | Comparison |
| `AmpersandAmpersandToken` | `&&` | `a && b` | `BinOp (TAnd, a, b)` or `And (pi_a, pi_b)` | Logical (context-dependent) |
| `BarBarToken` | `\|\|` | `a \|\| b` | `BinOp (TOr, a, b)` or `Or (pi_a, pi_b)` | Logical |
| `QuestionQuestionToken` | `??` | `a ?? b` | Desugar to `a !== null ? a : b` | Nullish coalescing |
| `AmpersandToken` | `&` | `a & b` | ❌ **UNSUPPORTED** | Bitwise ops not in Heifer |
| `BarToken` | `\|` | `a \| b` | ❌ **UNSUPPORTED** | Bitwise |
| `CaretToken` | `^` | `a ^ b` | ❌ **UNSUPPORTED** | Bitwise XOR |
| `LessThanLessThanToken` | `<<` | `a << b` | ❌ **UNSUPPORTED** | Bit shift |
| `GreaterThanGreaterThanToken` | `>>` | `a >> b` | ❌ **UNSUPPORTED** | Bit shift |
| `GreaterThanGreaterThanGreaterThanToken` | `>>>` | `a >>> b` | ❌ **UNSUPPORTED** | Unsigned bit shift |
| `InstanceOfKeyword` | `instanceof` | `x instanceof Y` | ⚠️ Type check → runtime assertion | Need type tags |
| `InKeyword` | `in` | `"prop" in obj` | ⚠️ Desugar to property check | Need object model |

**Assignment Operators:**
| SyntaxKind | TS Op | Translation | Variance Requirement |
|------------|-------|-------------|---------------------|
| `EqualsToken` | `=` | `CWrite` (see below) | `x.acc <: %W` |
| `PlusEqualsToken` | `+=` | Desugar: `x = x + y` | `x.acc <: %M` (read+write) |
| `MinusEqualsToken` | `-=` | Desugar: `x = x - y` | `x.acc <: %M` |
| `AsteriskEqualsToken` | `*=` | Desugar: `x = x * y` | `x.acc <: %M` |
| `SlashEqualsToken` | `/=` | Desugar: `x = x / y` | `x.acc <: %M` |
| (etc.) | All `*=` ops | Desugar to read, operation, write | `x.acc <: %M` |

**Assignment Translation with Variance:**
```ocaml
(* Simple assignment: x = v *)
| BinaryExpression (EqualsToken, Identifier x, rhs) ->
    let v = translate_expr rhs in
    let variance = get_variance x in

    (* Check: D |- x.acc <: %W *)
    assert (variance = Mutable);  (* Only mutable vars can be assigned *)

    (*@ fresh A, B
        D1 = x1:A ∧ x2':B ∧ D
        D1 |- x1.acc <: %W ∧ x2.acc <: %R ∧ B <: A
        ------------------------------------------------Assign
        {D} x1 := x2 {ens[r] D ∧ r:() ∘_{x1} (x1':x2')}
    @*)
    { core_desc = CWrite (x, v);
      core_type = Unit }

(* Compound assignment: x += v *)
| BinaryExpression (PlusEqualsToken, Identifier x, rhs) ->
    (* Desugar to: x = x + v *)
    (* Requires: x.acc <: %M (both read and write) *)
    let v = translate_expr rhs in
    { core_desc = CWrite (x,
        { term_desc = BinOp (Plus,
            { core_desc = CRead x; core_type = get_type x },
            v);
          term_type = get_type x });
      core_type = Unit }
```

**Read Operation with Variance:**
```ocaml
(* Variable read *)
| Identifier x ->
    let variance = get_variance x in

    match variance with
    | Immutable ->
        (*@ D |- x.acc <: %R (always true for %I)
            ===============================Read-Immutable
            {D} x {ens[r] D ∧ r:x'}
        @*)
        (* For immutable vars: x' = x, so just use Var *)
        { core_desc = CValue (Var x);
          core_type = get_type x }

    | Mutable ->
        (*@ D |- x.acc <: %R
            ===============================Read-Mutable
            {D} !x {ens[r] D ∧ r:x'}
        @*)
        { core_desc = CRead x;
          core_type = get_element_type (get_type x) }
```

**Translation:**
```ocaml
| BinaryExpression (PlusToken, left, right) ->
    let l = translate_expr left in
    let r = translate_expr right in
    { term_desc = BinOp (Plus, l, r);
      term_type = Int }

| BinaryExpression (LessThanToken, left, right) ->
    (* In boolean context *)
    Atomic (LT, translate_term left, translate_term right)
```

---

### 4. **UNARY OPERATORS** → `TNot`, `BinOp`

| SyntaxKind | TS Op | TypeScript Example | Heifer IR |
|------------|-------|-------------------|-----------|
| `ExclamationToken` | `!` | `!condition` | `TNot term` or `Not pi` |
| `PlusPlusToken` (prefix) | `++x` | `++i` | Desugar: `i = i + 1; i` |
| `MinusMinusToken` (prefix) | `--x` | `--i` | Desugar: `i = i - 1; i` |
| `PlusPlusToken` (postfix) | `x++` | `i++` | Desugar: `tmp = i; i = i + 1; tmp` |
| `MinusMinusToken` (postfix) | `x--` | `i--` | Desugar: `tmp = i; i = i - 1; tmp` |
| `MinusToken` (unary) | `-x` | `-5` | `BinOp (Minus, Const (Num 0), x)` |
| `PlusToken` (unary) | `+x` | `+value` | Identity (no-op) |
| `TildeToken` | `~x` | `~bits` | ❌ **UNSUPPORTED** (bitwise NOT) |
| `TypeOfKeyword` | `typeof x` | `typeof variable` | ⚠️ Return type name as string |
| `VoidKeyword` | `void expr` | `void 0` | Evaluate expr, return unit |
| `DeleteKeyword` | `delete obj.prop` | `delete x.y` | ⚠️ Set to undefined? |
| `AwaitKeyword` | `await promise` | `await fetch()` | See Async/Await section |
| `YieldKeyword` | `yield value` | `yield x` | ❌ **UNSUPPORTED** (generators) |

**Translation:**
```ocaml
| PrefixUnaryExpression (ExclamationToken, operand) ->
    let inner = translate_expr operand in
    { term_desc = TNot inner;
      term_type = Bool }

| PrefixUnaryExpression (PlusPlusToken, operand) ->
    (* ++x → x := x + 1; x *)
    (* Requires: x.acc <: %M (mutable) *)
    let var_name = get_identifier operand in
    assert (get_variance var_name = Mutable);
    CSequence (
      CWrite (var_name, BinOp (Plus, CRead var_name, Const (Num 1))),
      CRead var_name
    )

| PostfixUnaryExpression (PlusPlusToken, operand) ->
    (* x++ → tmp = x; x := x + 1; tmp *)
    (* Requires: x.acc <: %M *)
    let var_name = get_identifier operand in
    let tmp = fresh_var "tmp" in
    CLet ((tmp, get_type var_name),
      CRead var_name,
      CSequence (
        CWrite (var_name, BinOp (Plus, CRead var_name, Const (Num 1))),
        Var tmp
      )
    )
```

---

### 4b. **VARIANCE EXAMPLES**

#### Example 1: Immutable Variable

**TypeScript:**
```typescript
const x: number = 10;
const y = x + 5;
```

**Analysis:** `x` is never reassigned → variance = `%I`

**Heifer IR:**
```ocaml
(*@ x': Int @ S ∧ x.acc: %I ∧ x': x @*)
CLet (("x", Int),
  Const (Num 10),
  (*@ y': Int @ S ∧ y.acc: %I ∧ y': y @*)
  CLet (("y", Int),
    BinOp (Plus, Var "x", Const (Num 5)),  (* Direct use, no CRead *)
    ...
  )
)
```

**Note:** For immutable variables, `x' = x` (identity), so we use `Var "x"` directly, not `CRead "x"`.

---

#### Example 2: Mutable Variable

**TypeScript:**
```typescript
let x: number = 10;
x = x + 5;
return x;
```

**Analysis:** `x` is reassigned on line 2 → variance = `%M`

**Heifer IR:**
```ocaml
(*@ x': Int @ S ∧ x.acc: %M ∧ x: ⊤ @*)
CLet (("x", TConstr ("ref", [Int])),
  CRef (Const (Num 10)),          (* Allocate reference *)
  CSequence (
    (*@ Require: x.acc <: %W ∧ x.acc <: %R (both satisfied by %M) @*)
    CWrite ("x",
      BinOp (Plus,
        CRead "x",                 (* Read: requires x.acc <: %R *)
        Const (Num 5)
      )
    ),                              (* Write: requires x.acc <: %W *)
    CRead "x"                       (* Final read *)
  )
)
```

**Verification Conditions:**
```
1. x.acc = %M
2. %M <: %R ✓ (can read)
3. %M <: %W ✓ (can write)
```

---

#### Example 3: Attempting to Mutate Immutable (Error)

**TypeScript:**
```typescript
const x: number = 10;
x = 20;  // TypeScript error!
```

**Analysis:** `const` prevents reassignment → **translation error**

**Expected Behavior:**
```ocaml
(* TypeScript catches this at compile time *)
(* If translated anyway, would generate: *)

(*@ x': Int @ S ∧ x.acc: %I ∧ x': x @*)
CLet (("x", Int), Const (Num 10),
  CWrite ("x", Const (Num 20))  (* ERROR: x.acc = %I </: %W *)
)
```

**Verification Fails:**
```
x.acc = %I
%I </: %W  ✗ (cannot write to immutable)
```

---

#### Example 4: Function Parameter Mutation

**TypeScript:**
```typescript
function increment(x: number): number {
  x = x + 1;  // Mutates local parameter
  return x;
}
```

**Analysis:** Parameter `x` is reassigned → variance = `%M`

**Heifer IR:**
```ocaml
Meth ("increment",
  [("x_param", Int)],               (* Original parameter (immutable) *)
  None,
  (*@ x': Int @ S ∧ x.acc: %M ∧ x: ⊤ @*)
  CLet (("x", TConstr ("ref", [Int])),
    CRef (Var "x_param"),            (* Copy to mutable local *)
    CSequence (
      CWrite ("x", BinOp (Plus, CRead "x", Const (Num 1))),
      CRead "x"
    )
  ),
  [], None
)
```

**Key Insight:** Function parameters are always immutable. If the function body mutates a parameter, create a local mutable copy.

---

#### Example 5: Object Field Mutation with Variance

**TypeScript:**
```typescript
interface Point {
  x: number;
  y: number;
}

function moveX(p: Point, dx: number): void {
  p.x = p.x + dx;  // Mutates field
}
```

**Analysis:** Object fields in TypeScript are mutable by default

**Heifer IR (Object Desugaring):**
```ocaml
(* Type definition *)
type point = {
  x_ref: ref<int>;   (* Field is a reference *)
  y_ref: ref<int>
}

(* Method *)
Meth ("moveX",
  [("p", TConstr ("point", [])); ("dx", Int)],
  (*@ Require: (p.x_ref ↦ old_x) * (p.y_ref ↦ old_y)
      Ensure:  (p.x_ref ↦ (old_x + dx)) * (p.y_ref ↦ old_y) @*)
  Some (Sequence (
    Require (True,
      SepConj (
        PointsTo ("p_x_ref", Var "old_x"),
        PointsTo ("p_y_ref", Var "old_y")
      )
    ),
    NormalReturn (True,
      SepConj (
        PointsTo ("p_x_ref", BinOp (Plus, Var "old_x", Var "dx")),
        PointsTo ("p_y_ref", Var "old_y")  (* Unchanged *)
      )
    )
  )),
  (*@ p.x_ref.acc: %M ∧ p.y_ref.acc: %M @*)
  CWrite ("p_x_ref",
    BinOp (Plus, CRead "p_x_ref", Var "dx")
  ),
  [], None
)
```

**Variance Annotations for Fields:**
- Object fields are **always mutable** in TypeScript (no `readonly` considered yet)
- Each field ref has `acc: %M`
- Heap formulas track which fields are modified

---

#### Example 6: Closure Capturing Mutable Variable

**TypeScript:**
```typescript
function makeCounter(): () => number {
  let count = 0;
  return () => {
    count++;
    return count;
  };
}
```

**Analysis:** `count` is mutated inside closure → variance = `%M`

**Heifer IR:**
```ocaml
Meth ("makeCounter", [], None,
  (*@ count': Int @ S ∧ count.acc: %M ∧ count: ⊤ @*)
  CLet (("count", TConstr ("ref", [Int])),
    CRef (Const (Num 0)),
    (* Lambda captures count reference *)
    CLambda ([],
      (*@ Require: (count ↦ n)
          Ensure:  (res = n + 1) * (count ↦ (n + 1)) @*)
      Some (Sequence (
        Require (True, PointsTo ("count", Var "n")),
        NormalReturn (
          Atomic (EQ, Var "res", BinOp (Plus, Var "n", Const (Num 1))),
          PointsTo ("count", BinOp (Plus, Var "n", Const (Num 1)))
        )
      )),
      CSequence (
        CWrite ("count", BinOp (Plus, CRead "count", Const (Num 1))),
        CRead "count"
      )
    )
  ),
  [], None
)
```

**Key Points:**
- `count` is allocated in outer scope
- Lambda captures the **reference**, not the value
- Each call mutates the shared reference
- Specification tracks heap evolution

---

### 5. **CALL EXPRESSIONS** → `CFunCall`

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `CallExpression` | `foo(x, y)` | `CFunCall ("foo", [x_term; y_term])` |
| `NewExpression` | `new Point(1, 2)` | `CFunCall ("Point_new", [Const (Num 1); Const (Num 2)])` |
| `TaggedTemplateExpression` | `` tag`text` `` | ❌ **UNSUPPORTED** |

**Special Call Patterns:**
| Pattern | TypeScript | Translation |
|---------|------------|-------------|
| Method call | `obj.method(arg)` | `CFunCall ("obj_method", [Var "obj"; arg])` |
| Constructor | `new Class()` | `CFunCall ("Class_new", [])` |
| Super call | `super(args)` | ❌ **UNSUPPORTED** |

**Translation:**
```ocaml
| CallExpression (callee, args) ->
    let fn_name = get_function_name callee in
    let arg_values = List.map (fun a ->
      translate_expr a |> maybe_var
    ) args in
    { core_desc = CFunCall (fn_name, arg_values);
      core_type = get_return_type callee }
```

---

### 6. **PROPERTY ACCESS** → `CRead` (after object desugaring)

| SyntaxKind | TypeScript Example | Heifer IR | Notes |
|------------|-------------------|-----------|-------|
| `PropertyAccessExpression` | `obj.field` | `CRead "obj_field_ref"` | After desugaring |
| `ElementAccessExpression` | `arr[0]`, `obj["key"]` | Depends on type | Array vs object |
| `QuestionDotToken` | `obj?.field` | Desugar to conditional | Optional chaining |

**Translation Strategy:**
```typescript
// TypeScript
const p = { x: 1, y: 2 };
const value = p.x;

// Heifer IR (after desugaring)
let x_ref = ref 1 in
let y_ref = ref 2 in
let p = { x_ref; y_ref } in
let value = !p.x_ref in  (* CRead "p_x_ref" *)
...
```

**Translation:**
```ocaml
| PropertyAccessExpression (obj, property) ->
    let obj_name = get_identifier obj in
    let field_name = property.text in
    let ref_name = obj_name ^ "_" ^ field_name ^ "_ref" in
    { core_desc = CRead ref_name;
      core_type = get_field_type obj property }
```

---

### 7. **TEMPLATE EXPRESSIONS** → String concatenation

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `TemplateExpression` | `` `Hello ${name}!` `` | Nested `BinOp (SConcat, ...)` |

**Translation:**
```typescript
`Hello ${name}!`

// Becomes:
"Hello " + name + "!"

// Heifer IR:
BinOp (SConcat,
  BinOp (SConcat, Const (TStr "Hello "), Var "name"),
  Const (TStr "!")
)
```

**Translation:**
```ocaml
| TemplateExpression (head, spans) ->
    let init = Const (TStr (get_text head)) in
    List.fold_left (fun acc span ->
      let expr_part = translate_expr span.expression in
      let text_part = Const (TStr (get_text span.literal)) in
      BinOp (SConcat, BinOp (SConcat, acc, expr_part), text_part)
    ) init spans
```

---

### 8. **ARROW FUNCTIONS & FUNCTION EXPRESSIONS** → `CLambda`

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `ArrowFunction` | `(x, y) => x + y` | `CLambda ([("x", Int); ("y", Int)], None, body)` |
| `FunctionExpression` | `function(x) { return x * 2; }` | `CLambda ([("x", Int)], None, body)` |

**Translation:**
```ocaml
| ArrowFunction (params, body) ->
    let binders = List.map (fun p ->
      (p.name, ts_type_to_heifer p.typ)
    ) params in
    let body_expr = translate_expr body in
    { core_desc = CLambda (binders, None, body_expr);
      core_type = make_function_type binders body_expr.core_type }
```

---

### 9. **STATEMENTS**

#### Variable Declarations → `CLet`

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `VariableStatement` | `let x = 42;` | Container for declarations |
| `VariableDeclarationList` | `let x = 1, y = 2;` | Multiple `CLet` nested |
| `VariableDeclaration` | `x = 42` | `CLet (("x", Int), Const (Num 42), continuation)` |

**Const vs Let vs Var:**
- `const` → Immutable variable with variance `%I`
- `let` without reassignment → Immutable variable with variance `%I`
- `let` with reassignment → Mutable variable (ref) with variance `%M`
- `var` → Treat same as `let`

**Variance Annotations:**
- `%M` = Mutable (read + write)
- `%R` = Read-only
- `%W` = Write-only
- `%I` = Immutable (identity)
- `%N` = Non-accessible

**Subtyping:**
```
    .  <: +  <: \
    .  <: -  <: \
    %M <: %R <: %N
    %M <: %W <: %N
    %I <: %R
Note: %M ∧ %I = false
```

**Translation Strategy:**

1. **Analysis Pass**: Detect which variables are reassigned
```ocaml
type variance = Mutable | Immutable

let analyze_variance (decls: declaration list) : (string * variance) list =
  (* Walk AST and find all reassignments (BinaryExpression with EqualsToken) *)
  let reassigned = find_all_reassignments decls in
  List.map (fun (name, _) ->
    if List.mem name reassigned then (name, Mutable)
    else (name, Immutable)
  ) (collect_all_variables decls)
```

2. **Translation with Variance**:
```ocaml
| VariableStatement (declarations) ->
    List.fold_right (fun decl cont ->
      let name = decl.name in
      let init = translate_expr decl.initializer in
      let typ = infer_type init in
      let variance = get_variance name in

      match variance with
      | Immutable ->
          (* Immutable: x': T ∧ x.acc: %I ∧ x': x *)
          { core_desc = CLet ((name, typ), init, cont);
            core_type = cont.core_type }

      | Mutable ->
          (* Mutable: x': T ∧ x.acc: %M ∧ x: ⊤ *)
          { core_desc = CLet ((name, TConstr ("ref", [typ])),
                              { core_desc = CRef init;
                                core_type = TConstr ("ref", [typ]) },
                              cont);
            core_type = cont.core_type }
    ) declarations continuation
```

3. **Specification Generation**:
```ocaml
(* Immutable variable *)
(*@ x': Int @ S ∧ x.acc: %I ∧ x': x
    -- This means: x's value is x', x is immutable, and x equals its value
@*)

(* Mutable variable *)
(*@ x': Int @ S ∧ x.acc: %M ∧ x: ⊤
    -- This means: x's value is x', x is mutable, and x has top type (allows exceptions)
@*)

#### If Statements → `CIfElse`

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `IfStatement` | `if (x > 0) { ... } else { ... }` | `CIfElse (Atomic (GT, ...), then_branch, else_branch)` |

**Translation:**
```ocaml
| IfStatement (condition, then_stmt, else_stmt) ->
    let cond_pi = translate_condition condition in
    let then_branch = translate_stmt then_stmt in
    let else_branch = Option.map translate_stmt else_stmt
                      |> Option.value ~default:unit_stmt in
    { core_desc = CIfElse (cond_pi, then_branch, else_branch);
      core_type = then_branch.core_type }
```

#### Loops → Recursive functions

| SyntaxKind | TypeScript Example | Translation Strategy |
|------------|-------------------|---------------------|
| `WhileStatement` | `while (cond) { body }` | Recursive `loop` function |
| `DoStatement` | `do { body } while (cond);` | Execute body, then while loop |
| `ForStatement` | `for (init; cond; incr) { body }` | Desugar to while with init |
| `ForInStatement` | `for (x in obj) { ... }` | ❌ **UNSUPPORTED** (needs iteration) |
| `ForOfStatement` | `for (x of arr) { ... }` | ⚠️ Desugar to list recursion |

**While Loop Translation:**
```typescript
while (x > 0) {
  x = x - 1;
}

// Becomes:
let rec loop () =
  if x > 0 then
    let _ = x_ref := !x_ref - 1 in
    loop ()
  else
    ()
in loop ()
```

**Translation:**
```ocaml
| WhileStatement (condition, body) ->
    let loop_name = fresh_var "loop" in
    let cond_pi = translate_condition condition in
    let body_expr = translate_stmt body in
    let loop_call = CFunCall (loop_name, []) in
    let loop_body = CIfElse (cond_pi,
      CSequence (body_expr, loop_call),
      unit_stmt
    ) in
    CSequence (
      CLet ((loop_name, Arrow (Unit, Unit)),
        CLambda ([], None, loop_body),
        loop_call),
      continuation
    )
```

#### Control Flow

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `ReturnStatement` | `return x + 1;` | Just the expression (implicit return) |
| `BreakStatement` | `break;` | ⚠️ **COMPLEX** (needs labeled blocks) |
| `ContinueStatement` | `continue;` | ⚠️ **COMPLEX** |
| `ThrowStatement` | `throw new Error("msg");` | `CPerform ("Exception", msg)` |
| `TryStatement` | `try { ... } catch (e) { ... }` | `CMatch` with Exception handler |

#### Other Statements

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `Block` | `{ stmt1; stmt2; }` | Nested `CSequence` or scope |
| `ExpressionStatement` | `foo();` | Translate expression, sequence with next |
| `EmptyStatement` | `;` | `CValue unit_term` |
| `DebuggerStatement` | `debugger;` | ❌ Ignore or warning |
| `WithStatement` | `with (obj) { ... }` | ❌ **UNSUPPORTED** (deprecated) |
| `LabeledStatement` | `label: statement` | ⚠️ For break/continue |
| `SwitchStatement` | `switch (x) { case ...: }` | Desugar to if-else chain or match |
| `CaseClause` | `case 1: ...` | Part of switch → if-else |
| `DefaultClause` | `default: ...` | Else branch |

---

### 10. **FUNCTION & CLASS DECLARATIONS**

#### Function Declarations → `Meth`

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `FunctionDeclaration` | `function add(x: number, y: number): number { return x + y; }` | `Meth ("add", [("x", Int); ("y", Int)], None, body, [], None)` |

**With JSDoc:**
```typescript
/**
 * @requires x > 0, y > 0, heap_empty
 * @ensures res = x + y, heap_empty
 */
function add(x: number, y: number): number {
  return x + y;
}
```

**Heifer IR:**
```ocaml
Meth ("add",
  [("x", Int); ("y", Int)],
  Some (Sequence (
    Require (And (Atomic (GT, Var "x", Const (Num 0)),
                  Atomic (GT, Var "y", Const (Num 0))),
             EmptyHeap),
    NormalReturn (Atomic (EQ, Var "res",
                          BinOp (Plus, Var "x", Var "y")),
                  EmptyHeap)
  )),
  body, [], None)
```

#### Class Declarations → Record + Functions

| SyntaxKind | TypeScript Example | Translation |
|------------|-------------------|-------------|
| `ClassDeclaration` | `class Point { ... }` | Type + constructor + methods |
| `Constructor` | `constructor(x: number) { this.x = x; }` | `Point_new` function |
| `MethodDeclaration` | `increment(): void { this.count++; }` | `Class_method` function with `this` param |
| `PropertyDeclaration` | `x: number;` | Field in record type (as ref) |
| `GetAccessor` | `get value() { return this._value; }` | Regular method |
| `SetAccessor` | `set value(v) { this._value = v; }` | Method + write |

**Class Translation:**
```typescript
class Counter {
  private count: number = 0;

  increment(): void {
    this.count++;
  }

  getValue(): number {
    return this.count;
  }
}

// Becomes:
type counter = { count_ref: int ref }

let Counter_new () : counter =
  let count_ref = ref 0 in
  { count_ref }

let Counter_increment (this: counter) : unit =
  this.count_ref := !this.count_ref + 1

let Counter_getValue (this: counter) : int =
  !this.count_ref
```

---

### 11. **TYPE DECLARATIONS**

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `InterfaceDeclaration` | `interface Point { x: number; y: number; }` | Record type definition |
| `TypeAliasDeclaration` | `type Pair = [number, string];` | Type alias |
| `EnumDeclaration` | `enum Color { Red, Green }` | Sum type with constructors |

**Interface → Record:**
```typescript
interface Point {
  x: number;
  y: number;
}

// Heifer:
type point = {
  x_ref: int ref;
  y_ref: int ref
}
```

**Enum → Constructors:**
```typescript
enum Color {
  Red,
  Green,
  Blue
}

// Heifer:
type color =
  | Red
  | Green
  | Blue
```

---

### 12. **ASYNC/AWAIT** → Effect Handlers

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `AsyncKeyword` | `async function foo() { ... }` | Function that may raise effects |
| `AwaitExpression` | `await fetch(url)` | `CPerform (effect_name, arg)` |

**Translation:**
```typescript
async function fetchUser(id: number): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  return response;
}

// Heifer:
effect Fetch : string -> response

let fetchUser (id: int) : user =
  (*@ RaisingEff(Fetch, ...) @*)
  let response = perform (Fetch ("/api/users/" ^ string_of_int id)) in
  response
```

---

### 13. **EXCEPTION HANDLING** → Effect Handlers

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `TryStatement` | `try { ... } catch (e) { ... }` | `CMatch (Deep, ..., handlers)` |
| `CatchClause` | `catch (e) { ... }` | Exception effect handler |
| `ThrowStatement` | `throw new Error("msg");` | `CPerform ("Exception", msg)` |

**Translation:**
```typescript
try {
  riskyOp();
} catch (e) {
  handleError(e);
}

// Heifer:
match riskyOp () with
| effect (Exception e) k -> handleError e
```

---

### 14. **PATTERNS & DESTRUCTURING**

| SyntaxKind | TypeScript Example | Translation |
|------------|-------------------|-------------|
| `ObjectBindingPattern` | `const {x, y} = point;` | Multiple `let` bindings |
| `ArrayBindingPattern` | `const [first, second] = pair;` | Pattern match on list |
| `BindingElement` | `{x: newX}` | Individual binding in pattern |
| `SpreadElement` | `...rest` | ⚠️ List operations |

**Destructuring Translation:**
```typescript
const {x, y} = point;

// Becomes:
let x = point.x in
let y = point.y in
...
```

---

### 15. **ARRAY & OBJECT LITERALS**

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `ArrayLiteralExpression` | `[1, 2, 3]` | List construction with `::` |
| `ObjectLiteralExpression` | `{ x: 1, y: 2 }` | Record with ref fields |
| `PropertyAssignment` | `{ x: value }` | Field initialization |
| `ShorthandPropertyAssignment` | `{ x }` | `{ x: x }` |
| `SpreadAssignment` | `{ ...obj }` | ⚠️ Copy all fields |
| `ComputedPropertyName` | `{ [key]: value }` | ❌ **UNSUPPORTED** |

---

### 16. **CONDITIONAL EXPRESSION** → `CIfElse`

| SyntaxKind | TypeScript Example | Heifer IR |
|------------|-------------------|-----------|
| `ConditionalExpression` | `x > 0 ? "pos" : "neg"` | `CIfElse (Atomic (GT, ...), ...)` |

---

### 17. **TYPE SYSTEM NODES** (Type-level only)

These don't translate to runtime Heifer IR, only affect type mapping:

| SyntaxKind | TypeScript | Purpose |
|------------|------------|---------|
| `TypeReference` | `Foo<T>` | Type checking only |
| `UnionType` | `number \| string` | Map to `Union (Int, TyString)` |
| `IntersectionType` | `A & B` | ⚠️ Complex |
| `FunctionType` | `(x: number) => string` | `Arrow (Int, TyString)` |
| `ArrayType` | `number[]` | `TConstr ("Array", [Int])` |
| `TupleType` | `[number, string]` | Product type or record |
| `TypeLiteral` | `{ x: number }` | Object type |
| `TypeParameter` | `<T>` | Generic type variable |
| `TypePredicate` | `x is string` | Type guard (runtime check) |
| `TypeQuery` | `typeof x` | Extract type |
| `IndexedAccessType` | `T[K]` | Type-level indexing |
| `MappedType` | `{ [K in T]: U }` | Type transformation |
| `ConditionalType` | `T extends U ? X : Y` | Type-level conditional |

---

### 18. **JSX** (React)

| SyntaxKind | JSX Example | Translation |
|------------|-------------|-------------|
| `JsxElement` | `<div>content</div>` | ❌ **OUT OF SCOPE** |
| `JsxSelfClosingElement` | `<img />` | ❌ **OUT OF SCOPE** |
| `JsxAttribute` | `<div className="foo">` | ❌ **OUT OF SCOPE** |
| (All JSX nodes) | | Not relevant for verification |

---

### 19. **MODULES & IMPORTS**

| SyntaxKind | TypeScript Example | Translation |
|------------|-------------------|-------------|
| `ImportDeclaration` | `import { foo } from "bar";` | ⚠️ Resolve to definitions |
| `ImportClause` | `import foo from "bar";` | |
| `NamedImports` | `{ foo, bar }` | |
| `ExportDeclaration` | `export { foo };` | ⚠️ Module system |
| `ExportAssignment` | `export = foo;` | |
| `ModuleDeclaration` | `module Foo { ... }` | Namespace |

**Strategy:** Resolve imports at parse time, inline definitions.

---

### 20. **IGNORED / UNSUPPORTED NODES**

| Category | SyntaxKind | Reason |
|----------|------------|--------|
| **Trivia** | `SingleLineCommentTrivia`, `MultiLineCommentTrivia`, `WhitespaceTrivia` | Whitespace/comments |
| **Advanced Types** | `InferType`, `MappedType`, `TemplateLiteralType` | Type-level only |
| **Decorators** | `Decorator` | Metadata, not runtime |
| **JSDoc** | `JSDocComment`, `JSDocTag` | Parsed for specs, not IR |
| **Generators** | `YieldExpression`, `YieldKeyword` | No generators in Heifer |
| **Symbols** | `SymbolKeyword` | No symbols |
| **Regex** | `RegularExpressionLiteral` | No regex support |
| **Dynamic** | `eval`, `with` | Too dynamic |
| **Meta** | `SourceFile`, `EndOfFileToken`, `SyntaxList` | AST metadata |

---

## Translation Decision Tree

```
┌─ Is it a literal? ─────────→ Const (...)
├─ Is it an identifier? ─────→ Var "..."
├─ Is it a binary op? ───────→ BinOp or Rel or Atomic
├─ Is it a function call? ───→ CFunCall
├─ Is it property access? ───→ CRead (after desugaring)
├─ Is it a variable decl? ───→ CLet
├─ Is it an if statement? ───→ CIfElse
├─ Is it a loop? ────────────→ Recursive function
├─ Is it a function decl? ───→ Meth
├─ Is it a class? ───────────→ Type + constructor + methods
├─ Is it async/await? ───────→ Effect handlers
├─ Is it try/catch? ─────────→ Exception handler
├─ Is it type-level only? ───→ Skip (type info only)
└─ Is it unsupported? ───────→ Error or warning
```

---

## Implementation Priority

### Phase 1 (MVP) - Core Expressions & Statements
- ✅ Literals (`NumericLiteral`, `StringLiteral`, `TrueKeyword`, `FalseKeyword`)
- ✅ Identifiers (`Identifier`)
- ✅ Binary operators (`PlusToken`, `MinusToken`, `LessThanToken`, etc.)
- ✅ Function calls (`CallExpression`)
- ✅ Variable declarations (`VariableDeclaration`)
- ✅ If statements (`IfStatement`)
- ✅ Return statements (`ReturnStatement`)
- ✅ Function declarations (`FunctionDeclaration`)

### Phase 2 - Objects & Refs
- ✅ Object literals (`ObjectLiteralExpression`)
- ✅ Property access (`PropertyAccessExpression`)
- ✅ Property assignment
- ✅ Mutable references

### Phase 3 - Control Flow
- ✅ While loops (`WhileStatement`)
- ✅ For loops (`ForStatement`)
- ✅ Blocks (`Block`)
- ✅ Sequences

### Phase 4 - Advanced Features
- ✅ Classes (`ClassDeclaration`)
- ✅ Interfaces (`InterfaceDeclaration`)
- ✅ Async/await (`AwaitExpression`)
- ✅ Try/catch (`TryStatement`)
- ✅ Destructuring

### Phase 5 - Polish
- Error handling
- Unsupported feature detection
- Optimization
- Pretty printing

---

## Variance System Summary

### Overview

The variance system tracks **access permissions** for variables and fields during verification. This ensures that:
- Immutable variables cannot be written to
- Read-only references cannot be mutated
- Type soundness is preserved across mutations

### Variance Annotations

| Annotation | Meaning | Read | Write | Subtyping |
|------------|---------|------|-------|-----------|
| `%M` | Mutable | ✓ | ✓ | `%M <: %R`, `%M <: %W` |
| `%R` | Read-only | ✓ | ✗ | `%R <: %N` |
| `%W` | Write-only | ✗ | ✓ | `%W <: %N` |
| `%I` | Immutable (identity) | ✓ | ✗ | `%I <: %R` |
| `%N` | Non-accessible | ✗ | ✗ | Top |

### Subtyping Lattice

```
        ⊤ (unrestricted)
       / \
      +   -
     / \ / \
    %M  X  %I
   / \     |
  %R  %W   |
   \ /     |
    %N ----+

Where:
  %M <: %R <: %N
  %M <: %W <: %N
  %I <: %R
  %M ∧ %I = ⊥ (disjoint)
```

### Translation Rules

#### Variable Declaration
```ocaml
(* Immutable *)
let x: T = e  →  x': T @ S ∧ x.acc: %I ∧ x': x

(* Mutable *)
let mut x: T = e  →  x': T @ S ∧ x.acc: %M ∧ x: ⊤
```

#### Variable Read
```
D |- x.acc <: %R
===============================Read
{D} x {ens[r] D ∧ r:x'}
```

#### Variable Write
```
fresh A, B
D1 = x1:A ∧ x2':B ∧ D
D1 |- x1.acc <: %W ∧ x2.acc <: %R ∧ B <: A
------------------------------------------------Assign
{D} x1 := x2 {ens[r] D ∧ r:() ∘_{x1} (x1':x2')}
```

### Implementation Checklist

**Translation Time:**
- [ ] Implement variance analysis pass
  - [ ] Detect reassignments (look for `BinaryExpression` with `EqualsToken`)
  - [ ] Track mutable captures in closures
  - [ ] Handle function parameter mutations
- [ ] Generate variance annotations
  - [ ] `const` and never-reassigned `let` → `%I`
  - [ ] Reassigned `let` → `%M`
  - [ ] Object fields → `%M` (default mutable)
  - [ ] Function parameters → `%I` (always immutable)
- [ ] Emit correct IR
  - [ ] Immutable vars: direct `CLet` binding
  - [ ] Mutable vars: `CLet` with `CRef`
  - [ ] Variable reads: `Var` for immutable, `CRead` for mutable
  - [ ] Assignments: `CWrite` with variance check
- [ ] Generate specifications
  - [ ] Add `x.acc: %M` or `x.acc: %I` to specifications
  - [ ] Include `x': x` for immutable variables
  - [ ] Use `x: ⊤` for mutable variables

**Verification Time (Heifer's responsibility):**
- Check variance constraints at read/write operations
- Verify subtyping relationships
- Ensure heap safety with separation logic

---

## Sources

- [Using the Compiler API](https://github.com/microsoft/TypeScript/wiki/Using-the-Compiler-API)
- [SyntaxKind Enum Reference](https://typestrong.org/typedoc-auto-docs/typedoc/enums/TypeScript.SyntaxKind.html)
- [TypeScript AST Viewer](https://ts-ast-viewer.com/)
- [TypeScript Source Code](https://github.com/microsoft/TypeScript/blob/main/src/compiler/types.ts)
- [Compiler API Examples](https://github.com/growvv/ts-compiler-api-examples)
