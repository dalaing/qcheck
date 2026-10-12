/ M4 type zoo tests. loaded by t/run.q
system"S 5"
cs:"bgxhijefcspmdznuvt"
/ every .qc.t c value has type c
.t.t["t: every generator yields its own atom type"; all {[c] all (neg .Q.t?c)=type each .qc.draw 60#enlist .qc.t c} each cs]
/ origins: minimal value is c$0 (chr "a", sym `, guid 0Ng)
org:{$[x="c"; "a"; x="s"; `; x="g"; 0Ng; x$0]}
.t.t["t: the minimal value of each type is its origin"; all {[c] org[c]~.qc.minimal .qc.t c} each cs]
/ nulls and infinities appear, in both directions
hasnull:{[c] any null .qc.draw 400#enlist .qc.t c}
inf:{$[x in "efz"; x$0w; x$0W]}                                   / float-based types (e f z): "f"$0W is the finite 9.2e18, not 0w
hasinf:{[c] v:.qc.draw 1000#enlist .qc.t c; (any v=inf c) and any v=neg inf c}
.t.t["t: nulls appear for every nullable type"; all hasnull each "ghijefspmdznuvt"]
.t.t["t: infinities appear both ways for numeric and temporal types"; all hasinf each "hijefpmdznuvt"]
/ shrinking reaches the origin from wherever the failure was found
.t.t["t: {null x} shrinks to the origin for numeric and temporal types"; all {[c] (c$0)~(.qc.chk[q;.qc.t c;{null x}])[`x]`x} each "hijefpmdznuvt"]
.t.t["t: symbols shrink to `a, chars to \"a\""; ((`a)~(.qc.chk[q;.qc.t"s";{x=`}])[`x]`x) and ("a"~(.qc.chk[q;.qc.t"c";{x="b"}])[`x]`x)]
/ the finite zoo (M10): no null, no infinity, same origin as t (but for s and g, whose origin in t is a null)
.t.t["tf: no nulls and no infinities for any type"; all {[c] v:.qc.draw 400#enlist .qc.tf c; (not any null v) and not any (v=inf c) or v=neg inf c} each "hijefpmdznuvt"]
.t.t["tf: guids are never null, booleans and chars as before"; (not any null .qc.draw 200#enlist .qc.tf "g") and all (type each .qc.draw each .qc.tf "bcs") in -1 -10 -11h]
.t.t["tf: the minimal value of each type is its origin, as t's (s: `a, there is no empty symbol; g: the guid that ends in 1, there is no null guid)"; all {[c] $[c="s"; `a; c="g"; "G"$"00000000-0000-0000-0000-000000000001"; org c]~.qc.minimal .qc.tf c} each cs]
.t.t["gidf: its minimal value is not null, so a shrink never heads for a null"; not null .qc.minimal .qc.gidf]
.t.t["tf: no space in a char, no empty symbol; t keeps them"; (not any null .qc.draw 500#enlist .qc.tf "c") and (not any null .qc.draw 500#enlist .qc.tf "s") and any null .qc.draw 500#enlist .qc.t "s"]
.t.t["t still reaches the infinities of h i j (one short in tf)"; all {[c] v:.qc.draw 2000#enlist .qc.t c; (any v=inf c) and any v=neg inf c} each "hij"]
/ time in a window (M10, A26)
.t.t["ts: in the window, the start simplest, dates accepted as bounds"; (all (.qc.draw 200#enlist .qc.ts[2024.01.02D09:30;2024.01.02D16:00]) within 2024.01.02D09:30 2024.01.02D16:00) and 2024.01.02D00:00~.qc.minimal .qc.ts[2024.01.02;2024.01.03]]
.t.t["dates: in the range, the first simplest, a bad range refused"; (all (.qc.draw 200#enlist .qc.dates[2024.01.01;2024.12.31]) within 2024.01.01 2024.12.31) and (2024.01.01~.qc.minimal .qc.dates[2024.01.01;2024.12.31]) and (@[.qc.draw;.qc.dates[2024.12.31;2024.01.01];{x}]) like "qc: range*"]
.t.t["ts: a planted xbar bug shrinks to four timestamps in one minute from the open"; (4=count v) and (1=count distinct 0D00:01 xbar v) and 2024.01.02D09:30=first v:(.qc.chk[q;.qc.atr[`s] .qc.lst[0 20] .qc.ts[2024.01.02D09:30;2024.01.02D16:00];{not any 3<count each group 0D00:01 xbar x}])[`x]`x]
/ arbitrary values (M10, A27)
.t.sz 30
V:{.qc.draw x} each 300#enlist .qc.val
kinds:{$[99h=type x; $[98h=type key x; `ktab; `dict]; 98h=type x; `tab; 0h=type x; `list; type[x] within 1 19h; `vec; `atom]}
.t.t["val: atoms, vectors, lists, dicts and tables all appear at size 30"; all `atom`vec`list`dict`tab in distinct kinds each V]
.t.t["val: -9!-8! round-trips every drawn value"; all {x~-9!-8!x} each V]
.t.sz 100
/ floats
.t.t["flt: within range"; all within[;0 1] .qc.draw 300#enlist .qc.flt 0 1]
.t.t["flt: negative range within range"; all within[;-5 -2] .qc.draw 100#enlist .qc.flt -5 -2]
.t.t["flt: origin is 0 when inside, the nearest bound otherwise"; (0f~.qc.minimal .qc.flt -10 10) and (2f~.qc.minimal .qc.flt 2 5) and -3f~.qc.minimal .qc.flt -9 -3]
.t.t["flt: x>=0 shrinks to -1 (integers first)"; -1f~(.qc.chk[q;.qc.flt -10 10;{x>=0}])[`x]`x]
.t.t["flt: x<100 shrinks to 100"; 100f~(.qc.chk[q;.qc.flt 0 1000;{x<100}])[`x]`x]
.t.t["flt: x<0.5 shrinks to 1 (an integer before a half)"; 1f~(.qc.chk[q;.qc.flt 0 1;{x<0.5}])[`x]`x]
.t.t["flt: within 0.25 0.75 shrinks to 0.5"; 0.5~(.qc.chk[q;.qc.flt 0 1;{not x within 0.25 0.75}])[`x]`x]
/ a range with no whole number in it starts at the coarsest grid that has a point in it; one narrower than every grid is lo plus a fraction of its width
.t.t["flt: a range with no whole number in it draws within it, and its minimal value is on the coarsest grid that fits"; (all within[;0.2 0.8] .qc.draw 300#enlist .qc.flt 0.2 0.8) and (0.5~.qc.minimal .qc.flt 0.2 0.8) and (-0.5~.qc.minimal .qc.flt -0.8 -0.2) and 0.375~.qc.minimal .qc.flt 0.26 0.49]
.t.t["flt: a range with no whole number in it can be checked, and shrinks to the coarsest point that fails"; ((.qc.chk[q;.qc.flt 0.2 0.8;{1b}])`ok) and 0.75~(.qc.chk[q;.qc.flt 0.2 0.8;{x<0.6}])[`x]`x]
.t.t["flt: a range of one value, and one narrower than every grid, draw within it, lo simplest"; (all 0.3=.qc.draw 20#enlist .qc.flt 0.3 0.3) and (0.3~.qc.minimal .qc.flt 0.3 0.3) and (all within[;1e-20 2e-20] .qc.draw 300#enlist .qc.flt 1e-20 2e-20) and 1e-20~.qc.minimal .qc.flt 1e-20 2e-20]
.t.t["flt: simple fractions are common (k<=2 alone puts 3/53 of values on quarters; observed ~9%, uniform floats ~0)"; 0.05<avg {0=(x*4) mod 1} .qc.draw 400#enlist .qc.flt 0 1]   / exact test: a multiple of 1/4 times 4 is whole (pitfall 23)
.t.t["dbl: any finite double, large magnitudes reachable"; (all not null v) and 1e100<max abs v:.qc.draw 400#enlist .qc.dbl]
.t.t["t f: x<1e308 shrinks to 0w (no finite double that large), {not null x} to 0n"; (0w~(.qc.chk[q;.qc.t"f";{x<1e308}])[`x]`x) and null (.qc.chk[q;.qc.t"f";{not null x}])[`x]`x]
/ chars, strings, symbols
.t.t["chr: from the alphabet, origin a"; (all (.qc.draw 100#enlist .qc.chr) in .qc.AZ) and "a"~.qc.minimal .qc.chr]
.t.t["str: typed even when empty"; (10h=type .qc.draw .qc.str) and (""~.qc.minimal .qc.str) and 10h=type .qc.minimal .qc.str]
.t.t["strc: alphabet and length range"; all {(3=count x) and all x in "xy"} each .qc.draw 50#enlist .qc.strc["xy";3 3]]
sy:.qc.draw 300#enlist .qc.sym                                     / (sv is a keyword)
.t.t["sym: bounded alphabet, null symbol simplest"; (all 3>=count each string sy) and (all (raze string sy) in "abcd") and (`)~.qc.minimal .qc.sym]
.t.t["symc: custom alphabet, a one-char alphabet arrives as an atom"; all (.qc.draw 50#enlist .qc.symc["z";1 1]) in enlist `z]
.t.t["C16 elem/one/freq accept a single item as an atom"; (7~.qc.draw .qc.elem 7) and (3~.qc.draw .qc.one 3) and 4~.qc.draw .qc.freq[1] 4]
/ typed vectors
.t.t["vec: typed for every type char"; all {[c] (.Q.t?c)=type .qc.draw .qc.vec[1 5] c} each cs]
.t.sz 0
.t.t["vec: typed when empty"; all {[c] (.Q.t?c)=type .qc.draw .qc.vec[0 0] c} each cs]
.t.sz 100
/ tables
cg:`a`b`c!(.qc.int 0 9;.qc.sym;.qc.list .qc.int 0 9)
tb:.qc.draw .qc.tab cg
.t.t["tab: a table with the given columns, rows within size"; (98h=type tb) and (`a`b`c~cols tb) and (count tb) within 0 100]
.t.t["tab: typed simple columns, general nested column"; (7h=type tb`a) and (11h=type tb`b) and 0h=type tb`c]
.t.t["tabr: exact row count"; 3=count .qc.draw .qc.tabr[3 3] cg]
.t.t["tab: empty table still has its columns"; (`a`b`c~cols e) and 0=count e:.qc.minimal .qc.tab cg]
.t.t["tab: an empty table has typed columns where a minimal draw can say what they are (found by the mdp example)"; (7h=type e`a) and (11h=type e`b) and 0h=type e`c]
.t.t["tab: typed empties for constrained columns too; a dep sees the minimal row (here its generator fails, so its column stays general)"; (12h=type e2`t) and (11h=type e2`k) and 0h=type (e2:.qc.minimal .qc.tabr[0 0] `t`k`a!(.qc.mono[.qc.ts[2024.01.01;2024.01.02];.qc.int 0 9];.qc.uniq .qc.elem `a`b;.qc.dep {[r] .qc.int (r`t;9)}))`a]
.t.t["tab: a dep whose generator works on the minimal row is typed"; 9h=type (.qc.minimal .qc.tabr[0 0] `bid`ask!(.qc.flt 1 100;.qc.dep {[r] .qc.flt (r`bid;100)}))`ask]
.t.t["tab: probing leaves the example untouched (the choices are those of the table alone)"; 1=count .qc.C]
.t.t["ktab: keyed table"; (99h=type k) and (enlist[`a]~keys k) and 2=count k:.qc.draw .qc.ktab[`a;2 2] cg]
r:.qc.chk[q;.qc.tab `a`b!(.qc.int 0 9;.qc.int 0 9);{3>count x}]
.t.t["tab: shrinks by rows to three zero rows"; (3=count r[`x]`x) and all 0=raze value flip r[`x]`x]
/ C7 and C11 over the zoo: every generator records a choice at size 0, and replays across sizes
gs:(value .qc.t),(.qc.flt 0 1;.qc.dbl;.qc.chr;.qc.str;.qc.sym;.qc.vec[0 3]"j";.qc.tab cg;.qc.ktab[`a;0 3] cg;.qc.gid)
.t.sz 0
.t.t["C7 every zoo generator records a choice at size 0"; all {.qc.minimal x; 0<count .qc.C} each gs]
system"S 3"
.t.t["C11 every zoo generator replays across sizes"; all {[g] .t.sz 5; v:.qc.draw g; c:.qc.C`v; .t.sz 100; v~.qc.replay[c] g} each gs]
.t.sz 100
.t.t["canary: zoo defaults reject an extra argument"; all {(@[x;1;{x}]) like "qc: too many*"} each (.qc.str;.qc.sym;.qc.chr;.qc.dbl;.qc.gid)]
