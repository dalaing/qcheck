/ mdp generators, step 01: an instrument table and a price
\d .mdp
g.inst:.qc.ktab[`sym;1 5] `sym`tick`lot`mult!(.qc.symc["ABCD";1 3]; .qc.elem 0.01 0.05 0.25 1f; .qc.elem 1 10 100; .qc.elem 1 10 50)
g.px:.qc.flt 0 1000
g.ref:{[d] inst::.qc.draw g.inst; (.qc.draw .qc.elem exec sym from inst; .qc.draw g.px)}   / sets the piece's table, gives (sym; px)
\d .
