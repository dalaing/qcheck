/ oms: the generators as they stood at step 8: the reference data, an order, a fill
\d .oms
g.inst:([sym:`A`B`C] ccy:`USD`EUR`JPY; lot:1 10 100; tick:0.01 0.05 1f)
g.side:.qc.elem `buy`sell
g.qty:{[s] g.inst[s;`lot]*.qc.draw .qc.int 1 20}                                       / draws lots of the instrument
g.lim:{[s] t:g.inst[s;`tick]; t*.qc.draw .qc.int "j"$(g.px s)%t}                        / draws a limit price on the tick, in the instrument's range
g.order:{s:.qc.draw .qc.elem g.syms; (s; .qc.draw g.side; g.qty s; g.lim s)}            / sym side qty px
\d .
