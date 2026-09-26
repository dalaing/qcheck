\l spikes/h.q
/ A4: error handling — custom signals, nesting, backtraces, deep recursion
.h.t["custom signal caught as its string"; "qc.discard"~@[{'"qc.discard"};::;{x}]]
.h.t["symbol signal caught as string"; "sym"~@[{'`sym};::;{x}]]
.h.t["signals from inside each are caught"; "type"~@[{{x+`a} each x};1 2;{x}]]
inner:{@[{'"qc.eq"};::;{'x}]}                     / inner trap re-signals
.h.t["nested traps: outer sees re-signalled inner error"; "qc.eq"~@[inner;::;{x}]]
r:.Q.trp[{[x] x+`a};1;{[e;bt] (e;.Q.sbt bt)}]
.h.t[".Q.trp gives error and a backtrace naming the lambda"; ("type"~r 0) and (r 1) like "*x+`a*"]
/ generator vs property errors are distinguishable by wrapping separately
gerr:@[{'"gen boom"};::;{"gen: ",x}]; perr:@[{'"prop boom"};::;{"prop: ",x}]
.h.t["separate wrapping tags the phase"; (gerr like "gen:*") and perr like "prop:*"]
/ runaway recursion
deep:{deep x+1}
s:@[deep;0;{x}]
.h.t["infinite recursion signals a catchable 'stack"; s~"stack"]
/ budget check in the primitive stops runaway generators cleanly before 'stack
.s.n:0; .s.max:10000
ch:{.s.n+:1; if[.s.n>.s.max; '"qc.toolarge"]; 1}
tree:{$[ch[]; tree[]; 0]}
e:@[tree;::;{x}]
-1 "info: runaway recursive gen stopped by: ",e," after ",string[.s.n]," levels";
.h.t["runaway recursive generator is caught (stack before budget: depth limit ~2000)"; e in ("stack";"qc.toolarge")]
/ -1 output of a string containing unicode
.h.t["unicode marks are printable strings"; (count "✓")=3]
.h.done[]
