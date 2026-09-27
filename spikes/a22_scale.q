\l spikes/h.q
\l spikes/bench.q
/ A22: scale. How do 1e3..1e6-element vectors generate and shrink under two designs?
/   element — today's list: one ch per element (a loop; a table append per choice; rows are spans)
/   bulk    — one call records n choices at once: fresh values by n?, replay by slicing the prefix, one C,: append;
/             the block is one span, so the shrinker needs a block-deletion pass (ddmin over the block) to reach a
/             minimum that is not a prefix — spiked here as pblk, patched into shr
/ A third design, a seeded bulk draw recording only (n;seed), was dropped before measuring: q has one RNG stream,
/ so deriving n values from a seed means reseeding the process mid-example and restarting the outer draws — it
/ breaks A3 (values recorded, not RNG state).
chn:{[lo;hi;n] j:.qc.i; .qc.i+:n; m:0|n&count[.qc.P]-j; p:lo|hi&m#j _ .qc.P;
  v:$[m=n; p; .qc.sh; '"qc.overrun"; .qc.mn; p,(n-m)#lo|hi&0; p,lo+(n-m)?1+hi-lo];
  if[.qc.cf[`choices]<count .qc.C; '"qc.toolarge"]; .qc.C,:flip `v`lo`hi`o!(v;n#lo;n#hi;n#lo|hi&0); v}
bvec:{[r;n;d] .qc.dd[d;"bvec"]; k:.qc.ch[(0;n;0);`u]; chn[r 0;r 1;k]}                         / length first (choice 0), then the block
bfix:{[r;n;d] .qc.dd[d;"bfix"]; chn[r 0;r 1;n]}                                                / exactly n, for timing
efix:{[n] .qc.lst[n,n] .qc.int 0 99}                                                           / exactly n (forced bits), for timing
efree:{[n] .qc.lst[0,n] .qc.int 0 99}                                                          / free length: needs sz >= n
/ block deletion (ddmin): remove a chunk of the block and shorten the length choice; halve the chunk when nothing goes
pblk:{.qc.cp::`blk; p:0b; g:2;
  while[$[1>k:.qc.cv 0; 0b; g<=k]; w:k div g; s:0; ok:0b;
    while[(s<k) and not ok; w2:w&k-s; ok:.qc.try (enlist (.qc.cv 0)-w2),.qc.dl[1_.qc.cv;s;s+w2]; s+:w];
    $[ok; g:2|g div 2; g*:2]; if[ok; p:1b]];
  p}
.qc.shr:{[spec;prop;o] .qc.sspec::spec; .qc.sprop::prop; .qc.cv::.qc.C`v; .qc.cC::.qc.C; .qc.cE::.qc.E; .qc.co::o; .qc.cerr::o`err; .qc.na::0; .qc.ns::0;
  .qc.K::(enlist 0#0)!enlist 0N; .qc.H::0#.qc.H; .qc.bs::.qc.cf`sz;
  while[$[.qc.na<.qc.cf`shrinks; any {x[]} each (pblk;.qc.pdisc;.qc.pdel;.qc.pzero;.qc.pdesc;.qc.psort;.qc.pdup;.qc.pmin;.qc.pred); 0b]];
  .qc.co,`shrinks`attempts`hist!(.qc.ns;.qc.na;.qc.H)}
q:.b.q,`choices`sz!(3000000;100)
.qc.cfg[`choices]:.qc.cf[`choices]:3000000                                     / the timing draws run outside a check (cf: interactive draws read the effective config, which cfg reaches only through a run — a wart for the library)
tm:{[f;x] t0:.z.p; r:f x; (r;(.z.p-t0)%1000000)}
gen:{[g] .qc.new[]; w0:.Q.w[]`used; r:tm[.qc.draw;g]; (r 1;(.Q.w[][`used]-w0)%1000000)}       / ms, MB
G:([] n:1000 10000 100000 1000000)
G:update elem_ms:{first gen efix x} each n from G where n<=100000
G:update bulk_ms:{first gen bfix[0 99;x]} each n from G
show G
.h.t["bulk generates 1e6 longs in under a second"; 1000>G[3;`bulk_ms]]
.h.t["bulk is at least 10x faster than per-element at 1e5"; G[2;`elem_ms]>10*G[2;`bulk_ms]]
/ shrinking x~asc x: the minimum is 1 0
shr:{[c;g] r:tm[{[c;g] .qc.chk[c;g;{x~asc x}]}[c];g]; o:r 0; (o`why;o[`x]`x;o`attempts;"j"$r 1)}
S:([] n:1000 10000 100000)
S:update bulk:{shr[q;bvec[0 99;x]]} each n from S
S:update elem:{shr[q,enlist[`sz]!enlist x;efree x]} each n from S where n<=10000
system"c 40 200"; show S
.h.t["bulk with block deletion: every size shrinks to 1 0"; all {1 0~x 1} each S`bulk]
.h.t["bulk: 1e5 shrinks in under 30 s"; 30000>last S[2;`bulk]]
.h.t["element: 1e3 shrinks to 1 0"; 1 0~S[0;`elem] 1]
-1 "info: attempts/ms bulk ",.Q.s1[S[`bulk][;2 3]],"  element ",.Q.s1 S[`elem][;2 3];
.qc.cfg[`choices]:.qc.cf[`choices]:8192
.h.done[]
