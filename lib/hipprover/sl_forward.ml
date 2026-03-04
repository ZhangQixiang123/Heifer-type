(** Separation Logic Forward Verifier

    This module performs forward symbolic execution on code
    and produces sl_spec specifications directly.

    Unlike the staged forward verifier, this generates clean
    separation logic specs without complex staging constructs.
*)

open Hipcore_typed
open Typed_core_ast
open Typedhip
open Utils.Hstdlib
open Sl_types

(** Environment for forward verification *)
type sl_fvenv = {
  slfv_methods: meth_def SMap.t;
  slfv_predicates: pred_def SMap.t;
  slfv_assumed_pre: qstate option;  (** Assumed precondition for case-based verification *)
}

(** Create an environment *)
let create_env methods predicates = {
  slfv_methods = methods;
  slfv_predicates = predicates;
  slfv_assumed_pre = None;
}

(** Create an environment with assumed precondition *)
let create_env_with_pre methods predicates pre = {
  slfv_methods = methods;
  slfv_predicates = predicates;
  slfv_assumed_pre = pre;
}

(** Fresh variable counter *)
let var_counter = ref 0

(** Generate a fresh variable name *)
let fresh_var prefix =
  let n = !var_counter in
  incr var_counter;
  prefix ^ string_of_int n

(** Reset variable counter (for testing) *)
let reset_counter () = var_counter := 0

(** Find value for a location in the assumed precondition heap.
    Used for case-based verification where we know the precondition. *)
let find_in_assumed_heap (pre: qstate option) (loc: string) : term option =
  match pre with
  | None -> None
  | Some qs ->
      let rec find_in_kappa k =
        match k with
        | EmptyHeap -> None
        | PointsTo (l, v) -> if l = loc then Some v else None
        | RecordPointsTo (l, _fields) ->
            if l = loc then None else None  (* TODO: handle records *)
        | SepConj (k1, k2) ->
            (match find_in_kappa k1 with
             | Some v -> Some v
             | None -> find_in_kappa k2)
      in
      find_in_kappa qs.qs_heap

(** Create a term from a variable name *)
let var_term name typ = { term_desc = Var name; term_type = typ }

(** Create a term from an integer *)
let num_term n = { term_desc = Const (Num n); term_type = Int }

(** Create res = t equality *)
let res_eq (t: term) : pi =
  Atomic (EQ, var_term "res" t.term_type, t)

(** List of primitive functions that are pure computations *)
let primitive_functions = ["+"; "-"; "*"; "="; "not"; "::"; "&&"; "||"; ">"; "<"; ">="; "<="; "^"; "string_of_int"]

(** Check if a function name is a primitive *)
let is_primitive (name: string) : bool =
  List.mem name primitive_functions

(** Create a term for primitive function application *)
let call_primitive_term (name: string) (args: term list) (result_type: typ) : term =
  match name, args with
  | "+", [x1; x2] -> { term_desc = BinOp (Plus, x1, x2); term_type = result_type }
  | "-", [x1; x2] -> { term_desc = BinOp (Minus, x1, x2); term_type = result_type }
  | "*", [x1; x2] -> { term_desc = BinOp (TTimes, x1, x2); term_type = result_type }
  | "=", [x1; x2] -> { term_desc = Rel (EQ, x1, x2); term_type = result_type }
  | ">", [x1; x2] -> { term_desc = Rel (GT, x1, x2); term_type = result_type }
  | "<", [x1; x2] -> { term_desc = Rel (LT, x1, x2); term_type = result_type }
  | ">=", [x1; x2] -> { term_desc = Rel (GTEQ, x1, x2); term_type = result_type }
  | "<=", [x1; x2] -> { term_desc = Rel (LTEQ, x1, x2); term_type = result_type }
  | "not", [x] -> { term_desc = TNot x; term_type = result_type }
  | "::", [x1; x2] -> { term_desc = Construct ("::", [x1; x2]); term_type = result_type }
  | "&&", [x1; x2] -> { term_desc = BinOp (TAnd, x1, x2); term_type = result_type }
  | "||", [x1; x2] -> { term_desc = BinOp (TOr, x1, x2); term_type = result_type }
  | "^", [x1; x2] -> { term_desc = TApp ("^", [x1; x2]); term_type = result_type }
  | "string_of_int", [x] -> { term_desc = TApp ("string_of_int", [x]); term_type = result_type }
  | _ -> { term_desc = TApp (name, args); term_type = result_type }

(** Combine two sl_specs sequentially.
    Preconditions combine with *, postconditions combine with *.
    The first spec's postcondition should establish facts
    that the second spec can rely on. *)
let combine_sl_specs (s1: sl_spec) (s2: sl_spec) : sl_spec =
  let combined_pre = match s1.sl_pre, s2.sl_pre with
    | None, p | p, None -> p
    | Some p1, Some p2 -> Some (combine_qstate p1 p2)
  in
  let combined_post = combine_qstate s1.sl_post s2.sl_post in
  { sl_pre = combined_pre; sl_post = combined_post }

(** Apply substitution [res -> x] in a qstate *)
let subst_res_in_qstate (x: string) (qs: qstate) : qstate =
  let subst_in_term t =
    match t.term_desc with
    | Var "res" -> { t with term_desc = Var x }
    | _ -> t
  in
  let rec subst_in_pi p =
    match p with
    | True | False -> p
    | Atomic (op, t1, t2) -> Atomic (op, subst_in_term t1, subst_in_term t2)
    | And (p1, p2) -> And (subst_in_pi p1, subst_in_pi p2)
    | Or (p1, p2) -> Or (subst_in_pi p1, subst_in_pi p2)
    | Imply (p1, p2) -> Imply (subst_in_pi p1, subst_in_pi p2)
    | Not p1 -> Not (subst_in_pi p1)
    | Predicate (n, ts) -> Predicate (n, List.map subst_in_term ts)
    | Subsumption (t1, t2) -> Subsumption (subst_in_term t1, subst_in_term t2)
    | Colon (n, t) -> Colon (n, subst_in_term t)
  in
  let rec subst_in_kappa k =
    match k with
    | EmptyHeap -> EmptyHeap
    | PointsTo (loc, t) ->
        let loc' = if loc = "res" then x else loc in
        PointsTo (loc', subst_in_term t)
    | RecordPointsTo (loc, fields) ->
        let loc' = if loc = "res" then x else loc in
        RecordPointsTo (loc', List.map (fun (n, t) -> (n, subst_in_term t)) fields)
    | SepConj (k1, k2) -> SepConj (subst_in_kappa k1, subst_in_kappa k2)
  in
  { qs with
    qs_pure = subst_in_pi qs.qs_pure;
    qs_heap = subst_in_kappa qs.qs_heap;
  }

(** Apply substitution [res -> x] in a spec *)
let subst_res (x: string) (spec: sl_spec) : sl_spec =
  {
    sl_pre = Option.map (subst_res_in_qstate x) spec.sl_pre;
    sl_post = subst_res_in_qstate x spec.sl_post;
  }

(** Forward verification result - now with disjunction support *)
type sl_result =
  | SL_Spec of sl_spec_disj
  | SL_Unsupported of string

(** Wrap a simple sl_spec into the result type *)
let single_result (s: sl_spec) : sl_result =
  SL_Spec (SL_Single s)

(** Map a function over all branches of sl_spec_disj *)
let rec map_disj (f: sl_spec -> sl_spec) (d: sl_spec_disj) : sl_spec_disj =
  match d with
  | SL_Single s -> SL_Single (f s)
  | SL_Disj { cond; then_spec; else_spec } ->
      SL_Disj { cond; then_spec = map_disj f then_spec; else_spec = map_disj f else_spec }

(** Merge a single spec with all branches of a disjunction *)
let rec merge_single_with_disj (s1: sl_spec) (d2: sl_spec_disj) (merge_fn: sl_spec -> sl_spec -> sl_spec) : sl_spec_disj =
  match d2 with
  | SL_Single s2 -> SL_Single (merge_fn s1 s2)
  | SL_Disj { cond; then_spec; else_spec } ->
      SL_Disj { cond;
                then_spec = merge_single_with_disj s1 then_spec merge_fn;
                else_spec = merge_single_with_disj s1 else_spec merge_fn }

(** Merge two disjunctive specs *)
let rec merge_disj_specs (d1: sl_spec_disj) (d2: sl_spec_disj) (merge_fn: sl_spec -> sl_spec -> sl_spec) : sl_spec_disj =
  match d1 with
  | SL_Single s1 -> merge_single_with_disj s1 d2 merge_fn
  | SL_Disj { cond; then_spec; else_spec } ->
      SL_Disj { cond;
                then_spec = merge_disj_specs then_spec d2 merge_fn;
                else_spec = merge_disj_specs else_spec d2 merge_fn }

(** Forward verification for a core language expression.
    Returns sl_spec that captures the behavior. *)
let rec sl_forward (_env: sl_fvenv) (expr: core_lang) : sl_result =
  match expr.core_desc with

  (* Value: ens res = v *)
  | CValue v ->
      single_result {
        sl_pre = None;
        sl_post = {
          qs_forall = [];
          qs_exists = [];
          qs_pure = res_eq v;
          qs_heap = EmptyHeap;
        }
      }

  (* Read: forall v. req x->v; ens x->v /\ res=v *)
  (* When precondition is assumed, use the known value instead of fresh variable *)
  | CRead x ->
      (match find_in_assumed_heap _env.slfv_assumed_pre x with
       | Some known_value ->
           (* Value known from assumed precondition - no fresh quantification needed *)
           single_result {
             sl_pre = None;  (* Already assumed *)
             sl_post = {
               qs_forall = [];
               qs_exists = [];
               qs_pure = res_eq known_value;
               qs_heap = PointsTo (x, known_value);
             }
           }
       | None ->
           (* No assumed value - use fresh universal quantification *)
           let v = fresh_var "v" in
           let v_term = var_term v expr.core_type in
           let binder = (v, expr.core_type) in
           single_result {
             sl_pre = Some {
               qs_forall = [binder];
               qs_exists = [];
               qs_pure = True;
               qs_heap = PointsTo (x, v_term);
             };
             sl_post = {
               qs_forall = [binder];
               qs_exists = [];
               qs_pure = res_eq v_term;
               qs_heap = PointsTo (x, v_term);
             }
           })

  (* Write: forall old. req x->old; ens x->t *)
  | CWrite (x, t) ->
      let old = fresh_var "old" in
      let old_term = var_term old t.term_type in
      let binder = (old, t.term_type) in
      single_result {
        sl_pre = Some {
          qs_forall = [binder];
          qs_exists = [];
          qs_pure = True;
          qs_heap = PointsTo (x, old_term);
        };
        sl_post = {
          qs_forall = [binder];
          qs_exists = [];
          qs_pure = True;
          qs_heap = PointsTo (x, t);
        }
      }

  (* Ref: exists loc. ens res=loc * loc->v *)
  | CRef v ->
      let loc = fresh_var "loc" in
      let ref_type = TConstr ("ref", [v.term_type]) in
      let loc_term = var_term loc ref_type in
      let binder = (loc, ref_type) in
      single_result {
        sl_pre = None;
        sl_post = {
          qs_forall = [];
          qs_exists = [binder];
          qs_pure = res_eq loc_term;
          qs_heap = PointsTo (loc, v);
        }
      }

  (* Let binding: combine specs, substitute res->x in first *)
  | CLet ((x, _xt), e1, e2) ->
      (match sl_forward _env e1 with
       | SL_Unsupported msg -> SL_Unsupported msg
       | SL_Spec d1 ->
           let d1' = map_disj (subst_res x) d1 in
           match sl_forward _env e2 with
           | SL_Unsupported msg -> SL_Unsupported msg
           | SL_Spec d2 ->
               (* Merge the two specs - this is the key for read-then-write *)
               SL_Spec (merge_disj_specs d1' d2 merge_sequential_specs))

  (* Sequence: like let but discard first result *)
  | CSequence (e1, e2) ->
      (match sl_forward _env e1 with
       | SL_Unsupported msg -> SL_Unsupported msg
       | SL_Spec d1 ->
           match sl_forward _env e2 with
           | SL_Unsupported msg -> SL_Unsupported msg
           | SL_Spec d2 ->
               SL_Spec (merge_disj_specs d1 d2 merge_sequential_specs))

  (* If-else: produces disjunction of both branches *)
  | CIfElse (cond, e1, e2) ->
      (match sl_forward _env e1, sl_forward _env e2 with
       | SL_Spec d1, SL_Spec d2 ->
           (* Create disjunction: (cond => d1) \/ (~cond => d2) *)
           SL_Spec (SL_Disj { cond; then_spec = d1; else_spec = d2 })
       | SL_Unsupported msg, _ | _, SL_Unsupported msg ->
           SL_Unsupported msg)

  (* Primitive function calls - pure operations with no heap effects *)
  | CFunCall (name, args) when is_primitive name ->
      single_result {
        sl_pre = None;
        sl_post = {
          qs_forall = [];
          qs_exists = [];
          qs_pure = res_eq (call_primitive_term name args expr.core_type);
          qs_heap = EmptyHeap;
        }
      }

  (* Other function calls - not supported *)
  | CFunCall _ -> SL_Unsupported "Non-primitive function calls"
  | CPerform _ -> SL_Unsupported "Effect operations"
  | CMatch _ -> SL_Unsupported "Pattern matching"
  | CResume _ -> SL_Unsupported "Resumptions"
  | CLambda _ -> SL_Unsupported "Lambda expressions"
  | CShift _ -> SL_Unsupported "Shift"
  | CReset _ -> SL_Unsupported "Reset"
  (* Record creation: exists loc. ens res=loc * loc.f1->v1 * loc.f2->v2 ... *)
  | CRecord fields ->
      (* For simple field values, extract directly *)
      let field_terms = List.filter_map (fun (name, field_expr) ->
        match field_expr.core_desc with
        | CValue v -> Some (name, v)
        | _ -> None
      ) fields in
      if List.length field_terms <> List.length fields then
        SL_Unsupported "Complex field expressions in records"
      else
        let loc = fresh_var "rec" in
        let loc_term = var_term loc expr.core_type in
        let binder = (loc, expr.core_type) in
        (* Per-field decomposition: each field is a separate PointsTo *)
        let field_heap = List.fold_left (fun acc (fname, fterm) ->
          let cell = PointsTo (loc ^ "." ^ fname, fterm) in
          match acc with
          | EmptyHeap -> cell
          | _ -> SepConj (acc, cell)
        ) EmptyHeap field_terms in
        single_result {
          sl_pre = None;
          sl_post = {
            qs_forall = [];
            qs_exists = [binder];
            qs_pure = res_eq loc_term;
            qs_heap = field_heap;
          }
        }

  (* Field access: evaluate record, return field value *)
  | CGetField (record_expr, field_name) ->
      (match sl_forward _env record_expr with
       | SL_Unsupported msg -> SL_Unsupported msg
       | SL_Spec d1 ->
           let loc = fresh_var "rec" in
           let d1' = map_disj (subst_res loc) d1 in
           let get_field_term = {
             term_desc = TGetField (var_term loc record_expr.core_type, field_name);
             term_type = expr.core_type
           } in
           let field_read_spec = {
             sl_pre = None;
             sl_post = {
               qs_forall = [];
               qs_exists = [];
               qs_pure = res_eq get_field_term;
               qs_heap = EmptyHeap;
             }
           } in
           SL_Spec (merge_disj_specs d1' (SL_Single field_read_spec) merge_sequential_specs))

  (* Field mutation: evaluate record and value, return unit *)
  | CSetField (record_expr, _field_name, value_expr) ->
      (match sl_forward _env record_expr, sl_forward _env value_expr with
       | SL_Unsupported msg, _ | _, SL_Unsupported msg -> SL_Unsupported msg
       | SL_Spec d1, SL_Spec d2 ->
           let loc = fresh_var "rec" in
           let d1' = map_disj (subst_res loc) d1 in
           let new_val = fresh_var "new" in
           let d2' = map_disj (subst_res new_val) d2 in
           let unit_term = { term_desc = Const ValUnit; term_type = Unit } in
           let unit_spec = {
             sl_pre = None;
             sl_post = {
               qs_forall = [];
               qs_exists = [];
               qs_pure = res_eq unit_term;
               qs_heap = EmptyHeap;
             }
           } in
           let merged = merge_disj_specs d1' d2' merge_sequential_specs in
           SL_Spec (merge_disj_specs merged (SL_Single unit_spec) merge_sequential_specs))
  | CAssert _ -> SL_Unsupported "Assert (TODO)"

(** Merge specs for sequential composition.
    The key insight: if both specs access the same location,
    we need to unify the values.

    For x := !x + 1:
    - Read: forall v. req x->v; ens x->v /\ res=v
    - Write: forall old. req x->old; ens x->(v+1)

    After merging with substitution:
    - forall v. req x->v; ens x->(v+1)
*)
and merge_sequential_specs (s1: sl_spec) (s2: sl_spec) : sl_spec =
  (* Collect all quantifiers from both specs *)
  let post1_forall = s1.sl_post.qs_forall in
  let post1_exists = s1.sl_post.qs_exists in
  let pre2_forall = match s2.sl_pre with Some qs -> qs.qs_forall | None -> [] in

  (* Build substitution: for each location in s1.post and s2.pre, unify values *)
  let subst = compute_unification s1.sl_post s2.sl_pre in

  (* Apply substitution to s2 *)
  let s2' = apply_subst_to_spec subst s2 in

  (* Merge preconditions: s1.pre plus any parts of s2.pre not covered by s1.post *)
  let merged_pre = match s1.sl_pre, s2'.sl_pre with
    | Some p1, Some p2 ->
        (* Take s1's precondition, plus any heap cells from s2.pre not in s1.post *)
        let s1_post_locs = collect_locations s1.sl_post.qs_heap |> List.map fst in
        let extra_heap = filter_heap_by_locs p2.qs_heap
          (fun loc -> not (List.mem loc s1_post_locs)) in
        Some {
          qs_forall = p1.qs_forall @ (List.filter (fun b -> not (List.mem b post1_forall)) pre2_forall);
          qs_exists = p1.qs_exists @ p2.qs_exists;
          qs_pure = combine_pure p1.qs_pure p2.qs_pure;
          qs_heap = combine_heap p1.qs_heap extra_heap;
        }
    | Some p, None -> Some p
    | None, Some p -> Some (apply_subst_to_qstate subst p)
    | None, None -> None
  in

  (* Merge postconditions: use s2's postcondition (it's the final state) *)
  (* But keep heap facts from s1 that weren't overwritten *)
  let merged_post = {
    qs_forall = post1_forall @ (List.filter (fun b -> not (List.mem b post1_forall)) s2'.sl_post.qs_forall);
    qs_exists = post1_exists @ s2'.sl_post.qs_exists;
    qs_pure = combine_pure_final s1.sl_post.qs_pure s2'.sl_post.qs_pure;
    qs_heap = merge_heaps s1.sl_post.qs_heap s2'.sl_post.qs_heap;
  } in

  { sl_pre = merged_pre; sl_post = merged_post }

(** Compute substitution to unify matching locations between post and pre *)
and compute_unification (post: qstate) (pre: qstate option) : (string * term) list =
  match pre with
  | None -> []
  | Some pre_qs ->
      let post_locs = collect_locations post.qs_heap in
      let pre_locs = collect_locations pre_qs.qs_heap in
      (* For each location in both, create substitution *)
      List.filter_map (fun (loc, post_val) ->
        match List.assoc_opt loc pre_locs with
        | Some pre_val ->
            (* If pre has a variable for this location, substitute it with post's value *)
            (match pre_val.term_desc with
             | Var v when is_fresh_var v -> Some (v, post_val)
             | _ -> None)
        | None -> None
      ) post_locs

(** Check if a variable name is a fresh generated variable *)
and is_fresh_var (v: string) : bool =
  String.length v > 0 &&
  (String.get v 0 = 'v' || String.get v 0 = 'o') &&  (* v123 or old123 *)
  try
    let rest = String.sub v 1 (String.length v - 1) in
    int_of_string rest |> ignore; true
  with Failure _ -> false

(** Collect location -> value mappings from heap *)
and collect_locations (k: kappa) : (string * term) list =
  match k with
  | EmptyHeap -> []
  | PointsTo (loc, t) -> [(loc, t)]
  | RecordPointsTo (loc, fields) ->
      let record_term = { term_desc = TRecordTerm fields; term_type = TRecord (List.map (fun (n, t) -> (n, t.term_type)) fields) } in
      [(loc, record_term)]
  | SepConj (k1, k2) -> collect_locations k1 @ collect_locations k2

(** Filter heap to keep only locations matching predicate *)
and filter_heap_by_locs (k: kappa) (pred: string -> bool) : kappa =
  match k with
  | EmptyHeap -> EmptyHeap
  | PointsTo (loc, t) -> if pred loc then PointsTo (loc, t) else EmptyHeap
  | RecordPointsTo (loc, fields) -> if pred loc then RecordPointsTo (loc, fields) else EmptyHeap
  | SepConj (k1, k2) ->
      let k1' = filter_heap_by_locs k1 pred in
      let k2' = filter_heap_by_locs k2 pred in
      combine_heap k1' k2'

(** Apply substitution to a term *)
and apply_subst_to_term (subst: (string * term) list) (t: term) : term =
  match t.term_desc with
  | Var v ->
      (match List.assoc_opt v subst with
       | Some t' -> t'
       | None -> t)
  | BinOp (op, t1, t2) ->
      { t with term_desc = BinOp (op, apply_subst_to_term subst t1, apply_subst_to_term subst t2) }
  | Rel (op, t1, t2) ->
      { t with term_desc = Rel (op, apply_subst_to_term subst t1, apply_subst_to_term subst t2) }
  | TNot t1 ->
      { t with term_desc = TNot (apply_subst_to_term subst t1) }
  | TApp (f, args) ->
      { t with term_desc = TApp (f, List.map (apply_subst_to_term subst) args) }
  | Construct (c, args) ->
      { t with term_desc = Construct (c, List.map (apply_subst_to_term subst) args) }
  | TTuple ts ->
      { t with term_desc = TTuple (List.map (apply_subst_to_term subst) ts) }
  | TRecordTerm fields ->
      { t with term_desc = TRecordTerm (List.map (fun (n, v) -> (n, apply_subst_to_term subst v)) fields) }
  | TGetField (t1, f) ->
      { t with term_desc = TGetField (apply_subst_to_term subst t1, f) }
  | _ -> t

(** Apply substitution to pure formula *)
and apply_subst_to_pi (subst: (string * term) list) (p: pi) : pi =
  match p with
  | True | False -> p
  | Atomic (op, t1, t2) ->
      Atomic (op, apply_subst_to_term subst t1, apply_subst_to_term subst t2)
  | And (p1, p2) -> And (apply_subst_to_pi subst p1, apply_subst_to_pi subst p2)
  | Or (p1, p2) -> Or (apply_subst_to_pi subst p1, apply_subst_to_pi subst p2)
  | Imply (p1, p2) -> Imply (apply_subst_to_pi subst p1, apply_subst_to_pi subst p2)
  | Not p1 -> Not (apply_subst_to_pi subst p1)
  | Predicate (n, ts) -> Predicate (n, List.map (apply_subst_to_term subst) ts)
  | Subsumption (t1, t2) -> Subsumption (apply_subst_to_term subst t1, apply_subst_to_term subst t2)
  | Colon (n, t) -> Colon (n, apply_subst_to_term subst t)

(** Apply substitution to heap *)
and apply_subst_to_kappa (subst: (string * term) list) (k: kappa) : kappa =
  match k with
  | EmptyHeap -> EmptyHeap
  | PointsTo (loc, t) -> PointsTo (loc, apply_subst_to_term subst t)
  | RecordPointsTo (loc, fields) ->
      RecordPointsTo (loc, List.map (fun (n, t) -> (n, apply_subst_to_term subst t)) fields)
  | SepConj (k1, k2) ->
      SepConj (apply_subst_to_kappa subst k1, apply_subst_to_kappa subst k2)

(** Apply substitution to qstate *)
and apply_subst_to_qstate (subst: (string * term) list) (qs: qstate) : qstate =
  (* Remove substituted vars from forall/exists *)
  let subst_vars = List.map fst subst in
  {
    qs_forall = List.filter (fun (v, _) -> not (List.mem v subst_vars)) qs.qs_forall;
    qs_exists = List.filter (fun (v, _) -> not (List.mem v subst_vars)) qs.qs_exists;
    qs_pure = apply_subst_to_pi subst qs.qs_pure;
    qs_heap = apply_subst_to_kappa subst qs.qs_heap;
  }

(** Apply substitution to sl_spec *)
and apply_subst_to_spec (subst: (string * term) list) (spec: sl_spec) : sl_spec =
  {
    sl_pre = Option.map (apply_subst_to_qstate subst) spec.sl_pre;
    sl_post = apply_subst_to_qstate subst spec.sl_post;
  }

(** Combine pure parts, taking the latest value for res *)
and combine_pure_final (p1: pi) (p2: pi) : pi =
  (* Always combine both pure formulas to preserve equality constraints.
     The res = something from p2 takes precedence, but we keep other
     constraints from p1 (like tmp=v37 from earlier reads). *)
  combine_pure p1 p2

(** Check if a pure formula contains res = ... *)
and has_res_eq (p: pi) : bool =
  match p with
  | Atomic (EQ, t1, _) -> is_res_var t1
  | Atomic (EQ, _, t2) -> is_res_var t2
  | And (p1, p2) -> has_res_eq p1 || has_res_eq p2
  | Or (p1, p2) -> has_res_eq p1 || has_res_eq p2
  | _ -> false

(** Check if term is the res variable *)
and is_res_var (t: term) : bool =
  match t.term_desc with
  | Var "res" -> true
  | _ -> false

(** Merge heaps: keep s2's version for modified locations, s1 for unmodified *)
and merge_heaps (h1: kappa) (h2: kappa) : kappa =
  let locs1 = collect_locations h1 in
  let locs2 = collect_locations h2 in
  (* Use h2's values, add any from h1 not in h2 *)
  let h2_locs = List.map fst locs2 in
  let h1_remaining = List.filter (fun (loc, _) -> not (List.mem loc h2_locs)) locs1 in
  let remaining_heap = List.fold_left (fun acc (loc, t) ->
    combine_heap acc (PointsTo (loc, t))
  ) EmptyHeap h1_remaining in
  combine_heap h2 remaining_heap

(* combine_branch_specs removed - now using SL_Disj directly in CIfElse *)

(** Forward verification with assumed precondition.

    When pre is provided:
    - Heap reads use values from pre.qs_heap if present
    - This enables case-by-case verification where each case's
      precondition is assumed before analyzing the body.

    @param env Forward verification environment
    @param pre Optional precondition to assume
    @param expr Expression to analyze
    @return Inferred specification *)
let sl_forward_with_pre (env: sl_fvenv) (pre: qstate option) (expr: core_lang) : sl_result =
  let env' = { env with slfv_assumed_pre = pre } in
  sl_forward env' expr
