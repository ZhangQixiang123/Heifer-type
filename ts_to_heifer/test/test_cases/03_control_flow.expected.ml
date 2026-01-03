(* Expected Heifer IR translation for 03_control_flow.ts *)

open Hipcore_typed.Typed_core_ast
open Hipcore_common.Types

(* function abs(x: number): number {
     if (x < 0) { return -x; }
     return x;
   } *)
let abs_expected = `Meth (
  "abs",
  [("x", Int)],
  None,
  { core_desc = CIfElse (
      Atomic (LT, { term_desc = Var "x"; term_type = Int },
                  { term_desc = Const (Num 0); term_type = Int }),
      { core_desc = CValue {
          term_desc = BinOp (Minus,
            { term_desc = Const (Num 0); term_type = Int },
            { term_desc = Var "x"; term_type = Int });
          term_type = Int };
        core_type = Int },
      { core_desc = CValue { term_desc = Var "x"; term_type = Int };
        core_type = Int }
    );
    core_type = Int },
  [],
  None
)

(* function max(a: number, b: number): number {
     if (a > b) { return a; } else { return b; }
   } *)
let max_expected = `Meth (
  "max",
  [("a", Int); ("b", Int)],
  None,
  { core_desc = CIfElse (
      Atomic (GT, { term_desc = Var "a"; term_type = Int },
                  { term_desc = Var "b"; term_type = Int }),
      { core_desc = CValue { term_desc = Var "a"; term_type = Int };
        core_type = Int },
      { core_desc = CValue { term_desc = Var "b"; term_type = Int };
        core_type = Int }
    );
    core_type = Int },
  [],
  None
)

(* function min(a: number, b: number): number {
     return a < b ? a : b;
   } *)
let min_expected = `Meth (
  "min",
  [("a", Int); ("b", Int)],
  None,
  { core_desc = CIfElse (
      Atomic (LT, { term_desc = Var "a"; term_type = Int },
                  { term_desc = Var "b"; term_type = Int }),
      { core_desc = CValue { term_desc = Var "a"; term_type = Int };
        core_type = Int },
      { core_desc = CValue { term_desc = Var "b"; term_type = Int };
        core_type = Int }
    );
    core_type = Int },
  [],
  None
)

(* function sign(x: number): string {
     if (x > 0) { return "positive"; }
     else if (x < 0) { return "negative"; }
     else { return "zero"; }
   } *)
let sign_expected = `Meth (
  "sign",
  [("x", Int)],
  None,
  { core_desc = CIfElse (
      Atomic (GT, { term_desc = Var "x"; term_type = Int },
                  { term_desc = Const (Num 0); term_type = Int }),
      { core_desc = CValue { term_desc = Const (TStr "positive"); term_type = TyString };
        core_type = TyString },
      { core_desc = CIfElse (
          Atomic (LT, { term_desc = Var "x"; term_type = Int },
                      { term_desc = Const (Num 0); term_type = Int }),
          { core_desc = CValue { term_desc = Const (TStr "negative"); term_type = TyString };
            core_type = TyString },
          { core_desc = CValue { term_desc = Const (TStr "zero"); term_type = TyString };
            core_type = TyString }
        );
        core_type = TyString }
    );
    core_type = TyString },
  [],
  None
)

(* function safe_divide(a: number, b: number): number {
     if (b === 0) { return 0; }
     return a / b;
   } *)
let safe_divide_expected = `Meth (
  "safe_divide",
  [("a", Int); ("b", Int)],
  None,
  { core_desc = CIfElse (
      Atomic (EQ, { term_desc = Var "b"; term_type = Int },
                  { term_desc = Const (Num 0); term_type = Int }),
      { core_desc = CValue { term_desc = Const (Num 0); term_type = Int };
        core_type = Int },
      { core_desc = CValue {
          term_desc = BinOp (TDiv,
            { term_desc = Var "a"; term_type = Int },
            { term_desc = Var "b"; term_type = Int });
          term_type = Int };
        core_type = Int }
    );
    core_type = Int },
  [],
  None
)
