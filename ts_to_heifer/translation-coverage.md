# TypeScript to Separation Type IR: Translation Coverage

## ✅ CAN BE TRANSLATED

### 1. Type Refinement via Type Guards

#### instanceof checks
```typescript
function f(x: any) {
  if (x instanceof Number) {
    return x.valueOf();
  }
}
```
**IR:** `f : req[x] x:Any ens[r] (x:Number ⇒ r:Number)`

#### typeof checks
```typescript
function f(x: any) {
  if (typeof x === "string") {
    return x.length;
  }
}
```
**IR:** `f : req[x] x:Any ens[r] (x:String ⇒ r:Number)`

#### Null/undefined checks
```typescript
function f(x: number | null) {
  if (x !== null) {
    return x + 1;
  }
}
```
**IR:** `f : req[x] x:(Number | Null) ens[r] (x:Number ⇒ r:Number)`

### 2. Flow-Sensitive Type Mutations

#### Variable reassignment with type change
```typescript
function f() {
  let x: any = 42;      // x:Number
  x = "text";           // x:String
  return x;
}
```
**IR:** `f : req[] ens[r] r:String`

#### Heap location mutation
```typescript
function f(ref: {value: any}) {
  ref.value = 42;       // m→Ref(42:Number)
  ref.value = "text";   // m→Ref("text":String)
}
```
**IR:** `f : req[ref] ref→Ref(Any) ens[] ref→Ref("text":String)`

### 3. Conditional Branching

#### If-else with different return types per branch
```typescript
function f(flag: boolean) {
  if (flag) {
    return 42;
  } else {
    return "text";
  }
}
```
**IR:** `f : req[flag] flag:Boolean ens[r] (flag ⇒ r:Number) || (!flag ⇒ r:String)`

#### Multiple branches
```typescript
function f(x: number) {
  if (x > 0) return "positive";
  if (x < 0) return "negative";
  return 0;
}
```
**IR:** `f : req[x] x:Number ens[r] ((x>0 ⇒ r:String) || (x<0 ⇒ r:String) || (x=0 ⇒ r:Number))`

### 4. Separation and Disjoint Heap Locations

#### Non-aliasing references
```typescript
function f(ref1: {value: number}, ref2: {value: number}) {
  ref1.value = 10;
  ref2.value = 20;
}
```
**IR:** `f : req[ref1,ref2] m1→Ref(Number) ∗ m2→Ref(Number) ens[] m1→Ref(10) ∗ m2→Ref(20)`

The `∗` proves `ref1` and `ref2` don't alias!

### 5. Function Preconditions and Postconditions

#### Value-dependent types
```typescript
function f(x: number) {
  if (x > 0) {
    return x - 1;
  }
  return 0;
}
```
**IR:** `f : req[x] x:Number ens[r] ((x>0 ⇒ r:Number ∧ r=x-1) || (x≤0 ⇒ r:Number ∧ r=0))`

### 6. Linear/Affine Resource Types

#### Use-once semantics (with extension)
```typescript
function transfer(resource: Resource): Resource {
  // Consumes old reference, produces new one
  return resource;
}
```
**IR:** `transfer : req[r] m1→Ref(Resource) ens[r] m2→Ref(Resource)` (m1 consumed)

### 7. Exact Value Tracking

#### Constant propagation
```typescript
function f() {
  const x = 42;
  return x;
}
```
**IR:** `f : req[] ens[r] r:Number ∧ r=42`

#### Sequential updates
```typescript
function f() {
  let x = 0;    // x=0
  x = x + 1;    // x=1
  x = x + 1;    // x=2
  return x;
}
```
**IR:** `f : req[] ens[r] r:Number ∧ r=2`

### 8. Object Field Mutations

#### Field-level tracking
```typescript
function f(obj: {x: any, y: any}) {
  obj.x = 42;
  obj.y = "text";
}
```
**IR:** `f : req[obj] mx→Ref(Any) ∗ my→Ref(Any) ens[] mx→Ref(42:Number) ∗ my→Ref("text":String)`

### 9. Array Element Mutations

#### Index-based updates
```typescript
function f(arr: any[]) {
  arr[0] = 42;
  arr[1] = "text";
}
```
**IR:** `f : req[arr] m0→Ref(Any) ∗ m1→Ref(Any) ens[] m0→Ref(42:Number) ∗ m1→Ref("text":String)`

### 10. Polymorphic Functions with Constraints

#### Generic with bounds
```typescript
function f<T extends {id: number}>(x: T): number {
  return x.id;
}
```
**IR:** `∀T:{id:Number}. f : req[x] x:T ens[r] r:Number`

---

## Not trivial

### 1. Higher-Order Functions (without extension)

#### Function as argument
```typescript
function map<T, U>(arr: T[], fn: (x: T) => U): U[] {
  return arr.map(fn);
}
```
**Problem:** Need function types in IR: `(T → U)`

**Possible Extension:**
```
map : ∀T,U. req[arr,fn] arr:Array<T> ∗ fn:(T → U)
      ens[r] r:Array<U>
```

### 2. Closures with Captured Variables

#### Closure capturing mutable state
```typescript
function counter() {
  let count = 0;
  return () => ++count;
}
```
**Problem:** Returned function closes over `count` heap location. Need existential types or continuation-passing style.

**Possible Extension:**
```
counter : req[] ens[r] ∃m. (m→Ref(0) ∗ r:(Unit → Number) ∧ captures(r, m))
```

### 3. Recursive Functions

#### Direct recursion
```typescript
function factorial(n: number): number {
  if (n <= 1) return 1;
  return n * factorial(n - 1);
}
```
**Problem:** Need recursive specifications with invariants/variants.

**Possible Extension:** Use loop invariants or inductive predicates
```
factorial : req[n] n:Number ∧ n≥0 ens[r] r:Number ∧ r=n!
  where n! defined inductively
```

### 4. Complex Loop Invariants

#### While loops with mutation
```typescript
function sum(n: number): number {
  let acc = 0;
  let i = 0;
  while (i < n) {
    acc += i;
    i++;
  }
  return acc;
}
```
**Problem:** Need loop invariants: `acc = Σ[0..i)` and variant: `n - i`

**Possible Extension:**
```
sum : req[n] n:Number ∧ n≥0 ens[r] r:Number ∧ r=Σ[0..n)
  invariant: acc=Σ[0..i) ∧ 0≤i≤n
  variant: n-i
```

### 5. Promises and Async/Await

#### Asynchronous code
```typescript
async function fetchData(): Promise<string> {
  const response = await fetch("/api");
  return response.text();
}
```
**Problem:** Need temporal logic or effect types to model async behavior.

**Possible Extension:** Effect system
```
fetchData : req[] ens[r] r:Future<String> with effect IO
```

### 6. Exceptions and Try-Catch

#### Exception handling
```typescript
function parse(s: string): number {
  try {
    return parseInt(s);
  } catch (e) {
    return 0;
  }
}
```
**Problem:** Need sum types or effect rows to model exceptions.

**Possible Extension:**
```
parse : req[s] s:String ens[r] r:(Number | Exception)
  or with effects: req[s] s:String ens[r] r:Number with effect {Throw}
```

### 7. Prototype Manipulation and Dynamic Properties

#### Dynamic property access
```typescript
function f(obj: any, key: string) {
  return obj[key];
}
```
**Problem:** Cannot statically track arbitrary string keys.

**Workaround:** Use dependent types
```
f : req[obj,key] obj:{[key]:T} ∗ key:String ens[r] r:T
```

### 8. Generators and Iterators

#### Generator function
```typescript
function* range(n: number) {
  for (let i = 0; i < n; i++) {
    yield i;
  }
}
```
**Problem:** Generators are stateful coroutines, need session types or coroutine specifications.

### 9. Class Inheritance and Method Dispatch

#### Virtual method calls
```typescript
class Animal {
  speak() { return "..."; }
}
class Dog extends Animal {
  speak() { return "woof"; }
}
function f(a: Animal) {
  return a.speak();
}
```
**Problem:** Dynamic dispatch depends on runtime type. Need subtyping in IR.

**Possible Extension:** Refinement types
```
f : req[a] a:Animal ens[r] (a:Dog ⇒ r="woof") || (a:Cat ⇒ r="meow") || ...
```

### 10. Type Assertions and Casts

#### Unsafe casting
```typescript
function f(x: any) {
  const y = x as string;
  return y.length;
}
```
**Problem:** Type assertion bypasses type system. IR would need "trust me" operator or runtime checks.

**Options:**
- Reject: Type error if `x` not proven to be `String`
- Runtime check: Insert `assert(x:String)`

### 11. Mutually Recursive Types

#### Cyclic type definitions
```typescript
type Tree = {
  value: number;
  children: Tree[];
}
```
**Problem:** Need recursive type definitions or iso-recursive types in IR.

**Possible Extension:**
```
μTree. {value: Number, children: Array<Tree>}
```

### 12. Module System and Imports

#### Cross-module references
```typescript
import { f } from "./other";
function g(x: number) {
  return f(x);
}
```
**Problem:** Need module signatures and composition.

**Possible Extension:**
```
module Other {
  val f : Number → String
}
using Other
g : req[x] x:Number ens[r] r:String
```

### 13. Reflection and `eval`

#### Runtime code evaluation
```typescript
function f(code: string) {
  return eval(code);
}
```
**Problem:** Cannot statically analyze dynamically generated code.

**Solution:** Reject or type as `Any → Any`

### 14. Varargs and Rest Parameters

#### Variable arguments
```typescript
function sum(...nums: number[]): number {
  return nums.reduce((a, b) => a + b, 0);
}
```
**Problem:** Array length unknown statically.

**Possible Extension:** Dependent types
```
sum : ∀n. req[nums] nums:Array<Number> ∧ |nums|=n ens[r] r:Number ∧ r=Σnums
```

### 15. Intersection and Union Types (Complex Cases)

#### Intersection types
```typescript
type A = { x: number };
type B = { y: string };
function f(obj: A & B) {
  return obj.x + obj.y.length;
}
```
**Problem:** Intersection types create complex subtyping constraints.

**Possible Extension:**
```
f : req[obj] obj:(A ∧ B) ens[r] r:Number
  where A ∧ B = {x:Number, y:String}
```

---

## 🟡 CHALLENGING BUT POSSIBLE (with extensions)

### 1. Pattern Matching (if TypeScript adds it)
Can be modeled as nested conditionals with refinement.

### 2. Algebraic Data Types
If encoded properly, can use case analysis similar to `instanceof`.

### 3. First-Class Functions (Partial Application)
Need function types and closure conversion in IR.

### 4. Effect Systems
Track side effects (IO, exceptions, state) with effect annotations.

### 5. Dependent Types
Types depending on values (like array lengths) require dependent types in IR.

---

## Summary Table

| Feature | Translatable? | Difficulty | Extension Needed? |
|---------|--------------|------------|-------------------|
| Type guards (`instanceof`, `typeof`) | ✅ Yes | Easy | No |
| Flow-sensitive typing | ✅ Yes | Easy | No |
| Heap mutations (`m→Ref(T)`) | ✅ Yes | Easy | No |
| Spatial separation (`∗`) | ✅ Yes | Medium | No |
| Conditionals (if/else) | ✅ Yes | Easy | No |
| Exact value tracking | ✅ Yes | Medium | No |
| Linear/affine types | ✅ Yes | Medium | Minor |
| Simple loops | 🟡 Partial | Hard | Invariants |
| Higher-order functions | ❌ Hard | Hard | Function types |
| Closures | ❌ Hard | Hard | Existentials |
| Recursion | ❌ Hard | Hard | Inductive specs |
| Async/await | ❌ Very Hard | Very Hard | Temporal logic |
| Exceptions | ❌ Hard | Medium | Effect types |
| Generators | ❌ Very Hard | Very Hard | Session types |
| Dynamic properties | ❌ Hard | Hard | Dependent types |
| Type casts | 🟡 Partial | Medium | Runtime checks |
| Class inheritance | 🟡 Partial | Hard | Subtyping |
| Reflection/eval | ❌ Impossible | N/A | N/A |

---

## Recommended Translation Strategy

### Phase 1: Core Features (Current Implementation)
- ✅ Type guards and refinement
- ✅ Flow-sensitive typing
- ✅ Heap mutations
- ✅ Conditionals
- ✅ Basic value tracking

### Phase 2: Extensions
- 🔧 Simple loops with invariants
- 🔧 Function types for higher-order functions
- 🔧 Basic recursion with termination checking

### Phase 3: Advanced (Research)
- 🔬 Full dependent types
- 🔬 Effect systems
- 🔬 Session types for coroutines
