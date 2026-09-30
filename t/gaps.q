/ the gaps docs/REVIEW.md T1/T2 named: public names and configuration keys that had no behavioural test. loaded by t/run.q
/ dble: single-precision-shaped doubles; finite, both signs, minimal 0, replays
v:.qc.draw 200#enlist .qc.dble; c:.qc.C`v
.t.t["dble: floats, finite, both signs, replays, minimal 0"; (9h=type v;all not null v;any v<0;any v>0;v~.qc.replay[c] 200#enlist .qc.dble;0f~.qc.minimal .qc.dble)]
/ discard: a property that discards is counted as a discard, not a failure
r:.qc.chk[q;.qc.int 0 9;{if[x>5; .qc.discard[]]; x<=5}]
.t.t["discard: the property's discards are counted and the run passes"; (r`ok) and 0<(r`disc)`discard]
/ label: a label placed directly appears in the coverage table with its count
r:.qc.chk[q;.qc.int 0 9;{.qc.label $[x<5;`low;`high]; 1b}]
.t.t["label: both labels appear and their counts sum to the tests"; (`high`low~asc exec label from r`cover) and (r`n)=exec sum n from r`cover]
/ check and checks in-process, with the defaults (v is 0 here, so nothing prints)
r:.qc.check[.qc.int 0 9;{x<10}]
.t.t["check: the default-config form returns the result dict (int 0 9 exhausts at 10)"; (r`ok) and (10=r`n) and `exhausted=r`stop]
tb:.qc.checks `a`b!((.qc.int 0 9;{x<10});(.qc.int 0 9;{x<5}))
.t.t["checks: one row per property, ok says which failed"; (`a`b~tb`name) and 10b~tb`ok]
/ val: an arbitrary value shrinks like anything else
r:.qc.chk[q;.qc.val;{not 98h=type x}]
.t.t["val: a table-typed failure shrinks to a one-column, one-row table"; (98h=type r[`x]`x) and (1=count r[`x]`x) and (1=count cols r[`x]`x) and 0<r`shrinks]
/ configuration keys: tries, disc, rows, and the report at v 2 and for a stale replay
r:.qc.chk[q,enlist[`tries]!enlist 1;.qc.such[{x>8}] .qc.int 0 9;{1b}]
.t.t["cfg tries: one retry makes such discard often"; 0<(r`disc)`discard]
r:.qc.chk[q,enlist[`disc]!enlist 1;.qc.int 0 9;{if[x>2; .qc.discard[]]; 1b}]
.t.t["cfg disc: one discard per test stops the run short of its budget"; (0<(r`disc)`discard) and (r`n)<100]
r:.qc.chk[q;.qc.tabr[30 30] enlist[`a]!enlist .qc.int 0 9;{0b}]
.qc.cf[`rows]:5; lines:.qc.report r; .qc.cf[`rows]:20                                    / (report reads the run's config, cf; after the run it is the defaults again)
.qc.cf[`rerun]:0b; lines0:.qc.report r; .qc.cf[`rerun]:1b
.t.t["cfg rerun 0b leaves the rerun line out of the report, and 1b keeps it"; (not any lines0 like "rerun: *") and 1=sum .qc.report[r] like "rerun: *"]
.t.t["cfg rows: a 30-row table in a report shows 5 and says 25 more"; any lines like "*... 25 more rows*"]
r:.qc.chk[q;.qc.int 0 9;{if[x>3; '"boom"]; 1b}]
.qc.cf[`v]:2; lines:.qc.report r; .qc.cf[`v]:0
.t.t["report at v 2 carries the backtrace of an erroring property"; (10h=type r`bt) and any lines like "*boom*"]
r[`stale]:1b
.t.t["report: a stale replay says so"; any (.qc.report r) like "stale:*"]
/ one behavioural assertion each for the generators that had only a registry row
.t.t["chrc: only the alphabet"; all (.qc.draw 200#enlist .qc.chrc "abc") in "abc"]
s:.qc.draw 100#enlist .qc.strc["ab";2 3]
.t.t["strc: lengths in range, chars from the alphabet"; (all (count each s) within 2 3) and all raze[s] in "ab"]
.t.t["spc: the specials appear among the draws"; any (.qc.draw 300#enlist .qc.spc[(0N;0W)] .qc.int 0 9) in (0N;0W)]
.t.t["lin: the range widens with size"; (0 50~.qc.lin[0;100] 50) and 0 100~.qc.lin[0;100] 100]
.t.t["rerun: an empty choice vector is spelled out"; (.qc.rerun `long$()) like "*`long$()]"]
.t.t["gidf: never null"; all not null .qc.draw 50#enlist .qc.gidf]
