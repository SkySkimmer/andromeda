(** Context with hints. *)

type declaration =
  | Parameter of Syntax.ty
  | Definition of Syntax.ty * Syntax.term

type hint =
  | Advice of Syntax.ty
  | Equation of Syntax.term * Syntax.term
  | Rewrite of Syntax.term * Syntax.term

type t = {
  decls : declaration list ;
  names : Syntax.name list ;
  hints : hint list
}

let print {decls=ds; hints=hs; names=xs} =
  let rec print_names ds xs =
    match ds, xs with
      | [], [] -> ()
      | d::ds, x::xs ->
        print_names ds xs ;
        begin match d with
          | Parameter t ->
              Format.printf "@[<hov 4>assume %s@;<1 -2>: %t@]@\n" x (Print.ty xs t)
          | Definition (t, e) ->
              Format.printf "@[<hov 4>define %s@;<1 -2>: %t@;<1 -2>:= %t@]@\n"
                x (Print.ty xs t) (Print.term xs e)
        end
      | [], _::_ -> Error.impossible "fewer declarations than names in context"
      | _::_, [] -> Error.impossible "fewer names than declarations in context"
  in
  let print_hints xs =
    List.iter (function
      | Advice t ->
        Format.printf "advice (_ :: %t)@\n" (Print.ty xs t)
      | Rewrite (e1, e2) ->
        Format.printf "rewrite (_ :: %t == %t)@\n" (Print.term xs e1) (Print.term xs e2)
      | Equation (e1, e2) ->
        Format.printf "equation (_ :: %t == %t)@\n" (Print.term xs e1) (Print.term xs e2)
    )
  in
    print_names ds xs ;
    print_hints xs hs ;
    Format.printf "@."


let empty = { decls = [] ; names = [] ; hints = [] }

let names {names=lst} = lst

let shift_declaration delta declaration =
  match declaration with
  | Parameter ty1 ->
      Parameter( Syntax.shift_ty delta ty1 )
  | Definition(ty1, term1) ->
      Definition( Syntax.shift_ty delta ty1,
                  Syntax.shift delta term1 )

let shift_hint delta hint =
  match hint with

  | Advice t -> Advice (Syntax.shift_ty delta t)

  | Equation(term1, term2) ->
      Equation( Syntax.shift delta term1,
                Syntax.shift delta term2 )

  | Rewrite(term1, term2) ->
      Rewrite( Syntax.shift delta term1,
               Syntax.shift delta term2 )

let add_var x t ctx =
  {
    decls = Parameter t :: ctx.decls ;
    hints = List.map (shift_hint 1) ctx.hints;
    names = x :: ctx.names;
  }

let add_vars bnds ctx =
  let rec loop vars_added accum_ctx = function
    | []          -> accum_ctx
    | (x,t)::rest ->
        loop (vars_added+1)
             (add_var x (Syntax.shift_ty vars_added t) accum_ctx)
             rest
  in
     loop 0 ctx bnds

let add_def x t ((_,loc) as e) ctx =
  {
    decls = Definition (t, e) :: ctx.decls ;
    hints =
      (Rewrite ((Syntax.Var 0, loc), Syntax.shift 1 e)) ::
      List.map (shift_hint 1) ctx.hints ;
    names = x :: ctx.names;
  }

(** We always store all hints strongly normalized. Then we try
    to apply them, we strongly normalize the target as well. *)
let add_advice t ctx =
  let t = Norm.ty t in
  { ctx with
    hints = Advice t :: ctx.hints }

let add_equation e1 e2 ctx =
  let e1 = Norm.term e1
  and e2 = Norm.term e2 in
  { ctx with
    hints = Equation (e1, e2) :: ctx.hints }

let add_rewrite e1 e2 ctx =
  let e1 = Norm.term e1
  and e2 = Norm.term e2 in
  { ctx with
    hints = Rewrite (e1, e2) :: ctx.hints }

let lookup_var index {decls=lst} =
  try begin
    let inserted_ty =
      match List.nth lst index with
      | Parameter t       -> t
      | Definition (t, _) -> t  in
    (* Return the classifier relative to *this* context, not
       the context where we inserted the type.  (Unlike hints,
       we don't shift these inserted types each time a new
       variable is added to the context.)
     *)
    Syntax.shift_ty (index+1) inserted_ty
  end
  with
    | Failure _ -> Error.impossible "invalid de Bruijn index"

let lookup_advice t ctx =
  Print.debug "lookup_advice: looking for %t" (Print.ty ctx.names t) ;
  let t = Norm.ty t in
  Print.debug "lookup_advice*: looking for %t" (Print.ty ctx.names t) ;
  List.exists
    (function
      | Advice tprod ->
        begin match Apply.apply tprod t with
          | None -> 
            Print.debug "lookup_advice: rejecting advice %t for %t"
              (Print.ty ctx.names tprod) 
              (Print.ty ctx.names t) ;
            false
          | Some _ -> 
            Print.debug "lookup_advice: accepting advice %t for %t"
              (Print.ty ctx.names tprod) 
              (Print.ty ctx.names t) ;
            true
        end
      | Equation _ -> false
      | Rewrite _ -> false
    )
    ctx.hints

let lookup_equation e1 e2 ctx =
  Print.debug "lookup_equation: %t == %t" (Print.term ctx.names e1) (Print.term ctx.names e2) ;
  let e1 = Norm.term e1
  and e2 = Norm.term e2 in
  Print.debug "lookup_equation*: %t == %t" (Print.term ctx.names e1) (Print.term ctx.names e2) ;
  let predicate = function
    | Advice _ -> false
    | Equation(term1, term2)
    | Rewrite(term1, term2) ->
       Print.debug "lookup_equation: considering %t == %t"
         (Print.term ctx.names term1)
         (Print.term ctx.names term2) ;
       (Syntax.equal e1 term1 && Syntax.equal e2 term2) ||
       (Syntax.equal e2 term1 && Syntax.equal e1 term2)
  in
    List.exists predicate ctx.hints

let lookup_rewrite e1 ctx =
  let e1 = Norm.term e1 in
  let rec search = function
    | [] -> None
    | Rewrite (term1, term2) :: lst ->
      if Syntax.equal e1 term1 then
        Some term2
      else
        search lst
    | (Advice _ | Equation _) :: lst -> search lst
  in
    search ctx.hints


