(** Simple Separation Logic Entailment

    This module provides entailment checking for simple_spec, which uses
    only pre/post conditions without effects or exceptions.

    It leverages State_entail.entail_state for the core entailment logic.
*)

open Hipcore_typed
open Typedhip
open Pretty
open Debug

(** Result of simple spec entailment *)
type simple_entail_result =
  | Valid
  | Invalid of string

let string_of_result = function
  | Valid -> "Valid"
  | Invalid reason -> Format.sprintf "Invalid(%s)" reason

(** Convert simple_spec to staged_spec for compatibility with existing entailment *)
let staged_of_simple (ss : simple_spec) : staged_spec =
  (* Build base spec: req pre; ens post *)
  let base =
    match ss.ss_precond with
    | None ->
        (* No precondition: just postcondition *)
        let (post_pi, post_kappa) = ss.ss_postcond in
        NormalReturn (post_pi, post_kappa)
    | Some (pre_pi, pre_kappa) ->
        (* Both pre and post *)
        let (post_pi, post_kappa) = ss.ss_postcond in
        Sequence (
          Require (pre_pi, pre_kappa),
          NormalReturn (post_pi, post_kappa)
        )
  in
  (* Wrap with existential quantifiers *)
  let with_ex = List.fold_right (fun x s -> Exists (x, s)) ss.ss_ex base in
  (* Wrap with universal quantifiers *)
  let with_fa = List.fold_right (fun x s -> ForAll (x, s)) ss.ss_fa with_ex in
  with_fa

(** Helper to combine two states with conjunction *)
let combine_states (pi1, kappa1) (pi2, kappa2) =
  let combined_pi = match pi1, pi2 with
    | True, p | p, True -> p
    | p1, p2 -> And (p1, p2)
  in
  let combined_kappa = match kappa1, kappa2 with
    | EmptyHeap, k | k, EmptyHeap -> k
    | k1, k2 -> SepConj (k1, k2)
  in
  (combined_pi, combined_kappa)

(** Match heap locations between two kappas and generate equalities.
    Returns: (matched_eqs, remaining_from_kappa1, remaining_from_kappa2)

    For example:
    - match_heap_locations (x->v1) (x->v2) = ([v1=v2], emp, emp)
    - match_heap_locations (x->v1 * y->v2) (x->v3) = ([v1=v3], y->v2, emp)
*)
let match_heap_locations (kappa1 : kappa) (kappa2 : kappa) : (pi list * kappa * kappa) =
  let rec collect_points_to k acc =
    match k with
    | EmptyHeap -> acc
    | PointsTo (loc, t) -> (loc, t) :: acc
    | RecordPointsTo (loc, fields) -> (loc, Syntax.term (TRecordTerm fields) Any) :: acc
    | SepConj (k1, k2) -> collect_points_to k1 (collect_points_to k2 acc)
  in
  let pts1 = collect_points_to kappa1 [] in
  let pts2 = collect_points_to kappa2 [] in

  let eqs = ref [] in
  let remaining1 = ref pts1 in
  let remaining2 = ref [] in

  (* For each points-to in kappa2, try to find a match in kappa1 *)
  List.iter (fun (loc2, val2) ->
    match List.assoc_opt loc2 pts1 with
    | Some val1 ->
        (* Found a match - generate equality *)
        if val1 <> val2 then
          eqs := Syntax.eq val1 val2 :: !eqs;
        (* Remove from remaining1 *)
        remaining1 := List.filter (fun (l, _) -> l <> loc2) !remaining1
    | None ->
        (* No match - add to remaining2 *)
        remaining2 := (loc2, val2) :: !remaining2
  ) pts2;

  let kappa_of_pts pts =
    match pts with
    | [] -> EmptyHeap
    | [(loc, t)] -> PointsTo (loc, t)
    | _ -> List.fold_right (fun (loc, t) acc ->
        match acc with
        | EmptyHeap -> PointsTo (loc, t)
        | _ -> SepConj (PointsTo (loc, t), acc)
      ) pts EmptyHeap
  in

  (!eqs, kappa_of_pts !remaining1, kappa_of_pts !remaining2)

(** Substitute a variable in a term *)
let rec subst_term_in_term (from_var : string) (to_term : term) (t : term) : term =
  match t.term_desc with
  | Var v when v = from_var -> to_term
  | Var _ | Const _ -> t
  | BinOp (op, t1, t2) ->
      { t with term_desc = BinOp (op, subst_term_in_term from_var to_term t1, subst_term_in_term from_var to_term t2) }
  | TNot t1 -> { t with term_desc = TNot (subst_term_in_term from_var to_term t1) }
  | Rel (op, t1, t2) ->
      { t with term_desc = Rel (op, subst_term_in_term from_var to_term t1, subst_term_in_term from_var to_term t2) }
  | TApp (f, args) ->
      { t with term_desc = TApp (f, List.map (subst_term_in_term from_var to_term) args) }
  | TLambda (id, params, spec, body) ->
      if List.exists (fun (p, _) -> p = from_var) params then t
      else { t with term_desc = TLambda (id, params, spec, body) }
  | TGetField (t1, f) ->
      { t with term_desc = TGetField (subst_term_in_term from_var to_term t1, f) }
  | TRecordTerm fields ->
      { t with term_desc = TRecordTerm (List.map (fun (n, v) -> (n, subst_term_in_term from_var to_term v)) fields) }
  | Construct (name, args) ->
      { t with term_desc = Construct (name, List.map (subst_term_in_term from_var to_term) args) }
  | TTuple ts ->
      { t with term_desc = TTuple (List.map (subst_term_in_term from_var to_term) ts) }
  | Type _ -> t

(** Substitute a variable in a pi formula *)
let rec subst_term_in_pi (from_var : string) (to_term : term) (pi : pi) : pi =
  match pi with
  | True | False -> pi
  | Atomic (op, t1, t2) ->
      Atomic (op, subst_term_in_term from_var to_term t1, subst_term_in_term from_var to_term t2)
  | And (p1, p2) -> And (subst_term_in_pi from_var to_term p1, subst_term_in_pi from_var to_term p2)
  | Or (p1, p2) -> Or (subst_term_in_pi from_var to_term p1, subst_term_in_pi from_var to_term p2)
  | Not p -> Not (subst_term_in_pi from_var to_term p)
  | Imply (p1, p2) -> Imply (subst_term_in_pi from_var to_term p1, subst_term_in_pi from_var to_term p2)
  | Colon (v, t) -> Colon (v, subst_term_in_term from_var to_term t)
  | Predicate (name, args) -> Predicate (name, List.map (subst_term_in_term from_var to_term) args)
  | Subsumption (t1, t2) ->
      Subsumption (subst_term_in_term from_var to_term t1, subst_term_in_term from_var to_term t2)

(** Substitute a variable in a kappa *)
let rec subst_term_in_kappa (from_var : string) (to_term : term) (kappa : kappa) : kappa =
  match kappa with
  | EmptyHeap -> EmptyHeap
  | PointsTo (loc, t) -> PointsTo (loc, subst_term_in_term from_var to_term t)
  | RecordPointsTo (loc, fields) ->
      RecordPointsTo (loc, List.map (fun (n, t) -> (n, subst_term_in_term from_var to_term t)) fields)
  | SepConj (k1, k2) ->
      SepConj (subst_term_in_kappa from_var to_term k1, subst_term_in_kappa from_var to_term k2)

(** Substitute a variable in a staged_spec *)
let rec subst_term_in_staged (from_var : string) (to_term : term) (spec : staged_spec) : staged_spec =
  let subst_state (pi, kappa) =
    (subst_term_in_pi from_var to_term pi, subst_term_in_kappa from_var to_term kappa)
  in
  match spec with
  | NormalReturn (pi, kappa) ->
      let (pi', kappa') = subst_state (pi, kappa) in
      NormalReturn (pi', kappa')
  | Require (pi, kappa) ->
      let (pi', kappa') = subst_state (pi, kappa) in
      Require (pi', kappa')
  | Assume inner ->
      Assume (subst_term_in_staged from_var to_term inner)
  | Sequence (s1, s2) ->
      Sequence (subst_term_in_staged from_var to_term s1, subst_term_in_staged from_var to_term s2)
  | Bind (x, s1, s2) ->
      if fst x = from_var then Bind (x, s1, s2)  (* shadowed *)
      else Bind (x, subst_term_in_staged from_var to_term s1, subst_term_in_staged from_var to_term s2)
  | ForAll (x, s) ->
      if fst x = from_var then spec  (* shadowed *)
      else ForAll (x, subst_term_in_staged from_var to_term s)
  | Exists (x, s) ->
      if fst x = from_var then spec  (* shadowed *)
      else Exists (x, subst_term_in_staged from_var to_term s)
  | Disjunction (s1, s2) ->
      Disjunction (subst_term_in_staged from_var to_term s1, subst_term_in_staged from_var to_term s2)
  | Reset s ->
      Reset (subst_term_in_staged from_var to_term s)
  | Multi (s1, s2) ->
      Multi (subst_term_in_staged from_var to_term s1, subst_term_in_staged from_var to_term s2)
  | _ -> spec  (* Other complex cases not handled for now *)

(** Apply a list of equalities as substitutions.
    For eq v1 v2, we substitute v2 -> v1 (prefer earlier variables) *)
let apply_equalities_to_staged (eqs : pi list) (spec : staged_spec) : staged_spec =
  List.fold_left (fun acc eq ->
    match eq with
    | Atomic (EQ, {term_desc = Var v1; _}, t2) ->
        subst_term_in_staged v1 t2 acc
    | Atomic (EQ, t1, {term_desc = Var v2; _}) ->
        subst_term_in_staged v2 t1 acc
    | _ -> acc
  ) spec eqs

(** Try to find a Require nested inside quantifiers and merge it with a preceding NormalReturn.
    Returns Some (merged_rest, equalities_applied) if merging happened, None otherwise.
*)
let rec try_merge_with_nested_req (post_kappa : kappa) (spec : staged_spec)
    : (staged_spec * pi list) option =
  if post_kappa = EmptyHeap then None
  else match spec with
  | Sequence (Require (req_pi, req_kappa), rest) when req_kappa <> EmptyHeap ->
      let (eqs, _remaining_post, remaining_req) = match_heap_locations post_kappa req_kappa in
      if eqs <> [] then begin
        debug ~at:4 ~title:"try_merge_nested"
          "Matched: post_kappa=%s, req_kappa=%s, eqs=%s"
          (string_of_kappa post_kappa)
          (string_of_kappa req_kappa)
          (String.concat ", " (List.map string_of_pi eqs));
        let rest' = apply_equalities_to_staged eqs rest in
        let merged =
          if remaining_req = EmptyHeap then rest'
          else Sequence (Require (req_pi, remaining_req), rest')
        in
        Some (merged, eqs)
      end else None
  | ForAll (v, inner) ->
      (match try_merge_with_nested_req post_kappa inner with
       | Some (merged_inner, eqs) -> Some (ForAll (v, merged_inner), eqs)
       | None -> None)
  | Exists (v, inner) ->
      (match try_merge_with_nested_req post_kappa inner with
       | Some (merged_inner, eqs) -> Some (Exists (v, merged_inner), eqs)
       | None -> None)
  | _ -> None

(** Check if a variable name appears free in a term *)
let rec var_appears_in_term (var_name : string) (t : term) : bool =
  match t.term_desc with
  | Var v -> v = var_name
  | Const _ -> false
  | BinOp (_, t1, t2) -> var_appears_in_term var_name t1 || var_appears_in_term var_name t2
  | TNot t1 -> var_appears_in_term var_name t1
  | Rel (_, t1, t2) -> var_appears_in_term var_name t1 || var_appears_in_term var_name t2
  | TApp (_, args) -> List.exists (var_appears_in_term var_name) args
  | TLambda (_, params, _, _) -> not (List.exists (fun (p, _) -> p = var_name) params)
  | TGetField (t1, _) -> var_appears_in_term var_name t1
  | TRecordTerm fields -> List.exists (fun (_, v) -> var_appears_in_term var_name v) fields
  | Construct (_, args) -> List.exists (var_appears_in_term var_name) args
  | TTuple ts -> List.exists (var_appears_in_term var_name) ts
  | Type _ -> false

(** Check if a variable name appears free in a pi formula *)
let rec var_appears_in_pi (var_name : string) (pi : pi) : bool =
  match pi with
  | True | False -> false
  | Atomic (_, t1, t2) -> var_appears_in_term var_name t1 || var_appears_in_term var_name t2
  | And (p1, p2) | Or (p1, p2) | Imply (p1, p2) ->
      var_appears_in_pi var_name p1 || var_appears_in_pi var_name p2
  | Not p -> var_appears_in_pi var_name p
  | Colon (_, t) -> var_appears_in_term var_name t
  | Predicate (_, args) -> List.exists (var_appears_in_term var_name) args
  | Subsumption (t1, t2) -> var_appears_in_term var_name t1 || var_appears_in_term var_name t2

(** Check if a variable name appears free in a kappa formula *)
let rec var_appears_in_kappa (var_name : string) (kappa : kappa) : bool =
  match kappa with
  | EmptyHeap -> false
  | PointsTo (_, t) -> var_appears_in_term var_name t
  | RecordPointsTo (_, fields) -> List.exists (fun (_, t) -> var_appears_in_term var_name t) fields
  | SepConj (k1, k2) -> var_appears_in_kappa var_name k1 || var_appears_in_kappa var_name k2

(** Check if a variable name appears free in a staged_spec *)
let rec var_appears_in_staged (var_name : string) (spec : staged_spec) : bool =
  let var_appears_in_state (pi, kappa) =
    var_appears_in_pi var_name pi || var_appears_in_kappa var_name kappa
  in
  match spec with
  | NormalReturn (pi, kappa) | Require (pi, kappa) -> var_appears_in_state (pi, kappa)
  | Assume inner -> var_appears_in_staged var_name inner
  | Sequence (s1, s2) | Multi (s1, s2) | Disjunction (s1, s2) ->
      var_appears_in_staged var_name s1 || var_appears_in_staged var_name s2
  | Bind ((v, _), s1, s2) ->
      if v = var_name then var_appears_in_staged var_name s1
      else var_appears_in_staged var_name s1 || var_appears_in_staged var_name s2
  | ForAll ((v, _), s) | Exists ((v, _), s) ->
      if v = var_name then false  (* bound, not free *)
      else var_appears_in_staged var_name s
  | Reset s -> var_appears_in_staged var_name s
  | Shift _ | TryCatch _ | RaisingEff _ | HigherOrder _ -> false  (* simplified handling *)

(** Remove vacuous quantifiers (forall/exists where variable doesn't appear in body) *)
let rec remove_vacuous_quantifiers (spec : staged_spec) : staged_spec =
  match spec with
  | ForAll ((v, _), inner) ->
      let inner' = remove_vacuous_quantifiers inner in
      if var_appears_in_staged v inner' then ForAll ((v, Int), inner')
      else inner'
  | Exists ((v, _), inner) ->
      let inner' = remove_vacuous_quantifiers inner in
      if var_appears_in_staged v inner' then Exists ((v, Int), inner')
      else inner'
  | Sequence (s1, s2) ->
      Sequence (remove_vacuous_quantifiers s1, remove_vacuous_quantifiers s2)
  | Bind (x, s1, s2) ->
      Bind (x, remove_vacuous_quantifiers s1, remove_vacuous_quantifiers s2)
  | Disjunction (s1, s2) ->
      Disjunction (remove_vacuous_quantifiers s1, remove_vacuous_quantifiers s2)
  | _ -> spec

(** Extract the trailing NormalReturn's kappa from a spec, looking through wrappers *)
let rec extract_trailing_kappa (spec : staged_spec) : kappa option =
  match spec with
  | NormalReturn (_, kappa) -> Some kappa
  | Sequence (_, NormalReturn (_, kappa)) -> Some kappa
  | Exists (_, inner) -> extract_trailing_kappa inner
  | ForAll (_, inner) -> extract_trailing_kappa inner
  | Sequence (_, inner) -> extract_trailing_kappa inner
  | _ -> None

(** Update the trailing NormalReturn's kappa with a new value *)
let rec update_trailing_kappa (spec : staged_spec) (new_kappa : kappa) : staged_spec =
  match spec with
  | NormalReturn (pi, _) -> NormalReturn (pi, new_kappa)
  | Sequence (s1, NormalReturn (pi, _)) -> Sequence (s1, NormalReturn (pi, new_kappa))
  | Exists (v, inner) -> Exists (v, update_trailing_kappa inner new_kappa)
  | ForAll (v, inner) -> ForAll (v, update_trailing_kappa inner new_kappa)
  | Sequence (s1, inner) -> Sequence (s1, update_trailing_kappa inner new_kappa)
  | _ -> spec

(** Merge two kappas where kappa2 is the "later" state.
    For overlapping locations, kappa2 wins (mutation semantics).
    For non-overlapping locations, combine with SepConj.
    Returns the merged kappa. *)
let merge_kappas_with_overwrite (kappa1 : kappa) (kappa2 : kappa) : kappa =
  let rec collect_points_to k acc =
    match k with
    | EmptyHeap -> acc
    | PointsTo (loc, t) -> (loc, t) :: acc
    | RecordPointsTo (loc, fields) -> (loc, Syntax.term (TRecordTerm fields) Any) :: acc
    | SepConj (k1, k2) -> collect_points_to k1 (collect_points_to k2 acc)
  in
  let pts1 = collect_points_to kappa1 [] in
  let pts2 = collect_points_to kappa2 [] in
  (* Get locations in kappa2 *)
  let locs2 = List.map fst pts2 in
  (* Keep from kappa1 only locations NOT in kappa2 *)
  let remaining1 = List.filter (fun (loc, _) -> not (List.mem loc locs2)) pts1 in
  (* Combine: remaining from kappa1 + all of kappa2 *)
  let all_pts = remaining1 @ pts2 in
  match all_pts with
  | [] -> EmptyHeap
  | [(loc, t)] -> PointsTo (loc, t)
  | _ -> List.fold_right (fun (loc, t) acc ->
      match acc with
      | EmptyHeap -> PointsTo (loc, t)
      | _ -> SepConj (PointsTo (loc, t), acc)
    ) all_pts EmptyHeap

(** Combine two postconditions where post2 is the "later" state.
    Pure parts are conjoined (both constraints hold).
    Heaps are merged with later values winning for overlapping locations. *)
let combine_postconditions (pi1, kappa1) (pi2, kappa2) =
  let combined_pi = match pi1, pi2 with
    | True, p | p, True -> p
    | p1, p2 -> And (p1, p2)
  in
  let combined_kappa = merge_kappas_with_overwrite kappa1 kappa2 in
  (combined_pi, combined_kappa)

(** Collapse trailing ForAll/Exists wrapped NormalReturns in a Sequence.
    Pattern: Sequence(stuff, ForAll(v, NormalReturn(pi, kappa))) where v is vacuous
    becomes: Sequence(stuff, NormalReturn(pi, kappa))
    Also combines multiple trailing NormalReturns into one. *)
let rec collapse_trailing_postconditions (spec : staged_spec) : staged_spec =
  match spec with
  (* Sequence ending with ForAll-wrapped NormalReturn *)
  | Sequence (s1, ForAll (_, NormalReturn (pi, kappa))) ->
      let s1' = collapse_trailing_postconditions s1 in
      (* Try to combine with preceding NormalReturn *)
      (match s1' with
       | Sequence (s0, NormalReturn (pi1, kappa1)) ->
           let (combined_pi, combined_kappa) = combine_postconditions (pi1, kappa1) (pi, kappa) in
           Sequence (s0, NormalReturn (combined_pi, combined_kappa))
       | _ -> Sequence (s1', NormalReturn (pi, kappa)))

  (* Sequence ending with Exists-wrapped NormalReturn *)
  | Sequence (s1, Exists ((v, t), NormalReturn (pi, kappa))) ->
      let s1' = collapse_trailing_postconditions s1 in
      if var_appears_in_pi v pi || var_appears_in_kappa v kappa then
        Sequence (s1', Exists ((v, t), NormalReturn (pi, kappa)))
      else
        (* v is vacuous, drop the exists *)
        (match s1' with
         | Sequence (s0, NormalReturn (pi1, kappa1)) ->
             let (combined_pi, combined_kappa) = combine_postconditions (pi1, kappa1) (pi, kappa) in
             Sequence (s0, NormalReturn (combined_pi, combined_kappa))
         | _ -> Sequence (s1', NormalReturn (pi, kappa)))

  (* Sequence of two NormalReturns - combine them *)
  | Sequence (NormalReturn (pi1, kappa1), NormalReturn (pi2, kappa2)) ->
      let (combined_pi, combined_kappa) = combine_postconditions (pi1, kappa1) (pi2, kappa2) in
      NormalReturn (combined_pi, combined_kappa)

  (* Sequence where first part ends with NormalReturn, second is NormalReturn *)
  | Sequence (Sequence (s0, NormalReturn (pi1, kappa1)), NormalReturn (pi2, kappa2)) ->
      let s0' = collapse_trailing_postconditions s0 in
      let (combined_pi, combined_kappa) = combine_postconditions (pi1, kappa1) (pi2, kappa2) in
      Sequence (s0', NormalReturn (combined_pi, combined_kappa))

  (* Sequence where first part is Exists - look for trailing NormalReturn inside *)
  | Sequence (Exists ((v, t), inner), NormalReturn (pi2, kappa2)) ->
      let inner' = collapse_trailing_postconditions inner in
      (match extract_trailing_kappa inner' with
       | Some kappa1 when kappa1 <> EmptyHeap ->
           let combined_kappa = merge_kappas_with_overwrite kappa1 kappa2 in
           Exists ((v, t), update_trailing_kappa inner' combined_kappa)
       | _ ->
           Sequence (Exists ((v, t), inner'), NormalReturn (pi2, kappa2)))

  (* Recurse into structure *)
  | Sequence (s1, s2) ->
      Sequence (collapse_trailing_postconditions s1, collapse_trailing_postconditions s2)
  | ForAll (x, inner) -> ForAll (x, collapse_trailing_postconditions inner)
  | Exists (x, inner) -> Exists (x, collapse_trailing_postconditions inner)
  | Bind (x, s1, s2) ->
      Bind (x, collapse_trailing_postconditions s1, collapse_trailing_postconditions s2)
  | _ -> spec

(** Merge sequential heap requirements.

    When we see:
      Sequence(...ending with NormalReturn(post_pi, post_kappa), <wrapper>(Require(req_pi, req_kappa), rest))

    where <wrapper> can be any combination of ForAll/Exists quantifiers.

    If post_kappa and req_kappa share locations, we can:
    1. Generate equalities for the values (e.g., x->v1 and x->v2 gives v2=v1)
    2. Remove the redundant Require
    3. Apply the equalities to the rest

    This handles patterns like:
      let tmp = !x in x := tmp + 1
    Where the read produces x->v1 and the write requires x->v2 (should be same).
*)
let rec merge_sequential_requirements (spec : staged_spec) : staged_spec =
  match spec with
  (* Pattern: Sequence(Sequence(Require, NormalReturn), rest_with_require) *)
  | Sequence (Sequence (Require (pre_pi, pre_kappa), NormalReturn (post_pi, post_kappa)), rest) ->
      (match try_merge_with_nested_req post_kappa rest with
       | Some (merged_rest, _eqs) ->
           debug ~at:4 ~title:"merge_seq_req pattern1"
             "Merged: post_kappa=%s"
             (string_of_kappa post_kappa);
           let merged_rest' = merge_sequential_requirements merged_rest in
           Sequence (Sequence (Require (pre_pi, pre_kappa), NormalReturn (post_pi, post_kappa)), merged_rest')
       | None ->
           Sequence (
             Sequence (Require (pre_pi, pre_kappa), NormalReturn (post_pi, post_kappa)),
             merge_sequential_requirements rest))

  (* Pattern: Sequence(Exists(v, ...), rest) - look for trailing NormalReturn kappa *)
  | Sequence (Exists (v, inner), rest) ->
      (match extract_trailing_kappa inner with
       | Some post_kappa when post_kappa <> EmptyHeap ->
           (match try_merge_with_nested_req post_kappa rest with
            | Some (merged_rest, _eqs) ->
                let merged_rest' = merge_sequential_requirements merged_rest in
                Sequence (Exists (v, merge_sequential_requirements inner), merged_rest')
            | None ->
                Sequence (Exists (v, merge_sequential_requirements inner), merge_sequential_requirements rest))
       | _ ->
           Sequence (Exists (v, merge_sequential_requirements inner), merge_sequential_requirements rest))

  (* Pattern: NormalReturn followed by something with nested Require *)
  | Sequence (NormalReturn (post_pi, post_kappa), rest) ->
      (match try_merge_with_nested_req post_kappa rest with
       | Some (merged_rest, _eqs) ->
           debug ~at:4 ~title:"merge_seq_req pattern2"
             "Merged: post_kappa=%s"
             (string_of_kappa post_kappa);
           let merged_rest' = merge_sequential_requirements merged_rest in
           Sequence (NormalReturn (post_pi, post_kappa), merged_rest')
       | None ->
           Sequence (NormalReturn (post_pi, post_kappa), merge_sequential_requirements rest))

  (* Propagate through structure *)
  | Sequence (s1, s2) ->
      let s1' = merge_sequential_requirements s1 in
      let s2' = merge_sequential_requirements s2 in
      (* After processing children, check if we can now merge *)
      (match s1' with
       | Sequence (_, NormalReturn (_, post_kappa))
       | NormalReturn (_, post_kappa) ->
           (match try_merge_with_nested_req post_kappa s2' with
            | Some (merged_s2, _) ->
                merge_sequential_requirements (Sequence (s1', merged_s2))
            | None -> Sequence (s1', s2'))
       | _ -> Sequence (s1', s2'))
  | Bind (x, s1, s2) ->
      Bind (x, merge_sequential_requirements s1, merge_sequential_requirements s2)
  | ForAll (x, s) -> ForAll (x, merge_sequential_requirements s)
  | Exists (x, s) -> Exists (x, merge_sequential_requirements s)
  | Disjunction (s1, s2) ->
      Disjunction (merge_sequential_requirements s1, merge_sequential_requirements s2)
  | _ -> spec

(** Normalize a staged_spec by flattening Bind and Sequence for simple specs.

    For simple separation logic (no effects), we can flatten:
    - Bind(x, NormalReturn(p1,h1), spec2) -> exists x. (p1 /\ spec2.post, h1 * spec2.heap)
    - Sequence(NormalReturn(p1,h1), NormalReturn(p2,h2)) -> NormalReturn(p1/\p2, h1*h2)

    This normalization makes it possible to extract simple_spec from forward-verified code.
*)
let rec normalize_staged_spec (spec : staged_spec) : staged_spec =
  match spec with
  (* Handle Bind with ForAll first: lift ForAll outside *)
  | Bind (x, ForAll (y, inner1), inner2) ->
      ForAll (y, normalize_staged_spec (Bind (x, inner1, inner2)))

  (* Handle Bind with Sequence(Require, NormalReturn) - common pattern from forward verifier *)
  | Bind (x, Sequence (Require (pre_pi, pre_kappa), NormalReturn (post_pi, post_kappa)), inner) ->
      let inner_norm = normalize_staged_spec inner in
      Exists (x, Sequence (
        Require (pre_pi, pre_kappa),
        Sequence (NormalReturn (post_pi, post_kappa), inner_norm)))

  (* Flatten Bind: let x = ens P in ens Q => exists x. ens P /\ Q *)
  | Bind (x, NormalReturn (pi1, kappa1), inner) ->
      let inner_norm = normalize_staged_spec inner in
      (match inner_norm with
       | NormalReturn (pi2, kappa2) ->
           (* Combine into single postcondition, existentially quantify x *)
           let (combined_pi, combined_kappa) = combine_states (pi1, kappa1) (pi2, kappa2) in
           Exists (x, NormalReturn (combined_pi, combined_kappa))
       | _ ->
           (* Recursively wrapped in exists *)
           Exists (x, Sequence (NormalReturn (pi1, kappa1), inner_norm)))

  (* Flatten Bind with non-NormalReturn first arg: normalize children, check if first becomes NormalReturn *)
  | Bind (x, inner1, inner2) ->
      let inner1_norm = normalize_staged_spec inner1 in
      let inner2_norm = normalize_staged_spec inner2 in
      (match inner1_norm with
       | ForAll (y, inner1') ->
           (* After normalization, got ForAll - lift it outside *)
           ForAll (y, normalize_staged_spec (Bind (x, inner1', inner2_norm)))
       | NormalReturn (pi1, kappa1) ->
           (* After normalization, first arg is NormalReturn - can flatten *)
           (match inner2_norm with
            | NormalReturn (pi2, kappa2) ->
                let (combined_pi, combined_kappa) = combine_states (pi1, kappa1) (pi2, kappa2) in
                Exists (x, NormalReturn (combined_pi, combined_kappa))
            | _ ->
                Exists (x, Sequence (NormalReturn (pi1, kappa1), inner2_norm)))
       | Sequence (Require (pre_pi, pre_kappa), NormalReturn (post_pi, post_kappa)) ->
           (* First arg is req;ens - common pattern, combine with inner2 *)
           Exists (x, Sequence (
             Require (pre_pi, pre_kappa),
             Sequence (NormalReturn (post_pi, post_kappa), inner2_norm)))
       | _ ->
           (* Cannot flatten further - return normalized bind wrapped in exists *)
           Exists (x, Sequence (inner1_norm, inner2_norm)))

  (* Lift ForAll out of Sequence on left *)
  | Sequence (ForAll (y, inner1), inner2) ->
      ForAll (y, normalize_staged_spec (Sequence (inner1, inner2)))

  (* Flatten nested Sequence of NormalReturns *)
  | Sequence (NormalReturn (pi1, kappa1), NormalReturn (pi2, kappa2)) ->
      let (combined_pi, combined_kappa) = combine_states (pi1, kappa1) (pi2, kappa2) in
      NormalReturn (combined_pi, combined_kappa)

  (* Flatten Sequence with nested structures *)
  | Sequence (spec1, spec2) ->
      let spec1_norm = normalize_staged_spec spec1 in
      let spec2_norm = normalize_staged_spec spec2 in
      (match spec1_norm, spec2_norm with
       | ForAll (y, inner1), _ ->
           (* Lift ForAll outside *)
           ForAll (y, normalize_staged_spec (Sequence (inner1, spec2_norm)))
       | NormalReturn (pi1, kappa1), NormalReturn (pi2, kappa2) ->
           let (combined_pi, combined_kappa) = combine_states (pi1, kappa1) (pi2, kappa2) in
           NormalReturn (combined_pi, combined_kappa)
       | _ -> Sequence (spec1_norm, spec2_norm))

  (* Propagate through quantifiers *)
  | Exists (x, inner) -> Exists (x, normalize_staged_spec inner)
  | ForAll (x, inner) -> ForAll (x, normalize_staged_spec inner)

  (* Propagate through disjunction *)
  | Disjunction (spec1, spec2) ->
      Disjunction (normalize_staged_spec spec1, normalize_staged_spec spec2)

  (* Base cases - return as is *)
  | NormalReturn _ | Require _ | Assume _ -> spec

  (* Complex specs - return as is (cannot simplify) *)
  | Shift _ | Reset _ | TryCatch _ | RaisingEff _ | HigherOrder _ | Multi _ -> spec

(** Extract simple_spec from staged_spec if it fits the pattern.
    Returns None if the staged_spec uses complex features.
    First normalizes the spec to flatten Bind and Sequence,
    then merges sequential requirements on the same heap locations. *)
let simple_of_staged (spec : staged_spec) : simple_spec option =
  let spec_norm = normalize_staged_spec spec in
  debug ~at:4 ~title:"simple_of_staged normalized"
    "%s" (string_of_staged_spec spec_norm);
  (* Apply sequential requirement merging to handle read-then-write patterns *)
  let spec_merged = merge_sequential_requirements spec_norm in
  debug ~at:4 ~title:"simple_of_staged merged"
    "%s" (string_of_staged_spec spec_merged);
  (* Remove vacuous quantifiers (e.g., forall v6 where v6 was removed by merging) *)
  let spec_cleaned = remove_vacuous_quantifiers spec_merged in
  debug ~at:4 ~title:"simple_of_staged vacuous removed"
    "%s" (string_of_staged_spec spec_cleaned);
  (* Collapse trailing postconditions *)
  let spec_collapsed = collapse_trailing_postconditions spec_cleaned in
  debug ~at:4 ~title:"simple_of_staged collapsed"
    "%s" (string_of_staged_spec spec_collapsed);
  let spec_norm = spec_collapsed in
  let rec extract (s : staged_spec) : simple_spec option =
    match s with
    (* Pattern: req P; ens Q *)
    | Sequence (Require (pre_pi, pre_kappa), NormalReturn (post_pi, post_kappa)) ->
        Some {
          ss_precond = Some (pre_pi, pre_kappa);
          ss_postcond = (post_pi, post_kappa);
          ss_ex = [];
          ss_fa = []
        }
    (* Pattern: req P; (ens Q1; ens Q2) - require followed by sequence of ensures *)
    | Sequence (Require (pre_pi, pre_kappa), inner) ->
        (match extract inner with
         | Some ss when ss.ss_precond = None ->
             Some { ss with ss_precond = Some (pre_pi, pre_kappa) }
         | _ -> None)
    (* Pattern: ens Q (no precondition) *)
    | NormalReturn (post_pi, post_kappa) ->
        Some {
          ss_precond = None;
          ss_postcond = (post_pi, post_kappa);
          ss_ex = [];
          ss_fa = []
        }
    (* Pattern: ens Q1; ens Q2 - sequence of ensures, combine into one postcondition *)
    | Sequence (NormalReturn (pi1, kappa1), NormalReturn (pi2, kappa2)) ->
        Some {
          ss_precond = None;
          ss_postcond = combine_states (pi1, kappa1) (pi2, kappa2);
          ss_ex = [];
          ss_fa = []
        }
    (* Pattern: ens Q1; (ens Q2; ...) - nested sequence of ensures *)
    | Sequence (NormalReturn (pi1, kappa1), inner) ->
        (match extract inner with
         | Some ss when ss.ss_precond = None ->
             Some { ss with ss_postcond = combine_states (pi1, kappa1) ss.ss_postcond }
         | _ -> None)
    (* Pattern: exists x. ... *)
    | Exists (x, inner) ->
        extract inner
        |> Option.map (fun ss -> { ss with ss_ex = x :: ss.ss_ex })
    (* Pattern: forall x. ... *)
    | ForAll (x, inner) ->
        extract inner
        |> Option.map (fun ss -> { ss with ss_fa = x :: ss.ss_fa })
    (* Complex specs cannot be simplified *)
    | Shift _ | Reset _ | TryCatch _ | RaisingEff _ | HigherOrder _
    | Multi _ | Assume _ | Disjunction _ | Bind _ | Require _
    | Sequence _ ->
        None
  in
  extract spec_norm

(** Check simple spec entailment.

    For Hoare logic correctness with the FRAME RULE, we check:
    1. Precondition: declared.pre ⊢ inferred.pre (contravariant)
       - The declared precondition should entail the inferred one
       - This produces a FRAME: the part of declared.pre not used by inferred.pre
    2. Postcondition: (inferred.post * frame) ⊢ declared.post (covariant)
       - The inferred postcondition PLUS the preserved frame should entail declared.post
       - This implements the separation logic frame rule:
         {P} c {Q} implies {P * r} c {Q * r} when r is not modified

    @param inferred The specification inferred from the code
    @param declared The user-declared specification
    @return Valid if entailment holds, Invalid with reason otherwise
*)
let check_simple_spec_entailment
    (inferred : simple_spec)
    (declared : simple_spec)
    : simple_entail_result =

  debug ~at:3 ~title:"simple_entail"
    "inferred: %s\ndeclared: %s"
    (string_of_staged_spec (staged_of_simple inferred))
    (string_of_staged_spec (staged_of_simple declared));

  (* Build context with universally quantified vars from declared spec *)
  let ctx = State_entail.{
    assumptions = [];
    existentials = declared.ss_ex;
  } in

  (* Default precondition: True /\ emp *)
  let default_pre = (True, EmptyHeap) in

  (* 1. Check precondition: declared.pre ⊢ inferred.pre (contravariant)
        This gives us the FRAME: the heap resources in declared.pre that
        are not required by the code (inferred.pre) *)
  let declared_pre = Option.value declared.ss_precond ~default:default_pre in
  let inferred_pre = Option.value inferred.ss_precond ~default:default_pre in

  let pre_result = State_entail.entail_state ~ctx declared_pre inferred_pre in

  match pre_result with
  | State_entail.Failure reason ->
      Invalid (Format.sprintf "Precondition check failed: %s" reason)
  | State_entail.Success { frame = (frame_pi, frame_kappa); constraints = pre_constraints; _ } ->

      debug ~at:3 ~title:"simple_entail frame"
        "frame from precondition: (%s, %s)"
        (string_of_pi frame_pi) (string_of_kappa frame_kappa);

      (* 2. Check postcondition: (inferred.post * frame) ⊢ declared.post (covariant)
         The FRAME RULE: preserved heap resources are added to inferred.post
         Include inferred's existentials - they can be instantiated during entailment *)
      let post_ctx = State_entail.{
        assumptions = pre_constraints @ ctx.assumptions;
        existentials = inferred.ss_ex @ declared.ss_ex;
      } in

      (* Apply frame rule: add preserved frame to inferred postcondition *)
      let inferred_post_with_frame =
        combine_states inferred.ss_postcond (frame_pi, frame_kappa)
      in

      debug ~at:3 ~title:"simple_entail post check"
        "inferred.post + frame: %s\ndeclared.post: %s"
        (string_of_state inferred_post_with_frame)
        (string_of_state declared.ss_postcond);

      let post_result =
        State_entail.entail_state ~ctx:post_ctx inferred_post_with_frame declared.ss_postcond
      in

      match post_result with
      | State_entail.Failure reason ->
          Invalid (Format.sprintf "Postcondition check failed: %s" reason)
      | State_entail.Success { anti_frame = (anti_pi, anti_kappa); frame = (post_frame_pi, post_frame_kappa); _ } ->
          (* Check that anti-frame is empty (no missing resources) *)
          let anti_empty =
            anti_kappa = EmptyHeap &&
            (anti_pi = True || Simpl.simplify_pure anti_pi = True)
          in
          (* Check that frame is empty (no extra resources in inferred.post + frame)
             This ensures that preserved resources from precondition appear in declared.post *)
          let post_frame_empty =
            post_frame_kappa = EmptyHeap &&
            (post_frame_pi = True || Simpl.simplify_pure post_frame_pi = True)
          in
          if not anti_empty then
            Invalid (Format.sprintf "Missing resources in postcondition: %s"
              (string_of_state (anti_pi, anti_kappa)))
          else if not post_frame_empty then
            Invalid (Format.sprintf "Frame not preserved in declared postcondition: %s"
              (string_of_state (post_frame_pi, post_frame_kappa)))
          else
            Valid

(** Check if simple spec entailment holds (boolean version) *)
let check_simple_entailment inferred declared =
  match check_simple_spec_entailment inferred declared with
  | Valid -> true
  | Invalid _ -> false

(* ============================================================ *)
(* Unit Tests *)
(* ============================================================ *)

let%expect_test "simple_spec_to_staged" =
  let open Syntax in
  let ss = {
    ss_precond = Some (eq (var "x") (num 1), PointsTo ("p", var "v"));
    ss_postcond = (eq (var "res") (var "v"), PointsTo ("p", var "v"));
    ss_ex = [];
    ss_fa = [("v", Any)];
  } in
  Format.printf "%s@." (string_of_staged_spec (staged_of_simple ss));
  [%expect {| forall v. (req p->v/\x=1; ens p->v/\res=v) |}]

let%expect_test "empty_spec_entailment" =
  let ss = {
    ss_precond = None;
    ss_postcond = (True, EmptyHeap);
    ss_ex = [];
    ss_fa = [];
  } in
  let r = check_simple_spec_entailment ss ss in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Valid |}]

let%expect_test "basic_postcondition_entailment" =
  let open Syntax in
  (* inferred: ens res=1 should satisfy declared: ens res=1 *)
  let inferred = {
    ss_precond = None;
    ss_postcond = (eq (var "res") (num 1), EmptyHeap);
    ss_ex = [];
    ss_fa = [];
  } in
  let declared = {
    ss_precond = None;
    ss_postcond = (eq (var "res") (num 1), EmptyHeap);
    ss_ex = [];
    ss_fa = [];
  } in
  let r = check_simple_spec_entailment inferred declared in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Valid |}]

let%expect_test "heap_postcondition_entailment" =
  let open Syntax in
  (* inferred: ens x->1 should satisfy declared: ens x->1 *)
  let inferred = {
    ss_precond = None;
    ss_postcond = (True, PointsTo ("x", num 1));
    ss_ex = [];
    ss_fa = [];
  } in
  let declared = {
    ss_precond = None;
    ss_postcond = (True, PointsTo ("x", num 1));
    ss_ex = [];
    ss_fa = [];
  } in
  let r = check_simple_spec_entailment inferred declared in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Valid |}]

let%expect_test "postcondition_failure" =
  let open Syntax in
  (* inferred: ens res=1 should NOT satisfy declared: ens res=2 *)
  let inferred = {
    ss_precond = None;
    ss_postcond = (eq (var "res") (num 1), EmptyHeap);
    ss_ex = [];
    ss_fa = [];
  } in
  let declared = {
    ss_precond = None;
    ss_postcond = (eq (var "res") (num 2), EmptyHeap);
    ss_ex = [];
    ss_fa = [];
  } in
  let r = check_simple_spec_entailment inferred declared in
  Format.printf "%s@." (string_of_result r);
  [%expect {| Invalid(Postcondition check failed: Pure entailment failed) |}]
