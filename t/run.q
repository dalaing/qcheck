/ q t/run.q — load qc.q, run every t/*.q except this file, print one table, exit 0/1
\l qc.q
.t.r:()
.t.t:{[nm;ok] b:$[type[ok] in -1 1h; all ok; 0b]; if[not type[ok] in -1 1h; nm,:" (not a boolean: ",(.Q.s1 ok),")"]; .t.r,:enlist (.t.f;`$nm;b); if[not b; -1 "FAIL ",string[.t.f],": ",nm];}
.t.e:{[f;x] @[f;x;{x}]}
.t.cfg0:.qc.cfg                                                                   / the library defaults; restored before every file (C9)
.t.sz:{[s] .qc.cfg[`sz]:s; .qc.new[]}                                             / the interactive size, set the way a user would
/ a file is evaluated one top-level statement at a time (an indented line continues the statement above, as \l
/ does), each under a trap: a statement that raises fails alone, named by its line, and the rest of the file still
/ runs — a test whose and-chain raises on a broken property must not hide every test after it (C2, C18)
.t.stmts:{[L] b:where not L like " *"; (1+b;{[L;s;e] "\n" sv L s+til e-s}[L]'[b;(1_b),count L])}   / (line; statement)
.t.load:{[x] .t.f::x; .qc.cfg:.t.cfg0; .qc.new[]; se:.t.stmts read0 `$":t/",string x;
  {[n;s] e:.Q.trp[{value x; ""};s;{[e;bt] e,"\n",.Q.sbt bt}]; if[count e; .t.t["line ",string[n]," raised: ",first "\n" vs e;0b]; -1 "  ",e];}'[se 0;se 1];}
.t.load each except[key `:t;`run.q];
.t.R:flip `file`name`ok!flip .t.r
system"c 200 200"                                                                 / the summary in full: the default console cuts it at 25 rows
show select pass:sum ok,fail:sum not ok by file from .t.R
if[count f:select from .t.R where not ok; -1 "failed:"; -1 "  ",/:string[f`file],'": ",/:string f`name];   / the FAIL lines again, after everything else has scrolled
-1 string[sum .t.R`ok],"/",string[count .t.R]," passed";
exit "i"$0<sum not .t.R`ok
