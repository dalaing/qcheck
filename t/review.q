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
/ round 2: the library never applies a value it has not checked is callable (an integer would be an IPC handle)
.t.t["C20 sized, such, rec, sm hooks and columns, the property and checks refuse non-functions";
  all ((@[.qc.draw;.qc.sized 5;{x}]) like "qc: sized*"; (@[.qc.draw;.qc.such[5] .qc.int 0 9;{x}]) like "qc: such*";
       (@[.qc.draw;.qc.rec[2 2;0;5];{x}]) like "qc: rec*"; (@[.qc.draw;.qc.sm[`m0`init!(0;5)] ([cmd:enlist `a] run:enlist {[a] ::});{x}]) like "qc: init*";
       (@[.qc.draw;.qc.sm[enlist[`m0]!enlist 0] ([cmd:enlist `a] run:enlist 5);{x}]) like "qc: cmds*"; (@[.qc.chk[q;.qc.int 0 9];5;{x}]) like "qc: the property*";
       (@[.qc.recheck[.qc.int 0 9;5];enlist 1;{x}]) like "qc: the property*"; (@[.qc.chks[q];5;{x}]) like "qc: checks*"; (@[.qc.draw;.qc.tab 5;{x}]) like "qc: tab*")]
.t.t["C20 a property whose arity does not match a list spec is refused up front"; (@[.qc.chk[q;(.qc.int 0 9;.qc.int 0 9)];{x};{x}]) like "qc: the property takes 1 arguments*"]
/ round 3: arithmetic on bounds survives the full long range
.t.t["zig and the key do not overflow at 0W"; (.qc.less[.qc.skey[enlist 5;enlist 0];.qc.skey[enlist 0W;enlist 0]]) and not null first .qc.zig 0W]
r:.qc.chk[q;.qc.int -0W 0W;{x<1000000}]
.t.t["binary search shrinks a full-range long to the boundary"; 1000000~r[`x]`x]
r:.qc.chk[q;.qc.t"j";{$[null x; 1b; x<1000000]}]
.t.t["full-domain longs shrink to the boundary too"; 1000000~r[`x]`x]
.qc.reset[`long$();500;0b;0b]
.t.t["rec at an oversized budget fails loudly, before counting"; (@[.qc.draw;.qc.rec[2 2;0;{x}];{x}]) like "qc: rec:*"]
.qc.new[]
/ round 7
.t.t["freq: negative weights are refused"; (@[.qc.draw;.qc.freq[1 -1] (1;2);{x}]) like "qc: freq*"]
.qc.cfg[`v]:1
