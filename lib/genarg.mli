(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2016     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(** The route of a generic argument, from parsing to evaluation.
In the following diagram, "object" can be tactic_expr, constr, tactic_arg, etc.

{% \begin{%}verbatim{% }%}
             parsing          in_raw                            out_raw
   char stream ---> raw_object ---> raw_object generic_argument -------+
                          encapsulation                          decaps|
                                                                       |
                                                                       V
                                                                   raw_object
                                                                       |
                                                         globalization |
                                                                       V
                                                                   glob_object
                                                                       |
                                                                encaps |
                                                               in_glob |
                                                                       V
                                                           glob_object generic_argument
                                                                       |
          out                          in                     out_glob |
  object <--- object generic_argument <--- object <--- glob_object <---+
    |   decaps                       encaps      interp           decaps
    |
    V
effective use
{% \end{%}verbatim{% }%}

To distinguish between the uninterpreted (raw), globalized and
interpreted worlds, we annotate the type [generic_argument] by a
phantom argument which is either [constr_expr], [glob_constr] or
[constr].

Transformation for each type :
{% \begin{%}verbatim{% }%}
tag                            raw open type            cooked closed type

BoolArgType                    bool                      bool
IntArgType                     int                       int
IntOrVarArgType                int or_var                int
StringArgType                  string (parsed w/ "")     string
PreIdentArgType                string (parsed w/o "")    (vernac only)
IdentArgType true              identifier                identifier
IdentArgType false             identifier (pattern_ident) identifier
IntroPatternArgType            intro_pattern_expr        intro_pattern_expr
VarArgType                     identifier located        identifier
RefArgType                     reference                 global_reference
QuantHypArgType                quantified_hypothesis     quantified_hypothesis
ConstrArgType                  constr_expr               constr
ConstrMayEvalArgType           constr_expr may_eval      constr
OpenConstrArgType              open_constr_expr          open_constr
ConstrWithBindingsArgType      constr_expr with_bindings constr with_bindings
BindingsArgType                constr_expr bindings      constr bindings
List0ArgType of argument_type
List1ArgType of argument_type
OptArgType of argument_type
ExtraArgType of string         '_a                      '_b
{% \end{%}verbatim{% }%}
*)

(** {5 Generic types} *)

module ArgT :
sig
  type ('a, 'b, 'c) tag
  val eq : ('a1, 'b1, 'c1) tag -> ('a2, 'b2, 'c2) tag -> ('a1 * 'b1 * 'c1, 'a2 * 'b2 * 'c2) CSig.eq option
  val repr : ('a, 'b, 'c) tag -> string
  type any = Any : ('a, 'b, 'c) tag -> any
  val name : string -> any option
end

type (_, _, _) genarg_type =
| ExtraArg : ('a, 'b, 'c) ArgT.tag -> ('a, 'b, 'c) genarg_type
| ListArg : ('a, 'b, 'c) genarg_type -> ('a list, 'b list, 'c list) genarg_type
| OptArg : ('a, 'b, 'c) genarg_type -> ('a option, 'b option, 'c option) genarg_type
| PairArg : ('a1, 'b1, 'c1) genarg_type * ('a2, 'b2, 'c2) genarg_type ->
  ('a1 * 'a2, 'b1 * 'b2, 'c1 * 'c2) genarg_type
(** Generic types. ['raw] is the OCaml lowest level, ['glob] is the globalized
    one, and ['top] the internalized one. *)

type 'a uniform_genarg_type = ('a, 'a, 'a) genarg_type
(** Alias for concision when the three types agree. *)

val make0 : string -> ('raw, 'glob, 'top) genarg_type
(** Create a new generic type of argument: force to associate
    unique ML types at each of the three levels. *)

val create_arg : string -> ('raw, 'glob, 'top) genarg_type
(** Alias for [make0]. *)

(** {5 Specialized types} *)

(** All of [rlevel], [glevel] and [tlevel] must be non convertible
   to ensure the injectivity of the type inference from type
   ['co generic_argument] to [('a,'co) abstract_argument_type];
   this guarantees that, for 'co fixed, the type of
   out_gen is monomorphic over 'a, hence type-safe
*)

type rlevel = [ `rlevel ]
type glevel = [ `glevel ]
type tlevel = [ `tlevel ]

type (_, _) abstract_argument_type =
| Rawwit : ('a, 'b, 'c) genarg_type -> ('a, rlevel) abstract_argument_type
| Glbwit : ('a, 'b, 'c) genarg_type -> ('b, glevel) abstract_argument_type
| Topwit : ('a, 'b, 'c) genarg_type -> ('c, tlevel) abstract_argument_type
(** Type at level ['co] represented by an OCaml value of type ['a]. *)

type 'a raw_abstract_argument_type = ('a, rlevel) abstract_argument_type
(** Specialized type at raw level. *)

type 'a glob_abstract_argument_type = ('a, glevel) abstract_argument_type
(** Specialized type at globalized level. *)

type 'a typed_abstract_argument_type = ('a, tlevel) abstract_argument_type
(** Specialized type at internalized level. *)

(** {6 Projections} *)

val rawwit : ('a, 'b, 'c) genarg_type -> ('a, rlevel) abstract_argument_type
(** Projection on the raw type constructor. *)

val glbwit : ('a, 'b, 'c) genarg_type -> ('b, glevel) abstract_argument_type
(** Projection on the globalized type constructor. *)

val topwit : ('a, 'b, 'c) genarg_type -> ('c, tlevel) abstract_argument_type
(** Projection on the internalized type constructor. *)

(** {5 Generic arguments} *)

type 'l generic_argument = GenArg : ('a, 'l) abstract_argument_type * 'a -> 'l generic_argument
(** A inhabitant of ['level generic_argument] is a inhabitant of some type at
    level ['level], together with the representation of this type. *)

type raw_generic_argument = rlevel generic_argument
type glob_generic_argument = glevel generic_argument
type typed_generic_argument = tlevel generic_argument

(** {6 Constructors} *)

val in_gen : ('a, 'co) abstract_argument_type -> 'a -> 'co generic_argument
(** [in_gen t x] embeds an argument of type [t] into a generic argument. *)

val out_gen : ('a, 'co) abstract_argument_type -> 'co generic_argument -> 'a
(** [out_gen t x] recovers an argument of type [t] from a generic argument. It
    fails if [x] has not the right dynamic type. *)

val has_type : 'co generic_argument -> ('a, 'co) abstract_argument_type -> bool
(** [has_type v t] tells whether [v] has type [t]. If true, it ensures that
    [out_gen t v] will not raise a dynamic type exception. *)

(** {6 Type reification} *)

type argument_type = ArgumentType : ('a, 'b, 'c) genarg_type -> argument_type

(** {6 Equalities} *)

val argument_type_eq : argument_type -> argument_type -> bool
val genarg_type_eq :
  ('a1, 'b1, 'c1) genarg_type ->
  ('a2, 'b2, 'c2) genarg_type ->
  ('a1 * 'b1 * 'c1, 'a2 * 'b2 * 'c2) CSig.eq option
val abstract_argument_type_eq :
  ('a, 'l) abstract_argument_type -> ('b, 'l) abstract_argument_type ->
  ('a, 'b) CSig.eq option

val pr_argument_type : argument_type -> Pp.std_ppcmds
(** Print a human-readable representation for a given type. *)

val genarg_tag : 'a generic_argument -> argument_type

val unquote : ('a, 'co) abstract_argument_type -> argument_type

(** {6 Registering genarg-manipulating functions}

  This is boilerplate code used here and there in the code of Coq. *)

module type GenObj =
sig
  type ('raw, 'glb, 'top) obj
  (** An object manipulating generic arguments. *)

  val name : string
  (** A name for such kind of manipulation, e.g. [interp]. *)

  val default : ('raw, 'glb, 'top) genarg_type -> ('raw, 'glb, 'top) obj option
  (** A generic object when there is no registered object for this type. *)
end

module Register (M : GenObj) :
sig
  val register0 : ('raw, 'glb, 'top) genarg_type ->
    ('raw, 'glb, 'top) M.obj -> unit
  (** Register a ground type manipulation function. *)

  val obj : ('raw, 'glb, 'top) genarg_type -> ('raw, 'glb, 'top) M.obj
  (** Recover a manipulation function at a given type. *)

end

(** {5 Basic generic type constructors} *)

(** {6 Parameterized types} *)

val wit_list : ('a, 'b, 'c) genarg_type -> ('a list, 'b list, 'c list) genarg_type
val wit_opt : ('a, 'b, 'c) genarg_type -> ('a option, 'b option, 'c option) genarg_type
val wit_pair : ('a1, 'b1, 'c1) genarg_type -> ('a2, 'b2, 'c2) genarg_type ->
  ('a1 * 'a2, 'b1 * 'b2, 'c1 * 'c2) genarg_type
