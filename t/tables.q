/ M7: tables with constrained columns (mono uniq dep), attributes (atr) and schemas. loaded by t/run.q
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
system"S 7"
D:{[g;n] {.qc.draw x} each n#enlist g}
/ mono: sorted by construction, in every example and every shrink candidate (A18)
mt:.qc.tab `t`v!(.qc.mono[.qc.int 0 9;.qc.int 0 9];.qc.int 0 9)
.t.t["mono: every drawn table is sorted on the column"; all {x[`t]~asc x`t} each D[mt;100]]
bad:0
r:.qc.chk[q;mt;{if[not x[`t]~asc x`t; bad+:1]; $[1<count x; 9>max 1_deltas x`t; 1b]}]
.t.t["mono: a planted gap bug shrinks to two rows nine apart, and no candidate was ever unsorted"; (2=count r[`x]`x) and (9=last deltas r[`x][`x;`t]) and 0=bad]
.t.t["mono: the base draws the first row and the deltas the rest"; 5 6 7~(.qc.draw .qc.tabr[3 3] enlist[`t]!enlist .qc.mono[.qc.int 5 5;.qc.int 1 1])`t]
.t.t["mono outside a table is its base"; 0~.qc.minimal .qc.mono[.qc.int 0 9;.qc.int 1 9]]
tt:.qc.draw .qc.tabr[3 3] `a`t!(.qc.mono[.qc.int 0 9;.qc.int 0 9];.qc.mono[.qc.ts[2024.01.01;2024.01.02];.qc.int 0 100])
.t.t["mono: two columns of different types in one table (AUDIT2: the state was a typed dict)"; (7h=type tt`a) and (12h=type tt`t) and (tt[`a]~asc tt`a) and tt[`t]~asc tt`t]
/ uniq: distinct three ways (A19)
ue:.qc.tabr[0 10] `k`v!(.qc.uniq .qc.elem `a`b`c;.qc.int 0 9)
ui:.qc.tabr[0 10] `k`v!(.qc.uniq .qc.int 0 3;.qc.int 0 9)
uo:.qc.tabr[0 10] `k`v!(.qc.uniq .qc.int 0 1000000;.qc.int 0 9)
.t.t["uniq over an elem: distinct, rows capped by the set (3)"; all {(x[`k]~distinct x`k) and 3>=count x} each D[ue;100]]
.t.t["uniq over a small int range: distinct, rows capped by the range (4)"; all {(x[`k]~distinct x`k) and 4>=count x} each D[ui;100]]
.t.t["uniq over an open generator: distinct and not capped"; (all {x[`k]~distinct x`k} each tb) and 4<max count each tb:D[uo;100]]
.t.t["uniq over a generator that cannot vary discards when the tries run out"; "qc.discard"~@[.qc.draw;.qc.tabr[2 2] enlist[`k]!enlist .qc.uniq .qc.const 7;{x}]]
r:.qc.chk[q;ui;{20>sum x`v}]
.t.t["uniq: a planted bug shrinks to three rows with distinct keys summing to 20"; (3=count r[`x]`x) and (20<=sum r[`x][`x;`v]) and 3=count distinct r[`x][`x;`k]]
.t.t["uniq outside a table is its generator"; 0~.qc.minimal .qc.uniq .qc.int 0 9]
ud:.qc.draw .qc.tabr[2 2] enlist[`k]!enlist .qc.uniq .qc.one (.qc.const `a`b!1 2;.qc.const (enlist `c)!enlist 3)
.t.t["uniq over a generator that draws dicts of different shapes (AUDIT2: the used set collapsed to a table)"; (2=count ud) and 2=count distinct ud`k]
/ dep: sees the row so far, in column order
dpt:.qc.tab `bid`ask!(.qc.int 0 9;.qc.dep {[r] .qc.int (r`bid;9)})
.t.t["dep: ask >= bid in every row of 100 tables"; all {all x[`ask]>=x`bid} each D[dpt;100]]
.t.t["dep: a dep column sees only the columns before it"; all 0=(.qc.draw .qc.tabr[5 5] `a`b!(.qc.dep {[r] .qc.const count r};.qc.int 0 9))`a]
.t.t["dep outside a table receives an empty row"; 0~.qc.draw .qc.dep {[r] .qc.const count r}]
.t.t["dep refuses a non-function"; (@[.qc.draw;.qc.dep 5;{x}]) like "qc: dep*"]
/ atr (A23)
v:.qc.draw .qc.atr[`s] .qc.lst[1 9] .qc.int 0 9
.t.t["atr: s sorts and sets; g sets"; (`s=attr v) and (v~asc v) and `g=attr .qc.draw .qc.atr[`g] .qc.list .qc.int 0 9]
.t.t["atr: the shrunk counterexample keeps its attribute"; `s=attr (.qc.chk[q;.qc.atr[`s] .qc.lst[1 0W] .qc.int 0 9;{3>count x}])[`x]`x]
.t.t["atr: an unknown attribute is refused"; (@[.qc.draw;.qc.atr[`x] .qc.list .qc.int 0 9;{x}]) like "qc: atr*"]
/ ktab: keys distinct
.t.t["ktab: keys are distinct even from a small range, and the rows fit it"; all {((count x)=count distinct (0!x)`a) and 5>=count x} each D[.qc.ktab[`a;0 20] `a`b!(.qc.int 0 4;.qc.bool);50]]
.t.t["ktab: a key that is not a column is refused"; (@[.qc.draw;.qc.ktab[`z;1 1] (enlist `a)!enlist .qc.int 0 9;{x}]) like "qc: ktab*"]
/ schema (A21)
dom:`a`b`c
shapes:`plain`keyed`nested`sorted`parted`general`enum!(([]a:1 2;b:`x`y;c:1.5 2.5;d:2000.01.01 2000.01.02); ([k:1 2]v:`x`y); ([]a:1 2;b:(1 2;3 4 5);c:("ab";"cde"));
  ([]t:`s#1 2 3;v:1 2 3); ([]s:`p#`a`a`b;v:1 2 3;n:(1 2;3 4 5;6 7)); ([]a:1 2;b:(1;`x)); ([]s:`dom$`a`b;v:1 2))
rt:{[t] all {[t;i] tb:.qc.draw .qc.schema t; (meta $[count tb; t; 0#t])~meta tb}[t] each til 20}
.t.t["schema: meta round-trips for plain, keyed, nested, sorted, parted and enumerated shapes"; all rt each shapes `plain`keyed`nested`sorted`parted`enum]
.t.t["schema: a general column draws longs, symbols and strings"; all (type each (.qc.draw .qc.tabr[20 20] enlist[`b]!enlist .qc.colg (1;`x))`b) in -7 -11 10h]
.t.t["schema: the enumerated column stays enumerated (20h)"; all 20h={type (.qc.draw .qc.schema shapes`enum)`s} each til 10]
.t.t["schema: the minimal table is empty, typed, and without attributes (as 0# is)"; (meta 0#shapes`sorted)~meta .qc.minimal .qc.schema shapes`sorted]
.t.t["schema: keys are distinct"; all {(count x)=count distinct (0!x)`k} each D[.qc.schema shapes`keyed;30]]
.t.t["schema: a u# column is drawn distinct and keeps u# (an empty table carries none)"; all {$[count x; (`u=attr x`v) and x[`v]~distinct x`v; 1b]} each D[.qc.schema ([]v:`u#1 2 3);30]]
.t.t["schema: a column whose value is a table or a keyed table is a general column, not an enumeration (AUDIT2)"; ((first value .qc.colg ([]a:1 2;b:3 4))~.qc.one) and (first value .qc.colg ([k:1 2]v:3 4))~.qc.one]
.t.t["schema: p# with s# is refused, so is a non-table"; ((@[.qc.schema;([]a:`p#1 1 2;b:`s#1 2 3);{x}]) like "qc: schema*") and (@[.qc.schema;5;{x}]) like "qc: schema*"]
.t.t["schema: the generator carries the canary"; (@[.qc.schema shapes`plain;1;{x}]) like "qc: too many*"]
/ the as-of join (A20): two tables over one drawn symbol list; a naive join that takes the first quote instead of the last
syms:.qc.lst[1 3] .qc.symc["abc";1 1]
qt:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s;.qc.mono[.qc.int 0 9;.qc.int 0 9];g)}   / at least a row: tab's empty table has untyped columns, which aj treats differently
pair:{[d] s:.qc.draw syms; `s`q`t!(s;.qc.draw qt[s;`px;.qc.int 0 9];.qc.draw qt[s;`qty;.qc.int 0 9])}
naive:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; first r; 0N]}[q]; update px:"j"$f'[sym;time] from t}
bad:0
r:.qc.chk[q;pair;{if[not all (x[`q;`sym],x[`t;`sym]) in x`s; bad+:1]; (aj[`sym`time;x`t;x`q])~naive[x`t;x`q]}]
m:r[`x]`x
.t.t["aj: the planted bug shrinks to one symbol, two quotes at one time with two prices, one trade; every candidate referentially valid"; (2=count m`q) and (1=count m`t) and (1=count m`s) and (1=count distinct m[`q]`time) and (2=count distinct m[`q]`px) and 0=bad]
.t.t["aj: within 300 attempts"; r[`attempts]<=300]
.qc.cfg[`v]:1
