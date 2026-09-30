/ q spikes/explore/arms6_drop.q [seeds [arm ...]]
/ the drop pass (drop.q) over the sweep, against the library as it stands with A29 in it
/   lib     the library
/   drop    and pdrop: a step whose command could not run after a deletion is deleted too
/   dropc   and a step one of whose choices was clamped
/   orig    the library, a choice out of its range on replay taking the origin and not the nearer bound
/   droporig  drop and orig
system"l spikes/explore/sweep.q"
.qc.shrL:.qc.shr1
system"l spikes/explore/drop.q"
NS:$[count .z.x; "J"$first .z.x; 60]
.s.shown:{[o] t:o`notes; if[98h=type t; t:enlist t]; w:where {$[98h=type x; all `step`cmd in cols x; 0b]} each t; $[(::)~o`x; $[count w; " ; " sv {string[x`cmd],$[(::)~x`arg; ""; " ",.Q.s1 x`arg]} each t first w; .Q.s1 o`choices]; 1=count o`x; .Q.s1 first value o`x; .Q.s1 value o`x]}
arms:`lib`drop`dropc
if[1<count .z.x; arms:`$1_.z.x]
seeds:"i"$1+til NS
R:{[a] d:.qc.arm a; .qc.shr1:$[d; .qc.shrd; .qc.shrL]; t0:.z.p; t:.s.run seeds; -1 string[a],": ",string["j"$(.z.p-t0)%1e9]," s"; update arm:a from t}
A:raze R each arms
ref:.s.ref A
S:{[a] update arm:a from 0!.s.score[ref] select from A where arm=a} each arms
system"c 100 250"
-1 "\nthe share of ",string[NS]," seeds at which each arm ended on the simplest counterexample any arm found:";
W:exec arms#arm!atref by name:name from raze S
show select from W where not {all 1=x} each value W
-1 "(the other ",string[sum {all 1=x} each value W]," cases are 1 in every arm)";
T:0!select cases:count i, always:sum atref=1, atref:avg atref, kinds:sum kinds, attempts:sum attempts, ms:"j"$sum ms by arm from raze S
-1 "\nall ",string[count W]," cases:"; show T iasc arms?T`arm
-1 "\nthe state machines:"; show select name,arm,kinds,atref,attempts from (raze S) where name like "sm_*"
exit 0
