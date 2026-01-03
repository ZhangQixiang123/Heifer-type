(* Expected Heifer IR translation for 05_variables.ts *)

open Hipcore_typed.Typed_core_ast
open Hipcore_common.Types

(* function const_variable(): number {
     const x: number = 10;
     return x + 5;
   }
   x is immutable (never reassigned) *)
let const_variable_expected = `Meth (
  "const_variable",
  [],
  None,
  { core_desc = CLet (
      ("x", Int),
      { core_desc = CValue { term_desc = Const (Num 10); term_type = Int };
        core_type = Int },
      { core_desc = CValue {
          term_desc = BinOp (Plus,
            { term_desc = Var "x"; term_type = Int },
            { term_desc = Const (Num 5); term_type = Int });
          term_type = Int };
        core_type = Int }
    );
    core_type = Int },
  [], None
)

(* function immutable_let(): number {
     let x: number = 10;
     let y: number = 20;
     return x + y;
   }
   Both x and y are immutable (never reassigned) *)
let immutable_let_expected = `Meth (
  "immutable_let",
  [],
  None,
  { core_desc = CLet (
      ("x", Int),
      { core_desc = CValue { term_desc = Const (Num 10); term_type = Int };
        core_type = Int },
      { core_desc = CLet (
          ("y", Int),
          { core_desc = CValue { term_desc = Const (Num 20); term_type = Int };
            core_type = Int },
          { core_desc = CValue {
              term_desc = BinOp (Plus,
                { term_desc = Var "x"; term_type = Int },
                { term_desc = Var "y"; term_type = Int });
              term_type = Int };
            core_type = Int }
        );
        core_type = Int }
    );
    core_type = Int },
  [], None
)

(* function mutable_variable(): number {
     let x: number = 10;
     x = x + 5;
     return x;
   }
   x is mutable (reassigned) - allocated as ref *)
let mutable_variable_expected = `Meth (
  "mutable_variable",
  [],
  None,
  { core_desc = CLet (
      ("x", TConstr ("ref", [Int])),
      { core_desc = CRef { term_desc = Const (Num 10); term_type = Int };
        core_type = TConstr ("ref", [Int]) },
      { core_desc = CSequence (
          { core_desc = CWrite ("x",
              { term_desc = BinOp (Plus,
                  { term_desc = Var "x"; term_type = Int },
                  { term_desc = Const (Num 5); term_type = Int });
                term_type = Int });
            core_type = Unit },
          { core_desc = CRead "x";
            core_type = Int }
        );
        core_type = Int }
    );
    core_type = Int },
  [], None
)

(* function multiple_mutations(): number {
     let sum: number = 0;
     sum = sum + 10;
     sum = sum + 20;
     sum = sum + 30;
     return sum;
   } *)
let multiple_mutations_expected = `Meth (
  "multiple_mutations",
  [],
  None,
  { core_desc = CLet (
      ("sum", TConstr ("ref", [Int])),
      { core_desc = CRef { term_desc = Const (Num 0); term_type = Int };
        core_type = TConstr ("ref", [Int]) },
      { core_desc = CSequence (
          { core_desc = CWrite ("sum",
              { term_desc = BinOp (Plus,
                  { term_desc = Var "sum"; term_type = Int },
                  { term_desc = Const (Num 10); term_type = Int });
                term_type = Int });
            core_type = Unit },
          { core_desc = CSequence (
              { core_desc = CWrite ("sum",
                  { term_desc = BinOp (Plus,
                      { term_desc = Var "sum"; term_type = Int },
                      { term_desc = Const (Num 20); term_type = Int });
                    term_type = Int });
                core_type = Unit },
              { core_desc = CSequence (
                  { core_desc = CWrite ("sum",
                      { term_desc = BinOp (Plus,
                          { term_desc = Var "sum"; term_type = Int },
                          { term_desc = Const (Num 30); term_type = Int });
                        term_type = Int });
                    core_type = Unit },
                  { core_desc = CRead "sum";
                    core_type = Int }
                );
                core_type = Int }
            );
            core_type = Int }
        );
        core_type = Int }
    );
    core_type = Int },
  [], None
)

(* function mixed_variables(): number {
     const a: number = 10;
     let b: number = 20;
     b = b + a;
     const c: number = b * 2;
     return c;
   }
   a and c are immutable, b is mutable *)
let mixed_variables_expected = `Meth (
  "mixed_variables",
  [],
  None,
  { core_desc = CLet (
      ("a", Int),
      { core_desc = CValue { term_desc = Const (Num 10); term_type = Int };
        core_type = Int },
      { core_desc = CLet (
          ("b", TConstr ("ref", [Int])),
          { core_desc = CRef { term_desc = Const (Num 20); term_type = Int };
            core_type = TConstr ("ref", [Int]) },
          { core_desc = CSequence (
              { core_desc = CWrite ("b",
                  { term_desc = BinOp (Plus,
                      { term_desc = Var "b"; term_type = Int },
                      { term_desc = Var "a"; term_type = Int });
                    term_type = Int });
                core_type = Unit },
              { core_desc = CLet (
                  ("c", Int),
                  { core_desc = CValue {
                      term_desc = BinOp (TTimes,
                        { term_desc = Var "b"; term_type = Int },
                        { term_desc = Const (Num 2); term_type = Int });
                      term_type = Int };
                    core_type = Int },
                  { core_desc = CValue { term_desc = Var "c"; term_type = Int };
                    core_type = Int }
                );
                core_type = Int }
            );
            core_type = Int }
        );
        core_type = Int }
    );
    core_type = Int },
  [], None
)
