\l spikes/h.q
\l spikes/bench.q
/ A19: a key column without duplicates, three ways, over a key space of 10 at three densities (rows drawn up to
/ 5, 10 and 15):
/   such    — each row filters its key against the keys used so far: retries cost choices, and when the space is
/             smaller than the row count the example is discarded
/   remain  — each row indexes into the keys not yet used: one choice per row, no retries; the row count must be
/             capped by the key space (so it needs the space to be finite and known: an elem, not an int)
/   dedupe  — draw then `distinct`: never discards, but the table's row count is not the one drawn
/ Measured: discards, choices per example (the cost of retries), whether the planted bug shrinks to its minimum.
.s.used:`long$(); .s.rem:`long$(); .s.ch:0; .s.ex:0
mk:{[keyg;n] {[keyg;n;d] .s.used:`long$(); .s.rem:til 10; rs:.qc.draw .qc.lst[0,n] {[keyg;d] (keyg[];.qc.draw .qc.int 0 9)}[keyg];
  flip `k`v!$[count rs; flip rs; (`long$();`long$())]}[keyg;n]}
ksuch:{k:.qc.draw .qc.such[{not x in .s.used}] .qc.elem til 10; .s.used,:k; k}
kremain:{if[0=count .s.rem; '"qc.discard"]; k:.s.rem .qc.ch[(0;-1+count .s.rem;0);`u]; .s.rem:.s.rem except k; k}   / (a library uniq caps the rows instead)
dedupe:{[n] {[n;d] rs:.qc.draw .qc.lst[0,n] {[d] (.qc.draw .qc.elem til 10;.qc.draw .qc.int 0 9)}; t:flip `k`v!$[count rs; flip rs; (`long$();`long$())]; select by k from t}[n]}
/ the planted bug: values summing to 20 or more (minimum: three rows with distinct keys, values 9 9 2 in some order)
prop:{.s.ch+:count .qc.C; .s.ex+:1; x:0!x; (count[x]=count distinct x`k) and 20>sum x`v}
minp:{t:0!x`x; (3=count t) and (20<=sum t`v) and 3=count distinct t`k}
/ two runs per encoding and density: the bug (does it shrink to the minimum, in how many attempts) and the cost
/ (300 passing examples: discards and choices per example)
one:{[nm;g] o:.qc.chk[.b.q;g;prop]; .s.ch:0; .s.ex:0; c:.qc.chk[.b.q,enlist[`n]!enlist 300;g;{.s.ch+:count .qc.C; .s.ex+:1; 1b}];
  (nm;o`why;$[`falsified=o`why; minp o`x; 0b];o`attempts;c`why;sum c`disc;.s.ch%1|.s.ex)}
R:raze {[n] (one["such n<=",string n;mk[ksuch;n]];one["remain n<=",string n;mk[kremain;n]];one["dedupe n<=",string n;dedupe n])} each 5 10 15
T:flip `enc`why`minimal`attempts`costwhy`disc`chpe!flip R
system"c 40 200"; show T
.h.t["remain: no discards while the rows fit the key space, and the minimum is reached"; all exec (0=disc) and minimal from T where enc like "remain n<=[15]*",not enc like "remain n<=15"]
.h.t["remain: beyond the key space it must discard (or the library must cap the rows)"; 0<first exec disc from T where enc like "remain n<=15"]
.h.t["such: reaches the minimum, discards only beyond the key space"; (all exec minimal from T where enc like "such*") and (0=sum exec disc from T where enc like "such n<=[15]*",not enc like "such n<=15") and 0<first exec disc from T where enc like "such n<=15"]
.h.t["such costs more choices per example than remain at full density (retries are recorded)"; (first exec chpe from T where enc like "such n<=10")>first exec chpe from T where enc like "remain n<=10"]
.h.t["dedupe: never discards and reaches the minimum"; all exec (0=disc) and minimal from T where enc like "dedupe*"]
.h.done[]
