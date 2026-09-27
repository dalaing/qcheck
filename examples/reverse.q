/ q examples/reverse.q — a first property, and what a failure looks like. Run it from the repository root;
/ EXAMPLES.md ("A first property") talks through the output.
\l qc.q
.qc.cfg[`db]:`                                   / no failure database: every run of this script searches afresh

/ The generator describes the inputs: any list of longs from -99 to 99.
ints:.qc.list .qc.int -99 99

/ 1. A rule that holds. Reversing a list twice gives the list back, whatever the list, so a hundred examples pass.
-1 "reverse twice gives the list back:";
.qc.check[ints; {x~reverse reverse x}];

/ 2. A rule that does not. Most lists are not their own reverse. The first example that fails is some list of
/ random numbers; the report shows what is left of it after shrinking, the simplest list that still fails.
-1 "\nreverse gives the list back (false):";
.qc.check[ints; {x~reverse x}];

/ 3. Two inputs with names. The generator is a dict, the property takes parameters of the same names (in any
/ order), and the report names them too. The rule is false: a list need not have n items.
-1 "\na list has at least n items (false):";
.qc.check[`xs`n!(.qc.list .qc.int 0 9; .qc.int 0 5); {[n;xs] n<=count xs}];
exit 0
