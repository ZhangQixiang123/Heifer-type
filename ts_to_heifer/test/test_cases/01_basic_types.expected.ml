(* Expected Heifer IR translation for 01_basic_types.ts *)
(* Using Hipcore_typed.Typed_core_ast constructors *)

open Hipcore_typed.Typed_core_ast
open Hipcore_common.Types

(* function identity_number(x: number): number { return x; } *)
let identity_number_expected = `Meth (
  "identity_number",
  [("x", Int)],
  None,
  { core_desc = CValue { term_desc = Var "x"; term_type = Int };
    core_type = Int },
  [],
  None
)

(* function identity_string(s: string): string { return s; } *)
let identity_string_expected = `Meth (
  "identity_string",
  [("s", TyString)],
  None,
  { core_desc = CValue { term_desc = Var "s"; term_type = TyString };
    core_type = TyString },
  [],
  None
)

(* function identity_bool(b: boolean): boolean { return b; } *)
let identity_bool_expected = `Meth (
  "identity_bool",
  [("b", Bool)],
  None,
  { core_desc = CValue { term_desc = Var "b"; term_type = Bool };
    core_type = Bool },
  [],
  None
)

(* function log_message(msg: string): void { console.log(msg); } *)
(* console.log treated as no-op for now *)
let log_message_expected = `Meth (
  "log_message",
  [("msg", TyString)],
  None,
  { core_desc = CValue { term_desc = Const ValUnit; term_type = Unit };
    core_type = Unit },
  [],
  None
)

(* function add(x: number, y: number): number { return x + y; } *)
let add_expected = `Meth (
  "add",
  [("x", Int); ("y", Int)],
  None,
  { core_desc = CValue {
      term_desc = BinOp (Plus,
        { term_desc = Var "x"; term_type = Int },
        { term_desc = Var "y"; term_type = Int });
      term_type = Int };
    core_type = Int },
  [],
  None
)

(* function format(prefix: string, value: number): string *)
(* Note: value.toString() not yet supported - simplified *)
let format_expected = `Meth (
  "format",
  [("prefix", TyString); ("value", Int)],
  None,
  (* Simplified - string concatenation with number conversion *)
  { core_desc = CValue { term_desc = Var "prefix"; term_type = TyString };
    core_type = TyString },
  [],
  None
)
