=== Translation Successful ===

Heifer IR:
let get_value = fun s (*@ req s:_; ens res:int @*) -> if not(s=None()) then (s + 1) else (()) in
let maybe_positive = fun x (*@ req x:int; ens res:_ @*) -> if x>0 then x else (()) in
let process_value = fun x (*@ req x:_; ens res:int @*) -> if typeof(x)="number" then (x + 1) else (()) in
let get_or_default = fun x def (*@ req x:_/\def:int; ens res:int @*) -> if not(x=None()) then x else (()) in
let handle_result = fun result (*@ req result:_; ens res:int @*) -> if typeof(result)="string" then 0 else (if typeof(result)="number" then result else (if result=true then 1 else (0))) in
let is_null = fun x (*@ req x:_; ens res:bool @*) -> if x=None() then true else (false) in
let is_undefined = fun x (*@ req x:_; ens res:bool @*) -> if x=None() then true else (false) in
()

Type: unit

✓ Output is in Heifer's native format
