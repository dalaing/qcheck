/ oms: the generators as they stood at step 13: a run of fills for one instrument, and one rate per currency
\d .oms
g.fillrun:{[s] .qc.lst[0 8] (g.side; .qc.int[1 5]; .qc.flt g.px s)}                      / side, lots, price (the lot is applied by the caller)
g.fx1:.qc.tabr[3 3] `time`ccy`rate!(.qc.const g.open; .qc.uniq .qc.elem g.ccys; .qc.dep {[r] .oms.g.rate r`ccy})   / one rate for each currency, at the open
\d .
