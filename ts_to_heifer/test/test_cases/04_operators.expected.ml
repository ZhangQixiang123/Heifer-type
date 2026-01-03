(* Expected Heifer IR translation for 04_operators.ts *)

open Hipcore_typed.Typed_core_ast
open Hipcore_common.Types

(* Arithmetic operators *)
let add_nums_expected = `Meth (
  "add_nums",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (Plus,
        { term_desc = Var "x"; term_type = Int },
        { term_desc = Var "y"; term_type = Int });
      term_type = Int };
    core_type = Int },
  [], None
)

let subtract_expected = `Meth (
  "subtract",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (Minus,
        { term_desc = Var "x"; term_type = Int },
        { term_desc = Var "y"; term_type = Int });
      term_type = Int };
    core_type = Int },
  [], None
)

let multiply_expected = `Meth (
  "multiply",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (TTimes,
        { term_desc = Var "x"; term_type = Int },
        { term_desc = Var "y"; term_type = Int });
      term_type = Int };
    core_type = Int },
  [], None
)

let divide_expected = `Meth (
  "divide",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (TDiv,
        { term_desc = Var "x"; term_type = Int },
        { term_desc = Var "y"; term_type = Int });
      term_type = Int };
    core_type = Int },
  [], None
)

(* Comparison operators *)
let less_than_expected = `Meth (
  "less_than",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CIfElse (
      Atomic (LT, { term_desc = Var "x"; term_type = Int },
                  { term_desc = Var "y"; term_type = Int }),
      { core_desc = CValue { term_desc = Const TTrue; term_type = Bool };
        core_type = Bool },
      { core_desc = CValue { term_desc = Const TFalse; term_type = Bool };
        core_type = Bool }
    );
    core_type = Bool },
  [], None
)

let greater_or_equal_expected = `Meth (
  "greater_or_equal",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CIfElse (
      Atomic (GTEQ, { term_desc = Var "x"; term_type = Int },
                    { term_desc = Var "y"; term_type = Int }),
      { core_desc = CValue { term_desc = Const TTrue; term_type = Bool };
        core_type = Bool },
      { core_desc = CValue { term_desc = Const TFalse; term_type = Bool };
        core_type = Bool }
    );
    core_type = Bool },
  [], None
)

let equals_expected = `Meth (
  "equals",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CIfElse (
      Atomic (EQ, { term_desc = Var "x"; term_type = Int },
                  { term_desc = Var "y"; term_type = Int }),
      { core_desc = CValue { term_desc = Const TTrue; term_type = Bool };
        core_type = Bool },
      { core_desc = CValue { term_desc = Const TFalse; term_type = Bool };
        core_type = Bool }
    );
    core_type = Bool },
  [], None
)

let not_equals_expected = `Meth (
  "not_equals",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CIfElse (
      Not (Atomic (EQ, { term_desc = Var "x"; term_type = Int },
                       { term_desc = Var "y"; term_type = Int })),
      { core_desc = CValue { term_desc = Const TTrue; term_type = Bool };
        core_type = Bool },
      { core_desc = CValue { term_desc = Const TFalse; term_type = Bool };
        core_type = Bool }
    );
    core_type = Bool },
  [], None
)

(* Logical operators - note: these operate on boolean values *)
let and_op_expected = `Meth (
  "and_op",
  [("a", Bool); ("b", Bool)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (TAnd,
        { term_desc = Var "a"; term_type = Bool },
        { term_desc = Var "b"; term_type = Bool });
      term_type = Bool };
    core_type = Bool },
  [], None
)

let or_op_expected = `Meth (
  "or_op",
  [("a", Bool); ("b", Bool)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (TOr,
        { term_desc = Var "a"; term_type = Bool },
        { term_desc = Var "b"; term_type = Bool });
      term_type = Bool };
    core_type = Bool },
  [], None
)

(* Unary minus: -x becomes 0 - x *)
let negate_expected = `Meth (
  "negate",
  [("x", Int)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (Minus,
        { term_desc = Const (Num 0); term_type = Int },
        { term_desc = Var "x"; term_type = Int });
      term_type = Int };
    core_type = Int },
  [], None
)

(* Complex expression: (x + y) * z - (x - y) / 2 *)
let complex_expr_expected = `Meth (
  "complex_expr",
  [("x", Int); ("y", Int); ("z", Int)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (Minus,
        { term_desc = BinOp (TTimes,
            { term_desc = BinOp (Plus,
                { term_desc = Var "x"; term_type = Int },
                { term_desc = Var "y"; term_type = Int });
              term_type = Int },
            { term_desc = Var "z"; term_type = Int });
          term_type = Int },
        { term_desc = BinOp (TDiv,
            { term_desc = BinOp (Minus,
                { term_desc = Var "x"; term_type = Int },
                { term_desc = Var "y"; term_type = Int });
              term_type = Int },
            { term_desc = Const (Num 2); term_type = Int });
          term_type = Int });
      term_type = Int };
    core_type = Int },
  [], None
)
