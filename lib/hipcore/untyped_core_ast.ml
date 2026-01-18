
[@@@warning "-17"]

type binder = string

type bin_rel_op = GT | LT | EQ | GTEQ | LTEQ
and bin_term_op = Plus | Minus | SConcat | TAnd | TPower | TTimes | TDiv | TOr | TCons

and const =
  | ValUnit
  | Num of int
  | TStr of string
  | Nil
  | TTrue
  | TFalse
and ty_var = string
and name = string
and bty =
  (* The order of constructors is important:
    - base types
    - type constructors
    - type variables
    This is because type unification reduces a type to its "simplest form" given constraints,
    and constructors earlier in the list are treated as "simpler". *)
  (* dynamic type that can unify with anything else. this is an escape hatch for extensions that cannot be typed under the standard ocaml type system *)
  | Top
  | Bot
  | AnyBty
  | UnitBty
  | IntBty
  | BoolBty
  | TyStringBty
  | Tvar of string
  | Consta of const
  | RefBty of bty
  | Tyvar of ty_var
  | Defty of name * ty list
  (* TODO do we need a Poly variant for generics? *)

and ty = 
  | BaseTy of bty
  | Union of ty * ty 
  | Inter of ty * ty 
  | Neg of ty 
  | ArrowTy of ty * ty
  | TAny


and term =
  | Const of const
  | Var of string
  | Rel of bin_rel_op * term * term
  | BinOp of bin_term_op * term * term
  | TNot of term
  | TApp of string * term list
  (* constructor of an inductive datatype *)
  | Construct of string * term list
  (* the string is just an identifier for uniqueness.
     the last param is the name of the result *)
  (* The string seems to be redundant here and I think we should remove it if possible *)
  | TLambda of string * string list * staged_spec option * core_lang option
  | TTuple of term list
  | TRecordTerm of (string * term) list (* Record value with named fields *)
  | TGetField of term * string (* Field projection: record.field *)
  | Type of ty
(* (Label n) _k (*@ spec @*) -> e *)
and core_handler_ops = (string * string option * staged_spec option * core_lang) list
(* x :: xs -> e is represented as ("::", [x, xs], e) *)
(* effect work; let's group them into a single blob *)
and constr_case = {
  ccase_pat : pattern;
  ccase_guard : term option;
  ccase_expr : core_lang
}
and constr_cases = constr_case list
and pattern =
  | PVar of string
  | PConstr of (string * pattern list)
  | PConstant of const
  | PAlias of pattern * string
  | PAny
and tryCatchLemma = (staged_spec * staged_spec option * (*(handlingcases) **) staged_spec) (*tcl_head, tcl_handledCont, tcl_summary*)
and handler_type = Shallow | Deep

and core_value = term
and core_lang =
  | CValue of core_value
  | CLet of string * core_lang * core_lang
  | CSequence of core_lang * core_lang
  | CIfELse of (*core_value*) pi * core_lang * core_lang
  | CFunCall of string * (core_value) list
  | CWrite of string * core_value
  | CRef of core_value
  | CRead of string
  | CAssert of pi * kappa
  | CPerform of string * core_value option
  (* match e with | eff case... | constr case... *)
  | CMatch of handler_type * tryCatchLemma option * core_lang * core_handler_ops * constr_cases
  | CResume of core_value list
  | CLambda of string list * staged_spec option * core_lang
  | CShift of bool * string * core_lang (* bool=true is for shift, and bool=false for shift0 *)
  | CReset of core_lang
  (* Record operations *)
  | CRecord of (string * core_lang) list  (* field_name, field_value pairs - values can be any expression *)
  | CGetField of core_lang * string       (* record expression, field_name *)
  | CSetField of core_lang * string * core_lang  (* record expression, field_name, new_value - all can be any expression *)

(* an occurrence of an effect *)
and instant = string * term list
and pi =
  | True
  | False
  | Atomic of bin_rel_op * term * term
  | And    of pi * pi
  | Or     of pi * pi
  | Imply  of pi * pi
  | Not    of pi
  | Predicate of string * term list
  | Subsumption of term * term
  | Colon of string * term

and kappa =
  | EmptyHeap
    (* x -> -   means x is allocated, and - is encoded as Var "_" *)
  | PointsTo of string * term
  | RecordPointsTo of string * (string * term) list (* loc -> {field1: val1, field2: val2, ...} *)
  | SepConj of kappa * kappa
  (*| MagicWand of kappa * kappa*)

(* a formula which describes a program state *)
and state = pi * kappa

(* v->phi and (Eff arg?-> phi)* *)
and handlingcases = (string * staged_spec) * ((string * string option * staged_spec) list)
and trycatch = (staged_spec * handlingcases)

and staged_spec =
  | Exists of string * staged_spec
  | ForAll of string * staged_spec
  | Require of pi * kappa
  (* ens H /\ P, where P may contain contraints on res *)
  (* | Ens_Pure of pi
  | Ens_Heap of kappa
  | Ens_Result of term *)
  | NormalReturn of pi * kappa
  (* higher-order functions: H /\ P /\ f$(...args, term) *)
  (* this constructor is also used for inductive predicate applications *)
  (* f$(x, y) is HigherOrder(..., ..., (f, [x]), y) *)
  | HigherOrder of string * term list
  | Shift of bool * string * staged_spec * string * staged_spec (* see CShift for meaning of bool *)
  | Reset of staged_spec
  | Sequence of staged_spec * staged_spec
  | Bind of string * staged_spec * staged_spec
  | Disjunction of staged_spec * staged_spec
  (* effects: H /\ P /\ E(...args, v), term is always a placeholder variable *)
  | RaisingEff of (pi * kappa * instant * term)
  (* | IndPred of { name : string; args: term list } *)
  | TryCatch of (pi * kappa * trycatch * term)
  | Multi of staged_spec * staged_spec
  | Assume of staged_spec

(* and spec = stagedSpec list
and disj_spec = spec list *)
(* let compare_ty _ _ = true  *)
[@@deriving
  visitors { variety = "map"; name = "map_spec" },
  visitors { variety = "reduce"; name = "reduce_spec" },
  visitors { variety = "mapreduce"; name = "mapreduce_spec" },
  ord,eq]
