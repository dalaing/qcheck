/ M9: integration — must signals the report, main exits with the failure count, results are .j.j-ready, checks times. loaded by t/run.q
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
system"S 7"
r:.qc.mustc[q;.qc.int 0 9;{x<10}]
.t.t["must: returns the result on ok"; (99h=type r) and r`ok]
e:@[.qc.mustc[q;.qc.int 0 9];{x<5};{x}]
.t.t["must: signals the report on a falsification; the first line is the verdict, the rest the report"; (10h=type e) and ((first "\n" vs e) like "qc: FAIL falsified after *") and (any ("\n" vs e) like "x: 5") and any ("\n" vs e) like "rerun: *"]
.t.t["must: a give-up and a coverage failure signal too"; ((first "\n" vs @[.qc.mustc[q;.qc.such[{0b}] .qc.int 0 9];{1b};{x}]) like "qc: FAIL gave up*") and (first "\n" vs @[.qc.mustc[q;.qc.elem til 100];{.qc.cover[`m;90;x<50]; 1b};{x}]) like "qc: FAIL coverage*"]
.t.t["must: the plain form takes the defaults"; (.qc.must[.qc.int 0 9;{x<10}])`ok]
.t.t["must: state is clean after a signal"; (not .qc.run) and .qc.cf~.qc.cfg]
/ results are machine-readable as they are (A25)
R:(.qc.chk[q;.qc.int 0 9;{1b}]; .qc.chk[q;.qc.list .qc.int 0 9;{x~asc x}]; .qc.chk[q;{'"boom"};{1b}]; .qc.chk[q;.qc.such[{0b}] .qc.int 0 9;{1b}]; .qc.chk[q;.qc.list .qc.int 0 100;{.qc.eq[x;asc x]}]; .qc.chk[q;.qc.elem til 100;{.qc.cover[`m;90;x<95]; 1b}])
.t.t["json: .j.j serialises every outcome and .j.k reads each back with the same keys"; all {(key x)~key .j.k .j.j x} each R]
/ checks times each property
tb:.qc.chks[q;`a`b!((.qc.int 0 9;{1b});(.qc.int 0 9;{x<5}))]
.t.t["checks: an ms column of non-negative longs, in the data"; (`ms in cols tb) and (7h=type tb`ms) and all 0<=tb`ms]
/ main, as a script in a child q
D:`$":",getenv[`TMPDIR],"qcmain_",string .z.i; system"mkdir -p ",1_string D
f1:` sv D,`ok.q; f1 0: ("\\l qc.q";".qc.cfg[`v`db]:(0;`)";".qc.main `a`b!((.qc.int 0 9;{1b});(.qc.bool;{1b}))")
f2:` sv D,`bad.q; f2 0: ("\\l qc.q";".qc.cfg[`v`db]:(0;`)";".qc.main `a`b`c!((.qc.int 0 9;{1b});(.qc.int 0 9;{x<5});(.qc.bool;{not x}))")
runq:{[f] system "sh -c 'q ",(1_string f)," -q </dev/null >/dev/null 2>&1; echo $?'"}
.t.t["main: exits 0 when every property passes"; 0="J"$first runq f1]   / ("J"$: a one-character line comes back as a one-element string, pitfall 25)
.t.t["main: exits with the number of failures (2)"; 2="J"$first runq f2]
system"rm -rf ",1_string D
.qc.cfg[`v]:1
