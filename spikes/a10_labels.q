\l spikes/h.q
/ A10: labelling spans by generator identity, cheaply
f:{[r;d] r}; g1:f[0 9]; g2:f[0 8]; l:{x+1}
/ option a: dict keyed by function values
L:(enlist g1)!enlist 0
.h.t["dict lookup by identical projection"; 0=L[f[0 9]]]
.h.t["different projection args -> different key"; null L[g2]]
L[l]:1
.h.t["lambda key matches structurally equal lambda"; 1=L[{x+1}]]
ta:system"t:100000 L[g1]"
-1 "info: dict-by-function lookup: ",string[ta*10]," ns/op";
/ option b: md5 of .Q.s1
tb:system"t:100000 md5 .Q.s1 g1"
-1 "info: md5 .Q.s1: ",string[tb*10]," ns/op";
/ option c: serialised bytes as key
B:(enlist -8!g1)!enlist 0
tc:system"t:100000 B[-8!g1]"
-1 "info: dict-by-serialised-bytes: ",string[tc*10]," ns/op";
.h.t["at least one labelling option is <= 2us/draw"; 2000>=min 10*(ta;tb;tc)]
/ what does string give for each kind?
-1 "info: string of lambda: ",.Q.s1 string l;
-1 "info: string of projection: ",.Q.s1 .h.err[string;g1];
-1 "info: value of projection: ",.Q.s1 value g1;
.h.t["value of a projection exposes the underlying lambda first"; (value g1)[0]~f]
.h.done[]
