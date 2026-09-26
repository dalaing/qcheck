/ q examples/sm_ipc.q — a state machine against a second q process over IPC (A14)
\l qc.q
port:5011+rand 900
system"q -p ",string[port]," -q </dev/null >/dev/null 2>&1 &"
h:0; do[100; if[0=h; h:@[hopen;`$":localhost:",string port;0]; if[0=h; system"sleep 0.1"]]]
if[0=h; -1 "could not start a child q"; exit 1]
h "n:0; inc:{n::n+1; if[n>3; n::0]; n}; rd:{n}; rst:{n::0}"         / the remote system: a counter that wraps after 3
cmds:([cmd:`inc`get]
  run: ({[i] h(`inc;::)}; {[i] h(`rd;::)});
  post:({[m;i;o] o=m+1};   {[m;i;o] o=m});
  upd: ({[m;i;o] m+1};     {[m;i;o] m}))
-1 "a counter in another q process (wraps after 3), reset over IPC before every example and replay:";
r:.qc.check[.qc.sm[`m0`init!(0;{h(`rst;::)})] cmds; ::]
@[h;"exit 0";::];
exit "i"$not `falsified=r`why
