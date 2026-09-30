/ oms: the generators as they stood at step 5: a session of quotes, in time order
\d .oms
g.syms:`A`B`C
g.px:`A`B`C!(10 20; 100 110; 1000 1100)
g.quote:{[s] b:.qc.draw .qc.flt g.px s; (b; b+.qc.draw .qc.flt 0 1)}                  / a bid in the instrument's range and an ask at or above it
g.quotes:.qc.tabr[0 20] `time`sym`q!(.qc.mono[.qc.ts[g.open;g.close];.qc.int (0;"j"$0D00:01)]; .qc.elem g.syms; .qc.dep {[r] .oms.g.quote r`sym})
g.qs:{[t] select time, sym, bid:q[;0], ask:q[;1] from t}                              / the quote table from a draw
\d .
