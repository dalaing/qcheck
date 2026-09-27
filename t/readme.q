/ C18: the README's and the design's code blocks run. Every ```q block that is not a transcript (no line starting
/ q)) is loaded as a script under a trap; a block that errors fails the test and names its first line.
.qc.cfg[`v`db`seed]:(0;`;7i)                                / the blocks run their own checks: pinned (C8)
qbs:{[f] ln:read0 f; fence:where ln like "```*"; b:{[ln;se] ln (1+se 0)+til (se 1)-1+se 0}[ln] each 2 cut fence;
  b where (ln[fence 2*til count b] like "```q") and not any each b like\:"q)*"}
qb:raze qbs each `:README.md`:DESIGN.md`:COOKBOOK.md
S:([]v:`long$())                                             / the state-machine block redefines these; harmless
runb:{[i;b] e:@[{value each .t.stmts[x] 1; ""};b;{x}]; $[count e; (first b),": ",e; ""]}   / statement by statement, as t/run.q does: loading a script echoes the value of every bare expression
errs:runb'[til count qb;qb]
errs:errs where 0<count each errs
.t.t["every runnable README and DESIGN block loads without error"; (8<count qb) and 0=count errs]
if[count errs; -1 "  ",/:errs]
.qc.cfg[`v`seed]:(1;0Ni)
