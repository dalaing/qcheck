/ the seed sweep, shared by a28_sweep.q and shrink_arms.q: a shrinker should reach the same counterexample, the
/ simplest one, whatever the seed. .s.cases is the suite; .s.run[seeds] runs every case at every seed and records
/ the shortlex key of what the shrinker ended on; .s.score compares runs against the best key seen for each case.
if[not `qc in key `; system"l qc.q"]
if[not `b in key `; system"l spikes/bench.q"]
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
/ objects made one at a time and linked by their numbers, and a walk along the links that never counts past two. No
/ more than five objects may be made, so the command that makes them comes and goes: the case that a state machine's
/ way of recording its commands is there for (A29)
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
  ([] name:`sorted_neg`reverse_neg`distinct_neg`sum_neg`adjeq_neg`twoints_neg`twoside`absdiff`absdiff_neg`sum3`prod`prod_pos`between`gap3`tab_sum`nested_neg`fsum`fprod`aj`upsert`bars`sm_stack`sm_ctr`sm_tp`sm_chain;
     spec:(n;n;n;n;n;(i9;i9);.qc.int -99 99;(p;p);(.qc.int -99 99;.qc.int -99 99);(p;p;p);(.qc.int -20 20;.qc.int -20 20);(p;p);(p;p;p);(p;p;p);
           .qc.tab `k`v!(.qc.int 0 3;.qc.int 0 9);L L i9;(.qc.flt 0 1;.qc.flt 0 1);(.qc.flt 0 10;.qc.flt 0 10);.s.pair;(.s.kt;.s.kt);.s.trades;.s.stack;.s.ctr;.s.tp;.s.chain);
     prop:({x~asc x};{x~reverse x};{x~distinct x};{50>=abs sum x};{not any (=)':[x]};{x>=y};{(x<50) and x>-10};{[x;y] 10>abs x-y};{[x;y] 10>abs x-y};{[x;y;z] 100>x+y+z};{[x;y] 50>x*y};{[x;y] 500>x*y};
           {[x;y;z] not (x<y) and y<z};{[x;y;z] not (10<=y-x) and 10<=z-y};{20>sum x`v};{5>=abs sum raze x};{[x;y] 1.5>x+y};{[x;y] 30>x*y};
           {(aj[`sym`time;x`t;x`q])~.s.naive[x`t;x`q]};{[t;u] (t upsert u)~keys[t] xkey (0!t),0!u};{b:0!.s.bars x; mx:0!select mx:max px by 0D00:01 xbar time from x; b[`h]~mx`mx};::;::;::;::))}
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
