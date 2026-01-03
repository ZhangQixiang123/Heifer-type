(** TypeScript to Heifer Translator CLI *)

open Ts_to_heifer.Translator
open Hipcore_typed.Typed_core_ast
open Hipcore_typed.Pretty

(** Print function in OCaml format with specification *)
let print_function name params spec body =
  Printf.printf "let %s " name;
  List.iter (fun (param_name, _param_type) ->
    Printf.printf "%s " param_name
  ) params;
  (* Print body *)
  Printf.printf "= %s\n" (string_of_core_lang body);
  (* Print specification from parsed AST *)
  (match spec with
   | Some s -> Printf.printf " (*@ %s @*)\n" (string_of_staged_spec s)
   | None -> ());
  Printf.printf "\n"

let () =
  if Array.length Sys.argv < 2 then begin
    Printf.eprintf "Usage: %s <input.json> [--functions]\n" Sys.argv.(0);
    Printf.eprintf "  --functions: translate function declarations (default: expressions only)\n";
    exit 1
  end;

  let input_file = Sys.argv.(1) in
  let use_functions = Array.length Sys.argv > 2 && Sys.argv.(2) = "--functions" in

  try
    (* Parse JSON *)
    let json = Yojson.Safe.from_file input_file in

    if use_functions then begin
      (* Translate to function intermediates *)
      let intermediates = translate_program_to_intermediates json in

      if List.length intermediates = 0 then begin
        Printf.printf "(* No functions found *)\n";
        exit 0
      end;

      (* Print each function *)
      Printf.printf "(* Translated from TypeScript *)\n\n";
      List.iter (fun item ->
        match item with
        | `Meth (name, params, spec, body, _tactics, _pure_info) ->
            print_function name params spec body
      ) intermediates;

      Printf.printf "(* Translation complete: %d function(s) *)\n" (List.length intermediates)
    end else begin
      (* Translate as expression (original behavior) *)
      let heifer_ir = translate_program json in

      Printf.printf "=== Translation Successful ===\n\n";
      Printf.printf "Heifer IR:\n";
      Printf.printf "%s\n\n" (string_of_core_lang heifer_ir);
      Printf.printf "Type: %s\n" (string_of_type heifer_ir.core_type);
      Printf.printf "\n✓ Output is in Heifer's native format\n"
    end

  with
  | Yojson.Json_error msg ->
      Printf.eprintf "JSON parse error: %s\n" msg;
      exit 1
  | Failure msg ->
      Printf.eprintf "Translation error: %s\n" msg;
      exit 1
  | e ->
      Printf.eprintf "Unexpected error: %s\n" (Printexc.to_string e);
      exit 1
