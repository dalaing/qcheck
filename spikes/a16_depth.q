\l spikes/h.q
/ A16: usable user recursion depth through the interpreter, and the depth guard
.s.dp:0; .s.max:0W; .s.mx:0
draw:{$[type[x] within 100 112; [.s.dp+:1; .s.mx|:.s.dp; if[.s.dp>.s.max; '"qc.toodeep"]; r:x[]; .s.dp-:1; r]; 0h=type x; .z.s each x; x]}
deep:{[d] draw deep}                              / a user generator: one interpreter round-trip per level
e:@[draw;deep;{x}]
-1 "info: user recursion levels before '",e,": ",string .s.mx;
.h.t["stack error arrives through draw and is caught"; e~"stack"]
.h.t["usable depth through the interpreter is >= 200"; .s.mx>=200]
.s.max:200; .s.dp:0; .s.mx:0
r:.Q.trp[draw;deep;{[e;bt] (e;.Q.sbt bt)}]
.h.t["qc.toodeep fires at the configured depth"; ("qc.toodeep"~r 0) and .s.mx=201]
.h.t["backtrace names the user generator"; (r 1) like "*deep*"]
nest:{[n] r:1; do[n; r:enlist r]; r}
.s.max:0W; .s.dp:0
.h.t["draw over a 500-deep nested constant list works"; (nest 500)~@[draw;nest 500;{x}]]
.s.dp:0; e2:@[draw;deep;{x}]; .s.dp:0; ok:@[draw;{[d] 1};{x}]
.h.t["after a caught 'stack the interpreter still works (state reset per example)"; ok=1]
.h.done[]
