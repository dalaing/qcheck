/ q examples/sm_ipc.q — a state machine test of a system in another q process, driven over IPC. Run it from the
/ repository root, with q on the PATH; EXAMPLES.md ("A system in another process") talks through the output.
\l qc.q
.qc.cfg[`db]:`                                   / no failure database: every run of this script searches afresh

/ Start a second q on a port picked at random, and wait up to ten seconds for it to listen.
port:5011+rand 900
system"q -p ",string[port]," -q </dev/null >/dev/null 2>&1 &"
h:0; do[100; if[0=h; h:@[hopen;`$":localhost:",string port;0]; if[0=h; system"sleep 0.1"]]]
if[0=h; -1 "could not start a child q"; exit 1]

/ The real system lives in that process: a counter. inc adds one and returns the count, rd reads it, rst sets
/ it to zero. The bug: the counter wraps to zero when it passes three.
h "n:0; inc:{n::n+1; if[n>3; n::0]; n}; rd:{n}; rst:{n::0}"

/ The model is a long, the count there ought to be. Neither command takes an input, so there is no gen column;
/ and either may run at any time, so there is no pre column. A column left out takes its default.
cmds:([cmd:`inc`get]
  run: ({[i] h(`inc;::)}; {[i] h(`rd;::)});                 / the calls, sent down the handle
  post:({[m;i;o] o=m+1};   {[m;i;o] o=m});                  / inc answers one more than the model; get answers the model
  upd: ({[m;i;o] m+1};     {[m;i;o] m}))

/ init resets the remote counter before every sequence, replays and shrink attempts included, which is what lets
/ a failure found in another process be shrunk and replayed like any other.
-1 "a counter in another q process (it wraps after 3), reset over IPC before every sequence:";
r:.qc.check[.qc.sm[`m0`init!(0;{h(`rst;::)})] cmds; ::]
@[h;"exit 0";::];                                           / stop the child
exit "i"$not `falsified=r`why                               / exit 0 when the bug was found
