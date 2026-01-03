=== Translation Successful ===

Heifer IR:
let identity_number = fun x (*@ req x:int; ens res:int @*) -> x in
let identity_string = fun s (*@ req s:Str; ens res:Str @*) -> s in
let identity_bool = fun b (*@ req b:bool; ens res:bool @*) -> b in
let log_message = fun msg (*@ req msg:Str; ens res:() @*) -> log msg in
let add = fun x y (*@ req x:int/\y:int; ens res:int @*) -> (x + y) in
let format = fun prefix value (*@ req prefix:Str/\value:int; ens res:Str @*) -> let tmp1 = toString  in
(prefix + tmp1) in
()

Type: unit

✓ Output is in Heifer's native format
