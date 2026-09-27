/ q t/run.q — load qc.q, run every t/*.q except this file, print one table, exit 0/1
/ How a file is read: one top-level statement at a time, where a line that begins with a space continues the
/ statement above (as \l does), each statement evaluated with value under a trap. Two consequences for test files:
/ a closer (} or )) must never start at column 0, or it becomes a statement of its own and both halves raise;
/ and inside a multi-line lambda every line must end in a semicolon, because value of a multi-line string does
/ not treat the newline as a separator the way \l does. The check below enforces the first; t/names.q pl shows the second.
\l qc.q
.t.r:()
q:()!()                                                                              / (defined per file by .t.load)
.t.t:{[nm;ok] b:$[type[ok] in -1 1h; all ok; 0b]; if[not type[ok] in -1 1h; nm,:" (not a boolean: ",(.Q.s1 ok),")"];
  if[(1h=type ok) and 0=count ok; b:0b; nm,:" (no cases: an empty boolean list)"];   / all[] over nothing is true; a test with nothing to test has not passed
  if[(1h=type ok) and (not b) and 1<count ok; nm,:" (false at ",(" " sv string where not ok),")"];   / a list of conjuncts says which failed; an and-chain cannot
  .t.r,:enlist (.t.f;`$nm;b); if[not b; -1 "FAIL ",string[.t.f],": ",nm];}
.t.e:{[f;x] @[f;x;{x}]}
.t.each:{[f;xs] {[f;x] e:.Q.trp[{[f;x] f x; 1b}[f];x;{[e;bt] e}]; if[10h=type e; .t.t["row ",(40#.Q.s1 x)," raised: ",e;0b]];}[f] each xs;}   / f over rows, each under its own trap: one row's raise is one failure, not the end of the loop
.t.cfg0:.qc.cfg                                                                   / the library defaults; restored before every file (C9)
.t.sz:{[s] .qc.cfg[`sz]:s; .qc.new[]}                                             / the interactive size, set the way a user would
.t.tmp:{[nm] d:`$":",getenv[`TMPDIR],nm,"_",string .z.i; system"mkdir -p ",1_string d; d}   / a scratch directory; .t.rm removes it
.t.rm:{system"rm -rf ",1_string x;}
.t.q:{[cmd] system "sh -c '",cmd," </dev/null 2>&1; echo EXIT $?'"}                 / a child q's output lines, the last "EXIT n" (a system command that begins with "q " prints instead of returning; sh -c captures)
.t.code:{"J"$5_last x}                                                             / the exit code from .t.q's lines
/ a file is evaluated one top-level statement at a time (an indented line continues the statement above, as \l
/ does), each under a trap: a statement that raises fails alone, named by its line, and the rest of the file still
/ runs — a test whose and-chain raises on a broken property must not hide every test after it (C2, C18)
.t.stmts:{[L] b:where not L like " *"; (1+b;{[L;s;e] "\n" sv L s+til e-s}[L]'[b;(1_b),count L])}   / (line; statement)
/ every file starts from the defaults, quiet, with q (the pinned configuration every test passes to .qc.chk: seed 7,
/ no failure db) fresh; and every root global a file defines is deleted after it, so nothing leaks between files
/ except through .t. and .g. (the generator registry) — a file that needs another's global fails, by design
.t.load:{[x] .t.f::x; .qc.cfg:.t.cfg0; .qc.cfg[`v]:0; .qc.new[]; q::.qc.cfg,`v`n`seed`db!(0;100;7;`); g0:key `.; se:.t.stmts read0 `$":t/",string x;
  {[n;s] e:.Q.trp[{value x; ""};s;{[e;bt] e,"\n",.Q.sbt bt}]; if[count e; .t.t["line ",string[n]," raised: ",first "\n" vs e;0b]; -1 "  ",e];}'[se 0;se 1];
  if[count nw:(key `.) except g0,`q; ![`.;();0b;nw]];}   / (guarded: a functional delete with no names deletes everything, pitfall 43)
.t.f:`run.q; .t.t["no test file has a closer at column 0 (it would split its statement)"; not any {any (read0 ` sv `:t,x) like "[})]*"} each f where (f:key `:t) like "*.q"]
.t.load each except[f where (f:key `:t) like "*.q";`run.q];                        / *.q only: not an editor's stray file
.t.R:flip `file`name`ok!flip .t.r
system"c 200 200"                                                                 / the summary in full: the default console cuts it at 25 rows
show select pass:sum ok,fail:sum not ok by file from .t.R
if[count f:select from .t.R where not ok; -1 "failed:"; -1 "  ",/:string[f`file],'": ",/:string f`name];   / the FAIL lines again, after everything else has scrolled
-1 string[sum .t.R`ok],"/",string[count .t.R]," passed";
exit "i"$0<sum not .t.R`ok
