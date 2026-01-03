=== Translation Successful ===

Heifer IR:
let add_nums = fun x y (*@ req x:int/\y:int; ens res:int @*) -> (x + y) in
let subtract = fun x y (*@ req x:int/\y:int; ens res:int @*) -> (x - y) in
let multiply = fun x y (*@ req x:int/\y:int; ens res:int @*) -> (x * y) in
let divide = fun x y (*@ req x:int/\y:int; ens res:int @*) -> (x / y) in
let power = fun x y (*@ req x:int/\y:int; ens res:int @*) -> (x ^ y) in
let less_than = fun x y (*@ req x:int/\y:int; ens res:bool @*) -> if x<y then true else (false) in
let greater_or_equal = fun x y (*@ req x:int/\y:int; ens res:bool @*) -> if x>=y then true else (false) in
let equals = fun x y (*@ req x:int/\y:int; ens res:bool @*) -> if x=y then true else (false) in
let not_equals = fun x y (*@ req x:int/\y:int; ens res:bool @*) -> if not(x=y) then true else (false) in
let and_op = fun a b (*@ req a:bool/\b:bool; ens res:bool @*) -> (a && b) in
let or_op = fun a b (*@ req a:bool/\b:bool; ens res:bool @*) -> (a || b) in
let not_op = fun a (*@ req a:bool; ens res:bool @*) -> true in
let concat = fun a b (*@ req a:Str/\b:Str; ens res:Str @*) -> (a + b) in
let negate = fun x (*@ req x:int; ens res:int @*) -> (0 - x) in
let complex_expr = fun x y z (*@ req x:int/\y:int/\z:int; ens res:int @*) -> (((x + y) * z) - ((x - y) / 2)) in
()

Type: unit

✓ Output is in Heifer's native format
