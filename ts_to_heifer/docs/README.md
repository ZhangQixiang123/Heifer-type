# TypeScript to Heifer - Documentation

## Overview

This directory contains comprehensive documentation for the TypeScript to Heifer translator, including design documents, implementation guides, and reference materials.

---

## 📚 Documentation Index

### Getting Started

1. **[GETTING_STARTED_AUTO_SPEC.md](GETTING_STARTED_AUTO_SPEC.md)** ⭐ **START HERE**
   - Step-by-step implementation guide
   - How to build automatic specification generation
   - Testing and debugging tips
   - **Best for:** Implementing the auto-spec feature

### Core Design Documents

2. **[AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md)**
   - Complete design for automatic specification generation
   - Philosophy: Extract specs from TypeScript types
   - Detailed examples and patterns
   - Implementation roadmap with phases
   - **Best for:** Understanding the overall approach

3. **[NODE_TRANSLATION.md](NODE_TRANSLATION.md)**
   - Complete mapping of TypeScript AST nodes to Heifer IR
   - Translation rules for every SyntaxKind
   - Variance system details
   - Binary operators, control flow, classes, etc.
   - **Best for:** Reference when translating specific TypeScript features

### Quick References

4. **[SPEC_QUICK_REFERENCE.md](SPEC_QUICK_REFERENCE.md)**
   - Cheat sheet for specification generation
   - Common patterns and examples
   - Type mappings table
   - Testing checklist
   - **Best for:** Quick lookup while coding

---

## 🎯 Quick Navigation by Task

### "I want to understand how auto-spec generation works"
→ Read [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md)

### "I want to implement auto-spec generation"
→ Follow [GETTING_STARTED_AUTO_SPEC.md](GETTING_STARTED_AUTO_SPEC.md)

### "I need to translate a specific TypeScript construct"
→ Look up in [NODE_TRANSLATION.md](NODE_TRANSLATION.md)

### "I need a quick example or syntax"
→ Check [SPEC_QUICK_REFERENCE.md](SPEC_QUICK_REFERENCE.md)

---

## 🔑 Key Concepts

### 1. Automatic Specification Generation

**Problem:** Heifer requires verification specifications, but writing them manually is tedious.

**Solution:** Extract specifications automatically from TypeScript's type system!

```typescript
function add(x: number, y: number): number {
  return x + y;
}
```
↓ Automatically becomes:
```ocaml
let add x y = (x + y)
 (*@ req x:#int /\ y:#int ; ens res:#int /\ res = (x + y) @*)
```

**See:** [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md) for full details.

### 2. Variance Analysis

**Problem:** TypeScript variables can be mutable or immutable, affecting translation.

**Solution:** Analyze the AST to detect reassignments and allocate refs only when needed.

```typescript
const x = 10;      // Immutable
let y = 20;        // Immutable (never reassigned)
let z = 30;
z = 40;            // Mutable (reassigned)
```
↓
```ocaml
let x = 10 in           (* Direct binding *)
let y = 20 in           (* Direct binding *)
let z = ref 30 in       (* Reference cell *)
z := 40                 (* Mutation *)
```

**See:** [NODE_TRANSLATION.md](NODE_TRANSLATION.md), Section 4b "Variance Examples"

### 3. Type System Mapping

TypeScript types are converted to Heifer types:

| TypeScript | Heifer |
|------------|--------|
| `number` | `#int` |
| `string` | `#string` |
| `boolean` | `#bool` |
| `number \| string` | `(#int \| #string)` |
| `{x: number}` | `{x: int ref}` |
| `number[]` | `#list<int>` |

**See:** [SPEC_QUICK_REFERENCE.md](SPEC_QUICK_REFERENCE.md), "Type Mappings"

### 4. Heap Specifications

Objects and their mutations are tracked using separation logic:

```typescript
interface Point { x: number; y: number }
function moveX(p: Point, dx: number): void {
  p.x = p.x + dx;
}
```
↓
```ocaml
(*@ req p:#point /\ p.x |-> x0 /\ p.y |-> y0 /\ dx:#int ;
    ens p.x |-> (x0 + dx) * p.y |-> y0 @*)
```

**See:** [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md), Section "Object Types → Heap Structure"

---

## 📖 Reading Order

### For First-Time Users

1. Start with [GETTING_STARTED_AUTO_SPEC.md](GETTING_STARTED_AUTO_SPEC.md)
   - Understand the implementation steps
   - Set up your development environment
   - Run the first test

2. Read [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md)
   - Understand the design philosophy
   - See comprehensive examples
   - Learn about different phases

3. Keep [SPEC_QUICK_REFERENCE.md](SPEC_QUICK_REFERENCE.md) open
   - Quick lookup for syntax
   - Common patterns
   - Testing examples

4. Use [NODE_TRANSLATION.md](NODE_TRANSLATION.md) as reference
   - Look up specific TypeScript features
   - Understand translation rules
   - Check variance annotations

### For Implementation

1. **Phase 1: Basic Specs**
   - Follow [GETTING_STARTED_AUTO_SPEC.md](GETTING_STARTED_AUTO_SPEC.md), Steps 1-4
   - Implement parameter types → preconditions
   - Implement return types → postconditions

2. **Phase 2: Value Constraints**
   - Read [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md), "Phase 2"
   - Implement return expression analysis
   - Generate value constraints

3. **Phase 3: Control Flow**
   - Read [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md), "Phase 3"
   - Handle conditional returns
   - Generate implications

4. **Phase 4: Heap Formulas**
   - Read [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md), "Phase 4"
   - Track object mutations
   - Generate separation logic

---

## 🔧 Implementation Status

### ✅ Documented (Ready to Implement)
- Automatic specification generation design
- Type system mapping strategy
- Value constraint extraction
- Heap formula generation

### 🚧 In Progress
- Basic type → specification mapping
- Function specification generation

### 📋 TODO
- Enhanced postconditions with value constraints
- Conditional specification generation
- Object heap tracking
- Loop invariant inference

**Track Progress:** See [../STATUS.md](../STATUS.md)

---

## 💡 Examples Gallery

### Example 1: Simple Function

**TypeScript:**
```typescript
function square(x: number): number {
  return x * x;
}
```

**Generated Heifer:**
```ocaml
let square x = (x * x)
 (*@ req x:#int ; ens res:#int /\ res = (x * x) @*)
```

### Example 2: Nullable Types

**TypeScript:**
```typescript
function getLength(s: string | null): number {
  if (s !== null) {
    return s.length;
  }
  return 0;
}
```

**Generated Heifer:**
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

### Example 3: Object Mutation

**TypeScript:**
```typescript
interface Counter { count: number }
function increment(c: Counter): void {
  c.count = c.count + 1;
}
```

**Generated Heifer:**
```ocaml
type counter = { count: int ref }
let increment c = c.count := (!c.count + 1)
 (*@ req c:#counter /\ c.count |-> n ;
     ens c.count |-> (n + 1) @*)
```

**More examples:** See each document's examples section.

---

## 🎓 Learning Path

### Beginner (New to the Project)
1. Read project [README.md](../README.md)
2. Understand variance analysis concept
3. Follow [GETTING_STARTED_AUTO_SPEC.md](GETTING_STARTED_AUTO_SPEC.md)

### Intermediate (Implementing Features)
1. Study [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md) design
2. Reference [NODE_TRANSLATION.md](NODE_TRANSLATION.md) for specific features
3. Use [SPEC_QUICK_REFERENCE.md](SPEC_QUICK_REFERENCE.md) for syntax

### Advanced (Extending the System)
1. Design new specification generation strategies
2. Implement advanced features (loops, recursion, effects)
3. Contribute to documentation

---

## 🔍 Common Questions

### Q: Why automatic specification generation?

**A:** Heifer needs specifications to verify code, but:
- Writing specs manually is tedious
- TypeScript already has type information
- We can extract specs from types automatically!

Just like variance analysis automatically detects mutable variables, spec generation automatically creates verification conditions.

### Q: What TypeScript features are supported?

**A:** See [NODE_TRANSLATION.md](NODE_TRANSLATION.md) for complete coverage:
- ✅ Basic types, operators, control flow
- ✅ Functions with type annotations
- 🚧 Objects, classes (in progress)
- 📋 Loops, arrays, async (planned)

### Q: How do I test my implementation?

**A:** Follow testing strategy in [GETTING_STARTED_AUTO_SPEC.md](GETTING_STARTED_AUTO_SPEC.md):
1. Create TypeScript test files
2. Run through translator
3. Check generated specs
4. Verify with Heifer

### Q: Where do I start coding?

**A:** Follow [GETTING_STARTED_AUTO_SPEC.md](GETTING_STARTED_AUTO_SPEC.md), Step 1:
1. Create `lib/spec_generator.ml`
2. Update `lib/dune`
3. Integrate with `lib/translator.ml`
4. Test!

---

## 📝 Contributing to Documentation

### Adding New Documentation

1. Create `.md` file in `docs/`
2. Follow existing structure and style
3. Add entry to this README's index
4. Update navigation sections

### Improving Existing Docs

1. Keep examples up-to-date
2. Add clarifications where needed
3. Update implementation status
4. Add more examples

---

## 🔗 External Resources

- **TypeScript Compiler API:** https://github.com/microsoft/TypeScript/wiki/Using-the-Compiler-API
- **TypeScript AST Viewer:** https://ts-ast-viewer.com/
- **SyntaxKind Reference:** https://typestrong.org/typedoc-auto-docs/typedoc/enums/TypeScript.SyntaxKind.html
- **Heifer Project:** (Link to Heifer documentation)

---

## 📞 Need Help?

1. Check the relevant documentation file
2. Look at examples in that document
3. Check [../STATUS.md](../STATUS.md) for current state
4. Review [../README.md](../README.md) for setup

---

**Last Updated:** December 2024

**Status:** Auto-spec generation designed and documented, ready for implementation.

See [../STATUS.md](../STATUS.md) for current implementation status.
