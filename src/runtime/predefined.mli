(** Predefined types and operations. *)

(** The ML equivalent of the AML coercible type
 *)
type coercible =
  | NotCoercible
  | Convertible of Jdg.eq_ty
  | Coercible of Jdg.term

(** {6 Built-in Definitions} *)

(** The list of built-in type, operation, and dynamic variable definitions
    corresponding to the names in Name.Predeclared, e.g.,
       - ['a list] and its constructors [[]] and [::]
       - ['a option] and its constructors [Some] and [None]
       - [coercible] and its constructors (as above)
       - operations [equal], [as_prod], [as_eq], [coerce], [coerce_fun]
       - the dynamic variable [hypotheses]
 *)
val definitions : Input.toplevel list

(** {6 Runtime computations to invoke operations} *)

(** A computation that, when run, invokes the [equal] operation on the given
    terms (wrapped as AML values), and then returns the resulting term if any
    (unwrapped from an AML value to a type theoretical judgment
 *)
val operation_equal : loc:Location.t -> Jdg.term -> Jdg.term -> Jdg.term option Runtime.comp

(** A computation that, when run, invokes the [coerce] operation
    on the given type theory term and desired type, and decodes
    the resulting AML value as a value of the correponding ML type [coercible].
 *)
val operation_coerce : loc:Location.t -> Jdg.term -> Jdg.ty -> coercible Runtime.comp

(** A computation that, when run, invokes the [coerce_fun] operation on the
    given term and decodes the resulting AML value into the ML type [coercible].
 *)
val operation_coerce_fun : loc:Location.t -> Jdg.term -> coercible Runtime.comp

(** A computation that, when run, invokes the [as_prod] operration on the
    given type; unwraps the resulting evidence (if any) that the given
    type is equal to a Pi type.
 *)
val operation_as_prod : loc:Location.t -> Jdg.ty -> Jdg.term option Runtime.comp

(** A computation that, when run, invokes the [as_eq] operration on the
    given type; unwraps the resulting evidence (if any) that the given
    type is equal to an == type.
 *)
val operation_as_eq : loc:Location.t -> Jdg.ty -> Jdg.term option Runtime.comp

(** {6 translation between AML and ML values} *)

(** Decodes an AML list value as an ML list of AML values.
    Fails if the given value is not an AML [list].
 *)
val as_list : loc:Location.t -> Runtime.value -> Runtime.value list

(** Encodes a list of AML values as an AML list value
 *)
val mk_list : Runtime.value list -> Runtime.value

(** Encodes an ML option as an AML option
 *)
val from_option : Runtime.value option -> Runtime.value

(** Decodes an AML option as an ML option.
    Fails if the given value is not an AML [option]
 *)
val as_option : loc:Location.t -> Runtime.value -> Runtime.value option

(** {6 Other} *)

(** Takes a variable (a judgment describing a variable/atom within a context),
    temporarily adds it to the the front of the list contained in the
    dynamic variable [hypotheses] to run the given computation.
 *)
val add_abstracting : Jdg.term -> 'a Runtime.comp -> 'a Runtime.comp

