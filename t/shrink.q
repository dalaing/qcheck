/ M2 shrinker tests. loaded by t/run.q
ints:.qc.list .qc.int 0 99
r:.qc.chk[q;ints;{x~asc x}]
.t.t["sorted: minimal counterexample is 1 0"; (1 0~r[`x]`x) and (r`shrinks)>0]
.t.t["shrink history is a table with one row per accepted shrink"; (98h=type r`hist) and (count r`hist)=r`shrinks]
.t.t["attempts are counted and bounded"; (r[`attempts]>=r`shrinks) and r[`attempts]<=2000]
.t.t["reported choices replay to the shrunk value"; (1 0)~.qc.replay[r`choices] ints]
.t.t["recheck of the shrunk choices reproduces it"; (r[`x]~(.qc.recheck[ints;{x~asc x};r`choices])`x)]
.t.t["reverse: minimal is 0 1"; 0 1~(.qc.chk[q;ints;{x~reverse x}])[`x]`x]
.t.t["distinct: minimal is 0 0"; 0 0~(.qc.chk[q;ints;{x~distinct x}])[`x]`x]
.t.t["count: minimal is five zeros"; (5#0)~(.qc.chk[q;ints;{5>count x}])[`x]`x]
.t.t["sum > 100: minimal is 2 99 (redistribute pass)"; 2 99~(.qc.chk[q;ints;{100>=sum x}])[`x]`x]
.t.t["adjacent equal: minimal is 0 0"; 0 0~(.qc.chk[q;ints;{not any (=)':[x]}])[`x]`x]
.t.t["single int: minimal is the boundary"; 51~(.qc.chk[q;.qc.int 0 99;{x<=50}])[`x]`x]
.t.t["negative int shrinks toward zero from below"; -1~(.qc.chk[q;.qc.int -99 99;{x>=0}])[`x]`x]
.t.t["two ints: lexicographic minimum"; 0 1~value (.qc.chk[q;(.qc.int 0 9;.qc.int 0 9);{x>=y}])`x]
/ nested and recursive structures
ll:.qc.list .qc.list .qc.int 0 9
r:.qc.chk[q;ll;{6>sum count each x}]
.t.t["nested lists: total of six elements, minimal shape"; (6=sum count each r[`x]`x) and all 0=raze r[`x]`x]
tree:.qc.rec[2 2;.qc.int 0 9;{(x 0;x 1)}]
\l spikes/bench.q                                                                 / .b.depth and .b.nodes, shared with t/bench.q
r:.qc.chk[q;tree;{.b.depth[x]<3}]
.t.t["tree: depth 3 with exactly 3 internal nodes, all leaves 0"; (3=.b.depth r[`x]`x) and (3=.b.nodes r[`x]`x) and all 0=raze r[`x]`x]
r:.qc.chk[q;tree;{.b.nodes[x]<4}]
.t.t["tree: 4 .b.nodes minimal"; 4=.b.nodes r[`x]`x]
rose:.qc.rec[0 4;.qc.int 0 9;{(`n;x)}]
r:.qc.chk[q;rose;{$[0h=type x; 3>count x 1; 1b]}]
.t.t["rose: a node with three children, all leaves 0"; (3=count r[`x][`x;1]) and all 0=raze r[`x][`x;1]]
/ interactive draws shrink with everything else
r:.qc.chk[q;::;{n:.qc.draw .qc.int 0 99; .qc.note n; n<10}]
.t.t["interactive draws shrink: choices are 10, note follows"; (enlist[10]~r`choices) and (enlist[10]~r`notes)]
/ the same-error rule
two:{$[x>50; '"type"; x<10]}
r:.qc.chk[q,`same`seed!(1b;11);.qc.int 0 999;two]             / a sampled range (0 99 would be enumerated and hit the false region first)
.t.t["same=1b keeps the original error: type at 51"; ("type"~r`err) and 51~r[`x]`x]
r:.qc.chk[q,`same`seed!(0b;11);.qc.int 0 999;two]
.t.t["same=0b may cross into another failure: false at 10"; ("false"~r`err) and 10~r[`x]`x]
/ budgets
r0:.qc.chk[q,enlist[`shrinks]!enlist 0;ints;{x~asc x}]
.t.t["shrinks=0 disables shrinking"; (0=r0`shrinks) and (0=r0`attempts) and 0=count r0`hist]
r5:.qc.chk[q,enlist[`shrinks]!enlist 5;ints;{x~asc x}]
.t.t["shrinks=5 bounds attempts"; r5[`attempts]<=5]
/ failures in the generator shrink too
r:.qc.chk[q;{[d] n:.qc.draw .qc.int 0 99; $[n>20; '"gen boom"; n]};{1b}]
.t.t["generator error shrinks to the boundary"; (`error=r`why) and 21~first r`choices]
/ discards inside the failing example are removed
r:.qc.chk[q;.qc.list .qc.such[{x>0}] .qc.int -9 9;{x~asc x}]
.t.t["filtered elements: minimal is 2 1"; 2 1~r[`x]`x]
/ the failure database
d:.t.tmp "qcdb"; qd:q,`db`name!(d;`t1)
r1:.qc.chk[qd;ints;{x~asc x}]
.t.t["db: the shrunk choices are saved"; (r1`choices)~get ` sv d,`t1]
r2:.qc.chk[qd,enlist[`seed]!enlist 99;ints;{x~asc x}]
.t.t["db: a saved failure is replayed before generation"; (0=r2`n) and r2[`x]~r1`x]
r3:.qc.chk[qd;ints;{1b}]
.t.t["db: an entry that no longer fails is removed"; (r3`ok) and 0=count key ` sv d,`t1]
/ a value below its origin is tried above it: 1 is simpler than -1, and the binary search makes no attempt at distance 1
.t.t["a negative value shrinks to the positive one at the same distance where that still fails"; all {[s] 0 1~(.qc.chk[q,enlist[`seed]!enlist s;.qc.list .qc.int -99 99;{x~reverse x}])[`x]`x} each "i"$1+til 20]
.t.t["and stays negative where the positive one passes"; all {[s] -5~(.qc.chk[q,enlist[`seed]!enlist s;.qc.int -99 99;{x>-5}])[`x]`x} each "i"$1+til 20]
.t.rm d
