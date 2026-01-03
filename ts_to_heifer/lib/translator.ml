(** TypeScript to Heifer IR Translator

    Translates TypeScript AST (as JSON) directly to Heifer IR types.

    Flow: TypeScript source → [TS Parser] → JSON → [This module] → Heifer IR
*)

open Hipcore_typed.Typed_core_ast
open Yojson.Safe.Util
open Hipcore_common.Types
open Hipcore
open Parsing
open Hipcore_typed.Retypehip

type variance = Mutable | Immutable

type context = {
  variance_env: (string, variance) Hashtbl.t;  (* Variable name → variance *)
  type_env: (string, typ) Hashtbl.t;           (* Variable name → type *)
}

let create_context () = {
  variance_env = Hashtbl.create 16;
  type_env = Hashtbl.create 16;
}

type scope_info = {
  declared_vars: string list;
  mutated_vars: string list;
}

let get_variance ctx name =
  Hashtbl.find_opt ctx.variance_env name
  |> Option.value ~default:Immutable

let set_variance ctx name variance =
  Hashtbl.replace ctx.variance_env name variance

let get_type ctx name =
  Hashtbl.find_opt ctx.type_env name
  |> Option.value ~default:Any

let set_type ctx name typ =
  Hashtbl.replace ctx.type_env name typ

let get_operator json =
  json |> member "operator" |> to_string

let get_kind json =
  try
    json |> member "kind" |> to_string
  with Yojson.Safe.Util.Type_error _ ->
    failwith (Printf.sprintf "Failed to get 'kind' from JSON: %s" (Yojson.Safe.to_string json))

let get_spec_require json = 
  try 
    json |> member "jsdoc" |> member "require" |> to_string
  with Yojson.Safe.Util.Type_error _ ->
    failwith (Printf.sprintf "Failed to get 'require' from JSON: %s" (Yojson.Safe.to_string json))

let get_spec_ensure json =
  try 
    json |> member "jsdoc" |> member "ensure" |> to_string
  with Yojson.Safe.Util.Type_error _ ->
    failwith (Printf.sprintf "Failed to get 'ensure' from JSON: %s" (Yojson.Safe.to_string json))

let parse_to_hiptype json =
  let parse_state_from_string str =
    let lexbuf = Lexing.from_string str in
    Parser.parse_state Lexer.token lexbuf
  in
  (* Extract require and ensure from JSDoc annotations *)
  let require_str = get_spec_require json in
  let ensure_str = get_spec_ensure json in
  (* Parse both using the Heifer parser *)
  let (req_pi, req_kappa) = parse_state_from_string require_str in
  let (ens_pi, ens_kappa) = parse_state_from_string ensure_str in
  (* Build the specification *)
  Hiptypes.Sequence (
    Hiptypes.Require (req_pi, req_kappa),
    Hiptypes.NormalReturn (ens_pi, ens_kappa)
  )

let get_identifier json =
  try
    json |> member "text" |> to_string
  with Yojson.Safe.Util.Type_error _ ->
    failwith (Printf.sprintf "Failed to get identifier 'text' from JSON: %s" (Yojson.Safe.to_string json))

(** Get variance from TypeScript declaration flags
    flags = 1 → let (Mutable)
    flags = 2 → const (Immutable) *)
let variance_from_ts_declaration json =
  try
    let flags = json |> member "declarationList" |> member "flags" |> to_int in
    if flags = 2 then Immutable  (* const *)
    else Mutable                  (* let or var *)
  with _ -> Mutable  (* Default to mutable if flags not found *)

(** Track global variable accesses for heap specification generation *)
type global_access_info = {
  reads: string list;   (* Globals only read *)
  writes: string list;  (* Globals written (may also be read) *)
}

let collect_accessed_globals outer_ctx body_statements =
  let reads = ref [] in
  let writes = ref [] in

  let is_global name =
    Hashtbl.mem outer_ctx.variance_env name &&
    Hashtbl.find outer_ctx.variance_env name = Mutable
  in

  let add_read name =
    if is_global name then
      if not (List.mem name !reads || List.mem name !writes) then
        reads := name :: !reads
  in

  let add_write name =
    if is_global name then (
      (* Remove from reads if present *)
      reads := List.filter ((<>) name) !reads;
      if not (List.mem name !writes) then
        writes := name :: !writes
    )
  in

  let rec scan_expr json =
    try
      match get_kind json with
      | "Identifier" ->
          let name = get_identifier json in
          add_read name
      | "BinaryExpression" ->
          let op = get_operator json in
          if op = "EqualsToken" || op = "FirstAssignment" || op = "=" then (
            (* Assignment: LHS is written *)
            let lhs = json |> member "left" in
            (try
              match get_kind lhs with
              | "Identifier" ->
                  let name = get_identifier lhs in
                  add_write name
              | _ -> ()
            with _ -> ());
            (* RHS is read *)
            (try scan_expr (json |> member "right") with _ -> ())
          ) else (
            (try scan_expr (json |> member "left") with _ -> ());
            (try scan_expr (json |> member "right") with _ -> ())
          )
      | "CallExpression" ->
          (* Function calls - scan arguments *)
          (try
            let args = json |> member "arguments" |> to_list in
            List.iter scan_expr args
          with _ -> ())
      | _ -> ()
    with _ -> ()
  in

  let rec scan_stmt stmt =
    try
      if stmt = `Null then ()
      else
        match get_kind stmt with
        | "ExpressionStatement" ->
            (try scan_expr (stmt |> member "expression") with _ -> ())
        | "ReturnStatement" ->
            (try scan_expr (stmt |> member "expression") with _ -> ())
        | "IfStatement" ->
            (try scan_expr (stmt |> member "expression") with _ -> ());
            (try scan_stmt (stmt |> member "thenStatement") with _ -> ());
            (try scan_stmt (stmt |> member "elseStatement") with _ -> ())
        | "Block" ->
            (try
              let stmts = stmt |> member "statements" |> to_list in
              List.iter scan_stmt stmts
            with _ -> ())
        | "VariableStatement" | "FirstStatement" ->
            (try
              let decls = stmt |> member "declarationList" |> member "declarations" |> to_list in
              List.iter (fun decl ->
                try scan_expr (decl |> member "initializer") with _ -> ()
              ) decls
            with _ -> ())
        | _ -> ()
    with _ -> ()
  in

  List.iter scan_stmt body_statements;
  { reads = !reads; writes = !writes }

let fresh_counter = ref 0
let fresh_var prefix =
  incr fresh_counter;
  prefix ^ string_of_int !fresh_counter

(** Create arrow type from parameters and return type *)
let arrow_type_of_params params result_type =
  List.fold_right (fun (_name, typ) acc -> Arrow (typ, acc)) params result_type

(** Convert core_lang to term, adding let-binding if necessary *)
let maybe_var (f : term -> core_lang) (e : core_lang) : core_lang =
  match e.core_desc with
  | CValue v -> f v
  | _ ->
      let tmp = fresh_var "tmp" in
      { core_desc = CLet ((tmp, e.core_type), e, f { term_desc = Var tmp; term_type = e.core_type });
        core_type = (f { term_desc = Var tmp; term_type = e.core_type }).core_type }

let translate_bin_op = function
  | "PlusToken" | "+" -> Plus
  | "MinusToken" | "-" -> Minus
  | "AsteriskToken" | "*" -> TTimes
  | "SlashToken" | "/" -> TDiv
  | "AsteriskAsteriskToken" | "**" -> TPower  (* Exponentiation *)
  | "AmpersandAmpersandToken" | "&&" -> TAnd
  | "BarBarToken" | "||" -> TOr
  | op -> failwith ("Unsupported binary operator: " ^ op)

let translate_rel_op = function
  | "LessThanToken" | "<" -> LT
  | "GreaterThanToken" | ">" -> GT
  | "LessThanEqualsToken" | "<=" -> LTEQ
  | "GreaterThanEqualsToken" | ">=" -> GTEQ
  | "EqualsEqualsEqualsToken" | "===" -> EQ
  | "ExclamationEqualsEqualsToken" | "!==" -> EQ  (* Negated later with Not *)
  | op -> failwith ("Unsupported relational operator: " ^ op)

let is_relational_op = function
  | "LessThanToken" | "<"
  | "GreaterThanToken" | ">"
  | "LessThanEqualsToken" | "<="
  | "GreaterThanEqualsToken" | ">="
  | "EqualsEqualsEqualsToken" | "==="
  | "ExclamationEqualsEqualsToken" | "!==" -> true
  | _ -> false

let is_assignment_op = function
  (* Token names (old format) *)
  | "EqualsToken" | "FirstAssignment" | "PlusEqualsToken" | "MinusEqualsToken"
  | "AsteriskEqualsToken" | "SlashEqualsToken"
  (* Actual operator text (new format from parser) *)
  | "=" | "+=" | "-=" | "*=" | "/=" -> true
  | _ -> false

let translate_type json =
  try
    match get_kind json with
    | "NumberKeyword" -> Int
    | "StringKeyword" -> TyString
    | "BooleanKeyword" -> Bool
    | "VoidKeyword" -> Unit
    | "AnyKeyword" -> Any
    | "TypeReference" -> Any  (* Generic types become Any for now *)
    | _ -> Any  (* Default to Any for unknown types *)
  with _ -> Any  (* If any error, default to Any *)

(** Convert Heifer type to Hiptypes ty for specifications *)
let typ_to_ty t =
  match t with
  | Int -> BaseTy IntBty
  | TyString -> BaseTy TyStringBty
  | Bool -> BaseTy BoolBty
  | Unit -> BaseTy UnitBty
  | Any -> TAny
  | _ -> TAny  (* Default for complex types *)

(** Generate default specification from function signature *)
(* COMMENTED OUT: Heifer's type inference provides better specs
let generate_spec_from_signature _outer_ctx typed_params ret_type _body_statements =
  (* Pure parameter constraints *)
  let param_constraints = List.map (fun (name, typ) ->
    let ty = typ_to_ty typ in
    Hiptypes.Colon (name, Hiptypes.Type ty)
  ) typed_params in

  let require_pi = match param_constraints with
    | [] -> Hiptypes.True
    | [c] -> c
    | c :: cs -> List.fold_left (fun acc c -> Hiptypes.And (acc, c)) c cs
  in

  (* Collect accessed globals - these are now local refs created in function body *)
  let access_info = collect_accessed_globals _outer_ctx _body_statements in
  let all_accessed = access_info.reads @ access_info.writes in

  (* Since globals are wrapped as local refs (let globalCounter = ref 0), *)
  (* we use existential quantification: ex globalCounter. ens globalCounter->value *)

  let ret_ty = typ_to_ty ret_type in
  let ensure_pi = Hiptypes.Colon ("res", Hiptypes.Type ret_ty) in

  (* Build the base spec: req emp; ens res:type *)
  let base_spec = Hiptypes.Sequence (
    Hiptypes.Require (require_pi, Hiptypes.EmptyHeap),
    Hiptypes.NormalReturn (ensure_pi, Hiptypes.EmptyHeap)
  ) in

  (* Wrap with existential quantification for each global variable *)
  (* This creates: ex global1. ex global2. ... spec *)
  List.fold_right (fun global_name spec ->
    (* Each global is existentially quantified as a heap location *)
    Hiptypes.Exists (global_name, spec)
  ) all_accessed base_spec
*)

let translate_const json =
  match get_kind json with
  | "NumericLiteral" | "FirstLiteralToken" ->
      let value = json |> member "value" |> to_number |> int_of_float in
      { term_desc = Const (Num value);
        term_type = Int }

  | "StringLiteral" ->
      let value = json |> member "value" |> to_string in
      { term_desc = Const (TStr value);
        term_type = TyString }

  | "TrueKeyword" ->
      { term_desc = Const TTrue;
        term_type = Bool }

  | "FalseKeyword" ->
      { term_desc = Const TFalse;
        term_type = Bool }

  | kind -> failwith ("Not a constant: " ^ kind)

let rec translate_term ctx json =
  match get_kind json with
  | "NumericLiteral" | "FirstLiteralToken" | "StringLiteral" | "TrueKeyword" | "FalseKeyword" ->
      translate_const json

  | "NullKeyword" ->
      (* Represent null as None (option type constructor) *)
      { term_desc = Construct ("None", []);
        term_type = Any }

  | "Identifier" ->
      let name = get_identifier json in
      (* Special handling for undefined literal *)
      if name = "undefined" then
        (* Represent undefined as None (option type constructor) *)
        { term_desc = Construct ("None", []);
          term_type = Any }
      else
        let variance = get_variance ctx name in
        (match variance with
         | Immutable ->
             { term_desc = Var name;
               term_type = get_type ctx name }
         | Mutable ->
             { term_desc = Var name;
               term_type = get_type ctx name })

  | "BinaryExpression" ->
      let op_str = get_operator json in
      let left = json |> member "left" in
      let right = json |> member "right" in

      if is_relational_op op_str then
        translate_term ctx left
      else
        let l = translate_term ctx left in
        let r = translate_term ctx right in
        let op = translate_bin_op op_str in
        { term_desc = BinOp (op, l, r);
          term_type = l.term_type }  (* Assume same type *)

  | "TypeOfExpression" ->
      (* typeof x returns a string representing the type *)
      let children = json |> member "children" |> to_list in
      (match children with
       | [operand] ->
           let operand_term = translate_term ctx operand in
           { term_desc = TApp ("typeof", [operand_term]);
             term_type = TyString }
       | _ -> failwith "TypeOfExpression must have exactly one child")

  | kind -> failwith ("Unsupported term expression: " ^ kind)

let rec translate_condition ctx json =
  match get_kind json with
  | "TrueKeyword" -> True
  | "FalseKeyword" -> False

  | "BinaryExpression" ->
      let op_str = get_operator json in
      let left = json |> member "left" in
      let right = json |> member "right" in

      if is_relational_op op_str then
        let l = translate_term ctx left in
        let r = translate_term ctx right in
        let rel_op = translate_rel_op op_str in
        if op_str = "ExclamationEqualsEqualsToken" || op_str = "!==" then
          Not (Atomic (EQ, l, r))
        else
          Atomic (rel_op, l, r)
      else if op_str = "AmpersandAmpersandToken" then
        let l = translate_condition ctx left in
        let r = translate_condition ctx right in
        And (l, r)
      else if op_str = "BarBarToken" then
        let l = translate_condition ctx left in
        let r = translate_condition ctx right in
        Or (l, r)
      else
        failwith ("Expected boolean expression, got: " ^ op_str)

  | "PrefixUnaryExpression" ->
      let op_str = get_operator json in
      let operand = json |> member "operand" in
      if op_str = "ExclamationToken" then
        Not (translate_condition ctx operand)
      else
        failwith ("Expected !, got: " ^ op_str)

  | "Identifier" ->
      (* Boolean variable used as condition (e.g., "result ? 1 : 0") *)
      (* Translate to: identifier == true *)
      let term = translate_term ctx json in
      Atomic (EQ, term, { term_desc = Const TTrue; term_type = Bool })

  | kind -> failwith ("Unsupported condition: " ^ kind)

let rec translate_expr ctx json continuation =
  let kind = get_kind json in

  (* Check if this is a term that should be wrapped in CValue *)
  match kind with
  | "NumericLiteral" | "FirstLiteralToken" | "StringLiteral"
  | "TrueKeyword" | "FalseKeyword" | "NullKeyword" | "TypeOfExpression" ->
      let term = translate_term ctx json in
      { core_desc = CValue term;
        core_type = term.term_type }

  | "Identifier" ->
      let name = get_identifier json in
      let variance = get_variance ctx name in
      let typ = get_type ctx name in
      (match variance with
       | Immutable ->
           (* Immutable: use translate_term for consistency *)
           let term = translate_term ctx json in
           { core_desc = CValue term;
             core_type = term.term_type }
       | Mutable ->
           (* Mutable: read from reference *)
           { core_desc = CRead name;
             core_type = typ })

  | "BinaryExpression" ->
      let op_str = get_operator json in
      let left = json |> member "left" in
      let right = json |> member "right" in

      if op_str = "EqualsToken" || op_str = "FirstAssignment" || op_str = "=" then
        translate_assignment ctx left right continuation

      else if op_str = "PlusEqualsToken" || op_str = "MinusEqualsToken" ||
              op_str = "+=" || op_str = "-=" || op_str = "*=" || op_str = "/=" then
        translate_compound_assignment ctx op_str left right continuation

      else if not (is_relational_op op_str) then
        (* Translate operands as expressions and use maybe_var to extract terms *)
        let op = translate_bin_op op_str in
        let left_expr = translate_expr ctx left continuation in
        maybe_var (fun l_term ->
          let right_expr = translate_expr ctx right continuation in
          maybe_var (fun r_term ->
            { core_desc = CValue { term_desc = BinOp (op, l_term, r_term);
                                   term_type = l_term.term_type };
              core_type = l_term.term_type }
          ) right_expr
        ) left_expr

      else
        let cond = translate_condition ctx json in
        { core_desc = CIfElse (cond,
                                { core_desc = CValue { term_desc = Const TTrue; term_type = Bool };
                                  core_type = Bool },
                                { core_desc = CValue { term_desc = Const TFalse; term_type = Bool };
                                  core_type = Bool });
          core_type = Bool }

  | "PrefixUnaryExpression" ->
      let op_str = get_operator json in
      let operand = json |> member "operand" in

      if op_str = "PlusPlusToken" then
        let name = get_identifier operand in
        let variance = get_variance ctx name in
        assert (variance = Mutable);
        let typ = get_type ctx name in
        let new_val = { term_desc = BinOp (Plus,
                                            { term_desc = Var name; term_type = typ },
                                            { term_desc = Const (Num 1); term_type = Int });
                        term_type = typ } in
        { core_desc = CSequence (
            { core_desc = CWrite (name, new_val); core_type = Unit },
            { core_desc = CRead name; core_type = typ });
          core_type = typ }

      else if op_str = "MinusMinusToken" then
        let name = get_identifier operand in
        let variance = get_variance ctx name in
        assert (variance = Mutable);
        let typ = get_type ctx name in
        let new_val = { term_desc = BinOp (Minus,
                                            { term_desc = Var name; term_type = typ },
                                            { term_desc = Const (Num 1); term_type = Int });
                        term_type = typ } in
        { core_desc = CSequence (
            { core_desc = CWrite (name, new_val); core_type = Unit },
            { core_desc = CRead name; core_type = typ });
          core_type = typ }

      else if op_str = "ExclamationToken" then
        let _inner = translate_condition ctx operand in
        { core_desc = CValue { term_desc = Const TTrue; term_type = Bool };
          core_type = Bool }  (* Placeholder *)

      else if op_str = "MinusToken" || op_str = "-" then
        (* Unary minus: -x becomes 0 - x *)
        let operand_expr = translate_expr ctx operand continuation in
        maybe_var (fun operand_term ->
          { core_desc = CValue { term_desc = BinOp (Minus,
                                                      { term_desc = Const (Num 0); term_type = Int },
                                                      operand_term);
                                  term_type = operand_term.term_type };
            core_type = operand_term.term_type }
        ) operand_expr

      else
        failwith ("Unsupported prefix operator: " ^ op_str)

  | "PostfixUnaryExpression" ->
      let op_str = get_operator json in
      let operand = json |> member "operand" in

      if op_str = "PlusPlusToken" then
        let name = get_identifier operand in
        let variance = get_variance ctx name in
        assert (variance = Mutable);
        let typ = get_type ctx name in
        let tmp = fresh_var "tmp" in
        let new_val = { term_desc = BinOp (Plus,
                                            { term_desc = Var tmp; term_type = typ },
                                            { term_desc = Const (Num 1); term_type = Int });
                        term_type = typ } in
        { core_desc = CLet ((tmp, typ),
                            { core_desc = CRead name; core_type = typ },
                            { core_desc = CSequence (
                                { core_desc = CWrite (name, new_val); core_type = Unit },
                                { core_desc = CValue { term_desc = Var tmp; term_type = typ };
                                  core_type = typ });
                              core_type = typ });
          core_type = typ }

      else
        failwith ("Unsupported postfix operator: " ^ op_str)

  | "ElementAccessExpression" ->
      (* Array indexing: arr[index] *)
      (* Translate as function application: arr(index) *)
      let arr_json = json |> member "expression" in
      let index_json = json |> member "argumentExpression" in

      let arr_expr = translate_expr ctx arr_json continuation in
      let index_expr = translate_expr ctx index_json continuation in

      (* Extract terms and create function application *)
      maybe_var (fun arr_term ->
        maybe_var (fun index_term ->
          (* Represent as TApp for term-level array access *)
          { core_desc = CValue { term_desc = TApp ("array_get", [arr_term; index_term]);
                                  term_type = Any };
            core_type = Any }
        ) index_expr
      ) arr_expr

  | "PropertyAccessExpression" ->
      (* Object field access: obj.field *)
      let obj_json = json |> member "expression" in
      let property_name = json |> member "name" |> get_identifier in

      (* Check if object is a simple identifier *)
      (match get_kind obj_json with
       | "Identifier" ->
           let obj_name = get_identifier obj_json in
           let field_ref_name = obj_name ^ "_" ^ property_name in
           { core_desc = CRead field_ref_name;
             core_type = Any }
       | _ ->
           (* Complex object expression - not supported yet *)
           failwith "PropertyAccessExpression on complex objects not supported")

  | "ConditionalExpression" ->
      (* Handle ternary operator: condition ? then_expr : else_expr *)
      let children = json |> member "children" |> to_list in
      (* Children are: [condition, QuestionToken, then_expr, ColonToken, else_expr] *)
      (match children with
       | [cond_json; _; then_json; _; else_json] ->
           let cond = translate_condition ctx cond_json in
           let then_expr = translate_expr ctx then_json continuation in
           let else_expr = translate_expr ctx else_json continuation in
           { core_desc = CIfElse (cond, then_expr, else_expr);
             core_type = then_expr.core_type }
       | _ -> failwith "ConditionalExpression must have 5 children")

  | "ObjectLiteralExpression" ->
      (* For now, skip object literals - they need record type support *)
      failwith "Object literals not yet supported - use simpler examples"

  | "ParenthesizedExpression" ->
      (* Parentheses are just for grouping, unwrap and translate the inner expression *)
      let children = json |> member "children" |> to_list in
      (match children with
       | [inner] -> translate_expr ctx inner continuation
       | _ -> failwith "ParenthesizedExpression must have exactly one child")

  | "CallExpression" ->
      let callee = json |> member "expression" in
      let args = json |> member "arguments" |> to_list in

      (* Handle both simple function calls and method calls *)
      let fn_name = match get_kind callee with
        | "Identifier" -> get_identifier callee
        | "PropertyAccessExpression" ->
            (* For console.log, toString(), etc., use the method name *)
            (* PropertyAccessExpression has children: [object, property] *)
            let children = callee |> member "children" |> to_list in
            (match children with
             | [_obj; property] -> get_identifier property
             | _ -> failwith "PropertyAccessExpression must have 2 children")
        | kind -> failwith ("Unsupported callee in CallExpression: " ^ kind)
      in

      (* Translate arguments - check if simple term or complex expression *)
      let is_simple_term arg_json =
        match get_kind arg_json with
        | "NumericLiteral" | "FirstLiteralToken" | "StringLiteral"
        | "TrueKeyword" | "FalseKeyword" | "Identifier" -> true
        | "BinaryExpression" ->
            let op = get_operator arg_json in
            not (is_relational_op op) && not (is_assignment_op op)
        | _ -> false
      in

      let rec bind_args args_json acc_terms =
        match args_json with
        | [] ->
            { core_desc = CFunCall (fn_name, List.rev acc_terms);
              core_type = Any }
        | arg :: rest ->
            if is_simple_term arg then
              (* Simple term - translate directly *)
              let arg_term = translate_term ctx arg in
              bind_args rest (arg_term :: acc_terms)
            else
              (* Complex expression - evaluate first and bind to temp *)
              let tmp = fresh_var "arg" in
              let arg_expr = translate_expr ctx arg continuation in
              { core_desc = CLet ((tmp, arg_expr.core_type), arg_expr,
                                  bind_args rest ({ term_desc = Var tmp; term_type = arg_expr.core_type } :: acc_terms));
                core_type = Any }
      in

      bind_args args []

  | kind -> failwith ("Unsupported expression: " ^ kind)

and translate_assignment ctx lhs rhs continuation =
  let name = get_identifier lhs in
  let variance = get_variance ctx name in

  (* Verify variance: only mutable vars can be assigned *)
  if variance <> Mutable then
    failwith (Printf.sprintf "Cannot assign to immutable variable: %s" name);

  let rhs_expr = translate_expr ctx rhs continuation in
  (* Use maybe_var to handle complex RHS expressions *)
  maybe_var (fun rhs_term ->
    { core_desc = CWrite (name, rhs_term);
      core_type = Unit }
  ) rhs_expr

and translate_compound_assignment ctx op_str lhs rhs _continuation =
  let name = get_identifier lhs in
  let variance = get_variance ctx name in

  if variance <> Mutable then
    failwith (Printf.sprintf "Cannot modify immutable variable: %s" name);

  let typ = get_type ctx name in
  let rhs_term = translate_term ctx rhs in
  let bin_op = match op_str with
    | "PlusEqualsToken" | "+=" -> Plus
    | "MinusEqualsToken" | "-=" -> Minus
    | "AsteriskEqualsToken" | "*=" -> TTimes
    | "SlashEqualsToken" | "/=" -> TDiv
    | _ -> failwith ("Unsupported compound op: " ^ op_str) in

  let new_val = { term_desc = BinOp (bin_op,
                                      { term_desc = Var name; term_type = typ },
                                      rhs_term);
                  term_type = typ } in

  { core_desc = CWrite (name, new_val);
    core_type = Unit }

and translate_stmt ctx json continuation =
  match get_kind json with

  | "ExpressionStatement" ->
      let expr = json |> member "expression" in
      translate_expr ctx expr continuation

  | "ReturnStatement" ->
      let expr_opt = try Some (json |> member "expression")
                     with _ -> None in
      (match expr_opt with
       | Some expr ->
           translate_expr ctx expr continuation
       | None ->
           { core_desc = CValue { term_desc = Const ValUnit; term_type = Unit };
             core_type = Unit })

  | "IfStatement" ->
      let condition = json |> member "expression" in
      let then_stmt = json |> member "thenStatement" in
      let else_stmt_opt =
        try
          match json |> member "elseStatement" with
          | `Null -> None  (* Field exists but is null *)
          | else_json -> Some else_json
        with _ -> None in  (* Field doesn't exist *)

      let cond_pi = translate_condition ctx condition in
      let then_branch = translate_stmt ctx then_stmt continuation in
      let else_branch = match else_stmt_opt with
        | Some else_stmt -> translate_stmt ctx else_stmt continuation
        | None -> { core_desc = CValue { term_desc = Const ValUnit; term_type = Unit };
                    core_type = Unit } in

      { core_desc = CIfElse (cond_pi, then_branch, else_branch);
        core_type = then_branch.core_type }

  | "Block" ->
      let statements = json |> member "statements" |> to_list in
      translate_block ctx statements continuation
  | "FunctionDeclaration" -> translate_function_decl ctx json continuation
  | "VariableStatement" | "FirstStatement" ->
      translate_var_decl ctx json [] continuation
  | kind -> failwith ("Unsupported statement: " ^ kind)

and translate_block ctx statements continuation =
  match statements with
  | [] -> continuation
  | [stmt] -> translate_stmt ctx stmt continuation
  | stmt :: rest ->
      let rest_expr = translate_block ctx rest continuation in
      let stmt_expr = translate_stmt ctx stmt rest_expr in
      { core_desc = CSequence (stmt_expr, rest_expr);
        core_type = rest_expr.core_type }

and translate_function_decl outer_ctx json continuation =
  let name = json |> member "name" |> get_identifier in
  let params_json = json |> member "parameters" |> to_list in
  let body_json = json |> member "body" in
  let return_type_json = try Some (json |> member "type") with _ -> None in

  let ret_type = Option.fold ~none:Unit ~some:translate_type return_type_json in
  let body_statements = body_json |> member "statements" |> to_list in

  (* Define the final continuation for the function body *)
  let final_cont = {
    core_desc = CValue { term_desc = Const ValUnit; term_type = ret_type };
    core_type = ret_type
  } in

  (* Create function context by copying outer context - enables access to globals *)
  let func_ctx = {
    variance_env = Hashtbl.copy outer_ctx.variance_env;
    type_env = Hashtbl.copy outer_ctx.type_env;
  } in

  (* Register parameters in the function's local context *)
  let typed_params = List.map (fun p ->
    let param_name = p |> member "name" |> get_identifier in
    let param_type =
      try translate_type (p |> member "type")
      with _ -> Any in
    set_type func_ctx param_name param_type;
    set_variance func_ctx param_name Immutable;  (* Parameters are immutable *)
    (param_name, param_type)
  ) params_json in

  (* Forward-order translation: process statements in source order *)
  (* We need to build the result inside-out, but set variance as we encounter declarations *)
  let rec translate_body_forward stmts final_cont =
    match stmts with
    | [] -> final_cont
    | stmt :: rest ->
        if stmt = `Null then translate_body_forward rest final_cont
        else
          match get_kind stmt with
          | "VariableStatement" | "FirstStatement" ->
              (* Set variance from declaration flags BEFORE translating rest *)
              let variance = variance_from_ts_declaration stmt in
              let declarations = stmt |> member "declarationList" |> member "declarations" |> to_list in
              List.iter (fun decl ->
                let name = decl |> member "name" |> get_identifier in
                let type_opt = try Some (decl |> member "type") with _ -> None in
                set_variance func_ctx name variance;
                let typ = match type_opt with
                  | Some t -> translate_type t
                  | None -> Int in
                set_type func_ctx name typ
              ) declarations;
              (* Now translate rest with variance set, then wrap current declaration *)
              let rest_expr = translate_body_forward rest final_cont in
              translate_var_decl func_ctx stmt [] rest_expr
          | _ ->
              let rest_expr = translate_body_forward rest final_cont in
              translate_stmt func_ctx stmt rest_expr
  in

  let body_expr = translate_body_forward body_statements final_cont in

  (* Try to parse spec from JSDoc, use None if not present *)
  (* Let Heifer's type inference generate the spec instead of pre-generating it *)
  let spec_opt =
    try
      let untyped_spec = parse_to_hiptype json in
      let spec = retype_staged_spec untyped_spec in
      Some spec
    with e ->
      Printf.eprintf "Warning: Failed to parse JSDoc spec: %s\n" (Printexc.to_string e);
      Printf.eprintf "No spec provided - Heifer will infer it\n";
      None  (* Let Heifer infer the spec *)
  in

  let body_with_ret_type = { body_expr with core_type = ret_type } in

  (* Create the lambda and bind it *)
  let fn_type = arrow_type_of_params typed_params ret_type in
  let lambda = {
    core_desc = CLambda (typed_params, spec_opt, body_with_ret_type);
    core_type = fn_type
  } in
  { core_desc = CLet ((name, fn_type), lambda, continuation);
    core_type = continuation.core_type }

and translate_var_decl ctx json _mutated_vars continuation =
  let declarations = json |> member "declarationList" |> member "declarations" |> to_list in

  (* Translate declarations (variance already set in pre-pass) *)
  List.fold_right (fun decl cont ->
    let name = decl |> member "name" |> get_identifier in
    let init_opt = try Some (decl |> member "initializer")
                   with _ -> None in

    (* Get variance and type from context (already set in pre-pass) *)
    let variance = get_variance ctx name in
    let typ = get_type ctx name in

    let init = match init_opt with
      | Some i -> translate_expr ctx i cont
      | None -> { core_desc = CValue { term_desc = Const (Num 0); term_type = Int };
                  core_type = Int } in

    match variance with
    | Immutable ->
        (* const → direct binding *)
        { core_desc = CLet ((name, typ), init, cont);
          core_type = cont.core_type }

    | Mutable ->
        (* let → reference cell *)
        let ref_typ = TConstr ("ref", [typ]) in
        { core_desc = CLet ((name, ref_typ),
                            { core_desc = CRef (match init.core_desc with
                                                 | CValue t -> t
                                                 | _ -> { term_desc = Const (Num 0); term_type = typ });
                              core_type = ref_typ },
                            cont);
          core_type = cont.core_type }
  ) declarations continuation

let translate_program json =
  let ctx = create_context () in
  let statements = json |> member "statements" |> to_list in

  (* Pre-pass: Set variance for all top-level variable declarations *)
  List.iter (fun stmt ->
    match get_kind stmt with
    | "VariableStatement" | "FirstStatement" ->
        let variance = variance_from_ts_declaration stmt in
        let declarations = stmt |> member "declarationList" |> member "declarations" |> to_list in
        List.iter (fun decl ->
          let name = decl |> member "name" |> get_identifier in
          let type_opt = try Some (decl |> member "type") with _ -> None in
          set_variance ctx name variance;
          let typ = match type_opt with
            | Some t -> translate_type t
            | None -> Int in
          set_type ctx name typ
        ) declarations
    | _ -> ()
  ) statements;

  (* Variance is determined by TypeScript flags (const vs let) during translation *)
  let final_cont = { core_desc = CValue { term_desc = Const ValUnit; term_type = Unit };
                     core_type = Unit } in
  let rec translate_stmts stmts cont =
    match stmts with
    | [] -> cont
    | stmt :: rest ->
        let rest_expr = translate_stmts rest cont in
        (match get_kind stmt with
         | "VariableStatement" | "FirstStatement" ->
             translate_var_decl ctx stmt [] rest_expr
         | _ ->
             translate_stmt ctx stmt rest_expr)
  in

  translate_stmts statements final_cont

(** Extract global variable definitions from context *)
let extract_globals ctx =
  Hashtbl.fold (fun name variance acc ->
    if variance = Mutable then
      let typ = get_type ctx name in
      (name, typ) :: acc
    else
      acc
  ) ctx.variance_env []

(** Extract function metadata without creating full CLet binding *)
let extract_function_info ctx json =
  let name = json |> member "name" |> get_identifier in
  let params_json = json |> member "parameters" |> to_list in
  let body_json = json |> member "body" in
  let return_type_json = try Some (json |> member "type") with _ -> None in

  let typed_params = List.map (fun p ->
    let param_name = p |> member "name" |> get_identifier in
    let param_type =
      try translate_type (p |> member "type")
      with _ -> Any in
    set_type ctx param_name param_type;
    set_variance ctx param_name Immutable;
    (param_name, param_type)
  ) params_json in
  let ret_type = Option.fold ~none:Unit ~some:translate_type return_type_json in
  let body_statements = body_json |> member "statements" |> to_list in

  (* Detect which globals this method uses *)
  let global_access = collect_accessed_globals ctx body_statements in
  let used_globals = (global_access.reads @ global_access.writes)
                     |> List.sort_uniq String.compare in

  let final_cont = {
    core_desc = CValue { term_desc = Const ValUnit; term_type = ret_type };
    core_type = ret_type
  } in

  let rec translate_body stmts cont =
    match stmts with
    | [] -> cont
    | stmt :: rest ->
        if stmt = `Null then translate_body rest cont
        else
          let rest_expr = translate_body rest cont in
          (match get_kind stmt with
           | "VariableStatement" | "FirstStatement" ->
               translate_var_decl ctx stmt [] rest_expr
           | _ ->
               translate_stmt ctx stmt rest_expr)
  in

  let body_expr_raw = translate_body body_statements final_cont in

  (* Wrap body with global declarations for any globals used by this method *)
  let body_expr = List.fold_right (fun global_name acc ->
    let typ = get_type ctx global_name in
    let ref_typ = TConstr ("ref", [typ]) in
    let init_value = { term_desc = Const (Num 0); term_type = typ } in
    { core_desc = CLet ((global_name, ref_typ),
                        { core_desc = CRef init_value; core_type = ref_typ },
                        acc);
      core_type = acc.core_type }
  ) used_globals body_expr_raw in

  (* For functions with local refs (wrapped globals), let the verifier infer the spec *)
  (* The inferred spec will properly handle existential quantification *)
  let spec_opt =
    try
      let untyped_spec = parse_to_hiptype json in
      Some (retype_staged_spec untyped_spec)
    with e ->
      Printf.eprintf "Warning: Failed to parse JSDoc spec: %s\n" (Printexc.to_string e);
      Printf.eprintf "Falling back to inferred spec (no given spec)\n";
      (* Return None to let verifier infer the spec *)
      None
  in

  let body_with_ret_type = { body_expr with core_type = ret_type } in

  (name, typed_params, spec_opt, body_with_ret_type, [], None)

let translate_program_to_intermediates json =
  let ctx = create_context () in
  let statements = json |> member "statements" |> to_list in

  (* Pre-pass: Register all top-level variables in context *)
  List.iter (fun stmt ->
    match get_kind stmt with
    | "VariableStatement" | "FirstStatement" ->
        let variance = variance_from_ts_declaration stmt in
        let declarations = stmt |> member "declarationList" |> member "declarations" |> to_list in
        List.iter (fun decl ->
          let name = decl |> member "name" |> get_identifier in
          set_variance ctx name variance;
          let type_opt = try Some (decl |> member "type") with _ -> None in
          let typ = match type_opt with
            | Some t -> translate_type t
            | None -> Int in  (* Default to Int if no type annotation *)
          set_type ctx name typ
        ) declarations
    | _ -> ()
  ) statements;

  (* Now translate functions with populated context *)
  List.filter_map (fun stmt ->
    match get_kind stmt with
    | "FunctionDeclaration" ->
        let (name, params, spec, body, tactics, pure_info) = extract_function_info ctx stmt in
        Some (`Meth (name, params, spec, body, tactics, pure_info))
    | "VariableStatement" ->
        (* Skip variable statements in output *)
        None
    | _ ->
        None
  ) statements
