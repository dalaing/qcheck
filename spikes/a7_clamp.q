\l spikes/h.q
\l spikes/bench.q
/ A7: clamp on misalignment vs reject (candidate invalid when a replayed choice is out of range)
cs:.b.cases .qc.list
A:.b.run[.b.q;cs]; B:.b.run[.b.q,enlist[`clamp]!enlist 0b;cs]
-1 "--- clamp"; .b.show A; -1 "--- reject"; .b.show B
show ([] name:A`name; clamp_ok:A`ok; reject_ok:B`ok; clamp_att:A`attempts; reject_att:B`attempts)
.h.t["clamp reaches at least as many minima as reject"; (sum A`ok)>=sum B`ok]
.h.t["clamp uses no more attempts in total"; (sum A`attempts)<=sum B`attempts]
.h.done[]
