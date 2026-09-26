/ q t/run.q — load qc.q, run every t/*.q except this file, print one table, exit 0/1
\l qc.q
.t.r:()
.t.t:{[nm;ok] b:$[type[ok] in -1 1h; all ok; 0b]; if[not type[ok] in -1 1h; nm,:" (not a boolean: ",(.Q.s1 ok),")"]; .t.r,:enlist (.t.f;`$nm;b); if[not b; -1 "FAIL ",string[.t.f],": ",nm];}
.t.e:{[f;x] @[f;x;{x}]}
.t.load:{.t.f::x; e:.Q.trp[{system"l t/",string x; ""};x;{[e;bt] e,"\n",.Q.sbt bt}]; if[count e; .t.t["file loads";0b]; -1 "  error: ",e];}
.t.load each except[key `:t;`run.q];
.t.R:flip `file`name`ok!flip .t.r
show select pass:sum ok,fail:sum not ok by file from .t.R
-1 string[sum .t.R`ok],"/",string[count .t.R]," passed";
exit "i"$0<sum not .t.R`ok
