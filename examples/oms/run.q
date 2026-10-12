/ q examples/oms/run.q — the system's rules and its stateful tests as a CI script: one table, the exit code is the
/ number of failures (.qc.main). 300 tests each: entry 12 of LOG.md found its last bug at the seventieth sequence.
\l qc.q
\l examples/oms/oms.q
\l examples/oms/props.q
\l examples/oms/sm.q
.qc.cfg[`n`db]:(300;`)                                     / no failure db: a CI run must not replay a developer's, nor leave one behind
system"c 50 200"                                            / wide enough that the coverage table is not cut in the log
.z.exit:{system"rm -rf ",1_string .oms.hdb}                / the database goes on every exit, an error's included
r:.qc.checks props,stateful; exit "i"$sum not r`ok          / (.qc.main)
