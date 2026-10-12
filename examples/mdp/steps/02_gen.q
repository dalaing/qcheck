/ mdp generators, step 02: renames over the instrument table
\d .mdp
g.inst:.qc.ktab[`sym;1 5] `sym`tick`lot`mult!(.qc.symc["ABCD";1 3]; .qc.elem 0.01 0.05 0.25 1f; .qc.elem 1 10 100; .qc.elem 1 10 50)
g.px:.qc.flt 0 1000
g.ref:{[d] inst::.qc.draw g.inst; (.qc.draw .qc.elem exec sym from inst; .qc.draw g.px)}
g.day:.qc.dates[2024.01.01;2024.12.31]
/ renames: old is an instrument; new is another instrument or a fresh name (so chains and reversions can occur)
g.ren:{[d] inst::.qc.draw g.inst; s:exec sym from inst; ren::.qc.draw .qc.tabr[0 4] `old`new`eff!(.qc.elem s; .qc.one (.qc.elem s;.qc.symc["XYZ";1 2]); g.day); (.qc.draw .qc.elem s; .qc.draw g.day)}
\d .
