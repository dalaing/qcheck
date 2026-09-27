/ M8: bulk vectors and tables (A22). loaded by t/run.q
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
system"S 7"
ms:{[f;x] t0:.z.p; r:f x; (r;(.z.p-t0)%1000000)}
/ generation
g:ms[.qc.draw;.qc.bulk[0 99;1000000 1000000]]
.t.t["bulk: a million longs in range, in under half a second (spike: 9 ms)"; (1000000=count g 0) and (all (g 0) within 0 99) and 500>g 1]
.t.t["bulk: one block is one unit of the choice budget"; 2=.qc.nch]
.t.t["bulk: the length varies with the range and never exceeds it"; all (count each .qc.draw 50#enlist .qc.bulk[0 9;0 20]) within 0 20]
.t.t["bulk: minimal is empty"; (`long$())~.qc.minimal .qc.bulk[0 99;0 1000]]
.t.t["bulk: replays its own choices"; (v~.qc.replay[.qc.C`v] .qc.bulk[0 99;0 1000]) and 1000>=count v:.qc.draw .qc.bulk[0 99;0 1000]]
.t.t["bulk: a block past the prefix is qc.overrun under strict replay"; "qc.overrun"~@[.qc.strict[enlist 5];.qc.bulk[0 99;0 1000];{x}]]
/ the fresh-draw laws, vectorised, on the ranges people use
v:.qc.draw .qc.bulk[0 1000;100000 100000]
.t.t["bulk: zeros under 20%, the bound present, large values present (C17)"; (0.2>avg 0=v) and (any v=1000) and 0.03<avg 500<v]
v:.qc.draw .qc.bulk[-1000 1000;100000 100000]
.t.t["bulk: symmetric range has both signs"; (0.4<avg v>0) and 0.4<avg v<0]
.t.t["bulk: full long range stays in bounds"; all within[;(-0W;0W)] .qc.draw .qc.bulk[-0W 0W;1000 1000]]
/ shrinking: the minimum is not a prefix, and block deletion reaches it fast
r:ms[{.qc.chk[q;x;{x~asc x}]};.qc.bulk[0 99;0 100000]]
.t.t["bulk: x~asc x over up to 1e5 elements shrinks to 1 0"; 1 0~r[0][`x]`x]
.t.t["bulk: in under 100 attempts and 5 seconds (spike: 44 attempts, 3 ms)"; (100>r[0]`attempts) and 5000>r 1]
r:.qc.chk[q;.qc.bulk[0 99;0 100000];{100>sum x}]
.t.t["bulk: a global bug (sum >= 100) shrinks to two elements 99 and 1 or one of 99... within budget"; (100<=sum r[`x]`x) and 3>=count r[`x]`x]
/ btab
tb:.qc.draw .qc.btab[5 5] `a`b`c!(0 9;("d";0 9);("f";0 9))
.t.t["btab: typed columns, one row count"; (5=count tb) and (7h=type tb`a) and (14h=type tb`b) and 9h=type tb`c]
r:.qc.chk[q;.qc.btab[0 10000] `k`v!(0 9;0 9);{not any 5<x`v}]
.t.t["btab: a planted bug shrinks to one row"; (1=count r[`x]`x) and 6<=first r[`x][`x;`v]]
.t.t["btab refuses a non-dict"; (@[.qc.draw;.qc.btab[1 1] 5;{x}]) like "qc: btab*"]
.qc.cfg[`v]:1
