(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2016     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(* This file defines standard combinators to build ml expressions *)

open Compat

type argument_type =
| ListArgType of argument_type
| OptArgType of argument_type
| PairArgType of argument_type * argument_type
| ExtraArgType of string

type user_symbol =
| Ulist1 of user_symbol
| Ulist1sep of user_symbol * string
| Ulist0 of user_symbol
| Ulist0sep of user_symbol * string
| Uopt of user_symbol
| Uentry of string
| Uentryl of string * int

type extend_token =
| ExtTerminal of string
| ExtNonTerminal of user_symbol * string

let mlexpr_of_list f l =
  List.fold_right
    (fun e1 e2 ->
      let e1 = f e1 in
       let loc = CompatLoc.merge (MLast.loc_of_expr e1) (MLast.loc_of_expr e2) in
       <:expr< [$e1$ :: $e2$] >>)
    l (let loc = CompatLoc.ghost in <:expr< [] >>)

let mlexpr_of_pair m1 m2 (a1,a2) =
  let e1 = m1 a1 and e2 = m2 a2 in
  let loc = CompatLoc.merge (MLast.loc_of_expr e1) (MLast.loc_of_expr e2) in
  <:expr< ($e1$, $e2$) >>

(* We don't give location for tactic quotation! *)
let loc = CompatLoc.ghost


let mlexpr_of_bool = function
  | true -> <:expr< True >>
  | false -> <:expr< False >>

let mlexpr_of_int n = <:expr< $int:string_of_int n$ >>

let mlexpr_of_string s = <:expr< $str:s$ >>

let mlexpr_of_option f = function
  | None -> <:expr< None >>
  | Some e -> <:expr< Some $f e$ >>

let symbol_of_string s = <:expr< Extend.Atoken (CLexer.terminal $str:s$) >>

let rec mlexpr_of_prod_entry_key f = function
  | Ulist1 s -> <:expr< Extend.Alist1 $mlexpr_of_prod_entry_key f s$ >>
  | Ulist1sep (s,sep) -> <:expr< Extend.Alist1sep $mlexpr_of_prod_entry_key f s$ $symbol_of_string sep$ >>
  | Ulist0 s -> <:expr< Extend.Alist0 $mlexpr_of_prod_entry_key f s$ >>
  | Ulist0sep (s,sep) -> <:expr< Extend.Alist0sep $mlexpr_of_prod_entry_key f s$ $symbol_of_string sep$ >>
  | Uopt s -> <:expr< Extend.Aopt $mlexpr_of_prod_entry_key f s$ >>
  | Uentry e -> <:expr< Extend.Aentry $f e$ >>
  | Uentryl (e, l) ->
    (** Keep in sync with Pcoq! *)
    assert (e = "tactic");
    if l = 5 then <:expr< Extend.Aentry (Pcoq.Tactic.binder_tactic) >>
    else <:expr< Extend.Aentryl (Pcoq.Tactic.tactic_expr) $mlexpr_of_int l$ >>

let rec type_of_user_symbol = function
| Ulist1 s | Ulist1sep (s, _) | Ulist0 s | Ulist0sep (s, _) ->
  ListArgType (type_of_user_symbol s)
| Uopt s ->
  OptArgType (type_of_user_symbol s)
| Uentry e | Uentryl (e, _) -> ExtraArgType e

let coincide s pat off =
  let len = String.length pat in
  let break = ref true in
  let i = ref 0 in
  while !break && !i < len do
    let c = Char.code s.[off + !i] in
    let d = Char.code pat.[!i] in
    break := Int.equal c d;
    incr i
  done;
  !break

let rec parse_user_entry s sep =
  let l = String.length s in
  if l > 8 && coincide s "ne_" 0 && coincide s "_list" (l - 5) then
    let entry = parse_user_entry (String.sub s 3 (l-8)) "" in
    Ulist1 entry
  else if l > 12 && coincide s "ne_" 0 &&
                   coincide s "_list_sep" (l-9) then
    let entry = parse_user_entry (String.sub s 3 (l-12)) "" in
    Ulist1sep (entry, sep)
  else if l > 5 && coincide s "_list" (l-5) then
    let entry = parse_user_entry (String.sub s 0 (l-5)) "" in
    Ulist0 entry
  else if l > 9 && coincide s "_list_sep" (l-9) then
    let entry = parse_user_entry (String.sub s 0 (l-9)) "" in
    Ulist0sep (entry, sep)
  else if l > 4 && coincide s "_opt" (l-4) then
    let entry = parse_user_entry (String.sub s 0 (l-4)) "" in
    Uopt entry
  else if Int.equal l 7 && coincide s "tactic" 0 && '5' >= s.[6] && s.[6] >= '0' then
    let n = Char.code s.[6] - 48 in
    Uentryl ("tactic", n)
  else
    let s = match s with "hyp" -> "var" | _ -> s in
    Uentry s
