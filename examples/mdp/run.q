/ q examples/mdp/run.q — the pipeline's properties and its stateful test as a CI script: one table, the exit code
/ is the number of failures (.qc.main). 300 tests each: entry 20 of LOG.md is why the stateful test needs more than 100 sequences.
\l qc.q
\l examples/mdp/mdp.q
\l examples/mdp/props.q
\l examples/mdp/sm.q
.qc.cfg[`n`db]:(300;`)                                     / no failure db: a CI run must not replay a developer's, nor leave one behind
system"c 50 200"                                            / wide enough that the coverage tables are not cut in the log
.z.exit:{system"rm -rf ",1_string .mdp.hdb}                / the HDB goes on every exit, an error's included
r:.qc.checks props,stateful; exit "i"$sum not r`ok          / (.qc.main)
