/ generator contracts: every contract over every registry row (t/0gens.q). loaded by t/run.q
q[`n]:5                                                                            / five tests per contract check
system"S 7"                                                                       / fresh draws below are pinned too (C8)
sizes:0 1 2 5 30 100
at:{[s;f;a] .t.sz s; r:@[f;a;{[e] .t.sz 100; 'e}]; .t.sz 100; r}                  / run f a at size s
c1:{[g] all {[g;s] at[s;{[g] `ok~@[{.qc.draw x; `ok};g;{`ERR}]};g]}[g] each sizes}
c2:{[g;o] o~.qc.minimal g}
c3:{[g] all {[g;s] at[s;{[g] .qc.minimal g; 0<count .qc.C};g]}[g] each sizes}
c4:{[g] .t.sz 5; v:.qc.draw g; c:.qc.C`v; .t.sz 100; v~.qc.replay[c] g}
/ self-replay exactness in shrink mode: the recorded choices, replayed with the prefix strict, give the same
/ value, consume exactly that many choices, and record the same vector — what every shrink candidate relies on
c5:{[g] .qc.new[]; v:.qc.draw g; c:.qc.C`v; r:@[.qc.strict[c];g;{(`ERR;x)}]; (r~v) and (.qc.i=count c) and c~.qc.C`v}
c6:{[g] 1=count distinct type each {.qc.draw x} each 30#enlist g}
c7:{[g;ok] all ok each {.qc.draw x} each 200#enlist g}
c8:{[g] .qc.new[]; .qc.draw g; a:count .qc.L; l1:.qc.lbl g; do[50; .qc.draw g]; (a=count .qc.L) and l1=.qc.lbl g}
c9:{[g] .qc.draw g; (not .qc.run) and (0=.qc.dp) and (0=count .qc.st) and 25 80i~system"c"}
c10:{[g] (@[g;1;{x}]) like "qc: too many*"}
c11:{[g] (.qc.chk[q;::;{[g;x] n0:count .qc.C; .qc.draw g; count[.qc.C]>=n0}[g]])`ok}
{[r] nm:string r`name; g:r`gen;
  .t.t[nm,": draws at every size"; c1 g];
  .t.t[nm,": minimal is its origin"; c2[g;r`origin]];
  if[not (r`name) in .g.NOCH; .t.t[nm,": records a choice at every size"; c3 g]];
  .t.t[nm,": replays across sizes"; c4 g];
  .t.t[nm,": self-replay in shrink mode is exact"; c5 g];
  if[r`typed; .t.t[nm,": type is stable"; c6 g]];
  .t.t[nm,": values satisfy the registry predicate"; c7[g;r`ok]];
  .t.t[nm,": labels are stable and do not grow"; c8 g];
  .t.t[nm,": state is clean after a top-level draw"; c9 g];
  if[r`canary; .t.t[nm,": the canary refuses an extra argument"; c10 g]];
  .t.t[nm,": a draw inside a property joins the example"; c11 g];
  } each .g.T
.qc.new[]
