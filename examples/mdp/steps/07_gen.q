/ mdp generators, step 07: a day's trades in time order
\d .mdp
g.inst:.qc.ktab[`sym;1 5] `sym`tick`lot`mult!(.qc.symc["ABCD";1 3]; .qc.elem 0.01 0.05 0.25 1f; .qc.elem 1 10 100; .qc.elem 1 10 50)
g.px:.qc.flt 0 1000
g.ref:{[d] inst::.qc.draw g.inst; (.qc.draw .qc.elem exec sym from inst; .qc.draw g.px)}
g.day:.qc.dates[2024.01.01;2024.12.31]
g.ren:{[d] inst::.qc.draw g.inst; s:exec sym from inst; ren::.qc.draw .qc.tabr[0 4] `old`new`eff!(.qc.elem s; .qc.one (.qc.elem s;.qc.symc["XYZ";1 2]); g.day); (.qc.draw .qc.elem s; .qc.draw g.day)}
open:2024.01.02D09:30; close:2024.01.02D16:00
g.ev:{[s] .qc.tabr[0 40] `time`kind`sym`bid`ask`px`qty!(.qc.mono[.qc.ts[open;close];.qc.int (0;"j"$0D00:00:10)]; .qc.elem `quote`trade; .qc.elem s;
  .qc.flt 1 100; .qc.dep {[r] .qc.flt (r`bid;100)}; .qc.flt 1 100; .qc.elem 1 10 100)}
g.stream:{[d] inst::.qc.draw g.inst; .qc.draw g.ev exec sym from inst}
g.trades:{[d] inst::.qc.draw g.inst; .qc.draw .qc.tabr[0 40] `time`sym`px`qty!(.qc.mono[.qc.ts[open;close];.qc.int (0;"j"$0D00:00:30)]; .qc.elem exec sym from inst; .qc.flt 1 100; .qc.elem 1 10 100)}
\d .
