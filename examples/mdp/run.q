/ q examples/mdp/run.q — the pipeline's properties and its state machine as a CI script: one table, the exit code
/ is the number of failures (.qc.main). 300 tests each: entry 20 of LOG.md is why the machine needs more than 100.
\l qc.q
\l examples/mdp/mdp.q
\l examples/mdp/props.q
\l examples/mdp/sm.q
.qc.cfg[`n`db]:(300;`)                                     / no failure db: a CI run must not replay a developer's, nor leave one behind
system"c 50 200"                                            / wide enough that the coverage tables are not cut in the log
.qc.main props,machine
