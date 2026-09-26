/ the shrink benchmark as tests: every classic case reaches its analytic minimum within an attempt cap;
/ the shrinker never re-runs a candidate; shrinking is idempotent through the failure db. loaded by t/run.q
\l spikes/bench.q
.qc.cfg[`v]:0
res:.b.run[.b.q;.b.cases .qc.list]
cap:`sorted`reverse`distinct`len5`sum100`adjeq`bound`neg`twoints`nested`bound5`tree3`tree4`rose3`filtered`bigint`interactive`squares!70 70 30 80 120 30 30 10 10 160 70 80 90 30 120 130 30 50
{[r] .t.t["bench ",string[r`name],": analytic minimum within ",string[cap r`name]," attempts"; (r`ok) and r[`attempts]<=cap r`name]} each res
.t.t["bench: the whole suite under 1200 attempts"; 1200>sum res`attempts]
/ the candidate cache: every attempt was a new candidate
r:.qc.chk[.b.q;.qc.list .qc.int 0 99;{x~asc x}]
.t.t["cache: attempts equal distinct candidates tried"; (r`attempts) within (count[.qc.K]-1;count .qc.K)]   / -1 for the seed key, unless the empty candidate overwrote it
/ idempotence: the saved shrunk failure, replayed and shrunk again, needs no shrinks
d:`$":",getenv[`TMPDIR],"qcidem_",string .z.i; qd:.b.q,`db`name!(d;`i)
r1:.qc.chk[qd;.qc.list .qc.int 0 99;{x~asc x}]; r2:.qc.chk[qd;.qc.list .qc.int 0 99;{x~asc x}]
.t.t["idempotent: a shrunk failure replayed from the db shrinks no further"; (r1[`x]~r2`x) and (0=r2`shrinks) and 0=r2`n]
system"rm -rf ",1_string d
.qc.cfg[`v]:1
