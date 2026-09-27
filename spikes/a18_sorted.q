\l spikes/h.q
\l spikes/bench.q
/ A18: a monotone column. Two encodings of a table whose time column must be sorted:
/   delta — each row draws a non-negative delta on the previous time (the sortedness is in the choices; a
/           shrink of one choice moves every later time by the same amount and the table stays sorted)
/   sort  — rows draw times independently and the table is sorted afterwards (the sortedness is a post-process;
/           a shrink of one time permutes rows)
/ Rows are spans either way (C13). Measured: minima reached on four planted bugs, attempts, and whether every
/ candidate the property saw was sorted.
.s.last:0; .s.bad:0
row:{[d] t:.s.last+.qc.draw .qc.int 0 9; .s.last:t; (t;.qc.draw .qc.int 0 9)}                / delta encoding
delta:{[d] .s.last:0; rs:.qc.draw .qc.lst[0 20] row; flip `time`v!$[count rs; flip rs; (`long$();`long$())]}
rowu:{[d] (.qc.draw .qc.int 0 99;.qc.draw .qc.int 0 9)}
sortd:{[d] rs:.qc.draw .qc.lst[0 20] rowu; `time xasc flip `time`v!$[count rs; flip rs; (`long$();`long$())]}
chk:{[x] if[not x[`time]~asc x`time; .s.bad+:1]}                                                / every candidate must be sorted
cases:{[g] ([] name:`gap9`bucket`runmax`window;
  spec:4#enlist g;
  prop:({chk x; $[1<count x; 9>max 1_deltas x`time; 1b]};{chk x; (count x)=count distinct 5 xbar x`time};
        {chk x; x[`v]~maxs x`v};{chk x; not any 3<{sum x within (y-9;y)}[x`time] each x`time});
  minp:({(2=count x`x) and 9=last deltas x[`x]`time};{(2=count x`x) and 0=last deltas x[`x]`time};
        {(2=count x`x) and (1 0~x[`x]`v) and 0=last deltas x[`x]`time};{(4=count x`x) and all 0=1_deltas x[`x]`time});
  lists:4#1b)}
.s.bad:0; A:.b.run[.b.q;cases delta]; badA:.s.bad
.s.bad:0; B:.b.run[.b.q;cases sortd]; badB:.s.bad
-1 "--- delta"; .b.show A; -1 "--- sort after"; .b.show B
-1 "info: unsorted candidates seen by the property: delta ",string[badA],", sort-after ",string badB;
.h.t["delta: every planted bug shrinks to its analytic minimum"; all A`ok]
.h.t["delta: no candidate was ever unsorted"; 0=badA]
.h.t["sort-after: no candidate was ever unsorted (it cannot be, the sort is inside the generator)"; 0=badB]
.h.t["sort-after reaches the minima too, or says which it misses"; all B`ok]
.h.t["delta needs no more attempts than sort-after overall"; (sum A`attempts)<=sum B`attempts]
.h.done[]
