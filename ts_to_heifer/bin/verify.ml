(** TypeScript to Heifer: Full Verification Demo
    Translates TypeScript and runs Heifer's verification engine *)

open Ts_to_heifer.Translator
open Hipcore_typed.Pretty
open Hipcore_typed.Typedhip

(** Convert intermediate to meth_def *)
let to_meth_def item =
  match item with
  | `Meth (name, params, spec, body, tactics, _pure_info) ->
      {
        m_name = name;
        m_params = params;
        m_spec = spec;
        m_body = body;
        m_tactics = tactics;
      }

(** Verify a method using Heifer's forward rules *)
let verify_method prog meth =
  try
    let inferred_spec, result = Hiplib.infer_and_check_method prog meth meth.m_spec in
    (Some inferred_spec, result, None)
  with
  | Failure msg -> (None, false, Some msg)
  | e -> (None, false, Some (Printexc.to_string e))

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

    (* Convert to method definitions *)
    let methods = List.map to_meth_def intermediates in

    (* Build program incrementally, verifying each method *)
    let prog_ref = ref empty_program in

    Printf.printf "╔════════════════════════════════════════════════════════════╗\n";
    Printf.printf "║  TypeScript to Heifer: Full Verification                  ║\n";
    Printf.printf "╚════════════════════════════════════════════════════════════╝\n\n";
    Printf.printf "Translating and verifying %d function(s)\n\n" (List.length methods);

    List.iteri (fun idx meth ->
        Printf.printf "Function %d: %s\n" (idx + 1) meth.m_name;
        Printf.printf "%s\n" (String.make 60 '-');

        Printf.printf "\nSignature:\n";
        Printf.printf "  fun %s(" meth.m_name;
        if List.length meth.m_params = 0 then
          Printf.printf ")"
        else
          Printf.printf "%s)"
            (String.concat ", "
              (List.map (fun (n, t) ->
                Printf.sprintf "%s: %s" n (string_of_type t)) meth.m_params));
        Printf.printf " : %s\n" (string_of_type meth.m_body.core_type);

        (match meth.m_spec with
        | Some spec ->
            Printf.printf "\nGiven Specification:\n";
            Printf.printf "  %s\n" (string_of_staged_spec spec);
        | None ->
            Printf.printf "\nNo specification given\n"
        );

        Printf.printf "\nBody:\n";
        let body_lines = String.split_on_char '\n' (string_of_core_lang meth.m_body) in
        List.iter (fun line ->
          Printf.printf "  %s\n" line
        ) body_lines;

        Printf.printf "\nVerification:\n";
        let (inferred_opt, result, error_opt) = verify_method !prog_ref meth in

        (match inferred_opt with
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
              Printf.printf "  ✓ VERIFICATION PASSED\n";
              Printf.printf "  Result: %b\n" result
            end
            else begin
              Printf.printf "  ✗ Specification does not entail given spec\n";
              Printf.printf "  Result: %b\n" result
            end
        );

        (* Add verified method to program for next iteration *)
        prog_ref := Hiplib.analyze_method !prog_ref meth;

        Printf.printf "\n%s\n\n" (String.make 60 '=')
    ) methods;

    Printf.printf "╔════════════════════════════════════════════════════════════╗\n";
    Printf.printf "║  Summary                                                   ║\n";
    Printf.printf "╚════════════════════════════════════════════════════════════╝\n";
    Printf.printf "  Functions verified: %d\n" (List.length methods);
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
