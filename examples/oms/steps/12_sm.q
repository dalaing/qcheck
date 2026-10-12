/ oms: a stateful test of the order lifecycle. step 12: a partial fill needs at least two left, or there is no part
/ to draw (entry 8). Step 9 describes the test. Needs 04_ref.q, 07_quotes.q, 08_orders.q and the generators.
/ The model is a table of the orders the test has placed, with the state and the leaves each ought to have, and the
/ transition table T is read for what each event ought to do. The commands are the events: a new order; an ack, a
/ reject or a cancel of an order chosen from the model; a fill of part or all of what is left on an order that can
/ take one; and a fill of more than is left, which must be refused. pre asks the table whether the event is allowed
/ in the order's state, post whether the system's state and leaves are what the table and the arithmetic say.
\d .oms
o.m0:([id:`long$()] st:`symbol$(); leaves:`long$(); qty:`long$())
o.init:{order::0#order; fill::0#fill; seq::0}
o.nx:{[st;ev] {.oms.D[x;y]}'[st;ev]}                                                / the next state of each, one at a time: D[st;ev] over a list fails where a state has no row
o.can:{[m;ev] exec id from m where not null .oms.o.nx[st;ev]}                        / the orders the event is allowed on (q-sql resolves a bare name in the root, so the names are spelled out)
o.canp:{[m] exec id from m where not null .oms.o.nx[st;`part], leaves>1}            / and a partial fill needs something left after it
o.pick:{[m;ev] .qc.elem o.can[m;ev]}
o.cmds:([cmd:`new`ack`reject`cancel`fill`part`over]
  w:   3 3 1 1 2 2 1f;
  pre: ({[m] 1b}; {[m] 0<count o.can[m;`ack]}; {[m] 0<count o.can[m;`rej]}; {[m] 0<count o.can[m;`cxl]}; {[m] 0<count o.can[m;`fill]}; {[m] 0<count o.canp m}; {[m] 0<count o.can[m;`fill]});
  gen: ({[m] (.qc.const g.order[]; g.t)};                                              / (the tuple is drawn as the generator is built: one order per step)
        {[m] o.pick[m;`ack]}; {[m] o.pick[m;`rej]}; {[m] o.pick[m;`cxl]};
        {[m] o.pick[m;`fill]};
        {[m] id:.qc.draw .qc.elem o.canp m; (id; .qc.draw .qc.int (1;-1+m[id;`leaves]))};                / an id that can take a partial fill, and a part of what is left
        {[m] id:.qc.draw o.pick[m;`fill]; (id; .qc.draw .qc.int (1+m[id;`leaves];2*m[id;`leaves]))});   / more than is left
  run: ({[a] o:a 0; neworder[a 1;o 0;o 1;o 2;o 3]};
        {[id] ack id}; {[id] reject id}; {[id] cancel id};
        {[id] onfill[g.open;id;order[id;`leaves];order[id;`px]]; order[id;`st`leaves]};
        {[a] onfill[g.open;a 0;a 1;order[a 0;`px]]; order[a 0;`st`leaves]};
        {[a] @[{onfill[g.open;x 0;x 1;order[x 0;`px]]; `taken};a;{`refused}]});
  post:({[m;a;o] (order[o;`st]=`new) and order[o;`leaves]=a[0;2]};
        {[m;id;o] o=D[m[id;`st];`ack]}; {[m;id;o] o=D[m[id;`st];`rej]}; {[m;id;o] o=D[m[id;`st];`cxl]};
        {[m;id;o] o~(D[m[id;`st];`fill];0)};
        {[m;a;o] o~(D[m[a 0;`st];`part];m[a 0;`leaves]-a 1)};
        {[m;a;o] (o=`refused) and order[a 0;`st`leaves]~m[a 0;`st`leaves]});
  upd: ({[m;a;o] m upsert (o;`new;a[0;2];a[0;2])};
        {[m;id;o] m[id;`st]:`ack; m}; {[m;id;o] m[id;`st]:`rej; m}; {[m;id;o] m[id;`st]:`cxl; m};
        {[m;id;o] m[id;`st`leaves]:(`filled;0); m};
        {[m;a;o] m[a 0;`st]:`part; m[a 0;`leaves]-:a 1; m};
        {[m;a;o] m}))
o.hooks:`m0`init!(o.m0;o.init)
\d .
