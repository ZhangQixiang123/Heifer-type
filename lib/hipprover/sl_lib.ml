(** Separation Logic Library - Public Interface

    This module provides the main entry points for the separation logic
    verification system.

    Usage:
    1. Parse specs using the existing parser (produces staged_spec)
    2. Translate to sl_spec using sl_spec_of_staged
    3. Run forward verification on code using sl_forward
    4. Check entailment using verify_spec or check_sl_entailment

    Example:
    {[
      let check_method methods predicates meth =
        let env = Sl_forward.create_env methods predicates in
        let declared = Sl_types.sl_spec_of_staged declared_staged in
        match Sl_forward.sl_forward env meth.body with
        | Sl_forward.SL_Spec inferred ->
            Sl_entail.verify_spec inferred declared
        | Sl_forward.SL_Unsupported _ ->
            false
    ]}
*)

open Hipcore_typed
open Typed_core_ast
open Typedhip
open Utils.Hstdlib

(* Re-export the main types *)
module Types = Sl_types
module Forward = Sl_forward
module Entail = Sl_entail

(** Method definition for SL verification *)
type sl_method = {
  slm_name: string;
  slm_params: binder list;
  slm_declared: Sl_types.sl_spec option;
  slm_body: core_lang;
}

(** Convert from standard meth_def to sl_method *)
let sl_method_of_meth_def (m: meth_def) : sl_method option =
  let declared = match m.m_spec with
    | None -> None
    | Some staged ->
        try Some (Sl_types.sl_spec_of_staged staged)
        with Sl_types.Unsupported_feature _ -> None
  in
  (* Only return if we could translate the spec (or there's no spec) *)
  match m.m_spec, declared with
  | None, None -> Some {
      slm_name = m.m_name;
      slm_params = m.m_params;
      slm_declared = None;
      slm_body = m.m_body;
    }
  | Some _, Some decl -> Some {
      slm_name = m.m_name;
      slm_params = m.m_params;
      slm_declared = Some decl;
      slm_body = m.m_body;
    }
  | Some _, None ->
      (* Spec uses unsupported features *)
      None
  | None, Some _ ->
      (* Impossible case *)
      None

(** Verification result *)
type verify_result =
  | Success
  | Failure of string
  | Unsupported of string

(** Pretty print verification result *)
let string_of_verify_result = function
  | Success -> "Success"
  | Failure msg -> "Failure: " ^ msg
  | Unsupported msg -> "Unsupported: " ^ msg

(** Verify a single method.

    @param methods Map of method definitions (for function calls)
    @param predicates Map of predicate definitions
    @param meth The method to verify
    @return Success if spec is satisfied, Failure/Unsupported otherwise *)
let verify_method
    (methods: meth_def SMap.t)
    (predicates: pred_def SMap.t)
    (meth: sl_method)
    : verify_result =
  match meth.slm_declared with
  | None ->
      (* No declared spec - just check code is valid *)
      let env = Sl_forward.create_env methods predicates in
      (match Sl_forward.sl_forward env meth.slm_body with
       | Sl_forward.SL_Spec _ -> Success
       | Sl_forward.SL_Unsupported msg -> Unsupported msg)
  | Some declared ->
      (* Have declared spec - verify it *)
      let env = Sl_forward.create_env methods predicates in
      match Sl_forward.sl_forward env meth.slm_body with
      | Sl_forward.SL_Unsupported msg ->
          Unsupported msg
      | Sl_forward.SL_Spec inferred ->
          (* Wrap declared as SL_Single for entailment check *)
          let declared_disj = Sl_types.SL_Single declared in
          Debug.debug ~at:2 ~title:"SL verify method"
            "Method %s\nInferred: %s\nDeclared: %s"
            meth.slm_name
            (Sl_types.string_of_sl_spec_disj inferred)
            (Sl_types.string_of_sl_spec_disj declared_disj);
          (* Use disjunction-aware entailment: ALL branches must satisfy declared *)
          match Sl_entail.check_sl_entailment_disj_safe inferred declared_disj with
          | Sl_entail.Valid -> Success
          | Sl_entail.Invalid msg -> Failure msg

(** Verify a method, returning a boolean.
    This is the simple interface for test harnesses. *)
let verify_method_bool
    (methods: meth_def SMap.t)
    (predicates: pred_def SMap.t)
    (meth: sl_method)
    : bool =
  match verify_method methods predicates meth with
  | Success -> true
  | Failure _ | Unsupported _ -> false

(** Try to verify a standard meth_def using SL.
    Returns None if the method uses unsupported features.
    Returns Some(name, result) if verification was attempted. *)
let try_verify_meth_def
    (methods: meth_def SMap.t)
    (predicates: pred_def SMap.t)
    (m: meth_def)
    : (string * bool) option =
  match sl_method_of_meth_def m with
  | None -> None
  | Some slm ->
      let result = verify_method_bool methods predicates slm in
      Some (slm.slm_name, result)

(** Check if a method can be verified with SL (i.e., uses only supported features) *)
let is_sl_compatible (m: meth_def) : bool =
  match m.m_spec with
  | None -> true  (* No spec means compatible by default *)
  | Some staged ->
      try
        ignore (Sl_types.sl_spec_of_staged staged);
        true
      with Sl_types.Unsupported_feature _ -> false

(* ========== CASE-BASED SPECIFICATION SUPPORT ========== *)

(** Method definition with case-based specification *)
type sl_case_method = {
  slcm_name: string;
  slcm_params: binder list;
  slcm_case_spec: Sl_types.sl_spec_case;
  slcm_body: core_lang;
}

(** Verify a method with case-based specification.

    For each case branch:
    - The implementation must be correct when the case precondition holds
    - We verify by checking if inferred spec satisfies the case postcondition

    @param methods Map of method definitions (for function calls)
    @param predicates Map of predicate definitions
    @param meth The method with case spec to verify
    @return Success if all cases are satisfied, Failure otherwise *)
let verify_case_method
    (methods: meth_def SMap.t)
    (predicates: pred_def SMap.t)
    (meth: sl_case_method)
    : verify_result =
  let env = Sl_forward.create_env methods predicates in

  (* Run forward verification to get inferred spec *)
  match Sl_forward.sl_forward env meth.slcm_body with
  | Sl_forward.SL_Unsupported msg ->
      Unsupported msg
  | Sl_forward.SL_Spec inferred ->
      Debug.debug ~at:2 ~title:"SL case verify method"
        "Method %s\nInferred: %s\nDeclared cases: %s"
        meth.slcm_name
        (Sl_types.string_of_sl_spec_disj inferred)
        (Sl_types.string_of_case_spec meth.slcm_case_spec);

      (* Check entailment against case-based spec *)
      match Sl_entail.check_case_entailment_disj inferred meth.slcm_case_spec with
      | Sl_entail.Valid -> Success
      | Sl_entail.Invalid msg -> Failure msg

(** Verify a method with case-based specification, returning a boolean. *)
let verify_case_method_bool
    (methods: meth_def SMap.t)
    (predicates: pred_def SMap.t)
    (meth: sl_case_method)
    : bool =
  match verify_case_method methods predicates meth with
  | Success -> true
  | Failure _ | Unsupported _ -> false

(** Convert a case_spec (from parser) to sl_spec_case.
    The parser produces Hiptypes.case_spec, we need Sl_types.sl_spec_case. *)
let sl_spec_case_of_hiptypes (cs: Hipcore.Hiptypes.case_spec) : Sl_types.sl_spec_case =
  let convert_branch (cb: Hipcore.Hiptypes.case_branch) : Sl_types.sl_case_branch =
    (* Need to retype the untyped state to typed state *)
    let retype_state (pi, kappa) =
      let pi' = Hipcore_typed.Retypehip.retype_pi pi in
      let kappa' = Hipcore_typed.Retypehip.retype_kappa kappa in
      (pi', kappa')
    in
    let pre_state = retype_state cb.Hipcore.Hiptypes.cb_pre in
    let post_state = retype_state cb.Hipcore.Hiptypes.cb_post in
    {
      Sl_types.case_pre = Sl_types.qstate_of_state pre_state;
      case_post = Sl_types.qstate_of_state post_state;
    }
  in
  (* cs_forall is string list (value vars), convert to binder list *)
  let forall_binders = List.map (fun name -> (name, Any)) cs.Hipcore.Hiptypes.cs_forall in
  {
    Sl_types.case_type_vars = cs.Hipcore.Hiptypes.cs_type_vars;  (* Type variables: A, B *)
    case_forall = forall_binders;                                 (* Value variables: a, b *)
    case_params = cs.Hipcore.Hiptypes.cs_params;
    case_branches = List.map convert_branch cs.Hipcore.Hiptypes.cs_branches;
  }

(** Verify a method with extended specification (supports simple, disjunctive, and case specs).

    @param methods Map of method definitions
    @param predicates Map of predicate definitions
    @param name Method name
    @param params Method parameters
    @param spec Extended specification
    @param body Method body
    @return Verification result *)
let verify_method_ext
    (methods: meth_def SMap.t)
    (predicates: pred_def SMap.t)
    ~(name: string)
    ~(_params: binder list)
    ~(spec: Sl_types.sl_spec_ext)
    ~(body: core_lang)
    : verify_result =
  let env = Sl_forward.create_env methods predicates in

  match Sl_forward.sl_forward env body with
  | Sl_forward.SL_Unsupported msg ->
      Unsupported msg
  | Sl_forward.SL_Spec inferred ->
      Debug.debug ~at:2 ~title:"SL verify method (ext)"
        "Method %s\nInferred: %s\nDeclared: %s"
        name
        (Sl_types.string_of_sl_spec_disj inferred)
        (Sl_types.string_of_sl_spec_ext spec);

      match Sl_entail.check_sl_spec_ext_entailment inferred spec with
      | Sl_entail.Valid -> Success
      | Sl_entail.Invalid msg -> Failure msg
