\l spikes/h.q
/ A25: a machine-readable result. .j.j on the result dict for every outcome of the matrix in t/outcomes.q:
/ what breaks, what reads back.
if[not `qc in key `; system"l qc.q"]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
R:`okn`exh`fals`err`gave`cov`covs`nmax`rcf`rco!(.qc.chk[q;.qc.int 0 999;{1b}]; .qc.chk[q;.qc.bool;{1b}]; .qc.chk[q;.qc.list .qc.int 0 9;{x~asc x}]; .qc.chk[q;{'"boom"};{1b}];
   .qc.chk[q;.qc.such[{0b}] .qc.int 0 9;{1b}]; .qc.chk[q;.qc.elem til 1000;{.qc.cover[`m;90;x<800]; 1b}];
   .qc.chk[q;.qc.elem til 1000;{.qc.cover[`m;90;x<950]; 1b}]; .qc.chk[q,enlist[`nmax]!enlist 200;.qc.elem til 1000;{.qc.cover[`m;90;x<910]; 1b}];
   .qc.recheck[.qc.int 0 9;{x<5};enlist 7]; .qc.recheck[.qc.int 0 9;{x<5};enlist 2])
R[`eqn]:.qc.chk[q;.qc.list .qc.int 0 100;{.qc.eq[x;asc x]}]                       / notes hold a table
R[`fnx]:.qc.chk[q;.qc.elem ({x};{x+1});{0b}]                                       / a counterexample that is a function
js:{@[.j.j;x;{"ERR: ",x}]}
J:js each value R
show flip `outcome`json!(key R;40#'J)
.h.t[".j.j never errors on a result"; not any J like "ERR:*"]
back:key[R]!{@[.j.k;x;{(`ERR;x)}]} each J
.h.t[".j.k reads every one back as a dict with the same keys"; all {(99h=type y) and (key x)~key y}'[value R;value back]]
-1 "info: how :: comes back: ",.Q.s1 (back[`okn])`x;
-1 "info: how a symbol comes back: ",.Q.s1 (back[`okn])`why;
-1 "info: how the seed (int) comes back: ",.Q.s1 (back[`okn])`seed;
-1 "info: how the cover table comes back: ",.Q.s1 (back[`cov])`cover;
-1 "info: how a note table comes back: ",.Q.s1 (back[`eqn])`notes;
-1 "info: how a function counterexample comes back: ",.Q.s1 (back[`fnx])`x;
.h.t["symbols become strings, :: becomes null (0n back), ints become floats, functions become their source, and .j.k reads a table back as a table"; ((back[`okn])[`why]~"ok") and (null (back[`okn])`x) and (7f~(back[`okn])`seed) and (98h=type (back[`cov])`cover) and ("{x}"~(back[`fnx])[`x]`x)]
.h.done[]
