/ M6 dogfooding: qcheck testing qcheck's pure parts. loaded by t/run.q
ok:{[spec;prop] (.qc.chk[q;spec;prop])`ok}
/ the shortlex order on keys is a strict total order
kv:.qc.list .qc.int -9 9                                    / a choice vector; origins 0
k:{.qc.skey[x;count[x]#0]}
.t.t["less: irreflexive"; ok[kv;{not .qc.less[k x;k x]}]]
.t.t["less: total and antisymmetric"; ok[(kv;kv);{[a;b] $[a~b; 1b; .qc.less[k a;k b]<>.qc.less[k b;k a]]}]]
.t.t["less: transitive"; ok[(kv;kv;kv);{[a;b;c] $[.qc.less[k a;k b] and .qc.less[k b;k c]; .qc.less[k a;k c]; 1b]}]]
.t.t["key: deleting a choice makes the vector smaller"; ok[.qc.lst[1 0W] .qc.int -9 9;{.qc.less[k 1_x;k x]}]]
.t.t["key: moving a choice toward its origin makes the vector smaller"; ok[(.qc.lst[1 0W] .qc.int 1 9;.qc.int 0 99);{[v;i] i:i mod count v; .qc.less[k @[v;i;-;1];k v]}]]
.t.t["zig: 0 1 -1 2 -2 ... is injective on a range"; ok[.qc.lst[2 0W] .qc.int -50 50;{(count distinct x)=count distinct .qc.zig x}]]
/ the edit primitives
.t.t["pt: replacing a span with itself is the identity"; ok[(kv;.qc.int 0 99;.qc.int 0 99);{[v;s;e] n:count v; s:s mod 1+n; e:s+e mod 1+n-s; v~.qc.pt[v;s;e;v s+til e-s]}]]
.t.t["dl: deleting a span shortens by its width"; ok[(kv;.qc.int 0 99;.qc.int 0 99);{[v;s;e] n:count v; s:s mod 1+n; e:s+e mod 1+n-s; (count[v]-e-s)=count .qc.dl[v;s;e]}]]
/ diff and eq over the type zoo
vals:.qc.one (.qc.t"j";.qc.t"f";.qc.t"s";.qc.t"d";.qc.list .qc.t"j";.qc.list .qc.t"s";.qc.str;.qc.tab `a`b!(.qc.int 0 9;.qc.sym);.qc.list .qc.list .qc.int 0 3)
.t.t["diff: nothing differs from itself"; ok[vals;{0=count .qc.diff[x;x]}]]
.t.t["diff: a difference is found iff match fails (fixed column order)"; ok[(vals;vals);{[a;b] (a~b)=0=count .qc.diff[a;b]}]]
.t.t["diff: rows always say why, with a path"; ok[(vals;vals);{[a;b] d:.qc.diff[a;b]; all (d[`why] in `type`count`value`key) and 0h=type d`path}]]
.t.t["eq: agrees with match"; ok[(vals;vals);{[a;b] (a~b)=1b~@[.qc.eq[a;];b;{0b}]}]]
/ the formatter is total and the console is restored
shapes:.qc.one (vals;`a`b!(.qc.t"j";.qc.tab `c`d!(.qc.t"j";.qc.t"s"));(.qc.t"j";.qc.tab (enlist `c)!enlist .qc.t"j");.qc.ktab[`a;0 3] `a`b!(.qc.int 0 9;.qc.t"f");.qc.const {x+1};(::))
.t.t["fmt: returns a string for every shape and restores the console"; ok[shapes;{s:.qc.fmt x; (10h=abs type s) and 25 80i~system"c"}]]
/ the coverage bound
.t.t["wil: a probability, at least the observed rate, monotone in the count"; ok[(.qc.int 0 100;.qc.int 1 100);{[n;N] n:n&N; u:.qc.wil[n;N]; (u within 0 1) and (u>=n%N) and u>=.qc.wil[0|n-1;N]}]]
/ the counting tables satisfy the Catalan recurrence
ct:.qc.ctab[2 2;40]`T
.t.t["ctab: T[n+1] = sum T[i]*T[n-i]"; ok[.qc.int 0 39;{ct[x+1]=sum ct[til 1+x]*ct[x-til 1+x]}]]
.t.t["conv is commutative"; ok[(.qc.lst[3 3] .qc.flt 0 9;.qc.lst[3 3] .qc.flt 0 9);{[a;b] .qc.conv[a;b]~.qc.conv[b;a]}]]
/ the shrinker never accepts a longer candidate, and its result replays
shk:{[sp;pr] r:.qc.chk[q;sp;pr]; h:r`hist; (all 0>=1_deltas h`len) and (r[`x]~(.qc.recheck[sp;pr;r`choices])`x)}
.t.t["shrink history is non-increasing in length and the result rechecks"; all (shk[.qc.list .qc.int 0 99;{x~asc x}];shk[.qc.rec[2 2;.qc.int 0 9;{(x 0;x 1)}];{3>count raze x}];shk[(.qc.int 0 9;.qc.int 0 9);{x>=y}])]
/ the engine is not reentrant, and says so
.t.t["a nested check signals"; "qc: nested check"~(.qc.chk[q;.qc.int 0 9;{.qc.check[.qc.int 0 9;{1b}]}])`err]
/ C3 mechanised: every dispatcher in the runner is total over one fixed shape zoo (this is where byname failed)
zoo:(1;1 2;"ab";"a";`s;`a`b;();(1;`a);(1;(2 3;`b));`a`b!1 2;()!();([]a:1 2);([a:1 2]b:3 4);(::);{x+1};{x+y};.qc.int 0 9;0#([]a:1 2))
tot:{[f] all {[f;x] `ok~@[{[f;x] f x; `ok}[f];x;{`ERR}]}[f] each zoo}
.t.t["C3 kind, blocky, fmt, named, byname, app and diff are total over the shape zoo";
  all tot each (.qc.kind;.qc.blocky;.qc.fmt;.qc.named[.qc.int 0 9;{x}];.qc.byname[{[a;b] a}];.qc.app[{x};.qc.int 0 9];{.qc.diff[x;x]})]
.t.t["C3 app by name only for a real dict with matching keys"; (.qc.byname[{[a;b] a};`a`b!1 2]) and not any .qc.byname[{[a;b] a}] each (([a:1 2]b:3 4);`a`c!1 2;1 2;(::))]
/ C10 completeness: the interactive entry points refuse to run inside a run, as chk does
.t.t["minimal and replay inside a property signal instead of resetting it"; ("qc: nested check"~(.qc.chk[q;.qc.int 0 9;{.qc.minimal .qc.int 0 9}])`err) and "qc: nested check"~(.qc.chk[q;.qc.int 0 9;{.qc.replay[1 2] .qc.int 0 9}])`err]
