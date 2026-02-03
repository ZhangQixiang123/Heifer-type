
open Hipcore_typed
open Typedhip

(* let normalize : state -> state =
  fun (p, h) ->
  let h = simplify_heap h in
  (simplify_pure p, h) *)
exception Stateerror of string
(** given a nonempty heap formula, splits it into a points-to expression and another heap formula *)
let rec split_one (h : kappa) : ((string * term) * kappa) option =
  match h with
  | EmptyHeap -> None
  | PointsTo (x, t) -> Some ((x, t), EmptyHeap)
  | RecordPointsTo (_, _) -> None (* RecordPointsTo is handled separately *)
  | SepConj (a, b) ->
      match split_one a with
      | None -> split_one b
      | Some (c, r) -> Some (c, SepConj (r, b))

(** like split_one, but searches for a particular points-to *)
let rec split_find (n : string) (h : kappa) : (term * kappa) option =
  match h with
  | EmptyHeap -> None
  | PointsTo (x, t) ->
      if x = n then Some (t, EmptyHeap) else None
  | RecordPointsTo (_, _) -> None (* RecordPointsTo is handled separately *)
  | SepConj (a, b) ->
      match split_find n a with
      | Some (t, r) -> Some (t, SepConj (r, b))
      | None ->
          match split_find n b with
          | None -> None
          | Some (t, r) -> Some (t, SepConj (a, r))

let pairwise_var_inequality xs ys =
  let inequalities =
    List.concat_map
      (fun x ->
        List.filter_map
          (fun y ->
            if x = y then None
            else Some (Not (Atomic (EQ, var_of_binder x, var_of_binder y))))
          ys)
      xs
  in
  Syntax.conj inequalities

let xpure (h : kappa) : pi =
  let rec run h =
    match h with
    | EmptyHeap -> (True, [])
    | PointsTo (x, t) -> Syntax.(Atomic (GT, var x ~typ:Int, num 0), [(x, t.term_type)])
    | RecordPointsTo (x, fields) ->
        (* For records, we also require the pointer to be positive, and collect all field types *)
        let field_binders = List.map (fun (name, t) -> (name, t.term_type)) fields in
        Syntax.(Atomic (GT, var x ~typ:Int, num 0), (x, TRecord (List.map (fun (n, t) -> (n, t.term_type)) fields)) :: field_binders)
    | SepConj (a, b) ->
        let a, xs = run a in
        let b, ys = run b in
        (And (a, And (b, pairwise_var_inequality xs ys)), xs @ ys)
  in
  fst (run h)

let rec find_var_in_heap (v:string) (h:kappa) =

  match h with
  | EmptyHeap -> []
  | PointsTo (x, t) ->
      if x = v then [(x,t)] else []
  | RecordPointsTo (x, fields) ->
      (* For records, if the var matches, return the var with a record term representation *)
      if x = v then
        let record_type = TRecord (List.map (fun (name, t) -> (name, t.term_type)) fields) in
        let record_term = {term_desc = TRecordTerm fields; term_type = record_type} in
        [(x, record_term)]
      else []
  | SepConj (a, b) ->
      (find_var_in_heap v a) @ (find_var_in_heap v b) 



let try_return_var_name t =
  match t with
  | Typed_core_ast.Var x -> Some x
  | Typed_core_ast.Type (BaseTy (Tvar s)) -> Some s
  | _ -> None

let rec find_alising v (h:pi) =
  (*give v, find all x that x=v relation in pi*)
  match h with
  | Atomic (EQ, a, b) ->
      (match try_return_var_name a.term_desc, try_return_var_name b.term_desc with
       | Some a_var, Some b_var ->
           if a_var = v then [b_var]
           else if b_var = v then [a_var]
           else []
       | _ -> [])
  | And (a, b) ->
       (find_alising v a) @ (find_alising v b)
  | _ -> []
let rec check_alising (v:string list) (r:string list) (s:pi)  = 
  (*give v, find all x that x=>v relation in pi*)
  match v with 
  | [] -> r 
  | x::xs -> let alised = find_alising x s in 
             let current_v = List.fold_right (fun x acc -> if (List.exists (fun z -> if z = x then true else false ) r) then acc else x :: acc ) alised xs in check_alising current_v (x::r) s 

let find_all_var_in_heap v (s:(pi * kappa)) = 
  let alised = (check_alising [v] [] (fst s)) in
  (* print_int (List.length alised); *)
   List.fold_right (fun x acc -> find_var_in_heap x (snd s) @ acc) alised [] 

let find_alised_var_in_heap v (s:(pi * kappa)) = 
  let alised = (check_alising [v] [] (fst s)) in
  (* print_int (List.length alised); *)
   List.fold_right (fun x acc -> if not (List.is_empty (find_var_in_heap x (snd s))) then x else acc ) alised "" 

  

let rec swap_var_name_in_heap (ori:string) (replace:string) (h:kappa) =
  match h with
  | EmptyHeap -> EmptyHeap
  | PointsTo (x, t) ->
      if x=ori then PointsTo (replace, t) else  PointsTo (x, t)
  | RecordPointsTo (x, fields) ->
      if x=ori then RecordPointsTo (replace, fields) else RecordPointsTo (x, fields)
  | SepConj (a, b) ->
      SepConj (swap_var_name_in_heap ori replace a, swap_var_name_in_heap ori replace b)

let rec swap_content_in_heap (var:string) (contents:term) (h:kappa) =
  match h with
  | EmptyHeap -> EmptyHeap
  | PointsTo (x, t) ->
      if x=var then PointsTo (x, contents) else  PointsTo (x, t)
  | RecordPointsTo (x, fields) ->
      (* For records, if var matches, replace with contents if it's a record term *)
      if x=var then
        (match contents.term_desc with
         | TRecordTerm new_fields -> RecordPointsTo (x, new_fields)
         | _ -> RecordPointsTo (x, fields)) (* Keep original if contents is not a record *)
      else RecordPointsTo (x, fields)
  | SepConj (a, b) ->
      SepConj (swap_content_in_heap var contents a, swap_content_in_heap var contents b)

let rec find_var_in_pure (v:string) (h:pi) = 
  match h with
  | Colon (x,t) -> if x = v then [(x,t)] else []
  | And (a, b) ->
       (find_var_in_pure v a) @ (find_var_in_pure v b)
  | _ -> []

let rec swap_var_name_in_pure (ori:string) (replace:string) (s:pi) =
  match s with
  | Colon (x,t) -> if x = ori then Colon (replace,t) else Colon (x,t)
  | Atomic (EQ, a, b) ->
      let a_is_ori = match try_return_var_name a.term_desc with Some v -> v = ori | None -> false in
      let b_is_ori = match try_return_var_name b.term_desc with Some v -> v = ori | None -> false in
      if a_is_ori then Atomic (EQ, {term_desc=Var replace;term_type=a.term_type}, b)
      else if b_is_ori then Atomic (EQ, a, {term_desc=Var replace;term_type=b.term_type})
      else s
  | And (a, b) ->
       And (swap_var_name_in_pure ori replace a, swap_var_name_in_pure ori replace b)
  | _ -> s


let find_in_state (v:string) (s:(pi*kappa)) = 
  let r1 = find_all_var_in_heap v s in 
  match r1 with 
  |x::_ -> ("h",x) 
  | _ ->  (
    let r2 = find_var_in_pure v (fst s) in 
    match r2 with 
    | x :: _ -> ("s",x) 
    | _ -> raise (Stateerror "spec error") 
  )

let swap_var_name_in_state (ori:string) (replace:string) (s:pi*kappa) = 
  let new_pi = swap_var_name_in_pure ori replace (fst s) in 
  let new_kappa = swap_var_name_in_heap ori replace (snd s) in 
  (new_pi,new_kappa)

let swap_content_in_state (var:string) (contents:term) (s:pi*kappa) = 
  let result = find_alised_var_in_heap var s in 
  if result = "" then failwith "var not in heap" else
  let new_kappa = swap_content_in_heap result contents (snd s) in 
  (fst s,new_kappa)

let rec unify_terms_for_defty (ori:string) (args: ty list) (replace:ty) = 
  match args with 
  | [] -> [] 
  | x::xs -> (
    match x with 
    | BaseTy (Tyvar t) -> if t = ori then replace::(unify_terms_for_defty ori xs replace) else x::(unify_terms_for_defty ori xs replace)
    | BaseTy (Defty (a, ty_list)) -> BaseTy (Defty (a, unify_terms_for_defty ori ty_list replace)) ::  (unify_terms_for_defty ori xs replace) 
    | _ -> x:: (unify_terms_for_defty ori xs replace) 
  )

let rec unify_terms_in_heap (ori:string) (replace:ty) (s:kappa) = 
  match s with
  | PointsTo (x,t) -> (match t.term_desc with 
     |Type (BaseTy (Tyvar a)) -> if a = ori then PointsTo (x, {term_type=t.term_type;term_desc= Type replace}) else s
     |Type (BaseTy (Defty (a,b)))  ->  let des = Type (BaseTy (Defty (a, unify_terms_for_defty ori b replace))) in PointsTo (x,{term_desc=des;term_type = t.term_type})
     | _ -> s
     )
  | SepConj (s1,s2) -> SepConj (unify_terms_in_heap ori replace s1, unify_terms_in_heap ori replace s2)
  | _ -> s

let rec unify_var_name_in_pure (ori:string) (replace:ty) (s:pi) = 
  match s with
  | Colon (x,t) ->
     (match t.term_desc with 
     |Type (BaseTy (Tyvar a)) -> if a = ori then Colon (x, {term_type=t.term_type;term_desc= Type replace}) else s
     |Type (BaseTy (Defty (a,b)))  ->  let des = Type (BaseTy (Defty (a, unify_terms_for_defty ori b replace))) in Colon (x,{term_desc=des;term_type = t.term_type})
     | _ -> s
     )
  (* | Atomic (EQ, a, b) -> if (Typed_core_ast.return_var_name a.term_desc) = ori then Atomic (EQ, {term_desc=Var replace;term_type=a.term_type}, b) else if (Typed_core_ast.return_var_name b.term_desc) = ori then  Atomic (EQ, a, {term_desc=Var replace;term_type=b.term_type}) else s *)

  | And (a, b) ->
       And (unify_var_name_in_pure ori replace a, unify_var_name_in_pure ori replace b)
  | _ -> s

let unify_var_name_in_state (ori:string) (replace:term) (s:pi*kappa) = 
  let process_for_var_replace = (
  match replace.term_desc with 
  | Var x -> let new_pi = swap_var_name_in_pure ori x (fst s) in 
                              let new_kappa = swap_var_name_in_heap ori x (snd s) in 
                              
              let pi = unify_var_name_in_pure ori (BaseTy (Tvar x)) (new_pi) in 
              let kappa =  unify_terms_in_heap ori (BaseTy (Tvar x)) (new_kappa) in 
              (pi,kappa)

                
  | _ -> (fst s, snd s)
  ) in

 let pi = match replace.term_desc with 
  | Type a -> unify_var_name_in_pure ori a (fst process_for_var_replace) 
  | _ -> fst process_for_var_replace in
  
 let kappa =  match replace.term_desc with 
  | Type a -> unify_terms_in_heap ori a (snd process_for_var_replace) 
  | _ -> snd process_for_var_replace
  in 
 (pi,kappa)

  (*
let rec check :
  string ->
  string list ->
  state ->
  state ->
  (pi * pi * kappa -> 'a Search.t) ->
  'a Search.t =
fun id vs ante conseq k ->
let open Search in
(* TODO ptr equalities? *)
let a = (*normalize*) ante in
let c = (*normalize*) conseq in
(* debug ~at:1
  ~title:(Format.asprintf "SL entailment (%s)" id)
  "%s |- %s" (string_of_state ante) (string_of_state conseq); *)
(* TODO frame and spans *)
match (a, c) with
  | _ -> failwith "check"
(*
| (p1, h1), (p2, EmptyHeap) ->
  (* debug ~at:4 ~title:(Format.asprintf "right empty") ""; *)
  let left = And (xpure h1, p1) in
  (* TODO add more logging to surface what happens in these entailments *)
  k (left, p2, h1)
| (p1, h1), (p2, h2) -> begin
  (* we know h2 is non-empty *)
  match split_one h2 with
  | Some ((x, v), h2') when List.mem x vs ->
    (* debug ~at:4 ~title:(Format.asprintf "existential location %s" x) ""; *)
    let left_heap = list_of_heap h1 in
    (match left_heap with
    | [] -> fail
    | _ :: _ ->
      (* x is bound and could potentially be instantiated with anything on the right side, so try everything *)
      let r1 =
        any
          ~to_s:(fun (a, _) -> string_of_pair Fun.id string_of_term a)
          ~name:"ent-match-any"
          (left_heap |> List.map (fun a -> (a, (x, v))))
          (fun ((x1, v1), _) ->
            let _v2, h1' = split_find x1 h1 |> Option.get in
            (* ptr equality *)
            let _ptr_eq = Atomic (EQ, Var x1, Var x) in
            let triv = Atomic (EQ, v, v1) in
            (* matching ptr values are added as an eq to the right side, since we don't have a term := term substitution function *)
            check id vs (conj [p1], h1') (conj [p2; triv], h2') k)
      in
      r1)
  | Some ((x, v), h2') -> begin
    (* debug ~at:4 ~title:(Format.asprintf "free location %s" x) ""; *)
    (* x is free. match against h1 exactly *)
    match split_find x h1 with
    | Some (v1, h1') -> begin
      check id vs
        (conj [p1], h1')
        (conj [p2; And (p1, Atomic (EQ, v, v1))], h2')
        k
    end
    | None ->
      (* TODO *)
      (* debug ~at:4 ~title:(Format.asprintf "failed") ""; *)
      fail
  end
  | None -> failwith (Format.asprintf "could not split LHS, bug?")
end
*)

(* let%expect_test _ =
  let one ?ex h1 h2 =
    let on_ans (a, o, f) =
      Format.printf "%s |- %s * %s@.assumptions: %s@.obligations: %s@." (string_of_state h1) (string_of_state h2) (string_of_kappa f) (string_of_pi (Normalize.simplify_pure a)) (string_of_pi (Normalize.simplify_pure o))
    in
    (* TODO factor out this code which processes all answers *)
    let at_least_one = ref false in
    check "test" (Option.value ~default:[] ex) h1 h2 (fun (a, o, f) ->
      at_least_one := true;
      on_ans (a, o, f);
      (* continue to backtrack *)
      None) |> ignore;
    if not !at_least_one then
      Format.printf "%s |/- %s@." (string_of_state h1) (string_of_state h2)
  in
  one (True, PointsTo ("x", Num 1)) (True, PointsTo ("x", Num 1));
  [%expect {|
    x->1 |- x->1 * emp
    assumptions: T
    obligations: T
    |}];

  one (True, PointsTo ("x", Num 1)) (True, PointsTo ("x", Num 2));
  [%expect {|
    x->1 |- x->2 * emp
    assumptions: T
    obligations: 2=1
    |}];

  one (True, PointsTo ("x", Num 1)) (True, PointsTo ("y", Num 1));
  [%expect {| x->1 |/- y->1 |}];

  one (True, PointsTo ("x", Num 1)) (True, SepConj (PointsTo ("x", Num 1), PointsTo ("y", Num 2)));
  [%expect {| x->1 |/- x->1*y->2 |}];

  one (True, SepConj (PointsTo ("x", Num 1), PointsTo ("y", Num 2))) (True, PointsTo ("x", Num 1));
  [%expect {|
    x->1*y->2 |- x->1 * y->2
    assumptions: y>0
    obligations: T
    |}];

  (* Debug.init ~ctf:false ~org:false (Some "4"); *)
  one ~ex:["z"] (True, SepConj (PointsTo ("x", Num 1), PointsTo ("y", Num 1))) (True, PointsTo ("z", Num 1));
  [%expect {|
    x->1*y->1 |- z->1 * y->1
    assumptions: y>0
    obligations: T
    x->1*y->1 |- z->1 * x->1
    assumptions: x>0
    obligations: T
    |}] *)
*)
