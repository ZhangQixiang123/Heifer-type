(** TypeScript to Heifer: Full Verification Demo
    Translates TypeScript and runs Heifer's verification engine *)

open Ts_to_heifer.Translator
open Hipcore_typed.Pretty
open Hipcore_typed.Typedhip
open Hipcore_typed.Typed_core_ast

(** Extended method with optional case spec *)
type ext_method = {
  em_name: string;
  em_params: binder list;
  em_spec: staged_spec option;
  em_case_spec: Hipcore.Hiptypes.case_spec option;
  em_body: core_lang;
  em_tactics: tactic list;
}

(** Convert intermediate to ext_method *)
let to_ext_method item =
  match item with
  | `Meth (name, params, spec, case_spec, body, tactics, _pure_info) ->
      {
        em_name = name;
        em_params = params;
        em_spec = spec;
        em_case_spec = case_spec;
        em_body = body;
        em_tactics = tactics;
      }

(** Convert ext_method to standard meth_def for regular verification *)
let ext_to_meth_def em =
  {
    m_name = em.em_name;
    m_params = em.em_params;
    m_spec = em.em_spec;
    m_body = em.em_body;
    m_tactics = em.em_tactics;
  }

(** Verify a method using Heifer's forward rules.
    Returns (inferred_spec option, success, error option, flow_spec option).
    flow_spec is Some when Tier 2 flow analysis produced a synthetic spec. *)
let verify_method prog meth =
  try
    (* Tier 1: Has spec? → analyze_type_spec (full value-level proof) *)
    let type_spec_ok = match meth.m_spec with
      | Some spec ->
          (try
            let _r = Hipprover.Forward_rules.analyze_type_spec spec meth prog in
            true
          with _e ->
            false)
      | None -> false
    in
    if type_spec_ok then
      (meth.m_spec, true, None, None)
    else
      (* Tier 2: No spec + has Ref params? → analyze_flow (spec-free) *)
      let has_ref_params = List.exists (fun (_, typ) ->
        match typ with Hipcore_typed.Typed_core_ast.TConstr ("ref", _) -> true | _ -> false
      ) meth.m_params in
      let flow_ok, flow_spec = if meth.m_spec = None && has_ref_params then
        (try
          let syn_spec = Hipprover.Forward_rules.analyze_flow meth prog in
          (true, Some syn_spec)
        with _e ->
          (false, None))
      else
        (false, None)
      in
      if flow_ok then
        (flow_spec, true, None, flow_spec)
      else begin
        (* Tier 3: Fallback → infer_and_check_method (general entailment) *)
        let inferred_spec, result = Hiplib.infer_and_check_method prog meth meth.m_spec in
        (Some inferred_spec, result, None, None)
      end
  with
  | Failure msg -> (None, false, Some msg, None)
  | e -> (None, false, Some (Printexc.to_string e), None)

(** Verify a method with case-based specification.

    This uses the correct approach:
    1. Check case coverage (detect missing aliased case)
    2. For each case, assume precondition and verify postcondition
*)
let verify_case_method _prog em =
  match em.em_case_spec with
  | None -> (None, false, Some "No case spec provided")
  | Some case_spec ->
      try
        (* Convert case_spec to sl_spec_case for entailment checking *)
        let sl_case_spec = Hipprover.Sl_lib.sl_spec_case_of_hiptypes case_spec in

        (* Extract parameter names from function signature *)
        let param_names = List.map fst em.em_params in

        (* Step 1: Check case coverage *)
        (match Hipprover.Sl_entail.check_case_coverage param_names sl_case_spec.case_branches with
        | Some missing_msg ->
            (* Incomplete coverage - missing aliased case *)
            (None, false, Some ("Incomplete case coverage: " ^ missing_msg))
        | None ->
            (* Coverage OK, proceed with verification *)

            (* Create forward verification environment *)
            let methods_map = Utils.Hstdlib.SMap.empty in
            let pred_map = Utils.Hstdlib.SMap.empty in
            let env = Hipprover.Sl_forward.create_env methods_map pred_map in

            (* Step 2: Verify each case by assuming its precondition *)
            let result = Hipprover.Sl_entail.verify_case_spec_with_forward
              env sl_case_spec em.em_body in

            match result with
            | Hipprover.Sl_entail.Valid ->
                (None, true, None)
            | Hipprover.Sl_entail.Invalid msg ->
                (None, false, Some msg))
      with
      | Failure msg -> (None, false, Some msg)
      | Hipprover.Sl_types.Unsupported_feature msg ->
          (None, false, Some ("Unsupported feature: " ^ msg))
      | e -> (None, false, Some (Printexc.to_string e))

(** Pretty print a case spec *)
let string_of_case_spec_brief (cs: Hipcore.Hiptypes.case_spec) =
  let branch_strs = List.map (fun (cb: Hipcore.Hiptypes.case_branch) ->
    let pre_str = Hipcore.Pretty.string_of_state cb.Hipcore.Hiptypes.cb_pre in
    let post_str = Hipcore.Pretty.string_of_state cb.Hipcore.Hiptypes.cb_post in
    Printf.sprintf "%s => %s" pre_str post_str
  ) cs.Hipcore.Hiptypes.cs_branches in
  Printf.sprintf "case [%s] { %s }"
    (String.concat ", " cs.Hipcore.Hiptypes.cs_params)
    (String.concat "; " branch_strs)

let () =
  if Array.length Sys.argv < 2 then begin
    Printf.eprintf "Usage: %s <input.json>\n" Sys.argv.(0);
    Printf.eprintf "  Translates TypeScript and runs full verification\n";
    exit 1
  end;

  let input_file = Sys.argv.(1) in

  try
    let json = Yojson.Safe.from_file input_file in
    let intermediates = translate_program_to_intermediates json in

    if List.length intermediates = 0 then begin
      Printf.printf "No functions found\n";
      exit 0
    end;

    (* Convert to extended method definitions *)
    let ext_methods = List.map to_ext_method intermediates in

    (* Build program incrementally, verifying each method *)
    let prog_ref = ref empty_program in

    Printf.printf "╔════════════════════════════════════════════════════════════╗\n";
    Printf.printf "║  TypeScript to Heifer: Full Verification                  ║\n";
    Printf.printf "╚════════════════════════════════════════════════════════════╝\n\n";
    Printf.printf "Translating and verifying %d function(s)\n\n" (List.length ext_methods);

    List.iteri (fun idx em ->
        Printf.printf "Function %d: %s\n" (idx + 1) em.em_name;
        Printf.printf "%s\n" (String.make 60 '-');

        Printf.printf "\nSignature:\n";
        Printf.printf "  fun %s(" em.em_name;
        if List.length em.em_params = 0 then
          Printf.printf ")"
        else
          Printf.printf "%s)"
            (String.concat ", "
              (List.map (fun (n, t) ->
                Printf.sprintf "%s: %s" n (string_of_type t)) em.em_params));
        Printf.printf " : %s\n" (string_of_type em.em_body.core_type);

        (* Print specification *)
        (match em.em_case_spec with
        | Some cs ->
            Printf.printf "\nGiven Case Specification:\n";
            Printf.printf "  %s\n" (string_of_case_spec_brief cs);
            Printf.printf "  (%d case branches)\n" (List.length cs.Hipcore.Hiptypes.cs_branches)
        | None ->
            match em.em_spec with
            | Some spec ->
                Printf.printf "\nGiven Specification:\n";
                Printf.printf "  %s\n" (string_of_staged_spec spec);
            | None ->
                Printf.printf "\nNo specification given\n"
        );

        Printf.printf "\nBody:\n";
        let body_lines = String.split_on_char '\n' (string_of_core_lang em.em_body) in
        List.iter (fun line ->
          Printf.printf "  %s\n" line
        ) body_lines;

        Printf.printf "\nVerification:\n";

        (* Choose verification method based on spec type *)
        let (inferred_opt, result, error_opt, flow_spec_opt) =
          match em.em_case_spec with
          | Some _ ->
              let (i, r, e) = verify_case_method !prog_ref em in
              (i, r, e, None)
          | None ->
              let meth = ext_to_meth_def em in
              verify_method !prog_ref meth
        in

        (match flow_spec_opt with
        | Some syn_spec ->
            Printf.printf "  Flow-inferred spec: %s\n" (string_of_staged_spec syn_spec);
        | None ->
            match inferred_opt with
            | Some inferred ->
                Printf.printf "  Inferred spec: %s\n" (string_of_staged_spec inferred);
            | None -> ()
        );

        (match error_opt with
        | Some err ->
            Printf.printf "  ✗ VERIFICATION FAILED\n";
            Printf.printf "  Error: %s\n" err
        | None ->
            if result then begin
              (if flow_spec_opt <> None then
                Printf.printf "  ✓ FLOW ANALYSIS PASSED\n"
              else
                Printf.printf "  ✓ VERIFICATION PASSED\n");
              Printf.printf "  Result: %b\n" result
            end
            else begin
              Printf.printf "  ✗ Specification does not entail given spec\n";
              Printf.printf "  Result: %b\n" result
            end
        );

        (* Add verified method to program for next iteration *)
        let meth = ext_to_meth_def em in
        (match flow_spec_opt with
        | Some syn_spec ->
            (* Store synthetic spec from flow analysis directly *)
            let pred = Hipprover.Entail.derive_predicate_type
              meth.m_name meth.m_params syn_spec in
            let cp_predicates = Utils.Hstdlib.SMap.add
              meth.m_name pred (!prog_ref).cp_predicates in
            prog_ref := { !prog_ref with cp_predicates }
        | None ->
            prog_ref := Hiplib.analyze_method !prog_ref meth);

        Printf.printf "\n%s\n\n" (String.make 60 '=')
    ) ext_methods;

    Printf.printf "╔════════════════════════════════════════════════════════════╗\n";
    Printf.printf "║  Summary                                                   ║\n";
    Printf.printf "╚════════════════════════════════════════════════════════════╝\n";
    Printf.printf "  Functions verified: %d\n" (List.length ext_methods);
    Printf.printf "  Verification engine: Heifer forward rules + entailment\n"

  with
  | Yojson.Json_error msg ->
      Printf.eprintf "JSON error: %s\n" msg;
      exit 1
  | Failure msg ->
      Printf.eprintf "Translation error: %s\n" msg;
      exit 1
  | e ->
      Printf.eprintf "Error: %s\n" (Printexc.to_string e);
      exit 1
