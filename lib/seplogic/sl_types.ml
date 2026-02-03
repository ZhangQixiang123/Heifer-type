(** Separation Logic Types and Translator

    This module defines a clean separation logic specification type
    that is independent of the staged specification system.
*)

open Hipcore_typed
open Typed_core_ast

(** Quantified state with explicit quantifier lists.
    Unlike staged_spec which uses nested ForAll/Exists wrappers,
    we collect all quantifiers at the top level. *)
type qstate = {
  qs_forall: binder list;   (** universally quantified variables *)
  qs_exists: binder list;   (** existentially quantified variables *)
  qs_pure: pi;              (** pure part of the state *)
  qs_heap: kappa;           (** heap part of the state *)
}

(** Simple separation logic specification.
    This represents specs of the form:
      forall a b. exists x. req P; ens Q
*)
type sl_spec = {
  sl_pre: qstate option;    (** precondition: req ... (None means emp) *)
  sl_post: qstate;          (** postcondition: ens ... *)
}

(** Disjunctive separation logic specification.
    Supports case analysis: (cond ∧ spec1) ∨ (¬cond ∧ spec2)

    For verification against declared spec Q:
    - Both branches must satisfy Q (universal semantics)
    - This follows from: (P1 ∨ P2) ⊢ Q  iff  (P1 ⊢ Q) ∧ (P2 ⊢ Q)
*)
type sl_spec_disj =
  | SL_Single of sl_spec
  | SL_Disj of {
      cond: pi;                (** branch condition *)
      then_spec: sl_spec_disj; (** spec when cond is true *)
      else_spec: sl_spec_disj; (** spec when cond is false *)
    }

(** Method definition with SL spec *)
type sl_meth_def = {
  slm_name: string;
  slm_params: binder list;
  slm_spec: sl_spec option;
  slm_body: core_lang;
}

(** Exception for specs that cannot be translated to simple SL *)
exception Unsupported_feature of string

(** Create an empty qstate *)
let empty_qstate = {
  qs_forall = [];
  qs_exists = [];
  qs_pure = True;
  qs_heap = EmptyHeap;
}

(** Create a qstate from a state (pi, kappa) *)
let qstate_of_state (p, k) = {
  qs_forall = [];
  qs_exists = [];
  qs_pure = p;
  qs_heap = k;
}

(** Add a universal quantifier to qstate *)
let add_forall (v: binder) (qs: qstate) =
  { qs with qs_forall = v :: qs.qs_forall }

(** Add an existential quantifier to qstate *)
let add_exists (v: binder) (qs: qstate) =
  { qs with qs_exists = v :: qs.qs_exists }

(** Add a universal quantifier to both pre and post of sl_spec *)
let add_forall_to_spec (v: binder) (spec: sl_spec) =
  {
    sl_pre = Option.map (add_forall v) spec.sl_pre;
    sl_post = add_forall v spec.sl_post;
  }

(** Add an existential quantifier to both pre and post of sl_spec *)
let add_exists_to_spec (v: binder) (spec: sl_spec) =
  {
    sl_pre = Option.map (add_exists v) spec.sl_pre;
    sl_post = add_exists v spec.sl_post;
  }

(** Combine two heaps with separating conjunction *)
let combine_heap (h1: kappa) (h2: kappa) : kappa =
  match h1, h2 with
  | EmptyHeap, k | k, EmptyHeap -> k
  | k1, k2 -> SepConj (k1, k2)

(** Combine two pure formulas with conjunction *)
let combine_pure (p1: pi) (p2: pi) : pi =
  match p1, p2 with
  | True, p | p, True -> p
  | p1, p2 -> And (p1, p2)

(** Combine two qstates (for separating conjunction) *)
let combine_qstate (qs1: qstate) (qs2: qstate) : qstate = {
  qs_forall = qs1.qs_forall @ qs2.qs_forall;
  qs_exists = qs1.qs_exists @ qs2.qs_exists;
  qs_pure = combine_pure qs1.qs_pure qs2.qs_pure;
  qs_heap = combine_heap qs1.qs_heap qs2.qs_heap;
}

(** Translate a staged_spec to sl_spec.
    Only supports simple separation logic constructs.
    Raises Unsupported_feature for complex specs. *)
let rec sl_spec_of_staged (spec: staged_spec) : sl_spec =
  match spec with
  (* Quantifiers - lift to top level *)
  | ForAll (v, inner) ->
      add_forall_to_spec v (sl_spec_of_staged inner)

  | Exists (v, inner) ->
      add_exists_to_spec v (sl_spec_of_staged inner)

  (* Simple req; ens pattern *)
  | Sequence (Require (p1, k1), NormalReturn (p2, k2)) ->
      {
        sl_pre = Some (qstate_of_state (p1, k1));
        sl_post = qstate_of_state (p2, k2);
      }

  (* Just postcondition (no precondition) *)
  | NormalReturn (p, k) ->
      {
        sl_pre = None;
        sl_post = qstate_of_state (p, k);
      }

  (* Just precondition *)
  | Require (p, k) ->
      {
        sl_pre = Some (qstate_of_state (p, k));
        sl_post = empty_qstate;
      }

  (* Sequence of requirements - combine with * *)
  | Sequence (Require (p1, k1), Sequence (Require (p2, k2), rest)) ->
      let inner = sl_spec_of_staged (Sequence (Require (combine_pure p1 p2, combine_heap k1 k2), rest)) in
      inner

  (* Nested sequence with postcondition *)
  | Sequence (Require (p1, k1), rest) ->
      let inner = sl_spec_of_staged rest in
      (match inner.sl_pre with
       | None ->
           { inner with sl_pre = Some (qstate_of_state (p1, k1)) }
       | Some pre ->
           { inner with sl_pre = Some (combine_qstate (qstate_of_state (p1, k1)) pre) })

  (* Sequence of postconditions - combine with * *)
  | Sequence (NormalReturn (p1, k1), NormalReturn (p2, k2)) ->
      {
        sl_pre = None;
        sl_post = qstate_of_state (combine_pure p1 p2, combine_heap k1 k2);
      }

  (* Bind - handle let-binding in specs *)
  | Bind (_x, spec1, spec2) ->
      let sl1 = sl_spec_of_staged spec1 in
      let sl2 = sl_spec_of_staged spec2 in
      (* For simple specs, combine pre and post *)
      {
        sl_pre = (match sl1.sl_pre, sl2.sl_pre with
                  | None, p | p, None -> p
                  | Some p1, Some p2 -> Some (combine_qstate p1 p2));
        sl_post = combine_qstate sl1.sl_post sl2.sl_post;
      }

  (* Unsupported features *)
  | Shift (_, _, _, _, _) ->
      raise (Unsupported_feature "Shift/Reset effects")
  | Reset _ ->
      raise (Unsupported_feature "Shift/Reset effects")
  | TryCatch _ ->
      raise (Unsupported_feature "Exception handling")
  | RaisingEff _ ->
      raise (Unsupported_feature "Effect raising")
  | HigherOrder (_, _) ->
      raise (Unsupported_feature "Higher-order predicates")
  | Multi (_, _) ->
      raise (Unsupported_feature "Multi-shot effects")
  | Disjunction (_, _) ->
      (* Disjunction handled by sl_spec_disj_of_staged, not here *)
      raise (Unsupported_feature "Disjunction in simple sl_spec (use sl_spec_disj_of_staged)")
  | Assume _ ->
      raise (Unsupported_feature "Assume")
  | Sequence (_, _) ->
      (* General sequence not handled above *)
      raise (Unsupported_feature "Complex sequence pattern")

(** Add a universal quantifier to all branches of sl_spec_disj *)
let rec add_forall_to_disj (v: binder) (d: sl_spec_disj) : sl_spec_disj =
  match d with
  | SL_Single s -> SL_Single (add_forall_to_spec v s)
  | SL_Disj { cond; then_spec; else_spec } ->
      SL_Disj {
        cond;
        then_spec = add_forall_to_disj v then_spec;
        else_spec = add_forall_to_disj v else_spec;
      }

(** Add an existential quantifier to all branches of sl_spec_disj *)
let rec add_exists_to_disj (v: binder) (d: sl_spec_disj) : sl_spec_disj =
  match d with
  | SL_Single s -> SL_Single (add_exists_to_spec v s)
  | SL_Disj { cond; then_spec; else_spec } ->
      SL_Disj {
        cond;
        then_spec = add_exists_to_disj v then_spec;
        else_spec = add_exists_to_disj v else_spec;
      }

(** Translate staged_spec to sl_spec_disj, handling disjunction.
    This is the preferred entry point for declared specs that may contain disjunction.

    Examples:
    - `ens res=1 \/ ens res=2` -> SL_Disj of two single specs
    - `req x->v; ens x->100` -> SL_Single of req/ens spec
    - `req x->v; ens x->100 \/ ens x->200` -> req x->v with SL_Disj postcondition
    - `forall a b. (req ...; ens ...) \/ (req ...; ens ...)` -> Disjunction with quantifiers on each branch
*)
let rec sl_spec_disj_of_staged (spec: staged_spec) : sl_spec_disj =
  match spec with
  (* Handle quantifiers wrapping disjunctions *)
  | ForAll (v, inner) ->
      (* Recursively translate inner, then add forall to all branches *)
      let inner_disj = sl_spec_disj_of_staged inner in
      add_forall_to_disj v inner_disj

  | Exists (v, inner) ->
      (* Recursively translate inner, then add exists to all branches *)
      let inner_disj = sl_spec_disj_of_staged inner in
      add_exists_to_disj v inner_disj

  | Disjunction (s1, s2) ->
      (* Create disjunction with True as condition (both branches equally valid) *)
      SL_Disj {
        cond = True;
        then_spec = sl_spec_disj_of_staged s1;
        else_spec = sl_spec_disj_of_staged s2;
      }

  (* Handle: req P; (ens Q1 \/ ens Q2) -> distribute precondition *)
  | Sequence (Require (p, k), Disjunction (s1, s2)) ->
      (* Distribute the precondition to each branch *)
      let pre = qstate_of_state (p, k) in
      let d1 = sl_spec_disj_of_staged s1 in
      let d2 = sl_spec_disj_of_staged s2 in
      (* Add precondition to each branch *)
      let add_pre_to_disj d =
        let rec add_pre_rec d =
          match d with
          | SL_Single s -> SL_Single { s with sl_pre = Some (match s.sl_pre with
              | None -> pre
              | Some p -> combine_qstate pre p) }
          | SL_Disj { cond; then_spec; else_spec } ->
              SL_Disj { cond; then_spec = add_pre_rec then_spec; else_spec = add_pre_rec else_spec }
        in
        add_pre_rec d
      in
      SL_Disj {
        cond = True;
        then_spec = add_pre_to_disj d1;
        else_spec = add_pre_to_disj d2;
      }

  | _ ->
      (* Non-disjunctive specs translate to SL_Single *)
      SL_Single (sl_spec_of_staged spec)

(** Pretty print a qstate *)
let string_of_qstate (qs: qstate) : string =
  let pp_binder (v, _) = v in
  let foralls = match qs.qs_forall with
    | [] -> ""
    | vs -> "forall " ^ String.concat " " (List.map pp_binder vs) ^ ". "
  in
  let exists = match qs.qs_exists with
    | [] -> ""
    | vs -> "exists " ^ String.concat " " (List.map pp_binder vs) ^ ". "
  in
  let pure_str = Pretty.string_of_pi qs.qs_pure in
  let heap_str = Pretty.string_of_kappa qs.qs_heap in
  let state_str = match qs.qs_pure, qs.qs_heap with
    | True, EmptyHeap -> "emp"
    | True, _ -> heap_str
    | _, EmptyHeap -> pure_str
    | _, _ -> heap_str ^ " /\\ " ^ pure_str
  in
  foralls ^ exists ^ state_str

(** Pretty print an sl_spec *)
let string_of_sl_spec (spec: sl_spec) : string =
  let pre_str = match spec.sl_pre with
    | None -> ""
    | Some qs -> "req " ^ string_of_qstate qs ^ "; "
  in
  let post_str = "ens " ^ string_of_qstate spec.sl_post in
  pre_str ^ post_str

(** Pretty print an sl_spec_disj *)
let rec string_of_sl_spec_disj (spec: sl_spec_disj) : string =
  match spec with
  | SL_Single s -> string_of_sl_spec s
  | SL_Disj { cond; then_spec; else_spec } ->
      let cond_str = Pretty.string_of_pi cond in
      Printf.sprintf "(%s => %s) \\/ (~%s => %s)"
        cond_str (string_of_sl_spec_disj then_spec)
        cond_str (string_of_sl_spec_disj else_spec)

(** Wrap an sl_spec into sl_spec_disj *)
let single_spec (spec: sl_spec) : sl_spec_disj = SL_Single spec

(** Create a disjunctive spec from if-else *)
let disj_spec (cond: pi) (then_spec: sl_spec_disj) (else_spec: sl_spec_disj) : sl_spec_disj =
  SL_Disj { cond; then_spec; else_spec }

(** Flatten sl_spec_disj to list of (path_condition, sl_spec) pairs *)
let rec flatten_disj (spec: sl_spec_disj) : (pi * sl_spec) list =
  match spec with
  | SL_Single s -> [(True, s)]
  | SL_Disj { cond; then_spec; else_spec } ->
      let then_cases = flatten_disj then_spec in
      let else_cases = flatten_disj else_spec in
      let add_cond c cases =
        List.map (fun (pc, s) -> (combine_pure c pc, s)) cases
      in
      add_cond cond then_cases @ add_cond (Not cond) else_cases

(* ========== CASE-BASED SPECIFICATIONS ========== *)

(** Aliasing relation between two variables.
    This captures what we know about whether two references point to the same location. *)
type alias_rel =
  | Separate    (** x and y are definitely different (inferred from x->_ * y->_) *)
  | MayAlias    (** x and y might be the same (no information) *)
  | MustAlias   (** x and y are definitely the same (from y = x) *)

(** A single case branch in a case-based specification.

    Each case has:
    - A precondition that must be satisfied for this case to apply
    - A postcondition that holds when this case applies

    Cases are ordered from most specific to least specific.
*)
type sl_case_branch = {
  case_pre: qstate;           (** precondition for this case *)
  case_post: qstate;          (** postcondition when this case applies *)
}

(** Case-based separation logic specification.

    Represents: case [params] { pre₁ => spec₁; pre₂ => spec₂; ... }

    Example - swap function:
    {[
      case [x, y] {
        x : Ref(A) /\ y : Ref(A)       => ens r : ();
        x -> a * y -> b                 => ens x -> b * y -> a /\ r : ();
        x -> a /\ y = x                 => ens x -> a /\ r : ()
      }
    ]}

    Semantics:
    - At call site, gather known facts about arguments
    - Find the first (most specific) case whose precondition is satisfied
    - Use that case's postcondition for verification

    Invariants:
    - Cases should be ordered from most specific to least specific
    - The last case should be a "catch-all" that always applies
*)
type sl_spec_case = {
  case_type_vars: string list;     (** type variables (A, B) - uppercase names *)
  case_forall: binder list;        (** value variables (a, b) - lowercase names *)
  case_params: string list;        (** function parameter names for case dispatch *)
  case_branches: sl_case_branch list;  (** ordered list of case branches *)
}

(** Extended SL specification supporting disjunction and case analysis *)
type sl_spec_ext =
  | SL_Simple of sl_spec              (** simple req/ens spec *)
  | SL_Disjunctive of sl_spec_disj    (** postcondition disjunction *)
  | SL_Case of sl_spec_case           (** precondition-based case analysis *)

(** Create an empty case branch *)
let empty_case_branch = {
  case_pre = empty_qstate;
  case_post = empty_qstate;
}

(** Create a case branch from pre and post states *)
let make_case_branch (pre: qstate) (post: qstate) : sl_case_branch = {
  case_pre = pre;
  case_post = post;
}

(** Create a case spec with given parameters and branches *)
let make_case_spec
    ?(type_vars=[])
    ?(forall=[])
    (params: string list)
    (branches: sl_case_branch list) : sl_spec_case = {
  case_type_vars = type_vars;
  case_forall = forall;
  case_params = params;
  case_branches = branches;
}

(** Add a forall quantifier to a case spec *)
let add_forall_to_case (v: binder) (spec: sl_spec_case) : sl_spec_case =
  { spec with case_forall = v :: spec.case_forall }

(** Pretty print alias relation *)
let string_of_alias_rel = function
  | Separate -> "separate"
  | MayAlias -> "may_alias"
  | MustAlias -> "must_alias"

(** Pretty print a case branch *)
let string_of_case_branch (branch: sl_case_branch) : string =
  let pre_str = string_of_qstate branch.case_pre in
  let post_str = string_of_qstate branch.case_post in
  Printf.sprintf "%s => ens %s" pre_str post_str

(** Pretty print a case spec *)
let string_of_case_spec (spec: sl_spec_case) : string =
  let forall_str = match spec.case_forall with
    | [] -> ""
    | vs -> "forall " ^ String.concat " " (List.map fst vs) ^ ". "
  in
  let params_str = "[" ^ String.concat ", " spec.case_params ^ "]" in
  let branches_str =
    String.concat ";\n  " (List.map string_of_case_branch spec.case_branches)
  in
  Printf.sprintf "%scase %s {\n  %s\n}" forall_str params_str branches_str

(** Pretty print extended spec *)
let string_of_sl_spec_ext = function
  | SL_Simple s -> string_of_sl_spec s
  | SL_Disjunctive d -> string_of_sl_spec_disj d
  | SL_Case c -> string_of_case_spec c

(** Extract locations mentioned in a heap formula *)
let rec locations_in_kappa (k: kappa) : string list =
  match k with
  | EmptyHeap -> []
  | PointsTo (loc, _) -> [loc]
  | RecordPointsTo (loc, _) -> [loc]
  | SepConj (k1, k2) -> locations_in_kappa k1 @ locations_in_kappa k2

(** Extract aliasing information from a heap formula.

    - x->_ * y->_ implies Separate(x, y) because separating conjunction
      requires disjoint heap regions
    - x->_ alone gives no aliasing info about other variables
*)
let extract_aliasing_from_heap (k: kappa) : (string * string * alias_rel) list =
  let locs = locations_in_kappa k in
  (* For each pair of distinct locations in a separating conjunction,
     they must be separate *)
  let rec pairs = function
    | [] -> []
    | x :: xs -> List.map (fun y -> (x, y, Separate)) xs @ pairs xs
  in
  pairs locs

(** Extract aliasing information from a pure formula.

    - x = y implies MustAlias(x, y)
*)
let rec extract_aliasing_from_pure (p: pi) : (string * string * alias_rel) list =
  match p with
  | Atomic (EQ, t1, t2) ->
      (match t1.term_desc, t2.term_desc with
       | Var x, Var y -> [(x, y, MustAlias)]
       | _ -> [])
  | And (p1, p2) ->
      extract_aliasing_from_pure p1 @ extract_aliasing_from_pure p2
  | _ -> []

(** Extract all aliasing information from a qstate *)
let extract_aliasing (qs: qstate) : (string * string * alias_rel) list =
  extract_aliasing_from_heap qs.qs_heap @ extract_aliasing_from_pure qs.qs_pure

(** Check if two alias relations are compatible *)
let compatible_alias (r1: alias_rel) (r2: alias_rel) : bool =
  match r1, r2 with
  | Separate, MustAlias | MustAlias, Separate -> false
  | _ -> true

(** Merge two alias relations (taking the more specific one) *)
let merge_alias (r1: alias_rel) (r2: alias_rel) : alias_rel option =
  match r1, r2 with
  | Separate, MustAlias | MustAlias, Separate -> None  (* contradiction *)
  | MustAlias, _ | _, MustAlias -> Some MustAlias
  | Separate, _ | _, Separate -> Some Separate
  | MayAlias, MayAlias -> Some MayAlias

(* ========== EXPECT TESTS ========== *)

(* Helper to create terms for testing *)
let var name typ = { term_desc = Var name; term_type = typ }
let num n = { term_desc = Const (Num n); term_type = Int }

(* Test: Simple postcondition only - ens res->42 *)
let%expect_test "simple_ens" =
  let spec = NormalReturn (True, PointsTo ("res", num 42)) in
  let sl = sl_spec_of_staged spec in
  print_endline (string_of_sl_spec sl);
  [%expect {| ens res->42 |}]

(* Test: Precondition with heap - forall v. req x->v; ens x->v *)
let%expect_test "req_ens_forall" =
  let v = ("v", Int) in
  let spec = ForAll (v, Sequence (
    Require (True, PointsTo ("x", var "v" Int)),
    NormalReturn (True, PointsTo ("x", var "v" Int))
  )) in
  let sl = sl_spec_of_staged spec in
  print_endline (string_of_sl_spec sl);
  [%expect {| req forall v. x->v; ens forall v. x->v |}]

(* Test: Postcondition with pure and heap - forall v. req x->v; ens x->v /\ res=v *)
let%expect_test "req_ens_with_pure" =
  let v = ("v", Int) in
  let spec = ForAll (v, Sequence (
    Require (True, PointsTo ("x", var "v" Int)),
    NormalReturn (Atomic (EQ, var "res" Int, var "v" Int), PointsTo ("x", var "v" Int))
  )) in
  let sl = sl_spec_of_staged spec in
  print_endline (string_of_sl_spec sl);
  [%expect {| req forall v. x->v; ens forall v. x->v /\ res=v |}]

(* Test: Separating conjunction - forall a b. req x->a * y->b; ens x->a * y->b *)
let%expect_test "sep_conj" =
  let a = ("a", Int) in
  let b = ("b", Int) in
  let heap = SepConj (PointsTo ("x", var "a" Int), PointsTo ("y", var "b" Int)) in
  let spec = ForAll (a, ForAll (b, Sequence (
    Require (True, heap),
    NormalReturn (True, heap)
  ))) in
  let sl = sl_spec_of_staged spec in
  print_endline (string_of_sl_spec sl);
  [%expect {| req forall a b. x->a*y->b; ens forall a b. x->a*y->b |}]

(* Test: Frame rule pattern - forall a b. req x->a * y->b; ens x->42 * y->b *)
let%expect_test "frame_rule" =
  let a = ("a", Int) in
  let b = ("b", Int) in
  let pre_heap = SepConj (PointsTo ("x", var "a" Int), PointsTo ("y", var "b" Int)) in
  let post_heap = SepConj (PointsTo ("x", num 42), PointsTo ("y", var "b" Int)) in
  let spec = ForAll (a, ForAll (b, Sequence (
    Require (True, pre_heap),
    NormalReturn (True, post_heap)
  ))) in
  let sl = sl_spec_of_staged spec in
  print_endline (string_of_sl_spec sl);
  [%expect {| req forall a b. x->a*y->b; ens forall a b. x->42*y->b |}]

(* Test: Existential in postcondition - ens exists loc. res=loc * loc->42 *)
let%expect_test "exists_post" =
  let loc = ("loc", TConstr ("ref", [Int])) in
  let spec = Exists (loc, NormalReturn (
    Atomic (EQ, var "res" Int, var "loc" Int),
    PointsTo ("loc", num 42)
  )) in
  let sl = sl_spec_of_staged spec in
  print_endline (string_of_sl_spec sl);
  [%expect {| ens exists loc. loc->42 /\ res=loc |}]

(* ========== CASE-BASED SPEC TESTS ========== *)

(* Test: Extract aliasing from separating conjunction *)
let%expect_test "aliasing_from_sep_conj" =
  let heap = SepConj (PointsTo ("x", num 1), PointsTo ("y", num 2)) in
  let aliasing = extract_aliasing_from_heap heap in
  List.iter (fun (a, b, rel) ->
    Printf.printf "%s, %s: %s\n" a b (string_of_alias_rel rel)
  ) aliasing;
  [%expect {| x, y: separate |}]

(* Test: Extract aliasing from equality in pure formula *)
let%expect_test "aliasing_from_equality" =
  let pure = Atomic (EQ, var "y" Int, var "x" Int) in
  let aliasing = extract_aliasing_from_pure pure in
  List.iter (fun (a, b, rel) ->
    Printf.printf "%s, %s: %s\n" a b (string_of_alias_rel rel)
  ) aliasing;
  [%expect {| y, x: must_alias |}]

(* Test: Case branch pretty printing *)
let%expect_test "case_branch_pp" =
  let pre = qstate_of_state (True, SepConj (PointsTo ("x", var "a" Int), PointsTo ("y", var "b" Int))) in
  let post = qstate_of_state (True, SepConj (PointsTo ("x", var "b" Int), PointsTo ("y", var "a" Int))) in
  let branch = make_case_branch pre post in
  print_endline (string_of_case_branch branch);
  [%expect {| x->a*y->b => ens x->b*y->a |}]

(* Test: Full case spec pretty printing *)
let%expect_test "case_spec_pp" =
  let a = ("a", Int) in
  let b = ("b", Int) in
  (* Case 1: type only *)
  let case1_pre = { empty_qstate with qs_pure = And (Colon ("x", var "Ref" Any), Colon ("y", var "Ref" Any)) } in
  let case1_post = { empty_qstate with qs_pure = Colon ("r", { term_desc = Const ValUnit; term_type = Unit }) } in
  (* Case 2: separate refs *)
  let case2_pre = qstate_of_state (True, SepConj (PointsTo ("x", var "a" Int), PointsTo ("y", var "b" Int))) in
  let case2_post = qstate_of_state (True, SepConj (PointsTo ("x", var "b" Int), PointsTo ("y", var "a" Int))) in
  (* Case 3: aliased refs *)
  let case3_pre = { (qstate_of_state (True, PointsTo ("x", var "a" Int))) with
                    qs_pure = Atomic (EQ, var "y" Int, var "x" Int) } in
  let case3_post = qstate_of_state (True, PointsTo ("x", var "a" Int)) in
  let spec = make_case_spec ~forall:[a; b] ["x"; "y"] [
    make_case_branch case1_pre case1_post;
    make_case_branch case2_pre case2_post;
    make_case_branch case3_pre case3_post;
  ] in
  print_endline (string_of_case_spec spec);
  [%expect {|
    forall a b. case [x, y] {
      x:Ref/\y:Ref => ens r:();
      x->a*y->b => ens x->b*y->a;
      x->a /\ y=x => ens x->a
    } |}]

(* Test: Alias compatibility *)
let%expect_test "alias_compatibility" =
  Printf.printf "Separate vs MustAlias: %b\n" (compatible_alias Separate MustAlias);
  Printf.printf "Separate vs MayAlias: %b\n" (compatible_alias Separate MayAlias);
  Printf.printf "MustAlias vs MayAlias: %b\n" (compatible_alias MustAlias MayAlias);
  Printf.printf "MayAlias vs MayAlias: %b\n" (compatible_alias MayAlias MayAlias);
  [%expect {|
    Separate vs MustAlias: false
    Separate vs MayAlias: true
    MustAlias vs MayAlias: true
    MayAlias vs MayAlias: true |}]
