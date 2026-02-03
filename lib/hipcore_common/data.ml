(** Definitions which are not part of the core recursive AST loop, and can
 therefore be defined in a separate module. *)

open Utils.Hstdlib

module Make(M : Ast.AST) = struct
  type meth_def = {
    m_name: string;
    m_params: M.binder list;
    m_spec: M.staged_spec option;
    m_body: M.core_lang;
    m_tactics: Tactics.tactic list;
  }

  type pred_def = {
    p_name: string;
    p_params: M.binder list;
    p_body: M.staged_spec;
    p_rec: bool
  }

  type sl_pred_def = {
    p_sl_ex: M.binder list;
    p_sl_name: string;
    p_sl_params: M.binder list;
    p_sl_body: M.state;
  }

  (** Simple separation logic specification using only pre/post conditions.
      This is a simpler alternative to staged_spec for pure heap operations
      without control effects or exceptions. *)
  type simple_spec = {
    ss_precond: M.state option;     (** requires clause: precondition *)
    ss_postcond: M.state;           (** ensures clause: postcondition *)
    ss_ex: M.binder list;           (** existentially quantified variables *)
    ss_fa: M.binder list;           (** universally quantified variables *)
  }

  (** A single branch in a case-based specification.
      Each case has a precondition and postcondition. *)
  type case_branch = {
    cb_pre: M.state;      (** precondition for this case *)
    cb_post: M.state;     (** postcondition when this case applies *)
  }

  (** Case-based separation logic specification.
      Represents: case [params] { pre₁ => post₁; pre₂ => post₂; ... }

      Example - swap function:
        case [x, y] {
          x : Ref(A) /\ y : Ref(A)  => ens r : ();
          x -> Ref(a) * y -> Ref(b) => ens x -> Ref(b) * y -> Ref(a) /\ r : ();
          x -> Ref(a) /\ y = x      => ens x -> Ref(a) /\ r : ()
        }
  *)
  type case_spec = {
    cs_type_vars: string list;      (** type variables (A, B) - uppercase names *)
    cs_forall: M.binder list;       (** value variables (a, b) - lowercase names *)
    cs_params: string list;         (** function parameter names *)
    cs_branches: case_branch list;  (** list of case branches *)
  }

  (** Method definition with simple spec instead of full staged_spec *)
  type simple_meth_def = {
    sm_name: string;
    sm_params: M.binder list;
    sm_spec: simple_spec option;
    sm_body: M.core_lang;
  }

  type pure_fn_def = {
    pf_name: string;
    pf_params: M.binder list;
    pf_ret_type: Types.typ;
    pf_body: M.core_lang;
  }

  type lemma = {
    l_name: string;
    l_params: M.binder list;
    l_left: M.staged_spec;
    l_right: M.staged_spec;
  }

  type lambda_obligation = {
    lo_name: string;
    lo_preds: pred_def SMap.t;
    lo_left: M.staged_spec;
    lo_right: M.staged_spec;
  }

  type intermediate =
    | Eff of string
    | Lem of lemma
    (* type definition of pure logic function *)
    | LogicTypeDecl of string * Types.typ list * Types.typ * string list * string
    (* name, params, spec, body, tactics, pure_fn_info *)
    | Meth of string * M.binder list * M.staged_spec option * M.core_lang * Tactics.tactic list * (Types.typ list * Types.typ) option
    (* method with simple separation logic spec *)
    | SimpleMeth of string * M.binder list * simple_spec option * M.core_lang
    (* user-provided type definition *)
    | Typedef of Types.type_declaration
    | Pred of pred_def
    | SLPred of sl_pred_def

  type core_program = {
    cp_effs: string list;
    cp_predicates: pred_def SMap.t;
    cp_sl_predicates: sl_pred_def SMap.t;
    cp_lemmas: lemma SMap.t;
    cp_methods: meth_def list;
    cp_simple_methods: simple_meth_def list;  (** Methods with simple SL specs *)
  }

  let empty_program = {
    cp_effs = [];
    cp_methods = [];
    cp_simple_methods = [];
    cp_predicates = SMap.empty;
    cp_sl_predicates = SMap.empty;
    cp_lemmas = SMap.empty
  }
end
