/ q examples/order.q — a stateful test of a system that is itself a state machine: an order's lifecycle, with the
/ specification's transition table as the model. Run it from the repository root; COOKBOOK.md ("An order's
/ lifecycle: a transition table as the model") talks through the output.
\l qc.q
.qc.cfg[`db]:`                                   / no failure database: every run of this script searches afresh

/ The lifecycle as the specification writes it: a keyed table of (state; event) -> next state. Anything not in the
/ table may not happen. D is the same table as a dictionary of dictionaries, so D[state;event] is the next state
/ and a null where the table has no row.
T:([st:`new`new`new`ack`ack`ack`part`part`part; ev:`ack`rej`cxl`part`fill`cxl`part`fill`cxl]
   nx:`ack`rej`cxl`part`fill`cxl`part`fill`cxl)
D:exec ev!nx by st from T

/ The system under test: an order that keeps its state in a global and moves on an event. The bug is planted in
/ the fill after a partial fill, which leaves the order partly filled.
ORD:`new
on:{[e] s:ORD; n:$[(s=`new) and e=`ack; `ack; (s=`ack) and e=`rej; `rej; (s=`ack) and e=`cxl; `cxl;
  (s=`ack) and e=`part; `part; (s=`ack) and e=`fill; `fill; (s=`part) and e=`part; `part;
  (s=`part) and e=`fill; `part;                                               / the bug: should be `fill
  (s=`part) and e=`cxl; `cxl; (s=`new) and e in `rej`cxl; e; '"order: ",string[e]," not allowed in ",string s];
  ORD::n; n}

/ 1. The stateful test. The events are the commands, and each command's functions are built from the table with a
/ projection over the event: pre asks the table whether the event may happen in the model's state, post whether the
/ system moved to the state the table names, upd moves the model there. The report is the shortest sequence that
/ reaches the bug: ack, part, fill.
evs:exec distinct ev from T
cmds:([cmd:evs] pre:{[e;m] not null D[m;e]}@/:evs; run:{[e;a] on e}@/:evs;
  post:{[e;m;a;o] o~D[m;e]}@/:evs; upd:{[e;m;a;o] D[m;e]}@/:evs)
-1 "the order follows its transition table (false: a fill after a partial fill):";
.qc.check[.qc.sm[`m0`init!(`new;{`ORD set `new})] cmds; ::];

/ 2. Two rules about the table itself, no system needed. The trace of states an event sequence produces is a scan
/ over the table, an event the table does not allow leaving the state where it is. Once an order is filled,
/ cancelled or rejected, it stays in that state; and no event is allowed in a terminal state, which is a proof,
/ since three states and five events are fifteen inputs and the run tries them all.
walk:{[s;e] $[null n:D[s;e]; s; n]}
END:`rej`cxl`fill
-1 "\nonce an order reaches a terminal state it stays there:";
.qc.check[.qc.list .qc.elem evs; {w:walk\[`new;x]; all (-1_w in END)<=(1_w)=-1_w}];
-1 "\nno event is allowed in a terminal state:";
.qc.check[(.qc.elem END; .qc.elem evs); {[s;e] null D[s;e]}];
exit 0
