/ pinned by the intensive review after M6. loaded by t/run.q
system"S 7"
.t.t["flt: a huge range does not error and stays finite"; all {(not null x) and abs[x]<1e19} .qc.draw 50#enlist .qc.flt -1e300 1e300]
.t.t["elem/one of nothing say so"; ("qc: elem of nothing"~@[.qc.draw;.qc.elem ();{x}]) and "qc: one of nothing"~@[.qc.draw;.qc.one ();{x}]]
.t.t["freq: one weight per alternative"; (@[.qc.draw;.qc.freq[1 2] (1;2;3);{x}]) like "qc: freq*"]
.t.t["sm: a plain dict is rejected as cmds, not a type error"; (@[.qc.draw;.qc.sm[enlist[`m0]!enlist 0] `pre`run!(1;2);{x}]) like "qc: cmds must be a table*not a dict"]
F:0
cm:([cmd:enlist `boom] run:enlist {[i] '"kaboom"})
r:.qc.chk[q;.qc.sm[`m0`fini!(0;{F+:1})] cm;::]
.t.t["sm: fini runs even when the system errors"; (`falsified=r`why) and F>0]
e:@[{.qc.eq[`a`b!1 2;`b`a!2 1]};::;{x}]
.t.t["eq: the order row is a well-formed one-row table"; ("qc.eq"~e) and (1=count last .qc.N) and (`path`why`a`b~cols last .qc.N) and `order~first exec why from last .qc.N]
e:.[.qc.eq;((0#`)!`long$();()!());{x}]
.t.t["eq: two empty dicts whose keys differ in type get a keytype row, not order"; ("qc.eq"~e) and `keytype~first (last .qc.N)`why]
.t.t["report: the ok line has no suffix for a plain budget stop"; (first .qc.report .qc.chk[q;.qc.int 0 999;{1b}]) like "ok 100 tests (seed *"]
.t.t["report: the ok line names an exhausted space"; (first .qc.report .qc.chk[q;.qc.bool;{1b}]) like "ok 2 tests, exhausted (seed *"]
/ round 2: the library never applies a value it has not checked is callable (an integer would be an IPC handle)
.t.t["C20 sized, such, rec, sm hooks and columns, the property and checks refuse non-functions";
  all ((@[.qc.draw;.qc.sized 5;{x}]) like "qc: sized*"; (@[.qc.draw;.qc.such[5] .qc.int 0 9;{x}]) like "qc: such*";
       (@[.qc.draw;.qc.rec[2 2;0;5];{x}]) like "qc: rec*"; (@[.qc.draw;.qc.sm[`m0`init!(0;5)] ([cmd:enlist `a] run:enlist {[a] ::});{x}]) like "qc: init*";
       (@[.qc.draw;.qc.sm[enlist[`m0]!enlist 0] ([cmd:enlist `a] run:enlist 5);{x}]) like "qc: cmds*"; (@[.qc.chk[q;.qc.int 0 9];5;{x}]) like "qc: the property*";
       (@[.qc.recheck[.qc.int 0 9;5];enlist 1;{x}]) like "qc: the property*"; (@[.qc.chks[q];5;{x}]) like "qc: checks*"; (@[.qc.draw;.qc.tab 5;{x}]) like "qc: tab*")]
.t.t["C20 a property whose arity does not match a list generator is refused up front"; (@[.qc.chk[q;(.qc.int 0 9;.qc.int 0 9)];{x};{x}]) like "qc: the property takes 1 arguments*"]
/ round 3: arithmetic on bounds survives the full long range
.t.t["zig and the key do not overflow at 0W"; (.qc.less[.qc.skey[enlist 5;enlist 0];.qc.skey[enlist 0W;enlist 0]]) and not null first .qc.zig 0W]
r:.qc.chk[q;.qc.int -0W 0W;{x<1000000}]
.t.t["binary search shrinks a full-range long to the boundary"; 1000000~r[`x]`x]
r:.qc.chk[q;.qc.t"j";{$[null x; 1b; x<1000000]}]
.t.t["full-domain longs shrink to the boundary too"; 1000000~r[`x]`x]
.t.sz 500
.t.t["rec at an oversized budget fails loudly, before counting"; (@[.qc.draw;.qc.rec[2 2;0;{x}];{x}]) like "qc: rec:*"]
.t.sz 100
/ round 7
.t.t["freq: negative weights are refused"; (@[.qc.draw;.qc.freq[1 -1] (1;2);{x}]) like "qc: freq*"]
/ the audit (AUDIT.md, C14 and pitfall 28): malformed input is a usage error, never a bare q error
.t.t["C14 keyed tables are refused where a dict is wanted: cfg, tab, checks, sm hooks";
  all ((@[.qc.chk[;.qc.int 0 9;{1b}];([k:enlist `n]v:enlist 5);{x}]) like "qc: cfg*"; (@[.qc.draw;.qc.tab ([k:1 2]v:3 4);{x}]) like "qc: tab*";
       (@[.qc.chks[q];([a:enlist `p]b:enlist 1);{x}]) like "qc: checks*"; (@[.qc.draw;.qc.sm[([k:enlist `m0]v:enlist 0)] ([cmd:enlist `a] run:enlist {[a] ::});{x}]) like "qc: sm*")]   / (a keyed-table literal needs vector columns; with atoms the literal itself is a rank error)
.t.t["C14 unknown config keys and unknown sm hooks are named"; ((@[.qc.chk[;.qc.int 0 9;{1b}];q,enlist[`seeed]!enlist 5;{x}]) like "qc: cfg: unknown key seeed") and (@[.qc.draw;.qc.sm[`m0`fnii!(0;{})] ([cmd:enlist `a] run:enlist {[a] ::});{x}]) like "qc: sm: unknown hook fnii"]
.t.t["C14 labels must be symbols, in classify, cover and collect's path"; ((.qc.chk[q;.qc.int 0 9;{.qc.classify["big";x>5]; 1b}])[`err] like "qc: a label*") and (.qc.chk[q;.qc.int 0 9;{.qc.cover[`a`b;90;1b]; 1b}])[`err] like "qc: a label*"]
.t.t["C14 cover needs a numeric percentage"; (.qc.chk[q;.qc.int 0 9;{.qc.cover[`a;"90";1b]; 1b}])[`err] like "qc: cover*"]
.t.t["C14 freq: all-zero or non-numeric weights are refused"; ((@[.qc.draw;.qc.freq[0 0] (1;2);{x}]) like "qc: freq*") and (@[.qc.draw;.qc.freq[`a`b] (1;2);{x}]) like "qc: freq*"]
.t.t["C14 one, elem and freq of a dict say so"; all ((@[.qc.draw;.qc.one `a`b!(1;2);{x}]) like "qc: one*"; (@[.qc.draw;.qc.elem `a`b!1 2;{x}]) like "qc: elem*"; (@[.qc.draw;.qc.freq[1 1] `a`b!(1;2);{x}]) like "qc: freq*")]
.t.t["C20 checks entries must be (gen;prop) pairs"; ((@[.qc.chks[q];enlist[`p]!enlist {x};{x}]) like "qc: checks*") and (@[.qc.chks[q];enlist[`p]!enlist .qc.int 0 9;{x}]) like "qc: checks*"]
.t.t["C20 :: is not a function: sized, such and sm hooks refuse it"; ((@[.qc.draw;.qc.sized (::);{x}]) like "qc: sized*") and ((@[.qc.draw;.qc.such[::] .qc.int 0 9;{x}]) like "qc: such*") and (@[.qc.draw;.qc.sm[`m0`init!(0;::)] ([cmd:enlist `a] run:enlist {[a] ::});{x}]) like "qc: init*"]
.t.t["C20 the :: property is still the 'generation must not fail' property"; (.qc.chk[q;.qc.int 0 9;::])`ok]
/ AUDIT2 (C14): phase-2 boundaries say qc: too
.t.t["C14 ts and dates refuse non-temporal bounds; btab refuses a non-char type"; ((@[.qc.draw;.qc.ts[`a;`b];{x}]) like "qc: ts*") and ((@[.qc.draw;.qc.dates[1;2];{x}]) like "qc: dates*") and (@[.qc.draw;.qc.btab[1 1] enlist[`a]!enlist (5;0 9);{x}]) like "qc: btab*"]
.t.t["C14 mono refuses a negative delta, atr u makes the value distinct"; ((@[.qc.draw;.qc.tabr[3 3] enlist[`t]!enlist .qc.mono[.qc.int 0 9;.qc.int -9 -1];{x}]) like "qc: mono*") and (`u=attr v) and v~distinct v:.qc.draw .qc.atr[`u] .qc.lst[10 10] .qc.int 0 1]
