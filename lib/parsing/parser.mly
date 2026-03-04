%{
open Hipcore
open Hiptypes
%}

%token EQUAL
%token GREATER
%token LESS
%token PLUS
%token MINUS
%token STAR
%token STARDOT
%token MINUSGREATER
%token DOT
%token TILDE
%token CONJUNCTION
%token DISJUNCTION
%token LPAREN
%token RPAREN
%token LBRACKET
%token RBRACKET
%token LBRACE
%token RBRACE
%token SEMI
%token COMMA
%token COLON
%token NOT
%token ASSUME
%token TANY


%token TRUE
%token FALSE
%token EMP

%token <int> INT
%token <string> STRING
%token <string> LOWERCASE_IDENT
%token <string> CAPITAL_IDENT
%token <string> TYVAR

%token EXISTS
%token FORALL
%token REQUIRES
%token ENSURES
%token LET
%token IN
%token FUN
%token SHIFT
%token RESET
%token LONGARROW
%token CASE
%token FATARROW
%token TOP
%token BOT
%token ANY
%token UNIT
%token INTB
%token BOOLBTY
%token STRBTY
%token REF
%token TYAN
%token ARR
%token MULTI
%token EOF

///////////////////////////

%nonassoc EQUAL
%nonassoc GREATER
%nonassoc LESS
%left STARDOT
%left PLUS
%left MINUS
%right STAR
// %nonassoc MINUSGREATER
%nonassoc TILDE
%right CONJUNCTION

%nonassoc DOT
%right DISJUNCTION
%right SEMI
%nonassoc IN

%start parse_pi
%type <Hiptypes.pi> parse_pi
%start parse_kappa
%type <Hiptypes.kappa> parse_kappa
%start parse_state
%type <Hiptypes.pi * Hiptypes.kappa> parse_state
%start parse_staged_spec
%type <Hiptypes.staged_spec> parse_staged_spec
%start parse_term
%type <Hiptypes.term> parse_term
%start parse_lemma
%type <Hiptypes.lemma> parse_lemma
%start parse_simple_spec
%type <Hiptypes.simple_spec> parse_simple_spec
%start parse_case_spec
%type <Hiptypes.case_spec> parse_case_spec
%%

%inline bin_rel_op:
  | GREATER EQUAL
      { GTEQ }
  | LESS EQUAL
      { LTEQ }
  | GREATER
      { GT }
  | LESS
      { LT }
  | EQUAL
      { EQ }
;

%inline bin_term_op:
  | PLUS PLUS
      { SConcat }
  | PLUS
      { Plus }
  | MINUS
      { Minus }
  | STARDOT
      { TTimes }
;

const:
  | LPAREN RPAREN
      { ValUnit }
  | n = INT
      { Num n }
  | TRUE
      { TTrue }
  | FALSE
      { TFalse }
  | s = STRING
      { TStr s }
;

ty_var:
  | v = TYVAR 
    {Tyvar v}
;
opt_ty_var_list
   : {[]}
   | ty_var_list {$1}
;
ty_var_list:
    
    | ty {[$1]}
    | ty_var_list COMMA ty {$1 @ [$3]}

bty: 
  | TOP
    {Top}
  | BOT
    {Bot}
  | ANY
    {AnyBty}
  | UNIT
    {UnitBty}
  | INTB
    {IntBty}
  | BOOLBTY
    {BoolBty}
  | STRBTY
    {TyStringBty}
  | c = const
    {Consta c}
  | v = LOWERCASE_IDENT 
    {Tvar v}
  | REF LPAREN v = bty RPAREN
    {RefBty v} 
  | v = ty_var
    {v}
  | v = CAPITAL_IDENT 
    {Defty (v,[])}
  | v = CAPITAL_IDENT LBRACKET l = opt_ty_var_list  RBRACKET
    {Defty (v,l)}
;
ty:
  | v = bty
      {BaseTy v}
  | LPAREN t1 = ty DISJUNCTION t2 = ty RPAREN
      {Union (t1, t2)}
  | LPAREN t1 = ty CONJUNCTION t2 = ty RPAREN
      {Inter (t1, t2)} 
  | NOT LPAREN t=ty RPAREN
      {Neg t}
  | t1 = ty ARR t2 = ty
      {ArrowTy (t1, t2)}
  | TANY 
      {TAny}
;

term:
  | c = const
      { Const c }
  | v = LOWERCASE_IDENT
      { Var v }
  (* Allow type keywords as terms for colon assertions like "x : int" *)
  | INTB
      { Var "int" }
  | UNIT
      { Var "unit" }
  | BOOLBTY
      { Var "bool" }
  | TILDE t = term
      { TNot t }
  | t1 = term op = bin_rel_op t2 = term
      { Rel (op, t1, t2) }
  | t1 = term op = bin_term_op t2 = term
      { BinOp (op, t1, t2) }
  | TYAN t = ty
      {Type t}  
  | v = LOWERCASE_IDENT LPAREN args = separated_list(COMMA, term) RPAREN
      { TApp (v, args) }
  | v = CAPITAL_IDENT
      { Construct (v, []) }
  | v = CAPITAL_IDENT LPAREN args = separated_list(COMMA, term) RPAREN
      { Construct (v, args) }
  | LBRACKET items = separated_list(SEMI, term) RBRACKET
      { List.fold_right (fun v t -> BinOp (TCons, v, t)) items (Const Nil) }
  (* intended: function body spans maximally *)
  (* todo: remove the parens around function body *)
  | FUN LPAREN args = separated_list(COMMA, LOWERCASE_IDENT) RPAREN MINUSGREATER LPAREN body=single_staged_spec RPAREN
      { TLambda ("", args, Some body, None) }
;

pi:
  | TRUE
      { True }
  | FALSE
      { False }
  | t1 = term op = bin_rel_op t2 = term
      { Atomic (op, t1, t2) }
  // | a = pure_formula_term SUBSUMES b = pure_formula_term { Subsumption (a, b) }
  | p1 = pi CONJUNCTION p2 = pi
      { And (p1, p2) }
  // these cause shift-reduce conflicts, are not used, and are not in the symbolic heap fragment
//   | p1 = pi DISJUNCTION p2 = pi
//       { Or (p1, p2) }
  // | pure_formula IMPLICATION pure_formula { Imply ($1, $3) }
  | TILDE p = pi
      { Not p }
//   | v = LOWERCASE_IDENT args=delimited(LPAREN, separated_nonempty_list(COMMA, pure_formula_term), RPAREN) { Predicate (v, args) }
  | p = delimited(LPAREN, pi, RPAREN)
      { p }
  | v = LOWERCASE_IDENT COLON t = term
      { Colon (v, t)}
  | v = TYVAR COLON t = term
      { Colon (v, t)}
;

record_field:
  | f = LOWERCASE_IDENT COLON t = term
      { (f, t) }
;

kappa:
  | EMP
      { EmptyHeap }
  | v = LOWERCASE_IDENT MINUSGREATER t = term
      { PointsTo (v, t) }
  | v = TYVAR MINUSGREATER t = term
      { PointsTo (v, t) }
  (* Dotted points-to: p.x -> vx — per-field decomposition *)
  | v = LOWERCASE_IDENT DOT f = LOWERCASE_IDENT MINUSGREATER t = term
      { PointsTo (v ^ "." ^ f, t) }
  | v = TYVAR DOT f = LOWERCASE_IDENT MINUSGREATER t = term
      { PointsTo (v ^ "." ^ f, t) }
  (* Record points-to: v -> {f1: t1, f2: t2, ...} — desugared to per-field PointsTo *)
  | v = LOWERCASE_IDENT MINUSGREATER LBRACE fields = separated_nonempty_list(COMMA, record_field) RBRACE
      { List.fold_left (fun acc (f, t) ->
          let cell = PointsTo (v ^ "." ^ f, t) in
          match acc with EmptyHeap -> cell | _ -> SepConj (acc, cell)
        ) EmptyHeap fields }
  | v = TYVAR MINUSGREATER LBRACE fields = separated_nonempty_list(COMMA, record_field) RBRACE
      { List.fold_left (fun acc (f, t) ->
          let cell = PointsTo (v ^ "." ^ f, t) in
          match acc with EmptyHeap -> cell | _ -> SepConj (acc, cell)
        ) EmptyHeap fields }
  | k1 = kappa STAR k2 = kappa
      { SepConj (k1, k2) }
  | k = delimited(LPAREN, kappa, RPAREN)
      { k }
;

state:
  | p = pi
      { (p, EmptyHeap) }
  | k = kappa
      { (True, k) }
  | p = pi CONJUNCTION k = kappa
      { (p, k) }
  | k = kappa CONJUNCTION p = pi
      { (p, k) }
;

fn:
  | v = LOWERCASE_IDENT LPAREN args = separated_list(COMMA, term) RPAREN
    { (v, args) }
;

single_staged_spec:
  | EXISTS vs = LOWERCASE_IDENT* DOT s = single_staged_spec
      { List.fold_right (fun v t -> Exists (v, t)) vs s }
  | FORALL vs = LOWERCASE_IDENT* DOT s = single_staged_spec
      { List.fold_right (fun v t -> ForAll (v, t)) vs s }
  | s1 = single_staged_spec DISJUNCTION s2 = single_staged_spec
      { Disjunction (s1, s2) }
  | REQUIRES s = state
      { let (p, k) = s in Require (p, k) }
  | ENSURES s = state
      { let (p, k) = s in NormalReturn (p, k) }
  | va = fn
      { let (v, args) = va in HigherOrder (v, args) }
  | SHIFT LPAREN v = LOWERCASE_IDENT DOT s = single_staged_spec RPAREN
      { (* TODO: shiftc *)
        let x = Variables.fresh_variable ~v:"x" "continuation argument" in
        Shift (true, v, s, x, NormalReturn (Atomic (EQ, Variables.res_var, Var x), EmptyHeap)) }
  | RESET LPAREN s = single_staged_spec RPAREN
      { Reset s }
  | s1 = single_staged_spec SEMI s2 = single_staged_spec
      { Sequence (s1, s2) }
  | LET v = LOWERCASE_IDENT EQUAL s1 = single_staged_spec IN s2 = single_staged_spec
      { Bind (v, s1, s2) }
  | LPAREN s = single_staged_spec RPAREN
      { s }
  
;
staged_spec
    : single_staged_spec {$1}
   | staged_spec MULTI single_staged_spec {Multi ($1,$3)}
   | ASSUME s=staged_spec 
      {Assume s}

lemma:
  | name_params=fn EQUAL lhs=single_staged_spec LONGARROW rhs=single_staged_spec
    { let (f, params) = name_params in
      let params =
        List.map (function Var s -> s | _ -> failwith "invalid lemma") params
      in
      { l_name = f;
        l_params = params;
        l_left = lhs;
        l_right = rhs }
    }
;

parse_pi:
  | p = pi EOF
      { p }

parse_kappa:
  | k = kappa EOF
      { k }

parse_staged_spec:
  | s = staged_spec EOF
      { s }

parse_term:
  | t = term EOF
      { t }

parse_lemma:
  | t = lemma EOF
      { t }

parse_state:
  | t = state EOF
      { t }

(* Simple separation logic specification: requires/ensures only *)
simple_spec_body:
  (* Only ensures (postcondition) *)
  | ENSURES post = state
      { { ss_precond = None; ss_postcond = post; ss_ex = []; ss_fa = [] } }
  (* Only requires (precondition) - postcondition defaults to True/emp *)
  | REQUIRES pre = state
      { { ss_precond = Some pre; ss_postcond = (True, EmptyHeap); ss_ex = []; ss_fa = [] } }
  (* Both requires and ensures *)
  | REQUIRES pre = state ENSURES post = state
      { { ss_precond = Some pre; ss_postcond = post; ss_ex = []; ss_fa = [] } }
;

simple_spec:
  (* Existential quantification *)
  | EXISTS vs = LOWERCASE_IDENT+ DOT s = simple_spec
      { { s with ss_ex = vs @ s.ss_ex } }
  (* Universal quantification *)
  | FORALL vs = LOWERCASE_IDENT+ DOT s = simple_spec
      { { s with ss_fa = vs @ s.ss_fa } }
  (* Base case *)
  | simple_spec_body
      { $1 }
  (* Parenthesized *)
  | LPAREN s = simple_spec RPAREN
      { s }
;

parse_simple_spec:
  | s = simple_spec EOF
      { s }

(* ========== CASE-BASED SPECIFICATIONS ========== *)

(* A single case branch: precondition => postcondition *)
case_branch:
  | pre = state FATARROW ENSURES post = state
      { { cb_pre = pre; cb_post = post } }
  | pre = state FATARROW post = state
      { { cb_pre = pre; cb_post = post } }
;

(* List of case branches separated by semicolons *)
case_branches:
  | b = case_branch
      { [b] }
  | b = case_branch SEMI rest = case_branches
      { b :: rest }
;

(* Case specification: case [params] { branch1; branch2; ... } *)
case_spec_body:
  | CASE LBRACKET params = separated_list(COMMA, LOWERCASE_IDENT) RBRACKET
    LBRACE branches = case_branches RBRACE
      { { cs_type_vars = []; cs_forall = []; cs_params = params; cs_branches = branches } }
;

(* Case spec with optional quantifiers *)
case_spec:
  (* Universal quantification *)
  | FORALL vs = LOWERCASE_IDENT+ DOT s = case_spec
      { { s with cs_forall = vs @ s.cs_forall } }
  (* Base case *)
  | case_spec_body
      { $1 }
  (* Parenthesized *)
  | LPAREN s = case_spec RPAREN
      { s }
;

parse_case_spec:
  | s = case_spec EOF
      { s }
