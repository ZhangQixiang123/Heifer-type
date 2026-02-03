(** Level 2 State Entailment: (pi * kappa) |- (pi * kappa)

    This module provides a generalized entailment check at the state level,
    combining heap biabduction with pure formula entailment via SMT solver.

    It sits between:
    - Level 1: Individual heap (Biab) and pure (Provers) entailment
    - Level 3: Full staged_spec entailment (entail.ml)
*)

open Hipcore_typed
open Typedhip
open Pretty
open Debug

(** Context for state entailment *)
type state_entail_ctx = {
  assumptions : pi list;      (** Pure assumptions from proof context *)
  existentials : binder list; (** Variables to existentially quantify on RHS *)
}

let empty_ctx = { assumptions = []; existentials = [] }

(** Success result record *)
type success_result = {
  frame : state;          (** Leftover from LHS after matching RHS *)
  anti_frame : state;     (** Required by RHS but missing from LHS *)
  constraints : pi list;  (** Generated equalities from heap matching *)
}

(** Result of state entailment *)
type state_entail_result =
  | Success of success_result
  | Failure of string

let string_of_pi_list pis =
  match pis with
  | [] -> "[]"
  | _ -> "[" ^ (String.concat "; " (List.map string_of_pi pis)) ^ "]"

let string_of_result r =
  match r with
  | Success { frame; anti_frame; constraints } ->
      Format.asprintf "Success(frame=%s, anti_frame=%s, constraints=%s)"
        (string_of_state frame)
        (string_of_state anti_frame)
        (string_of_pi_list constraints)
  | Failure reason ->
      Format.asprintf "Failure(%s)" reason

(** Check pure entailment via Z3/Why3 *)
let check_pure (existentials : binder list) (lhs : pi) (rhs : pi) : bool =
  let lhs = Simpl.simplify_pure lhs in
  let rhs = Simpl.simplify_pure rhs in
  match Provers.entails_exists lhs existentials rhs with
  | Provers_common.Valid -> true
  | _ -> false

(** Main state entailment function.

    Checks if [lhs] entails [rhs], computing:
    - frame: what remains from [lhs] after satisfying [rhs]
    - anti_frame: what [rhs] requires but [lhs] doesn't provide
    - constraints: equalities generated during heap matching

    @param ctx Optional context with assumptions and existentials
    @param lhs Left-hand side state (what we have)
    @param rhs Right-hand side state (what we need)
    @return Success with frame/anti-frame/constraints, or Failure
*)
(** Extract equalities of form x=y from a pi formula.
    Returns both directions (x,y) and (y,x) so we can substitute either way. *)
let rec extract_var_equalities (pi : pi) : (string * string) list =
  match pi with
  | Atomic (EQ, {term_desc = Var x; _}, {term_desc = Var y; _}) ->
      [(x, y); (y, x)]  (* Both directions *)
  | And (p1, p2) -> extract_var_equalities p1 @ extract_var_equalities p2
  | _ -> []

(** Substitute location names in a kappa using equalities.
    If we have equality (x, y), replace x with y in all PointsTo locations.
    Prioritize substituting to "res" since that's the return value. *)
let rec subst_location_in_kappa (subst : (string * string) list) (kappa : kappa) : kappa =
  let find_subst loc =
    (* Prefer substituting to "res" if available *)
    match List.find_opt (fun (from, into) -> from = loc && into = "res") subst with
    | Some (_, into) -> into
    | None -> List.assoc_opt loc subst |> Option.value ~default:loc
  in
  match kappa with
  | EmptyHeap -> EmptyHeap
  | PointsTo (loc, value) ->
      PointsTo (find_subst loc, value)
  | RecordPointsTo (loc, fields) ->
      RecordPointsTo (find_subst loc, fields)
  | SepConj (k1, k2) ->
      SepConj (subst_location_in_kappa subst k1, subst_location_in_kappa subst k2)

let entail_state ?(ctx = empty_ctx) ((pi_l, kappa_l) : state) ((pi_r, kappa_r) : state)
    : state_entail_result =
  debug ~at:4 ~title:"state_entail"
    "(%s, %s) |- (%s, %s)"
    (string_of_pi pi_l)
    (string_of_kappa kappa_l)
    (string_of_pi pi_r)
    (string_of_kappa kappa_r);

  (* Extract equalities from LHS pure part and substitute into LHS heap.
     This allows biabduction to match v1->42 with res->42 when we have res=v1. *)
  let var_eqs = extract_var_equalities pi_l in
  let kappa_l = subst_location_in_kappa var_eqs kappa_l in

  debug ~at:4 ~title:"state_entail after subst"
    "kappa_l = %s (subst: %s)"
    (string_of_kappa kappa_l)
    (String.concat ", " (List.map (fun (a,b) -> a ^ "=" ^ b) var_eqs));

  (* Step 1: Heap entailment via biabduction *)
  let _common, anti_frame_h, frame_h, heap_eqs =
    Biab.solve Biab.emp_biab_ctx kappa_l kappa_r
  in

  (* Step 2: Convert heap results to kappa *)
  let frame_kappa = Syntax.sep_conj frame_h in
  let anti_frame_kappa = Syntax.sep_conj anti_frame_h in

  (* Step 3: Build pure obligation
     LHS context: assumptions + LHS pure + heap equalities *)
  let lhs_pure = Syntax.conj (ctx.assumptions @ [pi_l] @ heap_eqs) in
  let rhs_pure = pi_r in

  (* Step 4: Check pure entailment via Z3 *)
  let pure_valid = check_pure ctx.existentials lhs_pure rhs_pure in

  (* Step 5: Return result *)
  let result =
    if pure_valid then
      Success {
        frame = (True, frame_kappa);
        anti_frame = (True, anti_frame_kappa);
        constraints = heap_eqs;
      }
    else
      Failure "Pure entailment failed"
  in
  debug ~at:4 ~title:"state_entail result" "%s" (string_of_result result);
  result

(** Convenience wrapper that returns option *)
let entail_state_opt ?ctx lhs rhs =
  match entail_state ?ctx lhs rhs with
  | Success r -> Some r
  | Failure _ -> None

(** Check if entailment succeeds (discards frame info) *)
let check_state_entailment ?ctx lhs rhs =
  match entail_state ?ctx lhs rhs with
  | Success _ -> true
  | Failure _ -> false

(* ============================================================ *)
(* Unit Tests *)
(* ============================================================ *)

let%expect_test "empty_state_entailment" =
  let r = entail_state (True, EmptyHeap) (True, EmptyHeap) in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Success(frame=emp, anti_frame=emp, constraints=[]) |}]

let%expect_test "simple_heap_entailment" =
  let open Syntax in
  let h1 = PointsTo ("x", num 1) in
  let h2 = PointsTo ("x", num 1) in
  let r = entail_state (True, h1) (True, h2) in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Success(frame=emp, anti_frame=emp, constraints=[]) |}]

let%expect_test "frame_discovery" =
  let open Syntax in
  (* x->1 * y->2 |- x->1 should give frame y->2 *)
  let h1 = SepConj (PointsTo ("x", num 1), PointsTo ("y", num 2)) in
  let h2 = PointsTo ("x", num 1) in
  let r = entail_state (True, h1) (True, h2) in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Success(frame=y->2, anti_frame=emp, constraints=[]) |}]

let%expect_test "anti_frame_discovery" =
  let open Syntax in
  (* x->1 |- x->1 * y->2 should give anti_frame y->2 *)
  let h1 = PointsTo ("x", num 1) in
  let h2 = SepConj (PointsTo ("x", num 1), PointsTo ("y", num 2)) in
  let r = entail_state (True, h1) (True, h2) in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Success(frame=emp, anti_frame=y->2, constraints=[]) |}]

let%expect_test "heap_equality_generation" =
  let open Syntax in
  (* x->a |- x->1 should generate constraint a=1 *)
  let h1 = PointsTo ("x", var "a") in
  let h2 = PointsTo ("x", num 1) in
  let r = entail_state (True, h1) (True, h2) in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Success(frame=emp, anti_frame=emp, constraints=[a=1]) |}]

let%expect_test "pure_entailment_with_assumptions" =
  let open Syntax in
  (* With assumption a=1: (b=a, emp) |- (b=1, emp) *)
  let ctx = { assumptions = [eq (var "a") (num 1)]; existentials = [] } in
  let r = entail_state ~ctx (eq (var "b") (var "a"), EmptyHeap) (eq (var "b") (num 1), EmptyHeap) in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Success(frame=emp, anti_frame=emp, constraints=[]) |}]

let%expect_test "pure_entailment_failure" =
  let open Syntax in
  (* (x=1, emp) |- (x=2, emp) should fail *)
  let r = entail_state (eq (var "x") (num 1), EmptyHeap) (eq (var "x") (num 2), EmptyHeap) in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Failure(Pure entailment failed) |}]
