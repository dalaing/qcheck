/ M3 reporting tests. loaded by t/run.q
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
/ formatter
.t.t["fmt: atoms, vectors, ::, functions"; (enlist["1"]~.qc.fmt 1) and ("1 2 3"~.qc.fmt 1 2 3) and ("::"~.qc.fmt (::)) and "{x+1}"~.qc.fmt {x+1}]
.t.t["fmt: flat dict is key: value lines"; "a: 1\nb: 2 3"~.qc.fmt `a`b!(1;2 3)]
f:.qc.fmt `n`t!(3;([]a:1 2;b:`x`y))
.t.t["fmt: nested table is shown as a table, indented"; (f like "n: 3\nt:\n  a b*") and not f like "*+`a`b*"]
.t.t["fmt: long table is cut with a count"; (.qc.fmt ([]a:til 25)) like "*... 5 more rows"]
.t.t["fmt: general list of blocks is numbered"; (.qc.fmt (1;([]a:1 2))) like "0: 1\n1:\n  a*"]
.t.t["fmt: nested lists of atoms stay on one line"; ("(0;(0;0 0))"~.qc.fmt (0;(0;0 0))) and "xs: ()"~.qc.fmt enlist[`xs]!enlist ()]
.t.t["fmt: general list of atoms stays on one line"; "(1;\"a\";`b)"~.qc.fmt (1;"a";`b)]
.t.t["fmt: console width is restored"; 25 80i~system"c"]
/ diff
d:.qc.diff[1 2 3;1 0 3]
.t.t["diff: value rows with index paths"; (1=count d) and ((enlist 1)~d[0;`path]) and (`value=d[0;`why]) and (2=d[0;`a]) and 0=d[0;`b]]
.t.t["diff: equal values give an empty table"; (98h=type .qc.diff[1 2;1 2]) and 0=count .qc.diff[`a`b!1 2;`a`b!1 2]]
d:.qc.diff[1 2 3;1 2 3f]
.t.t["diff: type mismatch is one row of types"; (`type~first exec why from d) and (7h~d[0;`a]) and 9h~d[0;`b]]
d:.qc.diff[1 2 3;1 2]
.t.t["diff: count row, then no value rows for equal prefix"; (`count~exec first why from d) and (3~d[0;`a]) and 2~d[0;`b]]
d:.qc.diff[`a`b`c!1 2 3;`a`b`d!1 5 3]
.t.t["diff: dict keys missing each side and a value"; (`key`key`value~asc exec why from d) and (enlist[`b]~exec first path from d where why=`value)]
d:.qc.diff[([]a:1 2 3;b:`x`y`z);([]a:1 9 3;c:`x`y`z)]
.t.t["diff: table columns missing each side, cell path is (col;row)"; ((`a;1)~exec first path from d where why=`value) and 2=count select from d where why=`key]
.t.t["diff: strings compare as a whole"; 1=count .qc.diff["abc";"abd"]]
.t.t["diff: keyed tables compare unkeyed"; 1=count .qc.diff[([k:1 2]v:3 4);([k:1 2]v:3 5)]]
.t.t["diff: nested general lists recurse with paths"; (1 1~first exec path from .qc.diff[(1;2 3);(1;2 4)])]
.t.t["diff: functions and :: compare by match"; (0=count .qc.diff[{x};{x}]) and 1=count .qc.diff[{x};{y}]]
/ eq
.t.t["eq: equal is 1b and notes nothing"; (1b~.qc.eq[1 2;1 2]) and 0=count .qc.N]
e:@[{.qc.eq[1 2 3;1 0 3]};::;{x}]
.t.t["eq: unequal signals qc.eq and notes the diff table"; ("qc.eq"~e) and (98h=type last .qc.N) and 1=count last .qc.N]
e:@[{.qc.eq[`a`b!1 2;`b`a!2 1]};::;{x}]
.t.t["eq: reordered dict is explained as order"; ("qc.eq"~e) and `order~first exec why from last .qc.N]
r:.qc.chk[q;.qc.list .qc.int 0 100;{.qc.eq[x;asc x]}]
.t.t["eq inside a property: err is qc.eq, note is the two-row diff of 1 0"; ("qc.eq"~r`err) and (1 0~r[`x]`x) and (2=count first r`notes) and (enlist[0];enlist 1)~exec path from first r`notes]
/ the §1.6 mock, for real
s:.qc.report r
.t.t["report: header line"; ((s 0) like "FAIL falsified after *") and (s 0) like "* attempts, seed 7)"]
.t.t["report: counterexample, error, diff table, rerun line"; ("x: 1 0"~s 1) and ("qc.eq"~s 2) and ((s 3) like "path why*") and ((last s) like "rerun: .qc.again*") and (last s) like "*1 1 1 0 0*"]   / [] are classes in like
.t.t["report: a false property prints no error line"; not any (.qc.report .qc.chk[q;.qc.int 0 9;{x<5}]) like "false"]
.t.t["report: passing run is one line"; 1=count .qc.report .qc.chk[q;.qc.int 0 9;{x<10}]]
/ last failure and again
a:.qc.again[]
.t.t["again: rechecks the last failure"; (5~a[`x]`x) and not a`stale]
r:.qc.chk[q,enlist[`shrinks]!enlist 0;.qc.lst[80 80] .qc.int 0 99;{x~asc x}]; l:last .qc.report r
.t.t["report: the rerun line is exact, not truncated, and round-trips"; (not l like "*..*") and (r[`choices])~value -1_last ";" vs l]
/ coverage
r:.qc.chk[q;.qc.int 0 9;{.qc.cover[`big;90;x>5]; .qc.classify[`small;x<5]; 1b}]
.t.t["cover: unmet requirement fails the run as cover"; (`cover=r`why) and not r`ok]
c:r`cover
.t.t["cover: table has label n pct req lo hi ok bar"; (`label`n`pct`req`lo`hi`ok`bar~cols c) and (90f=exec first req from c where label=`big) and not exec first ok from c where label=`big]
.t.t["cover: labels without a requirement are ok"; exec first ok from c where label=`small]
.t.t["cover: a requirement that is never hit still appears"; `never in exec label from (.qc.chk[q;.qc.int 0 9;{.qc.cover[`never;1;0b]; 1b}])`cover]
/ C15: confidence, not a threshold. uniform draws via elem; observed rates near 92% and 80% over 100 tests
.t.t["cover: 92% observed passes a 90% requirement (upper bound ~96%)"; (.qc.chk[q;.qc.elem til 100;{.qc.cover[`big;90;x<92]; 1b}])`ok]
.t.t["cover: 80% observed fails a 90% requirement (upper bound ~87%)"; `cover=(.qc.chk[q;.qc.elem til 100;{.qc.cover[`big;90;x<80]; 1b}])`why]
.t.t["cover: never hit passes a 0.1% requirement (cannot tell by nmax) and fails 10%"; ((.qc.chk[q;.qc.int 0 999;{.qc.cover[`never;0.1;0b]; 1b}])`ok) and `cover=(.qc.chk[q;.qc.int 0 999;{.qc.cover[`never;10;0b]; 1b}])`why]
.t.t["cover: hi column is the Wilson upper bound in percent"; 3.7>abs 96.2-exec first hi from (.qc.chk[q;.qc.elem til 100;{.qc.cover[`big;90;x<92]; 1b}])`cover]
.t.t["cover: met requirement passes"; (.qc.chk[q;.qc.int 0 9;{.qc.cover[`any;1;1b]; 1b}])`ok]
.t.t["cover: report prints the table"; any (.qc.report r) like "label*"]
.t.t["collect: labels by value"; 10>=count (.qc.chk[q;.qc.int 0 9;{.qc.collect x; 1b}])`cover]
/ suites
t:.qc.chks[q;`comm`sorted!((( .qc.int 0 9;.qc.int 0 9);{(x+y)=y+x});(.qc.list .qc.int 0 9;{x~asc x}))]
.t.t["checks: one row per property with outcome"; (98h=type t) and (`comm`sorted~t`name) and 10b~t`ok]
.t.t["checks: why column"; `ok`falsified~t`why]
.qc.cfg[`v]:1
