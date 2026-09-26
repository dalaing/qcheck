/ pinned by the intensive review after M6. loaded by t/run.q
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
.t.t["flt: a huge range does not error and stays finite"; all {(not null x) and abs[x]<1e19} .qc.draw 50#enlist .qc.flt -1e300 1e300]
.t.t["elem/one of nothing say so"; ("qc: elem of nothing"~@[.qc.draw;.qc.elem ();{x}]) and "qc: one of nothing"~@[.qc.draw;.qc.one ();{x}]]
.t.t["freq: one weight per alternative"; (@[.qc.draw;.qc.freq[1 2] (1;2;3);{x}]) like "qc: freq*"]
.t.t["sm: a plain dict is rejected as cmds, not a type error"; "qc: cmds"~@[.qc.draw;.qc.sm[enlist[`m0]!enlist 0] `pre`run!(1;2);{x}]]
F:0
cm:([cmd:enlist `boom] run:enlist {[i] '"kaboom"})
r:.qc.chk[q;.qc.sm[`m0`fini!(0;{F+:1})] cm;::]
.t.t["sm: fini runs even when the system errors"; (`falsified=r`why) and F>0]
e:@[{.qc.eq[`a`b!1 2;`b`a!2 1]};::;{x}]
.t.t["eq: the order row is a well-formed one-row table"; ("qc.eq"~e) and (1=count last .qc.N) and (`path`why`a`b~cols last .qc.N) and `order~first exec why from last .qc.N]
.t.t["report: the ok line has no suffix for a plain budget stop"; (first .qc.report .qc.chk[q;.qc.int 0 999;{1b}]) like "ok 100 tests (seed *"]
.t.t["report: the ok line names an exhausted space"; (first .qc.report .qc.chk[q;.qc.bool;{1b}]) like "ok 2 tests, exhausted (seed *"]
.qc.cfg[`v]:1
