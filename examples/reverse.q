/ q examples/reverse.q
\l qc.q
-1 "reverse is an involution:";
.qc.check[.qc.list .qc.int -99 99; {x~reverse reverse x}];
-1 "\nreverse is not the identity:";
.qc.check[.qc.list .qc.int -99 99; {x~reverse x}];
-1 "\nnamed inputs, applied by parameter name:";
.qc.check[`xs`n!(.qc.list .qc.int 0 9; .qc.int 0 5); {[n;xs] n<=count xs}];
exit 0
