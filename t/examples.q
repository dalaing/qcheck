/ C18: the examples run. Each examples/*.q is a demo with a random seed, so only the shape of its outcome is
/ asserted: the process exits 0 and the report says what the script's own prose promises. Run as child
/ processes (each ends with exit). loaded by t/run.q
ex:{[f] system "sh -c 'q examples/",f," -q </dev/null 2>&1; echo EXIT $?'"}      / (a system command that begins with "q " prints instead of returning; sh -c captures)
code:{"J"$5_last x}
r:ex "reverse.q"
.t.t["examples/reverse.q: exits 0, the involution holds, the two planted properties fail"; (0=code r) and (1=sum r like "ok *") and 2=sum r like "FAIL falsified*"]
r:ex "tree.q"
.t.t["examples/tree.q: exits 0, leaves=1+nodes and the classify property pass, depth<4 fails"; (0=code r) and (2=sum r like "ok *") and 1=sum r like "FAIL falsified*"]
r:ex "sm_table.q"
.t.t["examples/sm_table.q: exits 0 and finds the planted pop bug as a postcondition failure"; (0=code r) and (1=sum r like "FAIL falsified*") and 1=sum r like "qc.post"]
r:ex "sm_ipc.q"
$[any r like "could not start a child q*"; -1 "  examples/sm_ipc.q skipped: no child q could be started";
  .t.t["examples/sm_ipc.q: exits 0 (the bug is found over IPC) and reports qc.post"; (0=code r) and 1=sum r like "qc.post"]]
