\l spikes/h.q
\l spikes/bench.q
/ A6: continue-bit lists (.qc.list) vs a length-prefixed list under the same shrinker
lstn:{[g;d] .qc.dd[d;"lstn g"]; n:.qc.ch[(0;.qc.sz;0);`u]; .qc.draw n#enlist g}      / length first, then n elements
cs:select from .b.cases[.qc.list] where lists; cn:select from .b.cases[lstn] where lists
A:.b.run[.b.q;cs]; B:.b.run[.b.q;cn]
-1 "--- continue bits"; .b.show A; -1 "--- length prefix"; .b.show B
show ([] name:A`name; bits_ok:A`ok; len_ok:B`ok; bits_att:A`attempts; len_att:B`attempts; bits_found:.Q.s1 each A`found; len_found:.Q.s1 each B`found)
.h.t["continue bits reach every minimum"; all A`ok]
.h.t["continue bits reach at least as many minima as the length prefix"; (sum A`ok)>=sum B`ok]
.h.done[]
