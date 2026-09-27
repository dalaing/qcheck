/ the outcome matrix: verdicts, signals in both phases, result schema, stop x why, and state after every exit
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
/ the pass rule
pv:((::);1b;0b;101b;111b;();5;"s";`a)
.t.t["pass: documented verdicts for every result kind"; (1b;1b;0b;0b;1b;1b;`ERR;`ERR;`ERR)~{@[.qc.pass;x;{`ERR}]} each pv]
/ engine signals are discards in either phase, failure signals are falsifications in either phase
gsig:{[e] .qc.chk[q;{[e;d] 'e}[e];{1b}]}
psig:{[e] .qc.chk[q;.qc.int 0 9;{[e;x] 'e}[e]]}
.t.t["ENG in the generation phase: gave up, discards counted by stem"; all {[e] r:gsig e; (`gaveup=r`why) and (`$3_e) in key r`disc} each .qc.ENG]
.t.t["ENG in the property phase: gave up, discards counted by stem"; all {[e] r:psig e; (`gaveup=r`why) and (`$3_e) in key r`disc} each .qc.ENG]
.t.t["FS stems in the generation phase: falsified with x ::"; all {[e] r:gsig e; (`falsified=r`why) and ((::)~r`x) and (r`err)~e} each .qc.FS]
.t.t["FS stems in the property phase: falsified with the text"; all {[e] r:psig e; (`falsified=r`why) and (r`err)~e} each .qc.FS]
.t.t["a usage error in generation is a generator error; in the property a falsification"; (`error=(gsig "qc: bad")`why) and `falsified=(psig "qc: bad")`why]
/ result schema for every outcome and stop kind
KS:`ok`why`stop`n`shrinks`attempts`seed`x`err`bt`notes`cover`choices`hist`disc`stale
ty:{(type x`ok;type x`why;type x`stop;type x`n;type x`shrinks;type x`attempts;type x`seed;type x`err;type x`bt;type x`cover;type x`choices;type x`hist;type x`disc;type x`stale)}
sch:{[r] (KS~key r) and (-1 -11 -11 -7 -7 -7 -6 10 10 98 7 98 99 -1h~ty r) and (0h=type r`notes)}
R:(.qc.chk[q;.qc.int 0 999;{1b}]; .qc.chk[q;.qc.bool;{1b}]; .qc.chk[q;.qc.list .qc.int 0 9;{x~asc x}]; .qc.chk[q;{'"boom"};{1b}];
   .qc.chk[q;.qc.such[{0b}] .qc.int 0 9;{1b}]; .qc.chk[q;.qc.elem til 1000;{.qc.cover[`m;90;x<800]; 1b}];
   .qc.chk[q;.qc.elem til 1000;{.qc.cover[`m;90;x<950]; 1b}]; .qc.chk[q,enlist[`nmax]!enlist 200;.qc.elem til 1000;{.qc.cover[`m;90;x<910]; 1b}];
   .qc.recheck[.qc.int 0 9;{x<5};enlist 7]; .qc.recheck[.qc.int 0 9;{x<5};enlist 2])
.t.t["schema: every field present with its type, for every outcome"; all sch each R]
pieces:(`n`exhausted`fail`fail`gaveup~(5#R)@\:`stop; `ok`ok`falsified`error`gaveup`cover~(6#R)@\:`why; (R[6]`stop) in `cover`nmax; (R[7]`stop) in `cover`nmax; `fail`n~(-2#R)@\:`stop)
if[not all pieces; -1 "  outcome pieces: ",.Q.s1 pieces; -1 "  stops: ",.Q.s1 R@\:`stop; -1 "  whys: ",.Q.s1 R@\:`why]
.t.t["outcomes exercised: ok n, ok exhausted, falsified, error, gaveup, cover, cover settled, nmax-or-cover, recheck fail, recheck ok"; all pieces]
.t.t["stop x why consistency"; all {[r] ((r[`why] in `falsified`error)=r[`stop]=`fail) and ((r[`why]=`gaveup)=r[`stop]=`gaveup) and (r[`why] in `ok`cover)=r[`stop] in `n`exhausted`cover`nmax} each R]
/ state after every entry point on every exit, including errors
clean:{(not .qc.run) and (.qc.cf~.qc.cfg) and (0=.qc.dp) and (0=count .qc.st) and (.qc.bs=.qc.cfg`sz) and (.qc.sz=.qc.cfg`sz) and 25 80i~system"c"}
calls:({.qc.chk[q;.qc.int 0 9;{1b}]}; {.qc.chk[q;.qc.int 0 9;{x<5}]}; {.qc.chk[q;.qc.int 0 9;{.qc.check[.qc.int 0 9;{1b}]}]};
  {.qc.chk[q;.qc.int 0 9;5]}; {.qc.chk[q;.qc.int 5 1;{1b}]}; {.qc.chk[q;.qc.sm[`m0`init!(0;{'"x"})] .g.cm;::]};
  {.qc.recheck[.qc.int 0 9;5;enlist 1]}; {.qc.minimal {[d] '"x"}}; {.qc.replay[1 2] {[d] .qc.draw .qc.int 5 1}}; {.qc.draw .qc.sized 5};
  {.qc.chk[q;.qc.int 0 9;{.qc.fmt ([]a:til 30); 1b}]}; {.qc.chks[q;5]}; {.qc.check[.qc.bool;{.qc.minimal .qc.bool}]})
/ a run's size must not leak into later interactive draws (C9): chk resets every example at the run's size. (Appended
/ after the definition: ,: on an undefined global defines it at top level, so the first version of this was lost — pitfall 41)
calls,:({.qc.chk[q,enlist[`sz]!enlist 3;.qc.list .qc.int 0 9;{1b}]}; {.qc.chk[q,enlist[`sz]!enlist 3;.qc.int 5 1;{1b}]})
.t.t["the size-leak calls are in the list (15 calls)"; 15=count calls]
.t.t["state is clean after every entry point, on success and on error"; all {@[x;::;{x}]; clean[]} each calls]
.qc.cfg[`v]:1
/ C6/C9: what an error leaves behind — the entry points and the probe restore everything they touched
.t.e[.qc.minimal;{'"boom"}]
.t.t["minimal: a raising spec leaves the minimal flag clear and the cursor at 0"; (not .qc.mn) and 0=.qc.i]
.qc.cfg[`sz]:100; .qc.new[]
.t.e[.qc.draw;.qc.tab enlist[`a]!enlist .qc.small {'"boom"}]
.t.t["probe: a small that raises inside the probe leaves the size unhalved and adds no note"; (100=.qc.sz) and 0=count .qc.N]
r:.qc.chk[q;.qc.int 0 9;{x<3}]
.t.t["chk: the shrinker's copy of the property does not outlive the run"; ((::)~.qc.sprop) and ((::)~.qc.sspec) and 0=count .qc.cv]
.t.e[.qc.draw;.qc.such[{1b}] {'"boom"}]
.t.t["such: a raising generator leaves no open span (the next entry starts clean)"; 0=.qc.dp]
