/ qcheck properties as qspec expectations. Load qc.q before qspec runs this file.
.tst.desc["qcheck inside qspec"]{
 / the shortest form: .qc.must signals when the property fails, and qspec shows the report as an error
 should["give the list back when it is reversed twice"]{
  .qc.must[.qc.list .qc.int 0 99; {x~reverse reverse x}];
  };
 / to have a failing property counted as a failure and not as an error, run the check quietly (the setting v
 / of 0) and assert on its result, with the report as the message
 should["find every list sorted (false)"]{
  r:.qc.chk[enlist[`v]!enlist 0; .qc.list .qc.int 0 99; {x~asc x}];
  must[r`ok; "\n" sv .qc.report r];
  };
 };
