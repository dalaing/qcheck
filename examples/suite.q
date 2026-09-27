/ q examples/suite.q — several properties as one script, for CI. Run it from the repository root; EXAMPLES.md
/ ("A suite") talks through the output. The exit code is the number of properties that failed: here 1.
\l qc.q
.qc.cfg[`db]:`                                   / no failure database: a CI run must not replay a developer's failures

/ A suite is a dict from a name to a pair: the generator and the property.
ints:.qc.list .qc.int 0 99
suite:()!()
suite[`reverse_twice]:(ints; {x~reverse reverse x})
suite[`sum_any_order]:(ints; {(sum x)=sum reverse x})
suite[`count_of_a_join]:((ints;ints); {[x;y] count[x,y]=count[x]+count y})
suite[`already_sorted]:(ints; {x~asc x})                                   / false, so that the script shows a failure

/ .qc.main runs each in turn, prints the report of each under its name, then one table with a row for each, and
/ exits with the number of failures. (.qc.checks does the same and returns the table, for use in a session.)
.qc.main suite
