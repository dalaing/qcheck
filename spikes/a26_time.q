\l spikes/h.q
\l spikes/bench.q
/ A26: finite temporal generators. Timestamps inside a session as a base plus non-negative deltas (A18), dates in
/ a business range; do xbar and ltime round-trip under shrinking, and what do the defaults look like?
.s.last:0p
ts:{[from;to;d] .s.last:from+.qc.draw .qc.int[(0;`long$to-from;0)]; .qc.draw .qc.lst[0 20] {[to;d] .s.last:to&.s.last+.qc.draw .qc.int 0 60000000000; .s.last}[to]}   / deltas up to a minute
dates:{[from;to;d] from+.qc.draw .qc.int (0;to-from;0)}
day:2024.01.02D09:30; close:2024.01.02D16:00
/ planted: at most three timestamps per minute (minimum: four timestamps in one minute)
r:.qc.chk[.b.q;ts[day;close];{not any 3<count each group 0D00:01 xbar x}]
show r[`x]`x
.h.t["xbar bug: four timestamps in one minute, sorted, at the session open"; (4=count v) and (v~asc v) and (1=count distinct 0D00:01 xbar v) and day=first v:r[`x]`x]
.h.t["timestamps never leave the session"; (.qc.chk[.b.q;ts[day;close];{all x within (day;close)}])`ok]
.h.t["timestamps are monotone in every example"; (.qc.chk[.b.q;ts[day;close];{x~asc x}])`ok]
.h.t["ltime/gtime round-trip is a fine property (and passes)"; (.qc.chk[.b.q;ts[day;close];{x~gtime ltime x}])`ok]
d:.qc.chk[.b.q;dates[2024.01.01;2024.12.31];{x<2024.06.01}]
.h.t["dates: a planted bug shrinks to the first date that fails"; 2024.06.01=d[`x]`x]
.h.t["dates stay in range"; (.qc.chk[.b.q;dates[2024.01.01;2024.12.31];{x within 2024.01.01 2024.12.31}])`ok]
.h.t["the minimal timestamp list is empty and the minimal date the first"; (0=count .qc.minimal ts[day;close]) and 2024.01.01=.qc.minimal dates[2024.01.01;2024.12.31]]
.h.done[]
