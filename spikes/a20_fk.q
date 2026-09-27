\l spikes/h.q
\l spikes/bench.q
/ A20: two tables over one drawn symbol list (a foreign key by shared draw). Does clamp-on-misalign keep every
/ shrink candidate referentially valid when the symbol list shrinks, and what is the minimum for a planted aj bug?
.s.last:0; .s.bad:0
row:{[s;cg;d] t:.s.last+.qc.draw .qc.int 0 9; .s.last:t; (.qc.draw .qc.elem s; t; .qc.draw cg)}          / sym, monotone time, one value
tbl:{[s;nm;cg;d] .s.last:0; rs:.qc.draw .qc.lst[0 6] row[s;cg]; flip (`sym`time,nm)!$[count rs; flip rs; (`symbol$();`long$();`long$())]}
pair:{[d] s:.qc.draw .qc.lst[1 3] .qc.symc["abc";1 1]; q:.qc.draw tbl[s;`px;.qc.int 0 9]; t:.qc.draw tbl[s;`qty;.qc.int 0 9]; `s`q`t!(s;q;t)}
/ the planted bug: a naive as-of join that takes the first quote at or before the trade instead of the last
naive:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; first r; 0N]}[q]; update px:"j"$f'[sym;time] from t}   / ("j"$: an empty t must still get a long column, as aj gives)
ref:{[t;q] aj[`sym`time;t;q]}
prop:{if[not all (x[`q;`sym],x[`t;`sym]) in x`s; .s.bad+:1]; (ref[x`t;x`q])~naive[x`t;x`q]}
r:.qc.chk[.b.q;pair;prop]
-1 "info: attempts ",string[r`attempts],", shrinks ",string r`shrinks; show r[`x]`x
.h.t["the bug is found"; `falsified=r`why]
.h.t["every candidate was referentially valid (elem s clamps into the shrunk list)"; 0=.s.bad]
m:r[`x]`x
.h.t["the minimum: two quotes for one symbol at the same time with different prices, one trade"; (2=count m`q) and (1=count m`t) and (1=count distinct m[`q]`sym) and (1=count distinct m[`q]`time) and 2=count distinct m[`q]`px]
.h.t["and the symbol list shrank to one symbol"; 1=count m`s]
.h.t["found within 300 attempts"; r[`attempts]<=300]
.h.done[]
