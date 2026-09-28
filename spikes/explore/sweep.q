/ the seed sweep, shared by a28_sweep.q and shrink_arms.q: a shrinker should reach the same counterexample, the
/ simplest one, whatever the seed. .s.cases is the suite; .s.run[seeds] runs every case at every seed and records
/ the shortlex key of what the shrinker ended on; .s.score compares runs against the best key seen for each case.
if[not `qc in key `; system"l qc.q"]
if[not `b in key `; system"l spikes/bench.q"]
.s.HARD:`run3`run3_neg`run4`sm_kv`sm_lg`sm_alias`sm_chain
.s.q:.qc.cfg,`v`n`db!(0;100;`)
/ what the cases need
.s.S:([]v:`long$())
.s.push:{`.s.S insert enlist x;}
.s.pop:{r:$[2<count .s.S; first .s.S`v; last .s.S`v]; delete from `.s.S where i=count[.s.S]-1; r}   / wrong once three are stacked
.s.stack:.qc.sm[`m0`init!(`long$();{.s.S::0#.s.S})] ([cmd:`push`pop] pre:({1b};{0<count x}); gen:({.qc.int 0 9};{::}); run:(.s.push;.s.pop); post:({[m;a;o] 1b};{[m;a;o] o=last m}); upd:({[m;a;o] m,a};{[m;a;o] -1_m}))
.s.N:0
.s.ctr:.qc.sm[`m0`init!(0;{.s.N::0})] ([cmd:`inc`get] run:({[a] .s.N+:1; if[.s.N>3; .s.N::0]; .s.N};{[a] .s.N}); post:({[m;a;o] o=m+1};{[m;a;o] o=m}); upd:({[m;a;o] m+1};{[m;a;o] m}))   / wraps after three
.s.T:([]sym:`symbol$();px:`float$())
.s.tp:.qc.sm[`m0`init`inv!(0;{.s.T::0#.s.T};{[m] m=count .s.T})] ([cmd:enlist `upd] gen:enlist {[m] .qc.tabr[1 5] `sym`px!(.qc.symc["ab";1 1];.qc.flt 0 9)}; run:enlist {[x] .s.T::0!(`sym xkey .s.T) upsert x;}; upd:enlist {[m;a;o] m+count a})
/ a store of keys and values in which two keys one apart share a slot: a put to k+1 overwrites what was put to k.
/ The keys of three steps must move together for the trace to get simpler: k, k+1, k
.s.KV:()!()
.s.slot:{x div 2}
.s.kv:.qc.sm[`m0`init!(()!();{.s.KV::()!()})] ([cmd:`put`get] pre:({1b};{0<count x}); gen:({(.qc.int 0 20;.qc.int 0 9)};{.qc.elem key x});
  run:({[a] .s.KV[.s.slot a 0]:a 1;};{[a] .s.KV .s.slot a}); post:({[m;a;o] 1b};{[m;a;o] o~m a}); upd:({[m;a;o] m[a 0]:a 1; m};{[m;a;o] m}))
/ a ledger of accounts in which a transfer of the whole of an account, to the account after it, is lost: the two
/ accounts and the amount are three inputs tied to what an earlier step deposited
.s.LG:()!()
.s.lg:.qc.sm[`m0`init!(()!();{.s.LG::()!()})] ([cmd:`dep`mov`bal] pre:({1b};{0<count x};{0<count x}); gen:({(.qc.int 0 9;.qc.int 1 50)};{(.qc.elem key x;.qc.int 0 9;.qc.int 1 50)};{.qc.elem key x});
  run:({[a] .s.LG[a 0]:(0^.s.LG a 0)+a 1;};{[a] f:a 0; t:a 1; n:a[2]&0^.s.LG f; .s.LG[f]:(0^.s.LG f)-n; if[not (t=f+1) and 0=.s.LG f; .s.LG[t]:(0^.s.LG t)+n];};{[a] 0^.s.LG a});
  post:({[m;a;o] 1b};{[m;a;o] 1b};{[m;a;o] o=0^m a}); upd:({[m;a;o] m[a 0]:(0^m a 0)+a 1; m};{[m;a;o] f:a 0; t:a 1; n:a[2]&0^m f; m[f]:(0^m f)-n; m[t]:(0^m t)+n; m};{[m;a;o] m}))
/ does x hold n values in a row that each add one to the one before? Every one of them must move for the run to
/ get simpler, and a run that starts below its origin gets simpler as a whole by moving up: -1 0 1 to 0 1 2
.s.runs:{[n;x] any (n-2) {x and next x}/ 1=1_deltas x}
/ ---- modelled on the pipeline's sabotage of the quote cache: names that are renamed, the rename taking effect at a
/ roll, and a merge at the roll that keeps the wrong entry. A later step refers to a name by its place in the model's
/ list of names, so deleting a step changes what later steps mean
.s.can:{[app;n] while[n in key app; n:app n]; n}
.s.AV:(`symbol$())!`long$(); .s.AQ:(`symbol$())!`long$(); .s.AP:(); .s.AA:(`symbol$())!`symbol$(); .s.AN:0; .s.AR:0
.s.ainit:{.s.AV::(`symbol$())!`long$(); .s.AQ::(`symbol$())!`long$(); .s.AP::(); .s.AA::(`symbol$())!`symbol$(); .s.AN::0; .s.AR::0}
.s.afree:{[m] m[`names] where not m[`names] in (key m`app),first each m`pend}
.s.aget:{[m;a] c:.s.can[m`app;a]; l:m`log; l:l where c=.s.can[m`app] each l[;1]; $[count l; last (l iasc l[;0])[;2]; 0N]}
.s.alias:.qc.sm[`m0`init!(`names`log`pend`app`seq`nr!(enlist `A;();();(`symbol$())!`symbol$();0;0);.s.ainit)] ([cmd:`put`ren`roll`get]
  pre:({[m] 1b};{[m] (4>count m`names) and 0<count .s.afree m};{[m] 1b};{[m] 1b});
  gen:({[m] (.qc.elem m`names;.qc.int 0 9)};{[m] .qc.elem .s.afree m};{[m] ::};{[m] .qc.elem m`names});
  run:({[a] n:.s.can[.s.AA;a 0]; .s.AV[n]:a 1; .s.AQ[n]:.s.AN; .s.AN+:1;};
       {[a] .s.AP,:enlist (a;`$"N",string .s.AR); .s.AR+:1;};
       {[a] {[r] o:r 0; n:r 1; if[o in key .s.AV; if[not n in key .s.AV; .s.AV[n]:.s.AV o; .s.AQ[n]:.s.AQ o]; .s.AV::(enlist o) _ .s.AV; .s.AQ::(enlist o) _ .s.AQ]; .s.AA[o]:n;} each .s.AP; .s.AP::();};
       {[a] .s.AV .s.can[.s.AA;a]});
  post:({[m;a;o] 1b};{[m;a;o] 1b};{[m;a;o] 1b};{[m;a;o] o~.s.aget[m;a]});
  upd:({[m;a;o] m[`log],:enlist (m`seq;a 0;a 1); m[`seq]+:1; m};
       {[m;a;o] n:`$"N",string m`nr; m[`pend],:enlist (a;n); m[`names],:n; m[`nr]+:1; m};
       {[m;a;o] m:{[m;r] m[`app;r 0]:r 1; m}/[m;m`pend]; m[`pend]:(); m};
       {[m;a;o] m}))
/ ---- objects made one at a time and linked by their numbers, and a walk along the links that is wrong for a chain of
/ three. Six steps at the least, and every link and the walk refer to objects by number: a step deleted puts several
/ later steps out at once
.s.CN:`long$()
.s.walk:{[p;a] n:0; c:a; while[$[c<0; 0b; n<count p]; n+:1; c:p c]; n}
.s.chain:.qc.sm[`m0`init!(`long$();{.s.CN::`long$()})] ([cmd:`new`link`walk]
  pre:({[m] 5>count m};{[m] 1<count m};{[m] 0<count m});
  gen:({[m] ::};{[m] (.qc.elem til count m;.qc.elem til count m)};{[m] .qc.elem til count m});
  run:({[a] .s.CN,:-1;};{[a] if[not a[0]=a 1; .s.CN[a 0]:a 1];};{[a] 2&.s.walk[.s.CN;a]});
  post:({[m;a;o] 1b};{[m;a;o] 1b};{[m;a;o] o=.s.walk[m;a]});
  upd:({[m;a;o] m,-1};{[m;a;o] $[a[0]=a 1; m; @[m;a 0;:;a 1]]};{[m;a;o] m}))
.s.syms:.qc.lst[1 3] .qc.symc["abc";1 1]
.s.tbl:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s;.qc.mono[.qc.int 0 9;.qc.int 0 9];g)}
.s.pair:{[d] s:.qc.draw .s.syms; `q`t!(.qc.draw .s.tbl[s;`px;.qc.int 0 9];.qc.draw .s.tbl[s;`qty;.qc.int 0 9])}
.s.naive:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; first r; 0N]}[q]; update px:"j"$f'[sym;time] from t}
.s.kt:.qc.ktab[`k;0 4] `k`v!(.qc.int 0 3;.qc.int 0 9)
.s.trades:.qc.tabr[1 50] `time`px!(.qc.mono[.qc.ts[2024.01.02D09:30;2024.01.02D16:00];.qc.int (0;"j"$0D00:01)];.qc.flt 1 100)
.s.bars:{select o:first px,h:first px,l:min px,c:last px by 0D00:01 xbar time from x}
/ the cases: the classic suite of bench.q, the same over ranges that span their origin, several inputs that
/ constrain one another, nested lists, tables, floats, and state machines
.s.extra:{[L] n:L .qc.int -99 99; i9:.qc.int -9 9; p:.qc.int 0 99;
  ([] name:`sorted_neg`reverse_neg`distinct_neg`sum_neg`adjeq_neg`twoints_neg`twoside`absdiff`absdiff_neg`sum3`prod`prod_pos`between`gap3`tab_sum`nested_neg`fsum`fprod`aj`upsert`bars`sm_stack`sm_ctr`sm_tp`run3`run3_neg`run4`sm_kv`sm_lg`sm_alias`sm_chain;
     spec:(n;n;n;n;n;(i9;i9);.qc.int -99 99;(p;p);(.qc.int -99 99;.qc.int -99 99);(p;p;p);(.qc.int -20 20;.qc.int -20 20);(p;p);(p;p;p);(p;p;p);
           .qc.tab `k`v!(.qc.int 0 3;.qc.int 0 9);L L i9;(.qc.flt 0 1;.qc.flt 0 1);(.qc.flt 0 10;.qc.flt 0 10);.s.pair;(.s.kt;.s.kt);.s.trades;.s.stack;.s.ctr;.s.tp;
           L .qc.int 0 20;L i9;L .qc.int 0 5;.s.kv;.s.lg;.s.alias;.s.chain);
     prop:({x~asc x};{x~reverse x};{x~distinct x};{50>=abs sum x};{not any (=)':[x]};{x>=y};{(x<50) and x>-10};{[x;y] 10>abs x-y};{[x;y] 10>abs x-y};{[x;y;z] 100>x+y+z};{[x;y] 50>x*y};{[x;y] 500>x*y};
           {[x;y;z] not (x<y) and y<z};{[x;y;z] not (10<=y-x) and 10<=z-y};{20>sum x`v};{5>=abs sum raze x};{[x;y] 1.5>x+y};{[x;y] 30>x*y};
           {(aj[`sym`time;x`t;x`q])~.s.naive[x`t;x`q]};{[t;u] (t upsert u)~keys[t] xkey (0!t),0!u};{b:0!.s.bars x; mx:0!select mx:max px by 0D00:01 xbar time from x; b[`h]~mx`mx};::;::;::;
           {not .s.runs[3;x]};{not .s.runs[3;x]};{not .s.runs[4;x]};::;::;::;::))}
.s.cases:{[L] (select name,spec,prop from .b.cases L),.s.extra L}
/ the key of what a shrink ended on, taken as the shrinker finishes (tidy clears its state afterwards)
\d .qc
shr1:shr
shr:{[gen;prop;o] r:shr1[gen;prop;o]; .s.K::skey[cv;cC`o]; r}
\d .
.s.K:()
.s.shown:{[o] .Q.s1 $[(::)~o`x; o`choices; 1=count o`x; first value o`x; value o`x]}
.s.one:{[r;s] .s.K::(); t0:.z.p; o:.qc.chk[.s.q,enlist[`seed]!enlist s;r`spec;r`prop];
  `name`seed`why`k`found`attempts`ms!(r`name;s;o`why;.s.K;$[`falsified=o`why; .s.shown o; string o`why];o`attempts;(.z.p-t0)%1000000)}
.s.run:{[seeds] raze {[seeds;r] .s.one[r] each seeds}[seeds] each .s.cases .qc.list}
/ the reference each run is scored against: the counterexample with the least key among the runs that failed. Runs
/ are compared with it by value, since two choice vectors may draw the same value and the reader sees the value
.s.best:{[ks] b:0; j:1; while[j<count ks; if[.qc.less[ks j;ks b]; b:j]; j+:1]; b}
.s.ref:{[t] t:select from t where why=`falsified; exec {[k;f] f .s.best k}[k;found] by name from t}
/ per case: how many runs failed, how many kinds of result, the share that reached the reference, attempts
.s.score:{[ref;t] t:select from t where why=`falsified;
  select runs:count i, kinds:count distinct found, atref:avg found~\:ref first name, attempts:sum attempts, ms:sum ms, top:{first key desc count each group x} found by name from t}
