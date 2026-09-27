/ q spikes/shrink_arms.q [seeds [arm ...]]   or   q spikes/shrink_arms.q show   (the last run's results again)
/ The experiment behind the shrinker's number passes, kept so that it can
/ be run again. Run by hand: run.sh does not run it (nine arms at sixty seeds take three minutes). It runs the seed
/ sweep (sweep.q) under several ways of shrinking numbers and scores each by how often it ends on the simplest
/ counterexample that any of them found. The passes that every arm shares are the library's; the arms differ in
/ the passes for one choice, for two choices, for duplicates, and for runs of choices:
/   base    the shrinker as it stood: bsr and a mirror; pairs within three places, moved all the way or both by one
/   rank    one choice: a binary search over the places of its values, 0 1 -1 2 -2 ..., in place of its values
/   two     one choice: each side of the origin searched by distance, as Hypothesis's minimize_nodes does
/   hyp     two, and for pairs Hypothesis's redistribute_numeric_pairs and lower_integers_together
/   trade   two, the old pairs, and a trade: an earlier choice made simpler, a later one searched outwards
/   both    two, Hypothesis's pairs, and the trade
/   del     both, and Hypothesis's node programs: any 1 to 5 choices in a row deleted, not only whole spans
/   lab     both, with a choice's partners the next ones made by the same generator, however far off, and
/           duplicates grouped by the generator that made them
/   all     lab and del
/   lib     the library as it now stands: all, with runs of 1 and 2 only
/ Hypothesis's passes are from its shrinker.py at commit 32ebeb2 (2026-09-27), written again for this engine. The
/ distances of every arm are the library's exact ones (dst): with distances in floats, as they were, no arm could
/ tell a timestamp from the one a nanosecond later.
\l spikes/h.q
\l spikes/sweep.q
SHOW:$[count .z.x; "show"~first .z.x; 0b]
NS:$[SHOW; 0; count .z.x; "J"$first .z.x; 60]
ONLY:`$1_.z.x
SAVED:hsym `$getenv[`TMPDIR],"/qc_shrink_arms"
\d .qc
/ ---- base: the passes as they were
pmir:{[j] o:cC[`o] j; v:cv j; $[v>=o; 0b; (("f"$o)+("f"$o)-"f"$v)>"f"$cC[`hi] j; 0b; try @[cv;j;:;o+o-v]]}
pmin0:{cp::`min; p:0b; j:0; while[j<count cv; $[cv[j]=cC[`o] j; j+:1; try @[cv;j;:;cC[`o] j]; p:1b; [if[bsr j; p:1b]; if[pmir j; p:1b]; j+:1]]]; p}
pred0:{cp::`pair; p:0b; ii:0; while[ii<count[cv]-1; vi:cv ii; oi:cC[`o] ii;
  $[vi=oi; ii+:1;
    [js:(ii+1+til 3) inter where (cC[`lo]=cC[`lo] ii)&cC[`hi]=cC[`hi] ii; ok:0b; n:0;
     while[(n<count js) and not ok; j:js n; vj:cv j; k:"j"$(("f"$vi)-"f"$oi)&("f"$cC[`hi] j)-"f"$vj;
       ok:$[k>0; try @[cv;ii,j;:;(vi-k;vj+k)]; 0b];
       if[(not ok) and vj>cC[`o] j; ok:try @[cv;ii,j;-;1]]; n+:1];
     $[ok; p:1b; ii+:1]]]]; p}
pdup0:{cp::`dup; p:0b; ix:where cv<>cC`o; g:ix each value group (flip (cv;cC`lo;cC`hi)) ix; g:g where 1<count each g; j:0;
  while[j<count g; ps:g j; ok:try @[cv;ps;:;cC[`o] ps];
    if[not ok; d:("f"$cv ps)-"f"$cC[`o] ps; go:1b; while[go and all 1<abs d; d:floor d%2; go:try @[cv;ps;:;cC[`o][ps]+"j"$d]; ok:ok or go]];
    if[ok; p:1b]; j+:1]; p}
/ ---- rank: the values of a range in order of simplicity, and a binary search over their places
ival:{[j;n] o:cC[`o] j; a:o-cC[`lo] j; b:cC[`hi][j]-o; m:a&b; $[n<=2*m; o+$[0=n mod 2; neg n div 2; (n+1) div 2]; b>a; o+n-m; o-n-m]}
vidx:{[j;v] o:cC[`o] j; a:o-cC[`lo] j; b:cC[`hi][j]-o; m:a&b; d:abs v-o; $[d<=m; (2*d)-v>o; m+d]}
bsrk:{[j] lo:0; hi:vidx[j;cv j]; p:0b; while[1<hi-lo; m:lo+(hi-lo) div 2; $[try @[cv;j;:;ival[j;m]]; [hi:m; p:1b]; lo:m]]; p}
pminr:{cp::`min; p:0b; j:0; while[j<count cv; $[cv[j]=cC[`o] j; j+:1; try @[cv;j;:;cC[`o] j]; p:1b; [if[bsrk j; p:1b]; j+:1]]]; p}
/ ---- hyp: Hypothesis's two passes for pairs, the partner of a choice being a later one of the same range within
/ four places (redistribute) or three (together)
near:{[ii;w] (ii+1+til w) inter where (cC[`lo]=cC[`lo] ii)&cC[`hi]=cC[`hi] ii}
redis:{[ii;j] s:sdo ii; d:far ii; vi:cv ii; vj:cv j; 0<fint {[ii;j;s;d;vi;vj;k] $[k>d; 0b; not inr[j;("f"$vj)+s*"f"$k]; 0b; tst @[cv;ii,j;:;(vi-s*k;vj+s*k)]]}[ii;j;s;d;vi;vj]}
toget:{[ii;j] s:sdo ii; d:far ii; vi:cv ii; vj:cv j; 0<fint {[ii;j;s;d;vi;vj;k] $[k>d; 0b; not inr[j;("f"$vj)-s*"f"$k]; 0b; tst @[cv;ii,j;:;(vi-s*k;vj-s*k)]]}[ii;j;s;d;vi;vj]}
predx:{[nr] cp::`pair; p:0b; ii:0; while[ii<count[cv]-1;
  $[cv[ii]=cC[`o] ii; ii+:1;
    [n:ns; js:nr[ii;4]; k:0; while[$[k>=count js; 0b; ns>n; 0b; not cv[ii]=cC[`o] ii]; redis[ii;js k]; k+:1];
     js:nr[ii;3]; k:0; while[$[k>=count js; 0b; ns>n; 0b; not cv[ii]=cC[`o] ii]; toget[ii;js k]; k+:1];
     $[ns>n; p:1b; ii+:1]]]]; p}
predh:{predx near}
predl:{predx prt}
/ ---- trade, with partners by place or by generator
ptrx:{[nr] cp::`trade; p:0b; ii:0; while[ii<count[cv]-1;
  $[cv[ii]=cC[`o] ii; ii+:1;
    [js:nr[ii;3]; ok:0b; ci:distinct cC[`o][ii],ring[ii;cv ii;2;0b]; n:0;
     while[$[n>=count js; 0b; not ok]; j:js n; cj:ring[j;cv j;TD;1b]; m:0;
       while[$[m>=count ci; 0b; not ok]; q:0; while[$[q>=count cj; 0b; not ok]; ok:try @[cv;ii,j;:;(ci m;cj q)]; q+:1]; m+:1];
       n+:1];
     $[ok; p:1b; ii+:1]]]]; p}
ptrd:{ptrx near}
ptrl:{ptrx prt}
/ ---- del: any k choices in a row deleted, k from 5 down to 1
pnod:{cp::`run; p:0b; k:5; while[k>0; ii:0; while[ii<=count[cv]-k; $[try dl[cv;ii;ii+k]; p:1b; ii+:1]]; k-:1]; p}
/ ---- the shrinker, over the passes PS; sweep.q's wrapper around it notes the key it ends on
PS:()
shr1:{[gen;prop;o] sgen::gen; sprop::prop; cv::C`v; cC::C; cE::E; co::o; cerr::o`err; na::0; ns::0;
  K::(enlist 0#0)!enlist 0N; H::0#H; bs::cf`sz;
  while[$[na<cf`shrinks; any {x[]} each PS; 0b]];
  co,`shrinks`attempts`hist!(ns;na;H)}
ST:(pblk;pdisc;pdel;pzero;pdesc;psort)
\d .
arms:`base`rank`two`hyp`trade`both`del`lab`all`lib!.qc.ST,/:(
  (.qc.pdup0;.qc.pmin0;.qc.pred0);
  (.qc.pdup0;.qc.pminr;.qc.pred0);
  (.qc.pdup0;.qc.pmin;.qc.pred0);
  (.qc.pdup0;.qc.pmin;.qc.predh);
  (.qc.pdup0;.qc.pmin;.qc.pred0;.qc.ptrd);
  (.qc.pdup0;.qc.pmin;.qc.predh;.qc.ptrd);
  (.qc.pdup0;.qc.pmin;.qc.predh;.qc.ptrd;.qc.pnod);
  (.qc.pdup;.qc.pmin;.qc.predl;.qc.ptrl);
  (.qc.pdup;.qc.pmin;.qc.predl;.qc.ptrl;.qc.pnod);
  (.qc.pdup;.qc.pmin;.qc.ppr;.qc.ptr;.qc.pnd))
if[count ONLY; arms:ONLY#arms]
seeds:"i"$1+til NS
R:{[a] .qc.PS:arms a; t0:.z.p; t:.s.run seeds; -1 string[a],": ",string["j"$(.z.p-t0)%1e9]," s"; update arm:a from t}
A:$[SHOW; get SAVED; raze R each key arms]
if[not SHOW; SAVED set A]
arms:(distinct A`arm)#arms; NS:count distinct A`seed
ref:.s.ref A
S:{[a] update arm:a from 0!.s.score[ref] select from A where arm=a} each key arms
system"c 100 250"
-1 "\nthe share of ",string[NS]," seeds at which each arm ended on the simplest counterexample any arm found:";
W:exec (key arms)#arm!atref by name:name from raze S
show select from W where not {all 1=x} each value W
-1 "(the other ",string[sum {all 1=x} each value W]," cases are 1 in every arm)";
-1 "\nin all:";
T:0!select cases:count i, always:sum atref=1, atref:avg atref, kinds:sum kinds, attempts:sum attempts, ms:"j"$sum ms by arm from raze S
show T iasc key[arms]?T`arm
-1 "\nthe cases the last arm does not always get right, and everything it found for them:";
L:select from A where arm=last key arms, why=`falsified, name in exec name from last[S] where atref<1
{[t;n] -1 string[n],":"; g:desc count each group exec found from t where name=n; -1 "  ",/:(string[value g],\:"  "),'200 sublist/:key g;}[L] each exec distinct name from L;
exit 0
