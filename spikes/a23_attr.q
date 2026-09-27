\l spikes/h.q
/ A23: attributes (s u g p) set inside a generator: do they survive draw, replay, strict, the shrinker's
/ candidates, the counterexample and the failure db? And does ~ compare them?
if[not `qc in key `; system"l qc.q"]
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
gs:`s`u`g`p!({[d] `s#asc .qc.draw .qc.lst[1 5] .qc.int 0 9};{[d] `u#distinct .qc.draw .qc.lst[1 5] .qc.int 0 9};
  {[d] `g#.qc.draw .qc.lst[1 5] .qc.int 0 9};{[d] `p#asc .qc.draw .qc.lst[1 5] .qc.int 0 9})
paths:{[a;g] v:.qc.draw g; c:.qc.C`v;
  (a=attr v; a=attr .qc.replay[c] g; a=attr .qc.strict[c] g; (.qc.chk[q;g;{[a;x] a=attr x}[a]])`ok; a=attr (r:.qc.chk[q;g;{3>count x}])[`x]`x)}
P:paths'[key gs;value gs]
show flip `attr`draw`replay`strict`candidates`counterexample!enlist[key gs],flip P
.h.t["every attribute survives every path"; all raze P]
f:`$":",getenv[`TMPDIR],"qcattr_",string .z.i; f set `s#1 2 3
.h.t["the failure db (set/get) keeps an attribute"; `s=attr get f]; hdel f
.h.t["~ ignores attributes: (`s#1 2)~1 2"; (`s#1 2)~1 2]
.h.t["so .qc.eq cannot report a missing attribute; a property must say attr x"; 1b~@[.qc.eq[`s#1 2;];1 2;{0b}]]
.h.t["`s# on an unsorted vector is an error, not a silent lie"; "s-fail"~@[{`s#x};2 1;{x}]]
.h.done[]
