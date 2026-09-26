/ C18: the README's and the design's code blocks run. Every ```q block that is not a transcript (no line starting
/ q)) is loaded as a script under a trap; a block that errors fails the test and names its first line.
.qc.new[]
.qc.cfg[`v`db`seed]:(0;`;7i)                                / the blocks run their own checks: pinned (C8)
qbs:{[f] L:read0 f; fence:where L like "```*"; b:{[L;se] L (1+se 0)+til (se 1)-1+se 0}[L] each 2 cut fence;
  b where (L[fence 2*til count b] like "```q") and not any each b like\:"q)*"}
qb:raze qbs each `:README.md`:DESIGN.md
d:`$":",getenv[`TMPDIR],"qcreadme_",string .z.i; system"mkdir -p ",1_string d
S:([]v:`long$())                                             / the state-machine block redefines these; harmless
run1:{[i;b] f:` sv d,`$"b",string[i],".q"; f 0: b; e:@[{system"l ",1_string x; ""};f;{x}]; $[count e; (first b),": ",e; ""]}
errs:run1'[til count qb;qb]
errs:errs where 0<count each errs
.t.t["every runnable README and DESIGN block loads without error"; (8<count qb) and 0=count errs]
if[count errs; -1 "  ",/:errs]
system"rm -rf ",1_string d
.qc.cfg[`v`seed]:(1;0Ni)
