/ C5: a name is free iff not in .Q.res,key .q; nothing in .qc may shadow a reserved word
.t.t["no .qc name shadows a reserved word"; not any (key[`.qc] except `) in .Q.res,key .q]
.t.t["the words that bit us are indeed reserved"; all `bin`tables`cov in .Q.res,key .q]
/ a name defined twice in qc.q is a collision inside .qc (M8 defined blk twice; a generator overwrote a shrinker helper)
defs:{`$x til x?":"} each src where {$[0=count x; 0b; not first[x] in .Q.a,.Q.A; 0b; (x?":")=count x; 0b; all (x til x?":") in .Q.a,.Q.A,.Q.n,"_"]} each src:read0 `:qc.q   / (a like with a middle * is nyi, pitfall 24)
.t.t["no name is defined twice in qc.q"; (count defs)=count distinct defs]
if[(count defs)<>count distinct defs; -1 "  defined twice: ",.Q.s1 defs where 1<(count each group defs) defs]
/ C14: the error vocabulary is closed: every 'qc. literal in the source is an engine signal in ENG or is qc.eq
lits:raze {[l] {[l;i] first "\"" vs (i+2)_l}[l] each l ss "'\"qc."} each read0 `:qc.q
.t.t["every qc. literal in the source is an engine signal (ENG) or begins with a failure-signal stem (FS)"; (0<count lits) and all (lits in .qc.ENG) or .qc.fsg each lits]
/ locals and parameters must not shadow engine globals: a later edit that reaches for the global gets the local
G:key[`.qc] except `
idch:.Q.a,.Q.A,.Q.n,"_"
ident:{[p] n:0; while[(n<count p) and p[(count[p]-1)-n] in idch; n+:1]; neg[n]#p}   / (count[p]-1-n is count[p]-(1-n) in q)   / identifier ending the string
/ locals: an identifier before a single colon, not at column 0, on a continuation line or after a { on the line
loc1:{[l] if[0=count l; :()]; cont:l like " *"; is:l ss ":"; is:is where (is>0)&not (l (is-1)) in ":=<>~"; is:is where not {[l;i] (((i+1)#l) like "*::") or (i+1<count l) and l[i+1]=":"}[l] each is;   / neither colon of ::
  raze {[l;cont;i] pre:i#l; $[not cont or "{" in pre; (); 0=count nm:ident pre; (); "."=pre (count[pre]-count nm)-1; (); enlist `$nm]}[l;cont] each is}   / (.s.last: is a namespaced global, not a local)
/ the parameters and locals of every lambda in a file: the text between {[ and ] ([ is a class in ss patterns, hence
/ [[]; a no-argument {[] gives the empty name, dropped), and name: inside a lambda. The first line drops comment lines and trailing comments, the second blanks string
/ literals. (Each line of pl ends in a semicolon: t/run.q evaluates a file statement by statement with value, and
/ value of a multi-line string does not treat a newline inside a lambda as a separator, as \l does.)
pl:{[f]
  code:{$[x like "/*"; ""; first " /" vs x]} each read0 f;
  code:{s:"\"" vs x; i:1+2*til count[s] div 2; $[count i; "\"" sv @[s;i;:;count[i]#enlist ""]; x]} each code;
  pars:distinct raze {[l] if[0=count l; :()]; raze {[l;i] `$trim each ";" vs first "]" vs (i+2)_l}[l] each l ss "{[[]"} each code;
  (pars except `;distinct raze loc1 each code)}
r:pl `:qc.q; pars:r 0; locs:r 1
.t.t["no lambda parameter shadows an engine global"; 0=count pars inter G]
.t.t["no lambda parameter or local is a reserved word (q accepts one, and the body then sees the keyword: vs, from, cols, like)"; 0=count (pars,locs) inter .Q.res,key .q]
if[count (pars,locs) inter .Q.res,key .q; -1 "  reserved as names: ",.Q.s1 (pars,locs) inter .Q.res,key .q]
ALLOW:enlist `label                                                         / a q-sql column name in covt's table literal, not a local
.t.t["no lambda local shadows an engine global"; 0=count (locs inter G) except ALLOW]
if[count pars inter G; -1 "  params: ",.Q.s1 pars inter G]; if[count (locs inter G) except ALLOW; -1 "  locals: ",.Q.s1 (locs inter G) except ALLOW]
/ the same reserved-word check over every other q file in the repository: the worked example met vs, inv and asof as
/ names four times before this ran anywhere but qc.q (REVIEW.md T15). Shadowing engine globals is qc.q's concern only.
qfiles:{[d] f:key d; ` sv/: d,/:f where f like "*.q"}
fs:raze qfiles each `:examples`:examples/mdp`:examples/mdp/steps`:tools`:t`:spikes
rsv:{[f] r:pl f; (r[0],r[1]) inter .Q.res,key .q}
bad:fs where 0<count each rsv each fs
.t.t["no lambda parameter or local in examples/, tools/, t/ or spikes/ is a reserved word"; (30<count fs) and 0=count bad]
if[count bad; -1 "  ",/:string[bad],'": ",/:.Q.s1 each rsv each bad]
