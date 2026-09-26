/ M1 core engine tests. loaded by t/run.q (which defines .t.t)
.qc.new[]
.qc.cfg[`v]:0                                                / quiet: recheck and cfg-as-number read the global
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)                          / quiet, pinned seed (C8), no failure db
/ draw is a homomorphism over data
.t.t["draw: atoms, vectors, tables, :: are constants"; (1~.qc.draw 1) and (1 2 3~.qc.draw 1 2 3) and (t~.qc.draw t:([]a:1 2)) and (::)~.qc.draw (::)]
.t.t["draw: keyed table is a constant"; kt~.qc.draw kt:([a:1 2]b:3 4)]
.t.t["draw: general list of constants is identity"; (1;"a";`b)~.qc.draw (1;"a";`b)]
d:.qc.draw `a`b!(.qc.int 0 9;(.qc.int 0 9;`k))
.t.t["draw: dict and list recursion"; (`a`b~key d) and (d[`a] within 0 9) and (`k~d[`b;1])]
.t.t["draw: const escape hatch"; f~.qc.draw .qc.const f:{x+1}]
.t.t["draw: several with k#enlist g"; 7h=type xs:.qc.draw 5#enlist .qc.int 0 9]
/ ranges and the primitive
.t.t["int: within range"; all within[;-5 5] .qc.draw 500#enlist .qc.int -5 5]
.t.t["int: range as a function of size"; all within[;0 100] .qc.draw 100#enlist .qc.int {0,x}]
.t.t["int: bad range signals"; "qc: range"~@[.qc.draw;.qc.int 5 1;{x}]]
.t.t["int: full long range does not error"; -7h=type .qc.draw .qc.int -0W 0W]
system"S 1"; a:rand 0W; system"S 1"; .qc.draw .qc.int 5 5; b:rand 0W
.t.t["int 5 5 consumes no randomness"; a=b]
.t.t["bool and bit are booleans"; (-1h=type .qc.draw .qc.bool) and (-1h=type .qc.draw .qc.bit 0.9)]
.t.t["bit 1 is always true, bit 0 always false"; (all .qc.draw 50#enlist .qc.bit 1) and not any .qc.draw 50#enlist .qc.bit 0]
/ minimal mode
.t.t["minimal: origins and empty list"; (0~.qc.minimal .qc.int -5 5) and (7~.qc.minimal .qc.int 7 9) and (()~.qc.minimal .qc.list .qc.int 0 9) and 0b~.qc.minimal .qc.bool]
.t.t["minimal: rec gives a leaf"; 0~.qc.minimal .qc.rec[2 2;0;{1+sum x}]]
/ lists
ls:.qc.draw 200#enlist .qc.lst[3 5] .qc.int 0 9
.t.t["list: lengths within range, typed when homogeneous"; (all (count each ls) within 3 5) and all 7h=type each ls]
.qc.new[]
.t.t["list: default range 0..size"; all (count each .qc.draw 30#enlist .qc.list .qc.int 0 9) within 0 100]
.qc.reset[`long$();0;0b;0b]
.t.t["list: size 0 gives empty lists"; ()~.qc.draw .qc.list .qc.int 0 9]
.qc.new[]
.t.t["list: general when elements are lists"; 0h=type .qc.draw .qc.lst[2 2] .qc.lst[1 1] .qc.int 0 9]
/ alternatives and filters
.t.t["elem: from the list"; all (.qc.draw 100#enlist .qc.elem `a`b`c) in `a`b`c]
.t.t["one: draws one alternative"; all (.qc.draw 100#enlist .qc.one (.qc.int 0 0;.qc.int 5 5)) in 0 5]
.t.t["freq: zero weight is never chosen"; all 1=.qc.draw 200#enlist .qc.freq[0 1;(0;1)]]
.t.t["such: predicate holds"; all 0<.qc.draw 100#enlist .qc.such[{x>0}] .qc.int -9 9]
.t.t["such: impossible predicate discards"; "qc.discard"~@[.qc.draw;.qc.such[{0b}] .qc.int 0 9;{x}]]
.t.t["such: rejected spans are marked discarded"; 0<sum exec x from .qc.E]
/ recursion: node function {1+sum x} on leaf 0 computes the internal node count
.qc.reset[`long$();30;0b;0b]
nb:{.qc.draw x} each 200#enlist .qc.rec[2 2;0;{1+sum x}]; nr:{.qc.draw x} each 200#enlist .qc.rec[0 4;0;{1+sum x}]; nu:{.qc.draw x} each 200#enlist .qc.recb[2 2;0;{1+sum x}]   / one example each: 200 trees in one would exceed the choice budget
.t.t["rec: binary node count <= size"; all nb<=30]
.t.t["rec: rose node count <= size"; all nr<=30]
.t.t["recb: node count <= size"; all nu<=30]
.t.t["rec: node counts vary"; 5<count distinct nb]
.t.t["rec: k=0 0 never exceeds the feasible size"; all 1>=.qc.draw 50#enlist .qc.rec[0 0;0;{1+sum x}]]
.qc.new[]
.t.t["rec: counting tables are Catalan"; 1 1 2 5 14 42f~.qc.TB[`$"2,2"][`T] til 6]
v:.qc.replay[enlist 5] .qc.rec[2 2;.qc.int 0 9;{(`n;x 0;x 1)}]        / the prefix forces a 5-node tree
.t.t["rec: children arrive as values"; (0h=type v) and (`n~v 0) and 3=count v]
/ budgets
deep:{[d] .qc.draw deep}
.t.t["depth guard: qc.toodeep"; "qc.toodeep"~@[.qc.draw;deep;{x}]]
.qc.new[]
.t.t["choice budget: qc.toolarge"; "qc.toolarge"~@[{.qc.cf[`choices]:100; r:@[.qc.draw;.qc.lst[500 500] .qc.int 0 9;{x}]; .qc.cf[`choices]:8192; r};::;{x}]]
.qc.new[]
/ check: outcomes
r:.qc.chk[q;(.qc.int -9 9;.qc.int -9 9);{(x+y)=y+x}]
.t.t["check: true property passes"; (r`ok) and (`ok=r`why) and 100=r`n]
r:.qc.chk[q;(.qc.int 0 9;.qc.int 0 9);{[a;b] a<=b}]
.t.t["check: falsified, counterexample named by parameters"; (`falsified=r`why) and (`a`b~key r`x) and r[`x;`a]>r[`x;`b]]
r:.qc.chk[q;`n`xs!(.qc.int 0 3;.qc.list .qc.int 0 9);{[xs;n] n<=count xs}]
.t.t["check: dict spec applied by parameter name"; (`falsified=r`why) and (`n`xs~key r`x) and r[`x;`n]>count r[`x;`xs]]
r:.qc.chk[q;`n`xs!(.qc.int 0 3;.qc.list .qc.int 0 9);{(x`n)>=0}]
.t.t["check: dict spec passed whole otherwise"; r`ok]
r:.qc.chk[q;::;{n:.qc.draw .qc.int 1 9; n>0}]
.t.t["check: interactive draws with a :: spec"; r`ok]
r:.qc.chk[q;.qc.int -9 9;{x<>0}]
.t.t["check: the first example is the minimal one"; (enlist[`x]!enlist 0)~r`x]
.t.t["check: it fails after zero passing tests"; 0=r`n]
r:.qc.chk[q;.qc.such[{0b}] .qc.int 0 9;{1b}]
.t.t["check: too many discards gives up"; (`gaveup=r`why) and 0<r[`disc]`discard]
r:.qc.chk[q;.qc.int 0 9;{x+`a}]
.t.t["check: property error is a failure with the error text"; (`falsified=r`why) and ("type"~r`err) and (r`bt) like "*x+`a*"]
r:.qc.chk[q;{'"boom"};{1b}]
.t.t["check: generator error is reported as error"; (`error=r`why) and "boom"~r`err]
r:.qc.chk[q;.qc.int 0 9;{x}]
.t.t["check: non-boolean result is an error"; (`falsified=r`why) and (r`err) like "qc: property returned*"]
r:.qc.chk[q;deep;{1b}]
.t.t["check: runaway recursion is a counted discard"; (`gaveup=r`why) and 0<r[`disc]`toodeep]
r:.qc.chk[q;.qc.int 0 9;{.qc.classify[`big;x>5]; .qc.note x; 1b}]
.t.t["check: labels are counted"; `big in r[`cover]`label]
.t.t["check: property may return ::"; (.qc.chk[q;.qc.int 0 9;{}])`ok]
.t.t["check: :: property means generation must not fail"; ((.qc.chk[q;.qc.int 0 9;::])`ok) and `error=(.qc.chk[q;{'"x"};::])`why]
.t.t["check: cfg as a number of tests"; 7=(.qc.chk[7;.qc.int 0 9;{1b}])`n]
/ seeds and replay
s:.qc.list .qc.int 0 99; p:{x~asc x}
a:.qc.chk[q,`seed`n!(42;50);s;p]; b:.qc.chk[q,`seed`n!(42;50);s;p]
.t.t["seed: same seed, same counterexample"; (a[`x]~b`x) and 42i=a`seed]
c:.qc.recheck[s;p;a`choices]
.t.t["recheck: replays the recorded choices exactly"; (c[`x]~a`x) and not c`stale]
.t.t["recheck: a changed generator is reported stale (fewer draws)"; (.qc.recheck[.qc.int 0 9;{1b};a`choices])`stale]
.t.t["recheck: a changed generator is reported stale (clamped value)"; (.qc.recheck[.qc.list .qc.int 0 0;{1b};a`choices])`stale]
.t.t["recheck: passing choices report ok"; (.qc.recheck[s;{1b};a`choices])`ok]
/ C9: engine state is restored at the example boundary from run-level values
e:@[.qc.draw;.qc.small {[d] '"boom"};{x}]
.t.t["C9 an error inside small leaves the size at its base"; ("boom"~e) and (100=.qc.sz) and 100=.qc.bs]
/ C10: the sources of a choice are entry points
.t.t["C10 replay reproduces the reported counterexample"; (a[`x]`x)~.qc.replay[a`choices] s]
.t.t["C10 minimal of a pair is the pair of origins"; (0;0b)~.qc.minimal (.qc.int -9 9;.qc.bool)]
.t.t["C10 entry points leave the run flag clear"; not .qc.run]
/ C7 dual: every library generator records at least one choice, even at size 0
.qc.reset[`long$();0;0b;0b]
gs:(.qc.int 0 9;.qc.bool;.qc.bit 0.5;.qc.elem `a`b;.qc.one (1;2);.qc.freq[1 1;(1;2)];.qc.such[{1b}] .qc.int 0 9;
  .qc.list .qc.int 0 9;.qc.lst[0 0] .qc.int 0 9;.qc.rec[2 2;0;{1+sum x}];.qc.recb[2 2;0;{1+sum x}];.qc.small .qc.int 0 9;.qc.sized {.qc.int 0 9})
.t.t["C7 every library generator records a choice at size 0"; all {.qc.minimal x; 0<count .qc.C} each gs]
.qc.new[]
/ C11: replay invariance — a value drawn at size 5 replays identically at size 100 from its recorded choices
system"S 3"
.t.t["C11 every library generator replays across sizes"; all {[g] .qc.reset[`long$();5;0b;0b]; v:.qc.draw g; c:.qc.C`v; .qc.new[]; v~.qc.replay[c] g} each gs]
.t.t["C11 a range that narrows with size does not (the rule is on users)"; not {[g] .qc.reset[`long$();5;0b;0b]; v:.qc.draw g; c:.qc.C`v; .qc.new[]; v~.qc.replay[c] g} .qc.int {(x div 2;x)}]
.qc.cfg[`v]:1
/ conventions (DESIGN.md 1.10)
.t.t["C1 canary: .qc.list[3 5] g signals and names .qc.lst"; (e like "qc: too many arguments*") and (e:@[{.qc.list[3 5] x};.qc.int 0 9;{x}]) like "*qc.lst*"]
.t.t["C1 canary: .qc.bool[0.9] signals and names .qc.bit"; (e like "qc: too many arguments*") and (e:@[.qc.bool;0.9;{x}]) like "*qc.bit*"]
.t.t["C1 canary: .qc.rec with four arguments signals"; (@[.qc.rec[2 2;0;{1+sum x}];1;{x}]) like "qc: too many*"]
.qc.draw .qc.int 0 9; .qc.draw .qc.int 0 9;
.t.t["C6 top-level draw is an example: one choice recorded after two draws"; 1=count .qc.C]
.qc.draw (.qc.int 0 9;.qc.int 0 9);
.t.t["C6 a top-level draw of a pair records both choices"; (2=count .qc.C) and not .qc.run]
e:@[.qc.draw;{[d] .qc.draw {[d] '"boom"}};{x}]
.t.t["C6 a draw error leaves depth 0 and the run flag clear"; ("boom"~e) and (0=.qc.dp) and not .qc.run]
.t.t["C6 and the next draw works"; -7h=type .qc.draw .qc.int 0 9]
r:.qc.chk[q;42;{x=42}]
.t.t["C7 exhausted: a constant spec runs once"; (r`ok) and 1=r`n]
r:.qc.chk[q;::;{1b}]
.t.t["C7 exhausted: a property that draws nothing runs once"; (r`ok) and 1=r`n]
r:.qc.chk[q;::;{0<.qc.draw .qc.int 1 9}]
.t.t["C7/C19 interactive draws: the space of int 1 9 is exhausted at 9"; (9=r`n) and `exhausted=r`stop]
r:.qc.chk[q;.qc.int 0 9;{1b}]
.t.t["C4 result shape: absent composites are empty, x is ::"; ((::)~r`x) and (0=count r`disc) and (0=count r`cover) and 98h=type r`cover]
/ C16: the remaining list-configuration entry points accept an atom
.t.t["C16 replay with an atom prefix, rec with an atom arity, spc with an atom special"; (7~.qc.replay[7] .qc.int 0 9) and (2=count .qc.replay[1] .qc.rec[2;0;{x}]) and 0N~.qc.replay[1 0] .qc.spc[0N;.qc.int 0 9]]
/ C17: the distribution you ship, measured on the ranges people use
system"S 2"
.t.t["C17 int 0 1000: zeros are common but not dominant (<20%)"; 0.2>avg 0=.qc.draw 1000#enlist .qc.int 0 1000]
.t.t["C17 int -1000 1000: both signs and both bounds appear"; (any v<0) and (any v>0) and (any v=1000) and any -1000=v:.qc.draw 1000#enlist .qc.int -1000 1000]
.qc.reset[`long$();30;0b;0b]
nn:{.qc.draw x} each 300#enlist .qc.rec[2 2;0;{1+sum x}]
.t.t["C17 rec at size 30: under 20% leaves, median node count >= 8"; (0.2>avg 0=nn) and 8<=med nn]
.qc.new[]
.t.t["C17 flt 0 1 hits both bounds"; (any v=0) and any 1=v:.qc.draw 1000#enlist .qc.flt 0 1]
.qc.cfg[`v]:1
