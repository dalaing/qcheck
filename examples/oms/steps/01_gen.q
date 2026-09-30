/ oms: the generators as they stood at step 1: a session of FX rates, and things to convert
\d .oms
g.day:2024.01.02
g.open:g.day+0D09:30; g.close:g.day+0D16:00
g.ccys:`EUR`GBP`JPY
g.rates:`EUR`GBP`JPY!(1.05 1.15; 1.2 1.35; 0.006 0.008)                               / USD per unit, roughly where they were
g.rate:{[c] .qc.flt g.rates c}
g.fx:.qc.tabr[0 20] `time`ccy`rate!(.qc.mono[.qc.ts[g.open;g.close];.qc.int (0;"j"$0D00:05)]; .qc.elem g.ccys; .qc.dep {[r] .oms.g.rate r`ccy})   / rates in time order, each in its currency's range
g.t:.qc.ts[g.open;g.close]
g.amt:.qc.flt -1000 1000
\d .
