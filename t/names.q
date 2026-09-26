/ C5: a name is free iff not in .Q.res,key .q; nothing in .qc may shadow a reserved word
.t.t["no .qc name shadows a reserved word"; not any (key[`.qc] except `) in .Q.res,key .q]
.t.t["the words that bit us are indeed reserved"; all `bin`tables`cov in .Q.res,key .q]
/ C14: the error vocabulary is closed: every 'qc. literal in the source is an engine signal in ENG or is qc.eq
lits:raze {[l] {[l;i] first "\"" vs (i+2)_l}[l] each l ss "'\"qc."} each read0 `:qc.q
.t.t["every qc. literal in the source is an engine signal (ENG) or begins with a failure-signal stem (FS)"; (0<count lits) and all (lits in .qc.ENG) or .qc.fsg each lits]
/ locals and parameters must not shadow engine globals: a later edit that reaches for the global gets the local
G:key[`.qc] except `
src:read0 `:qc.q
code:{$[x like "/*"; ""; first " /" vs x]} each src                     / drop comment lines and trailing comments
code:{s:"\"" vs x; i:1+2*til count[s] div 2; $[count i; "\"" sv @[s;i;:;count[i]#enlist ""]; x]} each code   / blank string literals
idch:.Q.a,.Q.A,.Q.n,"_"
ident:{[p] n:0; while[(n<count p) and p[(count[p]-1)-n] in idch; n+:1]; neg[n]#p}   / (count[p]-1-n is count[p]-(1-n) in q)   / identifier ending the string
/ parameters: text between {[ and ]  ([ is a class in ss patterns, hence [[])
pars:distinct raze {[l] if[0=count l; :()]; raze {[l;i] `$trim each ";" vs first "]" vs (i+2)_l}[l] each l ss "{[[]"} each code
/ locals: an identifier before a single colon, not at column 0, on a continuation line or after a { on the line
loc1:{[l] if[0=count l; :()]; cont:l like " *"; is:l ss ":"; is:is where (is>0)&not (l (is-1)) in ":=<>~"; is:is where not {[l;i] (((i+1)#l) like "*::") or (i+1<count l) and l[i+1]=":"}[l] each is;   / neither colon of ::
  raze {[l;cont;i] pre:i#l; $[not cont or "{" in pre; (); count[nm:ident pre]; enlist `$nm; ()]}[l;cont] each is}
locs:distinct raze loc1 each code
.t.t["no lambda parameter shadows an engine global"; 0=count pars inter G]
ALLOW:enlist `label                                                         / a q-sql column name in covt's table literal, not a local
.t.t["no lambda local shadows an engine global"; 0=count (locs inter G) except ALLOW]
if[count pars inter G; -1 "  params: ",.Q.s1 pars inter G]; if[count (locs inter G) except ALLOW; -1 "  locals: ",.Q.s1 (locs inter G) except ALLOW]
