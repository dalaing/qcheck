/ q examples/pubsub.q — a stateful test of asynchronous messages: a publisher in this process sends rows to a
/ subscriber in another with neg[h], and the two must agree on what was sent. Run it from the repository root, with
/ q on the PATH; COOKBOOK.md ("Asynchronous messages and the close of a handle") talks through the output.
\l qc.q
.qc.cfg[`db]:`                                   / no failure database: every run of this script searches afresh

/ Start a second q, on a port taken from this process's id so that two runs at once do not meet, and wait up to
/ ten seconds for it to listen.
port:5011+.z.i mod 900
system"q -p ",string[port]," -q </dev/null >/dev/null 2>&1 &"
h:0; do[100; if[0=h; h:@[hopen;`$":localhost:",string port;0]; if[0=h; system"sleep 0.1"]]]
if[0=h; -1 "could not start a child q"; exit 1]
addr:`$":localhost:",string port

/ The subscriber keeps what it has been sent. upd appends a row; rows returns the rows; rst clears them.
h "T:([]id:`long$();px:`float$()); upd:{`T insert x;}; rows:{T}; rst:{`T set 0#T}"

/ The publisher: send sends a row as an asynchronous message, neg[h]; reconnect closes the handle and opens it
/ again, as a publisher that drops and re-establishes its connection does. The bug: nothing is flushed before
/ the close, and q may drop asynchronous messages still in the handle's buffer when it is closed. The model is
/ the table the subscriber ought to hold; get reads it back synchronously and compares.
send:{[r] neg[h] (`upd;r);}
reconnect:{hclose h; h::hopen addr;}
cmds:([cmd:`send`reconnect`get]
  gen: ({[m] `id`px!(.qc.int 0 9; .qc.flt 1 9)}; {[m] ::};  {[m] ::});
  run: ({[r] send r};                                {[a] reconnect[]};  {[a] h(`rows;::)});
  post:({[m;r;o] 1b};                               {[m;a;o] 1b};       {[m;a;o] o~m});
  upd: ({[m;r;o] m upsert r};                       {[m;a;o] m};        {[m;a;o] m}))
h0:`m0`init!(([]id:`long$();px:`float$()); {h(`rst;::)})
-1 "asynchronous sends, a reconnect that flushes nothing (false):";
r:.qc.check[.qc.sm[h0] cmds; ::]

/ The fix: a synchronous message on the handle before it is closed. It returns only once every
/ message sent before it has been processed, so nothing is left in the buffer.
reconnect:{h""; hclose h; h::hopen addr;}
-1 "\nwith a synchronous chaser before the close:";
.qc.check[.qc.sm[h0] cmds; ::];
@[h;"exit 0";::];                                           / stop the child
exit "i"$not `falsified=r`why                               / exit 0 when the bug was found
