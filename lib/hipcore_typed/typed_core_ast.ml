open Hipcore



[@@@warning "-17"]
(* can also appear in pi *)
type bin_rel_op = Hiptypes.bin_rel_op =  GT | LT | EQ | GTEQ | LTEQ
and binder = string * typ
and bin_term_op = Hiptypes.bin_term_op = Plus | Minus | SConcat | TAnd | TPower | TTimes | TDiv | TOr | TCons
and const = Hiptypes.const =
  | ValUnit
  | Num of int
  | TStr of string
  | Nil
  | TTrue
  | TFalse
  (* TODO do we need a Poly variant for generics? *)

and ty_var = string

and name =string

and bty = Untyped_core_ast.bty =
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

and ty = Untyped_core_ast.ty =
  | BaseTy of bty
  | Union of ty * ty 
  | Inter of ty * ty 
  | Neg of ty 
  | ArrowTy of ty * ty
  | TAny

and term_desc =
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
  | TLambda of string * binder list * staged_spec option * core_lang option
  (* unused *)
  | TTuple of term list
  | TRecordTerm of (string * term) list (* Record value with named fields: {x: 10, y: 20} *)
  | TGetField of term * string (* Field projection: record.field *)
  | Type of ty
and term =
  {
    term_desc: term_desc;
    term_type: typ
  }

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

and pattern_desc =
  | PVar of binder
  | PConstr of (string * pattern list)
  | PConstant of const
  | PAlias of pattern * string
  | PAny

and pattern =
  {
    pattern_desc: pattern_desc;
    pattern_type: typ
  }
and tryCatchLemma = (staged_spec * staged_spec option * (*(handlingcases) **) staged_spec) (*tcl_head, tcl_handledCont, tcl_summary*)
and handler_type = Hiptypes.handler_type = Shallow | Deep

and core_value = term
and core_lang_desc =
  | CValue of core_value
  | CLet of binder * core_lang * core_lang
  | CSequence of core_lang * core_lang
  | CIfElse of (*core_value*) pi * core_lang * core_lang
  | CFunCall of string * (core_value) list
  | CWrite of string * core_value
  | CRef of core_value
  | CRead of string
  | CAssert of pi * kappa
  (* effect start *)
  | CPerform of string * core_value option
  (* match e with | eff case... | constr case... *)
  | CMatch of handler_type * tryCatchLemma option * core_lang * core_handler_ops * constr_cases
  | CResume of core_value list
  (* effect end *)
  | CLambda of binder list * staged_spec option * core_lang
  | CShift of bool * binder * core_lang (* bool=true is for shift, and bool=false for shift0 *)
  | CReset of core_lang
  (* Record operations *)
  | CRecord of (string * core_lang) list  (* field_name, field_value pairs - values can be any expression *)
  | CGetField of core_lang * string       (* record expression, field_name *)
  | CSetField of core_lang * string * core_lang  (* record expression, field_name, new_value - all can be any expression *)

and core_lang =
  {core_desc: core_lang_desc;
   core_type: typ}
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
  (* TODO should PointsTo use binders instead of strings...? *)
  | PointsTo of string * term
  | RecordPointsTo of string * (string * term) list (* loc -> {field1: val1, field2: val2, ...} *)
  | SepConj of kappa * kappa
  (*| MagicWand of kappa * kappa*)

(* a formula which describes a program state *)
and state = pi * kappa

(* effect start *)
(* v->phi and (Eff arg?-> phi)* *)
and handlingcases = (string * staged_spec) * ((string * string option * staged_spec) list)
and trycatch = (staged_spec * handlingcases)
(* effect end *)

and staged_spec =
  | Exists of binder * staged_spec
  | ForAll of binder * staged_spec
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
  | Shift of bool * binder * staged_spec * binder * staged_spec (* see CShift for meaning of bool *)
  | Reset of staged_spec
  | Sequence of staged_spec * staged_spec
  | Bind of binder * staged_spec * staged_spec
  | Disjunction of staged_spec * staged_spec
  (* effects: H /\ P /\ E(...args, v), term is always a placeholder variable *)
  | RaisingEff of (pi * kappa * instant * term)
  (* | IndPred of { name : string; args: term list } *)
  | TryCatch of (pi * kappa * trycatch * term)
  | Multi of staged_spec * staged_spec
  | Assume of staged_spec
(* copied here so visitors can be generated *)
and typ = Types.typ =
  | Any
  | Unit
  | Int
  | Bool
  | TyString
  | Lamb
  | Arrow of typ * typ
  | TConstr of string * typ list
  | TRecord of (string * typ) list
  | TVar of string


[@@deriving
  visitors { variety = "map"; name = "map_spec" },
  visitors { variety = "reduce"; name = "reduce_spec" },
  visitors { variety = "mapreduce"; name = "mapreduce_spec" },
  ord, eq]

let return_var_name t = 
  match t with 
  |Var x -> x 
  |Type (BaseTy (Tvar s)) -> s
  |_ -> failwith "must be var"

let rec map_typ_to_ty typ1  =
  match typ1 with
  | Any ->  (BaseTy AnyBty)
  | Unit ->  (BaseTy UnitBty)
  | Int ->  (BaseTy IntBty)
  | Bool ->  (BaseTy BoolBty)
  | TyString ->  (BaseTy TyStringBty)
  | Arrow (a,b)->  (ArrowTy (map_typ_to_ty a, map_typ_to_ty b))
  | TConstr (a,b) ->  (BaseTy (Defty (a, (List.map map_typ_to_ty b))))
  | TVar s ->  (BaseTy (Tyvar s))
  | TRecord fields ->
      (* Encode record as Defty with canonical name based on field names *)
      let field_names = List.map fst fields in
      let record_name = "{" ^ String.concat ";" field_names ^ "}" in
      let field_types = List.map (fun (_, t) -> map_typ_to_ty t) fields in
      (BaseTy (Defty (record_name, field_types)))
  | Lamb -> failwith "Lamb type not supported in map_typ_to_ty"

let rec map_ter_to_ty t = 
    match t.term_desc with
    | Var v -> BaseTy (Tvar v)
    | Const c -> BaseTy (Consta c) 
    | Construct (name, terms) -> BaseTy (Defty (name, (List.map map_ter_to_ty terms)))
    | _ -> map_typ_to_ty t.term_type
    
exception Unification of (bty * string)
let rec check_two_base_types t1 t2= 
    if t1 = t2 then true else match (t1,t2) with 
    | (Consta ((Num _)), IntBty) 
    | ((Consta TTrue),BoolBty)
    | ((Consta TFalse),BoolBty)
    | (Consta (TStr _), TyStringBty)
    | (Bot,_)
    | (_,Top)
    -> true
     | (a,Tyvar t) | (a,Tvar t) -> raise (Unification (a,t))
    | (Defty (n1,l1),Defty (n2,l2)) -> if not (n1 = n2) then false else List.equal is_subtype l1 l2
    | (Top,_) -> false 
    | (_, AnyBty) -> true 
    | _ -> false
    
and check_sub t1 t2 = match t2 with
  | BaseTy t -> check_two_base_types t1 t 
  | Union (s1,s2) -> check_sub t1 s1 || check_sub t1 s2
  | Inter (s1,s2) -> check_sub t1 s1 && check_sub t1 s2
  | Neg s -> not (check_sub t1 s) 
  | ArrowTy _-> failwith "fun type to be implemented"
  | TAny -> failwith "TAny type to be implemented"

and is_subtype t1 t2 = match t1 with 
  | BaseTy t -> check_sub t t2 
  | Union (x1,x2) -> is_subtype x1 t2 && is_subtype x2 t2
  | Inter (x1,x2) -> is_subtype x1 t2 || is_subtype x2 t2
  | Neg s -> not (is_subtype s t2) (*not correct placeholder only*)
  | _ -> failwith "to be implemented"

let get_type_from_terms t = 
  match t with 
  |Type x -> x 
  |_ -> failwith "not type term"

let get_var_name_from_terms t = 
  match t.term_desc with 
  |Var x -> x 
  |_ -> failwith "not type term"
