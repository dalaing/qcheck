/ C18: the README's code blocks run. Every ```q block that is not a transcript (no line starting q)) is loaded
/ as a script under a trap; a block that errors fails the test and names its first line.
.qc.new[]
.qc.cfg[`v`db`seed]:(0;`;7i)                                / the blocks run their own checks: pinned (C8)
L:read0 `:README.md
fence:where L like "```*"
blocks:{[L;se] L (1+se 0)+til (se 1)-1+se 0}[L] each 2 cut fence
qb:blocks where (L[fence 2*til count blocks] like "```q") and not any each blocks like\:"q)*"
d:`$":",getenv[`TMPDIR],"qcreadme_",string .z.i; system"mkdir -p ",1_string d
S:([]v:`long$())                                             / the state-machine block redefines these; harmless
run1:{[i;b] f:` sv d,`$"b",string[i],".q"; f 0: b; e:@[{system"l ",1_string x; ""};f;{x}]; $[count e; (first b),": ",e; ""]}
errs:run1'[til count qb;qb]
errs:errs where 0<count each errs
.t.t["every runnable README block loads without error"; (2<count qb) and 0=count errs]
if[count errs; -1 "  ",/:errs]
system"rm -rf ",1_string d
.qc.cfg[`v`seed]:(1;0Ni)
