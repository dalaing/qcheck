\l spikes/h.q
\l spikes/bench.q
/ A8: shrink quality on the classic suite — every case must reach its analytic minimum
T:.b.run[.b.q;.b.cases .qc.list]
.b.show T
.h.t["every case reaches its analytic minimum"; all T`ok]
.h.t["total attempts under 2000 for the whole suite"; 2000>sum T`attempts]
.h.t["no single case needs more than 400 attempts"; 400>max T`attempts]
.h.done[]
