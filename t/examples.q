/ C18: the examples run. Each examples/*.q is a demo with a random seed, so only the shape of its outcome is
/ asserted: the process exits 0 and the report says what the script's own prose promises. Run as child
/ processes (each ends with exit). loaded by t/run.q
ex:{[f] .t.q "q examples/",f," -q"}; code:.t.code
et:{[nm;r;ok] .t.t[nm;ok]; if[not ok; -1 "  ",/:-8#r];}                          / a failing example shows its last lines: the FAIL line alone says nothing
r:ex "reverse.q"
et["examples/reverse.q: exits 0, the involution holds, the two planted properties fail"; r; (0=code r) and (1=sum r like "ok *") and 2=sum r like "FAIL falsified*"]
r:ex "tree.q"
et["examples/tree.q: exits 0, leaves=1+nodes and the classify property pass, depth<4 fails"; r; (0=code r) and (2=sum r like "ok *") and 1=sum r like "FAIL falsified*"]
r:ex "sm_table.q"
et["examples/sm_table.q: exits 0 and finds the planted pop bug as a postcondition failure"; r; (0=code r) and (1=sum r like "FAIL falsified*") and 1=sum r like "qc.post"]
r:ex "aj.q"
et["examples/aj.q: exits 0 and finds the planted as-of-join bug"; r; (0=code r) and 1=sum r like "FAIL falsified*"]
r:ex "suite.q"
et["examples/suite.q: exits 1, the number of failures; three properties pass and the planted one fails"; r; (1=code r) and (1=sum r like "FAIL falsified*") and (3=sum r like "* 1  ok *") and 1=sum r like "* 0  falsified fail*"]
r:ex "sm_ipc.q"
$[any r like "could not start a child q*"; .t.t["examples/sm_ipc.q: skipped, no child q could be started (recorded, not hidden)"; 1b];
  et["examples/sm_ipc.q: exits 0 (the bug is found over IPC) and reports qc.post"; r; (0=code r) and 1=sum r like "qc.post"]]
r:ex "mdp/run.q"
et["examples/mdp/run.q: exits 0; every property and the stateful test pass (LOG.md's final system)"; r; (0=code r) and (0=sum r like "*falsified*") and 0<sum r like "*stateful_60_steps*"]
