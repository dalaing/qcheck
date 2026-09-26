/ reporting contracts: the rerun line round-trips as a property; one line pattern per outcome. loaded by t/run.q
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
line:{"rerun: .qc.again[]  or  .qc.recheck[spec;prop;",(" " sv string x),"]"}
back:{value -1_last ";" vs x}
r:.qc.chk[q,enlist[`n]!enlist 200;.qc.lst[1 300] .qc.one (.qc.int -1000 1000;.qc.elem 0W -0W 0);{x~(),back line x}]   / a one-choice line reads back as an atom (C16)
.t.t["rerun line round-trips for any choice vector (a property)"; r`ok]
pat:{[r] first .qc.report r}
.t.t["report: one first line per outcome"; all
  ((pat .qc.chk[q;.qc.int 0 999;{1b}]) like "ok 100 tests (seed *"; (pat .qc.chk[q;.qc.bool;{1b}]) like "ok 2 tests, exhausted (seed *";
   (p3 like "ok *") and (p3:pat .qc.chk[q;.qc.elem til 1000;{.qc.cover[`m;90;x<950]; 1b}]) like "*coverage settled (seed *";
   (p4 like "FAIL falsified after 5 tests, 0 shrinks (*") and (p4:pat .qc.chk[q;.qc.int 0 9;{x<5}]) like "* attempts, seed *";
   (pat .qc.chk[q;{'"boom"};{1b}]) like "FAIL error after 0 tests, *"; (pat .qc.chk[q;.qc.such[{0b}] .qc.int 0 9;{1b}]) like "FAIL gave up after 0 tests; discards: discard *";
   (pat .qc.chk[q;.qc.elem til 1000;{.qc.cover[`m;90;x<800]; 1b}]) like "FAIL coverage not met after 100 tests")]
.t.t["coverage table schema"; `label`n`pct`req`lo`hi`ok`bar~cols (.qc.chk[q;.qc.int 0 9;{.qc.classify[`a;x>5]; 1b}])`cover]
.qc.cfg[`v]:1
