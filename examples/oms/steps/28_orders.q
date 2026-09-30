/ oms piece 3: orders and fills. step 28: a fill records the arrival price its order had when it was made, since a
/ split later divides the order's, and a fill is measured against the benchmark of its day (entry 12). The piece is
/ described in 08_orders.q. Needs 04_ref.q and 07_quotes.q loaded.
/ An order is a row of a keyed table, keyed on its id, with its state and what is left to fill. Its life follows a
/ transition table, T, which is the specification written down: a state and an event give the next state, and an
/ event the table has no row for is refused. Fills are events against an order: each reduces what is left, and the
/ last one fills it. On the way in an order is checked against the reference data: the instrument must exist, the
/ quantity be a multiple of its lot, the limit price on its tick. Its arrival price, the mid as of its time, is kept
/ for the execution analysis later.
\d .oms
T:([st:`new`new`new`ack`ack`ack`part`part`part; ev:`ack`rej`cxl`fill`part`cxl`fill`part`cxl] nx:`ack`rej`cxl`filled`part`cxl`filled`part`cxl)
D:exec ev!nx by st from T
order:([id:`long$()] time:`timestamp$(); sym:`symbol$(); side:`symbol$(); qty:`long$(); px:`float$(); st:`symbol$(); leaves:`long$(); arr:`float$())
fill:([]time:`timestamp$(); id:`long$(); sym:`symbol$(); qty:`long$(); px:`float$(); arr:`float$())   / arr: the order's arrival price as it stood at the fill
seq:0
ontick:{[s;p] 1e-9>abs (p%inst[s;`tick])-"j"$p%inst[s;`tick]}                          / a price on the instrument's tick
move:{[id;ev] n:D[order[id;`st];ev]; if[null n; '"oms: order ",string[id],": ",string[ev]," not allowed in ",string order[id;`st]]; order[id;`st]:n; n}
neworder:{[t;s;side;q;p] if[null inst[s;`ccy]; '"oms: unknown instrument ",string s]; if[not side in `buy`sell; '"oms: side must be buy or sell"];
  if[(q<=0) or 0<>q mod inst[s;`lot]; '"oms: qty ",string[q]," is not a multiple of the lot ",string inst[s;`lot]]; if[not ontick[s;p]; '"oms: px ",string[p]," is not on the tick ",string inst[s;`tick]];
  id:seq; seq+:1; order[id]:`time`sym`side`qty`px`st`leaves`arr!(t;s;side;q;p;`new;q;mid[t;s]); id}
ack:{[id] move[id;`ack]}
reject:{[id] move[id;`rej]}
cancel:{[id] move[id;`cxl]}
onfill:{[t;id;q;p] o:order id; if[null o`sym; '"oms: fill for an unknown order ",string id];
  if[(q<=0) or q>o`leaves; '"oms: fill of ",string[q]," against ",string[o`leaves]," left on order ",string id];
  move[id;$[q=o`leaves; `fill; `part]]; order[id;`leaves]:(o`leaves)-q; `.oms.fill insert (t;id;o`sym;q;p;o`arr);}
\d .
