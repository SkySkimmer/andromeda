%{
  open InputTT

%}


%token <bool> BOOL
%token <int> INJ
%token <int> INT
%token <string> NAME


%token ASCRIBE
%token ASSUME
%token BAR
%token COLON
%token COLONEQ
%token COMMA
%token CONTEXT
%token DARROW
%token DEBRUIJN
%token DEFINE
%token END
%token EOF
%token EQ
%token FUN
%token HANDLE
%token HANDLER
%token HELP
%token IN
%token LAMBDA
%token LBRACK
%token LET
%token LPAREN
%token MATCH
%token OP
%token QUIT
%token RBRACK
%token RPAREN
%token SEMISEMI
%token UNIT
%token VAL
%token WITH


%start <InputTT.toplevel list> file
%start <InputTT.toplevel> commandline

%%

(* Toplevel syntax *)

file:
  | filecontents EOF            { $1 }

filecontents:
  |                                { [] }
  | topdef sso filecontents        { $1 :: $3 }
  | topdirective sso filecontents  { $1 :: $3 }
  (*| tophandler sso filecontents    { $1 :: $3 }*)

(*tophandler: mark_position(plain_tophandler) { $1 }*)
(*plain_tophandler:*)
  (*| WITH handler { TopHandler($2) }*)

commandline:
  | topdef SEMISEMI        { $1 }
  | topdirective SEMISEMI  { $1 }

(* Things that can be defined on toplevel. *)
topdef: mark_position(plain_topdef) { $1 }
plain_topdef:
  | DEFINE NAME COLONEQ comp               { TopDef ($2, None, $4) }
  | DEFINE NAME COLON comp COLONEQ comp    { TopDef ($2, Some $4, $6) }
  | ASSUME nonempty_list(NAME) COLON comp  { TopParam ($2, $4) }

(* Toplevel directive. *)
topdirective: mark_position(plain_topdirective) { $1 }
plain_topdirective:
  | CONTEXT    { Context }
  | HELP       { Help }
  | QUIT       { Quit }

sso :
  |          {}
  | SEMISEMI {}

(* Main syntax tree *)

exp: mark_position(plain_exp) { $1 }
plain_exp:
    | NAME                              { Var $1 }
    | FUN NAME DARROW comp    { Fun ($2, $4) }
    | handler                { Handler $1 }
    | LBRACK es=separated_list(COMMA, exp) RBRACK    { Tuple es }
    | const                  { Const $1 }
    | INJ exp               { Inj ($1, $2) }
    | LPAREN plain_exp RPAREN      { $2 }

comp: mark_position(plain_comp) { $1 }
plain_comp:
    | VAL exp        { Val $2 }
    | exp exp        { App ($1, $2) }
    | exp ASCRIBE exp        { Ascribe ($1, $3) }
    | LET NAME EQ comp IN comp { Let($2, $4, $6) }
    | OP NAME exp    { Op ($2, $3) }
    | WITH exp HANDLE comp  { WithHandle ($2, $4) }
    | HANDLE comp WITH exp  { WithHandle ($4, $2) }
    | MATCH e=exp WITH option(BAR) lst=separated_list(BAR, arm) END { Match (e, lst) }
    | DEBRUIJN INT       { MkVar $2 }
    | LAMBDA NAME COLON exp COMMA comp { MkLam($2, $4, $6) }

arm:
  pat DARROW comp { ($1, $3) }

pat:
    | LBRACK xs=separated_list(COMMA, NAME) RBRACK { PTuple xs }
    | INJ NAME  { PInj($1, $2) }
    | const     { PConst $1 }

handler:
    | HANDLER VAL x=NAME DARROW c=comp hcs=list(hcase) END { { valH = (x,c); opH = hcs } }

hcase:
    | BAR OP op=NAME p=pat k=NAME DARROW c=comp { (op,p,k,c) }

const:
    | INT  { Int $1 }
    | BOOL { Bool $1 }
    | UNIT { Unit }

mark_position(X):
  x = X
  { x, Position.make $startpos $endpos }

%%
