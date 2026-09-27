/ C17: the distribution you ship, measured on the ranges people use, for every hint and every generator.
/ pinned seed; bounds are several sigma wide, never exact rates. loaded by t/run.q
system"S 11"
near:{[x;t;w] x within t+w*-1 1}
/ lengths of a bounded list are uniform on lo..hi (each of 11 lengths ~9%; require >=4% over 2000)
ls:count each .t.D[.qc.lst[0 10] .qc.int 0 9;2000]
.t.t["lst[0 10]: every length appears and none is rare"; (11=count distinct ls) and all 0.04<(count each group ls)%2000]
/ alternatives and elements are uniform
o3:.t.D[.qc.one (0;1;2);2000]
.t.t["one: three alternatives each near a third"; all near[;1%3;0.06] (count each group o3)%2000]
e5:.t.D[.qc.elem til 5;2000]
.t.t["elem: five values each near a fifth"; all near[;0.2;0.05] (count each group e5)%2000]
f13:.t.D[.qc.freq[1 3] (0;1);2000]
.t.t["freq[1 3]: near 1:3"; near[avg f13;0.75;0.05]]
.t.t["bit 0.2: near 20%"; near[avg .t.D[.qc.bit 0.2;2000];0.2;0.05]]
/ the full-domain wrapper: specials near 5%, spread over the three
sp:.t.D[.qc.t"j";3000]
/ specials are 5% of draws, but the normal branch's boundary picks add the infinities of a full range: ~9% in all
.t.t["t j: nulls and infinities between 4% and 15%, each kind present"; ((avg (null sp) or 0W=abs sp) within 0.04 0.15) and (any null sp) and (any sp=0W) and any sp=-0W]
/ integers: symmetric ranges are sign-balanced, one-sided ranges are not dominated by the bound
si:.t.D[.qc.int -1000 1000;2000]
.t.t["int -1000 1000: signs balanced among nonzero"; near[avg 0<si where si<>0;0.5;0.08]]
.t.t["int 0 1000: zeros under 20%; large values and the bound present (small values are common by design)"; (0.2>avg 0=v) and (0.03<avg 500<v) and 0.01<avg 1000=v:.t.D[.qc.int 0 1000;2000]]
/ floats
fl:.t.D[.qc.flt 0 1;2000]
.t.t["flt 0 1: mean near a half, both halves populated"; near[avg fl;0.5;0.06] and (0.3<avg fl<0.5) and 0.3<avg fl>0.5]
.t.t["dbl: negatives near 30%"; near[avg 0>.t.D[.qc.dbl;2000];0.3;0.06]]
/ two implementations of one law agree (AUDIT2, C17): mix vs mixn, unif vs unifn, on the ranges people use
ms:.t.D[.qc.int 0 1000;4000]; mv:.qc.mixn[0;1000;0;4000]
.t.t["mixn agrees with mix on 0..1000: zeros, the bound, values under 10, the mean (within 3 sigma)"; (0.03>abs (avg 0=ms)-avg 0=mv) and (0.02>abs (avg 1000=ms)-avg 1000=mv) and (0.04>abs (avg ms<10)-avg mv<10) and 40>abs (avg ms)-avg mv]
ms:.t.D[.qc.int -1000 1000;4000]; mv:.qc.mixn[-1000;1000;0;4000]
.t.t["mixn agrees with mix on -1000..1000: sign balance and the mean"; (0.04>abs (avg ms>0)-avg mv>0) and 40>abs (avg ms)-avg mv]
us:.t.D[.qc.elem til 10;4000]; uv:.qc.unifn[0;9;4000]
.t.t["unifn agrees with unif on 0..9: every value within 3 sigma of a tenth in both"; (all near[;0.1;0.03] (count each group us)%4000) and all near[;0.1;0.03] (count each group uv)%4000]
/ structures: node counts of rec spread over the budget; step counts of sm spread over the cap
.t.sz 30
nb:.t.D[.qc.rec[2 2;0;{1+sum x}];1000]
qs:asc[nb] 250 500 750                                                     / (not q: every other test file's config dict)
.t.t["rec at size 30: quartiles spread across the budget (A15: 7 15 22)"; (qs[0] within 3 12) and (qs[1] within 10 20) and qs[2] within 17 28]
cm:([cmd:enlist `a] run:enlist {[a] ::})
sc:count each .t.D[.qc.sm[`m0`steps!(0;0 10)] cm;1000]
.t.t["sm steps 0..10 at size 30: every count appears and none is rare"; (11=count distinct sc) and all 0.04<(count each group sc)%1000]
.t.sz 100
