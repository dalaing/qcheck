\l spikes/h.q
/ A24: a signalling form for other test frameworks: does a multi-line report survive as an error string through
/ @, .Q.trp, -1 and an IPC boundary?
msg:"qc: falsified after 3 tests, 2 shrinks (7 attempts, seed 7)\nx: 1 0\nrerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]"
e:@[{'x};msg;{x}]
.h.t["@ hands back the whole multi-line text"; e~msg]
e2:.Q.trp[{'x};msg;{[e;bt] e}]
.h.t[".Q.trp too"; e2~msg]
.h.t["the first line is a one-line summary a framework can print"; (first "\n" vs e) like "qc: falsified*"]
-1 "info: how it prints:"; -1 e;
port:5011+rand 900
system"q -p ",string[port]," -q </dev/null >/dev/null 2>&1 &"
h:0; do[100; if[0=h; h:@[hopen;`$":localhost:",string port;0]; if[0=h; system"sleep 0.1"]]]
if[0=h; -1 "could not start a child q"; exit 1]
e3:@[h;({'x};msg);{x}]
-1 "info: over IPC the caught error is: ",.Q.s1 e3;
.h.t["over IPC the error arrives as a string"; 10h=type e3]
.h.t["over IPC only the first line survives (kdb+ truncates the signal at the newline) — or it all does"; (e3~msg) or e3~first "\n" vs msg]
@[h;"exit 0";::];
.h.done[]
