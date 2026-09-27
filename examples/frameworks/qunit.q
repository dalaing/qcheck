/ qcheck properties as QUnit tests. Load qc.q and qunit.q first, then this file, then .qunit.runTests `.qcTest
system "d .qcTest";
ints:.qc.list .qc.int 0 99;
/ the shortest form: .qc.must signals when the property fails, and QUnit gives the test the status error, with
/ the report as its result
testReverseTwice:{ .qc.must[ints; {x~reverse reverse x}] };
/ to have a failing property given the status fail, run the check quietly (the setting v of 0) and assert on
/ its result, with the report as the message
testSorted:{ r:.qc.chk[enlist[`v]!enlist 0; ints; {x~asc x}]; .qunit.assertTrue[r`ok; "\n" sv .qc.report r] };
system "d .";
