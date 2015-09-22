(** Runtime values and results *)

(** The values are "finished" or "computed" results. They are inert pieces
    of data.

    At the moment the only kind of value is a pair [(e,t)] where [e] is a
    term and [t] is a type. Such a value (in a given context [ctx]) indicates
    that the judgement [ctx |- e : t] is derivable. *)
type value =
  | Term of Judgement.term
  | Ty of Judgement.ty
  | Closure of closure
  | Handler of handler

(** A closure *)
and closure = value -> result

(** A result of computation at the moment is necessarily just a pure value
    because we do not have any operations in the language. But when we do,
    they will be results as well (and then handlers will handle them). *)
and result =
  | Return of value
  | Operation of string * value * closure

and handler = {
  handler_val: closure option;
  handler_ops: (string * (value -> value -> result)) list;
  handler_finally: closure option;
}

val as_term : loc:Location.t -> value -> Judgement.term
val as_ty : loc:Location.t -> value -> Judgement.ty
val as_closure : loc:Location.t -> value -> closure
val as_handler : loc:Location.t -> value -> handler

val return_term : Judgement.term -> result
val return_ty : Judgement.ty -> result

val bind: result -> closure -> result

(** Pretty-print a value. *)
val print : ?max_level:int -> Name.ident list -> value -> Format.formatter -> unit

(** Check that a result is a value and return it, or complain. *)
val to_value : loc:Location.t -> result -> value
