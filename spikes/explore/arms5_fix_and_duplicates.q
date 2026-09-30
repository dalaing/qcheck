/ the changes that held up on the pipeline, by themselves and together, over the sweep. Everything else is
/ the library's shrinker as committed.
/   lib     the library
/   fix     a state machine's command recorded as its place among all the commands
/   dup     duplicates grouped by value and generator, whatever their ranges
/   fixdup  both
/   fixdupswap  both, and every swap of neighbouring siblings tried
system"l spikes/explore/sweep.q"
.qc.shrL:.qc.shr1
system"l spikes/explore/defs.q"
.qc.shr1:.qc.shrL
NS:$[count .z.x; "J"$first .z.x; 60]
.s.shown:{[o] t:o`notes; if[98h=type t; t:enlist t]; w:where {$[98h=type x; all `step`cmd in cols x; 0b]} each t; $[(::)~o`x; $[count w; " ; " sv {string[x`cmd],$[(::)~x`arg; ""; " ",.Q.s1 x`arg]} each t first w; .Q.s1 o`choices]; .Q.s1 $[1=count o`x; first value o`x; value o`x]]}
arms:`lib`fix`dup`fixdup`fixdupswap
if[1<count .z.x; arms:`$1_.z.x]
seeds:"i"$1+til NS
R:{[a] .qc.smloop:$[a in `fix`fixdup`fixdupswap; .qc.smloop1; .qc.smloop0]; .qc.pdup:$[a in `dup`fixdup`fixdupswap; .qc.pdupv; .qc.pdup1]; .qc.psort:$[a=`fixdupswap; .qc.psortv; .qc.psort1]; t0:.z.p; t:.s.run seeds; -1 string[a],": ",string["j"$(.z.p-t0)%1e9]," s"; update arm:a from t}
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
exit 0
